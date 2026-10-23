import 'package:flutter/services.dart' hide ModifierKey;
import 'package:fushi/src/shortcuts/input_binding.dart';
import 'package:fushi/src/shortcuts/shortcut_action.dart';

abstract class ShortcutDefaults {
  static Map<ShortcutAction, ShortcutBindingSet> forPlatform(
    TargetPlatform platform,
  ) {
    switch (platform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        return _mobile;
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        return _base;
    }
  }

  static ShortcutBindingSet _kb(
    List<InputBinding> keyboard, [
    List<GamepadBinding> gamepad = const [],
  ]) =>
      ShortcutBindingSet(
        keyboardBindings: keyboard,
        gamepadBindings: gamepad,
      );

  static InputBinding _key(LogicalKeyboardKey key,
          [Set<ModifierKey> modifiers = const {}]) =>
      InputBinding(key: key, modifiers: modifiers);

  static const _gRB = GamepadBinding(GamepadButton.rb);
  static const _gLB = GamepadBinding(GamepadButton.lb);
  static const _gLT = GamepadBinding(GamepadButton.lt);
  static const _gRT = GamepadBinding(GamepadButton.rt);
  static const _gB = GamepadBinding(GamepadButton.b);
  static const _gY = GamepadBinding(GamepadButton.y);
  static const _gDpadRight = GamepadBinding(GamepadButton.dpadRight);
  static const _gDpadLeft = GamepadBinding(GamepadButton.dpadLeft);

  /// 外接键盘 / 手柄 / 鼠标的完整默认表；[_mobile] 由它按 scope 裁出。
  static final Map<ShortcutAction, ShortcutBindingSet> _base = {
    ShortcutAction.readerPageForward: _kb([
      _key(LogicalKeyboardKey.pageDown),
      _key(LogicalKeyboardKey.arrowRight),
      _key(LogicalKeyboardKey.arrowDown),
      _key(LogicalKeyboardKey.space),
    ], [
      _gRB,
      _gDpadRight
    ]),
    ShortcutAction.readerPageBackward: _kb([
      _key(LogicalKeyboardKey.pageUp),
      _key(LogicalKeyboardKey.arrowLeft),
      _key(LogicalKeyboardKey.arrowUp),
      _key(LogicalKeyboardKey.space, {ModifierKey.shift}),
    ], [
      _gLB,
      _gDpadLeft
    ]),
    // 底栏开关：键盘 M、手柄 Y（Esc 归 globalBack 的「返回」）。
    ShortcutAction.readerToggleChrome: _kb([
      _key(LogicalKeyboardKey.keyM),
    ], [
      _gY
    ]),
    ShortcutAction.readerOpenMenu: _kb([
      _key(LogicalKeyboardKey.keyT),
    ]),
    ShortcutAction.readerOpenNavigation: _kb([
      _key(LogicalKeyboardKey.keyF, {ModifierKey.ctrl}),
    ]),
    ShortcutAction.readerOpenGallery: _kb([
      _key(LogicalKeyboardKey.keyG),
    ]),
    ShortcutAction.readerOpenStatistics: _kb([
      _key(LogicalKeyboardKey.keyI),
    ]),
    ShortcutAction.readerToggleStudyClock: _kb([
      _key(LogicalKeyboardKey.keyP),
    ]),
    ShortcutAction.homeTabBooks: _kb([
      _key(LogicalKeyboardKey.digit1, {ModifierKey.ctrl}),
    ]),
    ShortcutAction.homeTabSettings: _kb([
      _key(LogicalKeyboardKey.digit3, {ModifierKey.ctrl}),
    ]),
    ShortcutAction.homeTabPrev: _kb([], [_gLT]),
    ShortcutAction.homeTabNext: _kb([], [_gRT]),
    ShortcutAction.homeFocusSearch: _kb([
      _key(LogicalKeyboardKey.keyF, {ModifierKey.ctrl}),
    ], [
      _gY
    ]),
    ShortcutAction.globalBack: _kb([
      _key(LogicalKeyboardKey.escape),
      _key(LogicalKeyboardKey.arrowLeft, {ModifierKey.alt}),
    ], [
      _gB
    ]),
    ShortcutAction.globalScrollPageDown: _kb([
      _key(LogicalKeyboardKey.pageDown),
    ], [
      _gRB
    ]),
    ShortcutAction.globalScrollPageUp: _kb([
      _key(LogicalKeyboardKey.pageUp),
    ], [
      _gLB
    ]),
    ShortcutAction.globalScrollLineDown: _kb([
      _key(LogicalKeyboardKey.arrowDown),
    ]),
    ShortcutAction.globalScrollLineUp: _kb([
      _key(LogicalKeyboardKey.arrowUp),
    ]),
    ShortcutAction.globalScrollToTop: _kb([
      _key(LogicalKeyboardKey.home),
    ]),
    ShortcutAction.globalScrollToBottom: _kb([
      _key(LogicalKeyboardKey.end),
    ]),
    ShortcutAction.globalToggleFullscreen: _kb([
      _key(LogicalKeyboardKey.f11),
    ]),
    ShortcutAction.globalContextMenu: const ShortcutBindingSet(
      mouseBindings: [MouseBinding(2)],
    ),
  };

  static final Map<ShortcutAction, ShortcutBindingSet> _mobile = {
    for (final action in ShortcutAction.values)
      action: () {
        final base = _base[action]!;
        switch (action.scope) {
          // 阅读器与「返回上一级」在移动端保留键盘绑定：外接键盘（平板 / DeX）上
          // 翻页与 Esc 同样该生效；没有外接键盘的设备上永不触发，无害。
          case ShortcutScope.reader:
          case ShortcutScope.universal:
            return ShortcutBindingSet(
              keyboardBindings: base.keyboardBindings,
              gamepadBindings: base.gamepadBindings,
            );
          // 首页 / 全局：手柄 + 鼠标（Android 可接鼠标，丢掉鼠标绑定会让
          // globalContextMenu 的右键菜单整个消失）。
          case ShortcutScope.home:
          case ShortcutScope.global:
            return ShortcutBindingSet(
              gamepadBindings: base.gamepadBindings,
              mouseBindings: base.mouseBindings,
            );
        }
      }(),
  };
}
