import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fushi/src/models/app_ui_font_chain.dart';
import 'package:fushi/src/models/cjk_font_families.dart' show CjkFontStyle;
import 'package:fushi/src/models/content_font_chain.dart';
import 'package:fushi/src/reader/reader_settings.dart' show FontTarget;
import 'package:fushi/src/utils/components/fushi_design_tokens.dart';
import 'package:fushi/src/utils/components/fushi_material_components.dart'
    show FushiSelectableChip;
import 'package:fushi/i18n/strings.g.dart';

/// 字体库里某个用途下已启用的一个条目，族名已解析。
@immutable
class FontPreviewCandidate {
  const FontPreviewCandidate({required this.family, required this.path});

  /// 引擎里可用的族名；null = 解析失败或还在解析。
  final String? family;

  /// 导入文件路径；null = 系统字体。
  final String? path;
}

/// 用途 → 这个用途**真正会用到**的族名，与各消费端同一语义：
///
/// 界面 / 正文：整条有序链都参与（缺字按序回退）。
///
/// 预览照这个结果渲染，所以「为什么我排第二的字体没生效」在预览里是看得见的。
List<String> effectiveFontTargetFamilies(
  FontTarget target,
  List<FontPreviewCandidate> enabledInOrder,
) {
  final List<String> families = <String>[];
  for (final FontPreviewCandidate candidate in enabledInOrder) {
    final String? family = candidate.family;
    if (family == null || family.isEmpty) continue;
    if (!families.contains(family)) families.add(family);
  }
  return families;
}

/// 各用途的实时样张：照着真实表面的形态画一块缩样，用该用途**实际生效**的字体链
/// 渲染日文。用途与真实消费端一一对应（[FontTarget] 穷尽 switch，新增用途编译报错）。
///
/// 全部是 Flutter 绘制，不起 WebView：字体库页要随勾选、排序即时刷新，WebView 的
/// 字体注入（词典要把整个字体文件内联成 data: URL）重得多，而字形本身两边一致。
class FontTargetPreview extends StatelessWidget {
  const FontTargetPreview({
    required this.target,
    required this.families,
    this.sampleText,
    super.key,
  });

  final FontTarget target;

  /// [effectiveFontTargetFamilies] 的结果；空 = 该用途没配字体，走系统默认。
  final List<String> families;

  /// 覆盖默认日文样张（系统字体浏览页允许用户输入自己的样字）。
  final String? sampleText;

