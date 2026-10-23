import 'package:flutter/material.dart';
import 'package:fushi_audio/fushi_audio.dart'
    show kDefaultReadingIdleTimeout, kStudyIdleTimeoutPrefKey;
import 'package:fushi_core/fushi_core.dart';
import 'package:fushi/src/models/module_id.dart';
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
import 'package:fushi/src/models/audio_source_config.dart';
import 'package:fushi_engine/foundation/pref_store.dart';

/// 视频画面缩放/比例模式（作用于 Flutter 层 [Video] widget 的 [BoxFit]，TODO-152 子B）。
///
/// 与 mpv 内置几何（`video_setting_mpv_aspect`/`zoom`/`panscan`）是两个不同层：这里只决定
/// 解码后的画面如何映射进媒体框，不改 mpv 渲染管线。窗口模式与全屏路由共用本偏好。
/// - [cover]：保持比例铺满媒体框、超出部分裁切（无 letterbox/pillarbox 黑边）。
/// - [contain]：默认。保持比例完整显示，比例不匹配时上下/左右补黑边（画面缩窄时
///   加黑，即用户要的「适应」）。
/// - [fill]：拉伸填满整个媒体框、不保持比例（变形）。
enum VideoFitMode {
  cover('cover'),
  contain('contain'),
  fill('fill');

  const VideoFitMode(this.storageValue);

  final String storageValue;

  static VideoFitMode fromStorage(String value) {
    for (final VideoFitMode mode in VideoFitMode.values) {
      if (mode.storageValue == value) return mode;
    }
    return VideoFitMode.contain;
  }
}

/// 「新下载任务交给哪台互联 host 执行」的偏好键（空 = 本机）。
/// 设备本地（见 `SyncRepository.deviceLocalPrefKeys`）。
const String kDownloadExecutionHostPrefKey = 'download_execution_host';

