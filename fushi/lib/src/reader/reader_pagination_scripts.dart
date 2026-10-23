import 'dart:convert';

import 'package:fushi/src/reader/reader_content_styles.dart';
import 'package:fushi/src/reader/reader_study_unit_script.dart';

enum ReaderNavigationDirection {
  forward('forward'),
  backward('backward');

  const ReaderNavigationDirection(this.jsValue);
  final String jsValue;
}

/// 翻页意图队列：换章加载 / 恢复在飞期间到达的翻页输入的暂存处。
///
/// 旧实现在 `_paginationInFlight` 为真时**直接丢弃**这些输入，于是用户在跨章的那几百
/// 毫秒里拨的滚轮全部石沉大海——体感就是「按了没反应，要再按一次」。丢弃的原始理由是
/// 真实的：在飞时 `fushiReader` 尚未就绪，`evaluateJavascript` 返 null 会被 `_didScroll`
/// 读成「已到页边界」→ 一次输入触发第二次跨章（用户复诉三次的「跳两章」）。但那是
/// **判定时机**错了，不是输入本身该被扔掉：把意图存下来、等 JS 就绪后再判定，两个问题
/// 一起消失。
///
/// 存的是「翻页意图」而不是「跨章意图」——重放走完整的 `_paginate`（章内还有页就翻页，
/// 真到边界才跨章）。所以刚落地新章的章首插图页/单页章会被正常翻过去，而不是被越过；
/// 「章首整页被跳过」正是同一个原始症状的另一半。
///
/// 反向意图相互抵消：用户翻过头往回拨时，不该先把积压的正向意图翻完再倒回来。
class ReaderPageTurnQueue {
  /// 积压上限。一次惯性流可能在单次换章加载里堆出几十个 tick；超出即饱和，
  /// 避免一次误触换来失控连翻。带符号计数，故上下界对称。
  static const int kMaxPending = 8;

  /// 带符号积压：> 0 为前进 N 次，< 0 为后退 N 次，0 为空。
  int _pending = 0;

  /// 记一次翻页意图。反向抵消后 clamp 到 [kMaxPending]。
  void push(ReaderNavigationDirection direction) {
    final int delta = direction == ReaderNavigationDirection.forward ? 1 : -1;
    _pending = (_pending + delta).clamp(-kMaxPending, kMaxPending);
  }

  /// 取出一次待重放的意图；队列为空时返回 null。
  ReaderNavigationDirection? consume() {
    if (_pending == 0) return null;
    final bool forward = _pending > 0;
    _pending += forward ? -1 : 1;
    return forward
        ? ReaderNavigationDirection.forward
        : ReaderNavigationDirection.backward;
  }

  /// 丢弃全部积压。用于「用户显式改变了意图」的场合（目录跳转 / 书签跳转 /
  /// 退出阅读器）——那些导航之后再重放旧滚轮意图只会把用户从刚跳到的位置带走。
  void clear() {
    _pending = 0;
  }
}

/// Groups the many horizontal wheel ticks emitted by one macOS trackpad swipe
/// into one page-turn intent.
///
/// The gate belongs to the reader State rather than the WebView document, so a
/// chapter navigation in the middle of momentum cannot reset it and admit a
/// second page turn. A tick that belongs to an already-claimed gesture moves the
/// trailing edge; only a full quiet interval starts the next gesture.
class ReaderWheelGestureGate {
  /// 最后一个**属于某个已认领手势**的 tick 时刻。被丢弃、翻不动页的 tick 不属于
  /// 任何手势，不写这里（见 [shouldStartNewGesture] 的 [canTurnPage]）。
  DateTime? _lastTickAt;

  /// BUG-1380：手势 token 的消费必须晚于「这一 tick 确实能翻页」的确认。
  ///
  /// [canTurnPage] 由调用方给出（阅读器侧是 `!_paginationInFlight`）：为 false 时
  /// 这一 tick 已知落不了地（换章加载 / restore 在飞），于是**不认领新手势**——
  /// 否则整段惯性的首个 tick 白白吃掉 token，加载落定后的后续 tick 全部在闸门早退，
  /// 用户这一次滑动零反馈。返回值仍是纯查询「本 tick 不属于已认领的手势」，让调用方
  /// 把 tick 继续送进下游（跨章冷却窗要靠这些 tick 续窗）。
  ///
  /// 已在手势内的 tick（返回 false）无条件滑动 trailing edge：它属于已认领的手势，
  /// 延长静默窗正是闸门的本意。
  bool shouldStartNewGesture({
    required DateTime now,
    required Duration settleInterval,
    required bool canTurnPage,
  }) {
    final DateTime? lastTickAt = _lastTickAt;
    final bool startsNewGesture =
        lastTickAt == null || now.difference(lastTickAt) >= settleInterval;
    if (!startsNewGesture || canTurnPage) {
      _lastTickAt = now;
    }
    return startsNewGesture;
  }
}

abstract class ReaderPaginationScripts {

  static String paginateInvocation(ReaderNavigationDirection direction) =>
      "window.fushiReader && window.fushiReader.paginate('${direction.jsValue}')";

  static String stableProgressInvocation() =>
      'window.fushiReader && !window.fushiReader._reanchorPending '
      '&& window.fushiProgressDetails ? window.fushiProgressDetails() : null';

  static String updatePageSizeInvocation(double width, double height) =>
      'window.fushiReader && window.fushiReader.updatePageSize($width, $height)';

  /// BUG-1743：存在性守卫是第二层防线。裸调 `window.fushiReader.scrollToSearchMatch`
  /// 在未实现该方法的 shell 上抛 TypeError，而 evaluateJavascript 的 JS 异常在
  /// 移动端通道上一般不回传成 Dart 异常——调用点的 try/catch 抓不到，症状只是
  /// 「点了没反应」，且同一次 evaluate 里后续语句会被一并中断。
  /// 同文件 [pageInfoInvocation] 与收藏跳转路径用的都是同款守卫写法。
  static String scrollToSearchMatchInvocation(String query, int hintOffset) =>
      '(window.fushiReader && '
      'typeof window.fushiReader.scrollToSearchMatch === "function") '
      '? window.fushiReader.scrollToSearchMatch('
      '${_jsStringLiteral(query)}, $hintOffset) : null';

  static String setChromeInsetsInvocation(double topPx, double bottomPx) =>
      'window.fushiReader && window.fushiReader.setChromeInsets($topPx, $bottomPx)';

  /// TODO-693: 连续模式 appUiScale 缩放重锚的第一阶段——在缩放重建那一帧同步采样首个
  /// 可见字符偏移并置 `_reanchorPending`（挡住 reflow 归零 scroll 污染落库）。返回采到
  /// 的字符偏移；-1 = 无可用锚 / 已有重锚在飞 → 调用方跳过提交阶段。
  /// `beginUiScaleReanchor` 只存在于连续模式的 `window.fushiReader`，分页模式缺席，
  /// `typeof` 守卫使分页模式整体 no-op（分页有 snap/lock 保护，无需此重锚）。
  static String beginUiScaleReanchorInvocation() =>
      '(window.fushiReader && '
      "typeof window.fushiReader.beginUiScaleReanchor === 'function') "
      '? window.fushiReader.beginUiScaleReanchor() : -1';

  /// TODO-693: 第二阶段——过渡帧 settle 后把暂存锚滚回视口首边并清 `_reanchorPending`。
  /// 仅当第一阶段成功暂存了有效锚时才生效，否则 no-op（绝不误清别处的重锚旗）。
  /// BUG-2652：恢复完成重锚的第一阶段——锚取恢复自己的精确字符锚（无精确锚时退回
  /// [beginUiScaleReanchorInvocation] 的现场采样），commit 仍是
  /// [commitUiScaleReanchorInvocation]。
  static String beginRestoreReanchorInvocation() =>
      '(window.fushiReader && '
      "typeof window.fushiReader.beginRestoreReanchor === 'function') "
      '? window.fushiReader.beginRestoreReanchor() : -1';

  static String commitUiScaleReanchorInvocation() =>
      '(window.fushiReader && '
      "typeof window.fushiReader.commitUiScaleReanchor === 'function') "
      '? window.fushiReader.commitUiScaleReanchor() : false';

  /// TODO-736 B-1（必补点2）：样式变更专用两阶段重锚的第一阶段调用——在换样式那一刻
  /// 同步采锚 + 换 CSS（[jsonCss] 须是已 jsonEncode 的 JS 字符串字面量）+ 失效 metrics +
  /// 重置 image-max + 置 `_reanchorPending` + 暂存锚。返回采到的字符偏移；-1 = 无锚 / 已有
  /// 重锚在飞 / pagination 未就绪（无 fushiReader 或非 reader 页）→ 调用方跳过提交阶段并
  /// 自行裸套 CSS 兜底。`beginStyleReanchor` 分页/连续两 shell **各自定义**（不在 _sharedJs，
  /// 因 scrollToCharOffset 签名两 shell 不同）；曾只加进连续 shell、分页缺席致改字号/边距/主题
  /// 等纯 CSS 设置在分页模式不实时生效（守卫见 reader_style_reanchor_both_shells_guard_test）。
  /// 分页/连续各自的 getFirstVisibleCharOffset/scrollToCharOffset 经 `this` 解析（连续含 A-2 兜底）。
  ///
  /// BUG-2261：`:-1` 兜底分支**自己换 CSS**。Dart 侧 `_applyStylesLive` 只在「重锚不会跑」
  /// （gate 关 / 无 fushiReader）时裸换 CSS，gate 开时把换 CSS 全托付给本调用；若某个 shell
  /// 有 `window.fushiReader` 却没实现 `beginStyleReanchor`（VN 第三 shell 曾如此），旧兜底
  /// 裸返 -1 = 两边都没换 → 字号/边距/主题等纯 CSS 设置静默丢弃、退出重进才生效——
  /// 这是 BUG-849（分页缺席）同一契约漏洞的第三次复发。把「CSS 永不丢」收进调用点，
  /// 不再靠每个 shell 都记得实现方法。
  static String beginStyleReanchorInvocation(String jsonCss) =>
      '(function(){'
      'var css = $jsonCss;'
      "var el = document.getElementById('fushi-reader-style');"
      'if (window.fushiReader && '
      "typeof window.fushiReader.beginStyleReanchor === 'function') {"
      'return window.fushiReader.beginStyleReanchor(el, css);'
      '}'
      'if (el) el.textContent = css;'
      'if (window.fushiReader && '
      'window.fushiReader.paginationMetrics !== undefined) {'
      'window.fushiReader.paginationMetrics = null;'
      '}'
      'return -1;'
      '})()';

  /// TODO-736 B-1：第二阶段——过渡帧 settle 后把暂存锚滚回视口首边并清 `_reanchorPending`。
  /// 仅当第一阶段成功暂存了有效锚时才生效，否则 no-op（绝不误清别处的重锚旗）。
  static String commitStyleReanchorInvocation() =>
      '(window.fushiReader && '
      "typeof window.fushiReader.commitStyleReanchor === 'function') "
      '? window.fushiReader.commitStyleReanchor() : false';

  static int? intResult(dynamic result) {
    if (result == null) return null;
    if (result is int) return result;
    if (result is num) return result.toInt();
    if (result is String) {
      return int.tryParse(result.trim().replaceAll('"', ''));
    }
    return null;
  }

  /// 三种 view-mode 的 shell 源码，按模式选一份（零 per-nav 插值）。
  ///
  /// 改动前是 `shellScript({initialProgress, chromeTopInset, sasayakiCuesJson, …})`
  /// —— 每次导航把当次参数插进源码，产出一份全新字符串，Dart 侧每章都要重新拼装 +
  /// 压缩近万行。现在每种 shell 被包成一个只读取运行时 config 的安装函数，源码在一个
  /// 进程里逐字不变，于是可以 memoize（见 `readerEngineSource`）。
  ///
  /// 每个 shell 函数体与改动前对应 shell 的 IIFE 内容逐字对应（`$x` → `C.x`），
  /// 词法作用域自洽：shell 顶层只声明 `_fushiBootInitialize`，其余全部写 `window.*`
  /// 全局，与外层手势层之间没有任何跨作用域引用（守卫
  /// `test/reader/reader_engine_static_source_guard_test.dart`）。
  static String engineShell({
    required bool vnMode,
    required bool continuousMode,
  }) {
    // Kitapsen: no visual-novel mode (readerViewMode never reports 'vn').
    final String shell = (continuousMode ? continuousShellSource() : paginatedShellSource());
    return '''<script>
$kStudyUnitJs
${''}
window.__fushiShells = {};
${_stripShellScriptTags(shell)}
window.__fushiInstallShell = function(C) {
  if (C.vnMode) return window.__fushiShells.vn(C);
  if (C.continuousMode) return window.__fushiShells.continuous(C);
  return window.__fushiShells.paginated(C);
};
</script>''';
  }

  /// 三个 shell 各自仍以 `<script>…</script>` 形式返回（它们的单测按这个形状钉着），
  /// 拼进引擎时剥掉外层标签。
  static String _stripShellScriptTags(String js) =>
      js.replaceAll('<script>', '').replaceAll('</script>', '').trim();

  // ── Shared JS (properties + methods used by both modes) ────────────

  static const String _sharedJs = _sharedJsHead +
      ('') +
      _sharedJsTail;

