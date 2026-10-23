
abstract class ReaderSelectionScripts {

  static String clearInvocation() => 'window.fushiSelection.clearSelection()';

  /// TODO-1317: 移动端「长按拖选」手势 IIFE（注入进阅读器 setup script）。触屏在正文
  /// 长按 [delayMs] 毫秒即建立单字选区，继续拖动经
  /// `window.fushiSelection.updateRangeSelection`
  /// 扩展 app 自绘选区（CSS Custom Highlight `fushi-selection`，绝不建立原生选区，
  /// 保住 TODO-1279 触屏无双选区），松手经 `endRangeSelection` 弹选区菜单（复制 / 查词，
  /// 走 `onSelectionMenu`）—— 选区间(可复制)与查词/制卡共存，不再被强制查词；原地未拖动
  /// 也保留长按时建立的单字选区，对齐 Hoshi/Android 原生长按选择。移动 > [slop]px
  /// 未及 [delayMs] 判为滑动/滚动，放弃拖选（长按 vs swipe 消歧）。置全局标志
  /// `window.__fushiTextSelectDragActive`，翻页（`_gestureEnd`）与边界跨章（`_bEnd`）
  /// 见到即让路，绝不与拖选争同一次触摸（消除拖选后误翻页 / 双查词）。
  ///
  /// 单独一个 IIFE、只挂 document 上的 touch 监听，与图片长按（`onImageLongPress`，
  /// 550ms，仅命中图片才 arm）按命中元素天然互斥；多指触摸（缩放）直接不 arm。
  ///
  /// BUG-长按选择不灵敏：[delayMs] 原为 400、[slop] 原为 10，两个都偏严。
  /// * 400ms：同一个 app 的查词弹窗长按已因「等待时间太长」从 500 调到 250
  ///   （BUG-536），阅读器这条却一直没跟。280ms 仍远高于轻点（轻点松手 timer 还没
  ///   fire 就被 touchend 清掉），也仍早于 WebView 自己的原生长按（~500ms）。
  /// * 10px：是全仓最紧的触摸容差——tap 判据 [ReaderSettings.tapSlopPx] 是 10 但只
  ///   需维持到松手，连续模式边界手势是 12px，翻页是 24px，而这里要求手指在整整
  ///   一个长按时限内**始终**停在 10px 半径内，实际上比单击还难触发。放宽到 16px，
  ///   仍小于翻页距离阈值（24px），所以「想滑动翻页」的手势照样能在 arm 阶段被
  ///   slop 取消，两者不会互抢。
  static String longPressDragGestureScript({int delayMs = 280, int slop = 16}) {
    final int slopSq = slop * slop;
    return '''
(function() {
  var LPS_DELAY = $delayMs;
  var LPS_SLOP_SQ = $slopSq;
  var lpsTimer = null;
  var lpsActive = false;
  var lpsStartX = 0, lpsStartY = 0;
  window.__fushiTextSelectDragActive = false;
  function lpsClearTimer() { if (lpsTimer) { clearTimeout(lpsTimer); lpsTimer = null; } }
  function lpsReset() {
    lpsClearTimer();
    lpsActive = false;
    window.__fushiTextSelectDragActive = false;
  }
  function lpsAllowed(target, x, y) {
    var el = target || document.elementFromPoint(x, y);
    if (el && el.closest &&
        el.closest('a[href], img, .block-img-wrapper, input, textarea, select, button, [contenteditable="true"], [data-fushi-clk], #fushi-caret-ring, [data-fushi-sel-handle]')) {
      return false;
    }
    return !!(window.fushiSelection && window.fushiSelection.getSelectableCharacterAtPoint &&
      window.fushiSelection.getSelectableCharacterAtPoint(x, y));
  }
  document.addEventListener('touchstart', function(e) {
    lpsReset();
    // Only single-finger presses select; a second finger is pinch/zoom.
    if (!e.touches || e.touches.length !== 1) return;
    var t = e.touches[0];
    if (!lpsAllowed(e.target, t.clientX, t.clientY)) return;
    lpsStartX = t.clientX;
    lpsStartY = t.clientY;
    lpsTimer = setTimeout(function() {
      lpsTimer = null;
      if (window.fushiSelection && window.fushiSelection.beginRangeSelection &&
          window.fushiSelection.beginRangeSelection(lpsStartX, lpsStartY)) {
        lpsActive = true;
        // Set BEFORE touchend so tap/swipe (_gestureEnd) and boundary cross-chapter
        // (_bEnd) both bail: the drag-select owns this touch exclusively.
        window.__fushiTextSelectDragActive = true;
      }
    }, LPS_DELAY);
  }, {passive: true});
  document.addEventListener('touchmove', function(e) {
    if (!e.touches || !e.touches.length) return;
    var t = e.touches[0];
    if (lpsActive) {
      // Own the gesture: block native scroll and extend the app-drawn selection.
      if (e.cancelable) e.preventDefault();
      if (window.fushiSelection && window.fushiSelection.updateRangeSelection) {
        window.fushiSelection.updateRangeSelection(t.clientX, t.clientY);
      }
      return;
    }
    if (lpsTimer) {
      var dx = t.clientX - lpsStartX;
      var dy = t.clientY - lpsStartY;
      // Moved past slop before the long-press fired: it is a scroll/swipe, not a
      // select; drop the arm and let the native scroll & swipe paths own it.
      if ((dx * dx + dy * dy) > LPS_SLOP_SQ) lpsClearTimer();
    }
  }, {passive: false});
  document.addEventListener('touchend', function(e) {
    if (!lpsActive) { lpsClearTimer(); return; }
    if (e.cancelable && e.preventDefault) e.preventDefault();
    var t = (e.changedTouches && e.changedTouches[0]) || null;
    var x = t ? t.clientX : lpsStartX;
    var y = t ? t.clientY : lpsStartY;
    if (window.fushiSelection && window.fushiSelection.endRangeSelection) {
      window.fushiSelection.endRangeSelection(x, y);
    }
    lpsClearTimer();
    lpsActive = false;
  }, {passive: false});
  document.addEventListener('touchcancel', function() { lpsReset(); }, {passive: true});
})();''';
  }

