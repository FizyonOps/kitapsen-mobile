// GENERATED-NOTE: extracted from reader_fushi_page.dart (TODO-589 batch6).
part of '../reader_fushi_page.dart';

/// caret domain (keyboard / gamepad / shortcut key navigation + char-level
/// reading cursor: enter / exit / move / scroll-page / activate / lookup /
/// long-press / jump-dict / reanchor / refresh / chrome+header promotion)
/// extracted via part-of (TODO-589 batch6); shared private scope.
/// Behaviour-preserving: bodies are byte-for-byte verbatim except the three
/// `setState(` calls (in `_enterCaret` x2 and `_exitCaret`) forwarded through
/// the main shell `_rebuild(` helper (extensions cannot call the @protected
/// `State.setState` directly), plus the @protected popup-stack members
/// `topPopupState` / `topVisiblePopupIndex` / `dismissTopPopup` (same
/// invalid_use_of_protected_member restriction) routed through the shell
/// forwarders `_caretTopPopupState` / `_caretTopVisiblePopupIndex` /
/// `_caretDismissTopPopup`. The two class statics moved with this domain
/// (`_isReaderDirectCaretShortcut` / `_isRepeatableCaretMove`) and all of
/// their call sites live entirely inside this extension, so they are declared
/// as extension statics and referenced by bare name (no qualification needed).
///
/// The `@override` host-interface members (`onDictionaryStackChanged` /
/// `onDictionaryPopupRendered` and the `DictionaryCaretHost` getters/setters
/// `caretHostMounted` / `caretTopPopupState` / `caretTopVisiblePopupIndex` /
/// `caretSetState` / `caretExitPrimaryRing`) cannot live on an extension and
/// stay in the shell, reachable via the shared private class scope, as does
/// the audiobook middle-click helper `_seekToClickedSentence`.
/// 阅读器鼠标通道的解析阶梯：reader → audiobook → universal → global。
///
/// **Flutter 腿与 WebView(JS) 腿共用同一条**，且与 `_handleKeyEvent` 的键盘阶梯
/// 同序（页面专属优先）。
///
/// BUG-2031 修正：第一版给两条腿各写了一条阶梯——Flutter 侧刻意砍掉 universal /
/// global，理由是「那两段留给 app 根兜底，页面再解析一遍就会双派发」。两处都错：
///
/// 1. 防双派发的机制是 [MouseBindingDispatch] 的认领，不是「把阶梯修窄」。修窄
///    换来的是**动作降级**：`globalBack` 在页内解析不到，只能落到 app 根那份平铺的
///    `Navigator.maybePop()`，而键盘 / 手柄的 `globalBack` 走的是本页**逐级退出**
///    （先关光标 / 关弹窗，最后才退书）。同一动作两条通道两种行为。
/// 2. 两条腿阶梯不等，等于同一个绑定在「指针归宿主」与「指针归 WebView」的平台上
///    行为不同（见 [hostOwnsWebViewPointerInput]）。合成一条后，两条腿只剩「谁拿到
///    事件」的区别，覆盖面逐字相同。
///
/// 页面解析到但执行体没接（返回 ignored）时**不认领**，app 根照常兜底——这正是
/// 键盘「返回 ignored 就冒泡」的等价物。
const List<ShortcutScope> kReaderMouseLadder = <ShortcutScope>[
  ShortcutScope.reader,
  ShortcutScope.audiobook,
  ShortcutScope.universal,
  ShortcutScope.global,
];