  static const String _sharedJsHead = r'''
  cueWrappers: new Map(),
  cueRangesMap: new Map(),
  cueRubyElements: new Map(),
  activeCueId: null,
  readerRegexNegated: /[^0-9A-Za-z○◯々-〇〻ぁ-ゖゝ-ゟァ-ヺー-ヿ０-９Ａ-Ｚａ-ｚｦ-ﾝ\u{2E80}-\u{2EFF}\u{2F00}-\u{2FDF}\u{3400}-\u{4DBF}\u{4E00}-\u{9FFF}\u{F900}-\u{FAFF}\u{20000}-\u{2A6DF}\u{2A700}-\u{2EBE0}\u{2F800}-\u{2FA1F}\u{30000}-\u{323AF}]+/gimu,
  readerRegex: /[0-9A-Za-z○◯々-〇〻ぁ-ゖゝ-ゟァ-ヺー-ヿ０-９Ａ-Ｚａ-ｚｦ-ﾝ\u{2E80}-\u{2EFF}\u{2F00}-\u{2FDF}\u{3400}-\u{4DBF}\u{4E00}-\u{9FFF}\u{F900}-\u{FAFF}\u{20000}-\u{2A6DF}\u{2A700}-\u{2EBE0}\u{2F800}-\u{2FA1F}\u{30000}-\u{323AF}]/iu,
  nodeStartOffsets: new WeakMap(),
  // 跨章分段计时（JS 侧）。Dart 的 [ReaderChapterPerfTrace] 只能测到「setup 脚本注入完成
  // → onRestoreComplete 回来」这一整段（真机 ~30ms），无法区分那段里图片等待 / 字符偏移
  // 建表 / 恢复滚动 / IPC 回传各占多少。perfMark 在这几处打点，perfSnapshot 连同浏览器
  // navigation timing（responseEnd / DOMContentLoaded / load）一起随 onRestoreComplete
  // 回传给 Dart。
  //
  // 开关：`_perfOn` 由各 shell 在注入期由 Dart 侧 [ReaderChapterPerfTrace.enabled]
  // 插值写死（见两个 shell 的对象字面量）。生产路径上它恒为 false，perfMark /
  // perfSnapshot 立即 early-return：不读 performance.now()、不走
  // getEntriesByType('navigation')、不做 JSON.stringify。与 Dart 侧同一个开关，
  // 不存在「采集端常开、只 gate 消费端」的无条件热路径开销。
  _perf: {},
  perfMark: function(name) {
    if (this._perfOn !== true) return;
    try { this._perf[name] = performance.now(); } catch (e) {}
  },
  perfSnapshot: function() {
    if (this._perfOn !== true) return '';
    try {
      var out = { marks: this._perf };
      var entries = performance.getEntriesByType ? performance.getEntriesByType('navigation') : null;
      var nav = entries && entries.length ? entries[0] : null;
      if (nav) {
        out.nav = {
          resp: Math.round(nav.responseEnd),
          dcl: Math.round(nav.domContentLoadedEventEnd),
          load: Math.round(nav.loadEventEnd)
        };
      }
      return JSON.stringify(out);
    } catch (e) { return ''; }
  },
  isVertical: function() {
    return window.getComputedStyle(document.body).writingMode === "vertical-rl";
  },
  // BUG-493 根因修复：_reanchorPending 的唯一写入口（清旗单点化，_sharedJs 两 shell 共用）。
  // true→false 转换 = 重锚 settle，那一刻（bridge 可用时）callHandler('onReanchorSettled')
  // 通知 Dart 补刷一次进度（webview.part.dart 注册），事件驱动替代旧的 Dart 侧 120ms×8
  // 轮询重试——setChromeInsets/updatePageSize/begin·commit 系列任何一处清旗（含 commit
  // 成功之外的逃逸路径）都会通知，进度不再锁死等 10s 轮询。
  _setReanchorPending: function(value) {
    var settled = this._reanchorPending === true && value !== true;
    this._reanchorPending = value === true;
    // BUG-2806：重锚落定 = 排版已按新几何落定，有声书补缝阴影按新排版重量。
    if (settled && this.paintSentenceAudioRubyGaps) this.paintSentenceAudioRubyGaps();
    if (settled && window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
      try { window.flutter_inappwebview.callHandler('onReanchorSettled'); } catch (e) {}
    }
  },
  // BUG-2465：重锚的落定一律排在下一帧（rAF），但页面隐藏时（macOS 窗口不可见 /
  // 隐藏、Chromium 最小化）浏览器冻结 requestAnimationFrame，`_reanchorPending` 就一直
  // 挂着——stableProgress 恒 null、位置永不落库、账本永不 arrive，直到窗口回到前台。
  // 隐藏时改用 setTimeout(0)：没有可见帧可等，布局在隐藏文档里照常可读，立刻落定。
  _reanchorFrame: function(fn) {
    if (document.hidden === true) { setTimeout(fn, 0); return; }
    requestAnimationFrame(fn);
  },
  // wave1 去重：content-box 尺寸探针（body clientWidth/Height 扣 padding）。曾在分页/连续
  // 两 shell 尾部各挂一份逐字相同的 window.fushiReader._contentSize = function(){...}；上移进
  // _sharedJs 作对象字面量属性，两 shell 经 $_sharedJs 各得一份、字节等价（_imageMaxBox 经
  // this._contentSize() 调用，属性先于 initialize 求值，定义先于使用）。
  _contentSize: function() {
    var cs = getComputedStyle(document.body);
    var pl = parseFloat(cs.paddingLeft) || 0;
    var pr = parseFloat(cs.paddingRight) || 0;
    var pt = parseFloat(cs.paddingTop) || 0;
    var pb = parseFloat(cs.paddingBottom) || 0;
    return { w: (document.body.clientWidth || window.innerWidth) - pl - pr, h: (document.body.clientHeight || window.innerHeight) - pt - pb };
  },
  // TODO-1285（图片挤压根因修复）：每页多列(pageColumns>=2)时 multicol 把「turn 轴」
  // （横排=宽 / 竖排=高）切成 N 个子列，但图片 max 约束过去恒用整 content-box（cs.w/cs.h）
  // → 整页插图按整页 turn 轴撑开，远超单个子列 → 溢出本列、盖住相邻列正文（用户报「图片
  // 被挤压」的真相：宽插图横跨两列压字）。修复：turn 轴的图片 max 改用**浏览器 used 子列宽**
  // getComputedStyle(body).columnWidth（与 getScrollContext 读的同一权威真值：横排=子列宽、
  // 竖排=子列高），图片正好落进本列不越界；block 轴（横排=高 / 竖排=宽）仍用整 content-box
  // （每列在 block 轴填满整页），不变。仅当 used 子列明显窄于整轴（真 pageColumns>=2）才夹到
  // 子列；单列 / 连续 / VN（无 column-count → columnWidth=='auto'→NaN，或子列≈整轴）回退整轴、
  // 与旧 cs.w/cs.h 字节等价（零回归，不碰 TODO-729/753/792 分页几何）。ratio 恒作用在宽（与旧同）。
  // BUG-2652：setChromeInsets 的重锚只为补偿「inset 改变 → body padding 改变 → 重排」。
  // 下发的 inset 与已生效的变量逐值相同、图片盒也不变时根本没有重排，采样首字锚
  // 只会读到**尚未落定的视口**：iOS 上同一个 WKWebView 原地换章（切滚动/分页模式等
  // 结构性重载）后，恢复滚动刚写下去的头几帧里原生侧会让 scrollX/scrollY 瞬时读成 0，
  // 此刻采到的锚就是章首，rAF 里 scrollToCharOffset(0) 便把用户钉回章首并落库。
  // 这里判「无变化」，调用方直接返回——不采样、不置旗、不动 metrics。
  _chromeInsetsUnchanged: function(topPx, bottomPx) {
    var st = document.documentElement.style;
    if (st.getPropertyValue('--chrome-top-inset') !== topPx + 'px') return false;
    if (st.getPropertyValue('--chrome-bottom-inset') !== bottomPx + 'px') return false;
    var box = this._imageMaxBox();
    return st.getPropertyValue('--fushi-image-max-width') === box.w + 'px' &&
        st.getPropertyValue('--fushi-image-max-height') === box.h + 'px';
  },
  _imageMaxBox: function() {
    var cs = this._contentSize();
    var ratio = (typeof this._imageWidthRatio === 'number') ? this._imageWidthRatio : 1;
    var vertical = this.isVertical();
    var turnFull = vertical ? cs.h : cs.w;
    var usedColW = parseFloat(getComputedStyle(document.body).columnWidth);
    var multicol = usedColW > 0 && usedColW < turnFull - 1;
    if (vertical) {
      var h = multicol ? Math.round(usedColW) : cs.h;
      return { w: Math.max(1, Math.floor(cs.w * ratio)), h: Math.max(1, h) };
    }
    var w = multicol ? usedColW : cs.w;
    return { w: Math.max(1, Math.floor(w * ratio)), h: Math.max(1, cs.h) };
  },
  isFurigana: function(node) {
    var el = node.nodeType === Node.TEXT_NODE ? node.parentElement : node;
    return !!(el && el.closest('rt, rp'));
  },
  normalizeText: function(text) {
    return (text || '').replace(this.readerRegexNegated, '');
  },
  // 统计 / 进度口径：学习单位数（无空格文字按码点、空格分词文字按连续串）。与 Dart
  // countStudyChars 逐样本对拍（study_char_count_parity_test.dart）。**不要**改回
  // normalizeText——那套白名单是有声书 cue 匹配与纯图片章判定的坐标系，见
  // reader_study_unit_script.dart 的「与匹配 / 归一化的分界」。
  countChars: function(text) {
    return window.fushiStudyUnits.count(text);
  },
  isMatchableChar: function(char) {
    return this.readerRegex.test(char || '');
  },
  // TODO-630 / BUG-366：sasayaki 高亮运行期把 cue 原文 needle 在实时 DOM 归一化全文
  // full 里做 full.indexOf(needle) 重定位（BUG-060）。匹配坐标系（Dart
  // AudioTextNormalizer.normalize）除剥非白名单字符外还做**值折叠**（片假名→平假名 /
  // 大小写折叠 / 全角→ASCII / 半角片假名→全角片假名）；JS 这边过去只剥不折，于是
  // 折叠类书（SRT 片假名 vs EPUB 平假名、全角 vs 半角）needle 在 full 里 indexOf 落空
  // → 回落 hint → 高亮看似「不显示/错位」。下面 foldCodePoint 与 AudioTextNormalizer
  // 的值转换严格同口径。所有折叠都是单 BMP 码元→单 BMP 码元（1:1 码元），因此
  // buildSasayakiNormIndex 的逐码元 map 粒度（代理对 push 两条）保持不变。
  hwKataToFwBase: 0xFF66,
  hwKataToFw: [0x30F2,0x30A1,0x30A3,0x30A5,0x30A7,0x30A9,0x30E3,0x30E5,0x30E7,0x30C3,0x30FC,0x30A2,0x30A4,0x30A6,0x30A8,0x30AA,0x30AB,0x30AD,0x30AF,0x30B1,0x30B3,0x30B5,0x30B7,0x30B9,0x30BB,0x30BD,0x30BF,0x30C1,0x30C4,0x30C6,0x30C8,0x30CA,0x30CB,0x30CC,0x30CD,0x30CE,0x30CF,0x30D2,0x30D5,0x30D8,0x30DB,0x30DE,0x30DF,0x30E0,0x30E1,0x30E2,0x30E4,0x30E6,0x30E8,0x30E9,0x30EA,0x30EB,0x30EC,0x30ED,0x30EF,0x30F3],
  foldCodePoint: function(cp) {
    var out = cp;
    if (cp >= 0x41 && cp <= 0x5A) out = cp + 0x20;            // ASCII A-Z -> a-z
    else if (cp >= 0xFF21 && cp <= 0xFF3A) out = cp - 0xFEC0; // fullwidth A-Z -> a-z
    else if (cp >= 0xFF41 && cp <= 0xFF5A) out = cp - 0xFEE0; // fullwidth a-z -> a-z
    else if (cp >= 0xFF10 && cp <= 0xFF19) out = cp - 0xFEE0; // fullwidth 0-9 -> 0-9
    else if (cp >= 0xFF66 && cp <= 0xFF9D) out = this.hwKataToFw[cp - this.hwKataToFwBase]; // halfwidth kana -> fullwidth kana
    if (out >= 0x30A1 && out <= 0x30F6) out -= 0x60;          // katakana -> hiragana
    return out;
  },
  foldNormalize: function(text) {
    var stripped = this.normalizeText(text);
    var folded = '';
    var i = 0;
    while (i < stripped.length) {
      var cp = stripped.codePointAt(i);
      var ch = String.fromCodePoint(cp);
      folded += String.fromCodePoint(this.foldCodePoint(cp));
      i += ch.length;
    }
    return folded;
  },
  scrollToProgressContinuous: function(progress) {
    var targetNode = this.findNodeAtProgress(progress);
    if (targetNode && targetNode.parentElement) {
      targetNode.parentElement.scrollIntoView({
        block: progress >= 0.999999 ? 'end' : 'start',
        inline: 'nearest',
        behavior: 'instant'
      });
    }
  },
  findNodeAtProgress: function(progress) {
    var walker = this.createWalker();
    var totalChars = 0;
    var node;
    while (node = walker.nextNode()) {
      totalChars += this.countChars(node.textContent);
    }
    if (totalChars <= 0) return null;
    var targetCharCount = Math.ceil(totalChars * progress);
    var runningSum = 0;
    var targetNode = null;
    walker = this.createWalker();
    while (node = walker.nextNode()) {
      runningSum += this.countChars(node.textContent);
      if (runningSum > targetCharCount) { targetNode = node; break; }
    }
    return targetNode;
  },
  scrollToProgressPaged: function(context, progress) {
    if (context.pageSize <= 0 || progress <= 0) {
      this.setPagePosition(context, this.contentFirstPageScroll(context));
      return;
    }
    if (progress >= 0.99) {
      this.setPagePosition(context, Math.max(0, this.contentLastPageScroll(context)));
      return;
    }
    var targetNode = this.findNodeAtProgress(progress);
    if (targetNode) {
      var range = document.createRange();
      range.setStart(targetNode, 0);
      range.setEnd(targetNode, Math.min(1, targetNode.length));
      var rect = this.getRect(range);
      var scroll = this.getPagePosition(context);
      var anchor = (context.vertical ? rect.top : rect.left) + scroll;
      this.setPagePosition(context, this.alignToPage(context, anchor));
    }
  },
  // TODO-1349（续·用户复诉「文字少也会去到最开头」）：把仍标记 loading="lazy" 的图强制翻成
  // eager 触发 load。往前翻到「文字少+图片」章的章末时，尾部整页插图仍是 lazy（非纯图片章
  // __fushiImageOnlyChapter=false），离屏 → 永不 load → 0 尺寸被 buildPaginationMetrics
  // 排除（分页 maxScroll 塌缩到章首）/ 被 scrollToChapterEnd 可见性判据跳过（连续停章首），
  // 且懒图 __imgReanchorProgress 重锚永不触发（尾图永不进视口 = 鸡生蛋）。这里在章末恢复时
  // 强制 load 打破鸡生蛋，图尺寸解析后走既有 load 回调重锚（分页 scrollToProgressPaged /
  // 连续 scrollToChapterEnd）落到含真实尾图几何的章末。仅往前翻到章末(restoreProgress>=0.99)
  // 触发，正向阅读 / 精确 char 锚不动 → 不回退 TODO-1074 懒加载；幂等（无 lazy 则 no-op）。
  forceLoadPendingImages: function() {
    var imgs = document.querySelectorAll('img[loading="lazy"]');
    for (var i = 0; i < imgs.length; i++) {
      imgs[i].setAttribute('loading', 'eager');
    }
  },
  // ── 迟到图片的语义重锚（TODO-1229 案B 的一般化 · BUG-1140 第二轮）─────────
  //
  // 恢复落点由「章内**语义锚**」定义：精确字符偏移（restoreToCharOffset）、粗粒度
  // progress（restoreProgress —— progressStops 同样是字符域）、或 fragment 目标元素。
  // 这三种锚本身与图片是否已 decode 无关，但把锚**换算成 scroll** 的那一步依赖当下
  // 几何：锚之前若有尚未 load 的懒图（0×0），换算结果就少了那些图的高度。图片随后
  // load、几何后移，冻结的 scroll 便指向别的内容——用户看到的位置漂了，随后
  // onReaderScroll 还会把这个漂掉的读数落库。
  //
  // 修法不是「恢复前等图片」（那正是要消除的整个加载周期），而是**图片 load 后按同一个
  // 语义锚重算一次**：终态与「图片本来就在」等价。仅在恢复落地后、用户尚未翻页的窗口内
  // 有效（paginate 清资格），且只由真正改变几何的 block 图 load 触发。重锚是程序化滚动，
  // 走既有 onReaderScroll 通道把**修正后**的位置落库（既有 >=0.99 章末重锚同一条路）。
  //
  // BUG-2744：锚是「阅读器**当前**正在展示的语义目标」，不是「本章打开时的落点」。程序化
  // 揭示（有声书跟读 highlightSentenceAudioCue → revealElement、跨插图暂停
  // __fushiRevealTarget、搜索命中）一旦把视口带到新目标，目标就换了——分页 scrollToRange /
  // 连续 scrollToTarget 在这里登记 {target}（Range 或元素），替换恢复锚。否则跟读翻过几页后
  // 前方懒图才 load，重锚把视口拽回开章那页（横排听书「插图位置闪一下、图被跳过」）；跨图
  // 暂停时滚到尚未 load 的插图（0 尺寸占位），load 后又对齐回那张图而不是停在错页。
  registerImageLateAnchor: function(anchor) {
    this.clearImageLateAnchor();
    if (!anchor) return;
    if (typeof anchor.charOffset === 'number') {
      this.__imgReanchorCharOffset = anchor.charOffset;
      this.__imgReanchorCharOffsetEnd = anchor.endCharOffset;
    } else if (typeof anchor.progress === 'number') {
      this.__imgReanchorProgress = anchor.progress;
    } else if (anchor.fragment) {
      this.__imgReanchorFragment = anchor.fragment;
    } else if (anchor.target) {
      // Range 是活的（DOM 变动后边界自动跟随，懒图 load 被包进 .block-img-wrapper 后仍选中
      // 那张图），复制一份避免与调用方共用（搜索把同一个 Range 交给了 CSS.highlights）。
      this.__imgReanchorTarget = typeof anchor.target.cloneRange === 'function'
        ? anchor.target.cloneRange() : anchor.target;
    }
  },
  clearImageLateAnchor: function() {
    this.__imgReanchorProgress = null;
    this.__imgReanchorCharOffset = null;
    this.__imgReanchorCharOffsetEnd = -1;
    this.__imgReanchorFragment = null;
    this.__imgReanchorTarget = null;
  },
  // BUG-2744 审查：**恢复锚**（BUG-2652 连续 beginRestoreReanchor 读的那一个）与上面的迟到
  // 图片锚分开存。图片锚会被程序化揭示替换（跟读 / 跨图 / 搜索的 {target}），而「播放中恢复
  // 完成」时 Dart 先同步下发跟读揭示（_onRestoreComplete → _updateCurrentCue → highlight
  // evaluateJavascript），之后才调 beginRestoreReanchor——两次 JS 按 FIFO，揭示总是先到。
  // 共用一个字段时揭示把字符锚换成 {target}，begin 退回现场采样，iOS 同一 WKWebView
  // 头几帧 scroll 读 0 → 采到章首 → commit 钉回章首并落库（BUG-2652 回归）。
  // 不变量：只由恢复入口（restoreToCharOffset 精确锚写入；restoreProgress / jumpToFragment /
  // 越界回退写 null）与用户翻页 paginate（写 null）改写；揭示、迟到图片重锚都不碰它。
  _setRestoreCharAnchor: function(charOffset, endCharOffset) {
    this.__restoreCharOffset = typeof charOffset === 'number' ? charOffset : null;
    this.__restoreCharOffsetEnd = endCharOffset;
  },
  // BUG-2748：用户亲手挪了视口（连续模式的滚轮 / 触摸原生滚动 / 拖滚动条 / 方向与翻页键
  // 原生滚动 / 查词弹窗遮罩转发的滚动），与 paginate 同一语义：放弃迟到图片锚与恢复锚。
  // 否则滚远后前方懒图 load，reapplyImageLateAnchor 把视口拽回最近一次揭示 / 恢复的目标。
  // 连续 shell 的输入监听见 continuousShellSource 末尾；Dart 转发见 _evaluateScrollForward。
  noteUserScroll: function() {
    this.clearImageLateAnchor();
    this._setRestoreCharAnchor(null);
  },
  // 连续 shell 独有 scrollToChapterEnd —— 与既有重锚回调同一条判别（不能用
  // scrollToProgressPaged，那是 _sharedJs 两 shell 都有的，连续会误走分页分支）。
  _isContinuousShell: function() {
    return typeof this.scrollToChapterEnd === 'function';
  },
  reapplyImageLateAnchor: function() {
    // BUG-2744：程序化揭示的目标——对齐回这个目标本身（分页落到它起始边所在页；连续按
    // 跟读同一套安全带判据滚回可见），绝不回退到开章落点。
    var target = this.__imgReanchorTarget;
    if (target) {
      if (this._isContinuousShell()) this.scrollToTarget(target);
      else this._alignRangeToPage(target);
      return true;
    }
    var co = this.__imgReanchorCharOffset;
    if (typeof co === 'number' && co > 0) {
      if (this._isContinuousShell()) {
        this.scrollToCharOffset(co, this.__imgReanchorCharOffsetEnd);
      } else {
        this.scrollToCharOffset(co);
      }
      return true;
    }
    if (this.__imgReanchorFragment) {
      return this.alignToFragmentTarget(this.__imgReanchorFragment);
    }
    var p = this.__imgReanchorProgress;
    if (typeof p !== 'number') return false;
    if (this._isContinuousShell()) {
      if (p >= 0.99) this.scrollToChapterEnd();
      else if (p <= 0) this.scrollToChapterStart();
      else this.scrollToProgressContinuous(p);
      return true;
    }
    var rctx = this.getScrollContext();
    if (!rctx || rctx.pageSize <= 0) return false;
    this.scrollToProgressPaged(rctx, p);
    return true;
  },
  notifyRestoreComplete: function() {
    this.perfMark('restoreDone');
    if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
      window.flutter_inappwebview.callHandler(
        'onRestoreComplete',
        this.perfSnapshot(),
        C.navigationGeneration
      );
    }
    if (typeof this.warmPaginationMetrics === 'function') {
      this.warmPaginationMetrics();
    }
  },
  createWalker: function(rootNode) {
    var root = rootNode || document.body;
    return document.createTreeWalker(root, NodeFilter.SHOW_TEXT, {
      acceptNode: (n) => this.isFurigana(n) ? NodeFilter.FILTER_REJECT : NodeFilter.FILTER_ACCEPT
    });
  },
  getRect: function(target) {
    var rect = target.getClientRects()[0];
    return rect || target.getBoundingClientRect();
  },
  buildNodeOffsets: function() {
    var offsets = new WeakMap();
    var walker = this.createWalker();
    var count = 0;
    var node;
    while (node = walker.nextNode()) {
      offsets.set(node, count);
      count += this.countChars(node.textContent);
    }
    this.nodeStartOffsets = offsets;
    if (this.paginationMetrics !== undefined) this.paginationMetrics = null;
  },
  // BUG-492 (TODO-1053 Bug A) 越界判据（分页/连续共用，_sharedJs）：charOffset 是否落在
  // 本章可匹配字符总数之内。恢复端用它护住旧脏收藏——写入端曾把某句错记成相邻章
  // sectionIndex，恢复加载错章后 charOffset 可能超本章字符总数 → 定位静默失败停错位。
  // 越界即回退章首（确定性落点）而非静默停。与 scrollToCharOffset 的走查同口径
  // （countChars / createWalker，furigana 已 REJECT）。>=0 且在范围内返 true。
  charOffsetInRange: function(charOffset) {
    if (typeof charOffset !== 'number' || charOffset < 0) return false;
    var walker = this.createWalker();
    var runningOffset = 0;
    var node;
    while (node = walker.nextNode()) {
      runningOffset += this.countChars(node.textContent);
      if (runningOffset > charOffset) return true;
    }
    return false;
  },
  // WebKit vertical text can give a collapsed caret range an all-zero rect,
  // even for an off-screen character. Measure that character instead; treating
  // the empty rect as a real origin restores every saved anchor to chapter start.
  characterAnchorRect: function(range) {
    var rect = range.getBoundingClientRect();
    if (rect.width > 0 || rect.height > 0) return rect;
    var node = range.startContainer;
    if (!node || node.nodeType !== 3) return null;
    var text = node.textContent || '';
    var start = range.startOffset;
    if (start >= text.length) return null;
    var glyph = range.cloneRange();
    // A learning-unit boundary can precede collapsed whitespace. Skip its
    // empty boxes, measuring one code point at a time rather than a union rect.
    while (start < text.length) {
      var end = start + (text.codePointAt(start) > 0xFFFF ? 2 : 1);
      glyph.setStart(node, start);
      glyph.setEnd(node, end);
      var rects = glyph.getClientRects();
      for (var i = 0; i < rects.length; i++) {
        if (rects[i].width > 0 && rects[i].height > 0) return rects[i];
      }
      start = end;
    }
    return null;
  },
  // TODO-736 A-1：连续模式进度的「字符级」分子。移植安卓 reader-continuous.js
  // countCharsBeforeViewport（:92-151）：返回本文本节点里**已滚出视口首边**的可匹配字符
  // 数（与 countChars / isMatchableChar 同口径作分子，calculateProgress 总字符作分母）。
  // 旧连续 calculateProgress 是「整节点 in/out」段落级粗粒度——节点只要有一像素还在视口
  // 就把整节点算未读，跨视口的长节点进度按整节点跳变 → 滚动模式进度感觉「没保存/不动」。
  // 这里对整节点先用 getClientRects 的并集矩形做三态短路（全过=满、全未过=0），仅当节点
  // 跨视口首边时才逐字二分定位首个仍可见字符，O(log n) 不全量遍历。空/零尺寸矩形跳过
  // （图片/折叠盒），代理对用 codePointAt/fromCodePoint 迭代（与 buildSasayakiNormIndex
  // 的码元处理一致），createWalker 已排除 rt/rp 振假名（分子分母同套，不重复计数）。
  //
  // 可选 edge（viewport 量纲）：缺省 = 视口**首边**（横排 0 / 竖排 window.innerWidth），
  // 逐字判据走 isTextOffsetBeforeViewport（TODO-773 守卫钉死其 window 量纲三件套，不加
  // 参数）；显式传入时 = 任意边（连续 getLastVisibleCharOffset 传视口**末边**：横排
  // window.innerHeight / 竖排 0），逐字判据走同算法的通用边版本 isTextOffsetBeforeViewportPaged
  // （名字里的 Paged 是它 body-relative 的出身，语义就是「rect 是否已越过给定边」）。
  countCharsBeforeViewport: function(node, vertical, edge) {
    var text = node.textContent || '';
    var totalChars = this.countChars(text);
    if (totalChars <= 0) return 0;
    var atFirstEdge = edge === undefined;
    if (atFirstEdge) edge = vertical ? window.innerWidth : 0;
    var range = document.createRange();
    range.selectNodeContents(node);
    var rects = range.getClientRects();
    if (!rects.length) return 0;
    var minStart = Infinity;
    var maxEnd = -Infinity;
    for (var i = 0; i < rects.length; i++) {
      var rect = rects[i];
      if (rect.width <= 0 || rect.height <= 0) continue;
      var start = vertical ? rect.left : rect.top;
      var end = vertical ? rect.right : rect.bottom;
      minStart = Math.min(minStart, start);
      maxEnd = Math.max(maxEnd, end);
    }
    if (vertical) {
      if (minStart >= edge) return totalChars;
      if (maxEnd <= edge || minStart === Infinity) return 0;
    } else {
      if (maxEnd <= edge) return totalChars;
      if (minStart >= edge || minStart === Infinity) return 0;
    }
    var offsets = [];
    var prefixCounts = [0];
    var count = 0;
    var offset = 0;
    while (offset < text.length) {
      offsets.push(offset);
      var char = String.fromCodePoint(text.codePointAt(offset));
      // 学习单位在**串尾**结算，判据吃位置而不是单个字符（见 reader_study_unit_script.dart）。
      if (window.fushiStudyUnits.isUnitEnd(text, offset)) count += 1;
      offset += char.length;
      prefixCounts.push(count);
    }
    var low = 0;
    var high = offsets.length - 1;
    var firstVisible = offsets.length;
    while (low <= high) {
      var mid = Math.floor((low + high) / 2);
      var passed = atFirstEdge
        ? this.isTextOffsetBeforeViewport(node, offsets[mid], text, vertical)
        : this.isTextOffsetBeforeViewportPaged(node, offsets[mid], text, vertical, edge);
      if (passed) {
        low = mid + 1;
      } else {
        firstVisible = mid;
        high = mid - 1;
      }
    }
    return prefixCounts[firstVisible];
  },
  // TODO-736 A-1：单字符是否已滚出视口首边（横排 rect.bottom<=0 / 竖排 rect.left>=innerWidth）。
  // 移植安卓 isTextOffsetBeforeViewport（:142-151）。零尺寸矩形（折叠/不可见）当未过，
  // 让二分把视口首边收敛到首个**真正可见**字符。
  isTextOffsetBeforeViewport: function(node, offset, text, vertical) {
    var char = String.fromCodePoint(text.codePointAt(offset));
    if (!char) return false;
    var range = document.createRange();
    range.setStart(node, offset);
    range.setEnd(node, offset + char.length);
    var rect = this.getRect(range);
    if (!rect || rect.width <= 0 || rect.height <= 0) return false;
    return vertical ? rect.left >= window.innerWidth : rect.bottom <= 0;
  },
  // TODO-736 A-2：getFirstVisibleCharOffset 的全文扫描兜底。连续模式下 caretRangeFromPoint
  // 在竖排 / ruby / 图片页 / 视口首边落在折叠盒时返 null → getFirstVisibleCharOffset 退化
  // 返 -1（落库丢精确锚、退回章节粒度分数）。本兜底用 countCharsBeforeViewport 全文累加，
  // 返「视口首边之前的可匹配字符总数」= 首个可见字符的绝对字符偏移（与 scrollToCharOffset
  // 的字符坐标系同口径，逆运算），无 caret 几何依赖。仅连续模式调用（分页有 snap/lock）。
  firstVisibleCharOffsetByScan: function() {
    var vertical = this.isVertical();
    // BUG-2903：连续 shell 有章内文本索引，同一个数走二分，不再全章 walk。
    if (typeof this._charsBeforeEdge === 'function') return this._charsBeforeEdge(vertical);
    var walker = this.createWalker();
    var explored = 0;
    var node;
    while (node = walker.nextNode()) {
      if (this.countChars(node.textContent) > 0) {
        explored += this.countCharsBeforeViewport(node, vertical);
      }
    }
    return explored;
  },
  // TODO-773 P0：分页版 getFirstVisibleCharOffset 的扫描兜底。竖排切字号/字体/主题后
  // 页顶常落 ruby / 图片 / 折叠盒 → caretRangeFromPoint 返 null → 分页版三个失败出口
  // 裸 return -1 → beginStyleReanchor 返 -1 → Dart 跳过 commit → CSS 已换但 scrollTop
  // 停残值不滚回 → 文字漂移。连续版在相同三失败点早已回退 firstVisibleCharOffsetByScan，
  // 但**不能裸抄连续版**：连续版沿书写轴的块方向滚动（横排上下 / 竖排左右），首边是
  // window 量纲的 0 / window.innerWidth；分页是 CSS multicol 沿**翻页轴**排列（与
  // getScrollContext / buildPaginationMetrics 同轴：横排列沿 x 左→右、scrollLeft 翻页；
  // 竖排列沿 y 上→下、scrollTop 翻页），前页在横排的**左侧** / 竖排的**上方**，首边是
  // body content-box 的起点（横排 padding-left / 竖排 padding-top，与分页 caret 探点
  // `pl + 2` / `pt + 2` 同量纲）。
  //
  // BUG-2492：此前这三件套抄了连续版的轴（横排比 rect.bottom<=0、竖排比
  // rect.left>=body.clientWidth），在分页几何下前页永远不满足「在首边之前」→ 逐节点累加
  // 恒为 0 → 兜底把任何页都报成章首 0。重锚路径被 scrollToCharOffset 的 `<=0 → 保当前页`
  // 掩住看不出来；统计接入后（fushiProgressDetails 第三/四段）页首角落在插图 / 空行时
  // 整段 [0, 页尾) 被当成本页可见区间，翻走一次就把几千字前文计成已读。仅分页 shell 调用。
  firstVisibleCharOffsetByScanPaged: function() {
    var vertical = this.isVertical();
    var firstEdge = this.pagedFirstEdge(vertical);
    var walker = this.createWalker();
    var explored = 0;
    var node;
    while (node = walker.nextNode()) {
      if (this.countChars(node.textContent) > 0) {
        explored += this.countCharsBeforeViewportPaged(node, vertical, firstEdge);
      }
    }
    return explored;
  },
  // 分页翻页轴上「当前页 content-box 起点」（body-relative）：横排 = padding-left、竖排 =
  // padding-top。前页的末列在它之前（中间还隔一个 column-gap），当前页的首列从它开始。
  // 分页 caret 探点（getFirstVisibleCharOffset 的 `pl + 2` / `pt + 2`）与扫描兜底、
  // 页上校验（charOffsetOnCurrentPage）都以它为首边，三处同量纲。
  pagedFirstEdge: function(vertical) {
    var cs = getComputedStyle(document.body);
    return vertical
      ? (parseFloat(cs.paddingTop) || 0)
      : (parseFloat(cs.paddingLeft) || 0);
  },
  // 分页翻页轴上「当前页 content-box 终点」（body-relative）：横排 = clientWidth −
  // padding-right、竖排 = clientHeight − padding-bottom。下一页的首列在它之后。
  pagedLastEdge: function(vertical) {
    var cs = getComputedStyle(document.body);
    return vertical
      ? document.body.clientHeight - (parseFloat(cs.paddingBottom) || 0)
      : document.body.clientWidth - (parseFloat(cs.paddingRight) || 0);
  },
  // TODO-773 P0：countCharsBeforeViewport 的分页版（body-relative 首边）。与连续版逐字
  // 二分定位同算法，只换轴：分页「在首边之前」= 沿翻页轴落在当前页 content-box 起点之前
  // （横排 rect.right <= firstEdge / 竖排 rect.bottom <= firstEdge，BUG-2492），其余三态
  // 短路、零尺寸跳过、代理对迭代全部一致。
  countCharsBeforeViewportPaged: function(node, vertical, firstEdge) {
    var text = node.textContent || '';
    var totalChars = this.countChars(text);
    if (totalChars <= 0) return 0;
    var range = document.createRange();
    range.selectNodeContents(node);
    var rects = range.getClientRects();
    if (!rects.length) return 0;
    var minStart = Infinity;
    var maxEnd = -Infinity;
    for (var i = 0; i < rects.length; i++) {
      var rect = rects[i];
      if (rect.width <= 0 || rect.height <= 0) continue;
      // 翻页轴：横排 x（列左→右）、竖排 y（列上→下）。
      var start = vertical ? rect.top : rect.left;
      var end = vertical ? rect.bottom : rect.right;
      minStart = Math.min(minStart, start);
      maxEnd = Math.max(maxEnd, end);
    }
    if (maxEnd <= firstEdge) return totalChars;
    if (minStart >= firstEdge || minStart === Infinity) return 0;
    var offsets = [];
    var prefixCounts = [0];
    var count = 0;
    var offset = 0;
    while (offset < text.length) {
      offsets.push(offset);
      var char = String.fromCodePoint(text.codePointAt(offset));
      // 学习单位在**串尾**结算，判据吃位置而不是单个字符（见 reader_study_unit_script.dart）。
      if (window.fushiStudyUnits.isUnitEnd(text, offset)) count += 1;
      offset += char.length;
      prefixCounts.push(count);
    }
    var low = 0;
    var high = offsets.length - 1;
    var firstVisible = offsets.length;
    while (low <= high) {
      var mid = Math.floor((low + high) / 2);
      if (this.isTextOffsetBeforeViewportPaged(node, offsets[mid], text, vertical, firstEdge)) {
        low = mid + 1;
      } else {
        firstVisible = mid;
        high = mid - 1;
      }
    }
    return prefixCounts[firstVisible];
  },
  // TODO-773 P0：isTextOffsetBeforeViewport 的分页版（body-relative 首边）。沿翻页轴判
  // 该字是否整个落在当前页 content-box 起点之前：横排 rect.right<=firstEdge（=padding-left）、
  // 竖排 rect.bottom<=firstEdge（=padding-top）（BUG-2492：不是连续版的 bottom<=0 /
  // left>=clientWidth）。
  isTextOffsetBeforeViewportPaged: function(node, offset, text, vertical, firstEdge) {
    var char = String.fromCodePoint(text.codePointAt(offset));
    if (!char) return false;
    var range = document.createRange();
    range.setStart(node, offset);
    range.setEnd(node, offset + char.length);
    var rect = this.getRect(range);
    if (!rect || rect.width <= 0 || rect.height <= 0) return false;
    return (vertical ? rect.bottom : rect.right) <= firstEdge;
  },
  // BUG-2492：章内偏移 [charOffset] 处那个学习单位是否画在**当前页**上（沿翻页轴与
  // 当前页 content-box [firstEdge, lastEdge) 相交）。fushiProgressDetails 把
  // getFirstVisibleCharOffset 的结果当可见区间起点喂统计账本，而该函数的三条兜底
  // （caret 失败 / 探点落元素 / 节点基址缺失）各自算出的偏移只保证「尽力」，不保证在
  // 本页；起点若不在本页，[起点, 页尾) 就不是一页而是一整段前文，翻走一次整段入账
  // （iOS 真机一页记了 5172 字）。走 scrollToCharOffset 同款的逐节点走查定位到字、取
  // 其 rect 校验；定位不到 / 零尺寸都按「不在本页」返 false——统计宁可不计。
  charOffsetOnCurrentPage: function(charOffset) {
    if (typeof charOffset !== 'number' || charOffset < 0) return false;
    var walker = this.createWalker();
    var node;
    var runningOffset = 0;
    var targetNode = null;
    var remaining = 0;
    while (node = walker.nextNode()) {
      var nodeChars = this.countChars(node.textContent);
      if (runningOffset + nodeChars > charOffset) {
        targetNode = node;
        remaining = charOffset - runningOffset;
        break;
      }
      runningOffset += nodeChars;
    }
    if (!targetNode) return false;
    var text = targetNode.textContent;
    var charIdx = 0;
    var textOffset = 0;
    for (var i = 0; i < text.length && charIdx < remaining; i++) {
      var cp = text.codePointAt(i);
      if (window.fushiStudyUnits.isUnitEnd(text, i)) charIdx++;
      if (cp > 0xFFFF) i++;
      textOffset = i + 1;
    }
    // 第 k 个单元结束后的下一个码元未必是第 k+1 个单元的首码元：西文空格分词的
    // 分隔空格、`<p>\n本文` 的前导折叠空白都落在这里。空白永远不是单元首字，而软换行
    // 处的尾随空格还可能带着一个落在**前页末行**的非零 rect——先按码元跳过空白，
    // 再交给 characterAnchorRect 跳零尺寸盒（scrollToCharOffset 同款）。
    while (textOffset < text.length && /\s/.test(text[textOffset])) textOffset++;
    if (textOffset >= text.length) return false;
    var cpAt = text.codePointAt(textOffset);
    var range = document.createRange();
    range.setStart(targetNode, textOffset);
    range.setEnd(targetNode, textOffset + (cpAt > 0xFFFF ? 2 : 1));
    var rect = this.characterAnchorRect(range);
    if (!rect || rect.width <= 0 || rect.height <= 0) return false;
    var vertical = this.isVertical();
    var firstEdge = this.pagedFirstEdge(vertical);
    var lastEdge = this.pagedLastEdge(vertical);
    var start = vertical ? rect.top : rect.left;
    var end = vertical ? rect.bottom : rect.right;
    return end > firstEdge && start < lastEdge;
  },
''';

