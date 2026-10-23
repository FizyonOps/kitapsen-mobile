/// fushi_audio 的**零 Flutter** 子集：字幕解析、有声书仓储、匹配对齐。
///
/// 无头服务端（`packages/fushi_server`）import 这个 barrel。本包 pubspec 已不
/// 声明 Flutter SDK，全 barrel `fushi_audio.dart` 与本 barrel 等价；原来的重文件
/// （just_audio 播放控制器 / 存储平台装配 / 字符集插件实现）已搬到 app 的
/// `fushi/lib/src/media/audiobook/`，经本包的装配点注入。
///
/// 守卫：`fushi/test/build/fushi_engine_purity_guard_test.dart`。
library fushi_audio_core;

// Parsers
export 'src/parsers/text_file_io.dart';
export 'src/parsers/subtitle_markup.dart';

// Audiobook core
export 'src/audiobook/audiobook_model.dart';
export 'src/audiobook/audiobook_health.dart';
export 'src/audiobook/audiobook_repository.dart';
export 'src/audiobook/audiobook_storage.dart';
export 'src/audiobook/audiobook_local_files.dart';
export 'src/audiobook/audio_file_sort.dart';
export 'src/audiobook/srt_book_model.dart';
export 'src/audiobook/srt_book_repository.dart';
export 'src/audiobook/reader_position_model.dart';
export 'src/audiobook/reader_position_repository.dart';
export 'src/audiobook/study_clock.dart';
export 'src/audiobook/bookmark_repository.dart';
export 'src/audiobook/favorite_sentence_repository.dart';

// Matching & alignment
export 'src/matching/epub_cue_matcher.dart';
export 'src/matching/epub_builder.dart';
