import '../audiobook/audiobook_model.dart';
import 'cue_parse_dispatch.dart';
import 'cue_timeline_scanner.dart';
import 'srt_parser.dart';

/// 解析 YouTube SubViewer（.sbv）字幕。
///
/// ```
/// 0:00:01.000,0:00:04.230
/// 吾輩は猫である。
///
/// 0:00:04.500,0:00:08.100
/// 名前はまだない。
/// ```
///
/// 与 SRT / VTT 同一个逐行扫描器（[scanTimedCues]），只是时间行形如 `a,b`。
class SbvParser {
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

  static List<AudioCue> parseString({
    required String content,
    required String bookKey,
    String chapterHref = defaultChapter,
    int audioFileIndex = 0,
  }) {
    return buildTimedTextCues(
      scanTimedCues(content, timingLine: parseSbvTimingLine),
      bookKey: bookKey,
      chapterHref: chapterHref,
      audioFileIndex: audioFileIndex,
    );
  }
}