  static String source() => r"""
const CJK_UNIFIED_IDEOGRAPHS_RANGE = [0x4e00, 0x9fff];
const CJK_UNIFIED_IDEOGRAPHS_EXTENSION_A_RANGE = [0x3400, 0x4dbf];
const CJK_UNIFIED_IDEOGRAPHS_EXTENSION_B_RANGE = [0x20000, 0x2a6df];
const CJK_UNIFIED_IDEOGRAPHS_EXTENSION_C_RANGE = [0x2a700, 0x2b73f];
const CJK_UNIFIED_IDEOGRAPHS_EXTENSION_D_RANGE = [0x2b740, 0x2b81f];
const CJK_UNIFIED_IDEOGRAPHS_EXTENSION_E_RANGE = [0x2b820, 0x2ceaf];
const CJK_UNIFIED_IDEOGRAPHS_EXTENSION_F_RANGE = [0x2ceb0, 0x2ebef];
const CJK_UNIFIED_IDEOGRAPHS_EXTENSION_G_RANGE = [0x30000, 0x3134f];
const CJK_UNIFIED_IDEOGRAPHS_EXTENSION_H_RANGE = [0x31350, 0x323af];
const CJK_UNIFIED_IDEOGRAPHS_EXTENSION_I_RANGE = [0x2ebf0, 0x2ee5f];
const CJK_COMPATIBILITY_IDEOGRAPHS_RANGE = [0xf900, 0xfaff];
const CJK_COMPATIBILITY_IDEOGRAPHS_SUPPLEMENT_RANGE = [0x2f800, 0x2fa1f];
const CJK_IDEOGRAPH_RANGES = [
  CJK_UNIFIED_IDEOGRAPHS_RANGE,
  CJK_UNIFIED_IDEOGRAPHS_EXTENSION_A_RANGE,
  CJK_UNIFIED_IDEOGRAPHS_EXTENSION_B_RANGE,
  CJK_UNIFIED_IDEOGRAPHS_EXTENSION_C_RANGE,
  CJK_UNIFIED_IDEOGRAPHS_EXTENSION_D_RANGE,
  CJK_UNIFIED_IDEOGRAPHS_EXTENSION_E_RANGE,
  CJK_UNIFIED_IDEOGRAPHS_EXTENSION_F_RANGE,
  CJK_UNIFIED_IDEOGRAPHS_EXTENSION_G_RANGE,
  CJK_UNIFIED_IDEOGRAPHS_EXTENSION_H_RANGE,
  CJK_UNIFIED_IDEOGRAPHS_EXTENSION_I_RANGE,
  CJK_COMPATIBILITY_IDEOGRAPHS_RANGE,
  CJK_COMPATIBILITY_IDEOGRAPHS_SUPPLEMENT_RANGE,
];
const FULLWIDTH_CHARACTER_RANGES = [
  [0xff10, 0xff19],
  [0xff21, 0xff3a],
  [0xff41, 0xff5a],
  [0xff01, 0xff0f],
  [0xff1a, 0xff1f],
  [0xff3b, 0xff3f],
  [0xff5b, 0xff60],
  [0xffe0, 0xffee],
];
const JAPANESE_RANGES = [
  [0x3040, 0x309f],
  [0x30a0, 0x30ff],
  ...CJK_IDEOGRAPH_RANGES,
  [0xff66, 0xff9f],
  [0x30fb, 0x30fc],
  [0xff61, 0xff65],
  [0x3000, 0x303f],
  ...FULLWIDTH_CHARACTER_RANGES,
];
window.__fushiCssHighlightsSupported = !!(window.CSS && CSS.highlights && window.Highlight);
window.fushiSelection = {
  selection: null,
  // TODO-1317: mobile long-press selection anchor.
  dragAnchor: null,
  // TODO-1366: start/end drag handles (touch grips) for the app-drawn selection.
  // Elements are lazily created and parented to <html> (like the caret ring),
  // shown only while a drag-selection is live and adjustable, hidden on clear.
  selectionHandles: null,
  activeHandle: null,
  highlightWrappers: [],
  selectionRubyElements: [],
  scanDelimiters: '。、！？…‥「」『』（）()【】〈〉《》〔〕｛｝{}［］[]・：；:;，,.─\n\r"\'“”‘’«»‹›',
  sentenceDelimiters: '。！？.!?',
  trailingSentenceChars: '。、！？…‥」』）)】〉》〕｝}］]',
  isCodePointJapanese: function(codePoint) {
    return JAPANESE_RANGES.some(function(range) { return codePoint >= range[0] && codePoint <= range[1]; });
  },
  isScanWhitespace: function(char) {
    return /^[\s　]$/.test(char);
  },
  isScanStop: function(char) {
    return this.scanDelimiters.includes(char) ||
      (window.scanNonJapaneseText === false && !this.isCodePointJapanese(char.codePointAt(0)));
  },
  isScanBoundary: function(char) {
    return this.isScanWhitespace(char) || this.isScanStop(char);
  },

  intraWordApostrophePattern: /['‘’ʼ]/,
  spaceDelimitedLetterPattern: /[A-Za-z\u00AA\u00B5\u00BA\u00C0-\u00D6\u00D8-\u00F6\u00F8-\u02AF\u0370-\u03FF\u0400-\u052F\u0531-\u0556\u0561-\u0587\u05D0-\u05EA\u05EF-\u05F2\u0620-\u063F\u0641-\u064A\u066E\u066F\u0671-\u06D3\u06D5\u06EE\u06EF\u06FA-\u06FC\u06FF\u0750-\u077F\u08A0-\u08BD\u10A0-\u10C5\u10D0-\u10FA\u1E00-\u1EFF\u1F00-\u1FFF]/,
  isFurigana: function(node) {
    var el = node.nodeType === Node.TEXT_NODE ? node.parentElement : node;
    return !!(el && el.closest('rt, rp'));
  },
  rubyForNode: function(node) {
    var el = node && node.nodeType === Node.TEXT_NODE ? node.parentElement : node;
    return el && el.closest ? el.closest('ruby') : null;
  },
  clearSelectionRubyHighlights: function() {
    if (!this.selectionRubyElements || !this.selectionRubyElements.length) return;
    this.selectionRubyElements.forEach(function(ruby) {
      ruby.classList.remove('fushi-selection-ruby-active');
    });
    this.selectionRubyElements = [];
  },
  BLOCK_SELECTOR: 'p, .glossary-content, .cue, h1, h2, h3, h4, h5, h6, div, li, figcaption, blockquote, section, td, dd',
  findParagraph: function(node) {
    var el = node.nodeType === Node.TEXT_NODE ? node.parentElement : node;
    if (!el) return null;
    var block = el.closest ? el.closest(this.BLOCK_SELECTOR) : null;
    if (block) return block;
    // 没有任何块级祖先：绝不放到整个 body 上游走，退到选区容器的父元素（最坏情况也
    // 只覆盖词所在的直接父节点，绝不跨整篇）。
    return el.parentElement || el;
  },
  createWalker: function(rootNode) {
    var root = rootNode || document.body;
    var self = this;
    return document.createTreeWalker(root, NodeFilter.SHOW_TEXT, {
      acceptNode: function(n) {
        if (self.isFurigana(n)) return NodeFilter.FILTER_REJECT;
        // TODO-956：跳过纯空白 / 纯换行文本节点（块间缩进、HTML 排版换行）。它们的
        // nodeValue 全是空白，被当作句子内容会让 rawSentence.trim() 退化成空字符串。
        var v = n.nodeValue;
        if (v != null && /^[\s　]*$/.test(v)) return NodeFilter.FILTER_REJECT;
        return NodeFilter.FILTER_ACCEPT;
      }
    });
  },
  // BUG-1797：可见正文盒 = body 的 content box ∩ 视口。
  //
  // 分页模式把整章内容当**一根** multicol，靠移动 scrollLeft/scrollTop 看每一页，所以
  // 相邻页的列在几何上就真实地落在 body 的 padding（页边距）带里。body{overflow:hidden}
  // 只在 border-box 裁，裁不掉 padding 带**内**的东西；真正遮住它的是 body 的 clip-path
  // 和 html::before 覆盖条（reader_content_styles.dart 的 contentClipCss / TODO-1285），
  // 两者都是**绘制期**机制。而命中测试是**布局期**的：caretPositionFromPoint 把落点 clamp
  // 到最近字符，getClientRects 完全无视 clip-path 与覆盖条 —— 于是「看不见」和「点得到」
  // 用了两套互不相干的真相，点页边距就查到了相邻页的词（横排在左右间距、竖排在上下间距）。
  //
  // 修法不是给页边距加特例分支，而是让两者同源：判据从「找得到字符」变成「这个字符可见吗」。
  // 盒子取 body 的 content box（border-box 内缩 computed padding，与 contentClipCss 逐项
  // 一致），computed 值已由引擎把 vh/vw/calc/var 解析成 px，不在 JS 里重算一遍 CSS、也就
  // 不会跟 CSS 那侧漂移。三种布局零特例：分页下 body 是钉在视口帧上的 scroller，content
  // box 恰等于 clip 出的可见区；连续模式 body 随内容滚动，与视口取交后滚出去的那截不会被
  // 误判成不可见；VN 模式 body padding 为 0，盒 == 整视口、判据近似恒真。
  visibleContentBox: function() {
    try {
      var body = document.body;
      if (!body) return null;
      var rect = body.getBoundingClientRect();
      var cs = window.getComputedStyle(body);
      var px = function(v) { var n = parseFloat(v); return isFinite(n) ? n : 0; };
      var left = rect.left + px(cs.borderLeftWidth) + px(cs.paddingLeft);
      var top = rect.top + px(cs.borderTopWidth) + px(cs.paddingTop);
      var right = rect.right - px(cs.borderRightWidth) - px(cs.paddingRight);
      var bottom = rect.bottom - px(cs.borderBottomWidth) - px(cs.paddingBottom);
      var vw = window.innerWidth || (document.documentElement && document.documentElement.clientWidth) || 0;
      var vh = window.innerHeight || (document.documentElement && document.documentElement.clientHeight) || 0;
      if (left < 0) left = 0;
      if (top < 0) top = 0;
      if (vw > 0 && right > vw) right = vw;
      if (vh > 0 && bottom > vh) bottom = vh;
      if (!(right > left) || !(bottom > top)) return null;
      return { left: left, top: top, right: right, bottom: bottom };
    } catch (err) {
      return null;
    }
  },
  charRangeVisible: function(charRange, box) {
    if (box === undefined) box = this.visibleContentBox();
    if (!box) return true;
    var rects = charRange.getClientRects();
    var list = (rects && rects.length) ? rects : [charRange.getBoundingClientRect()];
    for (var i = 0; i < list.length; i++) {
      var r = list[i];
      if (!r) continue;
      if (Math.min(r.right, box.right) > Math.max(r.left, box.left) &&
          Math.min(r.bottom, box.bottom) > Math.max(r.top, box.top)) {
        return true;
      }
    }
    return false;
  },
  inCharRange: function(charRange, x, y, pad) {
    // TODO-916 症状④：字符矩形按 [pad]（默认 0 = 旧的精确包含）外扩一圈再判包含，
    // 消除落在字缝/行距/描边外缘的 miss。pad 仅在 getCaretRange 的逐字符兜底里传入小值，
    // 其它调用点（±1 offset 确认）仍走精确 0。
    pad = pad || 0;
    var rects = charRange.getClientRects();
    if (rects.length) {
      for (var i = 0; i < rects.length; i++) {
        var rect = rects[i];
        if (x >= rect.left - pad && x <= rect.right + pad && y >= rect.top - pad && y <= rect.bottom + pad) return true;
      }
      return false;
    }
    var fallback = charRange.getBoundingClientRect();
    return x >= fallback.left - pad && x <= fallback.right + pad && y >= fallback.top - pad && y <= fallback.bottom + pad;
  },
  // TODO-916 症状④：点到字符矩形中心的距离平方（落在矩形内为 0），供逐字符兜底取最近字符。
  charRangeDistanceSq: function(charRange, x, y) {
    var rect = charRange.getClientRects()[0] || charRange.getBoundingClientRect();
    if (!rect) return Infinity;
    var cx = x < rect.left ? rect.left : (x > rect.right ? rect.right : x);
    var cy = y < rect.top ? rect.top : (y > rect.bottom ? rect.bottom : y);
    var dx = cx - x;
    var dy = cy - y;
    return dx * dx + dy * dy;
  },
  // BUG-1797：[box] 是调用方算好的可见正文盒（见 visibleContentBox），沿命中链往下传，
  // 逐字符兜底扫描才不会每个字符都现算一次 getComputedStyle。不传时自己算一份。
  getCaretRange: function(x, y, box) {
    if (box === undefined) box = this.visibleContentBox();
    // BUG-765 续修：`caretPositionFromPoint` 命中「非文本 / 振假名」节点时**不再早退**，
    // 落到下面的 `elementFromPoint`+最近字符几何兜底。根因：拖选区手柄时手指压在手柄
    // div 上，即便 `moveSelectionHandle` 已把手柄 `pointer-events:none`，部分 Android
    // WebView 的 `caretPositionFromPoint` 仍把命中解析到手柄自身 / documentElement
    // （ELEMENT_NODE）→ getCharacterAtPoint 返回 null → 手柄冻结拖不动。旧代码押注
    // 「caretPositionFromPoint 尊重 pointer-events」这一脆弱假设，真机不成立。现在只在
    // 拿到可用文本节点时才走快路，否则统一落到 elementFromPoint（对 pointer-events:none
    // 稳定生效）解析出的底层文本块里做有界的最近字符扫描，横竖排通吃。
    if (document.caretPositionFromPoint) {
      var pos = document.caretPositionFromPoint(x, y);
      if (pos && pos.offsetNode && pos.offsetNode.nodeType === Node.TEXT_NODE) {
        var caretRange = document.createRange();
        caretRange.setStart(pos.offsetNode, pos.offset);
        caretRange.collapse(true);
        return caretRange;
      }
    }
    var element = document.elementFromPoint(x, y);
    if (!element) return null;
    var container = element.closest('p, div, span, ruby, a') || document.body;
    var walker = this.createWalker(container);
    var range = document.createRange();
    var node;
    // 第一遍：精确包含（旧行为，零回归）。
    while (node = walker.nextNode()) {
      for (var i = 0; i < node.textContent.length; i++) {
        range.setStart(node, i);
        range.setEnd(node, i + 1);
        // BUG-1797：命中还不够，字符得真的可见 —— 页边距带里的相邻页字符会被这里剔掉。
        if (this.inCharRange(range, x, y) && this.charRangeVisible(range, box)) {
          range.collapse(true);
          return range;
        }
      }
    }
    // 第二遍（TODO-916 症状④）：精确全 miss 时回退到「最近字符」——仅当该字符在一个
    // 保守容差内（半行高，约半个字宽）才采纳，避免点空白处误选远字。walker 已 REJECT
    // furigana（rt/rp），故振假名永不被兜底命中；只放宽正文字符命中精度。
    var walker2 = this.createWalker(container);
    var bestNode = null;
    var bestOffset = -1;
    var bestDistSq = Infinity;
    while (node = walker2.nextNode()) {
      for (var j = 0; j < node.textContent.length; j++) {
        range.setStart(node, j);
        range.setEnd(node, j + 1);
        var distSq = this.charRangeDistanceSq(range, x, y);
        if (distSq >= bestDistSq) continue;
        var rect = range.getClientRects()[0] || range.getBoundingClientRect();
        if (!rect) continue;
        // BUG-1797：不可见字符不得参与「最近字符」竞争 —— 否则页边距带里的相邻页字符
        // 会以更近的距离抢走本页边缘字符的名额，落点从「查错词」变成「查不到词」。
        if (!this.charRangeVisible(range, box)) continue;
        var tol = Math.max(6, Math.max(rect.width, rect.height) / 2);
        if (distSq <= tol * tol) {
          bestDistSq = distSq;
          bestNode = node;
          bestOffset = j;
        }
      }
    }
    if (bestNode) {
      range.setStart(bestNode, bestOffset);
      range.collapse(true);
      return range;
    }
    return document.caretRangeFromPoint ? document.caretRangeFromPoint(x, y) : null;
  },
  getCharacterAtPoint: function(x, y) {
    var hit = this.getSelectableCharacterAtPoint(x, y);
    if (!hit) return null;
    if (this.isScanBoundary(hit.node.textContent[hit.offset])) return null;
    return hit;
  },
  // 几何命中层：只回答「这个点上有没有一个**可见的**字」，不判断它是不是词边界。
  getSelectableCharacterAtPoint: function(x, y) {
    // BUG-1797：整条命中链共用同一个可见正文盒，一次 hit-test 只量一次几何。
    var box = this.visibleContentBox();
    var range = this.getCaretRange(x, y, box);
    if (!range) return null;
    var node = range.startContainer;
    if (node.nodeType !== Node.TEXT_NODE || this.isFurigana(node)) return null;
    var text = node.textContent;
    var caret = range.startOffset;
    var offsets = [caret, caret - 1, caret + 1];
    // 第一遍精确确认（旧行为，零回归）；TODO-916 症状④：精确全 miss 时第二遍带容差
    // （半字宽/行高）兜底，消除字缝/行距点不中。
    var pads = [0, 6];
    for (var p = 0; p < pads.length; p++) {
      for (var i = 0; i < offsets.length; i++) {
        var offset = offsets[i];
        if (offset < 0 || offset >= text.length) continue;
        var charRange = document.createRange();
        charRange.setStart(node, offset);
        charRange.setEnd(node, offset + 1);
        if (this.inCharRange(charRange, x, y, pads[p]) &&
            this.charRangeVisible(charRange, box)) {
          return { node: node, offset: offset };
        }
      }
    }
    return null;
  },
  getSentenceContext: function(startNode, startOffset) {
    var container = this.findParagraph(startNode) || document.body;
    var walker = this.createWalker(container);
    walker.currentNode = startNode;
    var partsBefore = [];
    var node = startNode;
    var limit = startOffset;
    var sStartNode = startNode;
    var sStartOffset = 0;
    while (node) {
      var text = node.textContent;
      var foundStart = false;
      for (var i = limit - 1; i >= 0; i--) {
        if (this.sentenceDelimiters.includes(text[i])) {
          partsBefore.push(text.slice(i + 1, limit));
          sStartNode = node;
          sStartOffset = i + 1;
          foundStart = true;
          break;
        }
      }
      if (foundStart) break;
      partsBefore.push(text.slice(0, limit));
      sStartNode = node;
      sStartOffset = 0;
      node = walker.previousNode();
      if (node) limit = node.textContent.length;
    }
    walker.currentNode = startNode;
    var partsAfter = [];
    node = startNode;
    var start = startOffset;
    var sEndNode = startNode;
    var sEndOffset = startNode.textContent.length;
    while (node) {
      var afterText = node.textContent;
      var foundEnd = false;
      for (var j = start; j < afterText.length; j++) {
        if (this.sentenceDelimiters.includes(afterText[j])) {
          var end = j + 1;
          while (end < afterText.length && this.trailingSentenceChars.includes(afterText[end])) end++;
          partsAfter.push(afterText.slice(start, end));
          sEndNode = node;
          sEndOffset = end;
          foundEnd = true;
          break;
        }
      }
      if (foundEnd) break;
      partsAfter.push(afterText.slice(start));
      sEndNode = node;
      sEndOffset = afterText.length;
      node = walker.nextNode();
      start = 0;
    }
    var beforeText = partsBefore.reverse().join('');
    var rawSentence = (beforeText + partsAfter.join(''))
        .replace(/[\n\r]/g, ' ');
    var trimmedSentence = rawSentence.trim();
    var leadingTrim = rawSentence.length - rawSentence.trimStart().length;
    var sentenceOffset = Math.max(0, beforeText.length - leadingTrim);
    // TODO-956：契约——可见正文里选中的可见词必须产出非空句子。若逐分隔符游走拼出的
    // 句子 trim 后仍为空（例如游走只命中了块间空白 / 换行节点，或被分隔符切成空片段），
    // 退回到「词所在块自身的可见文本」。container 已是 findParagraph 解析出的块级元素
    // （绝不会是整个 body），故这层兜底不会越界跨块。仅当块本身就没有可见文本（纯空白
    // 容器）时才仍返回空字符串——这正是 card_mined_no_sentence_captured 该触发的真空选。
    if (trimmedSentence === '' && container && container.textContent) {
      var blockText = container.textContent.trim();
      if (blockText !== '') {
        trimmedSentence = blockText;
        sentenceOffset = 0;
      }
    }
    return {
      sentence: trimmedSentence,
      sentenceOffset: sentenceOffset,
      sStartNode: sStartNode,
      sStartOffset: sStartOffset,
      sEndNode: sEndNode,
      sEndOffset: sEndOffset
    };
  },
  // 返回 (node, offset) 处（含本位）的下一个有效文本位置，无则 null。
  // TODO-393 修：同 charBefore，walker 根用 document.body 以支持「下一句」跨 <p> 段落取到
  // 下一段首个可见文本节点（旧实现困在 findParagraph 当前块内、段末即 break → 后加一句没反应）。
  charAt: function(node, offset) {
    if (offset < node.textContent.length) return { node: node, offset: offset };
    var walker = this.createWalker(document.body);
    walker.currentNode = node;
    var next = walker.nextNode();
    while (next) {
      if (next.textContent.length > 0) return { node: next, offset: 0 };
      next = walker.nextNode();
    }
    return null;
  },
  buildSelectionPayload: function(x, y) {
    if (!this.selection || !this.selection.ranges || !this.selection.ranges.length) return null;
    var startNode = this.selection.startNode;
    var startOffset = this.selection.startOffset;
    var ranges = this.selection.ranges;
    var text = this.selection.text;
    var sentenceContext = this.getSentenceContext(startNode, startOffset);
    var normalizedOffset = window.fushiReader ? this.getNormalizedOffset(startNode, startOffset) : null;
    var normalizedLength = null;
    if (normalizedOffset !== null && ranges.length > 0) {
      var lastRange = ranges[ranges.length - 1];
      var normalizedEnd = this.getNormalizedOffset(lastRange.node, lastRange.end);
      if (normalizedEnd !== null) normalizedLength = Math.max(0, normalizedEnd - normalizedOffset);
    }
    return {
      text: text,
      sentence: sentenceContext.sentence,
      rect: this.getSelectionRect(x, y),
      normalizedOffset: normalizedOffset,
      normalizedLength: normalizedLength
    };
  },
  fireSelectionMenu: function(x, y) {
    var payload = this.buildSelectionPayload(x, y);
    if (!payload) return null;
    window.flutter_inappwebview.callHandler('onSelectionMenu', JSON.stringify(payload));
    return payload.text;
  },
  collectRangeBetween: function(nodeA, offA, nodeB, offB) {
    var startNode, startOffset, endNode, endOffset;
    var before;
    if (nodeA === nodeB) {
      before = offA <= offB;
    } else {
      before = !!(nodeA.compareDocumentPosition(nodeB) & Node.DOCUMENT_POSITION_FOLLOWING);
    }
    if (before) {
      startNode = nodeA; startOffset = offA; endNode = nodeB; endOffset = offB + 1;
    } else {
      startNode = nodeB; startOffset = offB; endNode = nodeA; endOffset = offA + 1;
    }
    var walker = this.createWalker(document.body);
    walker.currentNode = startNode;
    var ranges = [];
    var text = '';
    var node = startNode;
    var from = startOffset;
    // Bound the walk so a broken node relationship can never spin forever.
    var guard = 0;
    while (node && guard++ < 100000) {
      var content = node.textContent;
      var to = (node === endNode) ? Math.min(endOffset, content.length) : content.length;
      if (to > from) {
        ranges.push({ node: node, start: from, end: to });
        text += content.slice(from, to);
      }
      if (node === endNode) break;
      node = walker.nextNode();
      from = 0;
    }
    if (!text) return null;
    return { startNode: startNode, startOffset: startOffset, ranges: ranges, text: text };
  },
  renderSelectionHighlight: function() {
    if (!this.selection || !this.selection.text) return;
    if (window.__fushiCssHighlightsSupported) {
      this.highlightSelection(this.selection.text.length + 1);
    }
  },
  beginRangeSelection: function(x, y) {
    var el = document.elementFromPoint(x, y);
    if (el && el.closest && el.closest('a')) return false;
    var hit = this.getSelectableCharacterAtPoint(x, y);
    if (!hit) return false;
    this.clearSelection();
    this.dragAnchor = { node: hit.node, offset: hit.offset };
    // Establish and paint the anchor glyph immediately. This is the feedback the
    // native Android selection path gives at long-press time; the old path only
    // armed an anchor and made selection contingent on a later drag.
    this.updateRangeSelection(x, y);
    return true;
  },
  updateRangeSelection: function(x, y) {
    if (!this.dragAnchor) return null;
    var hit = this.getSelectableCharacterAtPoint(x, y);
    // Over a gap/blank while dragging, keep the anchor as the end (no shrink).
    var endNode = hit ? hit.node : this.dragAnchor.node;
    var endOffset = hit ? hit.offset : this.dragAnchor.offset;
    var built = this.collectRangeBetween(
      this.dragAnchor.node, this.dragAnchor.offset, endNode, endOffset);
    if (!built) return null;
    this.selection = {
      startNode: built.startNode, startOffset: built.startOffset,
      ranges: built.ranges, text: built.text
    };
    this.renderSelectionHighlight();
    return built.text;
  },
  endRangeSelection: function(x, y) {
    this.updateRangeSelection(x, y);
    this.dragAnchor = null;
    if (!this.selection || !this.selection.text) {
      this.clearSelection();
      return false;
    }
    this.showSelectionHandles();
    this.fireSelectionMenu(x, y);
    return true;
  },
  _selectionVertical: function() {
    if (window.fushiReader && typeof window.fushiReader.isVertical === 'function') {
      return window.fushiReader.isVertical();
    }
    return window.getComputedStyle(document.body).writingMode === 'vertical-rl';
  },
  // Visual endpoints of the current selection as {startNode, startOffset (first
  // glyph), endNode, endOffset (index of the last glyph = one before range end)}.
  // null when there is no live glyph selection.
  selectionEndpoints: function() {
    if (!this.selection || !this.selection.ranges || !this.selection.ranges.length) {
      return null;
    }
    var first = this.selection.ranges[0];
    var last = this.selection.ranges[this.selection.ranges.length - 1];
    if (last.end <= last.start) return null;
    return {
      startNode: first.node, startOffset: first.start,
      endNode: last.node, endOffset: last.end - 1
    };
  },
  _glyphRect: function(node, offset) {
    var len = 1;
    var cp = node.textContent.codePointAt(offset);
    if (cp !== undefined && cp > 0xffff) len = 2;
    var range = document.createRange();
    range.setStart(node, offset);
    range.setEnd(node, Math.min(offset + len, node.textContent.length));
    var rects = range.getClientRects();
    for (var i = 0; i < rects.length; i++) {
      if (rects[i].width > 0 && rects[i].height > 0) return rects[i];
    }
    return range.getBoundingClientRect();
  },
  ensureSelectionHandles: function() {
    if (this.selectionHandles && this.selectionHandles.start.isConnected &&
        this.selectionHandles.end.isConnected) {
      return this.selectionHandles;
    }
    var self = this;
    var make = function(which) {
      var el = document.getElementById('fushi-sel-handle-' + which);
      if (!el) {
        el = document.createElement('div');
        el.id = 'fushi-sel-handle-' + which;
        el.setAttribute('data-fushi-sel-handle', which);
        // BUG-765 续：外层是 32×32 透明触控盒（比旧 24px 大，改善抓取；不取更大是因为
        // 1~2 字 CJK 短选区两端相距仅约一个字宽，触控盒过大会几乎完全重叠、反而遮住起
        // 手柄）。命中区大、视觉小；pointer-events:auto + touch-action:none 让它吃掉浏览器
        // 滚动手势并可拖。视觉抓手是内层 18px 实心圆钮，用主题色 var(--fushi-sel-handle)
        // （reader CSS 从 linkColor 下发，随主题变）+ 白描边（任意背景都可见）+ 单柔和阴
        // 影，去掉旧的刺眼橙色 + 双重发光 box-shadow（用户投诉「难看」）。
        el.style.cssText = 'position:fixed;z-index:2147483645;width:32px;height:32px;' +
          'margin-left:-16px;margin-top:-16px;box-sizing:border-box;' +
          'background:transparent;border:0;' +
          'pointer-events:auto;touch-action:none;display:none;';
        var ball = document.createElement('div');
        ball.setAttribute('data-fushi-sel-ball', which);
        ball.style.cssText = 'position:absolute;left:50%;top:50%;width:18px;height:18px;' +
          'margin-left:-9px;margin-top:-9px;border-radius:50%;box-sizing:border-box;' +
          'background:var(--fushi-sel-handle, #3a5fad);' +
          'border:2px solid rgba(255,255,255,0.95);' +
          'box-shadow:0 1px 4px rgba(0,0,0,0.35);pointer-events:none;';
        el.appendChild(ball);
        document.documentElement.appendChild(el);
        self._wireHandle(el, which);
      }
      return el;
    };
    this.selectionHandles = { start: make('start'), end: make('end') };
    return this.selectionHandles;
  },
  _wireHandle: function(el, which) {
    var self = this;
    // stopPropagation keeps the document-level long-press / page-gesture
    // listeners from arming on a grip touch; preventDefault + touch-action:none
    // stop the browser treating the grip drag as a scroll.
    el.addEventListener('touchstart', function(e) {
      if (e.cancelable) e.preventDefault();
      e.stopPropagation();
      self.activeHandle = which;
    }, {passive: false});
    el.addEventListener('touchmove', function(e) {
      if (self.activeHandle !== which) return;
      if (e.cancelable) e.preventDefault();
      e.stopPropagation();
      var t = (e.touches && e.touches[0]) || null;
      if (t) self.moveSelectionHandle(which, t.clientX, t.clientY);
    }, {passive: false});
    el.addEventListener('touchend', function(e) {
      if (self.activeHandle !== which) return;
      if (e.cancelable) e.preventDefault();
      e.stopPropagation();
      self.activeHandle = null;
      var t = (e.changedTouches && e.changedTouches[0]) || null;
      var x = t ? t.clientX : 0;
      var y = t ? t.clientY : 0;
      self.positionSelectionHandles();
      self.fireSelectionMenu(x, y);
    }, {passive: false});
    el.addEventListener('touchcancel', function() {
      if (self.activeHandle === which) {
        self.activeHandle = null;
        self.positionSelectionHandles();
      }
    }, {passive: true});
  },
  // Drag one grip to (x,y): the other endpoint's glyph is the fixed anchor, the
  // grip's glyph becomes the point under the finger. Rebuild + re-highlight +
  // reposition both grips. No-op over a gap so the range never collapses.
  moveSelectionHandle: function(which, x, y) {
    var eps = this.selectionEndpoints();
    if (!eps) return;
    // The grip div sits directly under the finger (pointer-events:auto, top
    // z-index). A hit-test at the raw finger point resolves elementFromPoint /
    // caretPositionFromPoint to the grip element (an ELEMENT_NODE, not a text
    // node) -> getCharacterAtPoint returns null -> the grip appears frozen and
    // the range never adjusts. Make both grips transparent to hit-testing for
    // the duration of the point resolution so the finger coordinate falls
    // through to the glyph underneath, then restore. No native selection is
    // touched (still app-drawn only).
    var handles = this.selectionHandles;
    var savedStartPe = handles ? handles.start.style.pointerEvents : null;
    var savedEndPe = handles ? handles.end.style.pointerEvents : null;
    if (handles) {
      handles.start.style.pointerEvents = 'none';
      handles.end.style.pointerEvents = 'none';
    }
    var hit = this.getSelectableCharacterAtPoint(x, y);
    if (handles) {
      handles.start.style.pointerEvents = savedStartPe || 'auto';
      handles.end.style.pointerEvents = savedEndPe || 'auto';
    }
    if (!hit) return;
    var anchorNode, anchorOffset;
    if (which === 'end') {
      anchorNode = eps.startNode; anchorOffset = eps.startOffset;
    } else {
      anchorNode = eps.endNode; anchorOffset = eps.endOffset;
    }
    var built = this.collectRangeBetween(anchorNode, anchorOffset, hit.node, hit.offset);
    if (!built) return;
    this.selection = {
      startNode: built.startNode, startOffset: built.startOffset,
      ranges: built.ranges, text: built.text
    };
    this.renderSelectionHighlight();
    this.positionSelectionHandles();
  },
  positionSelectionHandles: function() {
    var eps = this.selectionEndpoints();
    if (!eps) { this.hideSelectionHandles(); return; }
    var handles = this.ensureSelectionHandles();
    var vertical = this._selectionVertical();
    var sRect = this._glyphRect(eps.startNode, eps.startOffset);
    var eRect = this._glyphRect(eps.endNode, eps.endOffset);
    var sx, sy, ex, ey;
    // 圆钮离开文字的间隙（约半个钮），让抓手悬在选区外缘、不压住字。
    var GAP = 8;
    if (vertical) {
      // vertical-rl: reading runs top->bottom, columns right->left. Start grip
      // above the first glyph, end grip below the last glyph.
      sx = sRect.left + sRect.width / 2;
      sy = sRect.top - GAP;
      ex = eRect.left + eRect.width / 2;
      ey = eRect.bottom + GAP;
    } else {
      // horizontal: start grip at the lower-left of the first glyph, end grip at
      // the lower-right of the last glyph (below the baseline).
      sx = sRect.left;
      sy = sRect.bottom + GAP;
      ex = eRect.right;
      ey = eRect.bottom + GAP;
    }
    handles.start.style.left = sx + 'px';
    handles.start.style.top = sy + 'px';
    handles.start.style.display = 'block';
    handles.end.style.left = ex + 'px';
    handles.end.style.top = ey + 'px';
    handles.end.style.display = 'block';
  },
  showSelectionHandles: function() {
    this.positionSelectionHandles();
  },
  hideSelectionHandles: function() {
    this.activeHandle = null;
    if (this.selectionHandles) {
      this.selectionHandles.start.style.display = 'none';
      this.selectionHandles.end.style.display = 'none';
    }
  },
  getSelectionRect: function(x, y) {
    if (!this.selection || !this.selection.ranges.length) return null;
    var first = this.selection.ranges[0];
    var range = document.createRange();
    range.setStart(first.node, first.start);
    range.setEnd(first.node, first.start + 1);
    var rects = Array.from(range.getClientRects());
    var rect = rects.find(function(rect) { return x >= rect.left && x <= rect.right && y >= rect.top && y <= rect.bottom; }) || range.getBoundingClientRect();
    return { x: rect.x, y: rect.y, width: rect.width, height: rect.height };
  },
  highlightSelection: function(charCount) {
    if (!this.selection || !this.selection.ranges.length) return null;
    var trimmedRanges = [];
    var remaining = charCount;
    for (var i = 0; i < this.selection.ranges.length; i++) {
      var r = this.selection.ranges[i];
      if (remaining <= 0) break;
      var end = r.start;
      while (end < r.end && remaining > 0) {
        var char = String.fromCodePoint(r.node.textContent.codePointAt(end));
        end += char.length;
        remaining--;
      }
      trimmedRanges.push({ node: r.node, start: r.start, end: end });
    }
    this.selection.matchedRanges = trimmedRanges;
    var bounds = null;
    for (var i = 0; i < trimmedRanges.length; i++) {
      var seg = trimmedRanges[i];
      var bRange = document.createRange();
      bRange.setStart(seg.node, seg.start);
      bRange.setEnd(seg.node, seg.end);
      var rects = bRange.getClientRects();
      for (var j = 0; j < rects.length; j++) {
        var r = rects[j];
        if (!bounds) {
          bounds = { left: r.left, top: r.top, right: r.right, bottom: r.bottom };
        } else {
          if (r.left < bounds.left) bounds.left = r.left;
          if (r.top < bounds.top) bounds.top = r.top;
          if (r.right > bounds.right) bounds.right = r.right;
          if (r.bottom > bounds.bottom) bounds.bottom = r.bottom;
        }
      }
    }
    if (window.__fushiCssHighlightsSupported) {
      // BUG-110：<ruby> 内的字不放进 ::highlight（竖排下 ::highlight 把 ruby 基字盒
      // 画两遍 → 半透明叠加成深色带遮字），改给 <ruby> 元素加 class 单次绘背景。
      var highlights = [];
      this.clearSelectionRubyHighlights();
      for (var i = 0; i < trimmedRanges.length; i++) {
        var seg = trimmedRanges[i];
        var ruby = this.rubyForNode(seg.node);
        if (ruby) {
          if (this.selectionRubyElements.indexOf(ruby) < 0) {
            ruby.classList.add('fushi-selection-ruby-active');
            this.selectionRubyElements.push(ruby);
          }
          continue;
        }
        var range = document.createRange();
        range.setStart(seg.node, seg.start);
        range.setEnd(seg.node, seg.end);
        highlights.push(range);
      }
      var selHl = highlights.length ? new Highlight(...highlights) : new Highlight();
      // BUG-125：选区高亮 priority=1，叠在其它 Highlight 之上。
      selHl.priority = 1;
      CSS.highlights.set('fushi-selection', selHl);
    } else {
      this.clearHighlightWrappers();
      var range = document.createRange();
      for (var i = trimmedRanges.length - 1; i >= 0; i--) {
        var seg = trimmedRanges[i];
        range.setStart(seg.node, seg.start);
        range.setEnd(seg.node, seg.end);
        var wrapper = document.createElement('span');
        wrapper.className = 'fushi-dict-highlight';
        wrapper.appendChild(range.extractContents());
        range.insertNode(wrapper);
        this.highlightWrappers.push(wrapper);
      }
      this.highlightWrappers.reverse();
    }
    return bounds ? { x: bounds.left, y: bounds.top, width: bounds.right - bounds.left, height: bounds.bottom - bounds.top } : null;
  },
  getMatchableOffset: function(targetNode, offset) {
    if (!window.fushiReader || !targetNode) return null;
    if (typeof window.fushiReader.getMatchableOffset === 'function') {
      return window.fushiReader.getMatchableOffset(targetNode, offset);
    }
    var walker = this.createWalker(document.body);
    var count = 0;
    var node;
    while ((node = walker.nextNode()) != null) {
      var text = node.textContent || '';
      var limit = node === targetNode ? offset : text.length;
      for (var i = 0; i < limit;) {
        var ch = String.fromCodePoint(text.codePointAt(i));
        if (window.fushiReader.isMatchableChar(ch)) count += ch.length;
        i += ch.length;
      }
      if (node === targetNode) return count;
    }
    return null;
  },
  getNormalizedOffset: function(targetNode, offset) {
    if (!window.fushiReader) return null;
    var base = window.fushiReader.nodeStartOffsets
      ? window.fushiReader.nodeStartOffsets.get(targetNode) : undefined;
    if (base !== undefined) {
      var count = base || 0;
      var text = targetNode.textContent;
      for (var i = 0; i < offset;) {
        var char = String.fromCodePoint(text.codePointAt(i));
        if (window.fushiStudyUnits.isUnitEnd(text, i)) count++;
        i += char.length;
      }
      return count;
    }
    var walker = this.createWalker(document.body);
    var count = 0;
    var node;
    while ((node = walker.nextNode()) != null) {
      var nodeText = node.textContent;
      if (node === targetNode) {
        for (var i = 0; i < offset;) {
          var char = String.fromCodePoint(nodeText.codePointAt(i));
          if (window.fushiStudyUnits.isUnitEnd(nodeText, i)) count++;
          i += char.length;
        }
        return count;
      }
      for (var i = 0; i < nodeText.length;) {
        var char = String.fromCodePoint(nodeText.codePointAt(i));
        if (window.fushiStudyUnits.isUnitEnd(nodeText, i)) count++;
        i += char.length;
      }
    }
    return null;
  },
  clearHighlightWrappers: function() {
    if (!this.highlightWrappers.length) return;
    for (var i = 0; i < this.highlightWrappers.length; i++) {
      var wrapper = this.highlightWrappers[i];
      var parent = wrapper.parentNode;
      if (!parent) continue;
      while (wrapper.firstChild) {
        parent.insertBefore(wrapper.firstChild, wrapper);
      }
      parent.removeChild(wrapper);
      parent.normalize();
    }
    this.highlightWrappers = [];
    if (!window.__fushiCssHighlightsSupported && window.fushiReader && window.fushiReader.buildNodeOffsets) {
      window.fushiReader.buildNodeOffsets();
    }
  },
  clearSelection: function() {
    window.getSelection()?.removeAllRanges();
    if (window.__fushiCssHighlightsSupported) {
      CSS.highlights.delete('fushi-selection');
      this.clearSelectionRubyHighlights();
    } else {
      this.clearHighlightWrappers();
    }
    this.hideSelectionHandles();
    this.selection = null;
  }
};
""";
}
