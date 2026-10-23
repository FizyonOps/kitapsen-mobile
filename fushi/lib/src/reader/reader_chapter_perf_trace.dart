

/// 跨章分段计时探针（默认关，零开销）。
///
/// 跨章一次要串 5 段异步：`loadUrl` → WebView 文档装载（`onLoadStop`）→ setup 脚本
/// 注入（含 sasayaki cue 准备）→ 桥接/高亮注入 → JS 侧 `initialize` 里的图片 decode +
/// buildNodeOffsets + 恢复滚动（`onRestoreComplete`）。任一段慢下来体感都是「翻章卡」，
/// 但从外部只能看到总时长，无法判断该优化哪一段。本探针在每段边界打点，日志前缀
/// `[chapter-perf]`，一次跨章输出一行分段 breakdown。
///
/// 用法：真机/集成测试前置 [enabled] = true（见
/// `integration_test/reader_cross_chapter_perf_itest.dart`）。默认 false 时
/// [begin]/[mark]/[end] 全部立即返回，生产路径零成本。
abstract class ReaderChapterPerfTrace {

  /// 总开关。默认 false（生产/普通测试零开销）。
  static bool enabled = false;

  /// 一次跨章开始。[label] 通常是 `目标章号`。重入（上一次未 end 就来新导航）
  /// 直接丢弃旧计时——被顶掉的导航本就不该计入。
  static void begin(String label) {
    if (!enabled) return;
  }

  /// 记一个阶段边界。[stage] 是刚刚**完成**的阶段名。
  static void mark(String stage) {
    if (!enabled) return;
  }

  /// 记一个与时间无关的量（如注入脚本字符数），随本次跨章一起打印。
  static void noteSize(String name, int value) {
    if (!enabled) return;
  }

  /// 收下 JS 侧随 `onRestoreComplete` 回传的计时快照（`fushiReader.perfSnapshot()`）。
  /// 把 WebView 内部那一大段拆成 `js.initSync`（initialize 同步部分：CSS 变量 + 图片
  /// 挂载 + 强制 layout）/ `js.images`（图片 decode 等待）/ `js.offsets`
  /// （buildNodeOffsets）/ `js.restore`（恢复滚动），外加浏览器 navigation timing
  /// （responseEnd→DOMContentLoaded→load）——定位跨章耗时到底卡在哪一环。
  static void noteJs(Object? raw) {
    if (!enabled) return;
  }

  /// 一次跨章结束，打印分段 breakdown。
  static void end() {
    if (!enabled) return;
  }

  /// 丢弃在飞计时（导航失败/被顶掉），不产出记录。
  static void abort() {
    if (!enabled) return;
  }

}
