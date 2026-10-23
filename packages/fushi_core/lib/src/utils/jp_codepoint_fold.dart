/// 日文归一化**码点原语**（G7 去重）：全角 ASCII 折叠、片假名→平假名平移、
/// 半角片假名折叠查表。
///
/// 此前多套 normalizer——媒体库搜索 `normalizeMediaSearchText`、视频刮削
/// `TitleNormalizer`、有声书/阅读器匹配 `AudioTextNormalizer` 及其
/// `ReaderPaginationScripts` Dart 影子——各自手写同一批码点变换。本文件只收拢
/// **底层原语**；策略层（保留白名单 / 丢弃集 / 繁简映射 / 装饰符处理）是各
/// normalizer 的真实语义差异，仍留在各自实现里，不在此统一。
///
/// ⚠️ 这些变换参与搜索归一化与 sasayaki 匹配坐标系：任何输出变化都会改变既有
/// 匹配/高亮行为。改动必须保持逐码点输出不变（各 normalizer 既有测试 +
/// `fushi/test/utils/jp_codepoint_fold_test.dart` 的 JS parity 测试锁定）。
library;

/// 全角 ASCII（U+FF01..U+FF5E ！..～）→ 半角 ASCII（平移 -0xFEE0）；范围外
/// 码点原样返回。**不含**全角空格 U+3000——各策略对它语义不同（丢弃 / 转半角
/// 空格），由调用方自理。
int fullwidthAsciiToHalfwidth(int codePoint) {
  if (codePoint >= 0xFF01 && codePoint <= 0xFF5E) {
    return codePoint - 0xFEE0;
  }
  return codePoint;
}

/// 片假名基本区（U+30A1..U+30F6 ァ..ヶ）→ 平假名（平移 -0x60）；范围外原样
/// 返回。刻意**不含**长音符 ー(U+30FC) 与叠字符 ヽヾ——它们无平假名基本区对应。
int katakanaToHiragana(int codePoint) {
  if (codePoint >= 0x30A1 && codePoint <= 0x30F6) {
    return codePoint - 0x60;
  }
  return codePoint;
}

