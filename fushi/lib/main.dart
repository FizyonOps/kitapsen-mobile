import 'dart:async';
import 'dart:io';
import 'dart:ui'
    show PlatformDispatcher;
import 'package:fushi/src/pages/implementations/kitapsen_store/kitapsen_sample.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_logs/flutter_logs.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:receive_intent/receive_intent.dart' as intents;
import 'package:stack_trace/stack_trace.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:fushi/models.dart';
import 'package:fushi/src/models/theme_notifier.dart'
    show buildFushiFallbackTheme;
import 'package:fushi/pages.dart';
import 'package:fushi/src/focus/fushi_focus_controller.dart';
import 'package:fushi/src/utils/components/current_app_icon.dart';
import 'package:fushi/src/utils/misc/channel_constants.dart';
import 'package:fushi/src/utils/misc/flutter_error_log.dart';
import 'package:fushi/src/utils/misc/smooth_wheel_scroll.dart';
import 'package:fushi/utils.dart';
import 'package:fushi/src/shortcuts/global_navigation.dart';
import 'package:fushi/src/stats/study_diag_log.dart';
import 'package:fushi_audio/fushi_audio.dart' show StudyClock;
import 'package:fushi/src/startup/loading_watchdog_view.dart';
import 'package:fushi/src/startup/webview_prewarm.dart';
import 'package:fushi/src/startup/exit_flush_registry.dart';
import 'package:fushi/src/startup/android_view_lifecycle.dart';
import 'package:fushi/src/platform/platform_services.dart';
import 'package:fushi/src/platform/app_shortcuts.dart';
import 'package:fushi/src/platform/app_shortcut_router.dart';
import 'package:fushi/src/platform/platform_providers.dart';
import 'package:fushi/src/platform/ios/ios_url_event_channel.dart';
import 'package:fushi_core/fushi_core.dart'
    show FushiDatabaseFailureKind;
import 'package:fushi/src/utils/misc/fushi_share.dart';
import 'package:fushi/src/engine_bindings.dart';

Color? _savedSplashColor;

/// 桌面端「从 app 外打开视频文件」时，runner 经 `set_dart_entrypoint_arguments`
/// 把视频路径传进 `main(List<String> args)`；这里暂存，待 app 初始化完成后由
/// [_FushiReaderAppState] 打开播放页并加入书架。null 表示本次启动不是外部打开视频。
String? _pendingExternalVideoPath;

/// BUG-1666：桌面端 `fushi://lookup?word=<词>` 深链（Anki 卡片上的词典交叉引用）
/// 冷启动时从 `main(args)` 暂存待查词；app 初始化完成后由 [_FushiReaderAppState]
/// 经 [DesktopLookupService.triggerLookup] 排队查词。null = 本次启动非深链查词。
String? _pendingLookupDeepLinkWord;
final List<String> _pendingCardSourceUrls = <String>[];

/// Single source of truth for the status/navigation bar overlay style.
///
/// Maps an app [brightness] to the matching system bar icon brightness while
/// keeping both bars transparent + uncontrasted for edge-to-edge layout. Used
/// both at startup (keyed off the platform brightness, to avoid a white flash
/// before init) and at runtime via an [AnnotatedRegion] keyed off the live
/// theme brightness, so the system navigation bar follows in-app theme
/// switches instead of being frozen at the launch-time platform brightness.
SystemUiOverlayStyle fushiSystemOverlayStyle(Brightness brightness) {
  // A dark app surface needs light (bright) bar icons; a light surface needs
  // dark icons. We set the icon brightnesses *explicitly* rather than reuse
  // SystemUiOverlayStyle.light/.dark, because both of those presets hardcode
  // systemNavigationBarIconBrightness: Brightness.light (they assume an opaque
  // black nav bar). With our transparent edge-to-edge nav bar that would leave
  // the gesture pill / buttons light on a light theme — invisible, and frozen
  // across theme switches.
  final iconBrightness =
      brightness == Brightness.dark ? Brightness.light : Brightness.dark;
  return SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: iconBrightness,
    // iOS: statusBarBrightness is the *background* brightness behind the bar.
    statusBarBrightness: brightness,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: iconBrightness,
    systemNavigationBarContrastEnforced: false,
  );
}