  static const String _sharedJsTail = r'''
  unwrap: function(wrappers) {
    wrappers.forEach(function(wrapper) {
      var parent = wrapper.parentNode;
      if (!parent) return;
      while (wrapper.firstChild) {
        parent.insertBefore(wrapper.firstChild, wrapper);
      }
      parent.removeChild(wrapper);
      parent.normalize();
    });
  },
  scrollToSearchMatch: function(query, hintOffset) {
    if (!query) return null;
    var walker = this.createWalker();
    var node;
    var segments = [];
    while (node = walker.nextNode()) {
      segments.push({ node: node, text: node.textContent });
    }
    var fullText = segments.map(function(s) { return s.text; }).join('');
    var lowerQuery = query.toLowerCase();
    var lowerFull = fullText.toLowerCase();
    var matches = [];
    var searchFrom = 0;
    while (searchFrom <= lowerFull.length) {
      var idx = lowerFull.indexOf(lowerQuery, searchFrom);
      if (idx < 0) break;
      matches.push(idx);
      searchFrom = idx + 1;
    }
    if (!matches.length) return null;
    var bestIdx = matches[0];
    var bestDist = Math.abs(bestIdx - hintOffset);
    for (var m = 1; m < matches.length; m++) {
      var dist = Math.abs(matches[m] - hintOffset);
      if (dist < bestDist) { bestIdx = matches[m]; bestDist = dist; }
    }
    var targetStart = bestIdx;
    var targetEnd = targetStart + query.length;
    var charPos = 0;
    var startNode = null, startOffset = 0, endNode = null, endOffset = 0;
    for (var i = 0; i < segments.length; i++) {
      var seg = segments[i];
      var segEnd = charPos + seg.text.length;
      if (!startNode && targetStart < segEnd) {
        startNode = seg.node;
        startOffset = targetStart - charPos;
      }
      if (targetEnd <= segEnd) {
        endNode = seg.node;
        endOffset = targetEnd - charPos;
        break;
      }
      charPos = segEnd;
    }
    if (!startNode || !endNode) return null;
    var range = document.createRange();
    range.setStart(startNode, startOffset);
    range.setEnd(endNode, endOffset);
    if (window.__fushiCssHighlightsSupported) {
      CSS.highlights.set('fushi-search', new Highlight(range));
    }
    if (this.scrollToRange) {
      this.scrollToRange(range);
    } else if (this.scrollToTarget) {
      // TODO-1308 问题②（BUG-696 根因②）：旧兜底 range.surroundContents(span) 在
      // rb/rtc 形态书（JIS mono-ruby，如 <ruby><rb>貫</rb>…<rb>禄</rb>…）上，命中词
      // 跨相邻 <rb> 基字时 Range 部分包含元素节点 → 抛 InvalidStateError → 滚动被
      // 跳过；跨章搜索经 _applyPendingPreciseLocate（catch 后只记日志）确定性停在
      // 章节开头。scrollToTarget → getRect 用 getClientRects()[0]，Range 原生支持
      // → 直接滚 Range，不做 DOM 手术（旧 span 无高亮 class 只当滚动靶，且
      // surroundContents 还会切开文本节点、永久残留 span、作废 nodeStartOffsets）。
      this.scrollToTarget(range);
    }
    return this.calculateProgress();
  },
  clearSearchHighlight: function() {
    if (window.__fushiCssHighlightsSupported) {
      CSS.highlights.delete('fushi-search');
    }
  },
''';

  // ── Shared init logic (viewport + SVG + images) ────────────────────

  /// BUG-1140 第二阶段①：恢复锚的三选一从「Dart 注入期挑一条语句」搬到运行时。
  ///
  /// 优先级与旧的 Dart 三元式逐条相同：`initialFragment` 非空 → `jumpToFragment`；
  /// 否则 `initialCharOffset >= 0` → `restoreToCharOffset`；否则 `restoreProgress`。
  /// 分页 shell 只用单点句首锚（旧实现也只传一个参数）。
  static const String _paginatedInitialRestoreJs = '''
    if (C.initialFragment !== null && C.initialFragment !== undefined) {
      window.fushiReader.jumpToFragment(C.initialFragment);
    } else if (C.initialCharOffset >= 0) {
      window.fushiReader.restoreToCharOffset(C.initialCharOffset);
    } else {
      window.fushiReader.restoreProgress(C.initialProgress);
    }''';

  /// 连续 shell 版：多一条 BUG-461 的句尾区间对齐分支（`initialCharOffsetEnd >
  /// initialCharOffset` 时透传句尾偏移），其余与 [_paginatedInitialRestoreJs] 相同。
  static const String _continuousInitialRestoreJs = '''
    if (C.initialFragment !== null && C.initialFragment !== undefined) {
      window.fushiReader.jumpToFragment(C.initialFragment);
    } else if (C.initialCharOffset >= 0) {
      if (C.initialCharOffsetEnd > C.initialCharOffset) {
        window.fushiReader.restoreToCharOffset(C.initialCharOffset, C.initialCharOffsetEnd);
      } else {
        window.fushiReader.restoreToCharOffset(C.initialCharOffset);
      }
    } else {
      window.fushiReader.restoreProgress(C.initialProgress);
    }''';

  /// 有声书 cue 下发：旧实现「有 cue 才注入这一行」，现在「有 cue 才调用」。
  static const String _sharedSentenceAudioInitJs = '';

  /// 阅读器正文的 viewport 声明，唯一真相源。章节 HTML 交付时就带上
  /// [readerViewportMetaTag]（BUG-2639：否则 WKWebView 在 initialize 跑到之前按
  /// 980 CSS px 布局，iPhone 真机上竖排滚动模式停在那个 0.41 倍的布局里），
  /// [sharedInitViewportJs] 再用同一串覆盖书自带的 viewport meta。
  static const String readerViewportContent =
      'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no';

  static const String readerViewportMetaTag =
      '<meta name="viewport" content="$readerViewportContent"/>';

  static const String _sharedInitViewport =
      '''
  var viewport = document.querySelector('meta[name="viewport"]');
  if (viewport) { viewport.remove(); }
  var newViewport = document.createElement('meta');
  newViewport.name = 'viewport';
  newViewport.content = '$readerViewportContent';
  document.head.appendChild(newViewport);
''';

  /// 三种阅读 shell 共用的防剧透图片身份与会话揭开语义。
  ///
  /// 图片分类/布局仍由各 shell 自己负责；这段只建立稳定 reveal key、消费 Dart
  /// 会话里的 [ReaderEngineConfig.revealedKeys]，并提供 `_fushiBlurImage`。VN
  /// 过去用 no-op media semantics，导致同一 `blur_images` 设置在第三种视图失效。
  static String imageRevealSemanticsScript() => '''
  var _fushiRevealedKeys = Object.create(null);
  if (C.blurImages) {
    var __fushiKeys = C.revealedKeys;
    if (__fushiKeys && __fushiKeys.length) {
      for (var i = 0; i < __fushiKeys.length; i++) { _fushiRevealedKeys[__fushiKeys[i]] = true; }
    }
  }
  // TODO-1367：暴露给有声书桥接（audiobook_bridge）——音频跟随读过某张图时把它的稳定
  // reveal key 登记进本活集，日后该图（含尚未 load 的懒图）真正 load 走 _fushiBlurImage
  // 时命中 key 跳过遮罩，与点击 / 手柄揭开同一套「已揭开不再遮罩」真相源（会话内存活集）。
  if (C.blurImages) {
    window.__fushiMarkImageRevealed = function(key) {
      if (key) _fushiRevealedKeys[key] = true;
    };
    // 插图册的「恢复遮罩」反向：把 key 移出活集，正文里这张图下次 load（或宿主
    // 立刻补的 classList.add）就重新遮上。没有它，撤销只改了 Drift 与网格，当前
    // 这次阅读会话的正文仍然记得「已揭开」，重载章节照样不遮 —— 两端对同一张图
    // 给出相反答案。
    window.__fushiUnmarkImageRevealed = function(key) {
      if (key) delete _fushiRevealedKeys[key];
    };
  }
  // BUG-898：稳定 reveal key 归一到「extractDir 相对、decode、正斜杠」路径（如
  // OEBPS/images/foo.jpg），与图片库磁盘 File 的相对路径、Dart ImageRevealKey.normalize
  // 完全一致 —— 三端（阅读器 WebView / 图片库 / Drift 持久表）共享同一 key，才能双向同步。
  // 用 new URL(raw, baseURI) 折叠 ../ 并解析相对 src → 剥 fushi.local 的 /epub/ 前缀 +
  // decodeURIComponent → 相对路径。host 非本资源域（不该发生）时回退原始串。
  function _fushiImageRevealKey(element) {
    if (!element) return '';
    var raw = '';
    if (element.tagName === 'IMG') {
      raw = element.getAttribute('src') || element.src || '';
    } else if (element.querySelector) {
      var im = element.querySelector('image');
      if (im) raw = im.getAttribute('xlink:href') || im.getAttribute('href') || '';
    }
    if (!raw) return '';
    try {
      var u = new URL(raw, document.baseURI);
      if (u.host !== 'fushi.local') return raw;
      var path = decodeURIComponent(u.pathname);
      var pfx = '/epub/';
      var i = path.indexOf(pfx);
      if (i < 0) return raw;
      return path.substring(i + pfx.length);
    } catch (e) { return raw; }
  }
  if (C.blurImages) {
    window.__fushiImageRevealKey = _fushiImageRevealKey;
  }
  function _fushiBlurImage(element) {
    var key = _fushiImageRevealKey(element);
    if (key && _fushiRevealedKeys[key]) return;
    element.classList.add('blurred');
  }''';

  static String _sharedInitImages() {
    // TODO-1289：图片防剧透遮罩「点击揭开后又恢复」根因——揭开只删 DOM `blurred`
    // class，章节 (重)载 / 布局设置切换（writing mode / 分栏 / view mode / spread /
    // blur 开关，均经 _reloadWithCurrentSettings→_loadChapterDirectly）会重跑
    // initialize→_sharedInitImages，无条件给所有 block-img 重加 `blurred` → 揭开丢失。
    // 修复：把「本次阅读会话已揭开」的稳定 key（<img> src / <svg><image> href 相对
    // baseURI 解析成绝对 URL）注入成 map，_fushiBlurImage 命中则跳过重新遮罩。揭开
    // 状态的真相源是 Dart 侧 _revealedImageKeys（内存会话集），经 onImageRevealed
    // 回传持久，重载时再嵌入这里。domStorageEnabled=false 故不用 localStorage。
    // BUG-1140 第二阶段①：整块从「blurImages 为假时**整段不注入**」改成「函数照常
    // 定义、副作用照常受 C.blurImages 门控」。行为等价：`window.__fushiMarkImageRevealed`
    // / `window.__fushiImageRevealKey` 两个全局仍**只在开了防剧透遮罩时**才挂上
    // （caret / 有声书桥接都用 `if (window.__fushiImageRevealKey && …)` 探测），
    // `_fushiBlurImage` 也仍只在开关为真时被调用。
    final String blurFn = imageRevealSemanticsScript();
    const String blurSvgCall = 'if (C.blurImages) _fushiBlurImage(svg);';
    const String blurImgCall = 'if (C.blurImages) _fushiBlurImage(img);';
    return '''
$blurFn
  Array.from(document.querySelectorAll('svg')).forEach(function(svg) {
    var svgImage = svg.querySelector('image');
    if (!svgImage) return;
    if (svg.getAttribute('preserveAspectRatio') === 'none') {
      svg.setAttribute('preserveAspectRatio', 'xMidYMid meet');
    }
    if (svg.classList.contains('gaiji') || svg.classList.contains('gaiji-line')) return;
    // Fixed-layout EPUB covers/illustrations ship as <svg><image> instead of
    // <img>. Give large ones the same block treatment as <img> below (centre
    // via .block-img-wrapper + tap-to-zoom) so they don't fall through as
    // inline content that drifts to the page edge in vertical-rl reflow.
    var iw = parseFloat(svgImage.getAttribute('width')) || 0;
    var ih = parseFloat(svgImage.getAttribute('height')) || 0;
    if (iw <= 256 && ih <= 256) {
      var vb = (svg.getAttribute('viewBox') || '').split(/[ ,]+/);
      iw = parseFloat(vb[2]) || iw;
      ih = parseFloat(vb[3]) || ih;
    }
    if ((iw > 256 || ih > 256) && !svg.closest('.block-img-wrapper')) {
      svg.classList.add('block-img');
      var swrap = document.createElement('div');
      swrap.className = 'block-img-wrapper';
      svg.parentNode.insertBefore(swrap, svg);
      swrap.appendChild(svg);
      $blurSvgCall
    }
  });
  // TODO-1074（根因 A）：首屏可见性/restore 不再被「所有 <img> 都 decode 完」整页阻塞。
  // 旧实现给每个未完成的 <img> 挂 img.onload 才 resolve，Promise.all 揭开 restore 前要等
  // 最大图读盘+全分辨率解码 → 图片章首屏/换章卡（文字章几乎无 <img> 故快）。
  // 现在：
  //   · 每个 <img> 加 loading="lazy"（视口外不预取解码，不再拖住 window.load）+
  //     decoding="async"（解码离主线程，不阻塞首帧）。gaiji 内联小图除外——它们参与文字
  //     排版几何，必须 eager 同步，lazy 会让占位撑不开破坏 metrics。
  //   · 已 decode 完（complete && naturalWidth>0）的图仍同步分类 block-img 并即刻 resolve。
  //   · 未完成的图**立即 resolve**（不再 gate restore），block-img 归类推迟到它真正 onload
  //     时补做（懒图滚进视口才 load，普通图 decode 完），补做后失效 paginationMetrics 强制
  //     下次 paginate 用纳入真实图尺寸的几何重建（与 TODO-627 首帧那次失效同源）。
  // 竖排 SVG 封面（<svg><image>）走上面 querySelectorAll('svg') 的同步分支（尺寸取
  // 属性/viewBox，无需 onload），本改动不触及 → BUG-025 行为不变。
  function _fushiClassifyBlockImg(img) {
    var isGaiji = img.classList.contains('gaiji') || img.classList.contains('gaiji-line');
    if (isGaiji) return false;
    if (img.naturalWidth > 256 || img.naturalHeight > 256) {
      if (img.closest('.block-img-wrapper')) return false;
      img.classList.add('block-img');
      var wrapper = document.createElement('div');
      wrapper.className = 'block-img-wrapper';
      img.parentNode.insertBefore(wrapper, img);
      wrapper.appendChild(img);
      $blurImgCall
      return true;
    }
    return false;
  }
  // TODO-1349：纯图片章（正文无任何可匹配文本、仅由整页封面/插图构成）的所有 <img> 都是
  // 结构性内容。若挂 loading="lazy"，离屏图（分页远列 / 连续模式下方）永不进视口懒加载
  // margin → 永不 load → 保持 0 尺寸 → 被 buildPaginationMetrics 的 first/lastContentEdge
  // 排除 → 章末落点 maxScroll(contentLastPageScroll) 塌缩到章首 → 往前翻到本章停在封面（第
  // 一张图）而非最后一张图（用户报「从目录往前翻会去到封面」在分页模式的根因；连续模式另由
  // scrollToChapterEnd 覆盖，两墙互补）。与 gaiji / 合并前导插图同理保持 eager：无条件 load、
  // 真实撑开尺寸，metrics 计入全部图。readerRegex 单字符匹配（无 /g，test 无状态）在首个可匹配
  // 字符即短路 → 文本章几乎零开销、只对纯图片章全扫（文本极少）。图文混排章仍 lazy（不回退
  // TODO-1074 懒加载优化）；非图片章（有文本）完全 no-op（向后兼容）。
  var __fushiImageOnlyChapter =
      !window.fushiReader.readerRegex.test(document.body.textContent || '');
  Array.from(document.querySelectorAll('img')).forEach(function(img) {
    var isGaiji = img.classList.contains('gaiji') || img.classList.contains('gaiji-line');
    // TODO-1339：图片合并（前导插图折进后随文本章）注入的插图（`.fushi-merged-image`
    // 内，webview.part.dart _injectMergedChapterImages）是章首**结构性**内容——章首落点
    // (restoreProgress/restoreToCharOffset <=0 走 minScroll) 依赖 buildPaginationMetrics
    // 的 firstContentEdge，而 firstContentEdge 只计入**有非零尺寸**的媒体（0 尺寸被跳过）。
    // 若给这些前导插图挂 loading="lazy"，离屏（离首个文本落点较远的**第一张**）永不进入
    // 懒加载视口 margin → 永不 load → 保持 0 尺寸 → 被 firstContentEdge 排除 → 章首锚落到
    // 最近的已加载图（**最后一张**）跳过第一张 =「两张连续图只有最后一张合并进章节」。
    // 故与 gaiji 同理保持 eager：无条件 load、真实撑开尺寸，firstContentEdge 计入全部前导图，
    // 章首锚落到第一张。仅影响合并书的少量前导插图，不回退 TODO-1074 普通图懒加载。
    var isMergedLeadImg = img.closest && img.closest('.fushi-merged-image');
    // gaiji 内联小图参与文字几何：保持 eager 同步解码，不加 lazy。
    // TODO-1349：纯图片章的图同理 eager（见上 __fushiImageOnlyChapter 长注释）。
    if (!isGaiji && !isMergedLeadImg && !__fushiImageOnlyChapter) {
      img.setAttribute('loading', 'lazy');
    }
    img.setAttribute('decoding', 'async');
    if (img.complete && img.naturalWidth > 0) {
      _fushiClassifyBlockImg(img);
    } else {
      // 未完成：restore 不等它。真正 load 后补做 block-img 归类并失效 metrics。
      img.addEventListener('load', function() {
        if (_fushiClassifyBlockImg(img)) {
          var r = window.fushiReader;
          if (r && r.paginationMetrics !== undefined) r.paginationMetrics = null;
          // TODO-1229 案B / BUG-1140 第二轮：懒加载 block 图 load 后整章几何后移，冻结的
          // restore scrollTop 错位（Chromium 只在 scrollTop=0 自愈）。按本次恢复登记的
          // **语义锚**（char / progress / fragment）重算一次落点，终态与「图片本来就在」
          // 等价。属程序化滚动，不污染 TODO-798 userDriven 因果门；有用户输入
          // （paginate 已 clearImageLateAnchor）则不动。三种锚的分派见 reapplyImageLateAnchor。
          if (r && typeof r.reapplyImageLateAnchor === 'function') {
            r.reapplyImageLateAnchor();
          }
        }
      });
    }
  });
  // TODO-1074：restore/buildNodeOffsets 只等已完成的图（几乎瞬时），未完成图不 gate。
  var imagePromises = [];
''';
  }

