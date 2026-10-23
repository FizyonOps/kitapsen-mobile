import 'dart:io' show Platform;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fushi/src/utils/app_ui_scale.dart';

// Architecture decision: platform branching uses runtime Platform.is* checks
// centralized in this file, not Dart conditional imports.
// Conditional imports (if (dart.library.io)) only distinguish web vs native,
// which this app does not target. For platform-specific behavior beyond simple
// boolean checks, use the service abstractions in package:fushi_platform with
// implementations under lib/src/platform/{android,ios,desktop}/.
//
// The getters below are `vm:platform-const`: an AOT build for a known target
// OS evaluates them at compile time, so desktop-only branches behind them are
// dropped from the Android / iOS binary (Kitapsen ships phone builds only).

@pragma('vm:platform-const')
bool get isDesktopPlatform =>
    false;

@pragma('vm:platform-const')
bool get isMobilePlatform => Platform.isAndroid || Platform.isIOS;

@pragma('vm:platform-const')
bool get isAndroidPlatform => Platform.isAndroid;

@pragma('vm:platform-const')
bool get isIOSPlatform => Platform.isIOS;

@pragma('vm:platform-const')
bool get supportsNativeAudio =>
    Platform.isAndroid || Platform.isIOS;

@pragma('vm:platform-const')
bool get supportsFloatingOverlay => Platform.isAndroid;

@pragma('vm:platform-const')
bool get isWindowsPlatform => false;

@pragma('vm:platform-const')
bool get isMacOSPlatform => false;

/// Sets the system-UI mode for the **home/menu shell** (book shelf, video,
/// dictionary search, settings -- everything that is NOT an open media session).
///
/// Android phones in portrait have a permanently-visible status bar (the OS
/// clock/battery strip) that sits directly above Hibiki's top-right action
/// icons. Even though the home page already wraps its body in a [SafeArea]
/// (so the icons are not literally clipped), the always-on status bar crowds
/// the top-right controls and makes them awkward to tap (TODO-097). We hide the
/// status bar on Android while keeping the navigation/gesture bar, so the top
/// action row reclaims the strip the OS bar was occupying.
///
/// Android: [SystemUiMode.manual] with only [SystemUiOverlay.bottom] enabled --
/// status bar hidden, navigation/gesture bar kept. Other platforms (iOS keeps
/// the status bar -- it is expected there and handled via SafeArea; desktop has
/// no system bars) keep the prior edge-to-edge behaviour. An open book/video
/// still uses `immersiveSticky` (both bars hidden) on open and the reader
/// restores its own mode on exit via `AppModel.closeMedia`, which calls back here.
Future<void> setHomeShellSystemUiMode() async {
  if (Platform.isAndroid) {
    await SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: <SystemUiOverlay>[SystemUiOverlay.bottom],
    );
    return;
  }
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
}

/// Windows/Linux 桌面用 MD3 的钳制滚动（去掉 iOS 风格回弹）；macOS（Cupertino
/// 平台，刻意不动）与移动端保持原有可回弹物理。始终保留 AlwaysScrollable 外层，
/// 使短内容也可滚动 / 触发下拉刷新等行为。
ScrollPhysics desktopAwareScrollPhysics() {
  return const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics());
}

