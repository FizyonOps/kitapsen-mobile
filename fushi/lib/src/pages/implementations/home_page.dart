import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' hide ModifierKey;
import 'package:fushi/src/updates/store_update_check.dart';
import 'package:fushi/src/pages/implementations/kitapsen_store/kitapsen_store_page.dart';
import 'package:fushi/src/utils/components/nav_rail_brand_button.dart';
import 'package:fushi/src/sync/sync_auto_trigger.dart';
import 'package:fushi/src/sync/kitapsen_client.dart'
    show syncKitapsenLibraryProgress;
import 'package:fushi/src/models/module_id.dart';
import 'package:fushi/pages.dart';
import 'package:fushi/utils.dart';
import 'package:fushi/src/focus/fushi_focus_controller.dart'
    show FushiFocusController, FushiFocusRoot;
import 'package:fushi/src/shortcuts/input_binding.dart'
    show GamepadButton, ModifierKey;
import 'package:fushi/src/shortcuts/gamepad_service.dart'
    show
        GamepadButtonIntent,
        arrowFocusMoveDirection,
        arrowKeyClaimedByFocus,
        arrowTraversalDirection,
        dispatchNativeGamepadButtonIntent,
        focusedEditableText;
import 'package:fushi/src/shortcuts/mouse_binding_dispatch.dart'
    show dispatchClaimedMouseAction, resolveMouseBindingAction;
import 'package:fushi/src/shortcuts/page_scroll_shortcuts.dart'
    show pageScrollRequestFor;
import 'package:fushi/src/shortcuts/shortcut_action.dart';

export 'package:fushi/src/models/home_tab.dart';

/// 纯函数：给定视频开关与游戏库开关，返回可见顶层 tab 的**视觉顺序**——视频固定插在书架
/// 与词典之间（用户要求「在书架和词典管理中间」），games（galgame 库）仅在开启时出现，
/// 位置固定紧跟 video 之后（用户要求「底栏里把游戏移动到视频后面」，与书/漫画/视频/游戏
/// 四类媒体入口连成一段）。提取成顶层函数便于单测条件插入与顺序，不必实例化整个
/// [HomePage]。底栏/侧栏的位置索引由此列表导出。
///
/// 形参是**一个** [ModuleVisibility] 而不是一串 bool：此前这里收七个具名 bool，
/// 调用方（`_activeTabs()` 与 main.dart 的 macOS 根侧栏）各手抄一份实参表，两份
/// 已经漂移——macOS 那份漏传 `gamesEnabled`，靠缺省 false 恰好蒙对，注释还把漏写
/// 说成「macOS 恒 false」。收成一个快照后平台判据只在 [ModuleId.availableOn] 判
/// 一次，两个调用点各减七行，也不可能再漏配。
List<HomeTab> homeActiveTabs(ModuleVisibility visibility) => <HomeTab>[
  HomeTab.home,
  // 七个库页/工具 tab 都可按「功能模块」偏好隐藏（设置 → 外观 → 功能模块）；
  // 首页/设置恒在，是全部隐藏后的安全回退面（故 [ModuleId] 里没有它们）。
  if (visibility.isEnabled(ModuleId.books)) HomeTab.books,
  HomeTab.store,
  HomeTab.settings,
];

/// 启动落地 tab。「启动默认打开查词」只在查词 tab 真的可见时成立——查词模块被
/// 关掉时返回它会让 `_currentTab` 从第一帧起就指向一个不在 [homeActiveTabs] 里的
/// tab（渲染由 `_visibleTab` 兜到首页，但选中身份一直是脏的，底栏高亮与
/// `_previousTab` 都跟着错），所以门控要在取值处，而不是靠下游兜底。
HomeTab homeInitialTab({
  required bool startupDefaultDictionaryTab,
  required HomeTab fallback,
  bool dictionariesEnabled = true,
}) {
  if (startupDefaultDictionaryTab && dictionariesEnabled) {
    return HomeTab.dictionaries;
  }
  return fallback;
}

int homeVisualIndexForTab({
  required List<HomeTab> tabs,
  required HomeTab tab,
  required bool reversed,
}) {
  final int logical = tabs.indexOf(tab);
  if (logical < 0) return 0;
  return reversed ? tabs.length - 1 - logical : logical;
}

HomeTab homeTabForVisualIndex({
  required List<HomeTab> tabs,
  required int visualIndex,
  required bool reversed,
}) {
  final int logicalIndex =
      reversed ? (tabs.length - 1 - visualIndex) : visualIndex;
  // 回退到恒在的 home（书架 tab 现可被「功能模块」偏好隐藏，不再是安全回退）。
  if (logicalIndex < 0 || logicalIndex >= tabs.length) return HomeTab.home;
  return tabs[logicalIndex];
}

/// 顶层 home-shell 选中 tab 的共享真值（[HomeTab] 身份，不用整数位置——插入 video /
/// games 条件 tab 不再打乱索引）。macOS 根 [MacosWindow] 的原生侧栏在 main.dart
/// 的 builder 里（Approach B，让 MacosWindow 包住整个 navigator，pushed 路由也拿到
/// MacosWindowScope）构建，与 HomePage 自绘的 rail / 底栏驱动**同一个**选中身份。
/// 非 macOS 平台不读写它，纯 no-op。
final ValueNotifier<HomeTab> homeShellTabNotifier =
    ValueNotifier<HomeTab>(HomeTab.home);

