import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
// Cross-platform controller plugin: GameInput on Windows, GameController on
// iOS/macOS, evdev/SDL on Linux. Aliased because it also exports a
// `GamepadButton` enum that would clash with Hibiki's.

import 'package:fushi/src/focus/fushi_focus_controller.dart';
import 'package:fushi/src/focus/fushi_focus_scroll.dart';
import 'package:fushi/src/shortcuts/input_binding.dart';
import 'package:fushi/src/shortcuts/shortcut_registry.dart';

/// Intent dispatched for a physical gamepad button on platforms where Flutter
/// does NOT deliver `gameButton*` key events (desktop / Apple). The active page
/// (reader/home) registers an [Actions] handler that resolves it against the
/// shortcut registry for its own scope — so polled controller input ends at the
/// exact same actions as Android's native key-event path.
///
/// The handler must return `true` when it consumed the button (so the service
/// knows not to apply the global navigation fallback) and `false`/null
/// otherwise.
@immutable
class GamepadButtonIntent extends Intent {
  const GamepadButtonIntent(this.button);

  final GamepadButton button;
}

/// Dispatches a normalized gamepad [button] to the [GamepadButtonIntent]
/// handler nearest [context]. Returns true only when a focused page/widget
/// explicitly consumes the button.
bool dispatchGamepadButtonIntent(
  BuildContext context,
  GamepadButton button,
) {
  return Actions.maybeInvoke<GamepadButtonIntent>(
        context,
        GamepadButtonIntent(button),
      ) ==
      true;
}

/// Converts Android/native controller key events into the same focused
/// [GamepadButtonIntent] path used by the desktop poller. TODO-700 T1: B is no
/// longer special-cased — it dispatches like every other button so the focused
/// page (reader → audiobookPrevSentence, etc.) gets first dibs, and the
/// outermost [wrapWithGlobalNavigation] resolves it against the registry's
/// globalBack only when no nearer handler consumed it.
KeyEventResult dispatchNativeGamepadButtonIntent(KeyEvent event) {
  if (event is! KeyDownEvent) return KeyEventResult.ignored;
  final GamepadButton? button = GamepadButton.fromKeyEvent(event);
  if (button == null) {
    return KeyEventResult.ignored;
  }

  final BuildContext? context = FocusManager.instance.primaryFocus?.context;
  if (context == null) return KeyEventResult.ignored;
  return dispatchGamepadButtonIntent(context, button)
      ? KeyEventResult.handled
      : KeyEventResult.ignored;
}

/// Wraps a focusable widget so a gamepad long-press (hold A) invokes the SAME
/// [onLongPress] callback a mouse long-press would. Place it ABOVE the widget
/// that takes focus (e.g. around a focusable list tile) so the
/// [GamepadLongPressIntent] dispatched to the focused node bubbles here. A null
/// [onLongPress] is a transparent pass-through.
class GamepadLongPressActions extends StatefulWidget {
  const GamepadLongPressActions({
    required this.onLongPress,
    required this.child,
    super.key,
  });

  final VoidCallback? onLongPress;
  final Widget child;

  @override
  State<GamepadLongPressActions> createState() =>
      _GamepadLongPressActionsState();
}

class _GamepadLongPressActionsState extends State<GamepadLongPressActions> {
  Timer? _aHoldTimer;
  bool _aLongFired = false;

