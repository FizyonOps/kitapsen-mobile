import 'package:flutter/material.dart';
import 'package:fushi_reading/fushi_reading.dart'
    show kDefaultReadingIdleTimeout, kStudyIdleTimeoutPrefKey;
import 'package:fushi_core/fushi_core.dart';
import 'package:fushi/src/reader/reader_control_layout.dart';
// 迁移判据要用「这个存量代理地址归一得出来吗」，与 applyAppProxy 同一份实现，
// 不在这里重写一遍（重写就会漂移，而漂移的后果是存量用户升级即断网）。
import 'package:fushi_engine/utils/net/app_proxy.dart'
    show
        appUserProxyModeReader,
        appUserProxyPasswordReader,
        appUserProxyReader,
        appUserProxyUsernameReader,
        kProxyModeAuto,
        kProxyModeDirect,
        kProxyModeManual,
        normalizeUserProxyHostPort;
import 'package:fushi_engine/foundation/pref_store.dart';

class PreferencesRepository extends ChangeNotifier
    implements PrefStore {
  PreferencesRepository(this._db);

  /// TODO-855: persisted monotonic counter, the cross-process change signal the
  /// separate :popup process reads via [readPrefsVersionFromDb] to decide
  /// whether to reload its warm-reuse pref cache, instead of unconditionally
  /// re-scanning the whole preferences table on every lookup. The bump itself
  /// lives at the single lowest write choke point [FushiDatabase.setPref], so
  /// EVERY writer (this repository, ThemeNotifier, MediaSource, profile switch,
  /// sync/backup restore) advances it automatically. This is an alias to that
  /// DB-layer key so app-layer call sites (ProfileKeys, tests) share one truth.
  /// Excluded from profile snapshots (see ProfileKeys) so it stays app-global
  /// and monotonic.
  static const String prefsVersionKey = FushiDatabase.prefsVersionKey;

  final FushiDatabase _db;
  final Map<String, String> _prefCache = {};

  Future<void> loadFromDb() async {
    final all = await _db.getAllPrefs();
    _prefCache
      ..clear()
      ..addAll(all);
    // 上面那次修复写会经 setPref 抬高持久化版本号，而缓存是**在它之前**读的。
    // 不把版本重读回来，loadFromDb 一结束进程内值就比 DB 少一个，
    // 「版本不同 = 别的进程改过」于是每次启动误报一次、白重载一次。
    _prefCache[prefsVersionKey] =
        PrefCodec.encode(await readPrefsVersionFromDb());
    _installAppProxyReaders();
  }

  /// 把进程级代理读取器接到本仓库上。**绑定点必须是「偏好变得可读的那一刻」**，不是
  /// 某一个调用点：以前只有 `AppModel.initialise()` 绑，而弹窗词典进程
  /// （`AppModel.initialiseForDictionaryPopup`）同样建了本仓库、同样读了偏好，却没绑，
  /// 于是那个进程整段生命周期都落在 [kProxyModeUnresolved] 兜底上——选了「直连」的用户
  /// 在弹窗里照样走系统代理（哨兵表达不了 direct）。绑在这里，任何读得到偏好的入口都
  /// 自动拿到用户的真实选择，不必各自记得补一行。
  ///
  /// 读取器是闭包而非快照：设置页改完立刻生效，`findProxy` 请求时才求值。
  void _installAppProxyReaders() {
    appUserProxyReader = () => updateCustomProxy;
    appUserProxyModeReader = () => networkProxyMode;
    appUserProxyUsernameReader = () => networkProxyUsername;
    appUserProxyPasswordReader = () => networkProxyPassword;
  }

  Map<String, String> get prefsSnapshot =>
      Map<String, String>.unmodifiable(_prefCache);

  Future<void> refreshFromDb() async {
    await loadFromDb();
    notifyListeners();
  }

  @override
  dynamic getPref(String key, {dynamic defaultValue}) {
    final raw = _prefCache[key];
    if (raw == null) {
      return defaultValue;
    }
    return PrefCodec.decode(raw, defaultValue);
  }

  @override
  Future<void> setPref(String key, dynamic value) async {
    final String strVal = PrefCodec.encode(value);
    _prefCache[key] = strVal;
    // [FushiDatabase.setPref] also bumps the persisted prefs-version (TODO-855)
    // for any key other than the version key itself; no explicit bump needed
    // here. The in-memory [prefsVersion] getter intentionally does NOT track
    // that same-process bump — change detection is cross-process and goes
    // through [readPrefsVersionFromDb] / a full [loadFromDb] reload.
    await _db.setPref(key, strVal);
  }

  /// Read the prefs-version straight from the DB (single indexed row lookup),
  /// bypassing this process's in-memory cache. The :popup process uses this to
  /// detect that the main app mutated a preference or switched profile while the
  /// warm-reuse popup was alive, without a full preferences-table reload.
  Future<int> readPrefsVersionFromDb() async {
    final String? raw = await _db.getPref(prefsVersionKey);
    return raw == null ? 0 : PrefCodec.decode<int>(raw, 0);
  }

  bool containsKey(String key) => _prefCache.containsKey(key);

  // TODO-861②（移植 Hoshi `07b5c09`）：是否扫描非日文文本进选区/查词。默认 true =
  // 现状（注入端原硬编码 true）。关闭时选区遇非日文码点即停（见
  // reader_selection_scripts.dart 的 isDelimiter 消费端）。
  bool get scanNonJapaneseText =>
      getPref('scan_non_japanese_text', defaultValue: true) as bool;

  // ── 内容语言（内容字体链）────────────────────────────────────────────

  /// **全局默认内容语言**（BCP-47，如 `ja` / `zh-Hant`）。空串 = 未设置。
  ///
  /// 它是内容字体链优先级里的第三档，兜在资源级之后：
  /// `资源手动指定 > 内容自带元数据 > 本项 > 硬编码兜底链`（见
  /// `content_font_chain.dart` 的 [resolveContentLanguage]）。
  ///
  /// 存在的理由：前两档覆盖不全——外挂 SRT 不带语言标记、自制 EPUB 常缺
  /// `dc:language`、hook 出来的 galgame 文本更没有任何声明。逐个资源手动指定能解
  /// 决，但用户装的内容通常以某一种语言为主，给一个默认值比让他点几十次省事。
  /// 默认空串而不是 `ja`：本仓不做「内容恒为日语」这种全局假设。
  ///
  /// Kitapsen sells Turkish books, so its unset default is `tr`.
  String get defaultContentLanguage =>
      getPref('default_content_language',
              defaultValue: 'tr')
          as String;

  Future<void> setDefaultContentLanguage(String language) async {
    await setPref('default_content_language', language);
    notifyListeners();
  }

  // ── 库页排序方式（排序交互重设计 2026-07-12）──────────────────────────

  /// 书架排序方式 `.name`（recent/title/imported）。默认 recent（=历史序，现状零变化）。
  String get shelfSortModeName =>
      getPref('shelf_sort_mode', defaultValue: 'recent') as String;

  Future<void> setShelfSortModeName(String name) async {
    await setPref('shelf_sort_mode', name);
    notifyListeners();
  }

  /// 已折叠的合集横排行 collectionId 集（书架/视频页共用；折叠 = 行只剩行头）。
  /// 逗号串存储；解析对空串/脏值宽容（tryParse 过滤）。
  Set<int> get collapsedCollectionIds {
    final String raw =
        getPref('collapsed_collection_ids', defaultValue: '') as String;
    return <int>{
      for (final String part in raw.split(','))
        if (int.tryParse(part) case final int id) id,
    };
  }

  Future<void> setCollapsedCollectionIds(Set<int> ids) async {
    final List<int> sorted = ids.toList()..sort();
    await setPref('collapsed_collection_ids', sorted.join(','));
    notifyListeners();
  }

  // ── Jellyfin / Emby 媒体服务器 ───────────────────────────────────────

  // ── 实验性：键盘/手柄焦点导航 ──────────────────────────────────────────
  // 整套自定义焦点导航（FushiFocusRoot/Ring + 手柄/方向键焦点移动）默认关闭，
  // 关闭时回退到 Flutter 原生焦点遍历。空格不再确认焦点的行为不受此开关影响。

  bool get experimentalFocusNavigationEnabled =>
      getPref('experimental_focus_navigation_enabled', defaultValue: false)
          as bool;

  // ── galgame 游戏库（首页「游戏」tab）─────────────────────────────────────

  // Default OFF (smooth/animated popup scrolling). Instant (no-animation)
  // jump scrolling is an e-ink opt-in enabled only by the dedicated lookup
  // setting. getPref returns this default solely when the key was never set,
  // so existing users who already toggled the switch keep their stored value.

  bool get isFirstTimeSetup =>
      getPref('first_time_setup', defaultValue: true) as bool;

  void setFirstTimeSetupFlag() async {
    await setPref('first_time_setup', false);
  }

  /// 新手引导完成标志。缺省值刻意取 **true**：既有安装升级上来不重弹引导；
  /// 全新安装在 HomePage 的 `first_time_setup` 首帧分支里显式写 false，向导
  /// 关闭后写回 true——中途杀进程下次启动值仍是 false，会重新弹出。备份合并的
  /// insert-if-absent 天然不会覆盖本键（描述本库自身状态，同 `first_time_setup`）。
  bool get onboardingCompleted =>
      getPref('onboarding_completed', defaultValue: true) as bool;

  Future<void> setOnboardingCompleted({required bool value}) async {
    await setPref('onboarding_completed', value);
  }

  bool get reverseNavigationBar =>
      getPref('reverse_navigation_bar', defaultValue: false) as bool;

  void toggleReverseNavigationBar() async {
    await setPref('reverse_navigation_bar', !reverseNavigationBar);
    notifyListeners();
  }

  bool get reverseReaderBottomBar =>
      getPref('reverse_reader_bottom_bar', defaultValue: false) as bool;

  void toggleReverseReaderBottomBar() async {
    await setPref('reverse_reader_bottom_bar', !reverseReaderBottomBar);
    notifyListeners();
  }

  /// 阅读器顶栏 / 底栏按钮布局（与视频页同一套泛型模型，2026-09-13）。持久化键
  /// `reader_control_layout`，空 / 坏值回出厂布局。
  ReaderControlLayout get readerControlLayout => ReaderControlLayout.decode(
        getPref('reader_control_layout', defaultValue: '') as String,
      );

  // ── audio sources ────────────────────────────────────────────────────

  // ── UI visibility ────────────────────────────────────────────────────

  // ── update preferences ───────────────────────────────────────────────

  /// 全局公网出口模式：auto = 环境/系统代理自动探测；direct = 强制直连；
  /// manual = 使用 [updateCustomProxy]。旧安装没有本键时，已有手填地址自动沿用
  /// manual，否则沿用历史 auto 语义。
  String get networkProxyMode {
    final String? stored =
        getPref('network_proxy_mode', defaultValue: null) as String?;
    if (stored == kProxyModeAuto ||
        stored == kProxyModeDirect ||
        stored == kProxyModeManual) {
      return stored!;
    }
    // 迁移判据是「这个存量地址归一得出来吗」，不是「非空吗」。设置页对非法地址只
    // 弹 SnackBar 但仍存原串，非空判据会把这类值推成 manual，而 manual 归一失败
    // 时硬走 DIRECT —— 存量用户升级即断网。只有「显式选了 manual」才该 fail-closed。
    return normalizeUserProxyHostPort(updateCustomProxy) == null
        ? kProxyModeAuto
        : kProxyModeManual;
  }

  Future<void> setNetworkProxyMode(String value) async {
    final String normalized =
        value == kProxyModeDirect || value == kProxyModeManual
            ? value
            : kProxyModeAuto;
    await setPref('network_proxy_mode', normalized);
    notifyListeners();
  }

  String get networkProxyUsername =>
      getPref('network_proxy_username', defaultValue: '') as String;

  Future<void> setNetworkProxyUsername(String value) async {
    await setPref('network_proxy_username', value);
    notifyListeners();
  }

  String get networkProxyPassword =>
      getPref('network_proxy_password', defaultValue: '') as String;

  Future<void> setNetworkProxyPassword(String value) async {
    await setPref('network_proxy_password', value);
    notifyListeners();
  }

  /// 用户手填的「自定义更新代理」（`host:port`，空串=未设）。fake-ip/TUN 模式下系统
  /// 代理只写注册表、Dart HttpClient 读不到时的兜底入口（TODO-871/862）：非空时检查/下载
  /// 直接走它，优先于 env/GUI 系统代理。空串=清除（回退默认 env>GUI>DIRECT 逻辑）。
  String get updateCustomProxy =>
      getPref('update_custom_proxy', defaultValue: '') as String;

  Future<void> setUpdateCustomProxy(String value) async {
    await setPref('update_custom_proxy', value);
    notifyListeners();
  }

  // 旧版单框 Gemini 云端识别的三对 getter/setter（`manga_cloud_ocr_enabled` /
  // `manga_cloud_ocr_api_key` / `manga_cloud_ocr_model`）随 PR#474 删掉框选补扫
  // 实现后已零消费方，本轮一并清掉（BUG-1164）。
  //
  // ⚠️ 存量设备的 Drift `preferences` 行**不删**（没有迁移方案就别动持久化数据），
  // 而 `manga_cloud_ocr_api_key` 仍然留在
  // `sync/pref_redaction_policy.dart` 的 `sensitiveKeys` 里 —— 老用户库里已经写
  // 过的那个 key 必须继续被备份/Profile 快照/Profile 分享三条出境通道剔除。
  // 删代码不等于删数据，脱敏名单不能跟着删。

  // galgame 窗口超分**不再有全局偏好**（BUG-1191）。原来的
  // `galgame_magpie_upscaling_mode` 是个一刀切开关，而超分该不该开完全取决于**这个
  // 游戏**的原生分辨率：同一个人手上既有 800×600 的老 gal，也有本身就 1080p 的新作。
  // 档位已改为每游戏一档，存在 galgame 库那一行（`galgames.upscaling_mode`）。
  //
  // v63 精确删除存量 `galgame_magpie_upscaling_mode` live 行及其 pref Profile
  // 副本，不迁移到任何游戏；旧 Profile apply/JSON import 也会拒绝它复活。全局值
  // 无法映射成「每个游戏各自开不开」，新结构仍一律从关闭起步，用户按游戏自己开。

  // 下载域曾有独立的代理三态（`download_network_proxy_mode` /
  // `download_custom_proxy`），2026-08-29 合并进唯一的全局代理项
  // [updateCustomProxy]；存量行由 schema v90 迁移归并后删除，这里不再有读写器。

  // ── low memory mode (raw pref only; side effect in AppModel) ─────────

  bool get lowMemoryMode =>
      getPref('low_memory_mode', defaultValue: false) as bool;

  // ── reading goals (TODO-1046) ────────────────────────────────────────
  // Daily/weekly reading targets measured in characters. 0 = unset/off,
  // which the statistics page treats as "no goal" (goal card hidden). Read
  // and write clamped so a corrupt/out-of-range stored value can never reach
  // the progress UI as an absurd goal. Per-Profile (not excluded in
  // ProfileKeys), so each profile keeps its own targets.

  /// v90 阅读空闲门（分钟）：这么久没有翻页 / 滚动 / 查词等输入就视为没在读，
  /// 之后的时长不入账。只对阅读面（小说 / PDF / 漫画）生效，视频以播放态为准
  /// （用户拍板）。偏好键与 fushi_reading 的 [kStudyIdleTimeoutPrefKey] 同名。
  static const int readingIdleTimeoutMinutesMin = 1;
  static const int readingIdleTimeoutMinutesMax = 120;

  int get readingIdleTimeoutMinutes => (getPref(kStudyIdleTimeoutPrefKey,
          defaultValue: kDefaultReadingIdleTimeout.inMinutes) as int)
      .clamp(readingIdleTimeoutMinutesMin, readingIdleTimeoutMinutesMax);

  Future<void> setReadingIdleTimeoutMinutes(int value) async {
    await setPref(
      kStudyIdleTimeoutPrefKey,
      value.clamp(readingIdleTimeoutMinutesMin, readingIdleTimeoutMinutesMax),
    );
    notifyListeners();
  }

  /// 统计「今日」重置时刻（整点 0..23，默认 0 = 本地午夜）：写入时把 dateKey 前移
  /// 该小时数（凌晨 2 点读的书在重置 = 4 时记到「昨日」）。全局唯一入口是
  /// [FushiDatabase.statDayResetHour]，AppModel 在偏好加载后与变更时镜像过去；
  /// 历史段不重分桶（用户改设置只影响之后写入）。
  static const int statDayResetHourMin = 0;
  static const int statDayResetHourMax = 23;

  int get statDayResetHour =>
      (getPref(kStatDayResetHourPrefKey, defaultValue: 0) as int).clamp(
        statDayResetHourMin,
        statDayResetHourMax,
      );

  Future<void> setStatDayResetHour(int value) async {
    await setPref(
      kStatDayResetHourPrefKey,
      value.clamp(statDayResetHourMin, statDayResetHourMax),
    );
    notifyListeners();
  }

  int get readingGoalDailyChars =>
      (getPref('reading_goal_daily_chars', defaultValue: 0) as int)
          .clamp(0, 1000000);

  Future<void> setReadingGoalDailyChars(int value) async {
    await setPref('reading_goal_daily_chars', value.clamp(0, 1000000));
    notifyListeners();
  }

  int get readingGoalWeeklyChars =>
      (getPref('reading_goal_weekly_chars', defaultValue: 0) as int)
          .clamp(0, 10000000);

  Future<void> setReadingGoalWeeklyChars(int value) async {
    await setPref('reading_goal_weekly_chars', value.clamp(0, 10000000));
    notifyListeners();
  }
}