/// 单个 [HomeTab] 的导航项（图标 + 标签）。顶层函数，供 HomePage 的 rail/底栏与 macOS
/// 根侧栏共用，保证三处标签/图标一致。
AdaptiveNavItem homeNavItemFor(HomeTab tab) {
  switch (tab) {
    case HomeTab.home:
      return AdaptiveNavItem(
        icon: Icons.home_outlined,
        selectedIcon: Icons.home,
        label: t.nav_home,
      );
    case HomeTab.books:
      return AdaptiveNavItem(
        icon: Icons.menu_book_outlined,
        selectedIcon: Icons.menu_book,
        label: t.books,
      );
    case HomeTab.store:
      return AdaptiveNavItem(
        icon: Icons.storefront_outlined,
        selectedIcon: Icons.storefront,
        label: t.kitapsen_nav_store,
      );
    case HomeTab.manga:
      return AdaptiveNavItem(
        icon: Icons.photo_library_outlined,
        selectedIcon: Icons.photo_library,
        label: t.manga_library,
      );
    case HomeTab.video:
      return AdaptiveNavItem(
        icon: Icons.movie_outlined,
        selectedIcon: Icons.movie,
        label: t.nav_video,
      );
    case HomeTab.browse:
      // Mihon 的 Browse：来源 / 扩展 / 发现 / 下载（2026-09-27 由「下载」改名）。
      return AdaptiveNavItem(
        icon: Icons.explore_outlined,
        selectedIcon: Icons.explore,
        label: t.nav_browse,
      );
    case HomeTab.dictionaries:
      return AdaptiveNavItem(
        icon: Icons.search_outlined,
        selectedIcon: Icons.search,
        label: t.nav_lookup,
      );
    case HomeTab.games:
      return AdaptiveNavItem(
        icon: Icons.sports_esports_outlined,
        selectedIcon: Icons.sports_esports,
        label: t.nav_game,
      );
    case HomeTab.browserExtension:
      return AdaptiveNavItem(
        icon: Icons.extension_outlined,
        selectedIcon: Icons.extension,
        label: t.nav_browser_extension,
      );
    case HomeTab.settings:
      return AdaptiveNavItem(
        icon: Icons.tune_outlined,
        selectedIcon: Icons.tune,
        label: t.settings,
      );
  }
}

class HomePage extends BasePage {
  const HomePage({super.key});