/// Application execution starts here.
///
/// [args] are the Dart entrypoint arguments. On Windows the runner forwards the
/// process argv (minus the binary name) via `set_dart_entrypoint_arguments`, so
/// opening a video with Hibiki (file association / drag-onto-exe / CLI) lands the
/// video path here. We stash the first supported video path for the widget tree
/// to act on once the app has finished initialising.
void main([List<String> args = const <String>[]]) {

  /// Run and handle an error zone to customise the action performed upon
  /// an error or exception. This allows for error logging for debug purposes
  /// as well as communicating errors to Crashlytics if enabled.
  runZonedGuarded<Future<void>>(() async {
    /// Necessary to initialise Flutter when running native code before
    /// starting the application.
    final binding = WidgetsFlutterBinding.ensureInitialized();
    // Engine log / paths / image-cache hooks, installed before anything
    // touches the engine packages.
    installEngineHostBindings();

    /// Ensure no pop-in for the app icon. Precaching is a best-effort
    /// optimisation: if the decode fails (e.g. the CI software-GPU emulator
    /// can't decompress the PNG → "Could not decompress image", or low memory),
    /// it must NOT surface as an unhandled FlutterError — that would both spam
    /// error reporting on real devices and fail the appSmoke integration test.
    /// Swallow it via precacheImage's onError; the icon just falls back to a
    /// one-frame decode-on-demand later.
    binding.addPostFrameCallback((_) async {
      final context = binding.rootElement;
      if (context != null) {
        precacheImage(
          const AssetImage(kAppIconAsset),
          context,
          onError: (Object error, StackTrace? stack) {
            debugPrint('[startup] app icon precache skipped: $error');
          },
        );
      }
    });

    /// Ensure wake prevention is disabled if not reverted from entering a
    /// media source.  WakelockPlus supports all desktop and mobile platforms,
    /// so clear it unconditionally; the try-catch handles unsupported targets.
    try {
      WakelockPlus.disable();
    } catch (e) {
      debugPrint('[Fushi] wakelock disable on startup failed: $e');
    }
    // Home/menu shell: hide the Android status bar (keep the nav bar) so the
    // always-on OS clock/battery strip stops crowding the top-right action
    // icons (TODO-097). iOS keeps edge-to-edge. Reader/video override this with
    // immersiveSticky on open and restore it via closeMedia on exit.
    unawaited(setHomeShellSystemUiMode());

    // Match system bar overlays to the platform brightness immediately so the
    // status bar and navigation bar don't flash white on dark-mode devices.
    final platformBrightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    SystemChrome.setSystemUIOverlayStyle(
      fushiSystemOverlayStyle(platformBrightness),
    );

    try {
      final raw =
          await FushiChannels.splash.invokeMethod<int>('getSplashColor');
      if (raw != null && raw != 0) _savedSplashColor = Color(raw);
    } catch (e) {
      debugPrint('[Fushi] getSplashColor failed: $e');
    }

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    /// Some packages propagate their [StackTrace] in an unusual format as
    /// opposed to the format generated by Dart. This function allows the
    /// Flutter framework to handle such formats so they can be displayed
    /// appropriately.
    FlutterError.demangleStackTrace = (stack) {
      if (stack is Trace) {
        return stack.vmTrace;
      }
      if (stack is Chain) {
        return stack.toTrace().vmTrace;
      }
      return stack;
    };

    /// Construct platform-specific service implementations once, before the
    /// provider container is created.  This value object is injected into both
    /// [platformServicesProvider] (for widget-layer access) and [AppModel]
    /// (via [appProvider]).
    final platformServices = PlatformServices.forCurrentPlatform();

    /// Create the provider container before running the app so the same
    /// [AppModel] instance is shared between the widget tree and the
    /// initialisation call below.
    final container = ProviderContainer(
      overrides: [
        platformServicesProvider.overrideWithValue(platformServices),
      ],
    );

    /// Start the application immediately so the user sees the loading page
    /// rather than a blank white screen while initialisation is in progress.
    runApp(
      UncontrolledProviderScope(
        container: container,
        child: const FushiReaderApp(),
      ),
    );

    /// Initialise error log service.
    await ErrorLogService.instance.init();
    // 统计诊断流水（用户 2026-09-12：导出日志排查阅读速度异常）。StudyClock 在
    // fushi_audio 包里，靠静态 sink 接进来——五个装配点一处不改。
    await StudyDiagLog.instance.init();
    StudyClock.trace = (String line) => StudyDiagLog.instance.add('clock', line);
    await DebugLogService.instance.init();

    /// Initialise local file-based logging (mobile only).
    await FlutterLogs.initLogs(
      logLevelsEnabled: [
        LogLevel.INFO,
        LogLevel.WARNING,
        LogLevel.ERROR,
        LogLevel.SEVERE
      ],
      timeStampFormat: TimeStampFormat.DATE_FORMAT_1,
      directoryStructure: DirectoryStructure.FOR_DATE,
      logTypesEnabled: ['device', 'network', 'errors'],
      logFileExtension: LogFileExtension.LOG,
      logsRetentionPeriodInDays: 7,
    );

    final appModel = container.read(appProvider);
    await appModel.initialise();
    // Kitapsen: a reading sample the app was killed on is still on the shelf.
    unawaited(removeKitapsenSample(appModel.database));

    // ── 预热 WebView 引擎 ──────────────────────────────────────────────
    // 用户还在看主页/书架时就把冷启动成本吃掉：~500-1500ms。
    // 移动端可直接预热；桌面端（WebView2）必须等首帧渲染、Flutter view
    // 已挂载后再构造 HeadlessInAppWebView，否则会崩 WebView2。


    final bool isMobilePlatform = Platform.isAndroid || Platform.isIOS;
    if (shouldPrewarmWebView(
      isMobile: isMobilePlatform,
      isDesktop: false,
      lowMemory: appModel.lowMemoryMode,
    )) {
      unawaited(Future(() async {
        // 预热持有的是进程级资源（一个 headless WebView = 一个 chromium
        // renderer 子进程），销毁必须有确定终点，不能只挂在 onLoadStop 这条
        // 成功路径上：回调不来就是永久泄漏一个 renderer，而 renderer 被 OOM
        // kill 且 onRenderProcessGone 无人接管时，Android 默认会连整个 app
        // 进程一起杀（CI Android appSmoke 连续 4 次死于此）。终点交给
        // WebViewPrewarmSession 收口：载入完成 / 载入失败 / renderer 死亡 /
        // 超时兜底，先到者胜、只 dispose 一次。
        late final HeadlessInAppWebView warmup;
        final WebViewPrewarmSession session = WebViewPrewarmSession(
          disposeWebView: () => warmup.dispose(),
          onFinished: (String reason) =>
              debugPrint('[Fushi] WebView engine pre-warm ended: $reason'),
        );
        try {
          warmup = HeadlessInAppWebView(
            initialUrlRequest: URLRequest(url: WebUri('about:blank')),
            onLoadStop: (controller, url) async {
              // 100ms 让 onLoadStop 的回调栈先出栈再销毁：这是原实现就有的
              // 保守做法（桌面 WebView2 上在回调里同步 dispose 曾不稳），
              // 不是等待载入的重试窗口——真正的终点保证在 session 那边。
              await Future.delayed(const Duration(milliseconds: 100));
              await session.finish('loaded');
            },
            onReceivedError: (controller, request, error) =>
                session.finish('load error: ${error.type}'),
            // 接管 renderer 死亡：Android 侧只要注册了这个回调，
            // InAppWebViewClient 就返回 true，chromium 不再连坐杀 app 进程。
            onWebContentProcessDidTerminate: (controller) =>
                session.finish('webkit content process terminated'),
            onRenderProcessGone: (controller, detail) =>
                session.finish('renderer gone (didCrash=${detail.didCrash})'),
          );
          await warmup.run();
          session.armTimeout();
        } catch (e) {
          debugPrint('[Fushi] WebView warmup failed (non-fatal): $e');
          await session.finish('run failed: $e');
        }
      }));
    }


    // galgame helper 与 Magpie 都只从 Windows 主包随附归档安装（BUG-1196 / BUG-1292）。
    // 版本与 app 强绑定：要新组件就更新 Hibiki。不要恢复后台静默下载或旧包联网兜底。

    /// Capture Flutter framework errors with full details.
    FlutterError.onError = (details) {
      // Suppress known Flutter framework bug: RawTooltipState creates
      // multiple tickers from SingleTickerProviderStateMixin.
      final msg = details.exceptionAsString();
      if (msg.contains('SingleTickerProviderStateMixin') &&
          msg.contains('RawTooltipState')) {
        return;
      }
      FlutterError.presentError(details);
      // BUG-2496：框架自己标 `silent: true` 的错误（图片解码失败等
      // `MultiFrameImageStreamCompleter` 上报的非致命错误）不是崩溃前兆，
      // 只留诊断痕迹（不计入错误计数、不同步 flush），别把一张坏封面记成致命错误。
      if (details.silent) {
        ErrorLogService.instance.logDiagnostic(
          flutterErrorLogSource(details),
          '$msg\n${details.stack}',
        );
        return;
      }
      // TODO-607 P0-1：FlutterError 是致命级，用同步 flush 落盘——若这条错误紧接着把
      // 进程带崩（如 build/layout 期的 native 回调异常），异步 append 来不及写盘。
      ErrorLogService.instance.logFatal(
        flutterErrorLogSource(details),
        msg,
        details.stack,
      );
    };

    /// TODO-607 P0-1：平台/引擎层未捕获的异步错误（platform message handler、
    /// 原生回调、microtask 等）不经 [FlutterError.onError] 也不一定经
    /// [runZonedGuarded] 的 onError——它们走 [PlatformDispatcher.onError]。此前没装
    /// 这个钩子，这类错误对错误日志完全不可见（用户报「错误日志一片空白」的一类
    /// 来源）。装上后用同步 flush 落盘（致命级），返回 true 标记「已处理」，避免
    /// 引擎把它再当未处理崩溃上报。
    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      ErrorLogService.instance.logFatal('PlatformDispatcher', error, stack);
      return true;
    };
  }, (exception, stack) {
    /// Print error details to the console.
    final details = FlutterErrorDetails(exception: exception, stack: stack);

    /// Log the error. UncaughtZone 是致命级（zone 顶层未捕获），同步 flush 落盘
    /// （TODO-607 P0-1）——这条之后进程往往就终止了，异步 append 来不及写盘。
    ErrorLogService.instance.logFatal('UncaughtZone', exception, stack);
    FlutterLogs.logError(
      'fushi_reader',
      details.exceptionAsString(),
      stack.toString(),
    );
  });
}

