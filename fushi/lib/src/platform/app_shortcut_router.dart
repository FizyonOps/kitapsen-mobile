import 'dart:async';

import 'package:flutter/widgets.dart';

import 'package:fushi/src/models/home_tab.dart';
import 'package:fushi/src/platform/app_shortcuts.dart';

/// 快捷方式 URL 的冷启动排队。
///
/// 冷启动时 URL 比 `initialise()` 先到，而 HomePage.initState 会把首页 tab 重置
/// 成启动 tab，所以先存着，等 home 挂载后的首帧再落地；连点多次只落最后一条。
class AppShortcutQueue {
  AppShortcutQueue({required this.isActive, required this.run});

  /// 宿主（根 widget）是否还挂着；帧回调跑到时已卸载就丢弃。
  final bool Function() isActive;

  /// 真正的落地动作（见 [runAppShortcut]）。
  final Future<void> Function(AppShortcut shortcut) run;

  AppShortcut? _pending;
  final bool _scheduled = false;

  /// 有排队的快捷方式就在下一帧落地。根 build 每次都会调，重复调用是 no-op。
  void schedule() {
    if (_scheduled || _pending == null) return;
  }
}

/// 落地一条长按图标快捷方式。
///
/// - 新手引导未完成：只在引导下面切 tab，不动路由栈（引导是压在首页上的路由，
///   以任何方式关掉都记为完成）；用户走完引导落在目标 tab 上。查词与其它 tab
///   同口径——不在引导上面再压一个独立查词页。
/// - 查词：交给 [openLookup]（HomePage 的查词落地入口；阅读器 / 播放器压在上面时
///   它推独立查词页到最上层，不打断正在看的东西）。
/// - 其余 tab：切 tab 后逐层退回首页根路由，否则 tab 切了也被上层页面挡住。
///   两步都排在 [ExternalMediaNavigation.navigate] 队列里。
Future<void> runAppShortcut(
  AppShortcut shortcut, {
  required bool onboardingCompleted,
  required NavigatorState? navigator,
  required void Function(HomeTab tab) selectHomeTab,
}) async {
  if (!onboardingCompleted) {
    selectHomeTab(shortcut.homeTab);
    return;
  }
  // Kitapsen: no Anki card-source navigation queue, and reader pages do not
  // register with it, so they are popped like any other route.
  selectHomeTab(shortcut.homeTab);
  if (navigator != null) await _popToHomeRoute(navigator);
  return;
}

/// [unwindToHomeRoute] without the media-page queue (Kitapsen edition).
Future<void> _popToHomeRoute(NavigatorState navigator) async {
  while (navigator.mounted && navigator.canPop()) {
    final Route<dynamic>? top = _topRoute(navigator);
    if (top == null) return;
    await navigator.maybePop();
    if (!navigator.mounted || top.isActive) return;
  }
}

Route<dynamic>? _topRoute(NavigatorState navigator) {
  Route<dynamic>? top;
  navigator.popUntil((Route<dynamic> route) {
    top = route;
    return true;
  });
  return top;
}
