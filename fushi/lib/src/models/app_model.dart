import 'dart:async';
import 'dart:io';
import 'dart:ui';

// archive/archive_io moved to DictionaryImportManager
// audio_service moved to AudioController
// external_app_launcher moved to AnkiIntegration
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fushi_core/fushi_core.dart';
import 'package:path/path.dart' as path;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:fushi/media.dart';
import 'package:fushi/utils.dart';
import 'package:fushi/src/media/override_thumbnail_migration.dart';
import 'package:fushi/src/storage/app_paths.dart';
import 'package:fushi/src/storage/books_directory.dart';
import 'package:fushi/src/storage/sandbox_relocation.dart';
import 'package:fushi/src/utils/net/app_network_bindings.dart';
import 'package:fushi_audio/fushi_audio.dart';
import 'package:fushi/src/profile/profile_repository.dart';
import 'package:fushi/src/models/app_font_loader.dart';
import 'package:fushi/src/models/app_ui_font_chain.dart';
import 'package:fushi/src/models/builtin_tags.dart';
import 'package:fushi/src/reader/reader_control_layout.dart';
import 'package:fushi/src/reader/reader_settings.dart';
import 'package:fushi/src/models/media_history_repository.dart';
import 'package:fushi/src/models/preferences_repository.dart';
import 'package:fushi/src/sync/sync_auto_trigger.dart';
import 'package:fushi/src/sync/sync_backend.dart';
import 'package:fushi/src/sync/sync_orchestrator.dart';
import 'package:fushi/src/sync/sync_repository.dart';
import 'package:fushi/src/models/theme_notifier.dart' as theme_notifier;
import 'package:fushi/src/models/theme_notifier.dart'
    show ThemeNotifier, CustomThemeEntry, ThemePreset;
// TODO-930: re-export the multi-theme value type so `fushi/models.dart`
// consumers (theme swatch row, CustomThemePage) can name it.
export 'package:fushi/src/models/theme_notifier.dart'
    show CustomThemeEntry, ThemePreset;
import 'package:fushi/src/migration/migration_readonly.dart';
import 'package:fushi/src/migration/migration_target_channel.dart';
import 'package:fushi/src/models/module_id.dart';
import 'package:fushi/src/settings/settings_schema.dart'
    show resetSettingsSchemaCache;
import 'package:fushi/src/shortcuts/gamepad_service.dart';
import 'package:fushi/src/shortcuts/shortcut_preferences.dart';
import 'package:fushi/src/shortcuts/shortcut_registry.dart';
import 'package:fushi/src/platform/platform_services.dart';
import 'package:fushi/src/platform/platform_providers.dart';

export 'package:fushi/src/models/local_audio_manager.dart' show InvalidLocalAudioDbException;
export 'package:fushi/src/models/audio_source_config.dart'
    show AudioSourceConfig, AudioSourceKind;

// LocalAudioDbEntry moved to local_audio_manager.dart, re-exported above.

/// A global [Provider] for app-wide configuration and state management.
final appProvider = ChangeNotifierProvider<AppModel>((ref) {
  return AppModel(ref.read(platformServicesProvider));
});

// Theme helper functions moved to theme_notifier.dart.
// Re-export for backward compatibility.
ColorScheme buildFushiColorScheme({
  required Color seedColor,
  required Brightness brightness,
  DynamicSchemeVariant variant = DynamicSchemeVariant.tonalSpot,
  Color? primary,
  Color? secondary,
  Color? tertiary,
  Color? primaryContainer,
  Color? surface,
  bool neutralDerived = false,
}) =>
    theme_notifier.buildFushiColorScheme(
      seedColor: seedColor,
      brightness: brightness,
      variant: variant,
      primary: primary,
      secondary: secondary,
      tertiary: tertiary,
      primaryContainer: primaryContainer,
      surface: surface,
      neutralDerived: neutralDerived,
    );

/// TODO-1151：本地备份导入/恢复的全屏遮罩阶段。[validating] 选完文件后正在读取/校验
/// 备份并生成合并预览（DB 仍打开、可取消）——旧实现这段只有设置行 24px 小圈，大 zip
/// 校验/预览要数十秒无明显反馈；[running] 正在解压落盘（DB 已关、阻塞、请勿关闭）；
/// [done] 已结束（成功或失败），显示确认视图等用户点「立即重启」。
enum BackupImportPhase { validating, running, done, failed }

/// 一次「请打开首页『查词』tab」请求（[AppModel.homeDictionaryTabRequest] 的值）。
///
/// [seq] 每次请求自增，只作 edge 触发（ValueNotifier 按相等性去重，两次同意图的请求
/// 也必须各触发一次）；[focusSearch] 是调用方对搜索框的意图，见
/// [AppModel.requestHomeDictionaryTab]。
@immutable
class HomeDictionaryTabRequest {
  const HomeDictionaryTabRequest({required this.seq, required this.focusSearch});

  final int seq;
  final bool focusSearch;

  @override
  bool operator ==(Object other) =>
      other is HomeDictionaryTabRequest &&
      other.seq == seq &&
      other.focusSearch == focusSearch;

  @override
  int get hashCode => Object.hash(seq, focusSearch);
}

/// A scoped model for parameters that affect the entire application.
/// RiverPod is used for global state management across multiple layers,
/// especially for preferences that persist across application restarts.
class AppModel with ChangeNotifier {
  /// Platform-specific service implementations, injected at construction.
  final PlatformServices platformServices;

  AppModel(this.platformServices);

  /// 同步报告产出后的统一 UI 回调（onReport）：并列触发**冲突弹窗**与**删除传播确认
  /// 弹窗**。两者独立（无冲突时仍可能有删除候选，反之亦然），故不能嵌套在
  /// [presentAutoConflicts] 的 early-return 之内。签名与 [SyncReportCallback] 一致。
  void presentSyncPrompts(SyncRunReport report, SyncBackend backend) {
  }

  /// Used for showing dialogs without needing to pass around a [BuildContext].
  GlobalKey<NavigatorState> get navigatorKey => _navigatorKey;
  late final GlobalKey<NavigatorState> _navigatorKey =
      GlobalKey<NavigatorState>();

  BuildContext? get _ctx => _navigatorKey.currentContext;

  /// Persistent database (Drift/SQLite).
  late FushiDatabase _database;

  /// True once [_database] has been opened in an init path. Used by
  /// [retryInitialise] to close a stale connection before re-running init
  /// (the late fields are reassigned, so the old DB would otherwise leak).
  bool _databaseOpened = false;

  /// Whether [database] is safe to read. False before any init path has opened
  /// the DB (and while a test seam deliberately leaves [_database] unset), so
  /// callers outside the init flow must gate [database] access on this instead
  /// of risking a LateInitializationError.
  bool get isDatabaseReady => _databaseOpened;

  /// Theme management, extracted from AppModel for testability.
  late ThemeNotifier themeNotifier;
  bool _themeListenerAdded = false;

  /// Preference management, extracted from AppModel for testability.
  PreferencesRepository? _prefsRepo;
  PreferencesRepository get prefsRepo => _prefsRepo!;
  bool get isPreferencesReady => _prefsRepo != null;

  /// Media history and search history, extracted for testability.
  late MediaHistoryRepository mediaHistoryRepo;

  /// **当前查词来源**的内容语言（BCP-47），决定查词卡里**词头**（`.expression`
  /// 与振假名）用哪条字体链。null = 未知 → 词头跟随弹窗的兜底链。
  ///
  /// 为什么词头不跟词典走：词头是**被查的那个词**，语言由用户正在读的东西决定，
  /// 不由哪本词典解释它决定——同一个词头在日文书里查和在中文书里查是两种字形。
  /// 释义区才跟词典语言（见 `dictionary_language_css.dart` 的分层）。
  ///
  /// 由各媒体页在进入/切换内容时写入（阅读器开书、视频页解析字幕语言、galgame
  /// 启动）；app 外查词（剪贴板/扩展）保持 null → 落到全局默认。
  String? currentLookupLanguage;

  /// Keyboard / gamepad shortcut bindings, persisted in preferences.
  final FushiShortcutRegistry shortcutRegistry = FushiShortcutRegistry();

  /// TODO-1375：媒体（阅读器 / 视频）是否打开的**可靠**通知源，专供 macOS 原生壳的
  /// 根 sidebar 显隐门控（main.dart 的 MacosWindow）。根因：sidebar 过去直接读
  /// `isMediaOpen`（= `_currentMediaSource != null`）在 MaterialApp.builder 里求值，
  /// 靠 `ref.watch(appProvider)` 重建——但 [openMedia] / [closeMedia] 只改
  /// `_currentMediaSource` 却**从不** notifyListeners，于是退出阅读器后 builder 不重跑、
  /// sidebar 卡在上一次求值的 `null`（永久消失 → 设置 tab 失去唯一切换出口 → 困死）。
  /// 用这个独立 ValueNotifier 在 open/close 里精确 set，配合 ValueListenableBuilder，
  /// 退出媒体必然重建并恢复 sidebar（单一真值源 + 保证通知），且不触发全局根重建。
  /// 非 macOS 平台不读它（阅读器是盖满的整页路由，与壳 sidebar 无关），纯 no-op。
  final ValueNotifier<bool> mediaOpenNotifier = ValueNotifier<bool>(false);

  /// Polls physical game controllers and dispatches them into the shortcut /
  /// focus pipeline on platforms where the Flutter engine does not deliver
  /// gameButton* key events (desktop). No-op on Android/iOS (native key events)
  /// and on desktops without an implemented input source.
  late final GamepadService gamepadService = GamepadService(
    navigatorKey: navigatorKey,
    registry: shortcutRegistry,
    // TODO-1113 P3: lets the pointer route keep the ring lit on a mouse DOWN that
    // carries focus to a target while focus navigation is enabled (hover/move
    // still hide it). Live-read so toggling the preference takes effect at once.
    focusNavigationEnabled: () => experimentalFocusNavigationEnabled,
  );