  @override
  void dispose() {
    _clearAHold();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.onLongPress == null) return widget.child;
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: _handleNativeGamepadKey,
      child: widget.child,
    );
  }

  KeyEventResult _handleNativeGamepadKey(FocusNode node, KeyEvent event) {
    if (event.logicalKey != LogicalKeyboardKey.gameButtonA) {
      return KeyEventResult.ignored;
    }
    if (event is KeyDownEvent) {
      if (_aHoldTimer != null) return KeyEventResult.handled;
      _aLongFired = false;
      _aHoldTimer = Timer(
        const Duration(milliseconds: GamepadFrameProcessor.longPressMs),
        () {
          _aHoldTimer = null;
          _aLongFired = true;
          if (mounted) widget.onLongPress?.call();
        },
      );
      return KeyEventResult.handled;
    }
    if (event is KeyRepeatEvent) {
      return KeyEventResult.handled;
    }
    if (event is KeyUpEvent) {
      final bool longFired = _aLongFired;
      _clearAHold();
      if (!longFired) {
        final BuildContext targetContext =
            FocusManager.instance.primaryFocus?.context ?? context;
        Actions.maybeInvoke<ActivateIntent>(
          targetContext,
          const ActivateIntent(),
        );
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _clearAHold() {
    _aHoldTimer?.cancel();
    _aHoldTimer = null;
    _aLongFired = false;
  }
}

/// Bridges physical game controllers into Hibiki's input pipeline on platforms
/// where the Flutter engine does NOT surface controller buttons as
/// `LogicalKeyboardKey.gameButton*` key events.
///
/// - **Android**: the engine already delivers gamepad buttons / D-pad as key
///   events, which the reader/home `Focus.onKeyEvent` handlers resolve, so the
///   `gamepads` POLLER is not started (it would double-deliver). TODO-939: the
///   highlight-strategy tracking (pointer route + key handler + startup seed)
///   STILL runs here, so a focus ring lit by a controller/D-pad key event drops
///   back to touch on the next tap/swipe instead of staying stuck.
/// - **Windows / iOS / macOS / Linux**: uses the `gamepads` plugin (GameInput /
///   GameController / evdev), normalized through one [GamepadFrameProcessor] so
///   every platform shares the SAME normalization + dispatch path.
///
/// Every source ends at the SAME action set. Dispatch order for one button
/// mirrors the key-event path:
///   1. [GamepadButtonIntent] → the active page's registry-resolved action;
///   2. else A → [ActivateIntent], B → global back (maybePop),
///      D-pad → directional focus (same as arrow keys).
class GamepadService {
  GamepadService({
    required this.navigatorKey,
    this.registry,
    this.focusNavigationEnabled,
  });

  final GlobalKey<NavigatorState> navigatorKey;

  /// TODO-1113 P3: reads whether the experimental focus-navigation layer is
  /// currently enabled (the [FushiFocusRoot] is mounted). When it is, a mouse
  /// DOWN on a focus target carries directional focus there, so [_onPointerGlobal]
  /// must NOT immediately drop the ring back to touch on that press — otherwise
  /// the focus a click just placed would be invisible. Hover/move still hide the
  /// ring (a mouse merely passing over must not light it — 保守方案 b). Null in
  /// tests / when focus navigation is not wired: pointer events keep the old
  /// unconditional touch behaviour.
  final bool Function()? focusNavigationEnabled;

  /// Resolves which action a controller button is bound to, used by the global
  /// LB/RB scroll-page fallback so a user-rebound key still works. Null in tests
  /// that don't exercise scrolling.
  final FushiShortcutRegistry? registry;

  // Whether the global pointer route + key handler were installed by [start]
  // (only on supported platforms). Guards [dispose] from removing routes that
  // were never added — removeGlobalRoute asserts on an unknown route, which
  // would otherwise crash on Android (start() early-returns there) and in tests
  // that build AppModel without starting the service.
  bool _inputRoutesInstalled = false;

  /// Whether the platform needs the `gamepads` plugin POLLER. Android delivers
  /// controllers as engine `gameButton*` key events (so it needs NO poller —
  /// polling would double-deliver); every other non-web platform polls the
  /// plugin.
  ///
  /// NOTE: this gates ONLY the poller, NOT the highlight-strategy tracking.
  /// TODO-939: the input-device → [FocusHighlightStrategy] management (pointer
  /// route + key handler + startup seed) is installed on EVERY platform,
  /// including Android, so a focus ring lit by gamepad/keyboard navigation drops
  /// back to touch on the next pointer event. Before TODO-939 Android early-
  /// returned out of [start] entirely, leaving Flutter's `automatic` strategy in
  /// charge — and `automatic` never flips back to touch on a PointerMove
  /// (swipe), so a ring lit by a controller key event stayed stuck.
  static bool get needsGamepadPoller =>
      Platform.isIOS;

  void start() {
    if (_inputRoutesInstalled) return; // already started (idempotent)
    // TODO-939: the input-device → highlight-strategy tracking runs on EVERY
    // platform (Android included). Only the gamepads POLLER is platform-gated.
    _installHighlightTracking();
    if (!needsGamepadPoller) return; // Android: engine key events, no poller
    // Kitapsen ships the gamepads plugin without its native side: no poller.
    return;
  }

  /// TODO-939: seeds the explicit [FocusHighlightStrategy] management and the
  /// input-device routes that drive it. Platform-independent so Android also
  /// gets a touch-resetting pointer route (the fix for "滑动/手柄点亮焦点框消
  /// 不掉"): without it Android stays on Flutter's `automatic` strategy, which a
  /// gamepad key event pushes to traditional but a PointerMove (swipe) never
  /// pulls back to touch.
  void _installHighlightTracking() {
    // Start with the ring HIDDEN: it must only appear AFTER the user actually
    // drives with a controller or physical keyboard ("焦点应该在使用手柄或者键盘
    // 以后才会出来"). Desktop's default `automatic` strategy treats a mouse as
    // "traditional" and shows the ring from launch / during mouse use, which is
    // exactly what we don't want — so we own the strategy explicitly here and in
    // the pointer/key handlers below. On Android the same explicit ownership
    // makes the ring (lit by a controller/D-pad key event) drop back on any
    // touch/swipe, which Flutter's `automatic` strategy would not do for a move.
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTouch;
    // Track the active input device so the focus ring follows it (pointer →
    // hidden, hardware nav → shown). Installed on all platforms (TODO-939).
    GestureBinding.instance.pointerRouter.addGlobalRoute(_onPointerGlobal);
    HardwareKeyboard.instance.addHandler(_onKey);
    _inputRoutesInstalled = true;
  }

  void dispose() {
    if (_inputRoutesInstalled) {
      GestureBinding.instance.pointerRouter.removeGlobalRoute(_onPointerGlobal);
      HardwareKeyboard.instance.removeHandler(_onKey);
      _inputRoutesInstalled = false;
    }
  }

  // The focus ring follows the ACTIVE input device: hardware navigation
  // (gamepad / physical keyboard) shows it (alwaysTraditional); a pointer
  // (mouse / touch / trackpad) hides it (alwaysTouch). A polled gamepad emits no
  // FocusManager events, so the `automatic` strategy can't react to it — hence
  // we drive the strategy explicitly from each source. This is why a global
  // pointer route + a key handler are installed (on ALL platforms incl. Android,
  // TODO-939): clicking/tapping/swiping should NOT leave a focus ring behind
  // ("点击正常使用不需要焦点"), while keyboard / gamepad navigation should.
  void _setHighlightForHardwareNav() {
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
  }

  void _onPointerGlobal(PointerEvent event) {
    // Any pointer (mouse/touch/trackpad) is a "pointing" device — no focus ring.
    // Hover/move included so a mouse move after gamepad nav hides the ring.
    if (event is PointerDownEvent ||
        event is PointerHoverEvent ||
        event is PointerMoveEvent ||
        event is PointerPanZoomStartEvent) {
      // TODO-1113 P3: when focus navigation is enabled, a mouse DOWN carries
      // directional focus to the clicked target (FushiFocusTarget), so the ring
      // must stay lit on that press to show where focus landed. Hover/move/pan
      // still hide it (a mouse merely passing over must not keep a ring — 保守
      // 方案 b: no ring flicker for pure-mouse users). Everything else, and when
      // focus navigation is off, keeps the old unconditional touch behaviour.
      if (event is PointerDownEvent &&
          (focusNavigationEnabled?.call() ?? false)) {
        return;
      }
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTouch;
    }
  }

  bool _onKey(KeyEvent event) {
    // Only ACTUAL focus navigation (arrow keys / Tab) should light the ring.
    // Typing a letter, Esc, a shortcut, or any release edge previously flipped
    // the strategy to alwaysTraditional, leaving a residual ring on the default
    // build (BUG-398). Never consume the event either way.
    if (!gamepadKeyDrivesFocusRing(event)) return false;
    // An arrow the focused text field consumes for its caret is editing, not
    // focus traversal — keep touch mode so the caret edit does not light a ring.
    if (_arrowEditsTextCaret(event)) return false;
    _setHighlightForHardwareNav();
    return false;
  }

  /// Drops the focus ring back to touch mode. Called when the screen changes
  /// (route push/pop or home-tab switch) so a ring lit by keyboard/gamepad
  /// navigation on one surface is not carried onto the next one (BUG-398). Safe
  /// to call unconditionally: [start] also seeds [FocusHighlightStrategy.alwaysTouch]
  /// on every platform (TODO-939), so this just re-asserts it. On Android, with
  /// the explicit strategy now owned by this service, the reset is no longer
  /// immediately clobbered by `automatic` on the next input — it actually holds.
  void resetHighlightForScreenSwitch() {
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTouch;
  }

}

/// Whether [event] is a keyboard event that should ARM the visible focus ring
/// (switch the highlight strategy to traditional). Only true focus navigation
/// qualifies: an arrow key on its move edge ([KeyDownEvent]/[KeyRepeatEvent]) or
/// Tab on its press edge. A plain letter, Escape, a shortcut combo, or any
/// release edge ([KeyUpEvent]) returns false — those are not focus traversal and
/// must not light the ring (BUG-398: the ring previously appeared on the first
/// keystroke and lingered).
///
/// This is the single arbiter so the gamepad service and its tests agree on
/// exactly which keys reveal the ring; the text-field caret carve-out is applied
/// by the caller (an arrow the caret consumes is editing, not navigation).
@visibleForTesting
bool gamepadKeyDrivesFocusRing(KeyEvent event) {
  if (arrowFocusMoveDirection(event) != null) return true;
  return event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.tab;
}

/// Whether [event] is an arrow key the currently-focused text field consumes for
/// its caret rather than focus traversal. Mirrors global_navigation's caret rule:
/// horizontal arrows always drive the caret; vertical arrows drive it only in a
/// multi-line field. No focused field → false (the arrow is pure navigation).
bool _arrowEditsTextCaret(KeyEvent event) {
  final TraversalDirection? dir = arrowFocusMoveDirection(event);
  if (dir == null) return false; // Tab / non-arrow: never a caret edit.
  final EditableText? editable = focusedEditableText();
  if (editable == null) return false;
  if (dir == TraversalDirection.left || dir == TraversalDirection.right) {
    return true;
  }
  final int? maxLines = editable.maxLines;
  return maxLines == null || maxLines > 1; // null = unbounded = multi-line
}

/// A [NavigatorObserver] that resets the focus highlight to touch mode on every
/// route push/pop/replace. Wired into [MaterialApp.navigatorObservers] so a
/// focus ring lit by keyboard/gamepad navigation on one page does not get
/// carried onto a freshly-entered page (BUG-398). The reset is a plain callback
/// (typically `GamepadService.resetHighlightForScreenSwitch`) so the observer
/// stays decoupled from the service and is unit-testable on its own.
class HighlightResetNavigatorObserver extends NavigatorObserver {
  HighlightResetNavigatorObserver(this._onScreenSwitch);

  final VoidCallback _onScreenSwitch;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _onScreenSwitch();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _onScreenSwitch();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _onScreenSwitch();
  }
}

/// Maps a [TraversalDirection] to the [AxisDirection] of the scroll it would
/// drive, so edge-takeover scrolling only fires on the matching axis (a
/// left/right press never scrolls a vertical list, and vice versa).
AxisDirection axisDirectionFromTraversal(TraversalDirection direction) {
  switch (direction) {
    case TraversalDirection.up:
      return AxisDirection.up;
    case TraversalDirection.down:
      return AxisDirection.down;
    case TraversalDirection.left:
      return AxisDirection.left;
    case TraversalDirection.right:
      return AxisDirection.right;
  }
}

/// Maps a keyboard arrow key to the [TraversalDirection] it drives for focus
/// navigation; any non-arrow key returns null. Shared by the home page handler
/// and the app-wide [wrapWithGlobalNavigation] handler so both read arrows the
/// same way.
TraversalDirection? arrowTraversalDirection(LogicalKeyboardKey key) {
  if (key == LogicalKeyboardKey.arrowUp) return TraversalDirection.up;
  if (key == LogicalKeyboardKey.arrowDown) return TraversalDirection.down;
  if (key == LogicalKeyboardKey.arrowLeft) return TraversalDirection.left;
  if (key == LogicalKeyboardKey.arrowRight) return TraversalDirection.right;
  return null;
}

/// Whether [event] is a keyboard event that should drive a single step of
/// directional FOCUS movement — i.e. an arrow key on its press edge
/// ([KeyDownEvent]) OR an OS auto-repeat ([KeyRepeatEvent]).
///
/// Holding an arrow key makes the OS emit one [KeyDownEvent] followed by a
/// stream of [KeyRepeatEvent]s until release; treating BOTH as a move keeps
/// focus advancing continuously while held instead of one step per discrete
/// press (“一个字一个字按过去还是太吃手指”). [KeyUpEvent] is excluded so release
/// does not move. Returns the [TraversalDirection] for the key, or null when the
/// event/key should not move focus (non-arrow key, or a [KeyUpEvent]).
///
/// Both [event] type and the arrow→direction mapping are centralized here so the
/// home page handler and the app-wide wrapper agree on exactly which keyboard
/// events continuously move focus — the move itself stays the caller's
/// [gamepadMoveFocusInDirection], so KeyDown and KeyRepeat share one geometry/
/// reading-order path (the framework's bare DirectionalFocusAction does NOT
/// carry Hibiki's reading-order fallback, so relying on it for repeats would
/// dead-end at row/panel edges where the press edge advanced fine).
TraversalDirection? arrowFocusMoveDirection(KeyEvent event) {
  if (event is! KeyDownEvent && event is! KeyRepeatEvent) return null;
  return arrowTraversalDirection(event.logicalKey);
}

/// The [EditableText] that currently holds focus, or null when no text field is
/// focused. Lets callers decide per-direction whether an arrow key should drive
/// the text caret or move focus (single-line fields don't use up/down).
///
/// [EditableText] owns its focus through an inner `Focus(debugLabel:
/// 'EditableText')`, so the primary focus node's own `context.widget` is that
/// `Focus`, NOT the [EditableText] — a bare `is EditableText` check would always
/// miss. The [EditableText] is that Focus's ancestor element, so we look it up.
EditableText? focusedEditableText() {
  final BuildContext? c = FocusManager.instance.primaryFocus?.context;
  if (c == null) return null;
  if (c.widget is EditableText) return c.widget as EditableText;
  return c.findAncestorWidgetOfExactType<EditableText>();
}

/// Moves keyboard/gamepad focus one step in [direction] from the focus tree
/// rooted at [context]. Used by the gamepad service (and unit-tested directly).
///
/// Strategy — predictable, never a random jump:
///  * Nothing usefully focused → bootstrap onto the first focusable in the
///    scope, so the first directional press lands somewhere visible.
///  * A control is focused → move geometrically in [direction]; if there is no
///    focusable that way (e.g. moving down off an app-bar with no control
///    directly beneath it) fall back to reading-order traversal so the user can
///    still progress: down/right = next, up/left = previous.
///
///
/// With a Hibiki focus root the controller is the ONLY engine: its candidate
/// set covers registered targets and native focusables of the current focus
/// scope alike, so when it finds nothing in [direction] the press only gets the
/// edge-scroll takeover below and otherwise stops at the edge. There is no
/// reading-order slide, so a shelf edge can escape to the side rail or top bar
/// without sliding sideways through shelf items.
///
/// Returns whether focus actually changed.
bool gamepadMoveFocusInDirection(
  BuildContext context,
  TraversalDirection direction,
) {
  final FushiFocusController? controller =
      FushiFocusRoot.maybeControllerOf(context);
  if (controller != null) {
    if (controller.move(fushiFocusDirectionFromTraversal(direction))) {
      return true;
    }
    // No target in this direction: take over and scroll the focused control's
    // nearest scrollable by a screen-fraction, so a long list/page does not
    // dead-end at its last focusable. Axis-matched so a left/right press never
    // scrolls a vertical list. At the scroll extent this returns false — i.e.
    // it simply stops at the edge.
    final BuildContext? focusContext =
        controller.activeContext ?? FocusManager.instance.primaryFocus?.context;
    if (controller.activeIsOnlyFocusableInNearestScrollable &&
        focusContext != null &&
        FushiFocusScroll.scrollByViewportFraction(
          focusContext,
          axisDirectionFromTraversal(direction),
          FushiFocusScroll.signedFractionFor(direction, 0.8),
        )) {
      return true;
    }
    // 手柄焦点重写：控制器的候选集已经包含当前作用域里的原生控件，它说「该方向
    // 没有目标」就是没有。旧实现在这里再跑一遍框架 focusInDirection——第二套
    // 引擎会落到控制器刻意排除的节点上（整页 key sink、受管复合控件的内部节点），
    // 同一次按键两套引擎结论不一致正是「焦点乱跳」的来源。
    return false;
  }

  return _movePrimaryFocusInDirection(
    context,
    direction,
    allowReadingOrderFallback: true,
  );
}

/// 键盘 ↑/↓ 的「先移焦、无目标才让给滚动」仲裁——与 D-pad 边缘接管同一套判据，
/// 返回 true = 焦点引擎接管了这次按键（焦点已移动 / 已 bootstrap 到首个目标），
/// 调用方不得再滚动；false = 该方向没有焦点目标，按键归页面滚动。
///
///   · 焦点导航开启（有 [FushiFocusRoot] 控制器）且本页登记了受管目标：走与 D-pad
///     完全相同的 [gamepadMoveFocusInDirection]（几何目标 → 阅读顺序 → 「列表内
///     只有自己可聚焦」时的边缘接管）。零受管目标时**不能**调 `move()`：它会经
///     ensureFocus 把持焦的页面 sink 踢到 app 级兜底节点（见
///     [FushiFocusController.hasFocusableTargets]），而焦点仍可能停在一个未登记的
///     原生控件上（可滚对话框里的 RadioListTile），那要落到下面的原生判据去移焦。
///   · 焦点导航关闭（默认安装）或本页零受管目标：没有引擎做 bootstrap，也**不该**有——用户裁定
///     关闭时 Tab 不遍历焦点，方向键同理不该从空焦点凭空跳到首个控件（那会把
///     「按 ↓ 想滚页」变成「焦点跳走 + 页面被 ensureVisible 甩到别处」）。只有焦点
///     已经停在一个真实控件上（非 scope / 非 skipTraversal / 可聚焦）且该方向真有
///     几何目标时，才由框架同款的 [FocusNode.focusInDirection] 移焦。
///
/// 文本框聚焦的情形由调用方先用 [focusedEditableText] 排除，这里不重复判。
bool arrowKeyClaimedByFocus(
    BuildContext context, TraversalDirection direction) {
  final FushiFocusController? controller =
      FushiFocusRoot.maybeControllerOf(context, listen: false);
  if (controller != null && controller.hasFocusableTargets) {
    return gamepadMoveFocusInDirection(context, direction);
  }
  final FocusNode? origin = directionalFocusOrigin();
  return origin != null && origin.focusInDirection(direction);
}

/// 当前主焦点若是一个能作为方向移焦起点的真实控件就返回它；null、scope、不可
/// 聚焦、skip-traversal 的整页键事件 sink（从它的全屏矩形出发「往某个方向」没有
/// 意义）都返回 null。[_movePrimaryFocusInDirection] 的 bootstrap 判据与此同一份。
FocusNode? directionalFocusOrigin() {
  final FocusNode? primary = FocusManager.instance.primaryFocus;
  if (primary == null ||
      primary is FocusScopeNode ||
      !primary.canRequestFocus ||
      primary.skipTraversal) {
    return null;
  }
  return primary;
}

bool _movePrimaryFocusInDirection(
  BuildContext context,
  TraversalDirection direction, {
  required bool allowReadingOrderFallback,
}) {
  // Bootstrap when nothing is usefully focused: null, a scope, a non-focusable
  // node, or a skip-traversal wrapper (e.g. a full-page key-event sink — moving
  // "in a direction" from its whole-screen rect is meaningless, so jump to the
  // first real control instead).
  final FocusNode? primary = directionalFocusOrigin();
  if (primary == null) {
    return allowReadingOrderFallback && FocusScope.of(context).nextFocus();
  }
  if (primary.focusInDirection(direction)) return true;
  if (!allowReadingOrderFallback) return false;
  switch (direction) {
    case TraversalDirection.down:
    case TraversalDirection.right:
      return primary.nextFocus();
    case TraversalDirection.up:
    case TraversalDirection.left:
      return primary.previousFocus();
  }
}

/// Pure, platform-free normalization of controller frames into Hibiki
/// [GamepadButton] presses and a single repeating directional signal.
///
/// Frames use the [GamepadFrameBits] bitmask layout. Separated from the I/O so
/// the edge-detection, analog-stick dead-zone/hysteresis and auto-repeat logic
/// can be unit-tested by feeding synthetic frames with controlled timestamps.
abstract class GamepadFrameProcessor {

  /// Hold threshold that turns A into a long-press (matches mouse long-press).
  static const int longPressMs = 500;

}