/// 让**横向**滚动区接受鼠标 / 触控板 / 触笔的拖动滚动。
///
/// Flutter 桌面的默认 `MaterialScrollBehavior.dragDevices` 不含
/// [PointerDeviceKind.mouse]：横排合集行、标签筛选栏、分段按钮条这类横向滚动区，
/// 用鼠标左键按住左右拖会**毫无反应**（用户实报），只能靠滚轮。这里显式放开鼠标 /
/// 触控板 / 触笔拖动，触屏行为不变。
///
/// 只包横向滚动区，**刻意不做成全局 `MaterialApp.scrollBehavior`**：垂直网格若
/// 也放开鼠标拖动滚动，会与卡片拖拽（`MediaCardDraggable` 里的 [Draggable]）抢
/// 手势竞技场，把「拖卡进合集」变成「拖动网格滚动」。横向区没有这个冲突——横拖
/// 归滚动、纵拖归拖卡，两者都要过 `kTouchSlop`、方向先满足者胜，正好是自然分工。
///
/// 同理，区内若有 `LongPressDraggable`（标签 chip）也不冲突：按下即动归滚动、
/// 按住不动满 `kLongPressTimeout` 归拖拽。
class HorizontalDragScrollable extends StatelessWidget {
  const HorizontalDragScrollable({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => ScrollConfiguration(
    behavior: ScrollConfiguration.of(context).copyWith(
      dragDevices: const <PointerDeviceKind>{
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.stylus,
        PointerDeviceKind.trackpad,
      },
    ),
    child: child,
  );
}

enum WindowSizeClass { compact, medium, expanded }

enum DesktopContentKind { readerShelf, dictionary, settings }

enum SupportingPaneSide { start, end }

/// Single source of truth for the Material compact/medium/expanded
/// breakpoints. [width] must be the **real physical viewport width** in
/// logical pixels — see [windowSizeClassReal] for why the raw logical width
/// handed down inside [FushiAppUiScale] is not it.
WindowSizeClass windowSizeClassForWidth(double width) {
  if (width >= 840) return WindowSizeClass.expanded;
  if (width >= 600) return WindowSizeClass.medium;
  return WindowSizeClass.compact;
}

/// Classify by the **real** viewport width.
///
/// BUG-401: inside [FushiAppUiScale] the subtree is laid out against a
/// virtual canvas of `realViewport / scale` (so visual scaling can fill the
/// screen). A breakpoint that reads that inflated logical width never falls
/// into [WindowSizeClass.compact] on desktop — the window's real width could
/// shrink, but the logical width stayed high, so the phone (bottom-bar)
/// layout was unreachable. The real width is `logicalWidth * scale`.
///
/// [appUiScale] is the net [FushiAppUiScale.of] factor at the call site
/// (1.0 below the neutraliser, on undecorated routes, or when no scale
/// ancestor exists). A non-finite / non-positive scale degrades to identity
/// (treat the logical width as already-real).
WindowSizeClass windowSizeClassReal(double logicalWidth, double appUiScale) {
  final bool usableScale =
      appUiScale.isFinite && !appUiScale.isNaN && appUiScale > 0;
  final double realWidth = usableScale
      ? logicalWidth * appUiScale
      : logicalWidth;
  return windowSizeClassForWidth(realWidth);
}

/// [DesktopContentLayout] 的侧向留白。媒体墙类页面（[DesktopContentKind.readerShelf]：
/// 书架/视频/游戏/漫画目录/来源页）恒为零——卡片自带内边距，宽屏上再叠 16/24px
/// 强制侧向留白只是在侧栏与内容间挤出一条空带（用户实报「首页左右强制的间距」）。
/// 查词/设置是文字流正文，贴边可读性差，宽屏保留 16/24px。
EdgeInsets desktopContentPadding(
  WindowSizeClass sizeClass,
  DesktopContentKind kind,
) {
  if (kind == DesktopContentKind.readerShelf) return EdgeInsets.zero;
  return switch (sizeClass) {
    WindowSizeClass.compact => EdgeInsets.zero,
    WindowSizeClass.medium => const EdgeInsets.symmetric(horizontal: 16),
    WindowSizeClass.expanded => const EdgeInsets.symmetric(horizontal: 24),
  };
}

double readerShelfGridExtentForWidth(double width) {
  if (width >= 1280) return 210;
  if (width >= 960) return 190;
  if (width >= 600) return 180;
  return 150;
}

double readerShelfGridExtentForLayout({
  required double mediaWidth,
  double? contentWidth,
}) {
  return readerShelfGridExtentForWidth(contentWidth ?? mediaWidth);
}

double supportingPaneWidthForLayout(double width) {
  return (width * 0.3).clamp(280.0, 360.0);
}

/// 书籍 / 视频快捷设置切换到宽窗 master-detail（左父菜单 + 右详情）的**宽度**阈值。
/// 窄于此值走窄窗 push。
///
/// 与 [kFushiSettingsWideMinHeight] 一起构成确定性的几何判据
/// `_isWide = maxWidth >= 阈值 && maxHeight >= 阈值`：两个 sheet 共用同一组常量，
/// 同一台设备 / 同一窗口尺寸下视频与书籍必然同时进 / 同时不进横屏（不再用「post-frame
/// 测左父菜单内容是否溢出」那套会随内容高度发散、导致同设备两种表现的回退）。
const double kFushiSettingsWideThreshold = 560.0;

/// 书籍 / 视频快捷设置进入宽窗 master-detail 所需的**最小可用高度**阈值。窗口比这
/// 更矮时左父菜单放不下，回退窄窗 push（不出滚动条）。书籍设置已把阅读进度并入右侧
/// 外观详情、左父菜单只留分类导航 + 动作，使两个 sheet 的左栏都能在此高度内放下。
const double kFushiSettingsWideMinHeight = 440.0;

/// 桌面宽窗下书籍 / 视频 / 阅读器快捷设置弹窗（[FushiDialogFrame]）的最大内容宽度。
/// 全屏 push 的设置类页面（如 `BookCssEditorPage`）也用它约束正文宽度，与限宽弹窗
/// 里的兄弟设置页保持同宽，消除各处重复出现的 `900` 魔法数。
const double kFushiSettingsDialogMaxWidth = 900.0;

class DesktopContentLayout extends StatelessWidget {
  const DesktopContentLayout({
    required this.kind,
    required this.child,
    super.key,
  });

  final DesktopContentKind kind;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // BUG-401: classify on the real physical width so a desktop window
        // dragged narrow collapses the shelf/dictionary/settings body into
        // the compact (full-bleed) layout instead of staying expanded.
        final WindowSizeClass sizeClass = windowSizeClassReal(
          constraints.maxWidth,
          FushiAppUiScale.of(context),
        );
        final Widget padded = Padding(
          padding: desktopContentPadding(sizeClass, kind),
          child: child,
        );
        return padded;
      },
    );
  }
}

