import 'package:flutter/services.dart';
import 'package:fushi/src/shortcuts/input_binding.dart';

/// Pure router for reader cursor input. No widget/WebView state — both the
/// Android key-event path and the desktop polled-gamepad path funnel through
/// these maps so a controller and a keyboard reach the exact same cursor
/// actions (mirrors how [GamepadFrameProcessor] is a platform-free normalizer).
abstract class ReaderCaretRouter {

  /// Whether a keyboard key should ENTER the cursor when it is inactive and the
  /// book (not the bottom chrome) holds focus.
  ///
  /// TODO-700 T7: the enter trigger is REMAPPABLE. [enterKeys] is the set of
  /// keyboard keys bound to [ShortcutAction.readerEnterCaret]; the reader passes
  /// it from the registry. When omitted (pure unit tests, or any call site
  /// without a registry) it defaults to the original hard-coded `Enter` +
  /// `gameButtonA`, so existing behaviour and tests are unchanged.
  ///
  /// [focusNavEnabled] mirrors the global keyboard/gamepad focus navigation
  /// switch: when the switch is off, reader caret navigation stays inactive.
  static bool isEnterTriggerKeyboard(
    LogicalKeyboardKey key, {
    bool focusNavEnabled = true,
    Set<LogicalKeyboardKey>? enterKeys,
  }) =>
      focusNavEnabled && (enterKeys ?? _defaultEnterKeys).contains(key);

  /// Whether a gamepad button should ENTER the cursor when it is inactive.
  ///
  /// TODO-700 T7: REMAPPABLE — [enterButtons] is the set of gamepad buttons bound
  /// to [ShortcutAction.readerEnterCaret] (passed from the registry by the
  /// reader). When omitted it defaults to the original hard-coded `A`, so the
  /// pure unit tests and any registry-less call site behave exactly as before.
  /// Gated on [focusNavEnabled] the same way as [isEnterTriggerKeyboard].
  static bool isEnterTriggerGamepad(
    GamepadButton button, {
    bool focusNavEnabled = true,
    Set<GamepadButton>? enterButtons,
  }) =>
      focusNavEnabled &&
      (enterButtons ?? _defaultEnterButtons).contains(button);

  // Non-const: LogicalKeyboardKey overrides ==, so it cannot live in a const Set.
  static final Set<LogicalKeyboardKey> _defaultEnterKeys = <LogicalKeyboardKey>{
    LogicalKeyboardKey.enter,
    LogicalKeyboardKey.gameButtonA,
  };
  static const Set<GamepadButton> _defaultEnterButtons = <GamepadButton>{
    GamepadButton.a,
  };
}