  // BUG-1017: `initialize()` runs synchronously inside the outer reader-setup
  // IIFE (webview.part.dart), whose tail removes the `#fushi-cloak`
  // `body{visibility:hidden}` FOUC guard. A synchronous throw in initialize()
  // (e.g. on a fixed-layout SVG vertical cover page with zero text nodes)
  // aborted the IIFE before its tail, stranding the cloak -> the whole book
  // stayed `visibility:hidden` (permanent blank). The VN shell already guards
  // its boot for exactly this reason (reader_visual_novel_scripts.dart) but the
  // paginated / continuous shells used a bare call. Contain the throw here so
  // the IIFE always reaches its cloak removal (and later caret / furigana /
  // gesture setup still installs), and surface the real error on the console so
  // the underlying init failure can still be diagnosed and fixed.
  static const String _sharedInitBoot = '''
function _fushiBootInitialize() {
  try {
    window.fushiReader.initialize();
  } catch (e) {
    try { if (window.console && console.error) console.error('[FushiReader] boot initialize failed', e); } catch (_ignored) {}
  }
}
window.addEventListener('load', function() {
  _fushiBootInitialize();
});
if (document.readyState === 'complete') {
  _fushiBootInitialize();
}
''';

  // ── Paginated mode ─────────────────────────────────────────────────

