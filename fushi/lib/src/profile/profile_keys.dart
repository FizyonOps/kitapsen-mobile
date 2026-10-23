
import 'package:fushi_core/fushi_core.dart' show kStatLegacyProfileIdPrefKey;

import 'package:fushi_engine/media/override_title_key.dart';
import 'package:fushi_engine/profile/profile_document.dart'
    show kProfileSettingCategoryPref;
import 'package:fushi/src/models/preferences_repository.dart';
import 'package:fushi/src/sync/pref_redaction_policy.dart';

abstract class ProfileKeys {

  static const String categoryPref = kProfileSettingCategoryPref;

  // Legacy category (pre-v2 snapshots stored reader prefs separately)
  static const String categoryReader = 'reader';

  static final Set<String> _excludedPrefKeys = <String>{
    'active_profile_id',
    // v105 统计按 Profile 隔离：legacy 统计家族归属哪个 Profile 是**本库**的
    // 事实（值是本库自增 id），与 active_profile_id 同族。进快照就会被别的
    // Profile 的 applyProfile 剪掉，legacy 历史随即对所有 Profile 可见。
    kStatLegacyProfileIdPrefKey,
    'first_time_setup',
    // 新手引导完成标志与 first_time_setup 同族：描述本安装的状态，不随 Profile 切换。
    'onboarding_completed',
    'app_ui_scale',
    'app_ui_scale_mode',
    'app_locale',
    // E-ink mode describes the physical display the app is running on (same
    // family as app_ui_scale), never a per-profile reading preference —
    // snapshotting it would flip the whole app's colors on profile switch.
    'eink_mode',
    // The app-wide network proxy (TODO-871; the only proxy setting since the
    // download-specific mode was folded into it) describes this device's
    // network, not a reading profile — never per-profile snapshot.
    'update_custom_proxy',
    // BUG-1980 同族：出口模式（自动/直连/手动）描述的是这台设备的网络，地址已经是
    // 设备本地的，模式却跟着 Profile 走 = 切一次 Profile 就把全局网络出口翻掉，
    // 事后极难归因。
    'network_proxy_mode',
    // TODO-855: the monotonic prefs-version counter is the cross-process signal
    // the :popup process reads to decide whether to refresh its warm-reuse
    // pref cache. It must stay app-global and monotonic — snapshotting it
    // into a profile (and restoring/wiping it on profile switch) would make
    // the counter non-monotonic and break change detection.
    PreferencesRepository.prefsVersionKey,
  };

  static const List<String> _excludedPrefPrefixes = [
    'current_source/',
  ];

  /// BUG-1018 (A4): per-item display-name overrides are CONTENT tied to a
  /// media item, not reading preferences. Their persisted form is
  /// `src:<sourceId>:override_title://<mediaIdentifier>` since BUG-1317
  /// (previously `src:<sourceId>:override_title://<sourceId>/<uniqueKey>`; both
  /// shapes coexist until the read-time fallback migrates the legacy rows — see
  /// [MediaSource.getOverrideTitleKey] + `dbSourcePrefKey`), so the marker is
  /// matched as a substring — it covers both shapes, and excluding them from
  /// profile snapshots keeps a rename visible across profile switches instead
  /// of being pruned/reverted.
  ///
  /// BUG-1488：前缀字面量收敛到 [kOverrideTitleKeyMarker] 单点——同一批 key 现在
  /// 还被互联 host 清单、备份导出谓词、备份合并导入认作「内容」，四处各写一份
  /// 字符串迟早漂开。
  static const String _overrideTitleMarker = kOverrideTitleKeyMarker;

  static bool isExcludedPref(String key) {
    // 凭据 / 设备本地 key 绝不进 Profile 快照（[PrefRedactionPolicy] 是这条判定
    // 的唯一真相源，与备份导出、Profile 分享 JSON 共用）。
    //
    // 这里此前完全没有凭据判定，造成两个独立缺陷：
    // 1. 泄漏：`snapshotCurrentSettings` 把全部 prefs（含 WebDAV/SFTP 密码、
    //    OAuth refresh token、API key）复制进 `profile_settings`，而备份导出只
    //    DELETE `preferences` —— 凭据以另一张表原样出境。
    // 2. 串号：`applyProfile` 会用快照覆盖当前 prefs，于是切换 Profile 会把
    //    A Profile 快照里的同步凭据写进 B Profile。这些 key 按定义是**设备
    //    本地**的（见 [SyncRepository.deviceLocalPrefKeys] 的命名与文档），本来
    //    就不该跟着 Profile 走。
    //
    // 放在 isExcludedPref 里而不是各调用点，是因为快照的写（snapshot）、读
    // （apply 的 restore map）与剪枝（apply 的 prune loop）三处已经全部走这个
    // 谓词：一处收敛即三处生效，且 prune 不再删除凭据行 —— 切 Profile 时本机
    // 凭据原样留存，正是想要的行为。存量快照里已有的凭据行由读侧过滤失效，
    // 无需 schema 迁移；导出副本里的那份由 `_stripCredentials` 删除。
    if (PrefRedactionPolicy.isDeviceLocalOrCredential(key)) return true;
    if (_excludedPrefKeys.contains(key)) return true;
    for (final prefix in _excludedPrefPrefixes) {
      if (key.startsWith(prefix)) return true;
    }
    if (key.contains(_overrideTitleMarker)) return true;
    return false;
  }

}
