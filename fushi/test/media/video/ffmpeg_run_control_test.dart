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