class MaterialSupportingPaneLayout extends StatelessWidget {
  const MaterialSupportingPaneLayout({
    required this.primary,
    required this.supporting,
    super.key,
    this.supportingSide = SupportingPaneSide.end,
    this.minSplitWidth = 840,
    this.supportingWidth,
    this.dividerColor,
    this.showDivider = true,
  });

  final Widget primary;
  final Widget supporting;
  final SupportingPaneSide supportingSide;
  final double minSplitWidth;
  final double? supportingWidth;
  final Color? dividerColor;

  /// 为 false 时两个窗格之间不画 1px 分隔线（也不占那 1px），窗格边界只由各自
  /// 的内容表达。设置主页的宽屏主从用它：用户实报窗格之间那条竖线多余。
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (constraints.maxWidth < minSplitWidth) return primary;

        final double resolvedSupportingWidth =
            supportingWidth ??
            supportingPaneWidthForLayout(constraints.maxWidth);
        final Widget fixedSupporting = SizedBox(
          width: resolvedSupportingWidth,
          child: supporting,
        );
        final Widget flexiblePrimary = Expanded(child: primary);

        return Row(
          // stretch (not the Row default center) so each pane gets a tight,
          // full-height constraint. Under center the panes receive a LOOSE
          // height, so a detail pane built from an own-scrolling
          // SingleChildScrollView shrink-wraps to its content and is then
          // vertically centered — a short settings page (e.g. the audiobook
          // destination with only a couple of desktop-visible toggles) floated
          // to the middle instead of hugging the top. A tight height makes the
          // scroll view fill the pane, so its content stays top-aligned.
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: supportingSide == SupportingPaneSide.start
              ? <Widget>[
                  fixedSupporting,
                  flexiblePrimary,
                ]
              : <Widget>[
                  flexiblePrimary,
                  fixedSupporting,
                ],
        );
      },
    );
  }
}
