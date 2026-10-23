/// Kitapsen 服务端请求失败（非鉴权类）：响应缺字段、HTTP 非 2xx 等。
class SyncBackendError implements Exception {
  SyncBackendError(this.message);
  final String message;

  @override
  String toString() => 'SyncBackendError: $message';
}

/// 鉴权类失败的两种**互不相同**的语义（BUG-1323）。
///
/// 压成同一条 `SyncAuthError('Authentication failed')` 会把 [forbidden] 误报成
/// [credentials]：「服务端按策略拒绝了这次请求」被说成「登录已过期」，
/// 把用户引去反复重配一个根本没问题的凭据（BUG-1311 的用户可见症状）。
enum SyncAuthFailureKind {
  /// 凭据本身不被接受：HTTP 401、授权过期/被撤销/被拒。
  /// 可操作项 = 重新登录。**会话已经不可用**，登出是正确反应。
  credentials,

  /// 凭据**已经被接受**，但服务端按策略拒绝了这一次请求：HTTP 403。
  /// 可操作项 = 看服务端给出的原因，**不是**去动凭据；把用户登出只会毁掉一个
  /// 好端端的会话。
  forbidden,
}

class SyncAuthError implements Exception {
  SyncAuthError(
    this.message, {
    this.kind = SyncAuthFailureKind.credentials,
    this.serverReason,
  });

  final String message;

  /// 见 [SyncAuthFailureKind]。默认 [SyncAuthFailureKind.credentials]；只有真正
  /// 知道自己拿到 403 的抛出点才显式传 [SyncAuthFailureKind.forbidden]。
  final SyncAuthFailureKind kind;

  /// 服务端在响应体里给出的拒绝原因原文。只在服务端真的说了话时非空。
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