  @override
  BasePageState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends BasePageState<HomePage>
    with WidgetsBindingObserver {

  HomeTab _currentTab = HomeTab.home;

  /// BUG-2719：tab 正文（[_bodyWithMiniBar]）的唯一身份。三套布局把正文挂在不同的父链下
  /// （底栏：`Scaffold.body > SafeArea`；侧栏：`Row > Expanded`；macOS：
  /// `ContentArea`），而 [LayoutBuilder] 只按**当前宽度**挑其一。没有这把 key，
  /// 宽度一越过 600 的断点，整棵正文就被卸载重建，所有 tab 的 State 一起丢掉。
  /// 最常见的触发是手机竖屏点开视频：播放页转横屏，被它盖住的首页跟着变宽换成侧栏
  /// 布局，退出视频转回竖屏再换一次——视频库的分区（系列 / 全部视频 / 媒体服务器…）
  /// 于是每次都回到第一个「首页」分区。持有 [GlobalKey] 让换布局变成同一子树换父节点。
  final GlobalKey _homeBodyKey = GlobalKey(debugLabel: 'home-tab-body');

  /// 进入「设置」标签前的来源 tab，供设置全屏左上返回箭头切回。
  HomeTab _previousTab = HomeTab.home;
  final FocusNode _keyboardFocusNode = FocusNode();

  final ValueNotifier<int> _videoLibraryRefreshSignal = ValueNotifier<int>(0);
  final Map<HomeTab, ScrollController> _tabScrollControllers =
      <HomeTab, ScrollController>{};

  @override
  void initState() {
    super.initState();

    _currentTab = homeInitialTab(
      startupDefaultDictionaryTab: appModelNoUpdate.startupDefaultDictionaryTab,
      dictionariesEnabled:
          false,
      fallback: _currentTab,
    );
    // Seed the shared shell notifier (drives the macOS root sidebar) and listen
    // for external selection from it. No-op on non-macOS (the sidebar that writes
    // it only exists under the macOS shell).
    homeShellTabNotifier.value = _currentTab;
    homeShellTabNotifier.addListener(_onShellTabRequested);

    WidgetsBinding.instance.addObserver(this);
    assert(() {
      return true;
    }());
    appModelNoUpdate.databaseCloseNotifier.addListener(refresh);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      // 在下面任何分支改写 first_time_setup 之前取：「下载 → 浏览」搬迁提示要据此
      // 区分全新安装与升级（见 browse_moved_notice.dart）。
      // Kitapsen ships no recommended dictionary pack.
      if (!mounted) return;
      // Serialize follow-up with ordinary onboarding and update dialogs.
      if (!mounted) return;

      if (appModel.isFirstTimeSetup) {
        appModel.setFirstTimeSetupFlag();
        // 全新安装：把新手引导标成「待完成」再进下面的弹出分支。既有安装升级
        // 上来时该键缺省即 true（不弹）；中途杀进程下次启动值仍是 false，会
        // 重新弹出（缺省语义见 PreferencesRepository.onboardingCompleted）。
        await appModel.setOnboardingCompleted(value: false);
      }

      // 新手引导在更新弹窗之前弹（避免两个模态抢同一帧）；向导关闭（完成/
      // 跳过/返回）后统一标记完成，之后可从「设置 → 系统」随时重新打开。
      if ((mounted) && !appModel.onboardingCompleted) {
        await Navigator.of(context).push(
          adaptivePageRoute<void>(
            context: context,
            builder: (_) => const OnboardingWizardPage(),
            fullscreenDialog: true,
          ),
        );
        await appModel.setOnboardingCompleted(value: true);
      }


      // Kitapsen never talks to the Fushi release feed: store builds ask
      // Google Play / the App Store instead (store_update_check.dart).
      if (mounted) unawaited(checkStoreUpdate(context));


      // 这一段是 HomePage 层的模块专属后台自启：同步（sync）与视频索引（video）。
      // 模块关掉就不再拉起——「关掉的模块下次启动不该还在后台跑」。已经在飞的
      // 任务不受影响（这里只决定启不启，不去 stop 任何东西）。
      // The sync module (cloud / interconnect) is off — always so in Kitapsen —
      // but books read on kitapsen.com still bring their position back on
      // app open (5 min cooldown inside).
      unawaited(syncKitapsenLibraryProgress(appModel.database));
      // 首帧同步之后挂定时轮询，让静止不动的设备也能周期性拉到远端改动（见
      // [_periodicSyncInterval] 注释）。dispose 时 cancel。排行榜书架同步挂在同一个
      // 定时器上（它自己有 30 分钟节流），所以定时器不再只随同步模块开启。

    });
  }

  void refresh() {
    setState(() {});
  }

  /// TODO-376：响应显式「打开查词 tab」请求（[AppModel.homeDictionaryTabRequest]）。
  /// 桌面悬浮字幕条点词（reader 路由 `_lookupFromFloatingLyric`）这类**显式**手势会先
  /// 把待查词排进 [DesktopLookupService.pendingText]、唤主窗前台，再发本请求；这里只把
  /// 主窗切到查词 tab，让 [HomeDictionaryPage] 挂载——它在 initState 里无条件消费一次
  /// 已存在的 pending 并展示。
  ///
  /// 这是与被动剪贴板监听正交的显式导航：本回调不读 pendingText、也不被剪贴板/热键的
  /// 被动命中触发，故不违反「HomePage 根节点不消费查词请求（mainTab 分区只归
  /// HomeDictionaryPage，spec 2026-07-10 §7）」的守卫。已在查词 tab 时无需切换
  /// （页面已挂载并消费）。
  void _onHomeDictionaryTabRequested() {
    return;
  }

  @override
  void dispose() {
    assert(() {
      return true;
    }());
    _videoLibraryRefreshSignal.dispose();
    for (final ScrollController controller in _tabScrollControllers.values) {
      controller.dispose();
    }
    _keyboardFocusNode.dispose();
    WidgetsBinding.instance.removeObserver(this);
    appModelNoUpdate.databaseCloseNotifier.removeListener(refresh);
    appModelNoUpdate.homeDictionaryTabRequest
        .removeListener(_onHomeDictionaryTabRequested);
    homeShellTabNotifier.removeListener(_onShellTabRequested);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (AppLifecycleState.resumed == state) {
      debugPrint('Lifecycle Resumed');
      // TODO-900: OS 层失焦（Alt+Tab 切窗）后 Flutter 不保证把 primaryFocus 归还到
      // 首页键事件 Focus，导致切窗回来后页级 / 全局快捷键全死，只能重启 app 才靠
      // autofocus 抢回。对齐视频页 [_reclaimVideoFocusIfOwned] 的 resumed 回收范式。
      _reclaimHomeFocusIfOwned();
    } else if (AppLifecycleState.detached == state) {
    } else if (AppLifecycleState.paused == state) {
      if (appModel.lowMemoryMode) {
        PaintingBinding.instance.imageCache.clear();
      }
      final item = appModel.currentMediaItem;
      if (item != null) {
        triggerAutoSyncOnBackground(
          db: appModel.database,
          mediaIdentifier: item.mediaIdentifier,
        );
      }
    }
  }

  /// TODO-900：app 回前台时把 Flutter 焦点收回首页键事件入口，修复「切窗回来后
  /// 首页 / 全局快捷键整体失灵、只能重启复活」。两态分支（对齐 [_wrapFocusNavigation]）：
  /// - 实验焦点导航开（存在 [FushiFocusRoot] 控制器）→ `controller.ensureFocus()`，
  ///   把焦点 home 到一个真实可聚焦目标（仍落在首页 Focus 子树内，键事件照常冒泡到
  ///   [_handleKeyEvent]）。
  /// - 关（默认，无 FushiFocusRoot）→ 直接 requestFocus **既有** [_keyboardFocusNode]
  ///   （绑定 [_handleKeyEvent] 的同一节点，不新造节点）。
  /// 路由门控：首页非当前路由（上方压着对话框）时不抢焦点，避免夺走对话框焦点
  /// （Never break userspace）——对话框关闭时各自的返回点会归还焦点。
  void _reclaimHomeFocusIfOwned() {
    if (!mounted) return;
    final ModalRoute<Object?>? owner = ModalRoute.of(context);
    if (owner != null && !owner.isCurrent) return;
    final FushiFocusController? controller =
        FushiFocusRoot.maybeControllerOf(context, listen: false);
    if (controller != null) {
      controller.ensureFocus();
      return;
    }
    if (_keyboardFocusNode.canRequestFocus) {
      _keyboardFocusNode.requestFocus();
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    // Arrow KeyDownEvent OR OS auto-repeat (KeyRepeatEvent) drives a step of
    // directional focus movement, so holding an arrow advances focus
    // continuously instead of one step per discrete press. KeyDown also runs the
    // shortcut/gamepad resolution below (once per press); a repeat must ONLY move
    // focus — re-resolving a bound shortcut on every repeat would fire it
    // repeatedly. Skipped while a text field is focused so the field's own caret
    // keeps the arrows (same guard as the KeyDown arrow branch below).
    //
    // 仲裁走 [arrowKeyClaimedByFocus]：有焦点目标才移焦并认领；没有（列表边缘 /
    // 焦点还停在本页键事件 sink 上）就放行冒泡，让 app 根的页面滚动兜底接住
    // ——按下沿的四个方向键在下面走的是**同一个**仲裁（六件套不在本页 return），
    // 重复沿若还自己 bootstrap 焦点，就成了「按一下滚页、按住却把焦点甩到首个卡片」。
    final TraversalDirection? repeatDir =
        event is KeyRepeatEvent ? arrowFocusMoveDirection(event) : null;
    if (repeatDir != null) {
      if (focusedEditableText() != null) return KeyEventResult.ignored;
      return arrowKeyClaimedByFocus(context, repeatDir)
          ? KeyEventResult.handled
          : KeyEventResult.ignored;
    }
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final KeyEventResult focusedGamepadAction =
        dispatchNativeGamepadButtonIntent(event);
    if (focusedGamepadAction == KeyEventResult.handled) {
      return focusedGamepadAction;
    }

    final modifiers = <ModifierKey>{};
    if (HardwareKeyboard.instance.isControlPressed) {
      modifiers.add(ModifierKey.ctrl);
    }
    if (HardwareKeyboard.instance.isShiftPressed) {
      modifiers.add(ModifierKey.shift);
    }
    if (HardwareKeyboard.instance.isAltPressed) {
      modifiers.add(ModifierKey.alt);
    }
    if (HardwareKeyboard.instance.isMetaPressed) {
      modifiers.add(ModifierKey.meta);
    }

    // TODO-847: IME 激活时 logicalKey 被改写成 process，传 physicalKey 让 registry
    // 走物理键回退；文本框 composing（focusedEditableText != null）时传 null 关闭
    // 回退，避免搜索框打字误触 Ctrl+数字等快捷键。
    final PhysicalKeyboardKey? imeFallbackPhysicalKey =
        focusedEditableText() == null ? event.physicalKey : null;
    ShortcutAction? action = appModel.shortcutRegistry.resolveKeyboard(
          event.logicalKey,
          modifiers: modifiers,
          scope: ShortcutScope.home,
          physicalKey: imeFallbackPhysicalKey,
        ) ??
        appModel.shortcutRegistry.resolveKeyboard(
          event.logicalKey,
          modifiers: modifiers,
          scope: ShortcutScope.global,
          physicalKey: imeFallbackPhysicalKey,
        ) ??
        // 兜底「返回上一级」（universal，默认 Esc / Alt+← / 手柄 B）。首页自解析它
        // 后不再冒泡到最外层 wrapper，与阅读器/漫画/视频三页同一范式。
        appModel.shortcutRegistry.resolveKeyboard(
          event.logicalKey,
          modifiers: modifiers,
          scope: ShortcutScope.universal,
          physicalKey: imeFallbackPhysicalKey,
        );

    if (action == null) {
      final GamepadButton? gamepad = GamepadButton.fromKeyEvent(event);
      if (gamepad != null) {
        action = appModel.shortcutRegistry.resolveGamepad(
              gamepad,
              scope: ShortcutScope.home,
            ) ??
            appModel.shortcutRegistry.resolveGamepad(
              gamepad,
              scope: ShortcutScope.global,
            ) ??
            appModel.shortcutRegistry.resolveGamepad(
              gamepad,
              scope: ShortcutScope.universal,
            );
      }
    }

    // 页面滚动六件套（global scope，默认 ↑/↓ 单步）不由本页执行——执行体在 app 根
    // [wrapWithGlobalNavigation]，而且它对方向键的规则是「先问焦点、无目标才滚」。
    // 解析到六件套时**不能**在这里 return：`_executeShortcutAction` 对它们落 default
    // → ignored 冒泡到根固然也能滚，但下面那段方向键仲裁就对 ↑/↓ 永远不可达，按下沿
    // （根用 primaryFocus.context 仲裁）与重复沿（本页 context 仲裁）走成两条路。
    // 让六件套穿过来、与重复沿同走一条仲裁；用户改绑到其它动作的键仍照常先执行。
    if (action != null && pageScrollRequestFor(action) == null) {
      return _executeShortcutAction(action);
    }

    // Arrow keys carry no home-scope binding, so drive robust directional focus
    // navigation through the SAME helper the gamepad D-pad/stick uses — keyboard
    // and gamepad therefore behave identically. Skipped while a text field is
    // focused so the field's own cursor movement keeps working (up/down then
    // bubble to wrapWithGlobalNavigation, which lets them escape a single-line
    // field). Uses the shared arrow/editable helpers so home and the app-wide
    // wrapper read arrows and "is a text field focused" the same way — the old
    // private `is EditableText` check missed every field (the primary focus is
    // EditableText's inner Focus, not the EditableText), so it never actually
    // guarded the search field's caret.
    // 按下沿与上面的重复沿走**同一条**判据 [arrowKeyClaimedByFocus]：有焦点目标才
    // 移焦并认领，没有就放行冒泡给 app 根（↑/↓ 在那里按六件套落到页面滚动；←/→
    // 没有 global 绑定则交给框架）。此前按下沿单独走 gamepadMoveFocusInDirection 的
    // 阅读顺序回退，焦点导航关闭时同一个 ← 按一下会跳焦点、按住却不动。
    final TraversalDirection? dir = arrowTraversalDirection(event.logicalKey);
    if (dir != null && focusedEditableText() == null) {
      return arrowKeyClaimedByFocus(context, dir)
          ? KeyEventResult.handled
          : KeyEventResult.ignored;
    }
    return KeyEventResult.ignored;
  }

  /// 当前可见的顶层 tab：首页 → 书架 → 漫画 → 视频 → 游戏 → 下载 → 词典 → 设置。
  /// 漫画/视频/游戏三个媒体库 tab 按「功能模块」偏好显隐（默认全开，行为与旧版一致）；
  /// games（galgame 库）额外叠加 Windows 平台门控（galgame 引擎-hook 注入本就
  /// Windows-only），紧跟视频之后。底栏/侧栏的位置索引由此列表导出。
  /// 按「功能模块」偏好显隐（偏好默认全开，行为与旧版一致）。平台门控——games
  /// 的 Windows-only、扩展的桌面-only——已由 [AppModel.moduleVisibility] 合成，
  /// 这里不再叠第二遍。
  List<HomeTab> _activeTabs() => homeActiveTabs(appModel.moduleVisibility);

  /// 渲染用的当前 tab：若 `_currentTab` 已不在可见列表（例如刚在「功能模块」里
  /// 关掉当前所在库页），回落到恒在的首页，避免渲染一个不存在的 tab。
  /// `_currentTab` 自身保持不变，下一次 [_selectTab] 会纠正它。
  HomeTab get _visibleTab {
    final List<HomeTab> tabs = _activeTabs();
    return tabs.contains(_currentTab) ? _currentTab : HomeTab.home;
  }

  /// 设置页返回箭头的目标：来源 tab 若在设置里刚被「功能模块」关掉，回落首页。
  HomeTab get _previousVisibleTab =>
      _activeTabs().contains(_previousTab) ? _previousTab : HomeTab.home;

  /// 用户从导航（移动底栏 / 桌面 rail）点选 tab 的**唯一**入口。
  ///
  /// 与程序化切 tab（桌面取词落地、dashboard 卡片、快捷键）分开：点「查词」是
  /// 「我要查个新词」这一条明确意图，故顺带清空上次残留的查询并聚焦搜索框——
  /// 键盘随焦点弹起。程序化路径继续走 [_selectTab]，不受影响（桌面取词正要把
  /// pending 的词填进去，清空会把它擦掉）。
  void _selectTabFromNav(HomeTab tab) {
    _selectTab(tab);
    return;
  }

  /// 统一切换顶层 tab：进入「设置」前记录来源 tab，供设置全屏返回箭头切回。
  /// 所有切 tab 入口（侧栏 / 底栏 / 快捷键 / 程序化跳转）都走这里，保证
  /// _previousTab 一致。目标 tab 已被「功能模块」隐藏时直接忽略：隐藏即该页
  /// 不可达，快捷键 / 「查看下载」/ 桌面查词请求都不该把用户莫名其妙甩到首页
  /// （旧行为：`_currentTab` 设成隐藏 tab 后由 [_visibleTab] 兜底成首页）。
  void _selectTab(HomeTab tab) {
    if (!_activeTabs().contains(tab)) {
      // 拒绝之后必须把共享 notifier 拨回真实选中态：外部写入方（dashboard 卡片、
      // galgame 浮窗、设置里的游戏入口）是**先写 notifier 再由 [_onShellTabRequested]
      // 转交**的，早退不回滚就会留下脏值——macOS 根侧栏与桌面自绘顶栏标题都直接
      // 读它（main.dart 的 FushiDesktopTitleBar），于是关掉视频后顶栏仍写「视频」
      // 而正文是首页。
      if (homeShellTabNotifier.value != _currentTab) {
        homeShellTabNotifier.value = _currentTab;
      }
      return;
    }
    // A same-route home-tab switch (IndexedStack, no route push/pop) still
    // changes the visible screen, so reset any focus ring lit on the old tab so
    // it is not carried onto the new one (BUG-398). Route-based navigation is
    // covered by AppModel.focusHighlightObserver; this handles the tab case the
    // NavigatorObserver cannot see.
    if (tab != _currentTab) {
      appModelNoUpdate.gamepadService.resetHighlightForScreenSwitch();
    }
    setState(() {
      if (tab == HomeTab.settings && _currentTab != HomeTab.settings) {
        _previousTab = _currentTab;
      }
      _currentTab = tab;
    });
    // Reflect the selection into the shared notifier so the macOS root sidebar
    // (built outside HomePage) stays in sync. Guarded by value-equality inside
    // ValueNotifier, so this never re-enters _onShellTabRequested pointlessly.
    homeShellTabNotifier.value = tab;
  }

  /// The macOS root sidebar writes [homeShellTabNotifier] directly; route that
  /// external request through the SAME [_selectTab] path so _previousTab and the
  /// focus-ring reset run identically to a rail/bottom-bar/shortcut switch. Guard
  /// against the echo from _selectTab's own write-back.
  void _onShellTabRequested() {
    final HomeTab requested = homeShellTabNotifier.value;
    if (requested == _currentTab) return;
    if (!mounted) return;
    _selectTab(requested);
  }

  /// next/prev 快捷键：在当前可见 tab 列表里环形步进（视频开关变化时自动适配长度）。
  void _cycleTab(int delta) {
    final List<HomeTab> tabs = _activeTabs();
    final int current = tabs.indexOf(_visibleTab);
    final int next = (current + delta) % tabs.length;
    _selectTab(tabs[(next + tabs.length) % tabs.length]);
  }

  /// 首页鼠标通道的解析阶梯：**只有 home 自己的 scope**。
  ///
  /// 键盘在页内解析 home → global → universal，但 global / universal 那两段的执行体
  /// 其实并不在本页——`_executeShortcutAction` 对它们（除 globalBack 外）返回 ignored，
  /// 让事件冒泡到 [wrapWithGlobalNavigation] 去执行。鼠标没有冒泡，那一层改由 app 根的
  /// `onPointerDown` 兜底（互斥见 [MouseBindingDispatch]），**执行体仍只有那一份**。
  /// BUG-2031：阶梯必须与本页**键盘阶梯逐字相同**。第一版只放了本页 scope，于是
  /// `globalBack`（universal）在页内解析不到，只能落到 app 根那份平铺的
  /// `Navigator.maybePop()`——而键盘 / 手柄的 `globalBack` 走的是本页的**逐级退出**
  /// （先关面板 / 退全屏，最后才退页）。同一个动作两条通道两种行为，正是要禁的形态。
  static const List<ShortcutScope> _kHomeMouseLadder = <ShortcutScope>[
    ShortcutScope.home,
    ShortcutScope.global,
    ShortcutScope.universal,
  ];

  /// 首页的**鼠标绑定通道**：与 [_handleKeyEvent] 挂在同一层、同一份注册表、同一个
  /// 执行体 [_executeShortcutAction]，只是触发器换成了鼠标非主键。
  ///
  /// ⚠️ 与视频页同一条几何限制：查词浮层可见时，根 Overlay 的 `LookupDismissBarrier`
  /// （`Positioned.fill` + 叶子 `ColoredBox`，命中行为 opaque）会吃光指针，本入口收不到
  /// 任何按下。那半边由 barrier 自己的 `onNonPrimaryButtonDown` 承接。
  void _handleHomePointerDown(PointerDownEvent event) {
    final ShortcutAction? action = resolveMouseBindingAction(
      registry: appModel.shortcutRegistry,
      buttons: event.buttons,
      ladder: _kHomeMouseLadder,
    );
    if (action == null) return;
    // 执行体返回 ignored 说明本页没接（等价于键盘的 ignored 冒泡），此时**不认领**，
    // 让 app 根兜底照常有机会解析同一个按钮上的 universal / global 绑定。
    dispatchClaimedMouseAction(
      event,
      () => _executeShortcutAction(action) == KeyEventResult.handled,
    );
  }

  /// 切 tab 类快捷键的统一执行体：目标 tab 被「功能模块」关掉时返回
  /// [KeyEventResult.ignored] 而**不是** handled。
  ///
  /// 差别是真实的：handled 会把按键**认领掉**，同一个物理键上绑的 universal /
  /// global 动作再也收不到它——于是「关掉书架后 Ctrl+1 既不切 tab、也不再冒泡」，
  /// 变成一个吃键的黑洞。不可达就等于本页没接，让它照常往上冒。
  KeyEventResult _selectTabFromShortcut(HomeTab tab) {
    if (!_activeTabs().contains(tab)) return KeyEventResult.ignored;
    _selectTab(tab);
    return KeyEventResult.handled;
  }

  KeyEventResult _executeShortcutAction(ShortcutAction action) {
    switch (action) {
      case ShortcutAction.homeTabBooks:
        return _selectTabFromShortcut(HomeTab.books);
      case ShortcutAction.homeTabDict:
        return KeyEventResult.ignored;
      case ShortcutAction.homeTabSettings:
        // 设置恒在，不可能不可达；仍走同一条路保持形态一致。
        return _selectTabFromShortcut(HomeTab.settings);
      case ShortcutAction.homeTabNext:
        _cycleTab(1);
        return KeyEventResult.handled;
      case ShortcutAction.homeTabPrev:
        _cycleTab(-1);
        return KeyEventResult.handled;
      case ShortcutAction.homeFocusSearch:
        return KeyEventResult.ignored;
      case ShortcutAction.globalBack:
        Navigator.of(context).maybePop();
        return KeyEventResult.handled;
      default:
        return KeyEventResult.ignored;
    }
  }

  /// Handles a gamepad button delivered via [GamepadButtonIntent] (desktop
  /// polled path), routing it through the same actions as the key-event path.
  /// Returns true when consumed; false lets the GamepadService fall back to
  /// directional focus / activate / global back.
  bool _handleGamepadButton(GamepadButton button) {
    final ShortcutAction? action = appModel.shortcutRegistry.resolveGamepad(
          button,
          scope: ShortcutScope.home,
        ) ??
        appModel.shortcutRegistry.resolveGamepad(
          button,
          scope: ShortcutScope.global,
        ) ??
        // 兜底「返回上一级」（universal，默认手柄 B）。
        appModel.shortcutRegistry.resolveGamepad(
          button,
          scope: ShortcutScope.universal,
        );
    if (action == null) return false;
    return _executeShortcutAction(action) == KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    if (!appModel.isDatabaseOpen) {
      return const SizedBox.shrink();
    }

    final Widget home = ValueListenableBuilder<bool>(
        valueListenable: syncInProgress,
        builder: (context, syncing, child) => PopScope(
              canPop: !syncing,
              onPopInvokedWithResult: (didPop, _) async {
                if (didPop) return;
                // 同 route 多 PopScope 的回调全部遍历，故此顶层同步 PopScope 在设置
                // tab 上也会被触发；设置 tab 的返回由内层 PopScope 切回来源 tab，
                // 这里据 [shouldWarnOnExit] 收窄到非设置 tab 才弹同步告警（TODO-698）。
                if (_visibleTab == HomeTab.settings) return;
                final bool? confirmed = await showAppDialog<bool>(
                  context: context,
                  builder: (BuildContext ctx) => _SyncExitWarningDialog(
                    onCancel: () => Navigator.pop(ctx, false),
                    onExit: () => Navigator.pop(ctx, true),
                  ),
                );
                if (confirmed == true) {
                  SystemNavigator.pop();
                }
              },
              child: child!,
            ),
        child: Actions(
            // Desktop gamepad path: the GamepadService dispatches
            // GamepadButtonIntent here (no gameButton* key events on desktop).
            // Resolving it against home/global routes polled controller input
            // through the same actions as the key-event path.
            actions: <Type, Action<Intent>>{
              GamepadButtonIntent: CallbackAction<GamepadButtonIntent>(
                onInvoke: (GamepadButtonIntent intent) =>
                    _handleGamepadButton(intent.button),
              ),
            },
            child: Focus(
                // Autofocus on every platform: on mobile no field on the home tabs
                // grabs focus at mount, so without this the FocusManager has no
                // primary focus and hardware-keyboard / gamepad shortcuts never
                // reach _handleKeyEvent until the user taps something. The home
                // search field focuses on demand, so this never fights an editable.
                autofocus: true,
                // But this wrapper spans the whole page, so it must NOT be a
                // traversal target: otherwise directional (keyboard arrow /
                // gamepad) navigation lands on it and the focus ring covers the
                // entire window. skipTraversal keeps it as a key-event sink only;
                // Tab/arrow/D-pad traversal moves between the real controls and
                // the ring follows them. Shortcut keys still bubble up here.
                skipTraversal: true,
                focusNode: _keyboardFocusNode,
                onKeyEvent: _handleKeyEvent,
                // 鼠标通道与键盘挂在同一层：作用域（整页）与解析阶梯都必须与
                // [_handleKeyEvent] 对齐，挂低了就会重演 BUG-1864 那种「注册表声明整页、
                // 挂载点只在子树，焦点一进面板整张表就够不着」。
                //
                // `translucent`：本层不画东西，默认 deferToChild 会让空白区收不到按下。
                // [Listener] 不进手势竞技场、不消费事件，下面那个 GestureDetector 的
                // onTap（只认主键）与所有子控件照常工作。
                child: Listener(
                  behavior: HitTestBehavior.translucent,
                  onPointerDown: _handleHomePointerDown,
                  child: GestureDetector(
                    onTap: () {
                      final FocusNode? current =
                          FocusManager.instance.primaryFocus;
                      if (current != null && current != _keyboardFocusNode) {
                        current.unfocus();
                      }
                    },
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final sizeClass = windowSizeClassReal(
                          constraints.maxWidth,
                          FushiAppUiScale.of(context),
                        );
                        // compact(<600) → 底栏；medium/expanded(≥600，含竖屏平板) → 侧边布局。
                        if (sizeClass == WindowSizeClass.compact) {
                          return _buildMobileLayout();
                        }
                        return _buildDesktopLayout(sizeClass);
                      },
                    ),
                  ),
                ))));
    // 桌面剪贴板/热键查词不再叠加独立 overlay 页；监听生命周期收窄到查词 tab。
    return home;
  }

  /// 单个 [HomeTab] 的导航项（图标 + 标签）。底栏/侧栏/macOS 根侧栏共用同一顶层
  /// [homeNavItemFor]，保证三处标签/选中图标一致。
  AdaptiveNavItem _navItemFor(HomeTab tab) => homeNavItemFor(tab);

  /// 可见 tab 列表对应的导航项（与 [_activeTabs] 顺序一致）。
  List<AdaptiveNavItem> _navItems(List<HomeTab> tabs) =>
      tabs.map(_navItemFor).toList();

  Widget _buildDesktopLayout(WindowSizeClass sizeClass) {
    if (_visibleTab == HomeTab.settings) {
      // 设置标签（全部设计系统）：隐藏 3 图标侧栏，全屏二栏（内部
      // MaterialSupportingPaneLayout），左上返回箭头切回来源 tab（参考 Mihon
      // 宽屏设置）。Cupertino 桌面也走这里——叶子控件保持 Cupertino 皮肤，但外壳
      // 复用同一 Material 架构；返回出口由 SettingsHomePage 的嵌入页头提供
      // （BUG-009 R2）。否则会退化成「3 图标 rail + 嵌入式 Cupertino 设置」三栏
      // 混排、无返回出口、且详情面板溢出。
      return Scaffold(
        resizeToAvoidBottomInset: false,
        body: SafeArea(
          child: FocusTraversalGroup(
            child: _buildSettingsTabContent(showBackButton: true),
          ),
        ),
      );
    }

    final List<HomeTab> tabs = _activeTabs();
    final bool reversed = appModel.reverseNavigationBar;
    final List<AdaptiveNavItem> items = _navItems(tabs);
    final List<AdaptiveNavItem> displayItems =
        reversed ? items.reversed.toList() : items;
    final int visualIndex = homeVisualIndexForTab(
      tabs: tabs,
      tab: _visibleTab,
      reversed: reversed,
    );

    void selectVisual(int index) {
      _selectTabFromNav(homeTabForVisualIndex(
        tabs: tabs,
        visualIndex: index,
        reversed: reversed,
      ));
    }

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        // 这里曾是 macOS 交通灯保留带（BUG-869）：透明标题栏 + full-size content
        // view 下交通灯不计入 SafeArea，会压住导航 rail 顶部。macOS 现在与 Windows
        // 一样自绘顶栏、交通灯在 `main()` 里被隐藏，rail 本来就落在顶栏之下，
        // 再留一条 28pt 就是纯空白。
        // Two traversal groups so Tab / Shift+Tab walk each region as one block
        // in visual order (whole rail, then whole content) instead of zig-zagging
        // between the rail and the content pane row-by-row.
        child: Row(
          children: [
            // Each rail destination is its own gamepad/keyboard focus target, so
            // the app focus ring hugs the single selected item; D-pad Up/Down
            // steps between them and Left/Right leaves to the content.
            FocusTraversalGroup(
              child: adaptiveNavRail(
                context: context,
                currentIndex: visualIndex,
                onTap: selectVisual,
                items: displayItems,
                leading: const NavRailBrandButton(),
              ),
            ),
            Expanded(child: FocusTraversalGroup(child: _bodyWithMiniBar())),
          ],
        ),
      ),
    );
  }

  /// 内容主体 + 底部迷你条：推荐包下载（BUG-2165）在上、「正在听书」（TODO-291
  /// 阶段2）在下，各自无任务时收起（[SizedBox.shrink]，不占布局）。
  ///
  /// 这里是三套布局（移动底栏 / 桌面 rail / macOS）**唯一**的共用点，也是 app 里
  /// 唯一一处「跨全部 home tab 常驻」的挂载位。推荐包那条 9.5 GB 的下载在
  /// BUG-2097 之后确实活过了向导，但可见入口只剩设置 → 系统里那一行 —— 新用户
  /// 走完引导正好落在首页，屏幕上一个像素都不说明它还在下。挂在这里它才真的
  /// 「有个地方看进度」。
  Widget _bodyWithMiniBar() {
    // 这两条是全 app 唯一「跨全部 home tab 常驻」的挂载位，也因此是最显眼的一处
    // 模块泄漏：推荐包下载进度条属下载模块、正在听书条属听书模块，此前无条件挂着
    // ——关掉下载/听书后它们仍钉在首页底部，与「看起来像纯粹的阅读器」直接相反。
    return Column(
      key: _homeBodyKey,
      children: <Widget>[
        Expanded(child: buildBody()),
      ],
    );
  }

  Widget _buildMobileLayout() {
    final List<HomeTab> tabs = _activeTabs();
    final bool reversed = appModel.reverseNavigationBar;
    final List<AdaptiveNavItem> items = _navItems(tabs);
    final List<AdaptiveNavItem> displayItems =
        reversed ? items.reversed.toList() : items;
    final int visualIndex = homeVisualIndexForTab(
      tabs: tabs,
      tab: _visibleTab,
      reversed: reversed,
    );

    // Two traversal groups so D-pad / arrow Left/Right walks each region as one
    // closed block (whole bottom bar, or whole content) instead of escaping from
    // an edge tab up into a content focus target. Mirrors the desktop layout,
    // which already isolates the rail and content panes (TODO-713: 移动端底栏
    // 边缘 tab 按左/右焦点跑到上部).
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: SafeArea(child: FocusTraversalGroup(child: _bodyWithMiniBar())),
      // The FocusTraversalGroup keeps the bottom-nav isolated as one closed
      // traversal block (TODO-713).
      bottomNavigationBar: FocusTraversalGroup(
        child: adaptiveBottomBar(
          context: context,
          currentIndex: visualIndex,
          onTap: (int index) {
            _selectTabFromNav(homeTabForVisualIndex(
              tabs: tabs,
              visualIndex: index,
              reversed: reversed,
            ));
          },
          items: displayItems,
        ),
      ),
    );
  }

  /// 需要跨 tab 切换**保活**（State 不随切走而销毁）的顶层 tab：书架、视频与游戏。
  ///
  /// 书架与视频进入时会做**无持久缓存的远端加载**——`listRemoteBooks()` /
  /// `listRemoteVideos()` 每次都实打实打网络，远端封面（`RemoteCoverImage`）只走进程
  /// 内 `ImageCache`、无磁盘缓存。若页面 State 随切走被销毁，切回时 `initState` 重跑
  /// 就会把远端列表 + 封面全部重新联网拉一遍（用户报「每次进书架/视频都重新加载」）。
  /// 保活让 State 常驻 → 切回沿用已加载的列表/封面/滚动位置，秒回。
  ///
  /// 游戏页也必须保活：捕获工作台拥有文本订阅、音频源与轮询会话，切去查词或设置时
  /// 只能隐藏，不能因 dispose 停止正在进行的 Hook。
  ///
  /// 浏览页也保活：它的来源 / 发现页签每次挂载都要对全部来源联网拉一遍（热门 /
  /// 发现列表），切去别的 tab 再回来不该丢掉搜索词、结果与滚动再重拉；跨页跳转
  /// 改走 [BrowsePage.navigationRequest] 原地切页签。
  ///
  /// 其余 tab（词典 / 设置）**故意不保活**、按需重建，以保留其依赖
  /// `initState` 挂载的语义——尤其 [HomeDictionaryPage] 靠切到查词 tab 时 re-mount
  /// 消费桌面悬浮字幕的 pending 查词（TODO-376，见 [_onHomeDictionaryTabRequested]）；
  /// 若把它也保活会不再 re-mount 而漏消费。
  static const Set<HomeTab> _keepAliveTabs = <HomeTab>{
    HomeTab.books,
    HomeTab.manga,
    HomeTab.video,
    HomeTab.games,
    HomeTab.browse,
  };

  /// 用户已实际打开过至少一次的保活 tab。惰性构建：没进过的视频/书架 tab 不预建，
  /// 避免 app 一启动就把没访问的 tab 的远端列表/封面预拉一遍。
  final Set<HomeTab> _visitedKeepAliveTabs = <HomeTab>{};

  Widget buildBody() {
    final HomeTab visible = _visibleTab;
    if (_keepAliveTabs.contains(visible)) {
      _visitedKeepAliveTabs.add(visible);
    }
    // 模块被关掉 → 把它的保活子树**真正移出树**，让 State/Timer/流订阅走正常
    // dispose。此前这里只看 `_keepAliveTabs ∩ _visitedKeepAliveTabs`、从不剪枝：
    // 本次会话访问过视频页再去设置里关掉视频，那一页仍挂在树上，只是被 Offstage
    // 藏了、TickerMode 停帧——监听与定时器照跑，要重启 app 才消失。这与「关掉的
    // 模块不该还在后台跑」直接矛盾。
    //
    // 代价（有意接受）：正在 hook 一局 galgame 时关掉「游戏」模块，游戏页会被
    // dispose、当前 hook 会话随之中断。这是用户显式关模块的直接后果，不是切 tab
    // 的副作用——`_keepAliveTabs` 本身没动，切导航仍然不 dispose 任何页
    // （守卫 test/pages/home_tab_keepalive_guard_test.dart 钉的就是那一条）。
    final List<HomeTab> active = _activeTabs();
    _visitedKeepAliveTabs.removeWhere((HomeTab t) => !active.contains(t));
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        // 保活 tab：一旦访问过就常驻树中，仅用 Offstage 隐藏未选中者（State 不销毁）。
        // 隐藏时同步关掉 TickerMode，令其 AnimationController 停走、不与可见 tab 抢帧。
        for (final HomeTab tab in _keepAliveTabs)
          if (_visitedKeepAliveTabs.contains(tab))
            Offstage(
              key: ValueKey<HomeTab>(tab),
              offstage: visible != tab,
              child: TickerMode(
                enabled: visible == tab,
                child: _buildTabContent(tab),
              ),
            ),
        // 非保活 tab：仅在选中时构建、切走即销毁，保留其 initState 挂载语义。
        if (!_keepAliveTabs.contains(visible))
          KeyedSubtree(
            key: ValueKey<HomeTab>(visible),
            child: _buildTabContent(visible),
          ),
      ],
    );
  }

  Widget _buildTabContent(HomeTab tab) {
    final Widget content = switch (tab) {
      HomeTab.home => HomeDashboardPage(),
      HomeTab.store =>
        const KitapsenStorePage(),
      // Kitapsen: hidden tabs build nothing, so their pages are tree-shaken out.
      HomeTab.video => const SizedBox.shrink(),
      HomeTab.browse => const SizedBox.shrink(),
      HomeTab.dictionaries => const SizedBox.shrink(),
      // Android 的 games 模块是串流接收端：远端主机游戏库 + 远程启动串流；
      // Windows 仍是本机 galgame 库。形态判据只在 [GamesModuleForm.on]。
      HomeTab.games => const SizedBox.shrink(),
      HomeTab.browserExtension =>
        const SizedBox.shrink(),
      HomeTab.settings =>
        // 设置 tab 走侧栏/底栏切回，不显示页头返回箭头；但仍需 PopScope 拦截系统
        // 返回键（否则冒泡到顶层 PopScope = 退出 app，见 BUG-236）。
        _buildSettingsTabContent(showBackButton: false),
      HomeTab.books => const HomeReaderPage(),
      HomeTab.manga =>
        const SizedBox.shrink(),
    };
    return PrimaryScrollController(
      controller: _tabScrollControllers.putIfAbsent(
        tab,
        ScrollController.new,
      ),
      automaticallyInheritForPlatforms: TargetPlatform.values.toSet(),
      child: content,
    );
  }

  /// 设置 tab 的内容外壳。[showBackButton] 为 true 时（宽屏隐藏 3 图标侧栏的全屏
  /// 设置）显示页头左上返回箭头；为 false 时（移动底栏 / 宽屏侧栏在侧 / Windows 自绘
  /// 标题栏常驻 rail，可直接切回）不显示箭头，系统返回手势仍由
  /// [HomeSettingsTabContent] 内的 PopScope 拦截。
  Widget _buildSettingsTabContent({required bool showBackButton}) {
    return HomeSettingsTabContent(
      showBackButton: showBackButton,
      onReturnToPreviousTab: () => _selectTab(_previousVisibleTab),
    );
  }
}

