/// 字幕行内标签剥离共享实现（G11 收敛：此前 srt / vtt / lrc 三个解析器各持一份
/// 逐字相同的正则替换）。

/// 注音（振假名）标注元素：`<rt>` 是读音本身，`<rp>` 是给不支持 ruby 的渲染器看的
/// 回退括号，`<rtc>` 是读音容器。三者的**内容都不是正文**——只有 ruby base 是。
/// 光删标签保留内容会把读音拼进正文（`<ruby>震<rt>ふる</rt></ruby>` → `震ふる`），
/// 污染查词 / 制卡 sentence / 字数统计，故整段丢弃（BUG-1161）。
///
/// 元素集合与 EPUB 侧 `EpubBook._removeRubyAnnotations`（`querySelectorAll('rt, rp, rtc')`
/// 逐个 remove）相同：`rt` / `rp` / `rtc` 三者内容都丢、只留 ruby base。阅读器 JS 的
/// `isFurigana()` 只 `closest('rt, rp')`、**不含 `rtc`**（既有差异，见 BUG-711）；合法 HTML 里
/// `<rtc>` 总包着 `<rt>`，实际结果收敛，但别把这里说成「与 JS 一致」。
///
/// **这是正则近似，不是 DOM 解析。** EPUB 侧走 `package:html` 真解析器，实体、嵌套、畸形标签
/// 由解析器兜底；字幕侧只有一行纯文本，没有解析器可用。两侧因此只在**良构输入**上等价，
/// 在**畸形输入**上可能分岔。本实现的取向是：认不出的形态整体不匹配、退回下面的通用模式
/// （= 旧行为），宁可多留一个假名，也绝不吃掉用户真正要读的正文。
///
/// 一条规则同时吃下两种闭合形态，不为「缺 `</rt>`」单开分支：
/// - 显式闭合 `<rt>ふる</rt>`（WebVTT 要求闭合）；
/// - 隐式闭合 `<ruby>震<rt>ふる</ruby>`（HTML 允许省略 `</rt>`，由 `</ruby>` 收尾）。
///
/// 做法是把注音内容定义成「开标签之后、下一个 ruby 家族标签之前的所有字符」，可选地
/// 连同自己的闭合标签一起吃掉。剩下的 `<ruby>` / `</ruby>` / `<rb>` 外壳标签由下面的
/// 通用模式删掉、内容（= ruby base）保留。
///
/// 开标签的属性段写成 `(?:[^<>/]|/(?!>))*` 而不是 `[^>]*`，这是兑现上面那句承诺的关键：
/// - **不许跨越 `<`**：`<ruby>漢<rt かん</ruby>の話`（缺 `>`）不能借 `</ruby>` 的 `>` 把开标签凑
///   「合法」，否则内容组会把后面的正文「の話」一路吃光。整体不匹配 → 退回旧行为 `漢の話`。
/// - **不许把自闭合当成有内容的开标签**：`a<rt/>b`（TTML / XHTML 派生字幕里真实存在）同理
///   → 退回旧行为 `ab`，而不是把 `b` 吞掉。
final RegExp _rubyAnnotationPattern = RegExp(
  r'<(?:rt|rp|rtc)\b(?:[^<>/]|/(?!>))*>'
  r'(?:(?!</?(?:ruby|rt|rp|rtc)\b).)*(?:</(?:rt|rp|rtc)\s*>)?',
  caseSensitive: false,
  dotAll: true,
);

/// `<...>` 形式的行内标签：HTML/VTT（`<i>`、`<b>`、`<ruby>`、`<c.className>`）
/// 与增强 LRC 词级时间标签（`<MM:SS.xx>`）同形，统一按此模式剥离。
final RegExp _inlineTagPattern = RegExp('<[^>]+>');

/// 剥离字幕文本中的 `<...>` 行内标签：仅移除标签本身、保留标签内文本，
/// 并去除首尾空白。例如 `<i>こんにちは</i>` → `こんにちは`。
///
/// 例外是注音标注（`<rt>` / `<rp>` / `<rtc>`）：内容随标签一起丢弃，只留 ruby base
/// （`<ruby>震<rt>ふる</rt></ruby>` → `震`），见 [_rubyAnnotationPattern]。
///
/// 注意：hibiki_anki 的 `BaseAnkiRepository.previewFromFieldValue` 有一份
/// **故意不同**的实现——那边把标签替换成**空格**再统一折叠（Anki 字段 HTML 里
/// `<br>` / 块级标签承担换行分词，直接删空会把相邻词粘连）；而字幕行内标签
/// 紧贴正文，替换成空格反而会在日文句中引入假空格。两份实现不强并。
String stripHtmlTags(String text) => decodeHtmlEntities(
      text
          .replaceAll(_rubyAnnotationPattern, '')
          .replaceAll(_inlineTagPattern, ''),
    ).trim();

/// 字符实体：命名实体（字幕里实际出现的那几个）与十进制 / 十六进制数字实体。
final RegExp _entityPattern = RegExp(r'&(#x[0-9a-fA-F]+|#\d+|[a-zA-Z]+);');

const Map<String, String> _namedEntities = <String, String>{
  'amp': '&',
  'lt': '<',
  'gt': '>',
  'quot': '"',
  'apos': "'",
  'nbsp': '\u00A0',
  'lrm': '\u200E',
  'rlm': '\u200F',
};

/// 解码 HTML / WebVTT 字符实体（`&amp;` `&lt;` `&nbsp;` `&#12354;` `&#x3042;`）。
///
/// WebVTT 规范要求正文里的 `&` `<` `>` 写成实体，SAMI / TTML 与不少转换器产出的
/// SRT 也带实体；不解码就原样显示 `Tom &amp; Jerry`（BUG-2748）。必须在**剥标签之后**
/// 解码，否则 `&lt;b&gt;` 解出的 `<b>` 会被当标签吃掉。认不出的实体原样保留。
String decodeHtmlEntities(String text) {
  if (!text.contains('&')) return text;
  return text.replaceAllMapped(_entityPattern, (Match m) {
    final String body = m.group(1)!;
    if (body.startsWith('#')) {
      final bool hex = body.length > 1 && (body[1] == 'x' || body[1] == 'X');
      final int? code = int.tryParse(
        hex ? body.substring(2) : body.substring(1),
        radix: hex ? 16 : 10,
      );
      if (code == null || code <= 0 || code > 0x10FFFF) return m.group(0)!;
      return String.fromCharCode(code);
    }
    return _namedEntities[body.toLowerCase()] ?? m.group(0)!;
  });
}
