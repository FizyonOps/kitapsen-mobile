import 'package:xml/xml.dart';

import '../audiobook/audiobook_model.dart';
import 'cue_parse_dispatch.dart';
import 'cue_timeline_scanner.dart';
import 'srt_parser.dart';

/// 解析 TTML / DFXP（.ttml / .dfxp）字幕——Netflix、Amazon 等流媒体下载的常见格式。
///
/// ```xml
/// <tt xmlns="http://www.w3.org/ns/ttml" ttp:tickRate="10000000">
///   <body><div>
///     <p begin="00:00:01.000" end="00:00:04.230">吾輩は<br/>猫である。</p>
///     <p begin="45000000t" dur="30000000t">名前はまだない。</p>
///   </div></body>
/// </tt>
/// ```
///
/// 每个 `<p>` 是一条 cue；`<br/>` 换行，`<span>` 只取文字。时间表达式支持
/// clock（`HH:MM:SS[.fff]` / `HH:MM:SS:FF` 帧）与 offset（`12.5s` `500ms` `2m` `1h`
/// `24f` `10000000t`）；`end` 缺失时用 `dur`。时间不可解析的 `<p>` 跳过。
class TtmlParser {
  static const String defaultChapter = SrtParser.defaultChapter;

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

  /// XML 不合法时抛 [XmlException]（调用方按「解析失败」分类）。
  static List<AudioCue> parseString({
    required String content,
    required String bookKey,
    String chapterHref = defaultChapter,
    int audioFileIndex = 0,
  }) {
    return buildTimedTextCues(
      scanTtmlCues(content),
      bookKey: bookKey,
      chapterHref: chapterHref,
      audioFileIndex: audioFileIndex,
    );
  }

  static List<RawTimedCue> scanTtmlCues(String content) {
    final String body = content.startsWith('﻿')
        ? content.substring(1)
        : content;
    final XmlDocument doc = XmlDocument.parse(body);
    final XmlElement root = doc.rootElement;
    final _TtmlClock clock = _TtmlClock(
      tickRate: _numAttr(root, 'tickRate'),
      frameRate: _numAttr(root, 'frameRate'),
    );
    final List<RawTimedCue> cues = <RawTimedCue>[];
    for (final XmlElement p in root.descendantElements) {
      if (p.localName != 'p') continue;
      final int? start = clock.parse(_attr(p, 'begin'));
      if (start == null) continue;
      int? end = clock.parse(_attr(p, 'end'));
      if (end == null) {
        final int? dur = clock.parse(_attr(p, 'dur'));
        end = dur == null ? null : start + dur;
      }
      if (end == null || end <= start) continue;
      final List<String> lines = _paragraphText(p)
          .split('\n')
          .map((String l) => l.trim())
          .where((String l) => l.isNotEmpty)
          .toList();
      if (lines.isEmpty) continue;
      cues.add((startMs: start, endMs: end, lines: lines));
    }
    cues.sort((RawTimedCue a, RawTimedCue b) => a.startMs.compareTo(b.startMs));
    return cues;
  }

  /// `<p>` 的正文：文本节点照抄，`<br>` 换行，其余元素（`<span>` 等）递归取字。
  ///
  /// XML 解析器已经解码过实体，而共用收尾段 [buildTimedTextCues] 还会再剥一次
  /// 标签、解一次实体；所以文本节点在这里**重新转义** `& < >`，让那一次解码
  /// 恰好还原原字符（台词里的字面 `<b>` / `&lt;` 不会被当标签吃掉或二次解码）。
  static String _paragraphText(XmlElement element) {
    final StringBuffer out = StringBuffer();
    void walk(XmlNode node) {
      for (final XmlNode child in node.children) {
        if (child is XmlText || child is XmlCDATA) {
          // 源文件里的排版换行 / 缩进不是字幕换行，折成空格。
          out.write(
            child.value!
                .replaceAll(RegExp(r'\s+'), ' ')
                .replaceAll('&', '&amp;')
                .replaceAll('<', '&lt;')
                .replaceAll('>', '&gt;'),
          );
        } else if (child is XmlElement) {
          if (child.localName == 'br') {
            out.write('\n');
          } else {
            walk(child);
          }
        }
      }
    }

    walk(element);
    return out.toString();
  }

  /// 按本地名取属性，忽略命名空间前缀（`ttp:tickRate` / `tickRate` 都认）。
  static String? _attr(XmlElement element, String localName) {
    for (final XmlAttribute a in element.attributes) {
      if (a.name.local == localName) return a.value;
    }
    return null;
  }

  static double? _numAttr(XmlElement element, String localName) {
    final String? raw = _attr(element, localName);
    return raw == null ? null : double.tryParse(raw.trim());
  }
}

/// TTML 时间表达式求值；`tickRate` / `frameRate` 取自 `<tt>` 根元素。
class _TtmlClock {
  _TtmlClock({double? tickRate, double? frameRate})
    : tickRate = (tickRate == null || tickRate <= 0) ? 1 : tickRate,
      frameRate = (frameRate == null || frameRate <= 0) ? 30 : frameRate;

  final double tickRate;
  final double frameRate;

  static final RegExp _frameClockRe = RegExp(
    r'^(\d+):(\d{2}):(\d{2}):(\d+(?:\.\d+)?)$',
  );
  static final RegExp _offsetRe = RegExp(r'^(\d+(?:\.\d+)?)(h|ms|m|s|f|t)$');

  int? parse(String? expression) {
    if (expression == null) return null;
    final String e = expression.trim();
    if (e.isEmpty) return null;
    final int? clock = parseTimecodeMs(e);
    if (clock != null) return clock;
    final RegExpMatch? frames = _frameClockRe.firstMatch(e);
    if (frames != null) {
      final int h = int.parse(frames.group(1)!);
      final int m = int.parse(frames.group(2)!);
      final int s = int.parse(frames.group(3)!);
      final double f = double.parse(frames.group(4)!);
      return h * 3600000 +
          m * 60000 +
          s * 1000 +
          (f * 1000 / frameRate).round();
    }
    final RegExpMatch? offset = _offsetRe.firstMatch(e);
    if (offset == null) return null;
    final double value = double.parse(offset.group(1)!);
    final double ms = switch (offset.group(2)!) {
      'h' => value * 3600000,
      'm' => value * 60000,
      's' => value * 1000,
      'ms' => value,
      'f' => value * 1000 / frameRate,
      _ => value * 1000 / tickRate,
    };
    return ms.round();
  }
}