  /// Resets the focus highlight to touch mode on every route push/pop so a ring
  /// lit by keyboard/gamepad navigation on one page is not carried onto the next
  /// (BUG-398). Wired into [MaterialApp.navigatorObservers] in main.dart. Same-
  /// route home-tab switches go through HomePage._selectTab, which calls the
  /// underlying [GamepadService.resetHighlightForScreenSwitch] directly.
  late final HighlightResetNavigatorObserver focusHighlightObserver =
      HighlightResetNavigatorObserver(
    gamepadService.resetHighlightForScreenSwitch,
  );

  Color? get systemPrimaryColor => themeNotifier.systemPrimaryColor;

  Future<void> refreshSystemPalette() {
    if (!_themeListenerAdded) {
      return Future<void>.value();
    }
    return themeNotifier.refreshSystemPalette();
  }

  /// Used to get the versioning metadata of the app. See [initialise].
  PackageInfo get packageInfo => _packageInfo;
  late PackageInfo _packageInfo;

  /// Whether [initialise] has completed successfully.
  bool get isInitialised => _isInitialised;
  bool _isInitialised = false;

  /// 已迁移只读态（Fushi 迁移 P1-4，见 [kMigrationReadonlyPrefKey]）。
  /// 置位后本启动周期内：不自启互联/Yomitan 服务、不跑自动同步与后台写手。
  ///
  /// **包名门**：该偏好会随迁移 core 批原样合并进 Fushi 的库，只有真正运行为
  /// 老包（`app.hibiki.reader`）时才生效——否则 Fushi 导入完成后会误锁自己。
  /// 顺序有意：先查偏好（测试夹具里 [packageInfo] 是未初始化的 late 字段，
  /// 偏好为 false 时短路，不触发 LateInitializationError）。
  bool get isMigrationReadonly =>
      prefsRepo.getPref(kMigrationReadonlyPrefKey) == true &&
      packageInfo.packageName == kHibikiPackageName;

  /// BUG-815: the currently-running [_initialiseOnce] future, or null when no
  /// init is in flight. [initialise] uses it to serialise concurrent callers so
  /// a second init can never race the first over the shared [_database] /
  /// repositories / [_isInitialised]. Cleared when the in-flight run completes.
  Future<void>? _initInFlight;

  /// Non-null if [initialise] threw; UI should display this instead of spinning.
  String? get initError => _initError;
  String? _initError;

  /// Non-null when init was refused because the on-disk DB was created by a
  /// NEWER build of Hibiki than this one (downgrade protection). The UI shows a
  /// dedicated "update your app" notice with NO retry button — retry would fail
  /// identically and this is not a transient error. The DB file is left intact.
  FushiDatabaseDowngradeException? get downgradeError => _downgradeError;
  FushiDatabaseDowngradeException? _downgradeError;

  /// Non-null when init failed because the database could NOT be opened even
  /// after the full WAL/sidecar recovery ladder (TODO-905) — i.e. the main
  /// `hibiki.db` itself is corrupt, not just a stale `-wal`/`-shm`. The UI shows
  /// an actionable "restore a backup / clear data" notice; a plain Retry would
  /// loop forever (the very bug TODO-905 fixes), so recovery already ran inside
  /// the open path and a fresh open of the same corrupt file would fail again.
  FushiDatabaseUnrecoverableException? get unrecoverableDbError =>
      _unrecoverableDbError;
  FushiDatabaseUnrecoverableException? _unrecoverableDbError;

  /// BUG-815：非 null 表示桌面**配置了自定义数据根、但本次启动它不可达**（休眠 / 掉线 /
  /// 拔出的盘）。UI 据此显「数据位置未响应」逃生屏（重试 / 显式用默认位置启动），而**不**
  /// 静默把空默认库当真数据显示。真实数据仍原封不动躺在 [DataRootUnavailableException.
  /// configuredPath]。DB 尚未打开（init 在 resolve-data-roots 步就抛出），故重试是干净重跑。
  DataRootUnavailableException? get dataRootUnavailable => _dataRootUnavailable;
  DataRootUnavailableException? _dataRootUnavailable;

  /// Clears the error state and re-runs [initialise].
  Future<void> retryInitialise() async {
    // BUG-815: if an init started by main() is still IN FLIGHT — a slow cold
    // start that merely tripped the 20s loading watchdog, NOT a hang — do NOT
    // tear down / re-open the DB below. Closing [_database] out from under the
    // running init and spawning a SECOND concurrent init races them over the
    // shared _database / repositories / _isInitialised and surfaces as "all data
    // empty" on the home screen (mobile has no custom data root, so restarting —
    // a single clean init — restores everything). Await the in-flight attempt
    // instead: it completes (data appears) or sets _initError (whose own Retry
    // then runs cleanly, because [initialise]'s whenComplete has cleared
    // _initInFlight by that point).
    final Future<void>? inFlight = _initInFlight;
    if (inFlight != null) {
      await inFlight;
      return;
    }
    // A previous attempt may have partially initialised resources. Tear down
    // the ones that would otherwise leak or double-register before re-running
    // (the late fields below are reassigned by initialise()).
    if (_databaseOpened) {
      _prefsRepo?.removeListener(notifyListeners);
      if (_themeListenerAdded) {
        themeNotifier.removeListener(notifyListeners);
        _themeListenerAdded = false;
      }
      try {
        await _database.close();
      } catch (e, stack) {
        ErrorLogService.instance
            .log('AppModel.retryInitialise.close', e, stack);
      }
      _databaseOpened = false;
    }
    _initError = null;
    _downgradeError = null;
    _unrecoverableDbError = null;
    _dataRootUnavailable = null;
    _isInitialised = false;
    notifyListeners();
    await initialise();
  }

  /// BUG-815：用户在「数据位置未响应」逃生屏点「仍用默认位置启动」时调用。置全局
  /// [AppPaths.forceDefaultRootForSession] 让本次进程用 `path_provider` 默认根打开
  /// （配置根不动、原盘数据一字节不动），再走常规 [retryInitialise]。仅本次有效：下次
  /// 启动重新探测配置根，盘醒了自动用回真实数据。绝不自动调用——只由用户显式点击触发。
  Future<void> retryInitialiseWithDefaultRoot() async {
    await retryInitialise();
  }

  /// Used to notify dictionary widgets to dictionary history additions.
  final ChangeNotifier dictionaryEntriesNotifier = ChangeNotifier();

  /// Used to notify dictionary widgets to dictionary import additions.
  final ChangeNotifier dictionarySearchAgainNotifier = ChangeNotifier();

  /// Used to notify dictionary widgets to dictionary menu changes.
  final ChangeNotifier dictionaryMenuNotifier = ChangeNotifier();

  /// Used to notify toggling incognito. Updates the app logo to and from
  /// grayscale.
  final ChangeNotifier incognitoNotifier = ChangeNotifier();

  /// Notifies app to stop showing any screens.
  final ChangeNotifier databaseCloseNotifier = ChangeNotifier();

  bool get dataRootMigrationActive => false;

  /// TODO-1151：本地备份「导入/恢复」期间的全屏遮罩状态。导入同样会
  /// [closeDatabase]（释放数据库句柄以便整体替换 DB + 内容树），流程结束后必须
  /// 重启进程重新载入数据。旧实现只在设置行显示一个 24px 小圈、成功后延迟 500ms
  /// 直接 `exit(0)`，用户看到 app「突然消失」误以为失败。这里镜像 TODO-959 数据根
  /// 迁移的做法：进入导入态时把根 widget 切到明确的「正在导入备份，请勿关闭」遮罩，
  /// 完成后切到「导入完成 → 立即重启」确认视图，由用户点按（或后续可加倒计时）再退出。
  BackupImportPhase? _backupImportPhase;
  bool get backupImportActive => _backupImportPhase != null;

  /// TODO-376：一次性「请打开首页『查词』tab」信号。值每请求一次自增（内容无关，
  /// 仅作 edge 触发）。桌面悬浮字幕条点词（reader 路由里 `_lookupFromFloatingLyric`）
  /// 这种**显式**查词手势，需要把主窗口从阅读器/任意 tab 切到查词 tab，让
  /// [HomeDictionaryPage] 挂载并消费 [DesktopLookupService.pendingText]。
  ///
  /// 这是显式导航原语：HomePage 监听本信号只切 tab，不监听 DesktopLookupService；
  /// pending 只由 HomeDictionaryPage 消费（tab 未挂载时排队），HomePage 根节点
  /// 依旧不消费查词请求。
  ///
  /// 值是 [HomeDictionaryTabRequest]：[HomeDictionaryTabRequest.seq] 每请求一次自增
  /// （内容无关，仅作 edge 触发），[HomeDictionaryTabRequest.focusSearch] 带调用方对
  /// 搜索框的意图（见 [requestHomeDictionaryTab]）。
  final ValueNotifier<HomeDictionaryTabRequest> homeDictionaryTabRequest =
      ValueNotifier<HomeDictionaryTabRequest>(
    const HomeDictionaryTabRequest(seq: 0, focusSearch: false),
  );

