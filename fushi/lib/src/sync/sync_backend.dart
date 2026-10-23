
import 'package:fushi_engine/sync/sync_asset_store.dart';
export 'package:fushi_engine/sync/sync_backend_type.dart';


class SyncBackendError implements Exception {
  SyncBackendError(this.message, {this.isRetryable = false});
  final String message;
  final bool isRetryable;

  @override
  String toString() => 'SyncBackendError: $message';
}

/// 鉴权类失败的三种**互不相同**的语义（BUG-1323 / BUG-1348）。
///
/// 压成同一条 `SyncAuthError('Authentication failed')` 会把 [forbidden] 误报成
/// [credentials]：「服务端按策略拒绝了这次请求」被说成「登录已过期」，
/// 把用户引去反复重配一个根本没问题的凭据（BUG-1311 的用户可见症状）。
enum SyncAuthFailureKind {
  /// 凭据本身不被接受：HTTP 401、凭据未配置、OAuth 授权过期/被撤销/被拒。
  /// 可操作项 = 重新登录 / 重新填凭据。**会话已经不可用**，登出是正确反应。
  credentials,

  /// 凭据**已经被接受**，但服务端按策略拒绝了这一次请求：HTTP 403。
  /// 可操作项 = 看服务端给出的原因（如「service config 必须走 HTTPS」），
  /// **不是**去动凭据；把用户登出只会毁掉一个好端端的会话。
  forbidden,

  /// 桌面 loopback 流程里**浏览器的授权回调始终没回到 app**（等待超时）。BUG-1348：
  /// 这跟凭据毫无关系——用户可能压根没在浏览器里点完，也可能点完了但发往
  /// `http://127.0.0.1:<port>` 的回调被全局代理吞掉。可操作项 = 重试并让代理放行回环
  /// 地址，**不是**「重新登录」。
  ///
  /// 单独立一个枚举值的原因：这条错误的消息里带 "authorization" 字样，而
  /// `sync_error_messages.dart` 曾按 `contains('auth')` 猜类型，于是它被抢先判成
  /// 「登录已过期」——把「浏览器没回来」说成「凭据坏了」，把用户指向完全错误的修复
  /// 方向。判据是类型，不是字符串。
  browserTimeout,

  /// 用户在桌面 loopback 等待对话框里自己点了「取消」（BUG-2120）。既不是凭据坏了，
  /// 也不是浏览器没回来，而是**用户决定不等了**——UI 对它必须静默：不弹错误、不写
  /// 错误日志、不登出。单立枚举值的理由同 [browserTimeout]：判据是类型，不是字符串。
  cancelled,

  /// 互联（Fushi 互联）的**配对凭据被对端拒绝**：对端对本机的请求回了 401
  /// （BUG-2377）。与 [credentials] 的差别不是程度而是**凭据模型**——互联根本没有
  /// 「登录会话」这回事，凭据是配对时对端发给本机的 per-peer token。压成
  /// [credentials] 会让 UI 说「登录已过期，请重新登录」，把用户指向一个应用里
  /// **不存在**的操作；真正可操作的是重新配对。
  ///
  /// 成因基本只有一种：对端把本机从已配对列表里删了（server 端 token 缓存随即
  /// 清空，被删设备下一次请求立刻 401，见 `FushiServerController`），或对端重置/
  /// 重装后 token 换了。
  ///
  /// 与 [credentials] 的第二个差别是**不得登出**：`InterconnectSyncBackend.signOut`
  /// 会清空 `sync_hibiki_client_urls`，把全部对端地址、TOFU 指纹和 per-peer token
  /// 一并抹掉——用一台对端的 401 去清整份配对配置，正是 BUG-1550 / BUG-1578 要
  /// 消灭的株连行为。
  pairingRejected,

  /// 互联**压根没有凭据可发**：一台对端都没配对，或配对信息已被清空。既不是
  /// 「凭据被拒」（还没走到发请求那一步），也不是 [credentials] 说的「登录过期」。
  /// 可操作项 = 去「Fushi 互联」里完成配对。
  ///
  /// 此前它靠消息字面量 `'Fushi server credentials not configured'` 落进
  /// `sync_error_messages` 的 `contains('not configured')` 分支 → 返回 null →
  /// **裸英文原文直接上屏**。判据改成类型（同 [SyncPeerUnreachableError] 的教训）。
  pairingNotConfigured,

  /// 服务端对这次请求回的是一份 **HTML 网页**，而不是同步协议的响应（BUG-2631）。
  /// 三种成因长得一样：Cloudflare 一类 CDN 的人机挑战页（`Just a moment...`）、
  /// 反向代理自己的错误页、或者用户填的 URL 压根就是个网站（`https://anidb.net/anime`
  /// 当 WebDAV 地址填）。共同点是**凭据根本没被评估过**——服务端还没走到鉴权那一步，
  /// 所以既不是 [credentials]，也不该像 [forbidden] 那样说「你的登录没问题」。
  ///
  /// 单立枚举值的理由：只有它的可操作项是「换个地址 / 这不是 WebDAV 端点」；而
  /// `serverReason` 在这条上只放网页 `<title>`（读不出就为空），整页标记绝不上屏。
  htmlPage,
}

class SyncAuthError implements Exception {
  SyncAuthError(
    this.message, {
    this.kind = SyncAuthFailureKind.credentials,
    this.serverReason,
  });

  final String message;

  /// 见 [SyncAuthFailureKind]。默认 [SyncAuthFailureKind.credentials] —— 仓库里既有的
  /// 三十余处抛出点（OAuth 流程、「credentials not configured」、FTP/SFTP 协议层拒绝）
  /// 语义上全是「凭据不被接受」，故默认值让它们的行为逐字不变；只有真正
  /// 知道自己拿到 403 的抛出点才显式传 [SyncAuthFailureKind.forbidden]。
  final SyncAuthFailureKind kind;

  /// 服务端在响应体里给出的拒绝原因原文（如 `HTTPS required for service config`）。
  /// 只在服务端真的说了话时非空；`checkStatus` 以前把它整个丢掉。
  final String? serverReason;

  /// 服务端拒绝（403），而不是凭据不被接受（401）。
  bool get isForbidden => kind == SyncAuthFailureKind.forbidden;

  @override
  String toString() {
    final String? reason = serverReason;
    if (reason == null || reason.isEmpty) return 'SyncAuthError: $message';
    return 'SyncAuthError: $message ($reason)';
  }
}

abstract class SyncBackend implements SyncAssetStore {

}
