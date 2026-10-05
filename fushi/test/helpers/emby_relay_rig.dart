import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fushi/src/utils/net/app_native_proxy.dart';
import 'package:fushi/src/utils/net/ffmpeg_relay_route.dart';
import 'package:fushi_engine/media/video/ffmpeg_backend.dart';
import 'package:fushi_engine/sync/tls/fushi_tls_identity.dart';
import 'package:fushi_engine/utils/misc/desktop_audio_clipper.dart';
import 'package:fushi_engine/utils/net/app_http.dart';
import 'package:fushi_engine/utils/net/app_proxy.dart';
import 'package:path/path.dart' as p;

/// Emby 直出流的 URL 形状（`/Videos/{id}/stream?static=true&…&api_key=`）。
const String kEmbyStreamUrl =
    'https://emby.example.com/Videos/136641/stream?static=true'
    '&MediaSourceId=mediasource_136641&PlaySessionId=p&DeviceId=d&api_key=k';

/// 本仓捆绑的 ffmpeg-min（Windows / macOS 才有）；没有时返回 null，调用方据此 skip。
String? bundledFfmpegMin() {
  final String? rel = Platform.isWindows
      ? p.join('..', 'third_party', 'ffmpeg-min', 'windows', 'ffmpeg.exe')
      : Platform.isMacOS
      ? p.join('..', 'third_party', 'ffmpeg-min', 'macos', 'ffmpeg')
      : null;
  if (rel == null) return null;
  return File(rel).existsSync() ? File(rel).absolute.path : null;
}

/// 端到端环境：真捆绑 ffmpeg-min + 真本机中继 + 自签 https 的 Emby 形状原点
/// （mp4 整文件 + Range）。ffmpeg 拿到的是中继的明文形式、只经 `-http_proxy` 取字节，
/// TLS 全由中继做——与播放器同一条路径（BUG-2692 制卡、BUG-2957 字幕对轴音源共用）。
///
/// 必须在 `test()` 体内调用：全局装配点的还原与原点关闭都挂在 [addTearDown] 上。
class EmbyRelayRig {
  EmbyRelayRig._(this.source, this.seen, this.tmp);

  /// 指向本机原点的 Emby 形状 https 地址（尚未改走中继）。
  final String source;

  /// 原点收到的每个请求 URI（断言字节确实来自原点、查询串原样送达）。
  final List<String> seen;

  /// 本次测试的临时目录，测试结束自动删除。
  final Directory tmp;

  static Future<EmbyRelayRig> start(String bundledFfmpeg) async {
    final Directory tmp = Directory.systemTemp.createTempSync('emby_relay_');
    final String? oldOverride = ffmpegPathOverride;
    final String? oldProbeOverride = ffprobePathOverride;
    final String Function() oldMode = appUserProxyModeReader;
    final HttpClient Function() oldFactory =
        appNativeProxyUpstreamClientFactory;
    addTearDown(() {
      tmp.deleteSync(recursive: true);
      ffmpegPathOverride = oldOverride;
      ffprobePathOverride = oldProbeOverride;
      setFfmpegBackendForTesting(null);
      debugResetFfmpegHlsSegmentExtensionSupport();
      ffmpegRemoteInputRouteResolver = null;
      debugClearFfmpegRelayRoutes();
      appUserProxyModeReader = oldMode;
      appNativeProxyUpstreamClientFactory = oldFactory;
      clearPinnedNativeOriginsForTesting();
    });
    ffmpegPathOverride = bundledFfmpeg;
    ffprobePathOverride = p.join(
      p.dirname(bundledFfmpeg),
      Platform.isWindows ? 'ffprobe.exe' : 'ffprobe',
    );
    setFfmpegBackendForTesting(null);
    debugResetFfmpegHlsSegmentExtensionSupport();
    appUserProxyModeReader = () => kProxyModeDirect;

    final List<int> video = File(
      p.join('..', 'docs', 'todo-524-video.mp4'),
    ).readAsBytesSync();
    final ({String certificatePem, String privateKeyPem}) cert =
        FushiSelfSignedCertGenerator.generate(
          commonName: 'fushi-test',
          sanIpAddresses: <String>['127.0.0.1'],
        );
    final SecurityContext ctx = SecurityContext()
      ..useCertificateChainBytes(cert.certificatePem.codeUnits)
      ..usePrivateKeyBytes(cert.privateKeyPem.codeUnits);
    final HttpServer origin = await HttpServer.bindSecure(
      InternetAddress.loopbackIPv4,
      0,
      ctx,
    );
    addTearDown(() => origin.close(force: true));
    final List<String> seen = <String>[];
    origin.listen((HttpRequest request) async {
      final HttpResponse res = request.response;
      seen.add(request.uri.toString());
      if (request.uri.path != '/Videos/136641/stream' ||
          request.uri.queryParameters['api_key'] != 'k') {
        res.statusCode = HttpStatus.unauthorized;
        await res.close();
        return;
      }
      res.headers.contentType = ContentType('video', 'mp4');
      res.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
      final String? range = request.headers.value(HttpHeaders.rangeHeader);
      final RegExpMatch? m = range == null
          ? null
          : RegExp(r'bytes=(\d+)-(\d*)').firstMatch(range);
      if (m == null) {
        res.contentLength = video.length;
        res.add(video);
      } else {
        final int start = int.parse(m.group(1)!);
        final int end = m.group(2)!.isEmpty
            ? video.length - 1
            : int.parse(m.group(2)!);
        res.statusCode = HttpStatus.partialContent;
        res.headers.set(
          HttpHeaders.contentRangeHeader,
          'bytes $start-$end/${video.length}',
        );
        res.contentLength = end - start + 1;
        res.add(video.sublist(start, end + 1));
      }
      await res.close();
    });
    // 系统信任根不认测试自签证书：测试里换成信任它的客户端；生产走默认工厂。
    appNativeProxyUpstreamClientFactory = () =>
        createAppHttpClient()
          ..badCertificateCallback = (X509Certificate _, String __, int ___) =>
              true;
    ffmpegRemoteInputRouteResolver = ffmpegRelayRouteFor;

    return EmbyRelayRig._(
      kEmbyStreamUrl.replaceFirst(
        'emby.example.com',
        '127.0.0.1:${origin.port}',
      ),
      seen,
      tmp,
    );
  }
}