/// 主机侧「允许已配对设备从游戏库远程启动游戏并串流」。默认关：开启即允许配对
/// 设备在本机起进程。设备本地（见 `SyncRepository.deviceLocalPrefKeys`），不能随
/// 备份把这扇门带到另一台电脑上。
const String kGameStreamRemoteLaunchPrefKey = 'game_stream_remote_launch';

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

  /// The prefs-version value currently held in this process's in-memory cache,
  /// as last populated by [loadFromDb]/[refreshFromDb] (0 when never loaded).
  /// Cheap synchronous read; NOT a cross-process check and NOT advanced by this
  /// process's own [setPref] calls (the bump is sunk into the DB layer and only
  /// re-enters the cache on the next full reload). [AppModel] uses it solely to
  /// prime its watermark right after a reload; live change detection goes
  /// through [readPrefsVersionFromDb]. Stored as a PrefCodec int, so
  /// [PrefCodec.decode] tolerates both the tagged (`i:N`) and legacy raw (`N`)
  /// form.
  int get prefsVersion {
    final String? raw = _prefCache[prefsVersionKey];
    return raw == null ? 0 : PrefCodec.decode<int>(raw, 0);
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

  /// 多端库联合视图（spec 2026-07-12 §2.1/§2.4）：书架/视频页主网格是否把「远端有、
  /// 本地无」的条目渲染成占位卡（云角标 + 远端封面，点击下载/流播）。**默认 true**——
  /// 用户拍板远端混排默认开。关闭时占位卡全部不渲染，两页只剩本地库。离线/未配对/
  /// 后端不可达时占位卡本就不出现（远端目录拉取失败态），与本开关正交。
  bool get showRemoteEntries =>
      getPref('show_remote_entries', defaultValue: true) as bool;

  // ── Jellyfin / Emby 媒体服务器 ───────────────────────────────────────

  // ── 实验性：键盘/手柄焦点导航 ──────────────────────────────────────────
  // 整套自定义焦点导航（FushiFocusRoot/Ring + 手柄/方向键焦点移动）默认关闭，
  // 关闭时回退到 Flutter 原生焦点遍历。空格不再确认焦点的行为不受此开关影响。

  bool get experimentalFocusNavigationEnabled =>
      getPref('experimental_focus_navigation_enabled', defaultValue: false)
          as bool;

  // ── galgame 游戏库（首页「游戏」tab）─────────────────────────────────────

  Future<void> setFloatingBallInApp(bool value) async {
    await setPref('floating_ball.in_app', value);
    notifyListeners();
  }

  void setDictionaryFontSize(double fontSize) async {
    await setPref('dictionary_entry_font_size', fontSize);
    notifyListeners();
  }

  // Default OFF (smooth/animated popup scrolling). Instant (no-animation)
  // jump scrolling is an e-ink opt-in enabled only by the dedicated lookup
  // setting. getPref returns this default solely when the key was never set,
  // so existing users who already toggled the switch keep their stored value.
  bool get popupInstantScroll =>
      getPref('popup_instant_scroll', defaultValue: false) as bool;

  bool get isFirstTimeSetup =>
      getPref('first_time_setup', defaultValue: true) as bool;

  void setFirstTimeSetupFlag() async {
    await setPref('first_time_setup', false);
  }

  /// 「功能模块」显隐：用户意愿的**唯一存储**，一个 [ModuleId] 一个键。
  ///
  /// 默认全开（与旧版行为一致）；新手引导的功能选择与 设置 → 外观 → 功能模块
  /// 写同一真值。games（Windows）与浏览器扩展（桌面）的平台门控**不在这里**——
  /// 这里只存用户意愿，平台判据统一在 [ModuleId.availableOn] 判一次，合成见
  /// [ModuleVisibility.resolve]。首页/设置恒在，是全部关闭后的安全回退面，
  /// 没有对应 [ModuleId]。
  ///
  /// 此前这里是七对手写 getter/setter（22 行/模块），加一个模块要在 prefs /
  /// AppModel / 设置 schema / 引导 / 底栏 / macOS 侧栏各抄一遍，少抄一处就静默
  /// 漏一处门控。现在读写都走枚举，加模块只加一个 enum 值。
  bool moduleEnabled(ModuleId module) =>
      getPref(module.prefKey, defaultValue: true) as bool;

  Future<void> setModuleEnabled(ModuleId module, bool value) async {
    await setPref(module.prefKey, value);
    notifyListeners();
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

  bool get startupDefaultDictionaryTab =>
      getPref('startup_default_dictionary_tab', defaultValue: false) as bool;

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

  /// 新任务默认使用的本机受管视频来源；0 表示尚未选择。
  int? get videoDownloadTargetSourceId {
    final int value = getPref(
      'video_download_target_source_id',
      defaultValue: 0,
    ) as int;
    return value > 0 ? value : null;
  }

  Future<void> setVideoDownloadTargetSourceId(int? sourceId) async {
    await setPref('video_download_target_source_id', sourceId ?? 0);
    notifyListeners();
  }

  /// 阅读器顶栏 / 底栏按钮布局（与视频页同一套泛型模型，2026-09-13）。持久化键
  /// `reader_control_layout`，空 / 坏值回出厂布局。
  ReaderControlLayout get readerControlLayout => ReaderControlLayout.decode(
        getPref('reader_control_layout', defaultValue: '') as String,
      );

  /// 视频字幕外观（JSON；解析见 VideoSubtitleStyle.encode/decode）。空串=默认外观。
  String get videoSubtitleStyle =>
      getPref('video_subtitle_style', defaultValue: '') as String;

  // ── audio sources ────────────────────────────────────────────────────

  /// 已退役的内置远端音频源 URL。曾经随新装默认写入用户的音频源列表；2026-09-13
  /// 用户拍板不再依赖任何第三方网络音频库，内置默认远端源整个删掉。老用户列表里
  /// 残留的这些 URL 在读取时剔除——只删默认值而不清持久化，就等于只对新装生效。
  /// 消费方一律经 [audioSourceConfigs] 读，这里是唯一咽喉。
  static const Set<String> retiredAudioSourceUrls = <String>{
    'https://fushi-reader.manhhaoo-do.workers.dev/?term={term}&reading={reading}',
  };

  /// Anki 本地音频服务器（local-audio-yomichan，默认端口 5050）的内置预设 URL。
  /// 用户装了该服务器后，在「管理音频来源」里打开开关即用；默认关闭——本地第三方
  /// 服务不经用户同意不参与查词发音（与 fushiRemote 同策）。
  /// 由 [_withDefaultAudioSources] 对所有用户「缺则补」为一条 disabled 源。
  static const String ankiLocalAudioUrl =
      'http://localhost:5050/?term={term}&reading={reading}';

  /// legacy `audio_sources`（只存已启用的远端 URL）。无内置默认远端源，未写过即空。
  List<String> get audioSources {
    final result = getPref('audio_sources', defaultValue: const <String>[]);
    if (result is List<String>) return result;
    if (result is List) return result.cast<String>();
    return <String>[];
  }

  List<AudioSourceConfig> get audioSourceConfigs {
    final result = getPref('audio_source_configs', defaultValue: null);
    if (result is List) {
      final configs = result
          .whereType<Map>()
          .map((Map json) => AudioSourceConfig.fromJson(
                Map<String, dynamic>.from(json),
              ))
          .where((AudioSourceConfig source) =>
              source.kind != AudioSourceKind.remoteAudio ||
              (source.url?.isNotEmpty ?? false))
          .toList();
      if (configs.isNotEmpty) return _withDefaultAudioSources(configs);
    }
    // 没写过 typed config 就按 legacy audio_sources 装配（fromLegacyUrls 默认
    // enabled，保留老用户已启用的 URL）；纯新装两个 pref 都空，走同一条路。
    return _withDefaultAudioSources(
      AudioSourceConfig.fromLegacyUrls(audioSources),
    );
  }

  List<AudioSourceConfig> _withDefaultAudioSources(
    List<AudioSourceConfig> sources,
  ) {
    // 已退役的内置远端源（见 [retiredAudioSourceUrls]）从老用户列表里剔除。
    final List<AudioSourceConfig> result = <AudioSourceConfig>[
      for (final AudioSourceConfig source in sources)
        if (source.kind != AudioSourceKind.remoteAudio ||
            !retiredAudioSourceUrls.contains(source.url))
          source,
    ];

    // fushiRemote 恒在列首（缺则补），历史行为不变。
    final bool hasFushiRemote = result.any(
      (AudioSourceConfig source) => source.kind == AudioSourceKind.fushiRemote,
    );
    if (!hasFushiRemote) {
      result.insert(0, AudioSourceConfig.fushiRemote());
    }

    // Anki 本地音频服务器（5050）内置预设：对所有用户「缺则补」为一条 disabled 源，
    // 追加在列尾。用户装了服务器打开开关即用；删掉后下次读取会 disabled 重生，与
    // fushiRemote 恒补策略一致（TODO-083 范式）。
    final bool hasAnki = result.any((AudioSourceConfig source) =>
        source.kind == AudioSourceKind.remoteAudio &&
        source.url == ankiLocalAudioUrl);
    if (!hasAnki) {
      result.add(AudioSourceConfig.remoteAudio(
        url: ankiLocalAudioUrl,
        label: 'Anki',
        enabled: false,
      ));
    }

    return result;
  }

  // ── UI visibility ────────────────────────────────────────────────────

  bool get showMediaNotification =>
      getPref('show_media_notification', defaultValue: true) as bool;

  bool get showFloatingLyric =>
      getPref('show_floating_lyric', defaultValue: false) as bool;

  double get floatingLyricFontSize =>
      getPref('floating_lyric_font_size', defaultValue: 20.0) as double;

  bool get floatingLyricClickLookup =>
      getPref('floating_lyric_click_lookup', defaultValue: true) as bool;

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
  /// （用户拍板）。偏好键与 fushi_audio 的 [kStudyIdleTimeoutPrefKey] 同名。
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