  /// 分页 shell 的静态源码（零 per-nav 插值，全部参数改由运行时 `C` 读取）。
  static String paginatedShellSource() {
    // BUG-162: 优先精确字符偏移恢复（restoreToCharOffset），无精确锚（旧存档）才
    // 回退粗粒度 restoreProgress；书签/fragment 跳转仍走 jumpToFragment。
    // BUG-1140 第二阶段①：三选一从「Dart 注入期挑一条语句」改成「运行时按同一优先级
    // 读 C 分派」。判据逐条对齐旧实现（fragment 非空 > charOffset >= 0 > progress）。
    const String initialRestoreScript = _paginatedInitialRestoreJs;
    const String sentenceAudioInit = _sharedSentenceAudioInitJs;

    const int bottomOverlapPx = ReaderLayoutDefaults.bottomOverlapPx;
    const double imageWidthRatio = ReaderLayoutDefaults.imageWidthViewportRatio;
    const String spacerHeight = ReaderLayoutDefaults.trailingSpacerHeightCss;
    const String spacerWidth = ReaderLayoutDefaults.trailingSpacerWidthCss;

    final String initImages = _sharedInitImages();

    return '''<script>
window.__fushiShells.paginated = function(C) {
window.__fushiCssHighlightsSupported = !!(window.CSS && CSS.highlights && window.Highlight);
window.fushiReader = {
  // 跨章分段计时总开关（Dart [ReaderChapterPerfTrace.enabled] → C.perfTraceEnabled）。
  // false = 生产路径，perfMark / perfSnapshot 零开销。
  _perfOn: C.perfTraceEnabled === true,
  pageHeight: 0,
  pageWidth: 0,
  // TODO-734：纯视口高 V（不含 bottomOverlap=O）。竖排列高几何唯一用它（见
  // getScrollContext），与 CSS --reader-viewport-height 成对。必须先声明 0，否则
  // 首帧读到 undefined→NaN→pageStep 退化成 1。initialize/updatePageSize 会赋为 V。
  viewportHeight: 0,
  paginationMetrics: null,
$_sharedJs
  revealElement: function(element) {
    var range = document.createRange();
    range.selectNodeContents(element);
    return this.scrollToRange(range);
  },
  getScrollContext: function() {
    // TODO-729：单一量纲（对齐安卓 reader-paginated.js getScrollContext）。
    // 列周期 = column-width + column-gap。CSS column-width 已等于 content-box
    // （reader_content_styles.dart 按书写轴分支扣 turn 轴 padding），单列正好填满
    // content-box，故真实列周期 == content-box + gap == pageStep。pageStep 是唯一的
    // 「整页步进 / 对齐 / maxScroll 减项」量纲，废除旧的「步进量与可视区减项」双量。
    // maxScroll = totalSize - pageStep（安卓 totalSize - pageSize 同形）：减项与对齐量
    // 同源，末页 floor 边界与真实最后一列严格对齐，杜绝「翻一半跳章」（旧实现减项用
    // 含 padding 的可视区，与对齐量差 padding-gap → 末页错位 ±gap）。
    var vertical = this.isVertical();
    var scrollEl = document.body;
    var cs = getComputedStyle(scrollEl);
    var contentBox;
    // TODO-753/792（横排 + 竖排亚像素 pageStep 统一）：列周期 = used column-width +
    // column-gap。直接取 getComputedStyle(scrollEl).columnWidth —— 浏览器对 CSS
    // column-width（横排 `calc(page-width − <ml>vw − <mr>vw)`、竖排
    // `max(F, calc(V − margins − F − chrome))`，两轴都解析成亚像素 used 列宽/列高）的
    // 单次解析结果，与 column-gap 一起就是真实列周期。令 JS 翻页网格步距 pageStep ==
    // 浏览器真实列周期，paginate 的 N×pageStep 绝对网格与真实列严格对齐，残差恒 0：
    //   · 横排（TODO-753 真机取证）：消除整数化 scrollEl.clientWidth（CSSOM client* 被
    //     规范取整成 1265，真实列宽 1265.33）泄漏的 δ≈0.33px/页。
    //   · 竖排（TODO-792/773）：消除「injectedV − 双 parseFloat(padding) 重建」与浏览器
    //     「单次 calc 解析 column-width」之间的亚像素失配 —— body padding 的 used 值按设备
    //     像素网格独立 snap，重建路径与 column-width 解析的取整粒度不同 → 每页同号 δ 经
    //     N×pageStep 网格累积 → 竖排文字越翻越向下偏。读 used columnWidth 让 contentBox
    //     按定义恒等于浏览器列周期分量（CSS 端 columnWidth==contentBox 由
    //     reader_vertical_pitch_invariant_test 代数证明，这里读权威的那个，消重建残差）。
    // 只有 columnWidth 解析失败（'auto'/空 → NaN）才按轴回退旧路径，绝不引入双量纲。
    var resolvedColumnWidth = parseFloat(cs.columnWidth);
    if (resolvedColumnWidth > 0) {
      contentBox = resolvedColumnWidth;
    } else if (vertical) {
      // 竖排兜底：注入纯视口高 V − 上下 padding（TODO-734 与 --reader-viewport-height 成对）。
      var pt = parseFloat(cs.paddingTop) || 0;
      var pb = parseFloat(cs.paddingBottom) || 0;
      contentBox = (this.viewportHeight || scrollEl.clientHeight || window.innerHeight) - pt - pb;
    } else {
      // 横排兜底：整数 clientWidth − 左右 padding（仅 columnWidth 不可用时）。
      var pl = parseFloat(cs.paddingLeft) || 0;
      var pr = parseFloat(cs.paddingRight) || 0;
      contentBox = (scrollEl.clientWidth || this.pageWidth || window.innerWidth) - pl - pr;
    }
    // TODO-743（P0 坍塌地板）：CSS column-width 在 cT+cB+F≥V 坍塌区夹了
    // max(Fpx, calc(...)) 地板（reader_content_styles.dart 的 verticalColumnWidthCss），这里
    // 必须用同一个字号地板，否则坍塌区 contentBox 仍归 1 → pageStep 与浏览器真实列
    // 周期失配复活「翻一半跳章」。fontSize 用 getComputedStyle(scrollEl).fontSize ——
    // 即 CSS `body { font-size: <settings.fontSize>px }` 应用到正文的同一运行时值，
    // 保证 CSS 地板 == JS 地板（不靠注入常量、不会漂）。
    var fontFloor = parseFloat(cs.fontSize) || 1;
    contentBox = Math.max(fontFloor, contentBox);
    var gap = parseFloat(cs.columnGap) || 0;
    // TODO-1285（每页列数根因修复）：一页含 N 列（CSS column-count），页步 =
    // N × 真实列周期(used column-width + gap)。N 从 getComputedStyle(body).columnCount
    // 直接读——与上面读 column-width/column-gap 同一权威真值源（CSS 由
    // reader_content_styles 按 pageColumns 成对发 column-count:N + 子列宽 column-width），
    // 无需注入 state、绝不与 CSS 失步。pageColumns=0（自动/无 column-count）→ columnCount
    // = 'auto' → parseInt → NaN → columns=1 → pageStep = contentBox + gap，与旧单列字节
    // 等价（零行为变化）。子列宽 contentBox 由浏览器亚像素解析，N×(contentBox+gap) 恒等
    // 整页 content-box + gap，翻页网格仍落真实列边界，无 TODO-753/792 亚像素漂移。
    // TODO-1285 健壮化根因修复（「相邻页/上下页内容全露出来」复诉）：pageStep 曾直接乘
    // parseInt(cs.columnCount)，若回读到有效数字才对；但 column-count 与 column-width 并存时，
    // 个别 WebView 会把 getComputedStyle(body).columnCount 回读成 'auto'（parseInt→NaN）。
    // 旧兜底 `if(!(columns>0)) columns=1` 此时把 columns 塌成 1 → pageStep = contentBox+gap
    // = **单列步长**，而 CSS 仍渲染 N 列 → 每次翻页只前进一列、视口内 N−1 列与上一页重叠
    // 露出（正是复诉的「上一页和下一页内容全露出来」）。根因：pageStep 不该脆弱依赖单个
    // columnCount 回读。columnCount 读不到有效数字时**绝不塌成 1**，改从真实几何反推 N——
    // 一页恒等于整 content-box（turn 轴），故 N = round((整 content-box + gap)/(used 子列宽 +
    // gap))，代数上 == 名义列数且不依赖 columnCount。整 content-box 从 turn 轴亚像素读：横排
    // getBoundingClientRect().width−左右 padding（分数精度，避开 TODO-753 的整数 clientWidth），
    // 竖排 this.viewportHeight−上下 padding（与上面竖排 contentBox 兜底同源）。columnCount 正常
    // 回读为数字时仍走原快路径、字节不变（Chromium/WebView2 实测回读 == N，零回归）；pageColumns=0
    // 单列(columnCount='auto')反推得 N=1、pageStep 退回 contentBox+gap，与旧单列字节等价。不改
    // contentBox（仍是 used columnWidth），TODO-753/792 亚像素列周期原样保留。
    var columns = parseInt(cs.columnCount, 10);
    if (!(columns > 0)) {
      var fullTurnBox = vertical
        ? ((this.viewportHeight || scrollEl.clientHeight || window.innerHeight)
            - (parseFloat(cs.paddingTop) || 0) - (parseFloat(cs.paddingBottom) || 0))
        : ((scrollEl.getBoundingClientRect().width || scrollEl.clientWidth
              || this.pageWidth || window.innerWidth)
            - (parseFloat(cs.paddingLeft) || 0) - (parseFloat(cs.paddingRight) || 0));
      columns = Math.max(1, Math.round((fullTurnBox + gap) / (contentBox + gap)));
    }
    var pageStep = columns * (contentBox + gap);
    // TODO-792（竖排「文字向下偏移」根因修复·已下沉到 CSS）：曾一度在这里给竖排 pageStep += O
    // 补偿「列被 V+O 容器拉伸」造成的 realPitch>pageStep，但那只治页间累积、治不了页内逐列斜置
    // （斜置同源于列拉伸）。根因修法是让多列容器 body 高 == 纯 V（reader_content_styles.dart 的
    // `body{height:var(--reader-viewport-height)}`）→ 列不再拉伸、used 列高回 793、realPitch 回
    // 815 == 名义 pageStep。故这里**不再补偿**：contentBox+gap 已等于真实列周期，加 O 反会过冲。
    var totalSize = vertical ? scrollEl.scrollHeight : scrollEl.scrollWidth;
    var maxScroll = Math.max(0, totalSize - pageStep);
    // maxScroll 是分页网格的逻辑尾界（仍以唯一 pageStep 为减项）；浏览器实际能赋给
    // scrollTop/scrollLeft 的终点则由 scroll extent - client extent 决定。chrome inset
    // 会让 pageStep 小于 client extent，两者因此可相差半页。物理尾界不是第二套步长，
    // 只用于最后一张无法整页对齐的 terminal clamp。
    var viewportExtent = vertical ? scrollEl.clientHeight : scrollEl.clientWidth;
    var physicalMaxScroll = Math.max(0, totalSize - viewportExtent);
    // BUG-1764（有声书下一页第一句不翻页）/ BUG-875（竖排行尾单字凭空前翻）的共同根因：
    // 分页网格的**相位**。滚动坐标原点是 body 的 padding box 起始边，而列内容从 content box
    // 起始边开始 —— 两者恰差一个 turn 轴起始 padding。故列 j 的起始滚动坐标恒为
    // contentStart + j*pageStep，而不是 j*pageStep。判「某个 anchor 属于第几列」必须先减掉
    // contentStart 再除 pageStep（见 alignToPage）。turn 轴由 vertical 决定：竖排（vertical-rl
    // 的 inline 轴竖直、列向下堆叠、滚 scrollTop）取 paddingTop，横排取 paddingLeft，与
    // getPagePosition / 各落页锚的起始边取轴严格同源。
    var contentStart = vertical
      ? (parseFloat(cs.paddingTop) || 0)
      : (parseFloat(cs.paddingLeft) || 0);
    return {
      vertical: vertical,
      scrollEl: scrollEl,
      pageSize: pageStep,
      maxScroll: maxScroll,
      physicalMaxScroll: physicalMaxScroll,
      viewportExtent: viewportExtent,
      contentStart: contentStart,
      // BUG-2325：列间距。alignToPage 拿它当「落页网格的下侧容差」——gap 带里没有任何
      // 内容，落进去的锚只可能是后一列列顶被网格漂移带到线下的字。见 alignToPage。
      columnGap: gap
    };
  },
  getPagePosition: function(context) {
    return context.vertical ? context.scrollEl.scrollTop : context.scrollEl.scrollLeft;
  },
  lockRootViewport: function() {
    var root = document.documentElement;
    var didScroll = false;
    if (root.scrollTop !== 0) {
      root.scrollTop = 0;
      didScroll = true;
    }
    if (root.scrollLeft !== 0) {
      root.scrollLeft = 0;
      didScroll = true;
    }
    if (window.scrollX !== 0 || window.scrollY !== 0) {
      window.scrollTo(0, 0);
      didScroll = true;
    }
    return didScroll;
  },
  assignPagePosition: function(context, position) {
    if (context.vertical) {
      context.scrollEl.scrollTop = position;
    } else {
      context.scrollEl.scrollLeft = position;
    }
    this.lockRootViewport();
  },
  setPagePosition: function(context, position) {
    var clamped = Math.min(Math.max(0, position), context.physicalMaxScroll);
    window.lastPageScroll = clamped;
    this.assignPagePosition(context, clamped);
    return clamped;
  },
  registerSnapScroll: function(initialScroll) {
    if (window.snapScrollRegistered) return;
    window.snapScrollRegistered = true;
    window.lastPageScroll = initialScroll;
    this.lockRootViewport();
    window.addEventListener('scroll', () => {
      if (this.lockRootViewport()) {
        requestAnimationFrame(() => this.lockRootViewport());
      }
    }, { passive: true });
    document.body.addEventListener('scroll', () => {
      this.lockRootViewport();
      var context = this.getScrollContext();
      if (context.pageSize <= 0) return;
      var currentScroll = this.getPagePosition(context);
      var snappedScroll = Math.round(currentScroll / context.pageSize) * context.pageSize;
      snappedScroll = Math.min(Math.max(0, snappedScroll), context.physicalMaxScroll);
      if (Math.abs(currentScroll - snappedScroll) > 1) {
        this.assignPagePosition(context, window.lastPageScroll || 0);
      } else {
        window.lastPageScroll = snappedScroll;
      }
    }, { passive: true });
  },
  alignToPage: function(context, offset) {
    // 相位修正（BUG-1764/BUG-875 同源根因）：列 j 的起始滚动坐标 = contentStart + j*pageSize
    // （见 getScrollContext 的 contentStart），所以列号 = floor((anchor − contentStart)/pageSize)。
    // 裸 floor(anchor/pageSize) 相当于把网格整体平移了 contentStart：
    //   · contentStart > gap 时，每列末尾 (contentStart − gap) 那段内容被判进下一列 → 落页前翻
    //     一页（BUG-875 竖排行尾单字凭空翻页的真正来源）；
    //   · 反过来下一列开头那段被判成仍属本列 → 该翻不翻（BUG-1764）。
    // 减相位后 alignToPage 就是精确的列号函数，两个方向的错判同时消失，不需要任何可见性特例。
    // 返回值仍落在 j*pageSize 的滚动网格上（页对齐后内容起始边露出 contentStart 的页边距，
    // 与 paginate / pageStepPosition / minScroll 的网格严格同源，网格本身零变化）。
    //
    // BUG-2325（真机 HiBreak 竖排：有声书跟随读到「句首恰在列顶」的句子时退回前一页，下
    // 一句又翻回来）：列号函数还必须带**下侧容差**，否则它在列边界上是零余量的等号判据。
    // 根因是 pageStep 与浏览器真实列周期之间存在**每页累积**的亚像素差：
    //   · pageStep 由 `parseFloat(getComputedStyle(body).columnWidth)` 推出，而 CSSOM 把
    //     used 值序列化成 3 位小数字符串；
    //   · 浏览器内部把 used 列宽量化到 LayoutUnit（1/64 px）再排版。
    //   两者只有在列宽恰好是 1/64 的整数倍时才相等。真机 824x1648@300dpi → DPR 1.875 →
    //   CSS 视口高 878.9333…px（小数！）→ used 列宽 832.9333…px 被量化成 832.921875px，
    //   而 JS 读到 "832.933px" → pageStep 每页比真实列周期大 0.0111px。第 j 列的真实起始
    //   坐标因此比网格线 j*pageStep 低 j*0.0111px：第 9 页起就低过 0.1px，第 89 页低近 1px。
    //   列顶首字的 anchor 恰好等于该列真实起始坐标，于是 floor 把它判进**前一列** → 视口
    //   退回上一页；下一句 cue 不在列顶，anchor 远离网格线，又翻回来。整数 CSS 视口（列宽
    //   本就是 1/64 倍数）零漂移，所以这条只在小数 DPR 设备上现形。
    // 网格线之前恰好是 column-gap 那一段，**没有任何内容**（前一列内容盒在 gap 之前就结束
    // 了），所以落进 gap 带的锚只可能是后一列被漂移带下来的列顶字。列号按「gap 归属后一列」
    // 定义即可，容差用的是几何真值 gap(22px)，不是拍脑袋的 ε：按上面的漂移率能兜住约 1900
    // 页，且列内任意位置（含列末最后一像素，anchor−phase+gap < (j+1)*pageSize）仍落本列，
    // BUG-875 / BUG-1764 两个方向都不受影响。
    // 不去改 pageStep 本身（把它量化到 1/64 是 Blink 实现细节、跨引擎不成立；改列周期口径
    // 会动到 paginate/minScroll/restore 全部落页路径，见 TODO-753/792 的历史）。
    var phase = context.contentStart || 0;
    var gapTolerance = context.columnGap || 0;
    return Math.floor(Math.max(0, offset - phase + gapTolerance) / context.pageSize) * context.pageSize;
  },
  alignContentStartToPage: function(context, offset) {
    // TODO-1179：章首落点只能向下偏置到「包含首行内容边」的那一页。firstContentEdge
    // 恰落在页边界下方 <1px（k*pageStep-ε，sub-pixel）时旧 Math.round 会向上取整到页 k，
    // 但首行内容边实际在页 k-1 → minScroll 抬到页 k、手动前进跳章 progress=0 落第二页、
    // 整页首行被跳。内容起始边恒属于它所在页(floor)，floor 对边界上/下方 sub-pixel 都落
    // 「含首行」那页，绝不跳过首行（宁可多显示半列 padding）。与 scrollToCharOffset /
    // scrollToProgressPaged 的 floor(alignToPage) 落页锚同量纲；此函数只被 minScroll
    // 一处调用，无其它场景受影响。
    // BUG-2325：alignToPage 起带 gap 下侧容差（列顶字不再被网格漂移判进前一列）；章首落点
    // **不吃**这条容差——这里的语义是「绝不跳过首行」，首行内容边真落在前一列末时必须留在
    // 前一列，吃了容差反而会把它推进下一列、跳过首行。故保留裸相位 floor。
    var phase = context.contentStart || 0;
    return Math.floor(Math.max(0, offset - phase) / context.pageSize) * context.pageSize;
  },
  pageStepPosition: function(currentScroll, pitch) {
    if (pitch <= 0) return currentScroll;
    var nearestPage = Math.round(currentScroll / pitch) * pitch;
    return Math.abs(currentScroll - nearestPage) <= 1 ? nearestPage : currentScroll;
  },
  scrollToRange: function(range) {
    // BUG-2744：揭示的目标即阅读器此刻的语义落点，替换恢复锚（见 registerImageLateAnchor）。
    // 不论这次是否真的翻页都要登记：跨图暂停滚到尚未 load 的插图时，0 尺寸占位常还在当前
    // 页（不翻），load 撑开后插图才挪到下一页，得靠这个锚把视口带过去。
    this.registerImageLateAnchor({target: range});
    return this._alignRangeToPage(range);
  },
  _alignRangeToPage: function(range) {
    var context = this.getScrollContext();
    if (context.pageSize <= 0) return false;
    var rect = this.getRect(range);
    var currentScroll = this.getPagePosition(context);
    // TODO-881：落页锚取起始边（竖排 rect.top、横排 rect.left），与
    // restoreToCharOffset / jumpToFragment / scrollToCharOffset 统一。
    // 旧实现用首段 rect 的几何中点（top/bottom 或 left/right 取中），句首落列后
    // 半段时中点越界相邻列 → floor 前翻，下一句又翻回 = 有声书自动读翻页抖动。
    // 起始边锚恒落「句子起点所在页」，不越界。轴向语义已被起始边路径锁定，不自创轴向。
    var startEdge = context.vertical ? rect.top : rect.left;
    var anchor = startEdge + currentScroll;
    var targetScroll = this.alignToPage(context, anchor);
    // BUG-1764（有声书跟随读到下一页第一句时不翻页）：这里曾有一条
    // `if (startEdge >= 0 && startEdge < context.viewportExtent) return false;` 的
    // 「已可见即不翻」短路，是 BUG-875（竖排行尾单字凭空前翻）的旧修法。它用 client 视口
    // extent 当可见判据，而 client 视口比一页真正的内容（contentBox）宽出 turn 轴两侧 padding：
    // 只要**结束边** padding > column-gap（横排 W>1100px 的宽屏、竖排字号>22 或底栏占位 /
    // 移动端系统 inset），下一页开头那段就落在 [pageStep, viewportExtent) 带内被判成「本页可见」
    // → 该翻不翻，要等到再下一句才翻，表现为「下一页第一句不自动翻页」。
    // 而 BUG-875 的行尾单字与本 bug 的下一页首句在 startEdge / targetScroll 上取值完全相同，
    // 单一阈值结构上区分不了两者 —— 说明判据维度本身就错了。真正的根因是 alignToPage 缺列
    // 网格相位（见那里的注释）：补上相位后，`targetScroll === currentScroll` 已经精确表达
    // 「句首就在本页」，两个方向的错判同时消失，这条特例短路不再需要，删除。
    if (targetScroll === currentScroll) return false;
    this.setPagePosition(context, targetScroll);
    var self = this;
    requestAnimationFrame(function() {
      self.setPagePosition(context, targetScroll);
    });
    return true;
  },
  contentLastPageScroll: function(context) {
    var metrics = this.paginationMetrics || this.buildPaginationMetrics();
    return metrics.maxScroll;
  },
  contentFirstPageScroll: function(context) {
    var metrics = this.paginationMetrics || this.buildPaginationMetrics();
    return metrics.minScroll;
  },
  warmPaginationMetrics: function() {
    if (this.paginationMetrics) return;
    var run = () => {
      if (this.paginationMetrics) return;
      this.buildPaginationMetrics();
    };
    if (window.requestIdleCallback) {
      window.requestIdleCallback(run, { timeout: 1000 });
    } else {
      setTimeout(run, 200);
    }
  },
  buildPaginationMetrics: function() {
    var context = this.getScrollContext();
    var currentScroll = this.getPagePosition(context);
    // TODO-1179：context.maxScroll = totalSize − pageStep，单一量纲下应恰为末列页的
    // 整页倍数；但竖排 vh/chrome-inset sub-pixel 使 totalSize 比 numCols*pageStep 少
    // 零点几 px → 裸 floor 把 P*pageStep−ε 砍成 (P−1)*pageStep，末列整页(含末行)不可达
    // → 手动后退跳章 progress=0.99 落 maxScroll 停在倒数第二页、末行被跳。加 1px 容差吸收
    // sub-pixel 下溢（要真多一页需近乎一整列真实尾随空间，容差绝不越界；下方 maxScroll 仍
    // 被 lastContentScroll 上限夹住不越过末内容页，setPagePosition 再 clamp 到
    // context.physicalMaxScroll，绝不 overscroll）。与 pageStepPosition / alignContentStartToPage
    // 的 1px sub-pixel 归一同口径。
    var maxAlignedScroll = Math.floor((context.maxScroll + 1) / context.pageSize) * context.pageSize;
    if (context.pageSize <= 0) {
      var emptyMetrics = { minScroll: 0, maxScroll: 0, totalChars: 0, progressStops: [] };
      this.paginationMetrics = emptyMetrics;
      return emptyMetrics;
    }
    var lastContentEdge = 0;
    var firstContentEdge = null;
    var progressStops = [];
    var exploredChars = 0;
    var totalChars = 0;
    var walker = this.createWalker();
    var node;
    while (node = walker.nextNode()) {
      var nodeLen = this.countChars(node.textContent);
      totalChars += nodeLen;
      if (nodeLen <= 0) continue;
      var range = document.createRange();
      range.selectNodeContents(node);
      var rects = range.getClientRects();
      var progressRect = this.getRect(range);
      var nodeStartEdge = progressRect && progressRect.width > 0 && progressRect.height > 0
        ? (context.vertical ? progressRect.top : progressRect.left) + currentScroll
        : null;
      for (var i = 0; i < rects.length; i++) {
        var rect = rects[i];
        if (rect.width <= 0 || rect.height <= 0) continue;
        var startEdge = (context.vertical ? rect.top : rect.left) + currentScroll;
        var endEdge = (context.vertical ? rect.bottom : rect.right) + currentScroll;
        firstContentEdge = firstContentEdge === null ? startEdge : Math.min(firstContentEdge, startEdge);
        lastContentEdge = Math.max(lastContentEdge, endEdge);
      }
      if (nodeStartEdge !== null) {
        progressStops.push({ scroll: nodeStartEdge, exploredChars: exploredChars + nodeLen });
      }
      exploredChars += nodeLen;
    }
    var media = document.querySelectorAll('img, svg, image, video, canvas');
    for (var j = 0; j < media.length; j++) {
      var mediaRect = media[j].getBoundingClientRect();
      if (mediaRect.width <= 0 || mediaRect.height <= 0) continue;
      var mediaStart = (context.vertical ? mediaRect.top : mediaRect.left) + currentScroll;
      var mediaEnd = (context.vertical ? mediaRect.bottom : mediaRect.right) + currentScroll;
      firstContentEdge = firstContentEdge === null ? mediaStart : Math.min(firstContentEdge, mediaStart);
      lastContentEdge = Math.max(lastContentEdge, mediaEnd);
    }
    var startAlignedScroll = firstContentEdge === null ? 0 : this.alignContentStartToPage(context, firstContentEdge);
    // BUG-2819：末页 = 最后内容边所在的那一列，列号同样要先减相位 contentStart（与
    // alignToPage / alignContentStartToPage 同源：列 j 的内容从 contentStart + j*pageSize
    // 开始）。裸 floor 把每列末尾 (contentStart − gap) 那段判进下一格——末行接近满行时
    // lastContentScroll 多算一页。旧几何下它被 maxAligned 盖住；WebKit 分页末尾补一栏后
    // maxAligned 跟着变大，末页就被推到补出来的那一栏的空白上。
    var lastContentPhase = context.contentStart || 0;
    var lastContentScroll = lastContentEdge <= 0 ? 0 : Math.floor(Math.max(0, lastContentEdge - 1 - lastContentPhase) / context.pageSize) * context.pageSize;
    var maxScroll = Math.min(maxAlignedScroll, lastContentScroll);
    // The real browser scroll endpoint can fall between two absolute
    // page-grid lines. BUG-2819: WebKit's scroll extent omits the multicol
    // body's inline-end padding (right margin / bottom margin + chrome inset),
    // so the last aligned page was out of reach and every chapter's last page
    // rendered shifted by that margin; the Apple paginated CSS now pads the
    // flow with one trailing column (_webKitPaginatedScrollEndCss), and this
    // branch is only a fallback. If content continues beyond the last
    // reachable aligned line, expose exactly that physical endpoint as one
    // partial terminal page. This keeps every intermediate turn on N*pitch,
    // makes the final turn finite, and never creates a blank page after the
    // actual last-content grid line. A <=1px physical shortfall retains the
    // aligned value so existing sub-pixel boundary normalization still works.
    if (maxScroll > context.physicalMaxScroll + 1) {
      maxScroll = context.physicalMaxScroll;
    }
    if (lastContentScroll > maxScroll + 1 &&
        context.physicalMaxScroll > maxScroll + 1) {
      maxScroll = Math.min(lastContentScroll, context.physicalMaxScroll);
    }
    var minScroll = Math.min(maxScroll, startAlignedScroll);
    progressStops.sort(function(a, b) { return a.scroll - b.scroll; });
    var metrics = {
      minScroll: minScroll,
      maxScroll: maxScroll,
      totalChars: totalChars,
      progressStops: progressStops
    };
    this.paginationMetrics = metrics;
    return metrics;
  },
  // 可选 atScroll：按任意页位置求进度（默认当前页）。getLastVisibleCharOffset 的降级
  // 路径传 `getPagePosition + pageSize`（下一页页首）得「下一页页首之前的累计字数」——
  // 节点粒度、随 scroll 单调，无需临时 setPagePosition 探测（那会触发 snap 监听 /
  // scroll 回传递归 / 闪屏）。
  calculateProgress: function(atScroll) {
    var metrics = this.paginationMetrics || this.buildPaginationMetrics();
    if (metrics.totalChars <= 0) return 0;
    return this.exploredCharsBeforeScroll(metrics, atScroll) / metrics.totalChars;
  },
  // progressStops 二分：起始边 <= scroll 的最后一个文本节点的累计字数（含该节点全部）。
  // atScroll 缺省取当前页位置。
  exploredCharsBeforeScroll: function(metrics, atScroll) {
    var scroll = atScroll === undefined
      ? this.getPagePosition(this.getScrollContext())
      : atScroll;
    var stops = metrics.progressStops;
    var low = 0;
    var high = stops.length - 1;
    var exploredChars = 0;
    while (low <= high) {
      var mid = Math.floor((low + high) / 2);
      if (stops[mid].scroll <= scroll) {
        exploredChars = stops[mid].exploredChars;
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }
    return exploredChars;
  },
  // BUG-1241：最后一页的 progress 是「视口首字符 / 全章字符」，只要末页还能显示多行，
  // 它就天然停在 0.99 左右，不能拿来判断用户是否真的到达章末。末页判定必须读分页
  // 几何的 terminal clamp；fushiProgressDetails 会在此为 true 时把持久进度钳到 100%。
  isAtEnd: function() {
    var metrics = this.paginationMetrics || this.buildPaginationMetrics();
    var context = this.getScrollContext();
    return this.getPagePosition(context) >= metrics.maxScroll - 1;
  },
  // 分页 caret 探点 → 章内学习单位偏移（与 getFirstVisibleCharOffset 同口径：
  // nodeStartOffsets 基址 + 节点内 isUnitEnd 累加）。返回 { offset, node, index }
  // （offset = caret 位置之前的单位数，node/index = caret 落点，供调用方判该字是否在页内），
  // caret 失败 / 落点无文本节点 / 基址缺失返 null——调用方各自决定降级路径。
  //
  // getFirstVisibleCharOffset 未改走本函数：它的函数体被 TODO-773 守卫
  // （paged_first_visible_scan_fallback_guard_test）钉成「三个失败出口各自回退
  // firstVisibleCharOffsetByScanPaged」+ BUG-2058 口径守卫（study_char_caliber_guard_test）
  // 要求其函数体内直接出现 fushiStudyUnits；两条守卫都要求逐出口内联，抽公共函数即红。
  _charOffsetAtPoint: function(x, y) {
    var range = document.caretRangeFromPoint(x, y);
    if (!range || !range.startContainer) return null;
    var target = range.startContainer;
    if (target.nodeType !== Node.TEXT_NODE) {
      var walker = this.createWalker(target);
      target = walker.nextNode();
      if (!target) return null;
    }
    var baseOffset = this.nodeStartOffsets.get(target);
    if (baseOffset === undefined) {
      this.buildNodeOffsets();
      baseOffset = this.nodeStartOffsets.get(target);
      if (baseOffset === undefined) return null;
    }
    var localChars = 0;
    var text = target.textContent;
    var limit = Math.min(range.startOffset, text.length);
    for (var i = 0; i < limit; i++) {
      var cp = text.codePointAt(i);
      if (window.fushiStudyUnits.isUnitEnd(text, i)) localChars++;
      if (cp > 0xFFFF) i++;
    }
    return { offset: baseOffset + localChars, node: target, index: limit };
  },
  // caret 落点处的那个字是否覆盖探点（沿行轴：横排 x 落在字的 [left,right]、竖排 y 落在
  // [top,bottom]）。caretRangeFromPoint 在探点落于字左半时返「该字之前」、落于右半 / 行尾
  // 空白时返「该字之后」；末字偏移只有前者需要 +1，后者 caret 之前的单位数已是半开区间 end。
  _caretCharCoversPoint: function(caret, x, y, vertical) {
    var text = caret.node.textContent;
    if (caret.index >= text.length) return false;
    var cp = text.codePointAt(caret.index);
    var range = document.createRange();
    range.setStart(caret.node, caret.index);
    range.setEnd(caret.node, caret.index + (cp > 0xFFFF ? 2 : 1));
    var rect = this.getRect(range);
    if (!rect || rect.width <= 0 || rect.height <= 0) return false;
    return vertical
      ? (rect.top <= y && rect.bottom >= y)
      : (rect.left <= x && rect.right >= x);
  },
  // 当前页可见字符区间的终点（半开 [start, end) 的 end，章内学习单位偏移）。统计口径
  // 「翻走即计 + 覆盖并集」需要每次进度采样同时拿到可见区间两端；起点是
  // getFirstVisibleCharOffset（页首角 caret），这里探页尾角：竖排（列自上而下堆叠、行自右
  // 向左）末字在左下 (paddingLeft+2, clientHeight−paddingBottom−2)，横排末字在右下
  // (clientWidth−paddingRight−2, clientHeight−paddingBottom−2)。探边量纲与
  // getFirstVisibleCharOffset 同为 body-relative（分页 body 填满视口左上角）。
  // 降级：caret 失败或算出 end <= start 时走 exploredCharsBeforeScroll(下一页页首)
  // （节点粒度、单调，见 calculateProgress 注释）；isAtEnd 时 end = 章总字数。
  // 不用 countCharsBeforeViewportPaged：它比较的轴（竖排 rect.left）与分页滚动轴（竖排 y）
  // 不一致，算不出页尾；不用临时 setPagePosition 探测再滚回（snap 监听 / scroll 回传递归 /
  // 闪屏）。startOffset 可选：调用方已算好 getFirstVisibleCharOffset 时传入免二次 caret。
  getLastVisibleCharOffset: function(startOffset) {
    var metrics = this.paginationMetrics || this.buildPaginationMetrics();
    if (metrics.totalChars <= 0) return -1;
    // BUG-2492：调用方传入的起点必须真的画在本页，否则 [起点, 页尾) 不是本页可见区间、
    // 不能交给统计（返 -1 → Dart 不 arrive）。先于 isAtEnd 短路：末页起点错时钳到
    // total 同样是整段幻象。
    if (typeof startOffset === 'number' && startOffset >= 0
        && !this.charOffsetOnCurrentPage(startOffset)) {
      return -1;
    }
    if (this.isAtEnd()) return metrics.totalChars;
    var context = this.getScrollContext();
    var start = (typeof startOffset === 'number' && startOffset >= 0)
      ? startOffset
      : this.getFirstVisibleCharOffset();
    var cs = getComputedStyle(document.body);
    var pl = parseFloat(cs.paddingLeft) || 0;
    var pr = parseFloat(cs.paddingRight) || 0;
    var pb = parseFloat(cs.paddingBottom) || 0;
    var x = context.vertical ? (pl + 2) : (document.body.clientWidth - pr - 2);
    var y = document.body.clientHeight - pb - 2;
    var end = -1;
    var caret = this._charOffsetAtPoint(x, y);
    if (caret) {
      end = caret.offset
        + (this._caretCharCoversPoint(caret, x, y, context.vertical) ? 1 : 0);
    }
    if (end <= start) {
      end = this.exploredCharsBeforeScroll(
        metrics, this.getPagePosition(context) + context.pageSize);
    }
    if (end > metrics.totalChars) end = metrics.totalChars;
    return end > start ? end : -1;
  },
  pageInfo: function() {
    // Page numbers only make sense once layout has settled. During a
    // pending re-anchor rAF (page-size / chrome-inset transition) getPagePosition
    // can read a transiently reset scrollTop (see setChromeInsets / HBK-REG-004),
    // which would mis-report page 1 — so bail and let the caller show no page.
    if (this._reanchorPending === true) return null;
    var context = this.getScrollContext();
    if (context.pageSize <= 0) return null;
    // Intermediate pages remain on the absolute pitch grid. The final page may
    // be a physical terminal clamp between grid lines when chrome insets make
    // the next full line unreachable, so count it as one additional page.
    var metrics = this.paginationMetrics || this.buildPaginationMetrics();
    var span = Math.max(0, metrics.maxScroll - metrics.minScroll);
    var alignedTurns = Math.floor((span + 1) / context.pageSize);
    var alignedEnd = metrics.minScroll + alignedTurns * context.pageSize;
    var hasPartialTerminal = metrics.maxScroll - alignedEnd > 1;
    var totalPages = alignedTurns + 1 + (hasPartialTerminal ? 1 : 0);
    var currentScroll = this.getPagePosition(context);
    var page = hasPartialTerminal && currentScroll >= metrics.maxScroll - 1
      ? totalPages
      : Math.round((currentScroll - metrics.minScroll) / context.pageSize) + 1;
    if (page < 1) page = 1;
    if (page > totalPages) page = totalPages;
    return { currentPage: page, totalPages: totalPages };
  },
  // 恢复/跳锚共用的落点 settle：等一帧让恢复滚动引发的 reflow 落定，重设落点 + 注册
  // snap 基线，然后立刻通知 Dart 恢复完成。
  //
  // TODO-perf（跨章）：旧实现是两层嵌套 setTimeout(16)——第一层重设落点（有实义），
  // **第二层什么都不做**，只为再拖 16ms 才通知 Dart。真机分段计时（[chapter-perf]
  // js.restore 35~44ms vs 跨章总耗时 ~96ms）显示这两层固定延迟占了跨章耗时的三分之一。
  // 落点在第一层回调里已被 setPagePosition 同步写死，Dart 收到通知后读到的就是这个
  // 位置；再空等一帧不改变任何落点，只是让「内容就绪」晚 16ms、遮罩多留一帧。故删掉
  // 第二层，保留第一层的「等一帧再重设」防 reflow 语义。
  _settleAndNotify: function(context, pos) {
    var self = this;
    setTimeout(function() {
      self.setPagePosition(context, pos);
      self.registerSnapScroll(pos);
      self.notifyRestoreComplete();
    }, 16);
  },
  restoreProgress: async function(progress) {
    await document.fonts.ready;
    var context = this.getScrollContext();
    // TODO-1349（续）：往前翻到章末(>=0.99)先强制 load 仍 lazy 的尾图（打破「尾图离屏永不
    // load → maxScroll 塌缩 → 停章首 → 尾图永不进视口」鸡生蛋，见 forceLoadPendingImages）；
    // 图 load 后 __imgReanchorProgress 回调按含真实尾图几何的 maxScroll 重锚。
    if (progress >= 0.99) this.forceLoadPendingImages();
    this.scrollToProgressPaged(context, progress);
    // BUG-1140 第二轮：登记本次 progress 落点供懒图 load 后语义重锚，**含中段**。
    // 旧实现只登记章首(0)/章末(>=0.99)，理由是「中段重锚到粗 progress 反更差」——那成立
    // 的前提是恢复时几何已终态（initialize 挂在 window.load，图片必已 decode），中段重锚
    // 只会把已经正确的位置白抖一下。把 loading="lazy" 写进 HTML 源码之后这个前提没了：
    // 恢复跑在图片 decode 之前，中段落点同样会被随后 load 的图顶走。progressStops 是字符域，
    // 按同一 progress 重算 = 落回同一批字符所在页，严格优于停在漂掉的 scroll 上。
    // 任一用户翻页(paginate)清资格。
    this.registerImageLateAnchor({progress: progress});
    var pos = this.getPagePosition(context);
    this._settleAndNotify(context, pos);
  },
  // BUG-162: 退出再进的精确恢复——按 section 内绝对字符偏移落到该字符真实所在页
  // （成熟 scrollToCharOffset 路径，是「存→取」不动点），替代粗粒度
  // restoreProgress/scrollToProgressPaged（alignToPage 取整落相邻页）。charOffset<0
  // （旧存档无精确锚）回退章首；调用方在 initialCharOffset<0 时改走 restoreProgress。
  restoreToCharOffset: async function(charOffset) {
    await document.fonts.ready;
    var context = this.getScrollContext();
    // BUG-492 (TODO-1053 Bug A) 越界兜底：旧脏收藏 charAnchor 属于相邻错章，恢复加载
    // 本章后可能超本章字符总数 → scrollToCharOffset 静默 no-op 停在页 1 附近。越界回退
    // 章首（scrollToProgressPaged 0），比静默停错位可诊断。范围内走精确定位，行为不变。
    // TODO-1229 (BUG-594)：charOffset 0 == 章节绝对起点（0 字已读）。若本章以插图页开篇，
    // 首个文本字符位于插图之后的下一页，而 scrollToCharOffset 只走文本节点（createWalker）
    // 会落到「首个文本页」跳过插图页。章首语义必须与 restoreProgress(0) 一致——scrollToProgressPaged(0)
    // 走 minScroll，buildPaginationMetrics 的 firstContentEdge 已含前导 block 图，落点即插图页。
    // 故 <=0 一律走 minScroll，绝不越过章首插图（跨章 renav / _syncPageSize 宽变重导以 charOffset 0
    // 重锚时不再跳页）。>0 的精确锚行为不变。
    if (charOffset <= 0 || !this.charOffsetInRange(charOffset)) {
      this.scrollToProgressPaged(context, 0);
      this.registerImageLateAnchor({progress: 0});
    } else {
      this.scrollToCharOffset(charOffset);
      // BUG-1140 第二轮：字符锚是**布局无关**的真相，迟到图片 load 后按同一个 charOffset
      // 重算即回到「图片本来就在」的落点。旧实现在这里什么都不登记 → 精确锚恢复（退出重进 /
      // 收藏跳转 / 有声书 seek 落中段）在图文混排章完全裸奔，位置漂了还会被落库。
      this.registerImageLateAnchor({charOffset: charOffset});
    }
    var pos = this.getPagePosition(context);
    this._settleAndNotify(context, pos);
  },
  // fragment 落点的纯几何对齐（jumpToFragment 与迟到图片重锚共用同一份换算，避免
  // 重锚复制一份会漂开的算法）。命中返 true 并已 setPagePosition，未命中返 false。
  alignToFragmentTarget: function(fragment) {
    var context = this.getScrollContext();
    var rawFragment = (fragment || '').trim();
    var target = rawFragment && (document.getElementById(rawFragment) || document.getElementsByName(rawFragment)[0]);
    if (context.pageSize <= 0 || !target) return false;
    var rect = this.getRect(target);
    var currentScroll = this.getPagePosition(context);
    var anchor = (context.vertical ? rect.top : rect.left) + currentScroll;
    this.setPagePosition(context, this.alignToPage(context, anchor));
    return true;
  },
  jumpToFragment: async function(fragment) {
    await document.fonts.ready;
    var context = this.getScrollContext();
    if (!this.alignToFragmentTarget(fragment)) {
      this.clearImageLateAnchor();
      this.registerSnapScroll(this.getPagePosition(context));
      this.notifyRestoreComplete();
      return false;
    }
    // BUG-1140 第二轮：目录/内链跳转同样在图片 decode 之前落点，登记 fragment 锚让迟到
    // 图片 load 后按同一个目标元素重新对齐。
    this.registerImageLateAnchor({fragment: fragment});
    this._settleAndNotify(context, this.getPagePosition(context));
    return true;
  },
  paginate: function(direction) {
    // TODO-1229 案B：用户翻页即放弃图片 late-load 重锚资格——避免把用户已翻走的位置
    // 拽回恢复锚（重锚只在恢复落地后、用户尚未翻页的窗口内有效）。
    this.clearImageLateAnchor();
    var context = this.getScrollContext();
    if (context.pageSize <= 0) return "limit";
    var currentScroll = this.getPagePosition(context);
    var metrics = this.paginationMetrics || this.buildPaginationMetrics();
    var minAlignedScroll = metrics.minScroll;
    var maxAlignedScroll = metrics.maxScroll;
    var pitch = context.pageSize;
    var stepScroll = this.pageStepPosition(currentScroll, pitch);
    var pageCoordinate = stepScroll / pitch;
    var nearestPage = Math.round(pageCoordinate);
    if (Math.abs(pageCoordinate - nearestPage) * pitch <= 1) {
      pageCoordinate = nearestPage;
    }
    // BUG-169：从可能未对齐的 currentScroll 出发先算「严格相邻整页边界」再 clamp，
    // 是否真翻页由 clamp 后的 target 与当前位置比较得出（共用同一 target，首/末页
    // 判定与步长计算一致）。pageCoordinate 延续 1px 页边界契约先规范化近整数商；
    // forward 取 floor(pageCoordinate)+1、backward 取 ceil(pageCoordinate)-1：
    // 对齐时与「当前页 ±1」等价、错位时永远只走一页，
    // 不会像旧 round((cur±pitch)/pitch) 那样把当前页算成相邻页跳 2 页。1px 内的
    // WebView sub-pixel 漂移先经 pageStepPosition 归一化到最近整页，避免连续 backward
    // 把 17955.33 → 17955 误判成 limit。与 Dart 影子 resolvePaginateStepForTesting
    // 同算法。
    //
    // TODO-729：单一量纲（pageStep == 真实列周期 == maxScroll 减项）后，metrics 的
    // max/minScroll 与对齐量同源、永不被低估，安卓式「翻不动即 return "limit" 跨章」
    // 是结构性正确的——不再需要旧的二次 settle 复核（那是双量纲下 maxScroll 低估的
    // 补救，根因消除后即多余）。安卓 reader-paginated.js paginate(814-840) 即直接
    // return "limit"。
    if (direction === "forward") {
      var targetForward = (Math.floor(pageCoordinate) + 1) * pitch;
      if (targetForward > maxAlignedScroll) targetForward = maxAlignedScroll;
      if (targetForward < minAlignedScroll) targetForward = minAlignedScroll;
      if (targetForward <= stepScroll + 1) return "limit";
      this.setPagePosition(context, targetForward);
      return "scrolled";
    } else {
      var targetBack = (Math.ceil(pageCoordinate) - 1) * pitch;
      if (targetBack < minAlignedScroll) targetBack = minAlignedScroll;
      if (targetBack > maxAlignedScroll) targetBack = maxAlignedScroll;
      if (targetBack >= stepScroll - 1) return "limit";
      this.setPagePosition(context, targetBack);
      return "scrolled";
    }
  },
  getFirstVisibleCharOffset: function() {
    var context = this.getScrollContext();
    var cs = getComputedStyle(document.body);
    var pt = parseFloat(cs.paddingTop) || 0;
    var pl = parseFloat(cs.paddingLeft) || 0;
    var pr = parseFloat(cs.paddingRight) || 0;
    var x = context.vertical ? (document.body.clientWidth - pr - 2) : (pl + 2);
    var y = pt + 2;
    var range = document.caretRangeFromPoint(x, y);
    // TODO-773 P0：竖排切字号/字体/主题后页顶落 ruby/图片/折叠盒 → caretRangeFromPoint 返
    // null → 旧实现裸 return -1 → beginStyleReanchor 返 -1 → Dart 跳过 commit → CSS 已换但
    // scrollTop 停残值不滚回 → 文字漂移。改走 firstVisibleCharOffsetByScanPaged 全文累加兜底
    // （body-relative 首边，与分页 caret 探边同量纲；不裸抄连续版 window 量纲的
    // firstVisibleCharOffsetByScan）。连续版三失败点早有同形兜底。
    if (!range || !range.startContainer) return this.firstVisibleCharOffsetByScanPaged();
    var target = range.startContainer;
    // BUG-2492：探点落在元素上（插图 `<p><img>` / 空行 / 章容器 `<div>` / body）时，
    // caret 的 startOffset 是子节点下标不是字符下标；旧写法取该元素**子树首个文本节点**
    // 再拿子节点下标当字符数，落在章容器上会算出章首附近的假偏移。几何扫描兜底按翻页
    // 轴数出前页字数，才是这一页真正的首字。
    if (target.nodeType !== Node.TEXT_NODE) return this.firstVisibleCharOffsetByScanPaged();
    var baseOffset = this.nodeStartOffsets.get(target);
    if (baseOffset === undefined) {
      this.buildNodeOffsets();
      baseOffset = this.nodeStartOffsets.get(target);
      if (baseOffset === undefined) return this.firstVisibleCharOffsetByScanPaged();
    }
    var localChars = 0;
    var text = target.textContent;
    var limit = Math.min(range.startOffset, text.length);
    for (var i = 0; i < limit; i++) {
      var cp = text.codePointAt(i);
      if (window.fushiStudyUnits.isUnitEnd(text, i)) localChars++;
      if (cp > 0xFFFF) i++;
    }
    return baseOffset + localChars;
  },
  scrollToCharOffset: function(charOffset, hintScroll) {
    // TODO-1229 (BUG-594 第 6 次复诉)：charOffset<=0 == 章首区（fvco 归 0：可能是「用户在前导
    // 插图页」也可能是「用户在首文本页、char0 正在本页顶」——两者语义不同，唯有 hint 能判开）。
    // 本函数只走文本节点（createWalker=SHOW_TEXT），下方 >0 逻辑对 charOffset 0 会算出**首个文本
    // 字符所在页**（前导插图之后）→ 重锚越过插图。旧的 ±1 page-stable hint 只在「前导内容恰占 1
    // 页」时兜住（charPage 与 origPage 差 1）；前导跨 ≥2 页（如扉页图+标题页、多张图）时差 ≥2、
    // ±1 失效 → 越过整段前导跳到首文本（headless 证 2 张前导图 jumped=2）。根治：<=0 时**保住用户
    // 当前页**（有 hint 走 origPage；无 hint 落 minScroll=章首含前导图），绝不按字符页跳——重锚本就
    // 该保位，char0 的文本页不是用户所在页。>0 精确锚 + ±1 hint 逻辑不变。裸落章首会把「在首文本
    // 页」的用户弹回插图页，故必须走 origPage（headless midChapter 守卫）。连续版无 hint，见那里
    // 的 <=0→scrollToChapterStart 归一。
    if (charOffset <= 0) {
      var ctx0 = this.getScrollContext();
      if (ctx0.pageSize > 0 && hintScroll !== undefined) {
        this.setPagePosition(
          ctx0, Math.round(hintScroll / ctx0.pageSize) * ctx0.pageSize);
      } else {
        this.setPagePosition(ctx0, this.contentFirstPageScroll(ctx0));
      }
      return;
    }
    var walker = this.createWalker();
    var node;
    var runningOffset = 0;
    var targetNode = null;
    var remaining = 0;
    while (node = walker.nextNode()) {
      var nodeChars = this.countChars(node.textContent);
      if (runningOffset + nodeChars > charOffset) {
        targetNode = node;
        remaining = charOffset - runningOffset;
        break;
      }
      runningOffset += nodeChars;
    }
    if (!targetNode) return;
    var charIdx = 0;
    var textOffset = 0;
    var text = targetNode.textContent;
    for (var i = 0; i < text.length && charIdx < remaining; i++) {
      var cp = text.codePointAt(i);
      if (window.fushiStudyUnits.isUnitEnd(text, i)) charIdx++;
      if (cp > 0xFFFF) i++;
      textOffset = i + 1;
    }
    var range = document.createRange();
    range.setStart(targetNode, Math.min(textOffset, text.length));
    range.collapse(true);
    var rect = this.characterAnchorRect(range);
    if (!rect) return;
    var context = this.getScrollContext();
    var scrollOffset = context.vertical
      ? (context.scrollEl.scrollTop + rect.top)
      : (context.scrollEl.scrollLeft + rect.left);
    // BUG-2325：字符落页走同一个列号函数 alignToPage（减相位 + gap 下侧容差）。旧的裸
    // floor(scrollOffset/pageSize) 既漏了相位 contentStart，也吃不住上面那条每页累积的
    // 网格漂移：精确锚恢复 / 样式重锚 commit 落到「页首字」时同样会退回前一列。
    var charPage = Math.round(this.alignToPage(context, scrollOffset) / context.pageSize);
    var aligned;
    if (hintScroll !== undefined) {
      // Page-stable hint: if the target char is within one page of where we
      // started, keep the original page so a ±1-column repagination doesn't
      // visibly shift the reader; otherwise jump to the char's actual page.
      var origPage = Math.round(hintScroll / context.pageSize);
      if (Math.abs(charPage - origPage) <= 1) {
        aligned = origPage * context.pageSize;
        // BUG-2205：±1 保原页只该兜「页边界舍入抖动」（同一布局下锚字恰在页首、collapsed
        // range 被算到上一列末）。缩字号 / 减边距 / 减行高 / 挤压态藏底栏这类**让每页
        // 装更多字**的重排会把锚字真的推到前一页：仍保原页 = 新页首字越过锚字 = 用户
        // 丢掉锚字到新页首这段正文（缩一步丢一页），且随后的进度刷新把这段当「新读到」
        // 计进统计（分页 progress 按节点粒度、水位只升不降 → 单向棘轮，反复缩放每次多计
        // 一页）。判据不用像素容差（横排末行 collapsed range 的 x 可落在整列任意处），
        // 而是落页后**实测页首字**：原页页首字 > 锚字即锚已丢，改落锚字所在页。
        // 放大字号（charPage > origPage）保原页只会让页首字 ≤ 锚字（多看到已读的几行），
        // 不丢正文、不推进度，维持原行为。
        if (charPage < origPage) {
          this.setPagePosition(context, aligned);
          var firstOnOrig = this.getFirstVisibleCharOffset();
          if (firstOnOrig > charOffset) aligned = charPage * context.pageSize;
        }
      } else {
        aligned = charPage * context.pageSize;
      }
    } else {
      aligned = charPage * context.pageSize;
    }
    this.setPagePosition(context, aligned);
  },
  setChromeInsets: function(topPx, bottomPx) {
    // BUG-2652：inset 与图片盒都没变 = 没有重排可补偿，见 _chromeInsetsUnchanged。
    if (this._chromeInsetsUnchanged(topPx, bottomPx)) return;
    // Re-anchoring (after a chrome-inset OR a page-size change) is serialised
    // through one shared in-flight flag, _reanchorPending. A layout change
    // transiently resets scrollTop to 0; if a re-anchor rAF is already pending
    // (from this handler or updatePageSize), reading a fresh char offset now
    // would sample that reset as the chapter start and snap there. So when one
    // is in flight we only apply the new CSS and let the pending rAF restore
    // position once the layout settles. This serialises without masking via a
    // delay, and covers both rapid toggles and toggle/resize interleaving.
    // (HBK-REG-004)
    var inFlight = this._reanchorPending === true;
    var charOffset = inFlight ? -1 : this.getFirstVisibleCharOffset();
    var scrollBefore = inFlight ? 0 : this.getPagePosition(this.getScrollContext());
    document.documentElement.style.setProperty('--chrome-top-inset', topPx + 'px');
    document.documentElement.style.setProperty('--chrome-bottom-inset', bottomPx + 'px');
    // Chrome insets participate in the paginated column-width/pageStep CSS.
    // Cached min/max bounds were built against the previous pitch; retaining
    // them can stop pagination before the final columns after the bottom bar
    // changes. Invalidate even when a re-anchor is already in flight.
    this.paginationMetrics = null;
    // The image max box (--fushi-image-max-width/height) is the body content
    // box, which the chrome insets just shrank/grew. initialize() sized it
    // against the initial insets (before the bottom bar / header occupied
    // layout), and only style/page-size re-anchors re-derived it — so after the
    // first-load inset re-send (or a squeeze-mode bar toggle) a full-page
    // illustration stayed one chrome height taller than the column and Blink
    // sliced the monolithic <img> across three columns: a strip at the bottom
    // of the previous page, the middle on its own page, a strip at the top of
    // the next. Re-derive it here, before the re-anchor samples the new layout.
    this._resetImageMaxVars();
    if (inFlight || charOffset < 0) return;
    this._setReanchorPending(true);
    var self = this;
    this._reanchorFrame(function() {
      try {
        self.scrollToCharOffset(charOffset, scrollBefore);
      } finally {
        self._setReanchorPending(false);
      }
    });
  },
  // TODO-736 B-1 续（分页缺席根因修复，BUG-849）：样式变更两阶段重锚在分页 shell 曾整体
  // 缺席，导致 beginStyleReanchorInvocation 恒走 `:-1` 兜底、CSS 从不换 → 分页模式下改
  // 字号/边距/主题等纯 CSS 设置不实时生效、必须重开书。补齐与连续 shell 同语义的三方法，
  // 用分页原生 hint 原语：reflow 前记 getPagePosition(getScrollContext())（分页 ±1 列保持
  // 原页，与 setChromeInsets 的成熟重锚同源），配分页 2 参 scrollToCharOffset(off, hint)。
  // 连续 shell 的对应版本另用 _readContinuousScroll（内容轴 raw scroll），各自 this 解析。
  _resetImageMaxVars: function() {
    var box = this._imageMaxBox();
    document.documentElement.style.setProperty('--fushi-image-max-width', box.w + 'px');
    document.documentElement.style.setProperty('--fushi-image-max-height', box.h + 'px');
  },
  beginStyleReanchor: function(styleEl, css) {
    if (!this.didInitialize) { if (styleEl) styleEl.textContent = css; return -1; }
    if (this._reanchorPending === true) {
      if (styleEl) styleEl.textContent = css;
      this._resetImageMaxVars();
      return -1;
    }
    var charOffset = this.getFirstVisibleCharOffset();
    // reflow 前记页内位置作 hint：分页 ±1 列时 scrollToCharOffset 保持原页
    // （getPagePosition 是分页专属；连续 shell 版改用内容轴 scroll）。
    var hint = this.getPagePosition(this.getScrollContext());
    if (styleEl) styleEl.textContent = css;
    if (this.paginationMetrics !== undefined) this.paginationMetrics = null;
    this._resetImageMaxVars();
    if (charOffset < 0) return -1;
    this._setReanchorPending(true);
    this._styleReanchorOffset = charOffset;
    this._styleReanchorHint = hint;
    return charOffset;
  },
  commitStyleReanchor: function() {
    var off = this._styleReanchorOffset;
    if (off === undefined || off < 0) return false;
    var hint = this._styleReanchorHint;
    try {
      this.scrollToCharOffset(off, hint);
    } finally {
      this._styleReanchorOffset = undefined;
      this._styleReanchorHint = undefined;
      this._setReanchorPending(false);
    }
    return true;
  }
};
window.fushiReader.initialize = function() {
  if (window.fushiReader.didInitialize) return;
  window.fushiReader.didInitialize = true;
  this.perfMark('initStart');
  document.documentElement.style.setProperty('--chrome-top-inset', C.chromeTopInset + 'px');
  document.documentElement.style.setProperty('--chrome-bottom-inset', C.chromeBottomInset + 'px');
$_sharedInitViewport
  // TODO-736 B-1：存图片宽比值供 _resetImageMaxVars 读（_sharedJs 不插值，见那里注释）。
  this._imageWidthRatio = $imageWidthRatio;
  var dartW = C.dartPageWidth;
  var dartH = C.dartPageHeight;
  var pageWidth = dartW || window.innerWidth;
  // TODO-734：viewportHeight = 纯视口高 V（不加 bottomOverlap）。pageHeight = V + O
  // 仍供图片虚高/scrollHeight 用。竖排列高几何（CSS column-width + JS contentBox）
  // 成对只用 V，杜绝列底边漏出 (O−F) 进底栏。
  var viewportHeight = dartH || window.innerHeight;
  var pageHeight = viewportHeight + $bottomOverlapPx;
  window.__fushiApplyReaderMargins(pageWidth, viewportHeight);
  console.log('[FushiInit] dartW=' + dartW + ' dartH=' + dartH
    + ' innerW=' + window.innerWidth + ' innerH=' + window.innerHeight
    + ' usedW=' + pageWidth + ' usedH=' + pageHeight + ' viewportH=' + viewportHeight);
  document.documentElement.style.setProperty('--page-height', pageHeight + 'px');
  document.documentElement.style.setProperty('--reader-viewport-height', viewportHeight + 'px');
  document.documentElement.style.setProperty('--page-width', pageWidth + 'px');
  var __imgBox = this._imageMaxBox();
  document.documentElement.style.setProperty('--fushi-image-max-width', __imgBox.w + 'px');
  document.documentElement.style.setProperty('--fushi-image-max-height', __imgBox.h + 'px');
  window.fushiReader.pageHeight = pageHeight;
  window.fushiReader.viewportHeight = viewportHeight;
  window.fushiReader.pageWidth = pageWidth;
$initImages
  var spacer = document.createElement('div');
  spacer.style.height = '$spacerHeight';
  spacer.style.width = '$spacerWidth';
  spacer.style.display = 'block';
  spacer.style.breakInside = 'avoid';
  document.body.appendChild(spacer);
  this.perfMark('initSyncDone');
  Promise.all(imagePromises).then(function() {
    window.fushiReader.perfMark('imagesReady');
    window.fushiReader.buildNodeOffsets();
    window.fushiReader.perfMark('offsetsBuilt');
    // TODO-627：图片可能在初次分页 metrics 建好之后才 decode 完。此前
    // buildPaginationMetrics 枚举到的 <img> 还是 0x0（getBoundingClientRect 全 0），
    // metrics.maxScroll 漏掉图片所占的列 → 偏小 → paginate 在图片页前就误判到末页
    // → _handlePageTurnLimit 跳过插画页跨章。图片 decode 完成后必须失效缓存的
    // paginationMetrics，强制下次 paginate 用纳入图片真实尺寸的几何重建（与
    // updatePageSize / reanchorAfterStyleChange 的 metrics 失效一致）。
    if (window.fushiReader.paginationMetrics !== undefined) {
      window.fushiReader.paginationMetrics = null;
    }
    $sentenceAudioInit
    $initialRestoreScript
  });
};
window.fushiReader.updatePageSize = function(cssWidth, cssHeight) {
  // TODO-734：newViewportHeight = 纯 V（Math.round(cssHeight)），newHeight = V + O。
  var newViewportHeight = Math.round(cssHeight);
  var newHeight = newViewportHeight + $bottomOverlapPx;
  var newWidth = Math.round(cssWidth);
  if (newHeight === this.pageHeight && newWidth === this.pageWidth) return;
  // Shares the _reanchorPending flag with setChromeInsets (see there). If a
  // re-anchor rAF is already pending, reading calculateProgress now would read a
  // transiently reset scrollTop as progress 0 and snap to the chapter start, so
  // we only update the page metrics and let the pending rAF restore position.
  var inFlight = this._reanchorPending === true;
  var progress = inFlight ? 0 : this.calculateProgress();
  document.documentElement.style.setProperty('--page-height', newHeight + 'px');
  document.documentElement.style.setProperty('--reader-viewport-height', newViewportHeight + 'px');
  document.documentElement.style.setProperty('--page-width', newWidth + 'px');
  window.__fushiApplyReaderMargins(newWidth, newViewportHeight);
  var __imgBox = this._imageMaxBox();
  document.documentElement.style.setProperty('--fushi-image-max-width', __imgBox.w + 'px');
  document.documentElement.style.setProperty('--fushi-image-max-height', __imgBox.h + 'px');
  this.pageHeight = newHeight;
  this.viewportHeight = newViewportHeight;
  this.pageWidth = newWidth;
  this.paginationMetrics = null;
  if (inFlight) return;
  this._setReanchorPending(true);
  var self = this;
  this._reanchorFrame(function() {
    try {
      self.scrollToProgressPaged(self.getScrollContext(), progress);
    } finally {
      self._setReanchorPending(false);
    }
  });
};
$_sharedInitBoot
};
</script>''';
  }

