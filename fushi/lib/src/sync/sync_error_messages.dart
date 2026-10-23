import 'package:fushi/src/sync/sync_backend.dart';
import 'package:fushi/utils.dart';

/// Localized friendly clause for a known error class, or null if the error is
/// not one we recognize (caller decides the fallback).
String? _friendlyClause(Object error) {
  // BUG-1323：有类型可依的鉴权失败先按类型分派，绝不落到下面的字符串猜测区——
  // 403 的凭据是好的，不能被 'auth' 字样误捕成「登录已过期」。
  if (error is SyncAuthError && error.kind == SyncAuthFailureKind.forbidden) {
    final String? reason = error.serverReason;
    if (reason == null || reason.isEmpty) return t.sync_err_forbidden;
    return t.sync_err_forbidden_detail(reason: reason);
  }
  final String l = _rawMessage(error).toLowerCase();

  if (error is SyncAuthError ||
      l.contains('401') ||
      l.contains('unauthorized') ||
      l.contains('expired')) {
    return t.sync_err_auth_expired;
  }
  if (l.contains('timed out') ||
      l.contains('timeout') ||
      l.contains('errno = 110')) {
    return t.sync_err_timeout;
  }
  if (l.contains('socketexception') ||
      l.contains('clientexception') ||
      l.contains('handshakeexception') ||
      l.contains('failed host lookup') ||
      l.contains('connection refused') ||
      l.contains('connection closed') ||
      l.contains('connection reset') ||
      l.contains('network is unreachable')) {
    return t.sync_err_network;
  }
  return null;
}

String _rawMessage(Object error) => error is SyncBackendError
    ? error.message
    : error is SyncAuthError
        ? error.message
        : error.toString();

/// Friendly clause for embedding in another template's `message:` slot. Falls
/// back to the raw message so nothing is hidden.
String friendlySyncErrorDetail(Object error) =>
    _friendlyClause(error) ?? _rawMessage(error);