  /// 发一次「打开查词 tab」请求（桌面悬浮字幕点词等显式手势调）。
  ///
  /// [focusSearch]：是否顺带把用户送进搜索框。**携带待查词**的调用方（桌面取词 /
  /// 悬浮字幕点词 / 扩展回流）传 false——它们正要把 pending 的词填进去出词卡，此刻
  /// 抢焦点只会打断；**不取任何文本**的 app 外热键「置顶并打开查词页」传 true——用户
  /// 按它就是为了打字，页面弹出来还得先点一下搜索框等于热键只做了一半。
  void requestHomeDictionaryTab({bool focusSearch = false}) {
    homeDictionaryTabRequest.value = HomeDictionaryTabRequest(
      seq: homeDictionaryTabRequest.value.seq + 1,
      focusSearch: focusSearch,
    );
  }

  late AppPaths _appPaths;

  /// Directory where data may be persisted.
  Directory get appDirectory => _appDirectory;
  late Directory _appDirectory;

  /// Directory where database data is persisted.
  Directory get databaseDirectory => _databaseDirectory;
  late Directory _databaseDirectory;

  /// Directory where database data is persisted.
  /// 磁盘上是否真装着名为 [name] 的词典（`dictionaryResourceDirectory/<name>/`）。
  ///
  /// BUG-1994：`dictionary_metadata` 行的存在性**不是**「已安装」的判据——旧的
  /// profile prune 会把已安装词典的行删掉。切 profile 回插时只信这个。
  ///
  /// 刻意**不**加「资源目录还没就绪就返回 false」的兜底：唯一调用方是
  /// [ProfileRepository.applyProfile]，四个入口全是用户操作（切换 / 导入覆盖 /
  /// 删除激活 profile 后回落），必在初始化之后。真要在初始化前被调到，`late` 抛
  /// 出来才是对的——静默返回 false =「判定成没装」= 不回插 = 正好重演本 bug 的
  /// 数据丢失，那是最不该选的失败模式。
  bool isDictionaryInstalledOnDisk(String name) =>
      Directory(path.join(_dictionaryResourceDirectory.path, name))
          .existsSync();

  late Directory _dictionaryResourceDirectory;

  /// Directory where media source thumbnails may be persisted.
  Directory get thumbnailsDirectory => _thumbnailsDirectory;
  late Directory _thumbnailsDirectory;

  /// Used to fetch an app locale by its locale tag with constant time
  /// performance. Initialised with [populateLocales] at startup.
  late Map<String, Locale> locales;

  /// Used to fetch a media type by its unique key with constant time
  /// performance. Initialised with [populateMediaTypes] at startup.
  late Map<String, MediaType> mediaTypes;

  /// Used to fetch initialised sources by their unique key with constant
  /// time performance. Initialised with [populateMediaSources] at startup.
  late Map<MediaType, Map<String, MediaSource>> mediaSources;

  /// Current active media source.
  MediaSource? get currentMediaSource => _currentMediaSource;
  MediaSource? _currentMediaSource;

  /// Current active media item.
  MediaItem? get currentMediaItem => _currentMediaItem;
  MediaItem? _currentMediaItem;

  /// The user's custom app-wide UI fonts, in the order they appear in the font
  /// library's `appUi` target — an ordered **fallback chain**, not a single
  /// face. Resolved and registered with the Flutter engine by [refreshAppFont];
  /// see [AppFontLoader.resolveAndLoadAll]. Empty means "no custom font", which
  /// hands the choice to the display language's system chain
  /// ([appUiFontChain]).
  List<String> _appFontFamilies = const <String>[];

  /// Primary app-chrome family = head of the resolved chain ([appFontChain]).
  /// Null keeps the platform default (non-CJK UI language with no custom font).
  String? get appFontFamily => appFontChain.isEmpty ? null : appFontChain.first;

  /// Everything after the primary family — feeds `TextStyle.fontFamilyFallback`.
  /// Null (not an empty list) when there is nothing to fall back to, so the
  /// style stays byte-identical to the pre-chain behaviour.
  List<String>? get appFontFallbacks {
    final List<String> chain = appFontChain;
    return chain.length > 1 ? chain.sublist(1) : null;
  }

  /// The full app-chrome font chain for the current display language, memoised
  /// on (locale, custom families) — [textStyle] is read on every theme rebuild,
  /// and rebuilding a dozen-entry chain each time is pure garbage.
  List<String> get appFontChain {
    final Locale uiLocale = appLocale;
    if (_cachedFontChainLocale == uiLocale &&
        identical(_cachedFontChainSource, _appFontFamilies)) {
      return _cachedFontChain;
    }
    _cachedFontChain = appUiFontChain(
      customFamilies: _appFontFamilies,
      locale: uiLocale,
      platform: defaultTargetPlatform,
    );
    _cachedFontChainLocale = uiLocale;
    _cachedFontChainSource = _appFontFamilies;
    return _cachedFontChain;
  }

  List<String> _cachedFontChain = const <String>[];
  Locale? _cachedFontChainLocale;
  List<String>? _cachedFontChainSource;

  /// The user's custom video-subtitle font family, or null to use the platform
  /// default (+ CJK fallback chain). Resolved/registered with the Flutter
  /// engine by [refreshAppFont] from the [FontTarget.videoSubtitle] target
  /// (TODO-864), independent of the app-wide UI font.
  String? _subtitleFontFamily;

  /// [FontTarget.gameLookup] 在 **Flutter 侧**解析出的字体链（texthooker 页面等
  /// 游戏文本面用），由 [refreshAppFont] 注册进引擎。
  ///
  /// 与 native hook 浮窗同一个用户设置、两端各取所能：native 分层窗只吃第一条裸
  /// sfnt（`AppFontLoader.resolveForNativeOverlay`），Flutter 侧能解码 WOFF/WOFF2
  /// 且能整链缺字回退，所以这里走 `resolveAndLoadAll` 取全链。
  List<String> _gameLookupFontFamilies = const <String>[];

  /// Loads **all** enabled entries of the `appUiFonts` target as the app-wide UI
  /// font chain (registering each file with the Flutter engine via
  /// [AppFontLoader]) and rebuilds the theme. Falls back to the display
  /// language's system fonts when none is usable. Safe to call repeatedly — a
  /// no-op when the resolved chain is unchanged.
  Future<void> refreshAppFont() async {
    final ReaderSettings settings = ReaderSettings(_database);
    await settings.refreshFromDb();
    // TODO-049: 软件系统字体走独立的 appUiFonts 目标，与小说正文(customFonts)、
    // 词典字体相互独立。整张列表都进链（不再只取第一条），用户排第 2、3 位的字体
    // 才真正参与缺字回退。
    final List<String> families =
        await AppFontLoader.resolveAndLoadAll(settings.appUiFonts);
    // TODO-864: 视频字幕字体走独立的 videoSubtitle 目标；复用同一次
    // refreshFromDb 一起解析。两个 target 都解析完再判是否 notify，否则
    // 只改字幕字体（appUi 未变）时 early-return 会吞掉刷新。
    // 字幕层自带 CJK 回退链（TODO-088）且与 mpv/libass 字号换算耦合（BUG-929），
    // 故仍取单个家族，不走链。
    final String? subtitleFamily =
        await AppFontLoader.resolveAndLoad(settings.videoSubtitleFonts);
    // 游戏文本目标同样在这里解析：texthooker 页面（Flutter 层）此前只跟主题字体，
    // 用户在字体库里为「游戏」设的字体只作用于 native hook 浮窗，同一批台词在
    // app 内页面里不跟随——两个表面各说各话。整链解析，理由见
    // [_gameLookupFontFamilies]。
    final List<String> gameFamilies =
        await AppFontLoader.resolveAndLoadAll(settings.gameLookupFonts);
    if (listEquals(families, _appFontFamilies) &&
        subtitleFamily == _subtitleFontFamily &&
        listEquals(gameFamilies, _gameLookupFontFamilies)) {
      return;
    }
    _appFontFamilies = families;
    _subtitleFontFamily = subtitleFamily;
    _gameLookupFontFamilies = gameFamilies;
    notifyListeners();
  }

  /// Get the app-wide text style.
  ///
  /// The UI font follows the *display* language ([appLocale]), not the pinned
  /// Japanese reading language (直取 JapaneseLanguage.instance). With no user custom font,
  /// [fontFamily] is left null so the platform resolves the correct regional
  /// glyphs for the UI locale (e.g. Simplified-Chinese glyphs for `zh-CN`)
  /// instead of the Japanese kanji variants the old `NotoSansJP` + `ja`-locale
  /// pin forced on every Material platform. Japanese reader/dictionary content
  /// renders in WebView with its own CSS font, so it is unaffected by this
  /// app-chrome style.
  TextStyle get textStyle {
    final Locale uiLocale = appLocale;
    return TextStyle(
      fontFamily: appFontFamily,
      // 缺字回退链（[appUiFontChain]）：用户列表里剩下的字体 + 显示语言的系统
      // CJK 字体 + 其余 CJK 语言。没有它时，主字体缺字（典型如日文 face 上的
      // 简中「们/东」、中文 face 上的日文假名）会逐字掉进引擎默认 fallback，
      // 同一行里字形忽宽忽窄。
      fontFamilyFallback: appFontFallbacks,
      fontFeatures: const [FontFeature('liga', 0)],
      locale: uiLocale,
      textBaseline: _isIdeographicLocale(uiLocale)
          ? TextBaseline.ideographic
          : TextBaseline.alphabetic,
    );
  }

  /// CJK locales sit on the ideographic baseline; every other script uses the
  /// alphabetic baseline. Drives [textStyle]'s [TextStyle.textBaseline].
  static bool _isIdeographicLocale(Locale locale) {
    switch (locale.languageCode) {
      case 'ja':
      case 'zh':
      case 'ko':
        return true;
      default:
        return false;
    }
  }

