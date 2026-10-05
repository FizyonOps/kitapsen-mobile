import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fushi/src/media/video/audio_energy_probe.dart';
import 'package:fushi/src/pages/implementations/video_fushi_page.dart';
import 'package:fushi/src/sync/remote_video_client.dart'
    show RemoteVideoTimingAudio;
import 'package:fushi/src/utils/net/ffmpeg_relay_route.dart';
import 'package:fushi_engine/utils/misc/desktop_audio_clipper.dart';
import 'package:path/path.dart' as p;

import '../helpers/emby_relay_rig.dart';
import '../helpers/source_guard.dart';

/// BUG-2957：Emby / Jellyfin / Plex 与在线视频源上没有波形对轴、自动对轴与语音模型
/// 重定时。三个入口共用的音源解析只认「本机视频文件」与「互联 host 裁整集音轨」，
/// 其它网络流一律判无音源，入口整个不挂。修复让音源解析多一条网络流分支：本机
/// ffmpeg 经制卡同一条取流路径（媒体服务器 / 在线源走本机中继）抽出当前音轨。
void main() {
  // 端到端用例要真中继 + 真原点：撤掉测试绑定默认那个一律回 400 的 HttpClient 桩。
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;

  group('subtitleTimingStreamSource', () {
    test('媒体服务器直出 / 在线源：播放流就是音源，沿用播放器的音轨下标', () {
      expect(
        subtitleTimingStreamSource(
          miningSource: kEmbyStreamUrl,
          miningAudioSource: null,
        ),
        (
          url: kEmbyStreamUrl,
          usesPlayerAudioTrack: true,
          audioStreamIndex: null,
          audioStreamCount: null,
        ),
      );
    });

    test('YouTube 分离流取 audio-only 那一路，播放器下标不适用', () {
      expect(
        subtitleTimingStreamSource(
          miningSource: 'https://rr1.googlevideo.com/videoplayback?itag=137',
          miningAudioSource:
              'https://rr1.googlevideo.com/videoplayback?itag=140',
        ),
        (
          url: 'https://rr1.googlevideo.com/videoplayback?itag=140',
          usesPlayerAudioTrack: false,
          audioStreamIndex: null,
          audioStreamCount: null,
        ),
      );
    });

    test('来源声明的对轴音源（转码会话的原文件直出 + 会话选的音轨）优先', () {
      const String transcodeHls =
          'https://emby.example.com/videos/1/master.m3u8?PlaySessionId=p';
      const String direct =
          'https://emby.example.com/Videos/1/stream?static=true&api_key=k';
      expect(
        subtitleTimingStreamSource(
          miningSource: transcodeHls,
          miningAudioSource: null,
          timingAudio: const RemoteVideoTimingAudio(
            url: direct,
            audioStreamIndex: 1,
            audioStreamCount: 2,
          ),
        ),
        (
          url: direct,
          usesPlayerAudioTrack: false,
          audioStreamIndex: 1,
          audioStreamCount: 2,
        ),
      );
    });

    test('本地文件 / 未解析的库内路径 / 无源都不算网络流音源', () {
      for (final String? source in <String?>[
        r'C:\videos\ep01.mkv',
        '/storage/emulated/0/Movies/ep01.mkv',
        'anime-source://kickassanime/ep-1',
        null,
      ]) {
        expect(
          subtitleTimingStreamSource(
            miningSource: source,
            miningAudioSource: null,
          ),
          isNull,
          reason: '$source',
        );
      }
    });
  });

  group('subtitleTimingStreamEndMs', () {
    const int twoHours = 2 * 60 * 60 * 1000;

    test('波形 / 自动对轴只抽探测上界那一段，不为画前 20 分钟读完整部', () {
      expect(
        subtitleTimingStreamEndMs(
          durationMs: twoHours,
          limitMs: kSubtitleAutoAlignProbeLimitMs,
        ),
        kSubtitleAutoAlignProbeLimitMs,
      );
    });

    test('片长短于上界时抽到片尾', () {
      expect(
        subtitleTimingStreamEndMs(
          durationMs: 90 * 1000,
          limitMs: kSubtitleAutoAlignProbeLimitMs,
        ),
        90 * 1000,
      );
    });

    test('不给上界（语音模型转录）抽整集', () {
      expect(subtitleTimingStreamEndMs(durationMs: twoHours), twoHours);
      expect(
        subtitleTimingStreamEndMs(durationMs: twoHours, limitMs: 0),
        twoHours,
      );
    });
  });

  // 端到端：与 `_extractStreamTimingAudio` 同一串调用——长读登记拿到 ffmpeg 输入 →
  // 带本集控制面从 0 抽当前音轨 → 喂波形包络。原点是自签 https 的 Emby 形状直出流，
  // 字节只经本机中继到 ffmpeg。
  final String? bundled = bundledFfmpegMin();
  test(
    'Emby 形状的 https 直出流：经中继抽出的音轨能画出波形包络',
    () async {
      final EmbyRelayRig rig = await EmbyRelayRig.start(bundled!);
      final String input = await relayFfmpegLongReadInput(
        rig.source,
        isHls: Future<bool>.value(false),
      );

      final List<String> failures = <String>[];
      final int endMs = subtitleTimingStreamEndMs(
        durationMs: 2000,
        limitMs: kSubtitleAutoAlignProbeLimitMs,
      );
      final String? audio = await extractAudioSegmentViaFfmpeg(
        inputPath: input,
        startMs: 0,
        endMs: endMs,
        outputPath: p.join(rig.tmp.path, 'timing.aac'),
        onFailure: failures.add,
        timeout: subtitleTimingAudioWallTimeout(endMs),
        control: newSubtitleTimingAudioControl(),
      );
      expect(
        audio,
        isNotNull,
        reason: 'ffmpeg: $failures; origin saw ${rig.seen}',
      );

      final List<double> envelope = await extractAudioEnergyEnvelope(
        videoPath: audio!,
        windowMs: kSubtitleWaveformWindowMs,
      );
      // 2 秒样本、20 ms 一帧 ≈ 100 帧；只要求覆盖到大半段，不钉编码器的首尾填充。
      expect(envelope.length, greaterThan(50));
      expect(rig.seen, isNotEmpty, reason: '字节来自 https 原点（经中继升回 https）');
      expect(
        rig.seen.every((String u) => u.contains('api_key=k')),
        isTrue,
        reason: '查询串（api_key / PlaySessionId）经中继原样送达',
      );
    },
    skip: bundled == null ? '只在带捆绑 ffmpeg-min 的平台跑（Windows / macOS）' : false,
    timeout: const Timeout(Duration(seconds: 90)),
  );

  // 页面胶水是 State 的私有方法、没有可注入的缝；与
  // `test/sync/interconnect_video_default_subtitle_test.dart` 的对轴守卫同形。
  group('源码守卫：网络流分支接在统一音源解析上', () {
    late String subtitle;
    late String mining;
    setUpAll(() {
      subtitle = File(
        'lib/src/pages/implementations/video_fushi/subtitle.part.dart',
      ).readAsStringSync();
      mining = File(
        'lib/src/pages/implementations/video_fushi/lookup_mining.part.dart',
      ).readAsStringSync();
    });

    test('入口判据认网络流音源，远端分支要求时长已知（直播流点了必然拿不到）', () {
      final String gate = methodBody(
        subtitle,
        'bool get _canResolveSubtitleTimingAudio',
      );
      expect(gate, contains('_subtitleTimingStreamSource != null'));
      final int duration = gate.indexOf('durationMs');
      expect(duration, isNonNegative);
      expect(duration, lessThan(gate.indexOf('_remoteHostVideoTarget()')));
    });

    test('媒体服务器转码会话改读来源声明的对轴地址', () {
      expect(
        methodBody(
          subtitle,
          'SubtitleTimingStream? get _subtitleTimingStreamSource',
        ),
        contains('client.timingAudio(info.id)'),
      );
    });

    test('真换集才叫停在途长读；已拿到的文件留到退页再删', () {
      final String retire = methodBody(subtitle, 'void _retireTimingAudio(');
      expect(retire, contains('_timingAudioControl.cancel()'));
      expect(
        retire,
        contains('_timingAudioControl = newSubtitleTimingAudioControl()'),
      );
      expect(
        retire,
        isNot(contains('deleteSync')),
        reason: 'ASR 弹层可能还在读上一集的音轨',
      );
      final String discard = methodBody(
        subtitle,
        'void _discardRemoteTimingAudio(',
      );
      expect(discard, contains('_retireTimingAudio()'));
      expect(discard, contains('_retiredTimingAudioFetches'));
      final String page = File(
        'lib/src/pages/implementations/video_fushi_page.dart',
      ).readAsStringSync();
      final String load = methodBody(page, 'Future<void> _loadRemoteEpisode(');
      final int gate = load.indexOf(
        'if (timingAudioEpisode != _timingAudioEpisode)',
      );
      expect(gate, isNonNegative, reason: '换画质 / 换线路不是换集');
      expect(load.indexOf('_retireTimingAudio()', gate), isNonNegative);
      expect(
        methodBody(page, 'void dispose('),
        contains('_discardRemoteTimingAudio()'),
      );
    });

    test('整集已抽过时，带上界的请求复用它', () {
      final String body = methodBody(
        subtitle,
        'Future<_SubtitleTimingAudio?> _resolveSubtitleTimingAudio(',
      );
      expect(body, contains('_remoteTimingAudioFetches.containsKey(wholeKey)'));
    });

    test('音源解析：互联 host 优先，其次网络流，截止时刻按调用方上界', () {
      final String body = methodBody(
        subtitle,
        'Future<_SubtitleTimingAudio?> _resolveSubtitleTimingAudio(',
      );
      final int host = body.indexOf('_remoteHostVideoTarget()');
      final int stream = body.indexOf('_subtitleTimingStreamSource');
      expect(host, isNonNegative);
      expect(
        stream,
        greaterThan(host),
        reason: '互联视频走 host 裁音频（TLS 钉扎 + 只回传音频），不改成本机读流',
      );
      expect(body, contains('subtitleTimingStreamEndMs('));
      expect(body, contains('_extractStreamTimingAudio('));
    });

    test('网络流抽取与制卡同一条取流路径', () {
      final String body = methodBody(
        subtitle,
        'Future<String?> _extractStreamTimingAudio(',
      );
      expect(body, contains('_ffmpegLongReadInput('));
      expect(body, contains('_streamHttpHeaderFields'));
      expect(body, contains('control: control'));
      // 分离的 googlevideo audio-only 流整段直读会被限速：与制卡同一判据先物化再
      // 抽；合流流（播放流本身）不物化，否则会把视频字节一起下满。
      final int separate = body.indexOf('!stream.usesPlayerAudioTrack &&');
      expect(separate, isNonNegative);
      expect(
        body.indexOf('audioSourceNeedsRangeMaterialization(stream.url)'),
        greaterThan(separate),
      );
      final String longRead = methodBody(
        mining,
        'Future<String> _ffmpegLongReadInput(',
      );
      expect(longRead, contains('videoMiningInputUsesPlaybackRelay('));
      expect(longRead, contains('relayFfmpegLongReadInput('));
      expect(
        methodBody(
          mining,
          'Future<MinePopupResult> _mineVideoCard({',
        ).contains('_routeFfmpegPlaybackInput(mediaSource, controller)'),
        isTrue,
        reason: '制卡与对轴音源共用同一处改道决定',
      );
      final String pageSources = Directory('lib/src/pages/implementations')
          .listSync(recursive: true)
          .whereType<File>()
          .where((File f) => f.path.endsWith('.dart'))
          .map((File f) => maskComments(f.readAsStringSync()))
          .join('\n');
      expect(
        RegExp(r'relayFfmpegRemoteInput\(').allMatches(pageSources).length,
        1,
        reason: '页面里只有 _routeFfmpegPlaybackInput 一处改走中继',
      );
    });

    test('波形与自动对轴只要探测上界那段，语音转录要整集', () {
      for (final String fn in <String>[
        'Future<int?> _autoAlignSubtitle(',
        'Future<List<double>> _loadSubtitleWaveformEnvelope(',
      ]) {
        expect(
          methodBody(subtitle, fn),
          contains('limitMs: kSubtitleAutoAlignProbeLimitMs'),
          reason: fn,
        );
      }
      expect(
        methodBody(subtitle, 'Future<String?> _transcribeVideoSpeech('),
        contains('_resolveSubtitleTimingAudio()'),
      );
    });
  });
}
