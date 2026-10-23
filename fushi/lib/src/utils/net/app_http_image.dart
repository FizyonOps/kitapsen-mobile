import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:http/http.dart' as http;

import 'package:fushi_engine/utils/net/app_http.dart';
import 'package:fushi/src/utils/net/transient_fetch_retry.dart';

/// 磁盘缓存图片只替换 HTTP 装配，保留原 provider 的 key、缩放及错误语义。
class AppCachedHttpImage extends CachedNetworkImageProvider {
  AppCachedHttpImage(
    super.url, {
    super.scale,
    super.headers,
    super.cacheKey,
    super.maxWidth,
    super.maxHeight,
    super.errorListener,
  }) : super(cacheManager: AppImageCacheManager());
}

/// 与原默认缓存共享磁盘命名空间，已有封面无需重新下载。
class AppImageCacheManager extends CacheManager with ImageCacheManager {
  AppImageCacheManager._()
      : super(
          Config(DefaultCacheManager.key, fileService: AppImageFileService()),
        );

  static final AppImageCacheManager _instance = AppImageCacheManager._();

  factory AppImageCacheManager() => _instance;
}

/// 磁盘缓存图片的首响应 / 正文空闲超时（BUG-2450）。
///
/// 出站客户端只有 20s 的 TCP connect 超时：连上之后服务端不吐响应头、或正文
/// 中途断流，请求会永远挂着——既到不了失败态、也轮不到退避重试。空闲超时按
/// 数据块重置，慢但仍在持续返回数据的大图不会被整包倒数切断。
const Duration kAppImageHeaderTimeout = Duration(seconds: 60);
const Duration kAppImageIdleTimeout = Duration(seconds: 60);

/// 每次缓存缺失/更新都重新装配客户端，代理与认证的设置变更立即生效。
///
/// 超时 / socket 错误 / 5xx 按 [retryBackoff] 自动退避重试（`retryTransient`）；
/// 4xx 与其它结构性错误照旧一次交给 CacheManager 落到 errorBuilder。
class AppImageFileService extends FileService {
  AppImageFileService({
    this.retryBackoff = kCoverFetchRetryBackoff,
    this.retryWait = retryWaitReal,
  });

  final List<Duration> retryBackoff;
  final RetryWait retryWait;

  @override
  Future<FileServiceResponse> get(
    String url, {
    Map<String, String>? headers,
  }) =>
      retryTransient<FileServiceResponse>(
        () => _getOnce(url, headers: headers),
        backoff: retryBackoff,
        wait: retryWait,
      );

  Future<FileServiceResponse> _getOnce(
    String url, {
    Map<String, String>? headers,
  }) async {
    final http.Client client = createAppHttpIoClient();
    try {
      final http.Request request = http.Request('GET', Uri.parse(url));
      if (headers != null) request.headers.addAll(headers);
      final http.StreamedResponse response =
          await client.send(request).timeout(kAppImageHeaderTimeout);
      // CacheManager 仅消费 200/202 正文，304 与错误响应须主动释放连接。
      final bool hasImage =
          response.statusCode == 200 || response.statusCode == 202;
      if (!hasImage) {
        await response.stream.listen(null).cancel();
        client.close();
        if (response.statusCode >= 500) {
          // 5xx 是瞬时故障：抛给退避层重试。梯度耗尽后仍以 CacheManager 自己
          // 对非 2xx 响应抛的同一异常类型落到 errorBuilder，调用方语义不变。
          throw HttpExceptionWithStatus(
            response.statusCode,
            'Invalid statusCode: ${response.statusCode}',
            uri: request.url,
          );
        }
      }
      return HttpGetResponse(
        http.StreamedResponse(
          hasImage
              ? _closeAfter(
                  response.stream.timeout(kAppImageIdleTimeout), client)
              : const Stream<List<int>>.empty(),
          response.statusCode,
          headers: response.headers,
          contentLength: response.contentLength,
          request: response.request,
          reasonPhrase: response.reasonPhrase,
          isRedirect: response.isRedirect,
          persistentConnection: response.persistentConnection,
        ),
      );
    } catch (_) {
      client.close();
      rethrow;
    }
  }

  Stream<List<int>> _closeAfter(
    Stream<List<int>> bytes,
    http.Client client,
  ) async* {
    try {
      yield* bytes;
    } finally {
      client.close();
    }
  }
}