  /// The app-wide [TextTheme]. [textStyle] carries the locale-aware font
  /// (fontFamily/fontFeatures/baseline); [FushiTypeScale] layers the editorial
  /// size/weight/line-height scale on top. Explicit sizes here survive the
  /// geometry merge `MaterialApp` performs, so this scale — not M3 defaults —
  /// is what renders.
  TextTheme get textTheme => FushiTypeScale.buildTextTheme(textStyle);

  ThemeMode get themeMode => themeNotifier.themeMode;
  ThemeData get theme => themeNotifier.theme;
  ThemeData get darkTheme => themeNotifier.darkTheme;

  ColorScheme buildColorScheme(Brightness brightness) =>
      themeNotifier.buildColorScheme(brightness);

  /// This should all be refactored as part of [MediaItem] if possible. No
  /// reason to expose it here if not for card export functions. This is super
  /// cursed. Need to extract this to its own Provider at some point.

  /// Override color for the dictionary widget.
  Color? get overrideDictionaryColor => _overrideDictionaryColor;
  Color? _overrideDictionaryColor;

  /// Override color for the dictionary widget.
  void setOverrideDictionaryColor(Color? color) {
    _overrideDictionaryColor = color;
  }

  /// Override theme for the dictionary widget.
  void setOverrideDictionaryTheme(ThemeData? themeData) {
  }

  /// Populate maps for locales at startup to optimise performance.
  void populateLocales() {
    /// A list of locales that the app will support at runtime. This is not
    /// related to supported target languages.
    final List<Locale> availableLocales = List<Locale>.unmodifiable(
      [
        const Locale('en', 'US'),
        const Locale('zh', 'CN'),
        const Locale('zh', 'HK'),
        const Locale('ja'),
        const Locale('ko'),
        const Locale('es'),
        const Locale('fr'),
        const Locale('de'),
        const Locale('pt', 'BR'),
        const Locale('ru'),
        const Locale('vi'),
        const Locale('th'),
        const Locale('id'),
        const Locale('ar'),
        const Locale('nl'),
        const Locale('it'),
        const Locale('tr'),
      ],
    );

    locales = Map<String, Locale>.unmodifiable(
      Map<String, Locale>.fromEntries(
        availableLocales.map(
          (locale) => MapEntry(locale.toLanguageTag(), locale),
        ),
      ),
    );
  }

  /// Populate maps for media types at startup to optimise performance.
  void populateMediaTypes() {
    /// A list of media types that the app will support at runtime.
    final List<MediaType> availableMediaTypes = List<MediaType>.unmodifiable(
      [
        ReaderMediaType.instance,
      ],
    );

    mediaTypes = Map<String, MediaType>.unmodifiable(
      Map<String, MediaType>.fromEntries(
        availableMediaTypes.map(
          (mediaType) => MapEntry(mediaType.uniqueKey, mediaType),
        ),
      ),
    );
  }

