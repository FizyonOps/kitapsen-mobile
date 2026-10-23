import 'package:fushi/src/sync/sync_repository.dart';

/// 「一条 `preferences` key 能不能进 Profile 快照」的唯一判定：凭据与设备本地
/// key 一律不进（[ProfileKeys.isExcludedPref] 调用）。
abstract class PrefRedactionPolicy {
  /// 形状兜底：key 含这些子串即视为凭据，**不限前缀**。
  static const List<String> credentialSubstrings = <String>[
    'password',
    'token',
    'secret',
    'private_key',
    'credential',
    'api_key',
  ];

  /// 名字看不出是凭据、但值里裹着凭据的 key——必须逐个点名。
  static const Set<String> sensitiveKeys = <String>{
    // 手动 HTTP 代理登录名；密码由 `password` 形状兜底命中。
    'network_proxy_username',
  };

  /// key 是否属于「设备本地 / 凭据」。判定顺序（任一命中即 true）：
  /// 1. [SyncRepository.deviceLocalPrefKeys] 白名单；
  /// 2. [sensitiveKeys] 点名；
  /// 3. [credentialSubstrings] 形状兜底——将来新增的凭据 key 也先拦下来。
  static bool isDeviceLocalOrCredential(String key) {
    if (SyncRepository.deviceLocalPrefKeys.contains(key)) return true;
    if (sensitiveKeys.contains(key)) return true;
    final String lower = key.toLowerCase();
    for (final String substring in credentialSubstrings) {
      if (lower.contains(substring)) return true;
    }
    return false;
  }
}
