part of '../reader_fushi_page.dart';

/// 阅读器鼠标通道的解析阶梯：reader → universal → global。
///
/// 与 [_ReaderInput._handleKeyEvent] 的键盘阶梯同序（页面专属优先）。页面解析到
/// 但执行体没接（返回 ignored）时**不认领**，app 根照常兜底——这正是键盘「返回
/// ignored 就冒泡」的等价物。
const List<ShortcutScope> kReaderMouseLadder = <ShortcutScope>[
  ShortcutScope.reader,
  ShortcutScope.universal,
  ShortcutScope.global,
];

/// 外接键盘 / 手柄 / 鼠标输入：解析注册表绑定并执行阅读器动作。
extension _ReaderInput on _ReaderFushiPageState {
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    // TODO-1370：长按方向键连续翻页。按住一个绑定到「可重复」阅读器动作（翻页）的
    // 键时，OS 自动重复的 [KeyRepeatEvent] 继续触发同一动作；离散动作仍一次一按。
    // 仅键盘：原生手柄键（含 Android D-pad 的 KeyRepeat）保持按下沿路由。必须落在
    // KeyDown-only 闸门之前，否则闸门会先把 KeyRepeat 拦掉。
    if (event is KeyRepeatEvent) {
      if (GamepadButton.fromKeyEvent(event) != null) {
        return KeyEventResult.ignored;
      }
      final ShortcutAction? repeatAction = _resolveReaderKeyboardShortcut(
        event,
        modifiers: activeModifierKeys(),
        imeFallbackPhysicalKey:
            focusedEditableText() == null ? event.physicalKey : null,
      );
      if (repeatAction != null &&
          isRepeatableReaderKeyboardShortcut(repeatAction)) {
        return _executeShortcutAction(repeatAction);
      }
      return KeyEventResult.ignored;
    }

    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    // Android/native controller events can surface as KeyEvents. D-pad arrows
    // share logical keys with keyboard arrows, so controller-like sources must
    // enter the gamepad registry before keyboard arrow reversal runs.
    final GamepadButton? nativeGamepadButton = GamepadButton.fromKeyEvent(
      event,
    );
    if (nativeGamepadButton != null) {
      return _handleGamepadButton(nativeGamepadButton)
          ? KeyEventResult.handled
          : KeyEventResult.ignored;
    }

    // TODO-847: IME 激活时 logicalKey 被改写成 process，传 physicalKey 让 registry
    // 走物理键回退；文本框 composing 时（focusedEditableText != null）传 null 关闭
    // 回退，避免 IME 打字误触快捷键。
    final ShortcutAction? action = _resolveReaderKeyboardShortcut(
      event,
      modifiers: activeModifierKeys(),
      imeFallbackPhysicalKey:
          focusedEditableText() == null ? event.physicalKey : null,
    );
    if (action == null) return KeyEventResult.ignored;
    return _executeShortcutAction(action);
  }

  /// 把键盘 [event] 解析成它触发的阅读器 [ShortcutAction]：裸左右键按阅读方向翻页
  /// 且尊重绑定（BUG-099/TODO-992），其余走 reader scope，最后兜底 universal 的
  /// 「返回上一级」。由按下沿与长按两条路径共用，保证两者解析结果一致。
  ShortcutAction? _resolveReaderKeyboardShortcut(
    KeyEvent event, {
    required Set<ModifierKey> modifiers,
    required PhysicalKeyboardKey? imeFallbackPhysicalKey,
  }) {
    final ShortcutAction? readerAction =
        appModel.shortcutRegistry.resolveKeyboard(
      event.logicalKey,
      modifiers: modifiers,
      scope: ShortcutScope.reader,
      physicalKey: imeFallbackPhysicalKey,
    );
    final ShortcutAction? arrowOverride = resolveReaderArrowPageTurn(
      key: event.logicalKey,
      modifiers: modifiers,
      rtl: _isRtlReading,
      boundAction: readerAction,
      reverse: ReaderFushiSource.instance.reverseArrowPageTurn,
      physicalKey: imeFallbackPhysicalKey,
    );
    return arrowOverride ??
        readerAction ??
        appModel.shortcutRegistry.resolveKeyboard(
          event.logicalKey,
          modifiers: modifiers,
          scope: ShortcutScope.universal,
          physicalKey: imeFallbackPhysicalKey,
        );
  }

  /// TODO-1078：WebView 内容层捕获的裸 Space（WebView 抢走键盘焦点后
  /// _focusNode.onKeyEvent 收不到键，见 [webview.part] 的 `onSpaceKey` 桥）解析成
  /// reader scope 里裸 Space 的真实绑定（默认 [ShortcutAction.readerPageForward]）。
  /// 返回 null 表示裸 Space 当前无绑定，调用方不执行。
  ShortcutAction? _resolveWebViewSpaceAction() {
    return appModel.shortcutRegistry.resolveKeyboard(
      LogicalKeyboardKey.space,
      modifiers: const <ModifierKey>{},
      scope: ShortcutScope.reader,
    );
  }

  /// Handles a gamepad button delivered via [GamepadButtonIntent] or an Android
  /// gameButton key event. Returns true when consumed; false lets the
  /// GamepadService apply its directional-focus / activate / global-back
  /// fallback.
  bool _handleGamepadButton(GamepadButton button) {
    final ShortcutAction? action =
        appModel.shortcutRegistry.resolveGamepad(
          button,
          scope: ShortcutScope.reader,
        ) ??
        appModel.shortcutRegistry.resolveGamepad(
          button,
          scope: ShortcutScope.universal,
        );
    if (action == null) return false;
    return _executeShortcutAction(action) == KeyEventResult.handled;
  }

  KeyEventResult _executeShortcutAction(ShortcutAction action) {
    switch (action) {
      case ShortcutAction.readerPageForward:
        _paginate(ReaderNavigationDirection.forward);
        return KeyEventResult.handled;
      case ShortcutAction.readerPageBackward:
        _paginate(ReaderNavigationDirection.backward);
        return KeyEventResult.handled;
      case ShortcutAction.globalBack:
        // 窗口全屏中 → 先退全屏、留在书里；不在全屏才真的退书（次序见
        // [_exitWindowFullscreenOrPopReader]）。
        unawaited(_exitWindowFullscreenOrPopReader());
        return KeyEventResult.handled;
      case ShortcutAction.readerToggleChrome:
        // BUG-1423: route through the mode-aware helper so a floating bottom bar
        // uses the same transient-visibility + auto-hide state machine as a
        // blank-content tap instead of flipping the invisible `_showChrome` gate.
        _toggleChromeFromShortcut();
        return KeyEventResult.handled;
      case ShortcutAction.readerOpenMenu:
        unawaited(_showAppearanceSheet());
        return KeyEventResult.handled;
      case ShortcutAction.readerOpenNavigation:
        unawaited(_showAppearanceSheet(initialSubPage: 'location'));
        return KeyEventResult.handled;
      case ShortcutAction.readerOpenGallery:
        _openGallery();
        return KeyEventResult.handled;
      case ShortcutAction.readerOpenStatistics:
        _openReadingStatistics();
        return KeyEventResult.handled;
      case ShortcutAction.readerToggleStudyClock:
        // 一键停 / 续阅读统计计时（默认 P），与状态行里那颗
        // [ReaderStudyClockButton] 同一入口。
        _toggleStudyClockManualPause();
        return KeyEventResult.handled;
      default:
        return KeyEventResult.ignored;
    }
  }
}
