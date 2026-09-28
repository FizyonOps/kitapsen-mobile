/// SRT / WebVTT 共用的「时间行 + 文本行」扫描器。
///
/// 旧实现两个解析器各自 `split(RegExp(r'\n{2,}'))` 切 block 再逐 block 找时间行，
/// 这套数据模型有三处结构性缺陷（BUG-2748）：
/// - **仅含空白的分隔行**（`" \n"`，转换器 / 编辑器常见）不等于 `\n\n`，整份文件被并成
///   一个 block：VTT 下它以 `WEBVTT` 开头被当头部整块跳过 → 0 条 cue → 「字幕加载失败」；
///   SRT 下只剩第一条，后续 cue 的序号与时间行被拼进正文。
/// - 头部与首条 cue 之间缺空行时首条 cue 随头部一起丢失。
/// - SRT 要求 block ≥3 行，没有序号行的单行 cue 被丢弃。
///
/// 这里改成逐行状态机，消掉 block 概念与「头部 / NOTE / STYLE / 序号行」这些特例：
/// **能解析成时间行的行开启一条新 cue；空白行结束当前 cue；cue 外的其它行一律忽略。**
/// 头部、NOTE、STYLE、REGION、SRT 序号全落在「cue 外的其它行」里，自然被跳过。
library;

import '../audiobook/audiobook_model.dart';
import 'strip_html_tags.dart';
import 'subtitle_markup.dart';

/// 一条原始 cue：起止毫秒 + 未经标签处理的文本行（已 trim、非空）。
typedef RawTimedCue = ({int startMs, int endMs, List<String> lines});

/// 逐行扫描 [content]，产出原始 cue 列表（顺序同文件）。去 BOM、统一换行。
///
/// 时间行出现在 cue 文本中间（文件缺少空行分隔）时视为新 cue 的开始——字幕规范
/// 本就禁止正文含 `-->`，按新 cue 处理比把时间码拼进正文更接近作者意图。
///
/// [timingLine] 决定「什么算时间行」：默认 SRT / VTT 的 `a --> b`，SBV 传
/// [parseSbvTimingLine]（`a,b`）。
List<RawTimedCue> scanTimedCues(
  String content, {
  (int, int)? Function(String line) timingLine = parseTimingLine,
}) {
  final String body = content.startsWith('﻿') ? content.substring(1) : content;
  final List<RawTimedCue> cues = <RawTimedCue>[];
  (int, int)? times;
  List<String> lines = <String>[];

  void flush() {
    if (times != null && lines.isNotEmpty) {
      cues.add((startMs: times!.$1, endMs: times!.$2, lines: lines));
    }
    times = null;
    lines = <String>[];
  }

  for (final String raw in body.split(_newlineRe)) {
    final String line = raw.trim();
    if (line.isEmpty) {
      flush();
      continue;
    }
    final (int, int)? parsed = timingLine(line);
    if (parsed != null) {
      flush();
      times = parsed;
      continue;
    }
    if (times != null) lines.add(line);
  }
  flush();
  return cues;
}

final RegExp _newlineRe = RegExp(r'\r\n|\r|\n');
final RegExp _whitespaceRe = RegExp(r'\s+');

/// 解析 `<start> --> <end>[ 设置...]`；不是时间行返回 null。
///
/// 结束时间之后的内容（VTT `align:start position:0%`、部分 SRT 的 `X1:… Y1:…`）
/// 按空白切开只取第一个 token。
(int, int)? parseTimingLine(String line) {
  final int arrow = line.indexOf('-->');
  if (arrow < 0) return null;
  final int? start = parseTimecodeMs(line.substring(0, arrow).trim());
  final String rest = line.substring(arrow + 3).trim();
  if (start == null || rest.isEmpty) return null;
  final int? end = parseTimecodeMs(rest.split(_whitespaceRe).first);
  if (end == null) return null;
  return (start, end);
}

/// YouTube SBV 时间行 `0:00:01.000,0:00:04.000`；不是时间行返回 null。
(int, int)? parseSbvTimingLine(String line) {
  final List<String> parts = line.split(',');
  if (parts.length != 2) return null;
  final int? start = parseTimecodeMs(parts[0].trim());
  final int? end = parseTimecodeMs(parts[1].trim());
  if (start == null || end == null) return null;
  return (start, end);
}

/// `[H:]MM:SS[.,]fff` 与 `[H:]MM:SS`（无毫秒）。小数位按「秒的小数」解释：
/// `.5` = 500ms，`.1234` 截到 123ms。分、秒 ≥60 视为非法。
final RegExp _timecodeRe = RegExp(
  r'^(?:(\d+):)?(\d{1,2}):(\d{2})(?:[.,](\d+))?$',
);

/// 时间码转毫秒；格式不合法返回 null。
int? parseTimecodeMs(String timecode) {
  final RegExpMatch? m = _timecodeRe.firstMatch(timecode);
  if (m == null) return null;
  final int h = m.group(1) == null ? 0 : int.parse(m.group(1)!);
  final int min = int.parse(m.group(2)!);
  final int sec = int.parse(m.group(3)!);
  if (min >= 60 || sec >= 60) return null;
  final String frac = m.group(4) ?? '0';
  final int ms = int.parse(
    frac.length >= 3 ? frac.substring(0, 3) : frac.padRight(3, '0'),
  );
  return h * 3600000 + min * 60000 + sec * 1000 + ms;
}

/// 原始 cue → [AudioCue]：SRT / VTT / SBV / SAMI / TTML 共用的收尾段。
///
/// 多行正文以空格连接；先剥 HTML/VTT 行内标签（含实体解码，[stripHtmlTags]），
/// 再交 markup 解析 ASS override 块（两者正交）。剥完为空的 cue 丢弃，
/// `sentenceIndex` 只对保留下来的 cue 连续编号。
List<AudioCue> buildTimedTextCues(
  List<RawTimedCue> raw, {
  required String bookKey,
  required String chapterHref,
  required int audioFileIndex,
}) {
  final List<AudioCue> cues = <AudioCue>[];
  for (final RawTimedCue cue in raw) {
    final SubtitleMarkup markup = parseSubtitleMarkup(
      stripHtmlTags(cue.lines.join(' ')),
    );
    final String text = markup.plainText;
    if (text.isEmpty) continue;
    final int index = cues.length;
    cues.add(
      AudioCue()
        ..bookKey = bookKey
        ..chapterHref = chapterHref
        ..sentenceIndex = index
        ..textFragmentId = '[data-cue-id="$index"]'
        ..text = text
        ..markup = markup
        ..startMs = cue.startMs
        ..endMs = cue.endMs
        ..audioFileIndex = audioFileIndex,
    );
  }
  return cues;
}
