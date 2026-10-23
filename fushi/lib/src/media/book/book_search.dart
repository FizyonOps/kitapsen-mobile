import 'package:flutter/foundation.dart';
import 'package:html/dom.dart' as html_dom;
import 'package:fushi_engine/epub/epub_book.dart';

/// 书内全文搜索（在后台 isolate 里逐章扫描）。
abstract class BookSearch {
  static Future<List<BookSearchResult>> searchBook(
    EpubBook book,
    String query,
  ) async {
    if (query.isEmpty) return const <BookSearchResult>[];

    final List<String> chapterHtmls = List<String>.generate(
      book.chapters.length,
      (i) => book.chapters[i].html,
    );

    return compute(
      _searchIsolate,
      _SearchParams(chapterHtmls: chapterHtmls, query: query),
    );
  }

}

// ── 搜索 isolate ─────────────────────────────────────────────────────────────

class _SearchParams {
  const _SearchParams({required this.chapterHtmls, required this.query});
  final List<String> chapterHtmls;
  final String query;
}

List<BookSearchResult> _searchIsolate(_SearchParams params) {
  final String query = params.query;
  final String needle = query.toLowerCase();
  const int contextRadius = 30;
  const int maxResults = 500;
  final RegExp collapseWs = RegExp(r'\s+');

  final List<BookSearchResult> results = <BookSearchResult>[];

  for (int i = 0; i < params.chapterHtmls.length; i++) {
    final String domText = _chapterDomText(params.chapterHtmls[i]);
    final String haystack = domText.toLowerCase();
    int start = 0;
    while (true) {
      final int idx = haystack.indexOf(needle, start);
      if (idx < 0) break;

      final int ctxStart = (idx - contextRadius).clamp(0, domText.length);
      final int ctxEnd =
          (idx + query.length + contextRadius).clamp(0, domText.length);
      final String rawCtx = domText.substring(ctxStart, ctxEnd);
      final String rawMatch = domText.substring(idx, idx + query.length);

      // Fold whitespace in context for display, recalculate matchStart.
      final String context = rawCtx.replaceAll(collapseWs, ' ');
      final String matchWord = rawMatch.replaceAll(collapseWs, ' ');
      final int matchStart =
          context.toLowerCase().indexOf(matchWord.toLowerCase());

      results.add(BookSearchResult(
        sectionIndex: i,
        charOffset: idx,
        context: context,
        matchStart: matchStart >= 0 ? matchStart : 0,
      ));

      if (results.length >= maxResults) return results;
      start = idx + 1;
    }
  }

  return results;
}

/// Extract text matching JS TreeWalker output: concatenate text nodes,
/// skip rt/rp content, NO whitespace folding. This produces the same
/// coordinate space as JS scrollToSearchMatch().
///
/// BUG-2017：全书搜索必须与 [EpubBook.chapterPlainText] 共用同一个 DOM 解析入口
/// [EpubBook.parseChapterHtml]。裸 HTML5 解析在 kobo 化 XHTML（head 里一行自闭合
/// `<script src="…"/>`、全文无 `</script>`）上会把整个 `<body>` 吞成 script 文本
/// → `doc.body` 为空 → 这类书全书搜索恒零结果。
String _chapterDomText(String html) {
  final html_dom.Document doc = EpubBook.parseChapterHtml(html);
  final html_dom.Element? body = doc.body;
  if (body == null) return '';
  final StringBuffer buf = StringBuffer();
  _collectTextNodes(body, buf);
  return buf.toString();
}

void _collectTextNodes(html_dom.Node node, StringBuffer buf) {
  if (node is html_dom.Element) {
    final String tag = node.localName ?? '';
    if (tag == 'rt' || tag == 'rp') return;
    for (final html_dom.Node child in node.nodes) {
      _collectTextNodes(child, buf);
    }
  } else if (node is html_dom.Text) {
    buf.write(node.text);
  }
}

// ── 数据类 ───────────────────────────────────────────────────────────────────

class TtuTocEntry {
  const TtuTocEntry({
    required this.index,
    required this.label,
    this.parent,
    this.depth = 0,
    this.fragment,
    this.anchorCharOffset,
  });

  final int index;
  final String label;
  final String? parent;
  final int depth;

  /// 目录项 href 里的 `#fragment`（章内锚），没有则 null。EPUB 里「一个 xhtml
  /// 装整卷、目录靠锚点分节」是常见结构：那些条目的 [index] 全指向同一个 spine
  /// 章，**只有 fragment 能区分它们**。丢掉它就等于每一条都跳章首。
  final String? fragment;

  /// [fragment] 锚点在章 [index] 内的字符偏移（`countStudyChars` 口径，与阅读器
  /// 回报的章内 `charOffset` 同尺）；无锚点 / 还没算出来 / 锚点在章里找不到时为
  /// null，判「当前读到哪一条」时按章首 0 处理（[resolveCurrentTocEntry]）。
  final int? anchorCharOffset;

  /// [anchorCharOffset] 的判位值：无锚点即章首。
  int get charOffsetInChapter => anchorCharOffset ?? 0;

  bool get isHeader => index < 0;
}

class BookSearchResult {

  const BookSearchResult({
    required this.sectionIndex,
    required this.charOffset,
    required this.context,
    required this.matchStart,
  });

  final int sectionIndex;
  final int charOffset;
  final String context;
  final int matchStart;
}
