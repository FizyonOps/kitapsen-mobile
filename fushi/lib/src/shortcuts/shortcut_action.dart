/// 快捷键作用域。没有任何地方按 index 持久化或解析 scope，调整顺序不影响行为。
enum ShortcutScope {
  global,

  // 「返回上一级」这一件事的唯一归属地（Esc / 手柄 B 一键从任何界面退一层）。
  //
  // 为什么是独立 scope 而不是塞进 global：阅读器只解析 reader 自己那一组，若把
  // 「返回」留在 global 就得让它连 home 组一起解析。universal 自成一组，由每个表面
  // 在**自己 scope 未命中之后**兜底解析，故页面专属键永远优先，页面没占用的键才
  // 落到「返回上一级」。
  universal,

  home,
  reader,
}

enum ShortcutAction {
  // 持久化 / 默认表都按字符串 key 对应，与声明序无关；resolveKeyboard /
  // resolveGamepad 按声明序取首个命中。

  // Reader
  readerPageForward(ShortcutScope.reader, 'reader_page_forward'),
  readerPageBackward(ShortcutScope.reader, 'reader_page_backward'),

  readerToggleChrome(ShortcutScope.reader, 'reader_toggle_chrome'),
  readerOpenMenu(ShortcutScope.reader, 'reader_open_menu'),
  readerOpenNavigation(ShortcutScope.reader, 'reader_open_navigation'),
  readerOpenGallery(ShortcutScope.reader, 'reader_open_gallery'),
  readerOpenStatistics(ShortcutScope.reader, 'reader_open_statistics'),
  // 一键停 / 续阅读统计计时（与状态行里的 ReaderStudyClockButton 同一入口）。
  readerToggleStudyClock(ShortcutScope.reader, 'reader_toggle_study_clock'),

  // Home
  homeTabBooks(ShortcutScope.home, 'home_tab_books'),
  homeTabSettings(ShortcutScope.home, 'home_tab_settings'),
  homeTabPrev(ShortcutScope.home, 'home_tab_prev'),
  homeTabNext(ShortcutScope.home, 'home_tab_next'),
  homeFocusSearch(ShortcutScope.home, 'home_focus_search'),

  // 「返回上一级」（universal）：关弹窗 / 退书 / 退页，见 [ShortcutScope.universal]。
  globalBack(ShortcutScope.universal, 'global_back'),

  // Global
  globalScrollPageDown(ShortcutScope.global, 'global_scroll_page_down'),
  globalScrollPageUp(ShortcutScope.global, 'global_scroll_page_up'),
  globalScrollLineDown(ShortcutScope.global, 'global_scroll_line_down'),
  globalScrollLineUp(ShortcutScope.global, 'global_scroll_line_up'),
  globalScrollToTop(ShortcutScope.global, 'global_scroll_to_top'),
  globalScrollToBottom(ShortcutScope.global, 'global_scroll_to_bottom'),
  globalToggleFullscreen(ShortcutScope.global, 'global_toggle_fullscreen'),

  // 鼠标侧键 / 右键打开当前焦点的上下文菜单（只有鼠标通道）。
  globalContextMenu(ShortcutScope.global, 'global_context_menu');

  const ShortcutAction(this.scope, this.key);

  final ShortcutScope scope;
  final String key;

  static List<ShortcutAction> actionsForScope(ShortcutScope scope) {
    return values.where((a) => a.scope == scope).toList(growable: false);
  }
}