  @override
  Widget build(BuildContext context) {
    final FushiDesignTokens tokens = FushiDesignTokens.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final String hint = families.isEmpty
        ? t.font_preview_default_font
        : t.font_preview_chain_hint;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        ClipRRect(
          borderRadius: tokens.radii.cardRadius,
          child: KeyedSubtree(
            key: ValueKey<String>('font-target-preview-${target.name}'),
            child: switch (target) {
              FontTarget.appUi => _AppUiPreview(families: families),
              FontTarget.body => _BodyPreview(
                families: families,
                sampleText: sampleText,
              ),
            },
          ),
        ),
        SizedBox(height: tokens.spacing.gap),
        Text(
          families.isEmpty ? hint : '${families.join(' → ')}\n$hint',
          style: tokens.type.metadata.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// 内容（日文）文字的样式：主字体 = 链首，回退 = 链余下 + 平台日文字体。
TextStyle _contentStyle(
  TextStyle base,
  List<String> families, {
  CjkFontStyle cjkStyle = CjkFontStyle.sansSerif,
}) {
  final List<String> chain = contentFontFamilies(
    languageTag: 'ja',
    platform: defaultTargetPlatform,
    style: cjkStyle,
    customFamilies: families,
  );
  return base.copyWith(
    fontFamily: families.isEmpty ? null : chain.first,
    fontFamilyFallback: families.isEmpty ? null : chain.skip(1).toList(),
  );
}

class _AppUiPreview extends StatelessWidget {
  const _AppUiPreview({required this.families});

  final List<String> families;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final FushiDesignTokens tokens = FushiDesignTokens.of(context);
    final List<String> chain = families.isEmpty
        ? const <String>[]
        : appUiFontChain(
            customFamilies: families,
            locale: Localizations.localeOf(context),
            platform: defaultTargetPlatform,
          );
    TextStyle ui(TextStyle? style) => (style ?? const TextStyle()).copyWith(
      fontFamily: chain.isEmpty ? null : chain.first,
      fontFamilyFallback: chain.isEmpty ? null : chain.skip(1).toList(),
    );
    return ColoredBox(
      color: tokens.surfaces.group,
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.card),
        child: Row(
          children: <Widget>[
            Container(
              width: 44,
              height: 60,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: tokens.radii.controlRadius,
              ),
              alignment: Alignment.center,
              child: Text(
                '猫',
                style: ui(
                  theme.textTheme.titleLarge,
                ).copyWith(color: scheme.onPrimaryContainer),
              ),
            ),
            SizedBox(width: tokens.spacing.card),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    t.font_preview_ui_sample_title,
                    style: ui(theme.textTheme.titleMedium),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '吾輩は猫である',
                    style: ui(theme.textTheme.bodyMedium),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    t.font_preview_ui_sample_subtitle,
                    style: ui(
                      theme.textTheme.bodySmall,
                    ).copyWith(color: scheme.onSurfaceVariant),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            SizedBox(width: tokens.spacing.gap),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: tokens.spacing.card,
                vertical: tokens.spacing.gap,
              ),
              decoration: BoxDecoration(
                color: scheme.primary,
                borderRadius: tokens.radii.chipRadius,
              ),
              child: Text(
                t.font_preview_ui_sample_action,
                style: ui(
                  theme.textTheme.labelLarge,
                ).copyWith(color: scheme.onPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 一段带振假名的日文：`(基字, 注音)`，注音为 null 即普通文字。
const List<(String, String?)> _kBodyRubySample = <(String, String?)>[
  ('吾輩', 'わがはい'),
  ('は猫である。名前はまだ無い。どこで', null),
  ('生', 'うま'),
  ('れたかとんと', null),
  ('見当', 'けんとう'),
  ('がつかぬ。', null),
];

class _BodyPreview extends StatefulWidget {
  const _BodyPreview({required this.families, this.sampleText});

  final List<String> families;
  final String? sampleText;

  @override
  State<_BodyPreview> createState() => _BodyPreviewState();
}

class _BodyPreviewState extends State<_BodyPreview> {
  bool _vertical = false;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final FushiDesignTokens tokens = FushiDesignTokens.of(context);
    final TextStyle body = _contentStyle(
      (theme.textTheme.titleMedium ?? const TextStyle()).copyWith(
        color: scheme.onSurface,
        height: 1.9,
        fontWeight: FontWeight.w400,
      ),
      widget.families,
      cjkStyle: CjkFontStyle.serif,
    );
    final TextStyle ruby = body.copyWith(
      fontSize: (body.fontSize ?? 16) * 0.5,
      height: 1,
    );
    final List<(String, String?)> segments = widget.sampleText == null
        ? _kBodyRubySample
        : <(String, String?)>[(widget.sampleText!, null)];
    return ColoredBox(
      color: tokens.surfaces.card,
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.card),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Wrap(
              spacing: tokens.spacing.gap,
              children: <Widget>[
                FushiSelectableChip(
                  label: t.font_preview_horizontal,
                  selected: !_vertical,
                  onSelected: (_) => setState(() => _vertical = false),
                ),
                FushiSelectableChip(
                  label: t.font_preview_vertical,
                  selected: _vertical,
                  onSelected: (_) => setState(() => _vertical = true),
                ),
              ],
            ),
            SizedBox(height: tokens.spacing.gap),
            if (_vertical)
              SizedBox(
                height: 176,
                child: _VerticalText(
                  segments: segments,
                  style: body,
                  rubyStyle: ruby,
                ),
              )
            else
              Text.rich(
                TextSpan(
                  children: <InlineSpan>[
                    for (final (String base, String? rt) in segments)
                      if (rt == null)
                        TextSpan(text: base, style: body)
                      else
                        // 基字与正文同样式、按基线对齐（Stack 的基线取基字）；
                        // 注音浮在基字上方的行距留白里，不撑高行、不挤换行。
                        WidgetSpan(
                          alignment: PlaceholderAlignment.baseline,
                          baseline: TextBaseline.alphabetic,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: <Widget>[
                              Text(base, style: body),
                              Positioned(
                                left: -8,
                                right: -8,
                                top:
                                    (body.fontSize ?? 16) *
                                        ((body.height ?? 1) - 1) /
                                        2 -
                                    (ruby.fontSize ?? 8),
                                // 不参与基线：否则 Stack 取最高基线 = 注音的。
                                child: IgnoreBaseline(
                                  child: Text(
                                    rt,
                                    style: ruby,
                                    textAlign: TextAlign.center,
                                    softWrap: false,
                                    overflow: TextOverflow.visible,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 竖排近似：从右往左一列一列排，每字一格，振假名贴在基字右侧。Flutter 没有原生
/// 竖排，这里只为看字形在竖排版面里的观感，不追求 WebView 的标点换形。
class _VerticalText extends StatelessWidget {
  const _VerticalText({
    required this.segments,
    required this.style,
    required this.rubyStyle,
  });

  final List<(String, String?)> segments;
  final TextStyle style;
  final TextStyle rubyStyle;

  @override
  Widget build(BuildContext context) {
    final double glyph = (style.fontSize ?? 16) * 1.15;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int perColumn = (constraints.maxHeight / glyph).floor().clamp(
          1,
          999,
        );
        final List<(String, String?)> cells = <(String, String?)>[
          for (final (String base, String? rt) in segments)
            // 逐字素切格；注音挂在该段第一格，其余格留空位对齐。
            for (final (int i, String char) in base.characters.indexed)
              (char, i == 0 ? rt : (rt == null ? null : '')),
        ];
        final List<List<(String, String?)>> columns = <List<(String, String?)>>[
          for (int i = 0; i < cells.length; i += perColumn)
            cells.sublist(i, (i + perColumn).clamp(0, cells.length)),
        ];
        return ClipRect(
          child: Row(
            textDirection: TextDirection.rtl,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              for (final List<(String, String?)> column in columns)
                Padding(
                  padding: EdgeInsets.only(left: glyph * 0.35),
                  child: Column(
                    children: <Widget>[
                      for (final (String char, String? rt) in column)
                        SizedBox(
                          height: glyph,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              // 竖排句读挪到字格右上（横排字形在左下）。
                              if (char == '。' || char == '、')
                                Transform.translate(
                                  offset: Offset(glyph * 0.4, -glyph * 0.4),
                                  child: Text(
                                    char,
                                    style: style.copyWith(height: 1),
                                  ),
                                )
                              else
                                Text(char, style: style.copyWith(height: 1)),
                              SizedBox(
                                width: rubyStyle.fontSize ?? 8,
                                child: rt == null || rt.isEmpty
                                    ? null
                                    : Text(
                                        rt.characters.join('\n'),
                                        style: rubyStyle,
                                        softWrap: false,
                                        overflow: TextOverflow.visible,
                                      ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
