import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fushi_engine/media/video/ffmpeg_backend.dart';
import 'package:fushi_engine/utils/misc/desktop_audio_clipper.dart';
import 'package:path/path.dart' as p;

import '../../helpers/emby_relay_rig.dart';

/// BUG-2957：字幕对轴从网络流抽前 20 分钟 / 整集音轨，是一次几十分钟级的 ffmpeg 读流。
/// 桌面 CLI 后端必须能被叫停（换集 / 退页），并按「无进展」而不是按片长估的壁钟判
/// 超时。这里用真捆绑 ffmpeg 读一个**发完响应头就再不给字节**的本机原点——正是源站
/// 断流 / 限速到零时 ffmpeg 看到的样子。
void main() {
  final String? bundled = bundledFfmpegMin();

  Future<String> stalledOrigin() async {
    final HttpServer server = await HttpServer.bind(
      InternetAddress.loopbackIPv4,
      0,
    );
    // force：连同挂着的连接一起断开。
    addTearDown(() => server.close(force: true));
    server.listen((HttpRequest request) {
      final HttpResponse res = request.response;
      res.headers.contentType = ContentType('video', 'mp4');
      res.contentLength = 50 * 1024 * 1024;
      // 只发头：ffmpeg 打开输入后在读第一个字节处永远等下去。
      res.flush().ignore();
    });
    return 'http://127.0.0.1:${server.port}/stream.mp4';
  }

  Future<FfmpegRunResult> run(
    String input,
    String output,
    FfmpegRunControl control,
  ) {
    return runFfmpegProcess(
      bundled!,
      buildFfmpegClipArgs(
        inputPath: input,
        startMs: 0,
        endMs: 20 * 60 * 1000,
        outputPath: output,
      ),
      const Duration(minutes: 10),
      control: control,
    );
  }

  test(
    '原点不再给字节：按 stallTimeout 判失败，不等壁钟时限',
    () async {
      final Directory tmp = Directory.systemTemp.createTempSync('ff_stall_');
      addTearDown(() => tmp.deleteSync(recursive: true));
      final Stopwatch watch = Stopwatch()..start();
      final FfmpegRunResult result = await run(
        await stalledOrigin(),
        p.join(tmp.path, 'out.aac'),
        FfmpegRunControl(stallTimeout: const Duration(seconds: 3)),
      );
      expect(result.returnCode, isNull);
      expect(result.output, contains('stalled'));
      expect(watch.elapsed, lessThan(const Duration(seconds: 30)));
    },
    skip: bundled == null ? '只在带捆绑 ffmpeg-min 的平台跑（Windows / macOS）' : false,
    timeout: const Timeout(Duration(seconds: 90)),
  );

  test(
    '叫停：在途的读流立即被杀，结果写明 cancelled',
    () async {
      final Directory tmp = Directory.systemTemp.createTempSync('ff_cancel_');
      addTearDown(() => tmp.deleteSync(recursive: true));
      final FfmpegRunControl control = FfmpegRunControl();
      final Future<FfmpegRunResult> pending = run(
        await stalledOrigin(),
        p.join(tmp.path, 'out.aac'),
        control,
      );
      await Future<void>.delayed(const Duration(seconds: 1));
      final Stopwatch watch = Stopwatch()..start();
      control.cancel();
      final FfmpegRunResult result = await pending;
      expect(result.returnCode, isNull);
      expect(result.output, contains('cancelled'));
      expect(watch.elapsed, lessThan(const Duration(seconds: 10)));
    },
    skip: bundled == null ? '只在带捆绑 ffmpeg-min 的平台跑（Windows / macOS）' : false,
    timeout: const Timeout(Duration(seconds: 90)),
  );

  test(
    '读到一半卡住：ffmpeg 7 照打 time 不变的进度行，也照样判 stalled',
    () async {
      final Directory tmp = Directory.systemTemp.createTempSync('ff_mid_');
      addTearDown(() => tmp.deleteSync(recursive: true));
      // 一条约 10 分钟的真 TS（2 秒样本循环拼接，约 9 MB——必须大于 ffmpeg 的探测
      // 窗口，否则它停在打开阶段，测到的只是「打开时卡住」）。原点只发前 60%、声称
      // 后面还有，然后再不给字节：ffmpeg 转出六分钟左右后卡在读下一块上，调度循环
      // 继续按 stats_period 打 time 不变的行（实测 n7.1.5：time 冻结、speed 递减）。
      final String ts = p.join(tmp.path, 'seg.ts');
      final ProcessResult mux = await Process.run(bundled!, <String>[
        '-hide_banner',
        '-loglevel',
        'error',
        '-y',
        '-stream_loop',
        '300',
        '-i',
        p.join('..', 'docs', 'todo-524-video.mp4'),
        '-c',
        'copy',
        '-f',
        'mpegts',
        ts,
      ]);
      expect(mux.exitCode, 0, reason: '${mux.stderr}');
      final List<int> segment = File(ts).readAsBytesSync();
      final HttpServer server = await HttpServer.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      addTearDown(() => server.close(force: true));
      server.listen((HttpRequest request) {
        final HttpResponse res = request.response;
        res.headers.contentType = ContentType('video', 'mp2t');
        res.contentLength = segment.length * 2;
        res.add(segment.sublist(0, segment.length * 6 ~/ 10));
        res.flush().ignore();
      });
      final Stopwatch watch = Stopwatch()..start();
      final FfmpegRunResult result = await run(
        'http://127.0.0.1:${server.port}/live.ts',
        p.join(tmp.path, 'out.aac'),
        FfmpegRunControl(stallTimeout: const Duration(seconds: 3)),
      );
      expect(result.returnCode, isNull);
      expect(result.output, contains('stalled'));
      expect(watch.elapsed, lessThan(const Duration(seconds: 30)));
    },
    skip: bundled == null ? '只在带捆绑 ffmpeg-min 的平台跑（Windows / macOS）' : false,
    timeout: const Timeout(Duration(seconds: 90)),
  );

  group('FfmpegProgressWatch', () {
    test('非统计行（banner / 流信息 / 警告）都算前进', () {
      final FfmpegProgressWatch watch = FfmpegProgressWatch();
      expect(watch.feed('ffmpeg version n7.1.5\n'), isTrue);
      expect(watch.feed("Input #0, mpegts, from 'x':\n"), isTrue);
    });

    test('统计行只有 time 变了才算前进', () {
      final FfmpegProgressWatch watch = FfmpegProgressWatch();
      expect(
        watch.feed('size=     256KiB time=00:00:16.27 bitrate= 128k speed=32x\r'),
        isTrue,
      );
      expect(
        watch.feed('size=     256KiB time=00:00:16.27 bitrate= 128k speed=N/A\r'),
        isFalse,
        reason: 'ffmpeg 7 读流卡住时照打的行',
      );
      expect(
        watch.feed('size=     260KiB time=00:00:16.80 bitrate= 128k speed=31x\r'),
        isTrue,
      );
    });

    test('跨块的半行拼上再判', () {
      final FfmpegProgressWatch watch = FfmpegProgressWatch();
      expect(watch.feed('size=  1KiB time=00:00:01.00 speed=1x\r'), isTrue);
      expect(watch.feed('size=  1KiB ti'), isFalse, reason: '半行先不判');
      expect(watch.feed('me=00:00:01.00 speed=1x\r'), isFalse);
      expect(watch.feed('size=  2KiB time=00:00:02.00 speed=1x\r'), isTrue);
    });
  });

  test('已叫停的控制面不再起进程', () async {
    final FfmpegRunResult result = await runFfmpegProcess(
      // 不存在的可执行：若真去起进程会抛 ProcessException。
      p.join(Directory.systemTemp.path, 'no-such-ffmpeg-bug-2957'),
      const <String>['-version'],
      const Duration(seconds: 5),
      control: FfmpegRunControl()..cancel(),
    );
    expect(result.returnCode, isNull);
    expect(result.output, contains('cancelled'));
  });
}
