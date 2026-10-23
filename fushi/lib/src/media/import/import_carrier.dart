import 'package:path/path.dart' as p;

import 'package:fushi_engine/epub/text_to_epub.dart';

/// 一个待导入文件的**载体身份**：它到底是哪种东西，因而该交给哪个 importer。
enum ImportCarrier {
  /// PDF。走 `PdfImporter`（真渲染，不经 TextToEpub 文本转换）。
  pdf,

  /// EPUB。走 `EpubImporter.importFromPath`。
  epub,

  /// 可转成 EPUB 的纯文本类（txt/md/html/…），以及不认识的扩展名。
  /// 走 `TextToEpub.convert` + `EpubImporter.import`。
  text,
}

/// 按扩展名判定 [path] 的载体身份。
ImportCarrier classifyImportCarrier(String path) {
  final String ext = p.extension(path).toLowerCase();

  // PDF 必须在下面的文本分支之前早退——否则 PDF 二进制会被当文本转成乱码 EPUB。
  if (ext == '.pdf') return ImportCarrier.pdf;

  // 非 epub/zip 的一切（含无扩展名文件）都尝试按文本转 EPUB——保持既有兜底语义。
  if (TextToEpub.isSupported(path) || (ext != '.epub' && ext != '.zip')) {
    return ImportCarrier.text;
  }
  return ImportCarrier.epub;
}