/// 设置 tab 的内容外壳：用 [PopScope] 拦截系统返回键（Android 硬件返回 / 手势返回），
/// 消费后切回来源 tab（[onReturnToPreviousTab]）而不是让事件冒泡到 home 顶层
/// [PopScope] 退出 app（BUG-236）。注意：同 route 多个 PopScope 的回调会被**全部
/// 遍历**、popDisposition 按 OR 聚合（任一 canPop:false 即不真正 pop），没有「内层先收
/// 到」的顺序保证；故顶层同步 PopScope 在设置 tab 上也会触发，需按当前 tab 自我收窄
/// （见 [shouldWarnOnExit]，TODO-698）。非设置 tab 不构造此 widget，仍走顶层 PopScope
/// 的正常退出/同步告警逻辑。
///
/// 设置内容默认是 [FushiSettingsContent]；[child] 仅供 widget 测试注入轻量占位以独立
/// 验证 PopScope 拦截行为（生产路径始终用默认值）。
class HomeSettingsTabContent extends StatelessWidget {
  const HomeSettingsTabContent({
    super.key,
    required this.onReturnToPreviousTab,
    this.showBackButton = false,
    this.child,
  });

  /// 系统返回键被拦截后调用：切回进入设置前的来源 tab。
  final VoidCallback onReturnToPreviousTab;

