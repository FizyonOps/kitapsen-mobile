// GENERATED-NOTE: extracted from reader_fushi_page.dart (TODO-589 batch1).
part of '../reader_fushi_page.dart';

/// lyrics + floating-lyric domain methods extracted via part-of (TODO-589
/// batch1); shared private scope. Behaviour-preserving: bodies are verbatim
/// except `setState(` forwarded through the main shell `_rebuild(` helper
/// (extensions cannot call the @protected State.setState directly).
extension _ReaderLyrics on _ReaderFushiPageState {
  // ── Lyrics Mode ──────────────────────────────────────────────────

  // ── Floating Lyric ─────────────────────────────────────────────────
  //
  // TODO-291 阶段2：悬浮窗 / 媒体通知的「拉起 + cue 同步 + 控制流订阅」已上移到进程级
  // [AudiobookSession]，让退出书籍后仍能后台听书 + 悬浮刷字。reader 这里只保留：
  // ① reader 主题样式 [_readerFloatingLyricStyle]（attach 期通过 session.installReaderSurfaces
  //    注入，使悬浮窗用 reader 当前书的深色/竖排主题）；
  // ② 桌面悬浮窗点词路由 [_lookupFromFloatingLyric]（attach 期注入，路由进 reader 弹窗）；
  // ③ 设置开关 [_toggleFloatingLyric] / [_toggleMediaNotification]（薄壳，委托 session）。

}