  // ── Continuous mode ────────────────────────────────────────────────

  /// 连续 shell 的静态源码（零 per-nav 插值，全部参数改由运行时 `C` 读取）。
  static String continuousShellSource() {
    // BUG-162: 同分页——优先精确字符偏移恢复，旧存档回退分数。BUG-461：收藏句跳转带句尾
    // 偏移（initialCharOffsetEnd>句首）时透传给 restoreToCharOffset 做整句区间对齐。
    // BUG-1140 第二阶段①：判据整体搬到运行时，逐条对齐旧的 Dart 三元式。
    const String initialRestoreScript = _continuousInitialRestoreJs;
    const String sentenceAudioInit = _sharedSentenceAudioInitJs;

    const double imageWidthRatio = ReaderLayoutDefaults.imageWidthViewportRatio;

    final String initImages = _sharedInitImages();

    return '''<script>
window.__fushiShells.continuous = function(C) {
window.__fushiCssHighlightsSupported = !!(window.CSS && CSS.highlights && window.Highlight);
window.fushiReader = {
  // 跨章分段计时总开关（Dart [ReaderChapterPerfTrace.enabled] → C.perfTraceEnabled）。
  // false = 生产路径，perfMark / perfSnapshot 零开销。
  _perfOn: C.perfTraceEnabled === true,
  // TODO-734：连续模式不用竖排分页几何（无 column），故 initialize/updatePageSize
  // 不注入 --reader-viewport-height、getScrollContext 也不引用它。但属性仍声明 0
  // （补点2 防 stale）：两个 fushiReader 实例属性表保持对齐，避免误读 undefined。
  viewportHeight: 0,
  // BUG-2013：竖排连续模式是**横向**滚动，桌面 WebView2 的水平滚动条是占位式的
  // （移动端是不占位的 overlay，所以这条只在桌面复现），它从视口底部吃掉约 15px。
  // window.innerHeight 与 Dart 传来的 MediaQuery 高度（dartPageHeight /
  // updatePageSize 的 cssHeight）都是**视口外框**高度、不扣这条；而 body 是
  // box-sizing: border-box + height: var(--fushi-continuous-height)
  // （见 reader_content_styles.dart 的 _continuousLayoutCss 竖排分支），于是 body
  // 最底部那 15px 落在滚动条之下，末行文字被裁掉大半——用户截图里每列底部的字
  // 只剩上半个，正是这个。documentElement.clientHeight 是唯一扣掉滚动条的
  // **可视内容**高度。
  //
  // 实测（Chromium 1200x800 + 竖排长文）：innerHeight=705 / clientHeight=690 /
  // 水平滚动条 15px。喂 705 → 文字底 705 > 可视 690（溢出）；改喂 690 → 文字底
  // 690（不溢出）；再量一轮仍 690（不震荡）；内容短到没有滚动条时 clientHeight
  // 回到 705（不误缩）。
  //
  // 不震荡的原因：竖排水平滚动条的有无只由内容宽度（列数）决定，与 body 高度无
  // 关；高度调小只让每列变短、列数变多，滚动条照样在，clientHeight 保持稳定。
  //
  // 刻意**不**改 __fushiApplyReaderMargins / _contH 的入参：那两个要的就是视口外
  // 框高度。本 bug 的根因正是「视口外框高度」和「可视内容高度」被当成同一个数，
  // 修法是把这两个概念分开，而不是把另一处也一起改掉。
  //
  // 夹在 fallback（视口外框高度）以内：可视内容高度按定义不可能超过外框高度。这
  // 不是「保险起见」的兜底，而是这个量的**定义域**——一旦超出就说明读到的不是本
  // 次布局的值：
  //   · iOS：连续 shell 的 initialize 里，共用的 viewport meta 重写（见
  //     sharedInitViewportJs）刚删掉并重建 meta[name=viewport]，隔 5 条语句就读
  //     clientHeight。BUG-1688 实测 WKWebView 在这次重写生效前按
  //     默认 980 CSS px 布局（innerHeight=1743，而 Dart 权威值 667）。若 WebKit 的
  //     重排不是同任务同步生效，这里会量到 1743 → 竖排 body 高度爆到 2.6 倍。而
  //     iOS 是**不占位**的 overlay 滚动条，本修复在 iOS 上收益为零——不能让一个
  //     零收益的平台替桌面的修复背回归。
  //   · quirks mode：章节文档是**书自己给的** XHTML，Fushi 只做净化并注入 style、
  //     全程不补 doctype（webview.part.dart:345 _buildSanitizedChapterHtmlBytes），
  //     而下发的 Content-Type 恒为 text/html（同文件:206-210）⇒ 走 HTML5 解析、
  //     由 doctype 定模式。书没写 doctype 就落 quirks，clientHeight 退化成 html
  //     自身 padding box 高度，不再是视口量。
  // 桌面竖排的正常值 690 <= 705，夹子不改变本 bug 的修复效果。
  _visibleViewportHeight: function(fallback) {
    var visible = document.documentElement.clientHeight;
    return (visible && visible > 0 && visible <= fallback) ? visible : fallback;
  },
  // `--fushi-continuous-height` 的**唯一**写入点（守卫钉死：全 shell 只此一处
  // setProperty 该变量）。调用方三个：initialize / updatePageSize / beginStyleReanchor。
  //
  // 为什么 beginStyleReanchor 也必须写：BUG-2013 之前这个变量只由**视口外框高度**
  // 决定，而外框高度只在 resize 时变，所以两处赋值就够。改取**可视高度**后它变成
  // 内容相关量——水平滚动条的有无由内容宽度（列数）决定，而改字号正是改列数。于是
  // 「首屏内容短 → 无滚动条 → 写 705」的书，用户放大字号后滚动条出现、变量仍是
  // 705，末行照旧被裁，要等下一次 resize 才自愈。写入点必须跟上这个**新出现的**
  // 失效源，否则修复恰好在最常见的「改字号」路径上漏掉。
  _applyContinuousHeight: function(fallback) {
    document.documentElement.style.setProperty(
        '--fushi-continuous-height', this._visibleViewportHeight(fallback) + 'px');
  },
$_sharedJs
  scrollToChapterStart: function() {
    var root = document.scrollingElement || document.documentElement;
    window.scrollTo(0, 0);
    root.scrollTop = 0;
    root.scrollLeft = 0;
    document.documentElement.scrollTop = 0;
    document.documentElement.scrollLeft = 0;
    document.body.scrollTop = 0;
    document.body.scrollLeft = 0;
  },
  // TODO-1349：连续模式「章末」落点——把正文最后一个可见内容元素对齐到滚动轴末端。
  // 往前翻上一章走 restoreProgress(0.99)（章尾语义，与分页 contentLastPageScroll=maxScroll
  // 对称）。但 scrollToProgressContinuous 只走文本节点（findNodeAtProgress）：纯图片/封面章
  // 无文本节点 → 返 null → 不滚动 → 停在章首（=封面图），而非封面章节的最后部分（用户报
  // 「从目录往前翻会去到封面」的根因）。这里用最后一个可见内容元素 scrollIntoView(block:'end')：
  // block/inline 轴由 writing-mode 自动映射（横排 block=竖直落到内容底；竖排 vertical-rl
  // block=横向 RTL 落到最左列 = 章末），故横排/竖排统一，且天然含尾部插图。无可见内容元素时
  // 兜底滚到滚动轴物理末端（横排底、竖排 rl 最左）。
  scrollToChapterEnd: function() {
    var body = document.body;
    var last = body.lastElementChild;
    while (last) {
      var tag = last.tagName;
      var rect = last.getBoundingClientRect();
      var visible = rect.width > 0 || rect.height > 0;
      if (tag !== 'SCRIPT' && tag !== 'STYLE' && tag !== 'TEMPLATE' && visible) {
        break;
      }
      last = last.previousElementSibling;
    }
    if (last) {
      last.scrollIntoView({block: 'end', inline: 'nearest', behavior: 'instant'});
    } else {
      this._writeContinuousScroll(this.isVertical() ? -1e9 : 1e9);
    }
  },
  // TODO-1229 (BUG-594 第 6 次复诉·续)：连续模式重锚保位读/写。连续无分页的
  // getScrollContext/getPagePosition（那是分页专属），滚动位就是内容轴 raw scroll：横排
  // 走 scrollTop、竖排走 window.scrollX（与 paginate 的轴判据同源）。重锚在 charOffset<=0
  // （章首区，fvco 二义）时用它保住用户当前滚动位，不弹回章顶前导。
  _readContinuousScroll: function() {
    var root = document.scrollingElement || document.documentElement;
    return this.isVertical() ? window.scrollX : root.scrollTop;
  },
  _writeContinuousScroll: function(pos) {
    if (this.isVertical()) {
      window.scrollTo(pos, 0);
    } else {
      var root = document.scrollingElement || document.documentElement;
      root.scrollTop = pos;
      document.documentElement.scrollTop = pos;
      document.body.scrollTop = pos;
    }
  },
  // TODO-825：连续模式有声书逐句高亮跟随滚动用 behavior:'smooth' 平滑动画（用户要求恢复
  // 动画，禁止砍成 instant——见已撤的 TODO-803）。「滚动结束闪一下屏幕」的根因不是 smooth
  // 动画本身，而是这条**程序化跟随滚动没武装 settle 保护窗**：cue reveal 经 Dart
  // AudiobookBridge.highlight(reveal:true) 触发本函数，但当年只有 恢复/缩放/换样式 三条
  // reanchor commit 武装了 B-3 250ms settle 窗（eaa151581）→ smooth 动画落定那帧 scroll 回弹
  // 回 Dart 触发 _refreshProgress setState 重绘 + 可能命中 TODO-798 非自愿归零判据被反手二次
  // 滚动 = 闪屏。TODO-825 的根因修是在 Dart 跟随滚动调用点（audiobook.part.dart _onCueChanged
  // reveal 分支）武装 _reanchorClearedAt 让 B-3 窗覆盖这条平滑滚动的落定尾沿，从源头消除二次
  // 反弹——动画保留，闪烁靠 settle 窗治住。分页模式 reveal（scrollToRange）走另一路不受影响。
  scrollToTarget: function(target) {
    // BUG-2744：跟读 / 跨图 / 搜索揭示的目标替换恢复锚，迟到懒图 load 后按它重对齐，
    // 而不是把视口拽回开章落点（与分页 scrollToRange 同一不变量）。
    this.registerImageLateAnchor({target: target});
    var rect = this.getRect(target);
    var margin = 0.15;
    var wm = window.getComputedStyle(document.body).writingMode;
    // 墨水屏模式（--fushi-reader-eink-mode: 1，由 ReaderContentStyles 的 eink 覆盖块
    // 注入）：跟随滚动退化为瞬时跳——慢刷新屏上 smooth 补间是一整段残影。普通模式
    // 保持 TODO-825 的 smooth（用户点名要动画，settle 窗治闪屏），零行为变化。
    var behavior = (window.getComputedStyle(document.documentElement)
      .getPropertyValue('--fushi-reader-eink-mode').trim() === '1') ? 'auto' : 'smooth';
    // BUG-2466：跨过一整个视口以上的「跟随」不是跟、是跳（重开书音频在几十页外 /
    // 跨章落地 / 手动 seek）——smooth 补间会连续多帧滚过中间所有页，settle 窗（250ms）
    // 关了之后每次 scroll 回传都把途中视口 arrive 进阅读账本，那些从没读过的页全部
    // 入账 = 字数虚增、字/时爆表。一个视口之内（逐句跟读翻到下一屏）仍走 behavior
    // 变量的 smooth（TODO-825 用户点名要的动画一根毛不动），只有跳才瞬时落地。
    var followBehavior = function(delta, viewport) {
      return Math.abs(delta) > viewport ? 'auto' : behavior;
    };
    if (wm.startsWith('vertical')) {
      var vw = window.innerWidth;
      var safe = vw * margin;
      if (rect.left >= safe && rect.right <= vw - safe) return false;
      var dx = (wm === 'vertical-rl') ? rect.right - (vw - safe) : rect.left - safe;
      window.scrollBy({left: dx, behavior: followBehavior(dx, vw)});
    } else {
      var vh = window.innerHeight;
      var safe = vh * margin;
      if (rect.top >= safe && rect.bottom <= vh - safe) return false;
      var dy = rect.top - safe;
      window.scrollBy({top: dy, behavior: followBehavior(dy, vh)});
    }
    return true;
  },
  revealElement: function(element) {
    return this.scrollToTarget(element);
  },
  // BUG-2903：章内文本索引——按文档序列出有可匹配字符的文本节点、各自的章内起始字数与
  // 章总字数。滚动中的进度回报每帧都要「视口边之前有多少字」（onReaderScroll →
  // fushiProgressDetails），旧实现每次对整章做三遍 walk（总字数 / calculateProgress /
  // getLastVisibleCharOffset），后两遍还逐节点 getClientRects——6000 个文本节点的长章
  // 桌面 Chrome 实测一次 150–200ms，滚轮 rAF 缓动（BUG-2830）在其间整段冻住，体感是
  // 「往下滚会卡在某处停一会」。索引只依赖 DOM 文本结构，不依赖几何，建一次即可；
  // 正文 DOM 变化（有声书 span 包裹兜底、注音切换等）由 MutationObserver 记账，取用时
  // 同步 takeRecords 判脏，不吃异步回调的时序。
  _textIndexCache: null,
  _textIndexObserver: null,
  _textIndex: function() {
    var obs = this._textIndexObserver;
    if (obs && obs.takeRecords().length > 0) this._textIndexCache = null;
    var cache = this._textIndexCache;
    if (cache && cache.body === document.body) return cache;
    if (!obs) {
      var self = this;
      obs = new MutationObserver(function() { self._textIndexCache = null; });
      this._textIndexObserver = obs;
    }
    obs.disconnect();
    obs.observe(document.body, {childList: true, characterData: true, subtree: true});
    var nodes = [];
    var starts = [];
    var total = 0;
    var walker = this.createWalker();
    var node;
    while (node = walker.nextNode()) {
      var len = this.countChars(node.textContent);
      if (len <= 0) continue;
      nodes.push(node);
      starts.push(total);
      total += len;
    }
    cache = {body: document.body, nodes: nodes, starts: starts, total: total};
    this._textIndexCache = cache;
    return cache;
  },
  chapterCharTotal: function() {
    return this._textIndex().total;
  },
  // 文本节点相对视口边的位置：-1 整段在边之前 / 0 跨边 / 1 整段在边之后 / null 无几何。
  // 判据与 countCharsBeforeViewport 的两个早返回逐条同口径（横排沿 top/bottom、竖排
  // vertical-rl 沿 left/right，「之前」在右侧）。
  _textNodeEdgeSide: function(node, vertical, edge) {
    var range = document.createRange();
    range.selectNodeContents(node);
    var rects = range.getClientRects();
    var minStart = Infinity;
    var maxEnd = -Infinity;
    for (var i = 0; i < rects.length; i++) {
      var rect = rects[i];
      if (rect.width <= 0 || rect.height <= 0) continue;
      var start = vertical ? rect.left : rect.top;
      var end = vertical ? rect.right : rect.bottom;
      if (start < minStart) minStart = start;
      if (end > maxEnd) maxEnd = end;
    }
    if (minStart === Infinity) return null;
    if (vertical) {
      if (minStart >= edge) return -1;
      if (maxEnd <= edge) return 1;
    } else {
      if (maxEnd <= edge) return -1;
      if (minStart >= edge) return 1;
    }
    return 0;
  },
  // 视口边（edge 缺省 = 首边，与 countCharsBeforeViewport 同语义）之前的可匹配字符数。
  // 连续模式单栏顺排，文本节点沿书写轴单调：二分出第一个不整段在边之前的节点 k，
  // 结果 = starts[k] + 从 k 起逐个跨边节点的局部计数，遇到整段在边之后即止。每次只
  // 量 O(log n) 个节点的几何，取代逐节点全章累加。无几何的节点（display:none 等）
  // 借其后最近一个有几何的节点判边。
  _charsBeforeEdge: function(vertical, edge) {
    var index = this._textIndex();
    var nodes = index.nodes;
    var n = nodes.length;
    if (n === 0) return 0;
    var probeEdge = edge === undefined ? (vertical ? window.innerWidth : 0) : edge;
    var lo = 0;
    var hi = n;
    while (lo < hi) {
      var mid = (lo + hi) >> 1;
      var j = mid;
      var side = null;
      while (j < hi && (side = this._textNodeEdgeSide(nodes[j], vertical, probeEdge)) === null) j++;
      if (side === null || side >= 0) hi = mid;
      else lo = j + 1;
    }
    if (lo >= n) return index.total;
    var explored = index.starts[lo];
    for (var k = lo; k < n; k++) {
      var kSide = this._textNodeEdgeSide(nodes[k], vertical, probeEdge);
      if (kSide === null) continue;
      if (kSide > 0) break;
      explored += this.countCharsBeforeViewport(nodes[k], vertical, edge);
    }
    return explored;
  },
  calculateProgress: function() {
    // TODO-736 A-1：字符级进度（对齐安卓 reader-continuous.js calculateProgress:529-541）。
    // 分子是「已滚出视口首边的可匹配字符数」（跨视口的长节点按字计，不整节点跳变），
    // 分母是 countChars 总可匹配字符；createWalker 排除 rt/rp，分子分母同套。
    // BUG-2903：两者都走章内文本索引 + 二分，不再逐帧全章 walk。
    var total = this._textIndex().total;
    if (total <= 0) return 0;
    return this._charsBeforeEdge(this.isVertical()) / total;
  },
  // BUG-1241：连续模式同样以视口首字符算 progress，物理滚到底时分数仍可能小于 1。
  // 横排读 scrollTop；竖排 WebView 在 vertical-rl 下 scrollX 为负，因此用绝对位移
  // 与物理最大滚动量比较。
  isAtEnd: function() {
    var root = document.scrollingElement || document.documentElement;
    if (this.isVertical()) {
      var maxX = Math.max(0, root.scrollWidth - root.clientWidth);
      return Math.abs(window.scrollX || root.scrollLeft || 0) >= maxX - 1;
    }
    var maxY = Math.max(0, root.scrollHeight - root.clientHeight);
    return root.scrollTop >= maxY - 1;
  },
  // 连续模式当前视口可见字符区间的终点（半开 end，章内学习单位偏移；口径与
  // calculateProgress 分子同源）。一次 walk 用 countCharsBeforeViewport 传视口**末边**
  // （横排 window.innerHeight / 竖排 0）求「末边之前的字数」；物理到底（isAtEnd）时
  // end = 章总字数。BUG-2903：同走章内文本索引 + 二分。
  getLastVisibleCharOffset: function() {
    var total = this._textIndex().total;
    if (total <= 0) return -1;
    if (this.isAtEnd()) return total;
    var vertical = this.isVertical();
    return this._charsBeforeEdge(vertical, vertical ? 0 : window.innerHeight);
  },
  // 连续模式恢复落点 settle：等一帧让恢复滚动落定后通知 Dart。
  //
  // TODO-perf（跨章）：旧实现是两层嵌套 setTimeout(16)，而且**两层里都不做任何事**，
  // 纯粹空等 32ms 再通知（分页版第一层至少还重设落点）。这里收敛成单层 16ms，与同
  // shell 的章首/章末分支（`单层 16ms + 重发滚动后立即通知`）时序一致。
  _settleAndNotify: function() {
    var self = this;
    setTimeout(function() { self.notifyRestoreComplete(); }, 16);
  },
  restoreProgress: async function(progress) {
    await document.fonts.ready;
    var self = this;
    // 新的恢复覆盖上一次的精确恢复锚：progress 落点没有字符锚，begin 走采样。
    this._setRestoreCharAnchor(null);
    if (progress <= 0) {
      // BUG-1140 第二轮：章首也登记。内容向下增长不移动 scroll 0，重锚
      // scrollToChapterStart 幂等；但章首之前若有前导插图（合并注入 / 封面），图 load
      // 后正文整体下移，不重锚就会停在图与正文之间的错位。
      this.registerImageLateAnchor({progress: 0});
      this.scrollToChapterStart();
      setTimeout(function() {
        self.scrollToChapterStart();
        self.notifyRestoreComplete();
      }, 16);
      return;
    }
    // TODO-1349：progress>=0.99 = 章末（往前翻到上一章的落点），与分页版
    // scrollToProgressPaged 的 `progress>=0.99 → contentLastPageScroll` 对称。走
    // scrollToChapterEnd 落到正文末端（含纯图片/封面章、尾部插图），不再因
    // scrollToProgressContinuous 只走文本节点而在图片章停回章首（封面）。双发一次
    // 再确认对齐（防恢复后自发 reflow 把落点冲回，与 scrollToChapterStart 同构）。
    if (progress >= 0.99) {
      // TODO-1349（续）：登记章末重锚资格 + 强制 load 尾部懒图（打破鸡生蛋，见
      // forceLoadPendingImages）。16ms 双发太快等不到图 load，故尾图 load 后由
      // _sharedInitImages 的 load 回调重锚 scrollToChapterEnd（连续分支）落到含尾图的真实章末。
      this.registerImageLateAnchor({progress: progress});
      this.forceLoadPendingImages();
      this.scrollToChapterEnd();
      setTimeout(function() {
        self.scrollToChapterEnd();
        self.notifyRestoreComplete();
      }, 16);
      return;
    }
    // BUG-1140 第二轮：中段 progress 同样登记（理由见分页版 restoreProgress 长注释）。
    this.registerImageLateAnchor({progress: progress});
    this.scrollToProgressContinuous(progress);
    this._settleAndNotify();
  },
  // fragment 落点的纯几何对齐（jumpToFragment 与迟到图片重锚共用），见分页版同名方法。
  alignToFragmentTarget: function(fragment) {
    var rawFragment = (fragment || '').trim();
    var target = rawFragment && (document.getElementById(rawFragment) || document.getElementsByName(rawFragment)[0]);
    if (!target) return false;
    target.scrollIntoView();
    return true;
  },
  jumpToFragment: async function(fragment) {
    await document.fonts.ready;
    this._setRestoreCharAnchor(null);
    if (!this.alignToFragmentTarget(fragment)) {
      this.clearImageLateAnchor();
      this.notifyRestoreComplete();
      return false;
    }
    this.registerImageLateAnchor({fragment: fragment});
    this._settleAndNotify();
    return true;
  },
  paginate: function(direction) {
    // TODO-1349（续）：用户翻页即放弃 late-load 重锚资格（镜像分页 paginate），
    // 避免图 load 回调把用户已翻走的位置拽回恢复锚。
    this.clearImageLateAnchor();
    this._setRestoreCharAnchor(null);
    var vertical = this.isVertical();
    var root = document.scrollingElement || document.documentElement;
    var before = vertical ? window.scrollX : root.scrollTop;
    var wm = window.getComputedStyle(document.body).writingMode;
    var amount = vertical
      ? Math.max(1, Math.floor(window.innerWidth * 0.9))
      : Math.max(1, Math.floor(window.innerHeight * 0.9));
    var forwardSign = vertical && wm === 'vertical-rl' ? -1 : 1;
    var step = amount * (direction === "forward" ? forwardSign : -forwardSign);
    if (vertical) {
      window.scrollBy({left: step, top: 0, behavior: 'auto'});
    } else {
      window.scrollBy({left: 0, top: step, behavior: 'auto'});
    }
    var after = vertical ? window.scrollX : root.scrollTop;
    var moved = Math.abs(after - before) > 1;
    return moved ? "scrolled" : "limit";
  },
  getFirstVisibleCharOffset: function() {
    var vertical = this.isVertical();
    var cs = getComputedStyle(document.body);
    var pt = parseFloat(cs.paddingTop) || 0;
    var pl = parseFloat(cs.paddingLeft) || 0;
    var pr = parseFloat(cs.paddingRight) || 0;
    var x = vertical ? (window.innerWidth - pr - 2) : (pl + 2);
    var y = pt + 2;
    var range = document.caretRangeFromPoint(x, y);
    // TODO-736 A-2：caretRangeFromPoint 在竖排 / ruby / 图片页 / 折叠盒落点返 null →
    // 旧实现返 -1，落库丢精确字符锚、退化成章节粒度分数（退出再进/重锚回章首附近）。
    // 改走 firstVisibleCharOffsetByScan 全文累加兜底（无 caret 几何依赖，同字符坐标系）。
    if (!range || !range.startContainer) return this.firstVisibleCharOffsetByScan();
    var target = range.startContainer;
    if (target.nodeType !== Node.TEXT_NODE) {
      var walker = this.createWalker(target);
      target = walker.nextNode();
      if (!target) return this.firstVisibleCharOffsetByScan();
    }
    var baseOffset = this.nodeStartOffsets.get(target);
    if (baseOffset === undefined) {
      this.buildNodeOffsets();
      baseOffset = this.nodeStartOffsets.get(target);
      if (baseOffset === undefined) return this.firstVisibleCharOffsetByScan();
    }
    var localChars = 0;
    var text = target.textContent;
    var limit = Math.min(range.startOffset, text.length);
    for (var i = 0; i < limit; i++) {
      var cp = text.codePointAt(i);
      if (window.fushiStudyUnits.isUnitEnd(text, i)) localChars++;
      if (cp > 0xFFFF) i++;
    }
    return baseOffset + localChars;
  },
  // BUG-162: 连续模式按 section 内绝对字符偏移定位（连续滚动语义：把目标字符滚到
  // 视口首边）。抽自原 setChromeInsets 内联体，供 setChromeInsets 重锚与退出再进
  // 恢复共用（DRY）。
  // BUG-461：把章内绝对可匹配字符索引解析成一个塌缩到该字符起始边的 collapsed range。
  // 抽自 scrollToCharOffset 内联体，供「句首锚」与「句尾锚」共用（DRY），返回 null 表示
  // 该偏移落在正文之外（解析失败）。
  collapsedRangeAtCharOffset: function(charOffset) {
    if (charOffset < 0) return null;
    var walker = this.createWalker();
    var node;
    var runningOffset = 0;
    var targetNode = null;
    while (node = walker.nextNode()) {
      var nodeChars = this.countChars(node.textContent);
      if (runningOffset + nodeChars > charOffset) { targetNode = node; break; }
      runningOffset += nodeChars;
    }
    if (!targetNode) return null;
    var remaining = charOffset - runningOffset;
    var charIdx = 0;
    var textOffset = 0;
    var text = targetNode.textContent;
    for (var i = 0; i < text.length && charIdx < remaining; i++) {
      var cp = text.codePointAt(i);
      if (window.fushiStudyUnits.isUnitEnd(text, i)) charIdx++;
      if (cp > 0xFFFF) i++;
      textOffset = i + 1;
    }
    var range = document.createRange();
    range.setStart(targetNode, Math.min(textOffset, text.length));
    range.collapse(true);
    return range;
  },
  // BUG-461：连续模式按章内绝对字符偏移定位（连续滚动语义：把目标字符滚到视口首边）。
  // [endCharOffset]（可选）= 收藏句句尾的绝对字符偏移：传入时把跳转目标当作字符区间
  // [charOffset, endCharOffset]，先把句首贴内容顶，若句尾溢出可见区底沿且整句放得下，
  // 多滚把句尾拉进可见区底沿（continuousFavoriteJumpScrollForTesting 的 JS 实现，整句完整
  // 可见、不被阅读底栏切尾）。不传 endCharOffset（setChromeInsets / 缩放 / 换样式重锚）
  // 时行为与旧版完全一致（句首贴顶，单点锚）。
  scrollToCharOffset: function(charOffset, endCharOffset, hintScroll) {
    // TODO-1229 (BUG-594 第 6 次复诉)：charOffset<=0 == 章节绝对起点区（fvco 归 0）。本函数只走
    // 文本节点（collapsedRangeAtCharOffset→createWalker=SHOW_TEXT），charOffset 0 的 range 落
    // 在**首个文本字符**——若本章以扉页插图开篇，该字符在插图之后，滚到它会跳过前导插图。
    // setChromeInsets / 缩放(commitUiScaleReanchor) / 换样式(commitStyleReanchor) 三条重锚都以
    // getFirstVisibleCharOffset()==0 裸调本函数（restoreToCharOffset 的 <=0 守卫只拦 restore 入口、
    // 拦不到这些 reanchor）→ 初始 restore 落插图页后被它们二次跳到首文本（残留第二跳）。
    //
    // 续修：fvco==0 二义——「用户在章顶前导插图」与「用户在首文本页（char0 正在视口首边）」都
    // 报 0，唯有重锚前采到的滚动位 hintScroll 能判开。裸 scrollToChapterStart 修好了「章顶被弹到
    // 首文本」却把「停在首文本页」的用户弹回章顶前导（headless continuous firstTextPage 守卫）。
    // 故 <=0 时：有正 hint（用户已滚离章顶）→ 保住当前滚动位（重锚只该保位、不移动用户，与分页
    // 版「<=0 保住当前页」同构）；hint 缺席/<=0（章顶前导页 or Dart 直接 scrollToCharOffset(0) 求
    // 章首）→ scrollToChapterStart 滚到顶（含前导图，与 restoreProgress(0) 语义一致）。charOffset>0
    // 精确锚（含收藏句区间 endCharOffset）不变。
    if (charOffset <= 0) {
      // TODO-1308 问题②（BUG-696 根因③）：连续滚动位横排是 scrollTop（>=0），竖排是
      // window.scrollX（vertical-rl 滚离章顶后为**负**，见 _readContinuousScroll /
      // scrollToChapterEnd 的 -1e9）。旧判据 hintScroll > 0 在竖排永假 → TODO-1229 的
      // 「保住当前滚动位」分支在竖排是死代码：任何重锚（setChromeInsets / 缩放 /
      // 换样式）一旦把 fvco 采成 0 就 scrollToChapterStart 把用户钉回章首。轴向归一：
      // 非零即「已滚离章顶」（两轴章顶都是 0），_writeContinuousScroll 原样写回带号位。
      if (typeof hintScroll === 'number' && Math.abs(hintScroll) > 0) {
        this._writeContinuousScroll(hintScroll);
      } else {
        this.scrollToChapterStart();
      }
      return;
    }
    var startRange = this.collapsedRangeAtCharOffset(charOffset);
    if (!startRange) return;
    var rect = this.characterAnchorRect(startRange);
    if (!rect) return;
    var vertical = this.isVertical();
    var root = document.scrollingElement || document.documentElement;
    var cs = getComputedStyle(document.body);
    if (vertical) {
      var pr = parseFloat(cs.paddingRight) || 0;
      var targetX = window.innerWidth - pr;
      // Align the glyph's right edge with the content band. Aligning its left
      // edge puts the whole glyph outside the viewport after expanding a caret.
      var startScrollV = root.scrollLeft + (rect.right - targetX);
      // 竖排可见区在内容宽度轴（chrome-* inset 仍是顶/底 padding 与本轴正交），无「句尾被
      // 底栏切」语义 → 句首贴右沿即可（与旧版一致）。
      root.scrollLeft = startScrollV;
      return;
    }
    var pt = parseFloat(cs.paddingTop) || 0;
    // 句尾区间锚（BUG-461）：仅横排、且调用方给了句尾偏移时启用。
    if (typeof endCharOffset === 'number' && endCharOffset > charOffset) {
      var endRange = this.collapsedRangeAtCharOffset(endCharOffset);
      var endRect = endRange ? this.characterAnchorRect(endRange) : null;
      if (endRect) {
        var lineH = parseFloat(cs.lineHeight);
        if (!(lineH > 0)) lineH = (parseFloat(cs.fontSize) || 16) * 1.5;
        // 句尾远边 = 句尾字符底边（含其所在行高），相对句首起始边的尺寸。
        var sentenceExtent = (endRect.top + lineH) - rect.top;
        var rootStyle = getComputedStyle(document.documentElement);
        var topInset = parseFloat(
          rootStyle.getPropertyValue('--chrome-top-inset')) || 0;
        var bottomInset = parseFloat(
          rootStyle.getPropertyValue('--chrome-bottom-inset')) || 0;
        var vh = window.innerHeight;
        var bandTop = topInset;
        var bandBottom = vh - bottomInset;
        var band = bandBottom - bandTop;
        var startAligned = root.scrollTop + (rect.top - pt);
        if (sentenceExtent > 0 && band > 0 && sentenceExtent <= band) {
          var sentenceBottomInViewport = pt + sentenceExtent;
          var overflow = sentenceBottomInViewport - bandBottom;
          if (overflow < 0) overflow = 0;
          var target = startAligned + overflow;
          root.scrollTop = target < 0 ? 0 : target;
          return;
        }
        root.scrollTop = startAligned < 0 ? 0 : startAligned;
        return;
      }
    }
    root.scrollTop += rect.top - pt;
  },
  // BUG-162: 退出再进的精确恢复（连续）。charOffset<0（旧存档）回退章首；调用方在
  // initialCharOffset<0 时改走 restoreProgress（分数）。BUG-461：endCharOffset（可选）=
  // 收藏句句尾偏移，透传给 scrollToCharOffset 做整句区间对齐（不传则单点句首锚）。
  restoreToCharOffset: async function(charOffset, endCharOffset) {
    await document.fonts.ready;
    // TODO-1229 (BUG-594)：charOffset 0 == 章首（0 字已读）。连续模式章首插图同理不得越过，
    // scrollToChapterStart 滚到顶（含前导图），与 restoreProgress 章首语义一致。>0 走精确锚不变。
    if (charOffset <= 0) {
      this.scrollToChapterStart();
      this.registerImageLateAnchor({progress: 0});
      this._setRestoreCharAnchor(null);
    } else {
      // BUG-492 (TODO-1053 Bug A) 越界兜底：护住旧脏收藏记录。写入端曾把某句错记成
      // 相邻章 sectionIndex（_currentChapter 漂移），恢复端忠实加载该错章 DOM 后，本 charOffset
      // 是「另一章」的绝对偏移，在当前（错）章内可能超出本章可匹配字符总数 →
      // collapsedRangeAtCharOffset 返 null → scrollToCharOffset 静默 return，视口停在恢复瞬态
      // 位置（章首附近的 reflow 落点）→ 用户看不到收藏句、且无任何提示。改为越界即回退章首
      // （确定性落点），比静默停错位可诊断。锚在范围内（含新写入 / 已修数据）走精确对齐，行为不变。
      if (!this.charOffsetInRange(charOffset)) {
        this.scrollToChapterStart();
        this.registerImageLateAnchor({progress: 0});
        this._setRestoreCharAnchor(null);
      } else {
        this.scrollToCharOffset(charOffset, endCharOffset);
        // BUG-1140 第二轮：精确字符锚登记重锚资格（理由见分页版 restoreToCharOffset）。
        this.registerImageLateAnchor(
            {charOffset: charOffset, endCharOffset: endCharOffset});
        // BUG-2744 审查：恢复锚另存一份给 beginRestoreReanchor（见 _setRestoreCharAnchor）。
        this._setRestoreCharAnchor(charOffset, endCharOffset);
      }
    }
    this._settleAndNotify();
  },
  setChromeInsets: function(topPx, bottomPx) {
    // BUG-2652：同分页版——无变化不采样、不重锚（见 _chromeInsetsUnchanged）。
    if (this._chromeInsetsUnchanged(topPx, bottomPx)) return;
    // See the paginated setChromeInsets: re-anchoring is serialised through the
    // shared _reanchorPending flag so a transiently reset scrollTop (from a
    // previous inset/size change's relayout) is never sampled as the chapter
    // start. The rAF clears the flag in a finally{} so an early return from a
    // failed node lookup can never leave the flag stuck. (HBK-REG-004)
    var inFlight = this._reanchorPending === true;
    var charOffset = inFlight ? -1 : this.getFirstVisibleCharOffset();
    // TODO-1229：采样重锚前滚动位（<=0 章首区二义时保住当前位，不弹回章顶前导）。
    var scrollBefore = inFlight ? 0 : this._readContinuousScroll();
    document.documentElement.style.setProperty('--chrome-top-inset', topPx + 'px');
    document.documentElement.style.setProperty('--chrome-bottom-inset', bottomPx + 'px');
    // Same as the paginated shell: the insets are part of the body padding, so
    // the image max box must be re-derived from the new content box.
    this._resetImageMaxVars();
    if (inFlight || charOffset < 0) return;
    this._setReanchorPending(true);
    var self = this;
    this._reanchorFrame(function() {
      try {
        self.scrollToCharOffset(charOffset, undefined, scrollBefore);
      } finally {
        self._setReanchorPending(false);
      }
    });
  },
  // TODO-693: appUiScale（整体界面缩放）变化时，连续模式的阅读位置只是裸 window.scrollY，
  // 没有分页模式的 registerSnapScroll/lockRootViewport 保护。FushiAppUiScale 用新 s 重建
  // 两层 FittedBox/SizedBox → WebView 平台视图 box.size 过渡帧抖动 → 击穿 SetSizeDedup →
  // native put_Bounds → WebView2 reflow 把 document scrollY 瞬时归 0，归零后无任何机制拉回，
  // 于是被章内 scroll 回传通道当作真实滚动落库 progress≈0 → 弹回章节开头。
  //
  // 修复镜像 setChromeInsets 的 _reanchorPending 串行契约，但拆成 Dart 编排的两阶段：缩放是
  // FittedBox 逐帧过渡，box.size 要等过渡帧 settle 才稳定，单个 rAF 不保证捕捉到稳定帧，故由
  // Dart 在缩放重建那一帧同步采样锚 + 置旗（挡住 reflow 自发的归零 scroll 经 onReaderScroll
  // 污染落库），再在 postFrame settle 后提交滚动。两阶段共用同一个 _reanchorPending（与
  // setChromeInsets/updatePageSize/reanchorAfterStyleChange 同一串行旗，HBK-REG-004）。
  beginUiScaleReanchor: function() {
    // 已有重锚在飞（setChromeInsets/updatePageSize 等）→ 让既有序列接管，本次不重复采样，
    // 返回 -1 让 Dart 跳过提交（_uiScaleReanchorOffset 不被本次覆盖）。
    if (this._reanchorPending === true) return -1;
    var charOffset = this.getFirstVisibleCharOffset();
    if (charOffset < 0) return -1;
    this._setReanchorPending(true);
    this._uiScaleReanchorOffset = charOffset;
    // TODO-1229：暂存重锚前滚动位，commit 时用作 <=0 章首区保位 hint。
    this._uiScaleReanchorScroll = this._readContinuousScroll();
    return charOffset;
  },
  // BUG-2652：恢复完成重锚（TODO-718，Dart `_reanchorContinuousAfterRestore`）的锚取
  // **恢复自己的语义锚**，不再现场采样视口。恢复刚写下滚动的头几帧，视口还没落定：
  // iOS 上同一个 WKWebView 原地换章（书内切滚动/分页等结构性重载）后，原生侧会让
  // scrollX/scrollY 瞬时读成 0（Mac 模拟器实测：写入 -1047 后 +16ms 读到 0、约 40ms 后
  // 滚动树里仍是 -1047，这之间没有任何 JS 写入）。此刻 getFirstVisibleCharOffset 采到章首，
  // commit 就 scrollToChapterStart——位置被永久钉回章首并落库，而新开书（全新
  // WebView）没有这个瞬时态，所以只在「书内切换」时坏、退出重进又好。
  // 恢复锚是 restoreToCharOffset 另存的 __restoreCharOffset（_setRestoreCharAnchor），**不是**
  // 迟到图片锚：后者会被跟读揭示替换，而播放中恢复完成时揭示先于本入口执行（BUG-2744 审查）。
  // 恢复落地到用户首次翻页之间有效，此刻用户还碰不到正文；只有精确字符锚能这样取，
  // progress / fragment 恢复仍走采样。
  beginRestoreReanchor: function() {
    var co = this.__restoreCharOffset;
    if (typeof co !== 'number' || co <= 0) return this.beginUiScaleReanchor();
    if (this._reanchorPending === true) return -1;
    this._setReanchorPending(true);
    this._uiScaleReanchorOffset = co;
    this._uiScaleReanchorEnd = this.__restoreCharOffsetEnd;
    this._uiScaleReanchorScroll = this._readContinuousScroll();
    return co;
  },
  commitUiScaleReanchor: function() {
    // beginUiScaleReanchor 必须先成功置旗 + 暂存锚；否则（旗未由本入口置/锚无效）整体 no-op，
    // 绝不误清别处的 _reanchorPending（finally 只在本入口确实拥有旗时执行）。
    var off = this._uiScaleReanchorOffset;
    if (off === undefined || off < 0) return false;
    try {
      // 句尾锚只由 beginRestoreReanchor 带入（收藏句跳转的整句对齐，BUG-461）；缩放入口
      // 不设，undefined 与旧行为一致。
      this.scrollToCharOffset(off, this._uiScaleReanchorEnd, this._uiScaleReanchorScroll);
    } finally {
      this._uiScaleReanchorOffset = undefined;
      this._uiScaleReanchorEnd = undefined;
      this._uiScaleReanchorScroll = undefined;
      this._setReanchorPending(false);
    }
    return true;
  },
  // TODO-736 B-1：图片 max 变量重置共享 helper。换样式后图片 max-width/height 须按当前
  // content-box 重算（否则改字号 reflow 后图片尺寸约束陈旧）。$imageWidthRatio 只能在
  // 各 shell 的 '''
        ' 模板里插值（_sharedJs 是 r'
        ''' 原始串不插值），故每个 shell 的
  // initialize 把比值存到 this._imageWidthRatio，本 helper 读它，begin/reanchor 共用。
  _resetImageMaxVars: function() {
    var box = this._imageMaxBox();
    document.documentElement.style.setProperty('--fushi-image-max-width', box.w + 'px');
    document.documentElement.style.setProperty('--fushi-image-max-height', box.h + 'px');
  },
  // TODO-736 B-1（必补点2）：样式变更专用两阶段重锚的**第一阶段**，由 Dart 在换样式那一
  // 刻调用。与 beginUiScaleReanchor 区别：那对只采锚滚回**不换 CSS**（缩放重建用），改字号
  // 必须在同一入口换 CSS 才能让重排后的 scrollToCharOffset 锚到新排版的真实位置——故新建
  // 这对专入口（不复用 appUiScale 那对）。流程：采锚（getFirstVisibleCharOffset，mode 解析
  // 到分页/连续各自版本，连续含 A-2 兜底）→ 换 CSS + 失效 metrics + 重置 image-max → 置旗
  // _reanchorPending + 暂存 _styleReanchorOffset/_styleReanchorHint。清旗推迟到 commit（由
  // Dart postFrame settle 驱动），挡住 reflow 未落定期的归零 scroll 经 onReaderScroll 污染
  // 落库（翻页多次改字号跳章首的时序根因）。返回采到的偏移；-1 = 无锚/已有重锚在飞 →
  // Dart 跳过 commit。styleEl 由调用方传入（Dart 已 getElementById/createElement 建好）。
  beginStyleReanchor: function(styleEl, css) {
    if (!this.didInitialize) { if (styleEl) styleEl.textContent = css; return -1; }
    // 已有重锚在飞（setChromeInsets/updatePageSize 等）→ 让既有序列接管，只换 CSS 不重采样。
    if (this._reanchorPending === true) {
      if (styleEl) styleEl.textContent = css;
      // BUG-2013：换样式/改字号会改列数 → 改水平滚动条的有无 → 改可视高度。
      // 这里不重写，放大字号后滚动条新出现的书末行照旧被裁，要等 resize 才自愈。
      this._applyContinuousHeight(
          this._contH || C.dartPageHeight || window.innerHeight);
      this._resetImageMaxVars();
      return -1;
    }
    var charOffset = this.getFirstVisibleCharOffset();
    // TODO-1229：连续模式采样 raw scroll 作 <=0 章首区保位 hint（getPagePosition 是分页专属，
    // 连续用内容轴 scroll）。charOffset>0 精确锚不用 hint，故仅 <=0 二义时消歧、不影响正段落。
    var hint = this._readContinuousScroll();
    if (styleEl) styleEl.textContent = css;
    if (this.paginationMetrics !== undefined) this.paginationMetrics = null;
    // BUG-2013：换样式/改字号会改列数 → 改水平滚动条的有无 → 改可视高度。
    // 这里不重写，放大字号后滚动条新出现的书末行照旧被裁，要等 resize 才自愈。
    this._applyContinuousHeight(
          this._contH || C.dartPageHeight || window.innerHeight);
    this._resetImageMaxVars();
    if (charOffset < 0) return -1;
    this._setReanchorPending(true);
    this._styleReanchorOffset = charOffset;
    this._styleReanchorHint = hint;
    return charOffset;
  },
  // TODO-736 B-1：第二阶段——过渡帧 settle 后把暂存锚滚回视口首边并清 _reanchorPending。
  // 仅当 beginStyleReanchor 成功暂存了有效锚时才生效，否则整体 no-op（绝不误清别处的旗，
  // finally 只在本入口确实拥有旗时执行）。TODO-1229：连续 hint=raw scroll，作 3 参 hintScroll
  // 传入（仅 <=0 章首区保位用；off>0 精确锚忽略，endCharOffset 传 undefined 保单点锚语义）。
  commitStyleReanchor: function() {
    var off = this._styleReanchorOffset;
    if (off === undefined || off < 0) return false;
    var hint = this._styleReanchorHint;
    try {
      this.scrollToCharOffset(off, undefined, hint);
    } finally {
      this._styleReanchorOffset = undefined;
      this._styleReanchorHint = undefined;
      this._setReanchorPending(false);
    }
    return true;
  }
};
window.fushiReader.initialize = function() {
  if (window.fushiReader.didInitialize) return;
  window.fushiReader.didInitialize = true;
  this.perfMark('initStart');
  document.documentElement.style.setProperty('--chrome-top-inset', C.chromeTopInset + 'px');
  document.documentElement.style.setProperty('--chrome-bottom-inset', C.chromeBottomInset + 'px');
$_sharedInitViewport
  // TODO-736 B-1：存图片宽比值供 _resetImageMaxVars 读（_sharedJs 不插值，见那里注释）。
  this._imageWidthRatio = $imageWidthRatio;
  var dartH = C.dartPageHeight;
  var contHeight = dartH || window.innerHeight;
  window.__fushiApplyReaderMargins(C.dartPageWidth || window.innerWidth, contHeight);
  // BUG-2013：写进 CSS 的必须是扣掉水平滚动条的可视高度，不是视口外框高度。
  this._applyContinuousHeight(contHeight);
  var __imgBox = this._imageMaxBox();
  document.documentElement.style.setProperty('--fushi-image-max-width', __imgBox.w + 'px');
  document.documentElement.style.setProperty('--fushi-image-max-height', __imgBox.h + 'px');
$initImages
  this.perfMark('initSyncDone');
  Promise.all(imagePromises).then(function() {
    window.fushiReader.perfMark('imagesReady');
    window.fushiReader.buildNodeOffsets();
    window.fushiReader.perfMark('offsetsBuilt');
    // TODO-627：图片可能在初次分页 metrics 建好之后才 decode 完。此前
    // buildPaginationMetrics 枚举到的 <img> 还是 0x0（getBoundingClientRect 全 0），
    // metrics.maxScroll 漏掉图片所占的列 → 偏小 → paginate 在图片页前就误判到末页
    // → _handlePageTurnLimit 跳过插画页跨章。图片 decode 完成后必须失效缓存的
    // paginationMetrics，强制下次 paginate 用纳入图片真实尺寸的几何重建（与
    // updatePageSize / reanchorAfterStyleChange 的 metrics 失效一致）。
    if (window.fushiReader.paginationMetrics !== undefined) {
      window.fushiReader.paginationMetrics = null;
    }
    $sentenceAudioInit
    $initialRestoreScript
  });
};
window.fushiReader.updatePageSize = function(cssWidth, cssHeight) {
  var newHeight = Math.round(cssHeight);
  var newWidth = Math.round(cssWidth);
  var changed = (newHeight !== this._contH || newWidth !== this._contW);
  this._contH = newHeight;
  this._contW = newWidth;
  // Shares _reanchorPending with setChromeInsets (see there): while a re-anchor
  // rAF is in flight, only update the layout and let it restore position.
  var inFlight = this._reanchorPending === true;
  var progress = (changed && !inFlight) ? this.calculateProgress() : 0;
  // BUG-2013：同 initialize——CSS 变量要可视高度，_contH / applyReaderMargins 要外框高度。
  this._applyContinuousHeight(newHeight);
  window.__fushiApplyReaderMargins(newWidth, newHeight);
  var __imgBox = this._imageMaxBox();
  document.documentElement.style.setProperty('--fushi-image-max-width', __imgBox.w + 'px');
  document.documentElement.style.setProperty('--fushi-image-max-height', __imgBox.h + 'px');
  if (inFlight || progress <= 0) return;
  this._setReanchorPending(true);
  var self = this;
  this._reanchorFrame(function() {
    try {
      self.scrollToProgressContinuous(progress);
    } finally {
      self._setReanchorPending(false);
    }
  });
};
(function() {
  var TAP_SLOP = 12;
  var SWIPE_THRESHOLD = 20;
  var downX = 0, downY = 0, downSPos = 0, downSMax = 1, hasDown = false;
  function _bStart(x, y) {
    hasDown = true; downX = x; downY = y;
    // TODO-656：记手势起点(touchstart)沿内容轴的滚动量 + 最大可滚量，跨章只看
    // 起点是否已在边界（见 _bEnd / 纯函数 touchBoundaryCrossDir）。
    var root = document.scrollingElement || document.documentElement;
    var vertical = window.fushiReader && window.fushiReader.isVertical();
    if (vertical) {
      downSPos = Math.abs(root.scrollLeft);
      downSMax = Math.max(1, root.scrollWidth - window.innerWidth);
    } else {
      downSPos = root.scrollTop;
      downSMax = Math.max(1, root.scrollHeight - window.innerHeight);
    }
  }
  function _bEnd(x, y, src) {
    if (!hasDown) return;
    hasDown = false;
    // TODO-1317: a mobile long-press drag-select owns this touch; never cross
    // chapters from a selection gesture.
    if (window.__fushiTextSelectDragActive) return;
    var dx = x - downX;
    var dy = y - downY;
    if (Math.abs(dx) < TAP_SLOP && Math.abs(dy) < TAP_SLOP) return;
    var vertical = window.fushiReader && window.fushiReader.isVertical();
    var gestureDir = null;
    if (vertical) {
      if (Math.abs(dx) < SWIPE_THRESHOLD || Math.abs(dx) < Math.abs(dy)) return;
      gestureDir = dx > 0 ? 'forward' : 'backward';
    } else {
      if (Math.abs(dy) < SWIPE_THRESHOLD || Math.abs(dy) < Math.abs(dx)) return;
      gestureDir = dy < 0 ? 'forward' : 'backward';
    }
    // TODO-656 根治：跨章只看手势起点(touchstart 记的 downSPos)是否已停在边界，不再用
    // touchend 瞬时 scrollTop<=2。从章中滚到边界的那一下起点不在边界 → 不跨章；到边界后
    // 再发同向手势才跨（与纯函数 touchBoundaryCrossDir 同形）。消除「没到章首就跨章」。
    var downAtStart = downSPos <= 2;
    var downAtEnd = downSPos >= downSMax - 2;
    var dir = null;
    if (gestureDir === 'backward' && downAtStart) dir = 'backward';
    else if (gestureDir === 'forward' && downAtEnd) dir = 'forward';
    console.log('[xchapter] bEnd src=' + src + ' vertical=' + (vertical ? 1 : 0)
      + ' gestureDir=' + gestureDir + ' downSPos=' + Math.round(downSPos)
      + ' downSMax=' + Math.round(downSMax)
      + ' downAtStart=' + (downAtStart ? 1 : 0) + ' downAtEnd=' + (downAtEnd ? 1 : 0)
      + ' dir=' + dir);
    if (dir && window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
      window.flutter_inappwebview.callHandler('onBoundarySwipe', dir);
    }
  }
  document.addEventListener('touchstart', function(e) {
    if (!e.touches.length) return;
    _bStart(e.touches[0].clientX, e.touches[0].clientY);
  }, {passive: true});
  document.addEventListener('touchend', function(e) {
    if (!e.changedTouches.length) return;
    _bEnd(e.changedTouches[0].clientX, e.changedTouches[0].clientY, 'touch');
  }, {passive: true});
  // 砍掉 PC 鼠标/触控笔(pointer)的边界手势跨章：连续模式鼠标左键已回归原生选字/划词
  // （见 _fushiReaderMouseDragStartAllowed 连续模式返 false），PC 桌面跨章只走滚轮；
  // 边界手势只保留触摸(touchstart/touchend)给手机。鼠标拖动选词到边界不再误跨章。
})();
// BUG-2748：连续模式用户滚动的输入入口统一在这里认领，调 noteUserScroll（语义见 _sharedJs）。
// 连续模式的视口由原生滚动驱动，没有分页那种单一 paginate 入口：滚轮（webview 层的 wheel
// 处理器自己 scrollBy）、手机原生触摸滚动、拖滚动条（按下点落在根元素上）、WebView 持焦时
// 方向 / 翻页键的原生滚动。捕获阶段 + passive，只记意图、不改任何既有手势行为。按键里不含
// Space（它被桥接成播放 / 暂停或翻页，翻页已由 paginate 清锚）。一个文档只装一次；切到分页
// shell 后监听仍在，所以按 fushiReader 当下是不是连续 shell 判断。
(function() {
  if (window.__fushiUserScrollIntentInstalled) return;
  window.__fushiUserScrollIntentInstalled = true;
  var SCROLL_KEYS = {
    ArrowUp: 1, ArrowDown: 1, ArrowLeft: 1, ArrowRight: 1,
    PageUp: 1, PageDown: 1, Home: 1, End: 1
  };
  function note() {
    var r = window.fushiReader;
    if (r && r._isContinuousShell && r._isContinuousShell() && r.noteUserScroll) {
      r.noteUserScroll();
    }
  }
  var opts = {capture: true, passive: true};
  document.addEventListener('wheel', note, opts);
  document.addEventListener('touchmove', note, opts);
  document.addEventListener('pointerdown', function(e) {
    if (e.target === document.documentElement) note();
  }, opts);
  document.addEventListener('keydown', function(e) {
    if (SCROLL_KEYS[e.key]) note();
  }, opts);
})();
$_sharedInitBoot
};
</script>''';
  }

  // BUG-1140 第二阶段①：VN 侧那份手写转义的 `_jsStringLiteral` 已随「shell 不再插值」
  // 一并删除（VN shell 不再从 Dart 造 JS 字符串字面量）。本实现仍供
  // highlightSasayakiCue / scrollToSearchMatch 这类**调用式**注入使用，
  // 输出字节形式由 test/reader/reader_pagination_scripts_test.dart 钉死。
  static String _jsStringLiteral(String value) {
    return jsonEncode(value);
  }
}