  /// 是否在设置页头左侧显示返回箭头（宽屏隐藏图标侧栏的全屏设置场景）。
  final bool showBackButton;

  /// 设置内容；为空时回落到默认的 [FushiSettingsContent]。
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) return;
        onReturnToPreviousTab();
      },
      child: child ??
          FushiSettingsContent(
            onBack: showBackButton ? onReturnToPreviousTab : null,
          ),
    );
  }
}

class _SyncExitWarningDialog extends StatelessWidget {
  const _SyncExitWarningDialog({
    required this.onCancel,
    required this.onExit,
  });

  final VoidCallback onCancel;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final FushiDesignTokens tokens = FushiDesignTokens.of(context);
    final ColorScheme colors = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return FushiDialogFrame(
      maxWidth: 380,
      padding: EdgeInsets.all(tokens.spacing.card + 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            t.sync_exit_warning_title,
            style: textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: tokens.spacing.gap + 4),
          Text(
            t.sync_exit_warning,
            style: textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          SizedBox(height: tokens.spacing.card + tokens.spacing.gap),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              adaptiveDialogAction(
                context: context,
                onPressed: onCancel,
                child: Text(t.dialog_cancel),
              ),
              SizedBox(width: tokens.spacing.gap),
              adaptiveDialogAction(
                context: context,
                isDestructiveAction: true,
                onPressed: onExit,
                child: Text(t.dialog_exit),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