/// Encapsulates theming, spacing and other configurable options pertaining to
/// the entire app, with some parameters dependent on the [AppModel].
class FushiReaderApp extends ConsumerStatefulWidget {
  /// Initialises an instance of the app.
  const FushiReaderApp({super.key});

  @override
  ConsumerState<FushiReaderApp> createState() => _FushiReaderAppState();
}

class _FushiReaderAppState extends ConsumerState<FushiReaderApp>
    with WidgetsBindingObserver {
  StreamSubscription? _intentsSubscription;

  /// 初始化完成后补发一次待发制卡 / 补一次 Anki 同步（桌面冷启动不一定有
  /// resumed 生命周期事件）。只触发一次。
  bool _startupPendingMinesFlushed = false;

  /// 长按 app 图标点下的快捷方式（`fushi://shortcut/<id>`）。冷启动时 URL 比
  /// `initialise()` 先到，而 HomePage.initState 会把 [homeShellTabNotifier]
  /// 重置成启动 tab，所以先排队，等 home 挂载后的首帧再落地。
  late final AppShortcutQueue _appShortcuts = AppShortcutQueue(
    isActive: () => mounted,
    run: _runAppShortcut,
  );
  bool _sourceNavigationScheduled = false;

  /// 守卫：`detached` 退出清理只跑一次。
  bool _shutdownStarted = false;

  final AndroidViewLifecycle _androidViewLifecycle = AndroidViewLifecycle();

  /// TODO-1260：启动加载「看门狗」。裸 loading 分支（[!appModel.isInitialised]）此前只有
  /// 一个**无超时**的 [CircularProgressIndicator]——若 `initialise()` 因某早期 IO（掉线
  /// 数据根盘的 stat / 目录创建）永不返回，就无限转圈、无任何逃生口（TODO-1260「偶发
  /// 无限加载」根因之一）。看门狗在进入裸加载态时启动，超过 [_loadingWatchdogTimeout]
  /// 仍未初始化完成就翻 [_loadingTimedOut]，加载分支改渲染「耗时超预期 + 说明 + 重试」
  /// 逃生 UI，消除「无 escape」的结构缺陷（Layer 1/2 的数据根超时降级是主修，这层是
  /// 兜底：任何未预见的启动挂起都有可点的出口，而非死转圈）。
  static const Duration _loadingWatchdogTimeout = Duration(seconds: 20);
  Timer? _loadingWatchdog;
  bool _loadingTimedOut = false;

  StreamSubscription<String>? _iosUrlSubscription;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    if (Platform.isAndroid) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        intents.ReceiveIntent.getInitialIntent().then(
          (intent) => handleIntent(
            intent: intent,
            isInitial: true,
          ),
        );
        _intentsSubscription =
            intents.ReceiveIntent.receivedIntentStream.listen(
          (intent) => handleIntent(
            intent: intent,
            isInitial: false,
          ),
        );
      });
    }
    if (Platform.isIOS) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        IosUrlEventChannel.getInitialUrl().then(
          (url) => handleIncomingUrl(
            data: url,
            isInitial: true,
          ),
        );
        _iosUrlSubscription = IosUrlEventChannel.urls.listen(
          (url) => handleIncomingUrl(
            data: url,
            isInitial: false,
          ),
        );
      });
    }
  }

  /// BUG-2459：引擎默认 deep linking 会把 `fushi://ankiFetch` 这类 x-callback
  /// 回跳再推成 `pushRouteInformation`，`WidgetsApp` 据此 `pushNamed('/')` 在
  /// 设置页上面又压一个 HomePage（用户看到「跳回主页」）。本 observer 在
  /// `WidgetsApp` 之前注册，先答 true 把这条推送截断；真正的 URL 处理仍由各平台
  /// 通道送进 [handleIncomingUrl]。理由与边界见 [swallowEngineDeepLinkRoute]。
  @override
  Future<bool> didPushRouteInformation(RouteInformation routeInformation) async {
    return true;
  }

  /// 回到前台补发待发制卡队列：桌面 / Android 上连续补发；AnkiMobile 只有在用户
  /// 点过「全部发送」的会话里才发下一张（每张卡 `x-success` 跳回都会走到这里）。
  void _flushPendingMines() {
    return;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(appProvider).refreshSystemPalette();
      return;
    }
    if (Platform.isAndroid) {
      // BUG-2280: AudioServiceActivity can detach while its cached engine
      // survives. A new Activity must retain that engine's DB and services.
      unawaited(_androidViewLifecycle.handleState(state));
      return;
    }
    // `detached` = the app is about to be terminated (the engine is detaching
    // from the view). Best-effort: the framework does not await this callback.
    if (state == AppLifecycleState.detached) {
      unawaited(_flushAndCloseForLifecycleDetach());
    }
  }

  /// Flushes the active pages and closes the database on the `detached`
  /// lifecycle state (iOS; an Android view detaching does not end the engine).
  Future<void> _flushAndCloseForLifecycleDetach() async {
    if (_shutdownStarted) return;
    _shutdownStarted = true;
    final AppModel appModel = ref.read(appProvider);
    try {
      await ExitFlushRegistry.instance.flushAll();
    } catch (e) {
      debugPrint('[Fushi] lifecycle detach flush failed: $e');
    }

    try {
      await appModel.closeDatabase();
    } catch (e) {
      debugPrint('[Fushi] database close on lifecycle detach failed: $e');
    }
  }

  @override
  void dispose() {
    _intentsSubscription?.cancel();
    _iosUrlSubscription?.cancel();
    _loadingWatchdog?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void handleIntent({
    required intents.Intent? intent,
    required bool isInitial,
  }) async {
    if (intent == null || !mounted) {
      return;
    }

    final String? data = intent.data;
    if (await handleIncomingUrl(data: data, isInitial: isInitial)) {
      return;
    }

    switch (intent.action) {
      case 'android.intent.action.MAIN':
        setState(() {
        });
        return;
    }
  }

  Future<bool> handleIncomingUrl({
    required String? data,
    required bool isInitial,
  }) async {
    if (data == null || !mounted) return false;
    // iOS：快捷指令 / 其它 app 打开的 `fushi://lookup?word=` 交给应用内查词弹窗
    // （Android 的这条链接由 manifest 直接路由到 :popup 查词窗，到不了这里；
    // Windows 走 argv / WM_COPYDATA，见 [lookupWordFromDeepLink]）。
    return false;
  }

  Future<void> _runAppShortcut(AppShortcut shortcut) {
    final AppModel appModel = ref.read(appProvider);
    return runAppShortcut(
      shortcut,
      visibility: appModel.moduleVisibility,
      onboardingCompleted: appModel.onboardingCompleted,
      navigator: appModel.navigatorKey.currentState,
      selectHomeTab: (HomeTab tab) => homeShellTabNotifier.value = tab,
      // 用户点「查词」就是要打字：送进搜索框。
      openLookup: () => appModel.requestHomeDictionaryTab(focusSearch: true),
    );
  }

  void _scheduleCardSourceNavigation() {
    if ((_sourceNavigationScheduled) || _pendingCardSourceUrls.isEmpty) {
      return;
    }
    _sourceNavigationScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sourceNavigationScheduled = false;
      if (mounted) unawaited(_drainCardSourceNavigation());
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  Future<void> _drainCardSourceNavigation() async {
    // Kitapsen: card source links come from Anki cards, which it never makes.
    return;
  }

  /// TODO-1260：进入裸加载态时启动看门狗（只挂一个；已翻超时标记则不再重启）。
  void _startLoadingWatchdogIfNeeded() {
    if (_loadingWatchdog != null || _loadingTimedOut) return;
    _loadingWatchdog = Timer(_loadingWatchdogTimeout, () {
      if (mounted) setState(() => _loadingTimedOut = true);
    });
  }

  /// TODO-1260：离开裸加载态（初始化完成 / 落错误屏 / 迁移 / 备份导入遮罩）或用户手动
  /// 重试时取消看门狗并复位，让下一轮加载重新计时、避免过时 timer 空转触发无用 setState。
  void _cancelLoadingWatchdog() {
    _loadingWatchdog?.cancel();
    _loadingWatchdog = null;
    _loadingTimedOut = false;
  }

  @override
  Widget build(BuildContext context) {
    // TODO-1260：只要不再处于「裸加载」态（已初始化 / 已落错误屏 / 迁移或备份导入有自己
    // 的进度遮罩），就撤掉加载看门狗，避免它在这些态里事后空转触发一次无用重建。
    if ((appModel.isInitialised ||
        appModel.initError != null) || appModel.backupImportActive) {
      _cancelLoadingWatchdog();
    }
    // Fields like locales/theme are late and only available
    // after initialise() completes. Return a minimal app while loading and
    // render the startup splash mark directly instead of going through
    // LoadingPage.
    //
    // Use system brightness to match the native splash and avoid a white
    // flash when the user has dark mode enabled.
    // Downgrade protection: the on-disk DB was created by a newer build. Show a
    // dedicated, NON-retryable "update your app" notice (no Retry button —
    // retrying re-runs init and fails identically; the DB is intentionally left
    // untouched). Checked BEFORE the generic init-error screen.
    final downgrade = appModel.downgradeError;
    if (downgrade != null) {
      final brightness =
          WidgetsBinding.instance.platformDispatcher.platformBrightness;
      final ThemeData fallbackTheme = buildFushiFallbackTheme(brightness);
      final ColorScheme cs = fallbackTheme.colorScheme;
      return TranslationProvider(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: fallbackTheme,
          home: Scaffold(
            backgroundColor: _savedSplashColor ?? cs.surface,
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.system_update, size: 48, color: cs.primary),
                    const SizedBox(height: 16),
                    Text(
                      t.db_downgrade_title,
                      style: fallbackTheme.textTheme.titleLarge?.copyWith(
                        color: cs.onSurface,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      t.db_downgrade_message(
                        dbVersion: downgrade.dbVersion,
                        appVersion: downgrade.appSchemaVersion,
                      ),
                      style: fallbackTheme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
    // TODO-905: the DB could not be opened even after WAL/sidecar recovery —
    // the main hibiki.db is corrupt. Show an actionable notice (the recovery
    // ladder already ran inside the open path, so a plain Retry would loop
    // forever against the same un-openable file). Checked BEFORE the generic
    // init-error screen so the user gets the corrupt-DB guidance, not a raw
    // "disk I/O error" with a dead Retry loop.
    final unrecoverable = appModel.unrecoverableDbError;
    if (unrecoverable != null) {
      // BUG-1899：「打不开」不是「坏了」。父目录不存在 / 无权限 / 只读介质 / 盘断链
      // 都会让 sqlite 报 SQLITE_CANTOPEN(14)，此前它们共用「数据库损坏，请恢复备份或
      // 清空数据」这句话——在磁盘完好的情况下把用户往清空数据上引。
      final bool cannotOpen =
          unrecoverable.kind == FushiDatabaseFailureKind.cannotOpen;
      final brightness =
          WidgetsBinding.instance.platformDispatcher.platformBrightness;
      final ThemeData fallbackTheme = buildFushiFallbackTheme(brightness);
      final ColorScheme cs = fallbackTheme.colorScheme;
      return TranslationProvider(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: fallbackTheme,
          home: Scaffold(
            backgroundColor: _savedSplashColor ?? cs.surface,
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                        cannotOpen
                            ? Icons.folder_off_outlined
                            : Icons.broken_image_outlined,
                        size: 48,
                        color: cs.error),
                    const SizedBox(height: 16),
                    Text(
                      cannotOpen
                          ? t.db_cannot_open_title
                          : t.db_unrecoverable_title,
                      style: fallbackTheme.textTheme.titleLarge?.copyWith(
                        color: cs.onSurface,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      cannotOpen
                          ? t.db_cannot_open_message
                          : t.db_unrecoverable_message,
                      style: fallbackTheme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    SelectableText(
                      appModel.initError!,
                      style: fallbackTheme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
    // BUG-815: a custom data location IS configured on desktop but is currently
    // unreachable (slow/sleeping/disconnected drive). AppPaths.resolve threw
    // instead of SILENTLY opening the empty default location — that empty view
    // reads as catastrophic data loss even though the real data sits untouched
    // on the configured drive, and any content created in that empty session
    // would land in the WRONG place. Show a dedicated escape screen that NEVER
    // presents empty-as-real: default action is Retry (re-probe → use the real
    // DB once the drive wakes); an explicit, clearly-worded second button lets
    // the user consciously start with the default location (their data is NOT
    // touched) for the drive-truly-gone case. Checked BEFORE the loading branch.
    final dataRootUnavailable = appModel.dataRootUnavailable;
    if (dataRootUnavailable != null) {
      final brightness =
          WidgetsBinding.instance.platformDispatcher.platformBrightness;
      final ThemeData fallbackTheme = buildFushiFallbackTheme(brightness);
      final ColorScheme cs = fallbackTheme.colorScheme;
      return TranslationProvider(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: fallbackTheme,
          home: Scaffold(
            backgroundColor: _savedSplashColor ?? cs.surface,
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.folder_off_outlined,
                        size: 48, color: cs.primary),
                    const SizedBox(height: 16),
                    Text(
                      t.data_root_unavailable_title,
                      style: fallbackTheme.textTheme.titleLarge?.copyWith(
                        color: cs.onSurface,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      t.data_root_unavailable_message(
                        path: dataRootUnavailable.configuredPath,
                      ),
                      style: fallbackTheme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        FilledButton.icon(
                          icon: const Icon(Icons.refresh, size: 18),
                          label: Text(t.retry),
                          onPressed: () => appModel.retryInitialise(),
                        ),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.folder_open, size: 18),
                          label: Text(t.data_root_use_default_button),
                          onPressed: () =>
                              appModel.retryInitialiseWithDefaultRoot(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
    if (appModel.initError != null) {
      final brightness =
          WidgetsBinding.instance.platformDispatcher.platformBrightness;
      final ThemeData fallbackTheme = buildFushiFallbackTheme(brightness);
      final ColorScheme cs = fallbackTheme.colorScheme;
      return TranslationProvider(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: fallbackTheme,
          home: Scaffold(
            backgroundColor: _savedSplashColor ?? cs.surface,
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: cs.error),
                    const SizedBox(height: 16),
                    Text(
                      t.initialization_failed,
                      style: fallbackTheme.textTheme.titleLarge?.copyWith(
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SelectableText(
                      appModel.initError!,
                      style: fallbackTheme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                      selectionControls: FushiTextSelectionControls(
                        shareAction: (text) => FushiShare.shareText(text),
                        allowCopy: true,
                        allowCut: false,
                        allowPaste: false,
                        allowSelectAll: true,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        FilledButton.icon(
                          icon: const Icon(Icons.refresh, size: 18),
                          label: Text(t.retry),
                          onPressed: () => appModel.retryInitialise(),
                        ),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.copy, size: 18),
                          label: Text(t.copy_error),
                          onPressed: () {
                            Clipboard.setData(
                              ClipboardData(text: appModel.initError!),
                            );
                            FushiToast.show(
                              msg: t.error_copied,
                              severity: ToastSeverity.success,
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
    if (!appModel.isInitialised) {
      // TODO-1260：进入裸加载态即挂看门狗；超时前显示转圈，超时后显示逃生 UI。
      _startLoadingWatchdogIfNeeded();
      final brightness =
          WidgetsBinding.instance.platformDispatcher.platformBrightness;
      final ThemeData fallbackTheme = buildFushiFallbackTheme(brightness);
      final ColorScheme cs = fallbackTheme.colorScheme;
      return TranslationProvider(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: fallbackTheme,
          home: Scaffold(
            backgroundColor: _savedSplashColor ?? cs.surface,
            body: LoadingWatchdogView(
              timedOut: _loadingTimedOut,
              colorScheme: cs,
              onRetry: () {
                // 复位看门狗，让重试触发的新一轮加载重新计时。retryInitialise 先退回
                // 默认根（Layer 1 的 2s 超时降级）再重跑 init，通常即成功。
                _cancelLoadingWatchdog();
                appModel.retryInitialise();
              },
            ),
          ),
        ),
      );
    }

    _scheduleCardSourceNavigation();
    _appShortcuts.schedule();
    // 长按图标菜单跟着模块开关与界面语言走：两者一变根 build 就重跑（模块开关
    // notifyListeners / 语言切换重建整树），发布器按签名去重，平时不过通道。
    AppShortcutsPublisher.instance.sync(
      AppShortcut.available(appModel.moduleVisibility),
      labelOf: (AppShortcut shortcut) => homeNavItemFor(shortcut.homeTab).label,
      disabledMessage: t.module_disabled_hint,
    );

    if (!_startupPendingMinesFlushed) {
      _startupPendingMinesFlushed = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _flushPendingMines());
    }

    // app 已初始化完成（走到这里说明 home 即将渲染）：若本次启动是「从 app 外
    // 打开视频」，在首帧后建/取 VideoBook 并打开播放页。只触发一次。
    if (_pendingExternalVideoPath != null) {
    }

    // BUG-1666：同上，冷启动带 `fushi://lookup?word=<词>` 深链时，初始化完成后
    // 排队一次显式查词（消费侧按用户的剪贴板落点配置路由到主窗 tab / 面板 / 瞬态卡）。
    if (_pendingLookupDeepLinkWord != null) {
    }

    // TODO-960: live UI-language switch on desktop. [setAppLocale] no longer
    // restarts the process there (it raced the Windows single-instance mutex
    // and killed the app); it mutates [LocaleSettings] + notifyListeners
    // instead. Most of the UI reads the global Method A `t`, which does NOT
    // rebuild on a [LocaleSettings] change on its own, so this locale-keyed
    // [KeyedSubtree] remounts the whole app subtree whenever the display
    // language changes, forcing every widget (incl. global-`t` readers) to
    // re-resolve its strings. (The generated [TranslationProvider] takes no
    // `key`, so the key lives on the enclosing [KeyedSubtree].) The remount
    // returns to [home]; this is acceptable (a real restart also dropped the
    // navigation stack) and only fires on an explicit language change, not on
    // ordinary [notifyListeners] ticks.
    return KeyedSubtree(
      key: ValueKey<String>('app-locale-${locale.toLanguageTag()}'),
      child: TranslationProvider(
        child: MaterialApp(
          title: 'Kitapsen',
          debugShowCheckedModeBanner: false,
          navigatorKey: appModel.navigatorKey,
          // Resets the focus highlight to touch on every route push/pop so a ring
          // lit by keyboard/gamepad navigation on one page is not carried onto the
          // freshly-entered page (BUG-398).
          navigatorObservers: <NavigatorObserver>[
            appModel.focusHighlightObserver,
          ],
          home: home,
          locale: locale,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: appModel.locales.values,
          themeMode: themeMode,
          theme: appModel.theme,
          darkTheme: appModel.darkTheme,
          // This is responsible for the initialising the global spacing across
          // the entire project, making use of the [spaces] package.
          builder: (context, child) {
            final cs = Theme.of(context).colorScheme;
            // Drive the status/navigation bar icon brightness from the *live*
            // theme so switching themes repaints the system bars. The builder
            // reruns on every theme change, so the AnnotatedRegion re-emits the
            // matching overlay style.
            final Widget gated = AnnotatedRegion<SystemUiOverlayStyle>(
                value: fushiSystemOverlayStyle(cs.brightness),
                child: CupertinoTheme(
                  data: fushiCupertinoTheme(cs,
                      fontFamily: appModel.appFontFamily),
                  child: LayoutBuilder(
                    builder:
                        (BuildContext context, BoxConstraints constraints) {
                      final Size viewport = constraints.hasBoundedWidth &&
                              constraints.hasBoundedHeight
                          ? constraints.biggest
                          : MediaQuery.sizeOf(context);
                      final double uiScale =
                          appModel.resolveAppUiScaleForViewport(
                        viewport: viewport,
                        platform: Theme.of(context).platform,
                      );
                      Widget navigation = wrapWithGlobalNavigation(
                        navigatorKey: appModel.navigatorKey,
                        focusNavigationEnabled:
                            appModel.experimentalFocusNavigationEnabled,
                        registry: appModel.shortcutRegistry,

                        // BUG-1349（第二处根因）：焦点导航层（FushiFocusRoot 的
                        // fallbackNode）必须在全局导航层**之内**。键事件沿焦点树
                        // 冒泡：fallbackNode 若在 wrapWithGlobalNavigation 之外，
                        // 零受管目标页把焦点回收到兜底节点后，Esc/全局快捷键根本
                        // 到不了全局处理器——整个全局键处理静默失效。
                        child: _wrapFocusNavigation(
                          enabled: appModel.experimentalFocusNavigationEnabled,
                          // TODO-354 ①：常驻悬浮字幕查词宿主覆盖在导航之上，让书架/
                          // 首页开的悬浮字幕（无 reader）点词也能在主窗口弹查词。无
                          // 挂起请求时整层 IgnorePointer 透传，不抢任何页面的命中测试。
                          // 全局悬浮球（docs/specs/2026-09-28-floating-ball.md）
                          // 在查词宿主之下：球点出的查词弹窗要盖在球上。
                          child: Stack(
                            children: <Widget>[
                              child!,
                            ],
                          ),
                        ),
                      );
                      navigation = FushiAppUiScale(
                        scale: uiScale,
                        child: navigation,
                      );
                      return navigation;
                    },
                  ),
                ),
            );
            // BUG-2834：全 app 鼠标滚轮无极滚动，一处接住所有滚动区。
            return SmoothWheelScrollScope(child: gated);
          },
        ),
      ),
    );
  }

  /// Responsible for managing global app-wide state.
  AppModel get appModel => ref.watch(appProvider);

  /// The application will open to this page upon startup.
  Widget get home => const HomePage();

  ThemeMode get themeMode => appModel.themeMode;

  /// The current app chrome locale, dependent on the display language.
  Locale get locale => appModel.appLocale;
}

/// 焦点导航层（[FushiFocusRoot] 焦点控制器 + [FushiFocusRing] 可见焦点环）
/// **恒定挂载，行为按实验开关门控**。禁用时 [FushiFocusRoot.maybeControllerOf]
/// 返回 null（各组件据此走原生焦点遍历，语义与「未包裹」时代逐字节一致）、
/// 焦点环不绘制。
///
/// **挂载位置纪律（BUG-1349）**：本层必须位于 [wrapWithGlobalNavigation]
/// **之内**——fallbackNode 是可聚焦节点，键事件沿焦点树只向祖先冒泡；挂在全局
/// 导航层之外时，零受管目标页把焦点回收到兜底节点后，Esc / 全局快捷键全部
/// 到不了全局处理器（详情页 Esc 失效正是此故障 + escape 解析遮蔽的叠加）。
///
/// 用户实报（2026-07-22）：旧实现按开关插/拔这两层——切「键盘/手柄焦点导航」
/// 开关时整棵 app 子树因结构变化被重挂载，被切的 Switch 以新状态直接 mount，
/// 滑块动画消失（其余开关都有动画）。结构恒定后 Element 全保留，动画回归，
/// 顺带不再丢各页滚动位置。
Widget _wrapFocusNavigation({required bool enabled, required Widget child}) {
  return FushiFocusRoot(
    enabled: enabled,
    child: FushiFocusRing(enabled: enabled, child: child),
  );
}
