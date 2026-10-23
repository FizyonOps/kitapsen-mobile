import 'package:fushi_core/fushi_core.dart' show BookFormat, EpubBookRow;
import 'package:path/path.dart' as p;

/// 书在磁盘上的主产物绝对路径——「这本书的源在哪」的**唯一**真相源。
/// `book_format_rebuild.dart` 的探测、PDF 阅读器开文件、书架「打开文件位置」都从
/// 这里取，不各自拼一份。
///
/// EPUB / PDF / 漫画是同一张 `EpubBooks` 表上的三种书身份，但主产物形态不同，
/// **不能**一律 `p.join(extractDir, epubPath)`：
/// - `epub`：主产物是**解压书目录本身**。本仓导入即解压、从不在书目录里留一份
///   独立 `.epub`；[EpubBookRow.epubPath] 只是导入时的原始文件名，拼出来的路径
///   永远指不到真实文件（BUG-088 就此坏过一次：同步靠它判「文件存在」，静默跳过
///   了每一次上传）。TextToEpub 文本书、有声书配对壳同属此类。
/// - `pdf`：`extractDir/document.pdf`，导入时真的拷进去了。
/// - `manga`：`extractDir/manga.json`，用户手改 mokuro 数据要的就是它。
///
/// 少数历史行 / 数据根迁移过的行把 `epubPath` 写成绝对路径。Windows 盘符形态
/// （`C:\…`）由 [p.join] 契约丢弃前段；POSIX 风格 `/…` 在 Windows 只是 root-relative，
/// 盘符会被保留。当代所有写入方都写相对文件名，这里不为历史形态加分支。
String bookMainFilePath(EpubBookRow row) {
  final BookFormat format = BookFormat.parseOrEpub(row.format);
  return switch (format) {
    BookFormat.epub => row.extractDir,
    BookFormat.pdf => p.join(row.extractDir, row.epubPath),
  };
}
