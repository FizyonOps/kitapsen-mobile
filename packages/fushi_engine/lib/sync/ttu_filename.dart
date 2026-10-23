

/// ッツ Ebook Reader 兼容的文件名生成/解析/sanitize。
///
/// 文件名格式: `{type}_1_6_{timestamp}_{metrics}.json`
/// 文件夹名: sanitized book title（与 ッツ web 实现一致）。
///
/// 注意：hibiki_core 有一份逐字节等价的私有副本（`src/utils/ttu_sanitize.dart`），
/// 供 v38 拆集迁移在 core 内派生视频每集 bookUid（core 不能依赖 app 层）。两份由
/// `video_book_uid_core_parity_test` 守卫；本函数是 app 侧真相源，改了必须同步那份。
String sanitizeTtuFilename(String title) {
  String result = title;
  if (result.endsWith(' ')) {
    result = '${result.substring(0, result.length - 1)}~ttu-spc~';
  }
  if (result.endsWith('.')) {
    result = '${result.substring(0, result.length - 1)}~ttu-dend~';
  }
  result = result.replaceAll('*', '~ttu-star~');
  result = result.replaceAllMapped(
    RegExp(r'[/?\<>\\:|%"]'),
    (match) => match[0]!
        .codeUnits
        .map((c) => '%${c.toRadixString(16).toUpperCase().padLeft(2, '0')}')
        .join(),
  );
  return result;
}