  /// Populate maps for media sources at startup to optimise performance.
  void populateMediaSources() {
    /// A list of media sources that the app will support at runtime.
    final Map<MediaType, List<MediaSource>> availableMediaSources = {
      ReaderMediaType.instance: [
        ReaderFushiSource.instance,
        // PDF 阅读器 Phase 1：注册第二个 reader 源。书架/页头恒用第一个（默认源），PDF 行
        // 仅在打开时经 mediaSourceIdentifier='reader_pdf' 路由到本源、进 ReaderPdfPage。
        // 通用 init 循环与 refreshPrefCache 按 mediaSources 遍历，自动接管本源初始化。
        ReaderPdfSource.instance,
      ],
    };

    mediaSources = Map<MediaType, Map<String, MediaSource>>.unmodifiable(
      availableMediaSources.map(
        (type, sources) => MapEntry(
          type,
          Map<String, MediaSource>.unmodifiable(
            Map<String, MediaSource>.fromEntries(
              sources.map(
                (source) => MapEntry(source.uniqueKey, source),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Populate maps for actions at startup to optimise performance.
  void populateQuickActions() {
    return;
  }

  /// Injects licenses to be displayed in the licenses page that aren't
  /// pre-included by Flutter upon compilation but are included as assets.
  Future<void> injectAssetLicenses() async {
    final packageNames = [
      'ebook-reader',
    ];

    for (String packageName in packageNames) {
      String licenseText =
          await rootBundle.loadString('assets/licenses/$packageName.txt');
      LicenseRegistry.addLicense(
        () => Stream<LicenseEntry>.value(
          LicenseEntryWithLineBreaks(<String>[packageName], licenseText),
        ),
      );
    }
  }

  /// TODO-1260：启动期对**数据根**做 IO 的关键 await 的超时上限。旧代码这些 await 若
  /// 因自定义数据根所在磁盘掉线而永不返回，会让 `initialise()` 无限挂起（首帧不出、
  /// 无限加载），而 `initialise()` 的顶层 try/catch 只接异常、接不住 hang。给这些 await
  /// 叠超时后，超时抛 [TimeoutException]→落顶层 catch→`_initError` 错误屏（有 Retry），
  /// 把「无逃生的无限 hang」变成「可重试的错误」。取 12s：远大于本机盘正常耗时（毫秒级），
  /// 只在盘真掉线 / 卡死时触发。
  static const Duration _initIoTimeout = Duration(seconds: 12);

  /// 给启动关键 IO 的 [Future] 叠一层超时：超时抛带**步骤名**的 [TimeoutException]，
  /// 让错误屏文案能指出卡在哪一步。
  Future<T> _guardInitIo<T>(String step, Future<T> future) => future.timeout(
        _initIoTimeout,
        onTimeout: () => throw TimeoutException(
          'AppModel.initialise 卡在「$step」超过 ${_initIoTimeout.inSeconds}s 未返回'
          '（多半是自定义数据根所在磁盘掉线 / 卡死）',
          _initIoTimeout,
        ),
      );

  /// Prepare application data and state to be ready of use upon starting up
  /// the application. [AppModel] is initialised in the main function before
  /// [runApp] is executed.
  Future<void> _prepareRuntimeDirectories() async {
    // TODO-935 E0：三个数据根经唯一入口 [AppPaths] 解析（内部已honor测试分支
    // [fushiTestDirectory]，故行为与旧的 test/production 双分支逐字节等价）。
    _appPaths = await AppPaths.resolve();
    // TODO-1236：把上游 `hibiki_audio` 的有声书持久根解析接到 `AppPaths`（它无法 import
    // AppPaths）。这样桌面自定义数据根生效后，有声书新导入落数据根下的 `audiobooks/`
    // （与 TODO-1226 迁移白名单一致），而不是落回平台 Documents。
    AudiobookStorage.documentsRootResolver = AppPaths.documentsRootDirectory;
    _appDirectory = _appPaths.documentsRoot;
    _databaseDirectory = _appPaths.supportRoot;
  }

  /// Public entry point for app initialisation.
  ///
  /// BUG-815: serialises initialisation. If a run is already in flight (e.g. the
  /// loading-watchdog Retry firing while main()'s init is still going on a slow
  /// cold start), concurrent callers share that single run instead of starting a
  /// SECOND init that races the first over [_database] / repositories /
  /// [_isInitialised]. Once the run completes — success OR [_initError] (the body
  /// catches internally and never rethrows, so this future always resolves
  /// normally) — the guard clears, so a genuine retry-after-error still starts a
  /// fresh attempt.
  Future<void> initialise() {
    final Future<void>? existing = _initInFlight;
    if (existing != null) return existing;
    final Future<void> run = _initialiseOnce();
    _initInFlight = run;
    return run.whenComplete(() {
      if (identical(_initInFlight, run)) _initInFlight = null;
    });
  }

  /// One-shot initialisation body. Never call directly — always go through
  /// [initialise] so the in-flight guard holds.
  Future<void> _initialiseOnce() async {
    try {
      debugPrint('[Fushi] init: PackageInfo + DeviceInfo');

      /// Prepare entities that may be repeatedly used at runtime.
      _packageInfo = await PackageInfo.fromPlatform();

      debugPrint('[Fushi] init: directories (early, needed for DB)');
      // TODO-1260：这一步内部解析数据根（含对自定义数据根盘的 stat）。盘掉线时最易 hang，
      // 故写启动面包屑 + 叠超时（超时→错误屏 Retry，不再无限加载）。
      ErrorLogService.instance
          .markInitStep('resolve-data-roots（AppPaths.resolve / 数据根 stat）');
      await _guardInitIo('resolve-data-roots', _prepareRuntimeDirectories());

      // W2-7：存量书库目录 hoshi_books → fushi_books 就地改名。必须在 DB 打开
      // **之前**跑：v72 迁移在首次打开时把 extract_dir / image_url 里的目录段
      // 改写成新名，先改磁盘再开库，同一次启动内两侧一致。改名失败不阻塞
      // （上报错误日志，下次启动重试自愈；旧目录原地保留，数据零丢失）。
      migrateLegacyBooksDirectoryAt(
        _appDirectory.path,
        onMigrationError: (Object e, StackTrace stack) => ErrorLogService
            .instance
            .log('AppModel.migrateLegacyBooksDirectory', e, stack),
      );

      debugPrint('[Fushi] init: Drift database');
      ErrorLogService.instance.markInitStep('open-database（Drift 打开 fushi.db）');
      _database = FushiDatabase(_databaseDirectory.path);
      _databaseOpened = true;


      // 沙箱重定位自愈：数据根被**平台**挪走后，把库里的绝对路径重基过去。
      //
      // iOS 每次安装/更新都会换掉 app 容器 UUID，文件随容器走、库里记的旧路径
      // 集体悬空 —— 症状是「更新一次，整个书架全部『找不到书籍文件』」，每次更新
      // 复发。这一步必须在**任何消费路径的东西读库之前**跑（下面的 SyncRepository
      // 迁移、各 repository 的 load、媒体历史都要读路径列），也必须在
      // recoverPendingImport **之后**：崩在半途的备份导入恢复出来的库同样带着
      // 导出设备的旧根，要一起重基。
      //
      // 自愈失败只上报、不阻塞启动：用户至多回到修复前的状态，绝不能因为对账
      // 出错而进不去 app（台账故意不写，下次启动会重试）。
      await SandboxRelocation.reconcile(
        db: _database,
        documentsRoot: _appDirectory.path,
        supportRoot: _databaseDirectory.path,
        onError: (Object e, StackTrace stack) => ErrorLogService.instance
            .log('AppModel.sandboxRelocation', e, stack),
      );
      //    cloud backup backend can now coexist);
      // 4) BUG-1576: drop the pre-decoupling GLOBAL folder cache. Two channels
      //    took turns writing that single pair of keys, so its value can no
      //    longer be attributed to any one remote — and an interconnect/WebDAV
      //    folderId is an ABSOLUTE URL, which the other channel would then hit
      //    (Basic credentials attached). It is a pure cache: every backend
      //    re-resolves its root/book folders by name on the next sweep.
      await SyncRepository(_database).migrateSmbToWebDav();
      await SyncRepository(_database).migrateInterconnectBackendToToggle();
      await SyncRepository(_database).migrateFolderCacheToPerChannel();

      /// Prepare all repositories (objects created first, then loaded in
      /// parallel to avoid serial await chains).
      _prefsRepo = PreferencesRepository(_database);
      final profileRepo = ProfileRepository(
        _database,
        // BUG-1994：切 profile 时「这本词典装没装」只认磁盘目录。闭包是惰性的，
        // 只在 applyProfile（用户操作）里调，那时 late 的资源目录早已就位。
        isDictionaryInstalled: isDictionaryInstalledOnDisk,
      );
      mediaHistoryRepo = MediaHistoryRepository(_database);

      debugPrint('[Fushi] init: repositories (parallel)');
      await Future.wait(<Future<void>>[
        prefsRepo.loadFromDb().then((_) => _applyStatDayResetHour()),
        profileRepo.ensureDefaultProfile(),
        mediaHistoryRepo.loadFromDb(),
      ]);
      prefsRepo.addListener(notifyListeners);
      // 主入口与精简词典入口共用装配，并等系统代理就绪后再启动网络服务。
      await installAppNetworkBindings();
      _applyMemoryPolicy();

      final Map<String, String> prefsSnapshot = prefsRepo.prefsSnapshot;

      themeNotifier = ThemeNotifier(_database, () => textTheme);
      themeNotifier.loadFromPrefsSnapshot(prefsSnapshot);
      themeNotifier.addListener(notifyListeners);
      _themeListenerAdded = true;

      debugPrint('[Fushi] init: directories + system palette (parallel)');
      _thumbnailsDirectory =
          Directory(path.join(appDirectory.path, 'thumbnails'));

      _dictionaryResourceDirectory =
          Directory(path.join(appDirectory.path, 'dictionaryResources'));

      // TODO-1260：这些目录都派生自数据根（documentsRoot）；盘掉线时 create() 会 hang。
      ErrorLogService.instance.markInitStep(
          'create-runtime-dirs（thumbnails / dictionaryResources 等目录创建）');
      await _guardInitIo(
        'create-runtime-dirs',
        Future.wait(<Future<void>>[
          thumbnailsDirectory.create(recursive: true),
          refreshSystemPalette(),
        ]),
      );

      // W2-3：override 封面文件名的 hoshi://→fushi:// 前缀换代一次性清扫
      // （文件名是 identifier 的 hashCode，v73 改写库内 identifier 后旧文件
      // 不再命中）。pref 门控幂等；清扫不干净（rename 失败）不落标记，下次
      // 启动重试。放在 thumbnails 目录建好、DB 迁移已跑完之后。
      if (!prefsRepo.containsKey(kOverrideThumbnailPrefixMigratedPrefKey)) {
        final bool clean = await migrateOverrideThumbnailPrefixes(
          db: _database,
          thumbnailsDirectory: thumbnailsDirectory,
        );
        if (clean) {
          await prefsRepo.setPref(
              kOverrideThumbnailPrefixMigratedPrefKey, true);
        }
      }

      debugPrint('[Fushi] init: populate maps + audio DB (parallel)');
      populateLocales();
      LocaleSettings.setLocaleRaw(appLocale.toLanguageTag());
      populateMediaTypes();
      populateMediaSources();
      populateQuickActions();


      await Future.wait(<Future<void>>[
        injectAssetLicenses(),
        _seedBuiltInTags(),
      ]);

      debugPrint(
          '[Fushi] init: reader settings + enhancements + quick actions + media sources (parallel)');
      MediaSource.setDatabase(_database);
      final readerSettings = ReaderSettings(_database);
      await readerSettings.loadFromPrefsSnapshot(prefsSnapshot);
      // TODO-1393 self-heal: recover custom-font entries whose stored absolute
      // path went stale (data-root move / pre-fix backup restore that never
      // rebased `font_catalog` / iOS reinstall / profile-import stripped path) by
      // relocating them onto same-basename files still present under the current
      // `<documents>/custom_fonts`. Runs before the font resolution below so the
      // app-wide + subtitle fonts load from healed paths on first paint. Idempotent
      // (a no-op DB touch when every path already resolves).
      try {
        final int relocated = await readerSettings.healMissingFontFilePaths(
          path.join(appDirectory.path, 'custom_fonts'),
        );
        if (relocated > 0) {
          debugPrint(
              '[Fushi] init: relocated $relocated stale custom-font path(s) to current custom_fonts dir');
        }
      } catch (e, stack) {
        ErrorLogService.instance.log('AppModel.healFontPaths', e, stack);
      }
      // Register the user's custom app-wide fonts (every enabled entry, in
      // order — the chain feeds fontFamily + fontFamilyFallback) before first
      // paint so the global theme uses them without a flash. Reuses the
      // settings just loaded above to avoid a second prefs read.
      // 三个字体目标互不依赖，并发解析（同名家族由 AppFontLoader 的在途表去重，
      // 只装一次）；串行三条链 = 首帧前三段可见等待。
      final Future<List<String>> appFontsF =
          AppFontLoader.resolveAndLoadAll(readerSettings.appUiFonts);
      // TODO-864: 视频字幕字体同样在首帧前从 videoSubtitle 目标解析。
      final Future<String?> subtitleFontF =
          AppFontLoader.resolveAndLoad(readerSettings.videoSubtitleFonts);
      // 游戏文本字体链也在首帧前解析：否则 texthooker 页面首次打开会先用主题字体
      // 画一帧再跳变（refreshAppFont 要等到用户改设置才跑）。
      final Future<List<String>> gameFontsF =
          AppFontLoader.resolveAndLoadAll(readerSettings.gameLookupFonts);
      await Future.wait<Object?>(
          <Future<Object?>>[appFontsF, subtitleFontF, gameFontsF]);
      _appFontFamilies = await appFontsF;
      _subtitleFontFamily = await subtitleFontF;
      _gameLookupFontFamilies = await gameFontsF;
      ReaderFushiSource.readerSettings = readerSettings;

      // Start polling physical controllers on platforms that need it (desktop);
      // start() is a no-op where the engine already delivers gameButton* keys.
      gamepadService.start();

      await Future.wait(<Future<void>>[
        Future.wait(<Future<void>>[
          for (MediaType type in mediaTypes.values)
            for (MediaSource source in mediaSources[type]!.values)
              source.initialise(),
        ]),
      ]);

      // BUG-207: load the shortcut registry only AFTER ReaderFushiSource has
      // run initialise() (which populates its in-memory preference cache from
      // the DB). Reading shortcut_bindings_json before the cache is loaded saw
      // an empty cache -> null -> resetToDefaults, and getPreference's
      // cache-miss write-through clobbered the saved JSON with 's:null',
      // permanently dropping the user's custom keys on every launch. Mirrors the
      // profile-switch path (refreshPrefCache: refresh source caches first, then
      // loadShortcutRegistry).
      await loadShortcutRegistry(
        shortcutRegistry,
        ReaderFushiSource.instance,
        defaultTargetPlatform,
      );

      debugPrint(
          '[Fushi] init: search preload (deferred to after first frame)');

      debugPrint('[Fushi] init: DONE');
      // TODO-1260：启动正常跑完，清掉启动步进面包屑（否则下次启动会误报上次 hang）。
      ErrorLogService.instance.clearInitStep();
      _isInitialised = true;
      // TODO-855: prime the prefs-version watermark from the freshly loaded
      // cache (keeps refreshPrefCacheIfChanged consistent if ever reused here).
      // 已迁移只读态（Fushi 迁移 P1-4）：不再自启互联服务——两版并存时端口
      // 固定必冲突（SyncServerPortInUseException 会打到用户脸上）；老版只保
      // 留「重新导出」通道。
      if (isMigrationReadonly) {
        notifyListeners();
        return;
      }
      // 「功能模块」后台自启门（模块被关 = 它专属的后台**下次启动不再拉起**）。
      //
      // 快照只取一次：[moduleVisibility] 每次读都重新合成一个 Set，而下面这一串
      // 是同一帧里的连续判定，取一次既省分配也保证这一批门读的是同一份真值。
      //
      // 刻意**只判启动、不 stop**：用户在会话中途关模块时不切断进行中的任务
      // （正在跑的同步/下载/做种照常跑完），下次启动才不再拉起。
      notifyListeners();
    } on DataRootUnavailableException catch (e, stack) {
      // BUG-815: a custom data root IS configured but is currently unreachable
      // (slow/sleeping/disconnected drive). AppPaths.resolve threw INSTEAD of
      // silently deriving the empty default location — the DB was never opened
      // (_databaseOpened stays false, so retry is a clean re-run). Surface a
      // dedicated "data location unavailable" escape screen (Retry / explicit
      // opt-in-to-default); do NOT set _initError so the generic error screen
      // doesn't shadow it. The real data is untouched on e.configuredPath.
      debugPrint('[Fushi] init PAUSED (data root unavailable): $e\n$stack');
      ErrorLogService.instance
          .log('AppModel.initialise.dataRootUnavailable', e, stack);
      _dataRootUnavailable = e;
      notifyListeners();
    } on FushiDatabaseDowngradeException catch (e, stack) {
      // The DB is newer than this build. drift refused to open it WITHOUT
      // touching the file (no DROP / migration ran). Surface a dedicated,
      // non-retryable notice instead of the generic init-error screen, and
      // STOP — never continue init, never delete or rebuild the DB.
      debugPrint('[Fushi] init REFUSED (DB downgrade): $e\n$stack');
      ErrorLogService.instance.log('AppModel.initialise.downgrade', e, stack);
      _downgradeError = e;
      _initError = '$e';
      notifyListeners();
    } on FushiDatabaseUnrecoverableException catch (e, stack) {
      // TODO-905: the WAL/sidecar recovery ladder already ran inside the open
      // path and exhausted — the main hibiki.db is corrupt. Surface a dedicated,
      // actionable notice (restore backup / clear data) instead of looping the
      // generic Retry button forever against the same un-openable file.
      debugPrint('[Fushi] init FAILED (DB unrecoverable): $e\n$stack');
      ErrorLogService.instance
          .log('AppModel.initialise.unrecoverableDb', e, stack);
      _unrecoverableDbError = e;
      _initError = '$e';
      notifyListeners();
    } catch (e, stack) {
      debugPrint('[Fushi] init FAILED: $e\n$stack');
      ErrorLogService.instance.log('AppModel.initialise', e, stack);
      _initError = '$e';
      notifyListeners();
    }
  }

  /// Reload the preference cache from the database, e.g. after a profile
  /// switch has written new values.
  Future<void> refreshPrefCache() async {
    await prefsRepo.refreshFromDb();
    for (final sourceMap in mediaSources.values) {
      for (final source in sourceMap.values) {
        await source.refreshPreferencesFromDb();
      }
    }
    await themeNotifier.refreshFromDb();
    // Shortcut bindings are profile-scoped: reload the live registry from the
    // (now-refreshed) source preference so a profile switch takes effect
    // immediately instead of only after an app restart.
    await loadShortcutRegistry(
      shortcutRegistry,
      ReaderFushiSource.instance,
      defaultTargetPlatform,
    );
    // TODO-855: after a full reload the in-memory cache holds the latest DB
    // version, so advance the watermark to keep refreshPrefCacheIfChanged from
    // immediately reloading again.
  }

  // ── sync pref helpers (delegated to PreferencesRepository) ──────────

  dynamic _getPref(String key, {dynamic defaultValue}) =>
      prefsRepo.getPref(key, defaultValue: defaultValue);

  Future<void> _setPref(String key, dynamic value) =>
      prefsRepo.setPref(key, value);

  // TODO-1166：新装时把内置默认标签播种为 5 档星级评分（1⭐..5⭐）。
  // 仍是「一次性、仅空池」播种：`builtInTagsSeeded` 标志种过即不再动，空池才种，
  // 保证既有用户的标签池不被覆盖（老用户改星级走标签管理页的一键补齐入口）。
  Future<void> _seedBuiltInTags() async {
    if (prefsRepo.containsKey('builtInTagsSeeded')) return;
    final existing = await _database.getAllTags();
    if (existing.isEmpty) {
      await seedStarRatingTags(_database);
    }
    await _setPref('builtInTagsSeeded', 'true');
  }

  // _bindLocalAudioDbForNativeHandler moved to LocalAudioManager.bindForNativeHandler

  // _rowToDictionary, _dictionaryToCompanion, _persistDictionary
  // moved to DictionaryRepository.

  // ── Theme delegates (logic moved to ThemeNotifier) ──────────────────

  static Map<String, ThemePreset> get themePresets =>
      ThemeNotifier.themePresets;

  static ColorScheme buildPresetColorScheme(
    ThemePreset preset,
    Brightness brightness,
  ) =>
      ThemeNotifier.buildPresetColorScheme(preset, brightness);

  String get appThemeKey => themeNotifier.appThemeKey;
  Future<void> setAppThemeKey(String key) => themeNotifier.setAppThemeKey(key);

  // TODO-930: multi custom theme list delegation. The UI (theme swatch row +
  // CustomThemePage) talks to AppModel, so mirror ThemeNotifier's list API here
  // exactly like the legacy flat custom_theme_* getters above.
  List<CustomThemeEntry> get customThemes => themeNotifier.customThemes;
  CustomThemeEntry? customThemeById(String id) =>
      themeNotifier.customThemeById(id);
  CustomThemeEntry? get activeCustomThemeEntry =>
      themeNotifier.activeCustomThemeEntry;
  Future<void> upsertCustomTheme(CustomThemeEntry entry) =>
      themeNotifier.upsertCustomTheme(entry);
  Future<void> deleteCustomTheme(String id) =>
      themeNotifier.deleteCustomTheme(id);
  Future<void> selectCustomTheme(String id) =>
      themeNotifier.selectCustomTheme(id);

  String get brightnessMode => themeNotifier.brightnessMode;
  Future<void> setBrightnessMode(String mode) =>
      themeNotifier.setBrightnessMode(mode);

  /// 墨水屏模式（E-ink）：全局纯黑白主题 + 关动画 + 阅读器/弹窗高对比。
  bool get einkMode => themeNotifier.einkMode;
  Future<void> setEinkMode(bool value) => themeNotifier.setEinkMode(value);

  double get appUiScale => themeNotifier.appUiScale;
  Future<void> setAppUiScale(double value) =>
      themeNotifier.setAppUiScale(value);
  double resolveAppUiScaleForViewport({
    required Size viewport,
    required TargetPlatform platform,
  }) =>
      themeNotifier.resolveAppUiScaleForViewport(
        viewport: viewport,
        platform: platform,
      );

  bool get isDarkMode => themeNotifier.isDarkMode;

  // BUG-2187：阅读器等 ColorScheme 之外的消费者读「当前生效自定义主题」的角色色
  // 必须走这几个 getter（条目优先、扁平偏好兜底、非自定义 key 恒 null），
  // 不得再直接读下面的 legacy 扁平 getter。
  Color? get activeCustomThemeFontColor =>
      themeNotifier.activeCustomThemeFontColor;
  Color? get activeCustomThemeBackgroundColor =>
      themeNotifier.activeCustomThemeBackgroundColor;
  Color? get activeCustomThemeSelectionColor =>
      themeNotifier.activeCustomThemeSelectionColor;
  Color? get activeCustomThemeLinkColor =>
      themeNotifier.activeCustomThemeLinkColor;

  /// TODO-977: 全局音频高亮颜色（与阅读器主题解耦），委托 ThemeNotifier。
  Color? get audioHighlightColor => themeNotifier.audioHighlightColor;
  Future<void> setAudioHighlightColor(Color? c) =>
      themeNotifier.setAudioHighlightColor(c);

  /// Get the current app locale from persisted preferences.
  /// Defaults to system locale if supported, otherwise en-US.
  Locale get appLocale {
    String? saved = _getPref('app_locale');
    if (saved != null && saved.isNotEmpty && locales.containsKey(saved)) {
      return locales[saved]!;
    }

    // Match system locale to available locales.
    final systemLocale = PlatformDispatcher.instance.locale;
    final systemTag = systemLocale.toLanguageTag();
    if (locales.containsKey(systemTag)) {
      return locales[systemTag]!;
    }
    // Try language-only match (e.g. "zh" matches "zh-CN").
    for (final entry in locales.entries) {
      if (entry.value.languageCode == systemLocale.languageCode) {
        return entry.value;
      }
    }

    return locales.values.first;
  }

  /// Persist a new app locale in preferences and switch the UI language.
  ///
  /// Desktop (TODO-960): live hot-reload, **never** restart the process. The
  /// desktop restart path (`Process.start(detached) + exit(0)`) races the
  /// Windows single-instance mutex (`windows/runner/main.cpp`): the freshly
  /// spawned process reaches `CreateMutexW` before the old process has called
  /// `exit(0)`, gets `ERROR_ALREADY_EXISTS`, fronts the old window then
  /// `return EXIT_SUCCESS` (self-terminates) — moments later the old process
  /// also exits, leaving no process at all (app closes, never reopens). So on
  /// desktop we mutate [LocaleSettings] in place and [notifyListeners]; because
  /// the bulk of the UI reads the global Method A `t` (which does NOT rebuild
  /// on a [LocaleSettings] change by itself), the root widget tree is
  /// additionally remounted via a locale-keyed [Key] at [main]'s
  /// [TranslationProvider] (see `_FushiReaderAppState.build`).
  ///
  /// Mobile (Android/iOS) keeps the native restart path (`restart_app` plugin
  /// rebuilds the Activity/scene — no mutex race). The data-root migration
  /// path still restarts on every platform via its own call site
  /// (`data_root.part.dart`), and is intentionally unaffected by this method.
  Future<void> setAppLocale(String localeTag) async {
    await _setPref('app_locale', localeTag);
    LocaleSettings.setLocaleRaw(localeTag);
    if (platformServices.lifecycle.supportsRestart) {
      await platformServices.lifecycle.restartApp();
    } else {
    }
  }

  bool get startupDefaultDictionaryTab => prefsRepo.startupDefaultDictionaryTab;

  /// 阅读器顶栏 / 底栏按钮布局（ReaderControlLayout，2026-09-13）。
  ReaderControlLayout get readerControlLayout => prefsRepo.readerControlLayout;

  /// 视频字幕外观（JSON；见 VideoSubtitleStyle）。
  String get videoSubtitleStyle => prefsRepo.videoSubtitleStyle;

  // galgame 窗口超分**每游戏一档**（BUG-1191），存 `galgames.upscaling_mode`，
  // 读写走 [galgameRepo]。这里刻意不再有全局 getter/setter —— 留着一个全局值就会
  // 有人接回去用，然后两份真值慢慢漂开。

  /// 只暴露当前设备可访问的本地受管视频来源，供发现页新任务/订阅选择。
  Future<List<MediaSourceRow>> getManagedVideoDownloadSources() async {
    final List<MediaSourceRow> sources =
        await database.getMediaSourcesByKind('video');
    return sources
        .where(
          (MediaSourceRow source) =>
              source.transport == 'local' &&
              path.isAbsolute(source.rootPath) &&
              Directory(source.rootPath).existsSync(),
        )
        .toList(growable: false);
  }

  Future<void> _disposeVideoDownloadPipelineRuntime({
    Duration? pipelineDrainTimeout,
  }) async {
  }

  // 注：远端视频播放偏好（调轴/音轨/副字幕源/副字幕调轴）不再走本层门面——统一
  // 落 `video_remote_*_` prefs 键对（播放偏好同步泛化批，键定义在
  // fushi_library_host_service.dart，页面直用 prefsRepo.getPref/setPref）。

  bool get reverseNavigationBar => prefsRepo.reverseNavigationBar;
  void toggleReverseNavigationBar() => prefsRepo.toggleReverseNavigationBar();

  bool get reverseReaderBottomBar => prefsRepo.reverseReaderBottomBar;
  void toggleReverseReaderBottomBar() =>
      prefsRepo.toggleReverseReaderBottomBar();

  /// Requests for full external storage permissions. Required to handle video
  /// files and their subtitle files in the same directory.
  ///
  /// **只申请存储权限，不碰相机**（BUG-1209）。本函数的全部调用点都是「选扫描根 /
  /// 选文件 / 改下载目录」（`media/import/real_path_directory_picker.dart`），它们只需要
  /// 读盘。此前这里顺带 `requestCameraPermission()`：用户理解不了选个文件夹为什么要给
  /// 相机，合理反应是拒绝，而在同一串权限流程里拒绝很可能把本该给的存储权限一起否掉
  /// ——于是「加了扫描根却扫不出东西」。
  ///
  /// 相机是另一件事，归真正需要相机的入口自己申请：当前唯一的相机消费方
  /// `creator/enhancements/camera_enhancement.dart` 走 image_picker 的 `ImageSource.camera`
  /// 系统拍照 intent，而 `AndroidManifest.xml` 并未声明 `android.permission.CAMERA`，
  /// 该 intent 本就不需要运行时权限，故它从来没有、也不需要调这里。
  ///
  /// 早退门同样只看存储：旧版的 `&& hasCameraPermission()` 在安卓上恒为 false
  /// （CAMERA 未在 manifest 声明 → permission_handler 直接判 denied），使得存储已授权时
  /// 也永远走不进早退分支。
  Future<void> requestExternalStoragePermissions() async {
    // Kitapsen declares no storage permissions: file imports go through the
    // system picker (SAF / Files), which needs none, so never ask.
    return;
  }

  /// Whether or not the media item should be killed upon exit.
  bool _shouldKillMediaOnPop = false;

  /// A helper function for launching a media source.
  Future<void> openMedia({
    required WidgetRef ref,
    required MediaSource mediaSource,
    bool killOnPop = false,
    bool pushReplacement = false,
    MediaItem? item,
    Bookmark? initialBookmarkJump,
    bool recordHistory = true,
    bool waitUntilClosed = true,
    Widget Function()? launchPageBuilder,
  }) async {
    // 已迁移只读态（Fushi 迁移 P1-4b）：单闸门挡掉全部媒体打开路径——进度/
    // 统计/制卡的所有写点都在媒体页内，媒体不开则写路径整体不可达（好过在
    // 每个写点各加一个特例分支）。老版此时只保留「重新导出」通道。
    if (isMigrationReadonly) {
      FushiToast.show(msg: t.migration_readonly_note);
      return;
    }
    _shouldKillMediaOnPop = true;

    mediaSource.clearExtraData();

    _currentMediaSource = mediaSource;
    _currentMediaItem = item;
    // TODO-1375：把「媒体已打开」推给可靠通知源，让 macOS 根 sidebar 隐藏（阅读全宽）。
    mediaOpenNotifier.value = true;

    _overrideDictionaryColor = null;

    if (ReaderFushiSource.instance.keepScreenAwake) {
      try {
        await WakelockPlus.enable();
      } catch (e) {
        debugPrint('[Fushi] wakelock enable failed: $e');
      }
    }
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    if (recordHistory && item != null && mediaSource.implementsHistory) {
    }

    final ctx = _ctx;
    if (ctx == null || !ctx.mounted) return;
    final Future<dynamic> routeDone;
    if (pushReplacement) {
      routeDone = Navigator.pushReplacement(
        ctx,
        adaptivePageRoute(
          context: ctx,
          builder: (context) =>
              launchPageBuilder?.call() ??
              mediaSource.buildLaunchPage(
                item: item,
                initialBookmarkJump: initialBookmarkJump,
              ),
        ),
      );
    } else {
      routeDone = Navigator.push(
        ctx,
        adaptivePageRoute(
          context: ctx,
          builder: (context) =>
              launchPageBuilder?.call() ??
              mediaSource.buildLaunchPage(
                item: item,
                initialBookmarkJump: initialBookmarkJump,
              ),
        ),
      );
    }
    if (waitUntilClosed) {
      await routeDone;
    } else {
      unawaited(routeDone);
    }
  }

  /// Ends a media session and ensures that values are reset.
  Future<void> closeMedia({
    required WidgetRef ref,
    required MediaSource mediaSource,
    MediaItem? item,
  }) async {

    mediaSource.setShouldGenerateImage(value: true);
    mediaSource.setShouldGenerateAudio(value: true);
    mediaSource.clearExtraData();
    _currentMediaSource = null;
    _currentMediaItem = null;
    // TODO-1375：把「媒体已关闭」推给可靠通知源，保证退出阅读器后 macOS 根 sidebar
    // 必然重建恢复（不再依赖碰巧有别的 notifyListeners 触发 builder 重跑）。
    mediaOpenNotifier.value = false;
    _overrideDictionaryColor = null;
    try {
      await WakelockPlus.disable();
    } catch (e) {
      debugPrint('[Fushi] wakelock disable failed: $e');
    }
    // Returning to the home/menu shell: hide the Android status bar again
    // (TODO-097) instead of plain edge-to-edge. iOS/desktop unchanged.
    await setHomeShellSystemUiMode();
    await mediaSource.onSourceExit(
      appModel: this,
      ref: ref,
    );


    mediaSource.mediaType.refreshTab();

    if (_shouldKillMediaOnPop) {
    }
  }

  Future<void> deleteMediaItem(MediaItem item) async {
    MediaSource mediaSource = item.getMediaSource(appModel: this);
    await mediaSource.clearOverrideValues(appModel: this, item: item);
    await mediaSource.onMediaItemClear(item);
    await mediaHistoryRepo.deleteMediaItemById(item);
  }

  /// For a given [MediaType], return the selected media source. If there is
  /// no persisted media source, use the first source in the list.
  MediaSource getCurrentSourceForMediaType({
    required MediaType mediaType,
  }) {
    MediaSource fallbackSource = mediaSources[mediaType]!.values.first;
    String uniqueKey = _getPref('current_source/${mediaType.uniqueKey}',
        defaultValue: fallbackSource.uniqueKey);

    return mediaSources[mediaType]![uniqueKey] ?? fallbackSource;
  }

  // ── 进程级常驻有声书会话编排（TODO-291 阶段2） ─────────────────────────

  // TODO-861②：是否扫描非日文文本（选区/查词）。默认 true，向后兼容。
  bool get scanNonJapaneseText => prefsRepo.scanNonJapaneseText;

  void setDictionaryFontSize(double fontSize) =>
      prefsRepo.setDictionaryFontSize(fontSize);

  bool get popupInstantScroll => prefsRepo.popupInstantScroll;

  bool get isFirstTimeSetup => prefsRepo.isFirstTimeSetup;
  void setFirstTimeSetupFlag() => prefsRepo.setFirstTimeSetupFlag();

  bool get onboardingCompleted => prefsRepo.onboardingCompleted;
  Future<void> setOnboardingCompleted({required bool value}) =>
      prefsRepo.setOnboardingCompleted(value: value);

  /// 「功能模块」用户意愿的读写。**平台判据不在这里**——见 [moduleVisibility]。
  ///
  /// 偏好仓库还没装配好时**一律判开**（fail-open）。模块门控读得比 `initialise()`
  /// 早：设置 schema 的 `visible` 谓词同时喂渲染与搜索索引，展平索引这条路径在弹窗
  /// 词典入口与纯 widget 测试里都会撞上一个未初始化的 AppModel。裸 `prefsRepo!` 会
  /// 在那里抛 null check——而「读不到用户意愿」的安全方向是全都显示，不是把整个设置
  /// 页藏掉（与 module_registry 里「漏写映射默认恒在」同一个方向）。
  bool moduleEnabled(ModuleId module) =>
      isPreferencesReady ? prefsRepo.moduleEnabled(module) : true;

  Future<void> setModuleEnabled(ModuleId module, bool value) async {
    await prefsRepo.setModuleEnabled(module, value);
    // 设置 schema 树按 locale 记忆化，两张投影表（阅读器/视频快捷面板）也惰性缓存。
    // 模块可见性会改变这些树的过滤结果，故翻转开关必须丢弃快照，否则快捷面板会
    // 继续发已被关掉模块的设置项（settings_schema.dart 的 `_SettingsSchemaCache`）。
    resetSettingsSchemaCache();
    notifyListeners();
  }

  /// 「此刻哪些模块可见」——pref 真值与平台判据的**唯一合成**。
  ///
  /// 全 app 的门控一律读它。此前底栏与 macOS 侧栏各手抄一份七参表，`games` 的
  /// `Platform.isWindows` 判据抄了两遍、漏了一遍（macOS 那份靠缺省值蒙对）。
  ///
  /// 平台判据取自 [PlatformServices]（那是本类「不必知道自己跑在哪个平台」的出口），
  /// 不再直读 `dart:io` —— 直读会让 widget 测试无缝可注，Windows 独有的模块
  /// （galgame）在 Linux CI 上被静默滤掉而本机全绿。
  ModuleVisibility get moduleVisibility => ModuleVisibility.resolve(
        prefOf: moduleEnabled,
        isWindows: platformServices.isWindows,
        isDesktop: platformServices.isDesktop,
        isIOS: platformServices.isIOS,
        isAndroid: platformServices.isAndroid,
      );

  /// Check if the database is still open.
  bool get isDatabaseOpen => _isInitialised;

  /// Direct access to the Drift database instance.
  FushiDatabase get database => _database;

  /// Close the database and notify listeners, without exiting the app.
  /// BUG-1505：关库**之前**把后台写手停掉。
  ///
  /// `closeDatabase()` 只关连接，不停任何人。下载流水线这类常驻 drain 循环仍在跑，
  /// 于是关库后每次唤醒都撞上 drift 的
  /// 「Tried to send Request ... over isolate channel, but the connection was
  /// closed!」——用户机器上实测一次迁移导入刷出 8 条。它至少污染诊断日志（真正的
  /// 失败原因被淹没），更糟的是合并导入正在直接操作同一个库文件，此时放任第二个
  /// 写手继续往里写是数据安全问题，不是噪声问题。
  ///
  /// 只停「后台自己会写库」的那几个（下载/订阅/漫画队列），不碰查词、TTS 这类只读
  /// 子系统：closeDatabase 之后调用方一律走重启，停多了没收益、只增加爆炸半径。
  ///
  /// [pipelineDrainTimeout] 只在**退出路径**给：见
  /// [VideoDownloadPipelineService.stop] 的注释——迁移导入 / 备份导入 / 数据根迁移
  /// 也走这条链，它们在关库后要在文件层动整个 DB 目录，放行一个仍在飞的 `_process`
  /// 会让它继续打已关闭的连接、并被随后的 `_videoDownloadBackend?.close()` 抽掉
  /// 句柄。那些路径必须等到真收尾。
  Future<void> quiesceBackgroundDatabaseWriters({
    Duration? pipelineDrainTimeout,
  }) async {
    await _disposeVideoDownloadPipelineRuntime(
      pipelineDrainTimeout: pipelineDrainTimeout,
    );
  }

  Future<void> closeDatabase({Duration? pipelineDrainTimeout}) async {
    _isInitialised = false;
    databaseCloseNotifier.notifyListeners();
    await quiesceBackgroundDatabaseWriters(
      pipelineDrainTimeout: pipelineDrainTimeout,
    );
    await _database.close();
  }

  @override
  void dispose() {
    _prefsRepo?.removeListener(notifyListeners);
    if (_themeListenerAdded) {
      themeNotifier.removeListener(notifyListeners);
      themeNotifier.dispose();
      _themeListenerAdded = false;
    }
    dictionaryEntriesNotifier.dispose();
    dictionarySearchAgainNotifier.dispose();
    dictionaryMenuNotifier.dispose();
    incognitoNotifier.dispose();
    databaseCloseNotifier.dispose();
    homeDictionaryTabRequest.dispose();
    mediaOpenNotifier.dispose();
    gamepadService.dispose();
    // Dispose the extracted repository notifiers (all ChangeNotifiers). Only
    // when fully initialised — a failed/partial init leaves these `late`
    // fields unassigned, and reading them would throw.
    _prefsRepo?.dispose();
    if (_isInitialised) {
      mediaHistoryRepo.dispose();
    }
    super.dispose();
  }

  // TODO-1046: daily/weekly reading goals (characters). 0 = unset/off; the
  // statistics page hides the goal card. Delegated to prefsRepo.
  int get readingGoalDailyChars => prefsRepo.readingGoalDailyChars;
  Future<void> setReadingGoalDailyChars(int value) =>
      prefsRepo.setReadingGoalDailyChars(value);

  /// v92 阅读空闲门（分钟 / Duration 两种形态；阅读器建 StudyClock 时取后者）。
  /// 偏好层未就绪（精简初始化路径 / 测试 harness）时回落默认 10 分钟——阅读器
  /// 建时钟绝不能因为一个可选偏好没加载而整页崩掉。
  int get readingIdleTimeoutMinutes =>
      _prefsRepo?.readingIdleTimeoutMinutes ??
      kDefaultReadingIdleTimeout.inMinutes;
  Duration get readingIdleTimeout =>
      Duration(minutes: readingIdleTimeoutMinutes);
  Future<void> setReadingIdleTimeoutMinutes(int value) =>
      prefsRepo.setReadingIdleTimeoutMinutes(value);

  /// 统计「今日」重置时刻（整点）。偏好层未就绪时回落 0（本地午夜）。
  int get statDayResetHour => _prefsRepo?.statDayResetHour ?? 0;
  Future<void> setStatDayResetHour(int value) async {
    await prefsRepo.setStatDayResetHour(value);
    _applyStatDayResetHour();
  }

  /// 把偏好镜像到 [FushiDatabase.statDayResetHour]——dateKey 派生的唯一输入。
  /// 偏好加载后（主进程 / 弹窗进程两条初始化路径）与用户改设置时各调一次。
  void _applyStatDayResetHour() {
    FushiDatabase.statDayResetHour = statDayResetHour;
  }

  int get readingGoalWeeklyChars => prefsRepo.readingGoalWeeklyChars;
  Future<void> setReadingGoalWeeklyChars(int value) =>
      prefsRepo.setReadingGoalWeeklyChars(value);

  /// 实验性：整套键盘/手柄焦点导航是否启用（默认 false）。关闭时 main.dart 不安装
  /// FushiFocusRoot/Ring，App 回退到 Flutter 原生焦点遍历。
  bool get experimentalFocusNavigationEnabled =>
      prefsRepo.experimentalFocusNavigationEnabled;

  // ── 可视化样式规则 ───────────────────────────────────────────────────
  //
  // 上面两个 getter 是**用户手写的原文**，编辑器要拿它回填文本框，绝不能混进
  // 编译产物。下面的 effective* 才是注入弹窗的最终值（产物在前、手写在后）。

  // ── 浏览器扩展「试一试」页 ───────────────────────────────────────────

  // ── UI visibility (delegated) ────────────────────────────────────────

  bool get showMediaNotification => prefsRepo.showMediaNotification;

  bool get showFloatingLyric => prefsRepo.showFloatingLyric;

  double get floatingLyricFontSize => prefsRepo.floatingLyricFontSize;

  bool get floatingLyricClickLookup => prefsRepo.floatingLyricClickLookup;

  String get updateCustomProxy => prefsRepo.updateCustomProxy;
  Future<void> setUpdateCustomProxy(String value) async {
    await prefsRepo.setUpdateCustomProxy(value);
  }

  String get networkProxyMode => prefsRepo.networkProxyMode;
  Future<void> setNetworkProxyMode(String value) async {
    await prefsRepo.setNetworkProxyMode(value);
  }

  String get networkProxyUsername => prefsRepo.networkProxyUsername;
  Future<void> setNetworkProxyUsername(String value) async {
    await prefsRepo.setNetworkProxyUsername(value);
  }

  String get networkProxyPassword => prefsRepo.networkProxyPassword;
  Future<void> setNetworkProxyPassword(String value) async {
    await prefsRepo.setNetworkProxyPassword(value);
  }

  // ── low memory mode (side effect stays here) ─────────────────────────

  bool get lowMemoryMode => prefsRepo.lowMemoryMode;

  Future<void> setLowMemoryMode(bool v) async {
    await prefsRepo.setPref('low_memory_mode', v);
    _applyMemoryPolicy();
    notifyListeners();
  }

  void _applyMemoryPolicy() {
    final imageCache = PaintingBinding.instance.imageCache;
    if (lowMemoryMode) {
      imageCache.maximumSize = 50;
      imageCache.maximumSizeBytes = 20 << 20; // 20 MB
    } else {
      imageCache.maximumSize = 1000;
      imageCache.maximumSizeBytes = 100 << 20; // 100 MB
    }
    // 诊断（2026-09-22）：小内存模式是用户用来换取视频不卡的那个开关，代价落在查词
    // 上。把它当前的**实际**预算记进时间轴，排查时不必再反推用户开了什么——三级词典
    // 缓存的预算由 [DictionaryRepository] 按同一个 isLowMemory 闭包决定，热槽与停驻
    // realm 则由 [DictionaryPopupController] 按同一个标志决定。
    // Kitapsen has no video diagnostics log.
    return;
  }
}
