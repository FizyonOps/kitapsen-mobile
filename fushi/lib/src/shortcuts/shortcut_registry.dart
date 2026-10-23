import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' hide ModifierKey;
import 'package:fushi/src/shortcuts/input_binding.dart';
import 'package:fushi/src/shortcuts/shortcut_action.dart';
import 'package:fushi/src/shortcuts/shortcut_defaults.dart';

/// 快捷键注册表：平台默认绑定（Kitapsen 版没有改键界面，绑定恒为默认表）。
class FushiShortcutRegistry extends ChangeNotifier {
  final Map<ShortcutAction, ShortcutBindingSet> _bindings = {};

  ShortcutBindingSet bindingsFor(ShortcutAction action) =>
      _bindings[action] ?? const ShortcutBindingSet();

  void loadDefaults(TargetPlatform platform) {
    _bindings
      ..clear()
      ..addAll(ShortcutDefaults.forPlatform(platform));
    notifyListeners();
  }

  /// 解析按下的键到 scope 内绑定的动作。正常路径走 [InputBinding.==] 精确相等
  /// （logicalKey + modifiers）。
  ///
  /// TODO-847：IME 激活时 Flutter 引擎把 KeyDownEvent 的 logicalKey 改写成
  /// [LogicalKeyboardKey.process]，精确相等永远失败、全表面快捷键失效。
  /// physicalKey（USB HID 扫描码）不受 IME 改写，故仅当 `key == process &&
  /// physicalKey != null` 时启用物理键回退分支：在 modifiers 完全相同的前提下按
  /// binding 的 [InputBinding.physicalKey] 比对。调用方在文本框 composing 时应传
  /// `physicalKey: null` 关闭回退，避免 IME 打字误触快捷键。
  ///
  /// 已知限制：物理回退仅对 US-QWERTY 物理布局正确（见 [InputBinding._logicalToPhysical]）。
  ShortcutAction? resolveKeyboard(
    LogicalKeyboardKey key, {
    required Set<ModifierKey> modifiers,
    required ShortcutScope scope,
    PhysicalKeyboardKey? physicalKey,
  }) {
    final target = InputBinding(key: key, modifiers: modifiers);
    for (final action in ShortcutAction.actionsForScope(scope)) {
      final bindings = _bindings[action];
      if (bindings == null) continue;
      for (final kb in bindings.keyboardBindings) {
        if (kb == target) return action;
      }
    }
    if (key == LogicalKeyboardKey.process && physicalKey != null) {
      for (final action in ShortcutAction.actionsForScope(scope)) {
        final bindings = _bindings[action];
        if (bindings == null) continue;
        for (final kb in bindings.keyboardBindings) {
          if (setEquals(kb.modifiers, modifiers) &&
              kb.physicalKey != null &&
              kb.physicalKey == physicalKey) {
            return action;
          }
        }
      }
    }
    return null;
  }

  ShortcutAction? resolveGamepad(
    GamepadButton button, {
    required ShortcutScope scope,
  }) {
    final target = GamepadBinding(button);
    for (final action in ShortcutAction.actionsForScope(scope)) {
      final bindings = _bindings[action];
      if (bindings == null) continue;
      for (final gp in bindings.gamepadBindings) {
        if (gp == target) return action;
      }
    }
    return null;
  }

  ShortcutAction? resolveMouse(
    int button, {
    required ShortcutScope scope,
  }) {
    final target = MouseBinding(button);
    for (final action in ShortcutAction.actionsForScope(scope)) {
      final bindings = _bindings[action];
      if (bindings == null) continue;
      for (final mb in bindings.mouseBindings) {
        if (mb == target) return action;
      }
    }
    return null;
  }
}
