import '../audiobook/audiobook_model.dart';
import 'cue_parse_dispatch.dart';
import 'cue_timeline_scanner.dart';
import 'srt_parser.dart';

/// 解析 SAMI（.smi / .sami）字幕——韩文字幕站的主流格式。
///
/// ```
/// <SAMI><HEAD><STYLE>…</STYLE></HEAD><BODY>
/// <SYNC Start=1000><P Class=KRCC>안녕<br>하세요
/// <SYNC Start=3000><P Class=KRCC>&nbsp;
/// </BODY></SAMI>
/// ```
///
/// SAMI 只有起点没有终点：每个 `<SYNC Start=N>` 的内容一直显示到下一个 SYNC。
/// 所以「清屏」就是一个内容为 `&nbsp;` 的 SYNC——剥完为空，由共用收尾段
/// [buildTimedTextCues] 丢掉，前一句的终点自然落在它的起点上，不需要特判。
///
/// 多语言 SAMI 每个 SYNC 下有多个 `<P Class=XXCC>`；只取文件里**第一个出现**的
/// Class（通常是主语言），避免两种语言拼成一句。没有 `<P>` 的 SYNC 取整段内容。
/// 这不是 HTML 解析器：SAMI 实际文件大量缺闭合标签、属性不加引号，正则按
/// 「SYNC 到下一个 SYNC」切段比 DOM 更贴近真实文件。
class SamiParser {
  static const String defaultChapter = SrtParser.defaultChapter;

  /// 文件最后一句没有下一个 SYNC 给终点时的显示时长。
  static const int lastCueDurationMs = 5000;

  static Future<List<AudioCue>> parseStringAsync({
    required String content,
    required String bookKey,
    String chapterHref = defaultChapter,
    int audioFileIndex = 0,
  }) {
    return CueParseDispatch.run(
      content: content,
      parse: () => parseString(
        content: content,
        bookKey: bookKey,
        chapterHref: chapterHref,
        audioFileIndex: audioFileIndex,
      ),
    );
  }

  static List<AudioCue> parseString({
    required String content,
    required String bookKey,
    String chapterHref = defaultChapter,
    int audioFileIndex = 0,
  }) {
    return buildTimedTextCues(
      scanSamiCues(content),
      bookKey: bookKey,
      chapterHref: chapterHref,
      audioFileIndex: audioFileIndex,
    );
  }

  static final RegExp _syncRe = RegExp(
    r'''<sync\b[^>]*?\bstart\s*=\s*["']?(\d+)[^>]*>''',
    caseSensitive: false,
  );
  static final RegExp _paragraphRe = RegExp(
    r'''<p\b([^>]*)>''',
    caseSensitive: false,
  );
  static final RegExp _classRe = RegExp(
    r'''\bclass\s*=\s*["']?([\w-]+)''',
    caseSensitive: false,
  );
  static final RegExp _brRe = RegExp(r'<br\s*/?>', caseSensitive: false);
  static final RegExp _bodyEndRe = RegExp(
    r'</body\s*>|</sami\s*>',
    caseSensitive: false,
  );

  /// SAMI → 原始 cue（正文行未剥标签，交 [buildTimedTextCues]）。
  static List<RawTimedCue> scanSamiCues(String content) {
    final List<RegExpMatch> syncs = _syncRe.allMatches(content).toList();
    String? primaryClass;
    final List<RawTimedCue> cues = <RawTimedCue>[];
    for (int i = 0; i < syncs.length; i++) {
      final RegExpMatch sync = syncs[i];
      final int start = int.parse(sync.group(1)!);
      final bool last = i + 1 == syncs.length;
      final int end = last
          ? start + lastCueDurationMs
          : int.parse(syncs[i + 1].group(1)!);
      String body = content.substring(
        sync.end,
        last ? content.length : syncs[i + 1].start,
      );
      final RegExpMatch? tail = _bodyEndRe.firstMatch(body);
      if (tail != null) body = body.substring(0, tail.start);

      final ({String? cls, String text}) picked = _pickParagraph(
        body,
        primaryClass,
      );
      primaryClass ??= picked.cls;
      if (end <= start) continue;
      final List<String> lines = picked.text
          .replaceAll(_brRe, '\n')
          .split('\n')
          .map((String l) => l.trim())
          .where((String l) => l.isNotEmpty)
          .toList();
      if (lines.isEmpty) continue;
      cues.add((startMs: start, endMs: end, lines: lines));
    }
    return cues;
  }

  /// 在一个 SYNC 段里挑正文：有 `<P>` 就取 Class == [primaryClass] 的那段
  /// （[primaryClass] 为 null 时取第一段并把它的 Class 作为主语言）；没有 `<P>`
  /// 取整段。
  static ({String? cls, String text}) _pickParagraph(
    String body,
    String? primaryClass,
  ) {
    final List<RegExpMatch> paragraphs = _paragraphRe.allMatches(body).toList();
    if (paragraphs.isEmpty) return (cls: null, text: body);
    for (int i = 0; i < paragraphs.length; i++) {
      final String? cls = _classRe
          .firstMatch(paragraphs[i].group(1)!)
          ?.group(1)
          ?.toLowerCase();
      if (primaryClass != null && cls != primaryClass) continue;
      final int textEnd = i + 1 < paragraphs.length
          ? paragraphs[i + 1].start
          : body.length;
      return (cls: cls, text: body.substring(paragraphs[i].end, textEnd));
    }
    return (cls: primaryClass, text: '');
  }
}