extension _ReaderCaret on _ReaderFushiPageState {
  /// 当前按下的修饰键集合（Ctrl/Shift/Alt/Meta）。键盘快捷解析与底栏焦点的
  /// Space 覆写共用，避免两处各自重建一份。
  /// 实现已抽到 [activeModifierKeys]（漫画页也要同一份，各自重建必漂）；
  /// 这里保留同名转发，避免改动本 part 里十余处调用点。
  Set<ModifierKey> _activeModifiers() => activeModifierKeys();

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    // BUG-2508（对齐视频页 BUG-880）：Shift 按下瞬间在最后指针位置直接查词，根治
    // 「光标停在词上不动、按 Shift 却不出词」——两条悬停腿都只在指针移动时派发。
    // 不消费按键：Shift 组合快捷键等行为不变。平台门（只在宿主腿平台）与光标模式门
    // （Shift+方向是键盘扩选，不能被查词抹掉）都在 [_triggerShiftLookupAtLastPointer]
    // 里，这里只认「是 Shift 的按下沿」。macOS 上 WKWebView 持有 first responder 时
    // Flutter 收不到 flagsChanged，下一次鼠标事件由嵌入层同步修饰键、合成同款
    // KeyDownEvent 送到这里，仍能触发。文本框聚焦时放行
    // （focusedEditableText != null）：在弹窗搜索框里打大写字母按的 Shift 不是查词。
    if (event is KeyDownEvent &&
        (event.logicalKey == LogicalKeyboardKey.shiftLeft ||
            event.logicalKey == LogicalKeyboardKey.shiftRight) &&
        focusedEditableText() == null) {
    }
    // The popup header toolbar (sibling of the popup content). Down returns to
    // the content caret; B/Escape dismiss the popup (ascend out of it). Left/
    // Right/Enter fall through to the framework so the buttons traverse and
    // activate natively (the global FushiFocusRing rings the focused one).
    if (_popupHeaderScope.hasFocus) {
      if (event is! KeyDownEvent) return KeyEventResult.ignored;
      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        return KeyEventResult.handled;
      }
      // The header is the TOP of the popup — nothing is above it. Consume Up so
      // focus stays on the header instead of the directional fallback wrapping
      // to another button (or, in any scope edge case, escaping and stranding
      // the hidden caret). Mirrors the bottom bar handling its Up explicitly.
      if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.gameButtonB ||
          event.logicalKey == LogicalKeyboardKey.escape) {
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    // TODO-700 T8: the bottom chrome bar is excluded from focus traversal
    // (ExcludeFocus in [_buildAudiobookBar]/[_buildSettingsBar]), so
    // `_chromeFocusScope.hasFocus` is permanently false and the old
    // chrome-focus key branch is unreachable. Focus stays on the reading
    // content, so Up/B/Escape and the BUG-204 bare-Space audiobook override are
    // all handled below by the normal content path (see [resolveReaderSpaceOverride]).

    final KeyEventResult? gamepadAResult = _focusNavEnabled
        ? _handleGamepadAKeyEvent(event)
        : null;
    if (gamepadAResult != null) return gamepadAResult;


    // TODO-1370：长按方向键连续切句。按住一个绑定到「可重复」阅读器/有声书动作
    // （翻页 或 有声书上一句/下一句）的键时，OS 自动重复的 [KeyRepeatEvent] 继续
    // 触发同一动作，使长按连续前进/切句，而不是一次按下只走一步——与视频播放器
    // （`SingleActivator(includeRepeats: true)`）、上面的字符光标重复、手柄 D-pad
    // 长按（[GamepadFrameProcessor] 自动重复）对齐。只放行移动类动作
    // （[isRepeatableReaderKeyboardShortcut]）；离散动作（查词/书签/关词典/播放暂停）
    // 仍一次一按。仅键盘：原生手柄键（含 Android D-pad 的 KeyRepeat）保持按下沿路由
    // （KeyDown 走 [_handleGamepadButton]）；字符光标激活时它自己的重复已在上面处理。
    // 必须落在 KeyDown-only 闸门之前，否则闸门会先把 KeyRepeat 拦掉。
    if (event is KeyRepeatEvent) {
      if (GamepadButton.fromKeyEvent(event) != null) {
        return KeyEventResult.ignored;
      }
      final Set<ModifierKey> repeatModifiers = _activeModifiers();
      final PhysicalKeyboardKey? repeatImePhysicalKey =
          focusedEditableText() == null ? event.physicalKey : null;
      final ShortcutAction? repeatDirectReaderAction = appModel.shortcutRegistry
          .resolveKeyboard(
            event.logicalKey,
            modifiers: repeatModifiers,
            scope: ShortcutScope.reader,
            physicalKey: repeatImePhysicalKey,
          );
      final ShortcutAction? repeatAction = _resolveReaderKeyboardShortcut(
        event,
        modifiers: repeatModifiers,
        directReaderAction: repeatDirectReaderAction,
        imeFallbackPhysicalKey: repeatImePhysicalKey,
      );
      if (repeatAction != null &&
          isRepeatableReaderKeyboardShortcut(repeatAction)) {
        return _executeShortcutAction(
          repeatAction,
          keyboardTriggerKey: event.logicalKey,
        );
      }
      return KeyEventResult.ignored;
    }

    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final Set<ModifierKey> modifiers = _activeModifiers();

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
    final PhysicalKeyboardKey? imeFallbackPhysicalKey =
        focusedEditableText() == null ? event.physicalKey : null;
    final ShortcutAction? directReaderAction = appModel.shortcutRegistry
        .resolveKeyboard(
          event.logicalKey,
          modifiers: modifiers,
          scope: ShortcutScope.reader,
          physicalKey: imeFallbackPhysicalKey,
        );

    // Char-level reading cursor (book has focus; chrome already returned above).
    // While active, the cursor owns Tab / arrows / A(Enter) / B(Esc) before the
    // registry is consulted. While inactive, A / Enter ENTER the cursor.
    if (_isReaderDirectCaretShortcut(directReaderAction)) {
      return _executeShortcutAction(
        directReaderAction!,
        keyboardTriggerKey: event.logicalKey,
      );
    }

    // TODO-700 T8: the bottom bar is excluded from focus traversal, so arrow
    // Down no longer routes focus into the chrome (the old BUG-020 keyboard
    // chrome route is gone). Down falls through to normal shortcut resolution
    // below; the bar is reached by touch/mouse, never by directional keys.

    final ShortcutAction? action = _resolveReaderKeyboardShortcut(
      event,
      modifiers: modifiers,
      directReaderAction: directReaderAction,
      imeFallbackPhysicalKey: imeFallbackPhysicalKey,
    );
    if (action == null) return KeyEventResult.ignored;
    return _executeShortcutAction(action, keyboardTriggerKey: event.logicalKey);
  }

  /// 把键盘 [event] 解析成它触发的阅读器/有声书 [ShortcutAction]，套用有声书裸
  /// Space 覆写、RTL/reverse 方向键翻页覆写，以及 reader→audiobook 作用域回退。由
  /// 按下沿（[KeyDownEvent]）与长按（[KeyRepeatEvent]，TODO-1370）两条路径共用，
  /// 保证长按解析出的动作与按下沿完全一致。键未绑定任何 reader/audiobook 动作时返回
  /// null。[directReaderAction] 由调用方预解析（reader scope）后传入，避免重复解析。
  ///
  /// 有声书激活时无修饰 Space 改作播放/暂停（媒体播放器惯例），先于 reader scope 的
  /// 「翻页」解析（否则 Space 被抢成翻页）；BUG-099/TODO-992 裸左右键按阅读方向翻页
  /// 且尊重用户改键。TODO-847：IME 把 logicalKey 改写成 process 时用 physicalKey 回退，
  /// 文本框 composing 时调用方传 null 关闭回退。
  ShortcutAction? _resolveReaderKeyboardShortcut(
    KeyEvent event, {
    required Set<ModifierKey> modifiers,
    required ShortcutAction? directReaderAction,
    required PhysicalKeyboardKey? imeFallbackPhysicalKey,
  }) {
    final ShortcutAction? spaceOverride = resolveReaderSpaceOverride(
      key: event.logicalKey,
      modifiers: modifiers,
      hasActiveAudiobook: false,
      physicalKey: imeFallbackPhysicalKey,
    );
    final ShortcutAction? bareArrowBinding =
        appModel.shortcutRegistry.resolveKeyboard(
          event.logicalKey,
          modifiers: modifiers,
          scope: ShortcutScope.reader,
          physicalKey: imeFallbackPhysicalKey,
        ) ??
        appModel.shortcutRegistry.resolveKeyboard(
          event.logicalKey,
          modifiers: modifiers,
          scope: ShortcutScope.audiobook,
          physicalKey: imeFallbackPhysicalKey,
        );
    final ShortcutAction? arrowOverride = resolveReaderArrowPageTurn(
      key: event.logicalKey,
      modifiers: modifiers,
      rtl: _isRtlReading,
      boundAction: bareArrowBinding,
      reverse: ReaderFushiSource.instance.reverseArrowPageTurn,
      physicalKey: imeFallbackPhysicalKey,
    );
    return spaceOverride ??
        arrowOverride ??
        directReaderAction ??
        appModel.shortcutRegistry.resolveKeyboard(
          event.logicalKey,
          modifiers: modifiers,
          scope: ShortcutScope.reader,
          physicalKey: imeFallbackPhysicalKey,
        ) ??
        appModel.shortcutRegistry.resolveKeyboard(
          event.logicalKey,
          modifiers: modifiers,
          scope: ShortcutScope.audiobook,
          physicalKey: imeFallbackPhysicalKey,
        ) ??
        // 最后兜底：universal 的「返回上一级」（默认 Esc / Alt+← / 手柄 B）。
        // 必须排在 reader+audiobook **之后**：页面专属键永远优先，故书内手柄 B
        // 仍是 audiobookPrevSentence（上一句），不被返回夺舍（TODO-700 约束2/4）。
        appModel.shortcutRegistry.resolveKeyboard(
          event.logicalKey,
          modifiers: modifiers,
          scope: ShortcutScope.universal,
          physicalKey: imeFallbackPhysicalKey,
        );
  }

  /// TODO-1078：WebView 内容层捕获的裸 Space（Windows WebView2 抢走 OS 键盘焦点后
  /// _focusNode.onKeyEvent 收不到键，见 [webview.part] 的 `onSpaceKey` 桥）解析成
  /// 阅读器动作。与 [_handleKeyEvent] 的 Space 解析同款语义：有声书激活 →
  /// [ShortcutAction.audiobookPlayPause]（[resolveReaderSpaceOverride]）；否则回落
  /// 到 reader scope 注册表里裸 Space 的真实绑定（默认 [ShortcutAction.readerPageForward]，
  /// 用户改键后跟随其绑定）。返回 null 表示裸 Space 当前无绑定，调用方不执行。
  ShortcutAction? _resolveWebViewSpaceAction() {
    return appModel.shortcutRegistry.resolveKeyboard(
      LogicalKeyboardKey.space,
      modifiers: const <ModifierKey>{},
      scope: ShortcutScope.reader,
    );
  }

  static bool _isReaderDirectCaretShortcut(ShortcutAction? action) {
    switch (action) {
      case ShortcutAction.readerLookupAtCursor:
      case ShortcutAction.readerShiftLookup:
      case ShortcutAction.readerCreateCardFromPopup:
        return true;
      default:
        return false;
    }
  }

  KeyEventResult? _handleGamepadAKeyEvent(KeyEvent event) {
    if (event.logicalKey != LogicalKeyboardKey.gameButtonA) return null;
    final ShortcutAction? resolvedAction = appModel.shortcutRegistry
        .resolveGamepad(GamepadButton.a, scope: ShortcutScope.reader);
    if (resolvedAction != ShortcutAction.readerLookupAtCursor) return null;
    if (event is KeyDownEvent) {
      if (_gamepadAHoldTimer != null) return KeyEventResult.handled;
      _gamepadALongFired = false;
      _gamepadAHoldTimer = Timer(const Duration(milliseconds: 500), () {
        _gamepadAHoldTimer = null;
        _gamepadALongFired = true;
        return;
      });
      return KeyEventResult.handled;
    }
    if (event is KeyRepeatEvent) return KeyEventResult.handled;
    if (event is KeyUpEvent) {
      final bool longFired = _gamepadALongFired;
      _clearGamepadAHold();
      if (longFired) return KeyEventResult.handled;
      return _executeShortcutAction(
        ShortcutAction.readerLookupAtCursor,
        gamepadTriggerButton: GamepadButton.a,
      );
    }
    return KeyEventResult.handled;
  }

  void _clearGamepadAHold() {
    _gamepadAHoldTimer?.cancel();
    _gamepadAHoldTimer = null;
    _gamepadALongFired = false;
  }

  /// Handles a gamepad button delivered via [GamepadButtonIntent] (desktop
  /// polled path). Mirrors the gamepad branch of [_handleKeyEvent] so polled
  /// input behaves identically to Android's native gameButton key events.
  /// Returns true when consumed; false lets the GamepadService apply its
  /// directional-focus / activate / global-back fallback.
  bool _handleGamepadButton(GamepadButton button) {
    // Popup header toolbar (sibling of the popup content). Down → content caret;
    // B → dismiss the popup. Left/Right/A fall through (return false) so the
    // GamepadService traverses the buttons and activates the focused one.
    if (_popupHeaderScope.hasFocus) {
      if (button == GamepadButton.dpadDown) {
        return true;
      }
      // Header is the top of the popup — consume Up so focus stays here (don't
      // let the directional fallback in gamepadMoveFocusInDirection wrap to
      // another button or escape the scope and strand the hidden caret).
      if (button == GamepadButton.dpadUp) {
        return true;
      }
      if (button == GamepadButton.b) {
        return true;
      }
      return false;
    }
    // TODO-700 T8: the bottom chrome bar is excluded from focus traversal, so
    // `_chromeFocusScope.hasFocus` is permanently false here too. The old
    // gamepad chrome-focus branch (dpad Up → content, B → exit) is unreachable
    // and removed; focus stays on the reading content.

    // Char-level reading cursor — same contextual routing as the keyboard path.
    if (ReaderCaretRouter.isEnterTriggerGamepad(
      button,
      focusNavEnabled: _focusNavEnabled,
      enterButtons: _readerEnterCaretButtons(),
    )) {
      return true;
    }
    // TODO-700 T8: the bottom bar is excluded from focus traversal, so D-pad
    // Down no longer routes focus into the chrome. It falls through to normal
    // gamepad shortcut resolution below; the bar is operated by touch/mouse.
    final ShortcutAction? action =
        appModel.shortcutRegistry.resolveGamepad(
          button,
          scope: ShortcutScope.reader,
        ) ??
        appModel.shortcutRegistry.resolveGamepad(
          button,
          scope: ShortcutScope.audiobook,
        ) ??
        // 兜底「返回上一级」（universal，默认手柄 B）。排在 reader+audiobook 之后
        // ⇒ 书内 B 仍先命中 audiobookPrevSentence（上一句），不退书；只有用户把
        // B 从上一句上解绑、或把返回改绑到别的键时，这条才会真的接管。
        appModel.shortcutRegistry.resolveGamepad(
          button,
          scope: ShortcutScope.universal,
        );
    if (action == null) return false;
    return _executeShortcutAction(action, gamepadTriggerButton: button) ==
        KeyEventResult.handled;
  }

  bool _isCaretEntryTrigger({
    LogicalKeyboardKey? keyboardTriggerKey,
    GamepadButton? gamepadTriggerButton,
  }) {
    if (keyboardTriggerKey != null) {
      return ReaderCaretRouter.isEnterTriggerKeyboard(
        keyboardTriggerKey,
        focusNavEnabled: _focusNavEnabled,
        enterKeys: _readerEnterCaretKeys(),
      );
    }
    if (gamepadTriggerButton != null) {
      return ReaderCaretRouter.isEnterTriggerGamepad(
        gamepadTriggerButton,
        focusNavEnabled: _focusNavEnabled,
        enterButtons: _readerEnterCaretButtons(),
      );
    }
    return _focusNavEnabled;
  }

  /// TODO-700 T7: the live keyboard keys bound to [ShortcutAction.readerEnterCaret]
  /// (default Enter, remappable in shortcut settings). The reader's "enter the
  /// char cursor" trigger reads these instead of the old hard-coded Enter/A, so
  /// "进入选字查词" is a configurable key while staying Enter by default.
  Set<LogicalKeyboardKey> _readerEnterCaretKeys() {
    return appModel.shortcutRegistry
        .bindingsFor(ShortcutAction.readerEnterCaret)
        .keyboardBindings
        .map((b) => b.key)
        .toSet();
  }

  /// TODO-700 T7: the live gamepad buttons bound to
  /// [ShortcutAction.readerEnterCaret] (default A, remappable).
  Set<GamepadButton> _readerEnterCaretButtons() {
    return appModel.shortcutRegistry
        .bindingsFor(ShortcutAction.readerEnterCaret)
        .gamepadBindings
        .map((b) => b.button)
        .toSet();
  }

  /// 阅读器 Flutter 侧的鼠标绑定入口（挂在 build 的页面根 [Listener] 上）。
  ///
  /// **位置型动作在这里被有意跳过**：「seek 到点击句」要知道点在哪一句上，只有页内
  /// JS 拿得到坐标，故它恒由 `onPointerSeek` 承担（判据 [isSeekToClickedSentenceButton]
  /// 两侧共用，不会各判各的）。
  void _handleReaderPointerDown(PointerDownEvent event) {
    // BUG-2031 审查②：两条腿的互斥必须是**构造性**的，不能只门控一侧。
    //
    // 原先只有 JS 那条腿带 [hostOwnsWebViewPointerInput] 门控，本 Flutter 腿是**无条件
    // 挂载**的，注释却写着「两条路按平台互斥」。那个判据是从查词弹窗那边提上来的——
    // 弹窗在 Android 上是独立 Activity，确实在 Flutter 命中树之外；但本页正文的 WebView
    // 是**树内 platform view**，祖先 [Listener] 照样收得到指针（同一条「opaque 只排除
    // 兄弟、不排除祖先」的事实）。于是非 Windows 上同一次按下可能被 Flutter 腿与 JS 腿
    // 各执行一次，而 JS 腿没有 pointer id、无法参与认领协议。
    //
    // 补上这道门后，任一平台恒只有一条腿活着。代价是非 Windows 上**页面外壳**（正文
    // WebView 之外）的鼠标绑定不生效——那恰是本轮之前的行为（本页当时根本没有 Flutter
    // 侧鼠标腿），故不是回归；正文区照常由 JS 腿覆盖完整阶梯。
    return;
  }

  KeyEventResult _executeShortcutAction(
    ShortcutAction action, {
    LogicalKeyboardKey? keyboardTriggerKey,
    GamepadButton? gamepadTriggerButton,
  }) {
    switch (action) {
      case ShortcutAction.readerPageForward:
        _paginate(ReaderNavigationDirection.forward);
        return KeyEventResult.handled;
      case ShortcutAction.readerPageBackward:
        _paginate(ReaderNavigationDirection.backward);
        return KeyEventResult.handled;
      case ShortcutAction.readerDismissDict:
        return KeyEventResult.ignored;
      case ShortcutAction.globalBack:
        // ③ 窗口全屏中 → 先退全屏、留在书里；不在全屏才真的退书。用户裁定「Esc 也可以
        //    退出全屏」，次序见 [_exitWindowFullscreenOrPopReader]。非全屏时它只多读一次
        //    窗口状态就落回原来的 maybePop，退书路径本身没变。
        unawaited(_exitWindowFullscreenOrPopReader());
        return KeyEventResult.handled;
      case ShortcutAction.readerToggleChrome:
        // TODO-700 T8: showing the bar no longer moves focus into it — the bar
        // is excluded from focus traversal; focus stays on the reading content.
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
      case ShortcutAction.readerOpenAudiobook:
        // 一键打开有声书面板（默认 B）；没挂有声书时直接进导入。
        // 「听书」模块关掉时本键**不消费**（ignored 而非 handled）：吃掉按键会让
        // 同一个键上可能存在的通用动作也跟着失效，而模块关掉只该关自己的入口。
        return KeyEventResult.ignored;
      case ShortcutAction.readerToggleStudyClock:
        // 一键停 / 续阅读统计计时（默认 P），与状态行 / 播放条内联读数里那颗
        // [ReaderStudyClockButton] 同一入口。纯状态切换、不动任何界面，故不像开面板
        // 的动作那样先关词典弹窗——查着词也能停表。
        _toggleStudyClockManualPause();
        return KeyEventResult.handled;
      case ShortcutAction.readerToggleFurigana:
        // 振假名 toggle 态的整页揭示 / 收回（CSS `body.show-all-rt`）：键盘 / 手柄
        // (R3) 没有「点一个揭示一个」的指针，这颗键一次揭示全页；dimmed 态同一颗键
        // 是「临时恢复全亮」（opacity 拉回 1）；off / hidden 态没有对应 CSS，按下是
        // no-op。
        _controller?.evaluateJavascript(
          source: "document.body.classList.toggle('show-all-rt');",
        );
        return KeyEventResult.handled;
      case ShortcutAction.readerLookupAtCursor:
        if (_isCaretEntryTrigger(
          keyboardTriggerKey: keyboardTriggerKey,
          gamepadTriggerButton: gamepadTriggerButton,
        )) {
        }
        return KeyEventResult.handled;
      case ShortcutAction.readerShiftLookup:
        if (_focusNavEnabled) {
        }
        return KeyEventResult.handled;
      case ShortcutAction.readerCreateCardFromPopup:
        // 「制卡」模块关掉时不消费（同 readerOpenAudiobook 的 ignored 理由）。
        return KeyEventResult.ignored;
      // 三个有声书传输键同属 [ShortcutScope.audiobook]，「听书」模块关掉时统一
      // 不消费（ignored），让键继续冒泡给可能绑同一键的通用动作。
      case ShortcutAction.audiobookPlayPause:
        return KeyEventResult.ignored;
      case ShortcutAction.audiobookNextSentence:
        return KeyEventResult.ignored;
      case ShortcutAction.audiobookPrevSentence:
        return KeyEventResult.ignored;
      default:
        return KeyEventResult.ignored;
    }
  }

  /// rgba() for the cursor focus ring — the theme primary for the reader's
  /// current brightness (dark paper used to hard-code the highlight yellow, so
  /// the ring ignored the user's accent; now both follow the theme).
  String _caretRingColorCss() {
    final Color accent = appModel
        .buildColorScheme(
          _isReaderThemeDark ? Brightness.dark : Brightness.light,
        )
        .primary;
    return readerColorToCssRgba(accent, alphaOverride: 0.98);
  }

  /// Place the reader cursor at the entering edge of the freshly paginated page.
  /// Reader-only — the popup never paginates.
  Future<void> _caretReanchor(ReaderNavigationDirection direction) async {
    return;
  }

  /// Re-measure the reader ring after a relayout (chrome toggle, font/size). If
  /// the cursor's node detached, JS re-anchors to the first visible character.
  /// Reader-only.
  Future<void> _caretRefresh() async {
    return;
  }
}
