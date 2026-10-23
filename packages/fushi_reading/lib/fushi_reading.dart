/// 零 Flutter 的阅读支撑：文本读取、阅读位置 / 书签 / 收藏句仓储、学习时钟、
/// EPUB 构建。
library fushi_reading;

// Parsers
export 'src/parsers/text_file_io.dart';

// Reader state
export 'src/reading/file_path_sort.dart';
export 'src/reading/reader_position_model.dart';
export 'src/reading/reader_position_repository.dart';
export 'src/reading/study_clock.dart';
export 'src/reading/bookmark_repository.dart';
export 'src/reading/favorite_sentence_repository.dart';

// EPUB building
export 'src/matching/epub_builder.dart';
