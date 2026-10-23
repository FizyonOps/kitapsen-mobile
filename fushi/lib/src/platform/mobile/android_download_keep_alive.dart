/// 互联下载保活的唯一 Dart 门面。
///
/// 互联下载（手机从已配对电脑拉视频）跑在主 isolate 里，没有原生组件托底；
/// 用户切走后 Android 随时可能杀进程，下载随之中断。Android 上本门面驱动原生
/// `DownloadKeepAliveService.java`（dataSync 前台服务 + 常驻进度通知）把进程
/// 保活到下载结束；其余平台是 no-op。
///
/// 方法名与参数名（`update` / `stop`，`title` / `text` / `progress`）是跨语言
/// 契约，改一边必须改另一边。
///
/// **调用纪律**：第一次 [DownloadKeepAlive.update] 必须发生在 app 前台（用户点
/// 下载那一刻）——Android 12+ 不允许后台拉起前台服务，原生侧会拒绝并只记日志。
/// 服务起来之后的进度更新在后台也安全（原生侧直接改通知，不再拉起服务）。
/// 所有下载结束（完成 / 失败 / 取消）后必须 [DownloadKeepAlive.stop]。
library;

import 'dart:async';

/// 下载保活门面。
abstract interface class DownloadKeepAlive {
  /// 开始（尚未保活时）或更新保活通知。[percent] 为 null / 越界时显示不确定进度。
  Future<void> update({
    required String title,
    required String text,
    int? percent,
  });

  /// 结束保活并移除通知。未在保活时是 no-op。
  Future<void> stop();
}

/// 按平台选实现：只有 Android 有原生侧，其余平台一律 no-op。
DownloadKeepAlive createDownloadKeepAlive() {
  return const NoopDownloadKeepAlive();
}

/// 非 Android 平台的实现：什么也不做，也不发任何通道调用。
class NoopDownloadKeepAlive implements DownloadKeepAlive {
  const NoopDownloadKeepAlive();

  @override
  Future<void> update({
    required String title,
    required String text,
    int? percent,
  }) async {}

  @override
  Future<void> stop() async {}
}
