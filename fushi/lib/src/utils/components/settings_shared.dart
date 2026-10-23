import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fushi/src/shortcuts/gamepad_forwarding_action.dart';
import 'package:fushi/i18n/strings.g.dart';
import 'package:fushi/src/focus/fushi_focus_controller.dart';
import 'package:fushi/src/focus/fushi_focus_target.dart';
import 'package:fushi/src/shortcuts/gamepad_service.dart';
import 'package:fushi/src/shortcuts/input_binding.dart';
import 'package:fushi/src/utils/adaptive/adaptive_platform.dart';
import 'package:fushi/src/utils/adaptive/adaptive_widgets.dart';
import 'package:fushi/src/utils/components/fushi_design_tokens.dart';
import 'package:fushi/src/utils/components/fushi_dropdown.dart';
import 'package:fushi/src/utils/misc/platform_utils.dart';
import 'package:fushi/src/utils/components/fushi_focusable.dart';
import 'package:fushi/src/utils/components/fushi_material_components.dart';
import 'package:fushi/src/utils/components/fushi_option_selection_page.dart';

class SettingsSectionHeader extends StatelessWidget {
  const SettingsSectionHeader(this.text, {super.key, this.padding});
  final String text;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? const EdgeInsets.only(top: 16, bottom: 4),
      child: Text(text, style: FushiDesignTokens.of(context).type.sectionLabel),
    );
  }
}

const kSettingsSegmentedStyle = ButtonStyle(
  visualDensity: VisualDensity.compact,
  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
);

const int kSettingsRowTitleMaxLines = 2;

const double kSettingsStepperValueWidth = 72;

/// stepper 行 trailing（`−` / 读数 / `+`）的固有宽度：两个
/// `VisualDensity.compact` 的 [IconButton]（48 − 8 = 40）+ [Wrap] 的两处 4
/// 间距 + [kSettingsStepperValueWidth] 读数槽。读数走 [FittedBox] 缩放，所以
/// 这个盒子不随文字缩放变宽。
///
/// 之所以要写成常量：它是 [AdaptiveSettingsRow] 堆叠判据的输入之一（见
/// [AdaptiveSettingsRow.trailingWidth]）——判「这行还放不放得下标题」必须知道
/// trailing 到底占多宽，靠经验常数猜会把标题削没（BUG-2550）。
const double kSettingsStepperTrailingWidth =
    kSettingsStepperValueWidth + 2 * (40 + 4);

/// 行内布局下，标题至少要拿到的宽度（1x；随文字缩放放大）。
///
/// 标题默认 2 行 + ellipsis（[kSettingsRowTitleMaxLines]），低于这个宽度就只剩
/// 开头一两个字加省略号，配置项等于失效。判据与 BUG-1184 / BUG-1537 对说明文字
/// 的判断同一条：截断即失效，宁可让控件换到下一行（[AdaptiveSettingsRow] 本来就
/// 有这条堆叠退路）。96dp ≈ 7 个 CJK 字（bodyMedium 14）。
const double kSettingsRowLabelMinWidth = 96;
const double kSettingsPickerDefaultWidth = 220;
const double kSettingsPickerMinInlineWidth = 120;

/// An [AdaptiveSettingsPickerRow] with more options than this renders as a
/// chevron navigation row that pushes a bounded full-page selector instead of
/// an inline overlay dropdown / action sheet — the overlay's anchored height
/// would otherwise run a long list (app languages, dozens of Anki decks) off
/// the screen edge. Short option sets keep the inline control.
const int kSettingsPickerInlineLimit = 8;

class AdaptiveSettingsScaffold extends StatelessWidget {
  const AdaptiveSettingsScaffold({
    required this.title,
    required this.children,
    super.key,
    this.actions,
    this.padding,
    this.bottom,
  });

  final Widget title;
  final List<Widget> children;
  final List<Widget>? actions;
  final EdgeInsetsGeometry? padding;

  /// 钉在列表下方、不随内容滚动的一条（多选态的批量操作栏用）。为空时布局与
  /// 加它之前逐字相同。
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    final EdgeInsets mediaPadding = MediaQuery.of(context).padding;
    final EdgeInsetsGeometry listPadding = padding ??
        EdgeInsets.fromLTRB(
          16,
          8,
          16,
          8 + mediaPadding.bottom,
        );

    final Widget list = ListView(padding: listPadding, children: children);
    return FushiToolScaffold.customTitle(
      title: title,
      actions: actions ?? const <Widget>[],
      body: bottom == null
          ? list
          : Column(
              children: <Widget>[Expanded(child: list), bottom!],
            ),
    );
  }
}

enum SettingsSectionTitlePlacement { outside, inside }

class AdaptiveSettingsSurface extends StatelessWidget {
  const AdaptiveSettingsSurface({
    required this.child,
    super.key,
    this.title,
    this.color,
    this.contentPadding = EdgeInsets.zero,
    this.titleTrailing,
    this.onTitleTap,
  });

  final Widget child;
  final String? title;
  final Color? color;
  final EdgeInsetsGeometry contentPadding;

  /// 内嵌标题右侧的尾随控件（如折叠 section 的展开箭头）。仅当 [title] 非空时渲染。
  final Widget? titleTrailing;

  /// 非空时把内嵌标题头变成可点击 + 可焦点驱动（Enter/手柄 A）的整头，用于折叠
  /// section 的展开/收起。为空时标题头是纯装饰文字，行为不变。
  final VoidCallback? onTitleTap;

  @override
  Widget build(BuildContext context) {
    final FushiDesignTokens tokens = FushiDesignTokens.of(context);
    final Widget content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (title != null && title!.isNotEmpty)
          _buildContainedTitle(context, tokens, false),
        Padding(padding: contentPadding, child: child),
      ],
    );

    // 设置分组卡靠「填充分层」表达边界，不再在填充之上再叠一圈 1px
    // outlineVariant 描边：MD3 的 filled card 不描边，填充 + 描边是两套并存的
    // 边界信号。设置页一屏里原本还有输入框与分段控件的 colorScheme.outline
    // 描边（比卡片描边深一档）和 0.5px 行分隔线，三种强度的线叠在一起就是
    // 「描边很怪」的来源。
    //
    // eink 例外由 FushiCard 内部兜住：eink scheme 把所有 surface container 塌
    // 缩成背景色，卡片没有可分层的填充，此时它自己补一圈实描边
    // （fushi_material_components.dart 的 eink 分支），这里不传 borderColor。
    return FushiCard(
      padding: EdgeInsets.zero,
      borderRadius: tokens.radii.groupRadius,
      color: color ?? tokens.surfaces.card,
      child: content,
    );
  }

  Widget _buildContainedTitle(
    BuildContext context,
    FushiDesignTokens tokens,
    bool cupertino,
  ) {
    // 折叠头（onTitleTap != null）是带尾随箭头的可点整头：箭头在 Row 里按
    // crossAxisAlignment.center 垂直居中，标题必须用上下对称 padding 才能与箭头
    // 在同一垂直中线上（否则上重下轻的标签 padding 会让标题比箭头低几像素）。
    // 静态内嵌小标题（onTitleTap == null）是行上方的标签，保持上重下轻贴住下方
    // 设置行，行为不变。
    final bool interactive = onTitleTap != null;
    final Widget label = cupertino
        ? Padding(
            padding: interactive
                ? const EdgeInsets.fromLTRB(16, 10, 16, 10)
                : const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Text(
              title!.toUpperCase(),
              style: tokens.type.metadata.copyWith(
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
                fontWeight: FontWeight.w600,
              ),
            ),
          )
        : SettingsSectionHeader(
            title!,
            padding: interactive
                ? const EdgeInsets.fromLTRB(12, 10, 12, 10)
                : const EdgeInsets.fromLTRB(12, 10, 12, 4),
          );

    if (!interactive) return label;

    // 折叠头：标题 + 尾随箭头拼成整头，整头可点、可焦点驱动展开/收起。焦点驱动走
    // 与设置行一致的 _SettingsRowFocusTarget（Enter/手柄 A 触发 Activate），保证纯
    // 手柄/键盘用户也能展开折叠 section；无焦点根时退回平台原生可点组件。
    final Widget header = Row(
      children: <Widget>[
        Expanded(child: label),
        if (titleTrailing != null)
          Padding(
            padding: EdgeInsets.only(
              right: cupertino ? 12 : tokens.spacing.gap,
            ),
            child: titleTrailing!,
          ),
      ],
    );
    final bool hasFocusRoot = FushiFocusRoot.maybeControllerOf(context) != null;
    final Widget tappable = cupertino
        ? GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTitleTap,
            child: header,
          )
        : InkWell(onTap: onTitleTap, child: header);
    if (!hasFocusRoot) {
      return cupertino
          ? FushiFocusable(
              onTap: onTitleTap!,
              borderRadius: BorderRadius.zero,
              child: header,
            )
          : tappable;
    }
    return _SettingsRowFocusTarget(
      onTap: onTitleTap!,
      autoHome: false,
      child: tappable,
    );
  }
}

class AdaptiveSettingsSection extends StatefulWidget {
  const AdaptiveSettingsSection({
    required this.children,
    super.key,
    this.title,
    this.titlePlacement = SettingsSectionTitlePlacement.outside,
    this.surfaceColor,
    this.collapsible = false,
    this.initiallyExpanded = true,
    this.expanded,
    this.onExpansionChanged,
    this.summary,
  });

  final String? title;
  final List<Widget> children;
  final SettingsSectionTitlePlacement titlePlacement;
  final Color? surfaceColor;

  /// 为 true 时内嵌标题头带展开箭头、可点击折叠本 section 的内容。仅在标题内嵌
  /// （[SettingsSectionTitlePlacement.inside]）且 [title] 非空时才成立；否则退回
  /// 普通静态渲染。默认 false，保证所有既有调用点行为不变。
  final bool collapsible;

  /// 折叠 section 的初始展开态；仅 [collapsible] 为 true 时有意义。搜索命中折叠
  /// section 内的项时由上层传 true 强制展开定位。
  final bool initiallyExpanded;

  /// Optional controlled state. Only explicit user toggles call the callback.
  final bool? expanded;
  final ValueChanged<bool>? onExpansionChanged;
  final String? summary;

  @override
  State<AdaptiveSettingsSection> createState() =>
      _AdaptiveSettingsSectionState();
}

class _AdaptiveSettingsSectionState extends State<AdaptiveSettingsSection> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  void didUpdateWidget(AdaptiveSettingsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 搜索命中折叠 section 时，上层把 initiallyExpanded 由 false 翻成 true——同一
    // widget 身份下的 rebuild 里据此强制展开定位；用户手动收/展的态在无此翻转时保留。
    if (widget.collapsible &&
        widget.initiallyExpanded &&
        !oldWidget.initiallyExpanded) {
      _expanded = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.children.isEmpty) return const SizedBox.shrink();

    final FushiDesignTokens tokens = FushiDesignTokens.of(context);
    final bool titleInside =
        widget.titlePlacement == SettingsSectionTitlePlacement.inside;
    final bool collapsible = widget.collapsible &&
        titleInside &&
        (widget.title?.isNotEmpty ?? false);
    final bool expanded = widget.expanded ?? _expanded;
    final List<Widget> rows = _withDividers(context, widget.children);
    final Widget rowsColumn = Column(
      mainAxisSize: MainAxisSize.min,
      children: rows,
    );

    final Widget group;
    if (collapsible) {
      group = AdaptiveSettingsSurface(
        title: widget.title,
        color: widget.surfaceColor,
        onTitleTap: () {
          final bool next = !expanded;
          setState(() => _expanded = next);
          widget.onExpansionChanged?.call(next);
        },
        titleTrailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (widget.summary?.isNotEmpty ?? false)
              Flexible(
                child: Text(
                  widget.summary!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tokens.type.metadata,
                ),
              ),
            AnimatedRotation(
              turns: expanded ? 0.5 : 0.0,
              // eink 下动画归零（连续重绘=残影），箭头直接跳到目标朝向。
              duration: einkSafeDuration(
                context,
                const Duration(milliseconds: 180),
              ),
              child: Icon(
                Icons.expand_more,
                size: 22,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        // 收起时行不入树（不可聚焦、不参与焦点驱动），只保留标题头；用 AnimatedSize
        // 平滑高度过渡，ClipRect 防过渡帧溢出。eink 下高度过渡同样归零。
        child: ClipRect(
          child: AnimatedSize(
            duration: einkSafeDuration(
              context,
              const Duration(milliseconds: 180),
            ),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child:
                expanded ? rowsColumn : const SizedBox(width: double.infinity),
          ),
        ),
      );
    } else {
      group = AdaptiveSettingsSurface(
        title: titleInside ? widget.title : null,
        color: widget.surfaceColor,
        child: rowsColumn,
      );
    }

    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (!titleInside && widget.title != null && widget.title!.isNotEmpty)
            SettingsSectionHeader(
                    widget.title!,
                    padding: const EdgeInsets.only(bottom: 6),
                  ),
          group,
        ],
      ),
    );
  }

  List<Widget> _withDividers(BuildContext context, List<Widget> rows) {
    final FushiDesignTokens tokens = FushiDesignTokens.of(context);
    final Color dividerColor = Theme.of(context).colorScheme.outlineVariant;
    final List<Widget> result = <Widget>[];
    for (int i = 0; i < rows.length; i++) {
      if (i > 0) {
        result.add(
          Divider(
            height: 1,
            thickness: 0.5,
            indent: tokens.spacing.rowHorizontal,
            endIndent: tokens.spacing.rowHorizontal,
            color: dividerColor,
          ),
        );
      }
      result.add(rows[i]);
    }
    return result;
  }
}

class AdaptiveSettingsRow extends StatelessWidget {
  const AdaptiveSettingsRow({
    required this.title,
    super.key,
    this.subtitle,
    this.icon,
    this.showIcon = false,
    this.trailing,
    this.onTap,
    this.controlBelow = false,
    this.trailingFlexible = false,
    this.trailingWidth,
    this.titleMaxLines,
    this.subtitleMaxLines,
    this.horizontalPadding,
  });

  /// 覆盖本行的水平内边距；null = 用标准 `tokens.spacing.rowHorizontal`（16）。
  ///
  /// 存在的理由：这 16px 此前是硬编码、无逃生口的，而它同时是「设置行左边缘」的
  /// 事实标准。于是任何**自带内边距**的嵌入式正文（`SettingsCustomItem` 的 builder、
  /// `SettingsDestination.body` 逃生口）一旦把自己整体缩进 16，里面夹杂的
  /// [AdaptiveSettingsRow] 就变成 32，与同卡片其它行错开——「下载设置左右间距和其他
  /// 设置不一样」正是这一类。给出显式 0 让调用方声明「外层已经缩进过了」。
  final double? horizontalPadding;

  final String title;
  final String? subtitle;
  final IconData? icon;
  final bool showIcon;

  /// Overrides how many lines the title may occupy before ellipsizing. When
  /// null the shared [kSettingsRowTitleMaxLines] default (2) is used, so every
  /// existing call site keeps its current behavior. Pass a larger finite value
  /// (never null-as-unbounded) for rows whose title can legitimately be long -
  /// e.g. a table-of-contents chapter name on a narrow phone - so it wraps
  /// instead of being clipped at two lines.
  final int? titleMaxLines;

  /// Overrides how many lines the subtitle (说明文字) may occupy before
  /// ellipsizing. Null = 不限行数：说明文字整段显示。
  ///
  /// BUG-1184：此前说明文字硬钳 [kSettingsRowSubtitleMaxLines]（3 行）+ ellipsis，
  /// 且没有 [titleMaxLines] 那样的逃生口。设置行本身只有 minHeight 约束、行高自由，
  /// 所以这个上限不是为了防溢出，纯粹是自伤——窄屏上 label 被 `Expanded` 压窄，
  /// 一条稍长的说明（尤其带路径/警告拼接的那些）第 4 行起直接被吃掉，用户看不到
  /// 配置项到底在说什么。说明文字的唯一职责就是解释配置项，截断即等于失效，因此
  /// 默认改为不限；需要压缩的场景（列表密度敏感处）显式传一个有限值。
  ///
  /// BUG-1537：上面那次修复只改了 maxLines，说明文字的 `Text` 仍恒传
  /// `TextOverflow.ellipsis`——而 ellipsis 配 `maxLines: null` 在 Flutter 里不是
  /// 「不生效」，是把整段压成**单行**，比原来的 3 行更糟。所以 overflow 必须跟着
  /// 本字段联动（见 [_SettingsLabel]），守卫在
  /// `test/settings/settings_row_subtitle_wrap_test.dart`。
  final int? subtitleMaxLines;

  /// CONTRACT: [trailing] must be self-sizing. With [controlBelow] false it is
  /// placed as a NON-flex child of a Row that also has an `Expanded` label, so
  /// RenderFlex measures it with UNBOUNDED main-axis width. A trailing whose
  /// top-level layout demands width (a bare `Expanded`/`Flexible(tight)`, or a
  /// `DropdownMenu(expandedInsets: …)` without a bounding `SizedBox`) throws
  /// "RenderFlex children have non-zero flex but incoming width constraints are
  /// unbounded". Bound such controls (e.g. `SizedBox(width: …)`, as
  /// [AdaptiveSettingsPickerRow] does), set [trailingFlexible] for a control
  /// that should shrink-and-scroll, or pass them via [controlBelow] instead.
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool controlBelow;

  /// When true (and [controlBelow] is false), [trailing] is hosted as a
  /// `Flexible(fit: loose)` child of the inline Row instead of a non-flex one,
  /// so it receives BOUNDED main-axis constraints. Use this for an intrinsically
  /// wide control wrapped in a horizontal scroll view (e.g. a `SegmentedButton`
  /// in [AdaptiveSettingsSegmentedRow]): with bounded width the scroll view
  /// actually scrolls instead of overflowing the row. Self-sizing controls
  /// (switches, steppers) must leave this false so the label stays greedy.
  final bool trailingFlexible;

  /// [trailing] 的固有宽度（dp），由知道自己多宽的调用方声明（如
  /// [AdaptiveSettingsStepperRow] 传 [kSettingsStepperTrailingWidth]）。
  ///
  /// 只影响**堆叠判据**：给出它，这行就按「padding + 图标 + 标题最低可读宽
  /// （[kSettingsRowLabelMinWidth]）+ 间距 + 本值」判断还放不放得下行内布局，
  /// 而不是套那个与 trailing 无关的经验常数。不给（默认）= 维持原经验值。
  ///
  /// 它**不**参与布局本身：trailing 仍是自尺寸的非 flex 子，本值只是声明，
  /// 写错不会把控件拉宽或压窄，只会让堆叠点偏移。
  final double? trailingWidth;

  @override
  Widget build(BuildContext context) {
    final FushiDesignTokens tokens = FushiDesignTokens.of(context);
    // Auto-stack a non-flex trailing under the label only when the row is
    // genuinely too narrow to host both side by side — NOT on every typical
    // phone. The label is already `Expanded` and the trailing is self-sizing,
    // so the inline Row never overflows down to fairly small widths; the column
    // layout is only an improvement when there is no horizontal room left.
    //
    // The threshold must follow text scale: at 1x a label + a switch/stepper
    // fit comfortably below any real phone row width (≈320–380dp), so a
    // fixed 360 wrongly stacked nearly every row — worse at high UI scale, where
    // the app shrinks the logical width and pushed `maxWidth` under 360. Scaling
    // the threshold with the effective text scale keeps it modest at 1x (so
    // normal rows stay horizontal) while still stacking when large text or a
    // wider non-flex trailing, like a stepper with a fixed readout slot,
    // genuinely needs the extra room. Capped so absurd scales don't demand an
    // impossible width.
    //
    // BUG-2550：那个经验值只在 trailing 窄（switch ~60）时成立。trailing 一旦真的
    // 宽——stepper 是 [kSettingsStepperTrailingWidth]（160）——220 就远低于这行真正
    // 需要的宽度：行宽刚好卡在阈值上时，标题拿到的是
    // `220 + 42 − 32(padding) − 42(icon) − 12(gap) − 160(stepper) ≈ 16dp`，
    // 一个汉字都装不下，于是「字体大小 / 字体粗细 / 段落间距」在阅读设置面板里
    // 全被 ellipsis 削成开头一个字。所以**声明了固有宽度的 trailing** 改按真实需求
    // 算阈值（padding + 图标 + 标题最低可读宽 + 间距 + trailing 实宽），没声明的
    // 维持原经验值不动（它们的窄屏行为另有守卫钉着）。
    final double textScale = MediaQuery.textScalerOf(context).scale(1);
    final double horizontalInset =
        horizontalPadding ?? (tokens.spacing.rowHorizontal);
    final double? declaredTrailingWidth = trailingWidth;
    final double stackThreshold = declaredTrailingWidth == null
        ? (220.0 * textScale).clamp(220.0, 420.0)
        : 2 * horizontalInset +
            (kSettingsRowLabelMinWidth * textScale).clamp(
              kSettingsRowLabelMinWidth,
              2 * kSettingsRowLabelMinWidth,
            ) +
            (tokens.spacing.gap + 4) +
            declaredTrailingWidth;
    // 左栏图标占固定宽（badge ~30 + 间距 gap+4 = 12）：堆叠判断必须把它计入
    // 需求，否则窄 pane（如视频快捷设置侧栏）里带图标的行仍按无图标阈值走
    // 行内布局，label+trailing 少了一个图标位而右溢出。
    final double iconExtra = (showIcon && icon != null) ? 42.0 : 0.0;
    final Widget content = LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        // BUG-1184：flexible trailing 此前被排除在堆叠判定外（`!trailingFlexible`），
        // 理由是它「会自己 shrink-and-scroll，不会溢出」。不溢出 ≠ 看得清：flexible
        // trailing 与 `Expanded` 标题按 flex 五五分整行宽，360dp 上标题只剩 ~130px，
        // 于是标题被压成两行省略号、控件也缩进一条窄滚动条——两边都读不了。窄到放不下
        // 时同样该让出整行给标题、控件独占下一行，与非 flex trailing 完全同一条规则。
        final bool stackControls = controlBelow ||
            (trailing != null &&
                constraints.maxWidth < stackThreshold + iconExtra);
        return Padding(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding ??
                (tokens.spacing.rowHorizontal),
            vertical:
                stackControls ? tokens.spacing.rowVertical : tokens.spacing.gap,
          ),
          child: stackControls
              ? _buildColumnLayout(context)
              : _buildRowLayout(context),
        );
      },
    );

    if (onTap == null) return content;
    final bool hasFocusRoot = FushiFocusRoot.maybeControllerOf(context) != null;
    // Material：**结构恒定，行为按 hasFocusRoot 门控**。此前按有无焦点根换两棵
    // 不同的树（裸 InkWell vs 目标+ExcludeFocus 包裹），切「键盘/手柄焦点导航」
    // 实验开关时行子树整体重挂载，行里的 Switch 以新状态直接 mount——滑块动画
    // 消失（用户实报 2026-07-22）。恒定结构下两态语义不变：
    // - 有焦点根：目标可聚焦 + ExcludeFocus 生效 → 单停靠点（PR-0 契约）；
    // - 无焦点根：目标 skipTraversal + ExcludeFocus 直通 → InkWell/Switch 照旧
    //   参与原生 Tab 遍历，与旧「裸 InkWell」分支逐字节同语义。
    return _SettingsRowFocusTarget(
      onTap: onTap!,
      focusEnabled: hasFocusRoot,
      child: ExcludeFocus(
        excluding: hasFocusRoot,
        child: InkWell(onTap: onTap, child: content),
      ),
    );
  }

  Widget _buildRowLayout(BuildContext context) {
    final FushiDesignTokens tokens = FushiDesignTokens.of(context);
    return ConstrainedBox(
      constraints: BoxConstraints(
        minHeight:
            tokens.density.controlHeight,
      ),
      child: Row(
        children: [
          if (showIcon && icon != null) ...[
            _SettingsIcon(icon: icon!),
            SizedBox(width: tokens.spacing.gap + 4),
          ],
          Expanded(
            child: _SettingsLabel(
              title: title,
              subtitle: subtitle,
              titleMaxLines: titleMaxLines,
              subtitleMaxLines: subtitleMaxLines,
            ),
          ),
          if (trailing != null) ...[
            SizedBox(width: tokens.spacing.gap + 4),
            // A flexible trailing receives bounded width so an inner horizontal
            // scroll view scrolls instead of overflowing (see [trailingFlexible]).
            _buildInlineTrailing(trailing!, flexible: trailingFlexible),
          ],
        ],
      ),
    );
  }

  Widget _buildInlineTrailing(Widget child, {required bool flexible}) {
    final Widget aligned = Align(
      alignment: Alignment.centerRight,
      widthFactor: flexible ? null : 1,
      child: child,
    );
    if (!flexible) return aligned;
    return Flexible(fit: FlexFit.loose, child: aligned);
  }

  Widget _buildColumnLayout(BuildContext context) {
    final FushiDesignTokens tokens = FushiDesignTokens.of(context);
    return ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: tokens.density.controlHeight + tokens.spacing.gap + 4,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (showIcon && icon != null) ...[
                _SettingsIcon(icon: icon!),
                SizedBox(width: tokens.spacing.gap + 4),
              ],
              Expanded(
                child: _SettingsLabel(
                  title: title,
                  subtitle: subtitle,
                  titleMaxLines: titleMaxLines,
                  subtitleMaxLines: subtitleMaxLines,
                ),
              ),
            ],
          ),
          if (trailing != null) ...[
            SizedBox(height: tokens.spacing.gap),
            Align(alignment: Alignment.centerLeft, child: trailing!),
          ],
        ],
      ),
    );
  }
}

class _SettingsRowFocusTarget extends StatefulWidget {
  const _SettingsRowFocusTarget({
    required this.onTap,
    required this.child,
    this.autoHome = true,
    this.focusEnabled = true,
  });

  final VoidCallback onTap;
  final Widget child;

  /// False = 目标保持挂载但不参与遍历/注册（无焦点根时的恒定结构模式，
  /// 见调用处注释）。透传 [FushiFocusTarget.enabled]。
  final bool focusEnabled;

  /// False for a collapsible section's fold header: it stays keyboard/gamepad
  /// reachable but passive focus auto-home skips it so the cursor lands on the
  /// first real setting row (see [FushiFocusTargetEntry.autoHome]).
  final bool autoHome;

  @override
  State<_SettingsRowFocusTarget> createState() =>
      _SettingsRowFocusTargetState();
}

class _SettingsRowFocusTargetState extends State<_SettingsRowFocusTarget> {
  late final FushiFocusId _focusId = FushiFocusId(
    'settings-row-${identityHashCode(this)}',
  );

  @override
  Widget build(BuildContext context) {
    return Actions(
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onTap();
            return null;
          },
        ),
      },
      child: FushiFocusTarget(
        id: _focusId,
        autoHome: widget.autoHome,
        enabled: widget.focusEnabled,
        child: widget.child,
      ),
    );
  }
}

class AdaptiveSettingsSwitchRow extends StatelessWidget {
  const AdaptiveSettingsSwitchRow({
    required this.title,
    required this.value,
    required this.onChanged,
    super.key,
    this.subtitle,
    this.icon,
    this.showIcon = false,
    this.horizontalPadding,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;

  /// 与 [AdaptiveSettingsNavigationRow.showIcon] 同款开关：true 且 [icon] 非空
  /// 才渲染左栏图标徽章。schema 层的 `showIcons` 经此透传（此前只转发 icon 不
  /// 转发 showIcon，值控件行声明的图标从不渲染，同卡片左栏对不齐）。
  final bool showIcon;
  final double? horizontalPadding;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return AdaptiveSettingsRow(
      title: title,
      subtitle: subtitle,
      icon: icon,
      showIcon: showIcon,
      horizontalPadding: horizontalPadding,
      trailing: adaptiveSwitch(
        context: context,
        value: value,
        onChanged: onChanged,
      ),
      onTap: onChanged == null ? null : () => onChanged!(!value),
    );
  }
}

/// Per-segment horizontal chrome (padding + border) baked into a Material
/// [SegmentedButton] segment under [kSettingsSegmentedStyle] (compact density,
/// shrink-wrap tap target). Deliberately on the generous side: when estimating
/// whether a strip fits, over-estimating the width makes us fall back to the
/// (non-clipping) horizontal scroll instead of forcing a too-tight full-width
/// layout — i.e. errors land on the safe, BUG-008-preserving side.
const double _kSegmentHorizontalChrome = 28.0;

/// Width reserved for a segment that carries no text label (icon-only segments
/// such as the 深色模式 light/system/dark strip), in logical pixels.
const double _kSegmentIconOnlyWidth = 44.0;

/// Average advance width of one label glyph relative to the font size. CJK /
/// fullwidth glyphs are ~1em wide; Latin (and most other narrow scripts) are
/// ~0.55em — estimated at 0.62em so the guess stays conservative (wide) without
/// grossly over-shooting for long Latin labels (which would force strips into
/// the scroll fallback that actually fit).
const double _kSegmentWideGlyphWidthFactor = 1.0;
const double _kSegmentNarrowGlyphWidthFactor = 0.62;

/// Estimated advance width of [label] (logical pixels) at [scaledFont],
/// classifying each rune as wide (CJK/fullwidth, >= U+1100) or narrow.
double _segmentLabelContentWidth(String label, double scaledFont) =>
    estimateLabelAdvanceWidth(
      label: label,
      fontSize: scaledFont,
      textScaleFactor: 1.0,
    );

/// 估算一排 MD3 tab（库页顶栏 [LibrarySectionTabs]）按各自文案取宽时的自然总宽
/// （逻辑像素）。[horizontalPaddingPerTab] 是单侧 label 内边距。
///
/// 逐段求和，不是「段数 × 最宽段」——后者是等宽分段条 [estimateSegmentedStripWidth]
/// 的算法，tab 各自取宽，用错会高估近一倍。
///
/// 字号 / 文字缩放在这里就地取自 tokens 与 [MediaQuery]，调用点不再重复那三行样板，
/// 也不必自己碰 `fontSize`——顶栏字号是共享组件层的决策，页面侧不该重开。
double estimateSectionTabBarWidth(
  BuildContext context,
  List<String> labels, {
  required double horizontalPaddingPerTab,
}) {
  final FushiDesignTokens tokens = FushiDesignTokens.of(context);
  final double fontSize = tokens.type.controlLabel.fontSize ?? 14.0;
  final double textScaleFactor = MediaQuery.textScalerOf(context).scale(1);
  double total = 0.0;
  for (final String label in labels) {
    total += estimateLabelAdvanceWidth(
          label: label,
          fontSize: fontSize,
          textScaleFactor: textScaleFactor,
        ) +
        horizontalPaddingPerTab * 2;
  }
  return total;
}

/// 一段标签文案的估算横向进距（逻辑像素），CJK / 全角按 1em、其余按 0.62em。
///
/// Build 期可算（只依赖文案 / 字号 / 文字缩放，不依赖布局），供两类顶栏控件共用：
/// [segmentedStripCellWidth]（分段条的等宽单元格）与库页顶栏 [LibrarySectionTabs]
/// 的 tab 自然宽。两者的换行 / 滚动兜底判据必须出自同一张字宽表，否则同一批文案
/// 在两个控件上会得出不同的「摆得下吗」结论。
double estimateLabelAdvanceWidth({
  required String label,
  required double fontSize,
  required double textScaleFactor,
}) {
  final double scaledFont = fontSize * textScaleFactor;
  double width = 0.0;
  for (final int rune in label.runes) {
    width += scaledFont *
        (rune >= 0x1100
            ? _kSegmentWideGlyphWidthFactor
            : _kSegmentNarrowGlyphWidthFactor);
  }
  return width;
}

/// Estimated width (logical pixels) of ONE segment cell of a Material
/// segmented strip: the widest segment's content, floored at [minSegmentWidth],
/// plus per-segment chrome. Material [SegmentedButton] lays EVERY segment out
/// at the same width — the widest segment's intrinsic width (framework
/// `_calculateHorizontalChildSize`) — so this is the building block for the
/// strip's natural width.
double segmentedStripCellWidth({
  required List<String?> segmentLabels,
  required double fontSize,
  required double textScaleFactor,
  double minSegmentWidth = 0.0,
}) {
  final double scaledFont = fontSize * textScaleFactor;
  double cell = minSegmentWidth;
  for (final String? label in segmentLabels) {
    final double content = (label == null || label.isEmpty)
        ? _kSegmentIconOnlyWidth
        : _segmentLabelContentWidth(label, scaledFont);
    final double candidate = content + _kSegmentHorizontalChrome;
    if (candidate > cell) cell = candidate;
  }
  return cell;
}

/// Estimates the intrinsic width (logical pixels) a Material segmented strip
/// would occupy if laid out at its natural size, WITHOUT actually building it.
///
/// Used by [AdaptiveSettingsSegmentedRow] and [FushiSegmentedStrip] to decide,
/// inside a [LayoutBuilder], whether the strip fits (→ bounded equal-width
/// layout) or must fall back to a horizontal scroll view (→ narrow pane, keep
/// every segment reachable per BUG-008). It does not need to be exact — only
/// conservative: a slight over-estimate prefers the safe scrolling path.
///
/// BUG-1719 (顶栏下沉): the estimate MUST model the framework's equal-width
/// layout — `segmentCount × widestCell` — NOT the sum of each segment's own
/// width. The old per-segment sum under-estimated any strip whose labels differ
/// in length, so 「fits」 was declared for widths that could not actually hold
/// the equal-width layout; the framework then clamped every cell below the
/// widest label, which wrapped to two lines and grew the strip 8px taller than
/// its siblings (the game capture-workbench top bar visibly sank on tab
/// switch).
///
/// [segmentLabels] is one entry per segment: the label's text, or `null` for an
/// icon-only segment. [fontSize] is the segment label font size and
/// [textScaleFactor] the active text scaler — both widen the estimate so large
/// text or high UI scale correctly falls back to scrolling.
double estimateSegmentedStripWidth({
  required List<String?> segmentLabels,
  required double fontSize,
  required double textScaleFactor,
  double minSegmentWidth = 0.0,
}) {
  if (segmentLabels.isEmpty) return 0.0;
  return segmentLabels.length *
      segmentedStripCellWidth(
        segmentLabels: segmentLabels,
        fontSize: fontSize,
        textScaleFactor: textScaleFactor,
        minSegmentWidth: minSegmentWidth,
      );
}

class AdaptiveSettingsSegmentedRow<T extends Object> extends StatelessWidget {
  const AdaptiveSettingsSegmentedRow({
    required this.title,
    required this.segments,
    required this.selected,
    required this.onChanged,
    super.key,
    this.subtitle,
    this.icon,
    this.showIcon = false,
    this.controlBelow = true,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;

  /// 见 [AdaptiveSettingsSwitchRow.showIcon]。
  final bool showIcon;
  final List<ButtonSegment<T>> segments;
  final T selected;
  final ValueChanged<T> onChanged;

  /// A segmented strip is an intrinsically WIDE, multi-option control. Hosted
  /// inline ([controlBelow] false) it shares the row with an `Expanded` label,
  /// and RenderFlex splits the width by flex (≈50/50) — so a strip wider than
  /// its share is clipped/scrolled and trailing segments fall off the right
  /// edge (the reported 设计系统/深色模式 bug, BUG-008). Default is therefore
  /// [controlBelow] true: the strip gets its own full-width row below the
  /// label, showing every segment and scrolling only when the pane is genuinely
  /// narrower than the strip. Pass `controlBelow: false` only for a short strip
  /// that must sit inline next to a short label.
  final bool controlBelow;

  @override
  Widget build(BuildContext context) {
    // A segmented row is a discrete-valued control: register it as a SINGLE
    // gamepad/keyboard focus stop (like the stepper/slider rows) so geometric
    // focus navigation can land on it, and D-pad Left/Right steps the segment
    // in place (clamped at the ends, no wrap). Without this wrapper the row
    // carries no FushiFocusTarget (its
    // AdaptiveSettingsRow has no onTap), so it is invisible to directional
    // navigation — the cursor skips the whole layout section.
    final int currentIndex = segments.indexWhere(
      (ButtonSegment<T> s) => s.value == selected,
    );
    void selectAt(int index) {
      if (segments.isEmpty) return;
      final int clamped = index.clamp(0, segments.length - 1);
      final T value = segments[clamped].value;
      if (value != selected) onChanged(value);
    }

    // Extract each segment's label text (null for icon-only segments) so the
    // pure-function width estimate can decide whether the strip fits full-width.
    final List<String?> segmentLabels =
        segments.map<String?>((ButtonSegment<T> s) {
      final Widget? label = s.label;
      return label is Text ? label.data : null;
    }).toList(growable: false);

    final Widget strip = adaptiveSegmentedButton<T>(
      context: context,
      segments: segments,
      selected: <T>{selected},
      onSelectionChanged: (Set<T> values) {
        if (values.isEmpty) return;
        onChanged(values.first);
      },
      style: kSettingsSegmentedStyle,
    );

    return AdaptiveSettingsRow(
      title: title,
      subtitle: subtitle,
      icon: icon,
      showIcon: showIcon,
      controlBelow: controlBelow,
      // The segmented strip is intrinsically wide and wrapped in a horizontal
      // scroll view; host it as a flexible (bounded-width) trailing so it
      // shrink-and-scrolls on narrow panes instead of overflowing the row.
      trailingFlexible: true,
      trailing: _GamepadAdjustableValue(
        focusIdPrefix: 'settings-segmented',
        onIncrement: () => selectAt(currentIndex + 1),
        onDecrement: () => selectAt(currentIndex - 1),
        child: _SegmentedStripHost(
          controlBelow: controlBelow,
          segmentLabels: segmentLabels,
          strip: strip,
        ),
      ),
    );
  }
}

/// Hosts the segmented [strip] in a FULL-WIDTH box that occupies the whole row
/// ([controlBelow] true), so every segmented box in the same section is the same
/// width (TODO-882). Only the box's CHILD varies with whether the strip fits:
/// when it fits, the [SegmentedButton] takes the full width directly (every
/// segment equally sized, no scroll); when it does not, the intrinsic-width strip
/// is placed in a horizontal scroll view INSIDE the full-width box (BUG-008:
/// every segment stays reachable, nothing clipped off the edge).
///
/// A segmented strip in a config row is intrinsically wide. Giving a controlBelow
/// strip its own full-width row and stretching it (Material [SegmentedButton]
/// under a `double.infinity` width divides the space equally between segments)
/// reads as a deliberate, balanced control. Previously a fitting strip stretched
/// while a too-wide one fell back to a bare scroll view sized to its narrow
/// intrinsic width — so two boxes in one section rendered at different widths
/// (the TODO-882 bug). Now the outer box is unconditionally full-width and only
/// the inner content differs.
///
/// When hosted inline ([controlBelow] false) the strip shares the row with the
/// label and must stay scroll-only, exactly as before, so it never steals the
/// label's width.
class _SegmentedStripHost extends StatelessWidget {
  const _SegmentedStripHost({
    required this.controlBelow,
    required this.segmentLabels,
    required this.strip,
  });

  final bool controlBelow;
  final List<String?> segmentLabels;
  final Widget strip;

  @override
  Widget build(BuildContext context) {
    final Widget scrolling = HorizontalDragScrollable(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: strip,
      ),
    );

    // Inline strips never stretch (they would crowd the label); keep the old
    // shrink-and-scroll behaviour untouched.
    if (!controlBelow) return scrolling;

    final FushiDesignTokens tokens = FushiDesignTokens.of(context);
    final double fontSize = tokens.type.controlLabel.fontSize ?? 14.0;
    final double textScale = MediaQuery.textScalerOf(context).scale(1);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double available = constraints.maxWidth;
        final double estimated = estimateSegmentedStripWidth(
          segmentLabels: segmentLabels,
          fontSize: fontSize,
          textScaleFactor: textScale,
        );
        // A controlBelow strip ALWAYS occupies the full row width so that every
        // segmented box in the same section reads as equal-width (TODO-882: a
        // short strip stretched to fill and a long strip falling back to its
        // intrinsic width previously rendered at different widths). The outer
        // box is therefore unconditionally `width: double.infinity`; only the
        // CHILD differs: when the strip fits we hand the SegmentedButton the
        // bounded full width directly (equal-width segments, no scroll); when it
        // does not fit we put the intrinsic-width strip in a horizontal scroll
        // view so the full-width box still scrolls to the last segment (BUG-008:
        // never clip trailing segments off the edge).
        final bool fits = available.isFinite && estimated <= available;
        return SizedBox(
          width: double.infinity,
          child: fits ? strip : scrolling,
        );
      },
    );
  }
}

/// Registers a STANDALONE [adaptiveSegmentedButton] (one NOT hosted by an
/// [AdaptiveSettingsSegmentedRow] — e.g. a segmented selector inside a dialog
/// header) as a single gamepad/keyboard focus stop, with D-pad Left/Right
/// cycling the selection in place. Without this the segmented strip is a cluster
/// of native buttons that the directional [FushiFocusController] — which walks
/// only registered targets — skips entirely. Pass the already-built segmented
/// button (or its scroll wrapper) as [child]; it is excluded from inner focus
/// traversal so this is the one stop, while staying mouse/touch-tappable.
class FushiAdjustableSegmented<T extends Object> extends StatelessWidget {
  const FushiAdjustableSegmented({
    required this.values,
    required this.selected,
    required this.onChanged,
    required this.child,
    super.key,
    this.focusIdPrefix = 'segmented',
    this.focusId,
  });

  /// The segment values in display order; [selected] must be one of them.
  final List<T> values;
  final T selected;
  final ValueChanged<T> onChanged;
  final Widget child;
  final String focusIdPrefix;
  final FushiFocusId? focusId;

  @override
  Widget build(BuildContext context) {
    final int currentIndex = values.indexOf(selected);
    void selectAt(int index) {
      if (values.isEmpty) return;
      final int clamped = index.clamp(0, values.length - 1);
      final T value = values[clamped];
      if (value != selected) onChanged(value);
    }

    return _GamepadAdjustableValue(
      focusIdPrefix: focusIdPrefix,
      focusId: focusId,
      onIncrement: () => selectAt(currentIndex + 1),
      onDecrement: () => selectAt(currentIndex - 1),
      child: child,
    );
  }
}

class AdaptiveSettingsPickerOption<T> {
  const AdaptiveSettingsPickerOption({
    required this.value,
    required this.label,
  });

  final T value;
  final String label;
}

class AdaptiveSettingsPickerRow<T> extends StatelessWidget {
  const AdaptiveSettingsPickerRow({
    required this.title,
    required this.options,
    required this.selected,
    required this.onChanged,
    super.key,
    this.subtitle,
    this.icon,
    this.showIcon = false,
    this.placeholder,
    this.materialWidth,
    this.controlBelow = false,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;

  /// 见 [AdaptiveSettingsSwitchRow.showIcon]。仅作用于行内 picker 分支；超过
  /// [kSettingsPickerInlineLimit] 的整页选择器分支沿用「有 icon 即显示」旧契约。
  final bool showIcon;
  final List<AdaptiveSettingsPickerOption<T>> options;
  final T selected;
  final ValueChanged<T> onChanged;
  final String? placeholder;
  final double? materialWidth;
  final bool controlBelow;

  @override
  Widget build(BuildContext context) {
    if (options.length > kSettingsPickerInlineLimit) {
      return _buildFullPageRow(context);
    }
    return AdaptiveSettingsRow(
      title: title,
      subtitle: subtitle,
      icon: icon,
      showIcon: showIcon,
      controlBelow: controlBelow,
      trailingFlexible: !controlBelow,
      trailing: _buildMaterialDropdown(context),
      onTap: null,
    );
  }

  /// Long option sets route to a bounded full-page selector
  /// ([FushiOptionSelectionPage]) instead of an anchored overlay that could
  /// overflow the screen. The chosen entry is reported through [onChanged];
  /// backing out (null result) leaves the selection unchanged. Index-keyed so
  /// the page never needs `==`/hashCode on [T].
  Widget _buildFullPageRow(BuildContext context) {
    return AdaptiveSettingsNavigationRow(
      title: title,
      subtitle: _selectedLabel ?? placeholder,
      icon: icon,
      showIcon: icon != null,
      onTap: () async {
        final int? index = await pickOption<int>(
          context,
          title: title,
          selected: _selectedIndex,
          options: <FushiOptionSelectionOption<int>>[
            for (int i = 0; i < options.length; i++)
              FushiOptionSelectionOption<int>(
                value: i,
                label: options[i].label,
              ),
          ],
        );
        if (index != null) onChanged(options[index].value);
      },
    );
  }

  Widget _buildMaterialDropdown(BuildContext context) {
    // GamepadMenuDropdown renders a stock DropdownMenu on Android (engine
    // delivers real key events) and a gamepad-enterable MenuAnchor on desktop
    // (a polled gamepad's D-pad is focus-traversal, not arrow keys, so it can't
    // enter a stock DropdownMenu's menu). Index-keyed so the Android path stays
    // DropdownMenu<int> — entries map option index → label.
    Widget buildDropdown(double? width) {
      return GamepadMenuDropdown<int>(
        width: width,
        label: title,
        hintText: placeholder,
        selected: _selectedIndex,
        onChanged: (int index) => onChanged(options[index].value),
        entries: <GamepadDropdownEntry<int>>[
          for (int i = 0; i < options.length; i++)
            (value: i, label: options[i].label),
        ],
      );
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double maxWidth = constraints.maxWidth;
        if (controlBelow || materialWidth == double.infinity) {
          return buildDropdown(
            maxWidth.isFinite ? maxWidth : kSettingsPickerDefaultWidth,
          );
        }

        final double requestedWidth =
            materialWidth ?? kSettingsPickerDefaultWidth;
        if (!maxWidth.isFinite) return buildDropdown(requestedWidth);
        final double minWidth = maxWidth < kSettingsPickerMinInlineWidth
            ? maxWidth
            : kSettingsPickerMinInlineWidth;
        return buildDropdown(
          requestedWidth.clamp(minWidth, maxWidth).toDouble(),
        );
      },
    );
  }

  String? get _selectedLabel {
    for (final option in options) {
      if (option.value == selected) return option.label;
    }
    return null;
  }

  int? get _selectedIndex {
    for (int i = 0; i < options.length; i++) {
      if (options[i].value == selected) return i;
    }
    return null;
  }
}

class AdaptiveSettingsTextField extends StatefulWidget {
  const AdaptiveSettingsTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.initialValue,
    this.hintText,
    this.labelText,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
    this.suffixIcon,
    this.focusId,
  }) : assert(controller == null || initialValue == null);

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? initialValue;
  final String? hintText;
  final String? labelText;
  final bool obscureText;
  final TextInputType keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final Widget? suffixIcon;

  /// Explicit geometric-focus id; when null a stable per-instance fallback is
  /// used so the field is always a directional-navigation anchor (see below).
  final FushiFocusId? focusId;

  @override
  State<AdaptiveSettingsTextField> createState() =>
      _AdaptiveSettingsTextFieldState();
}

class _AdaptiveSettingsTextFieldState extends State<AdaptiveSettingsTextField> {
  // A settings text field MUST register with the directional focus controller,
  // otherwise it is invisible to geometric navigation: when an arrow key escapes
  // the focused (single-line) field, [FushiFocusController.move] cannot locate
  // the active entry and dead-reckons to the FIRST registered row — which can
  // sit ABOVE the field, so Down jumps up (BUG-048). [FushiTextField] only
  // registers when given a focusId, so we always supply one. The id is owned by
  // the State (stable across rebuilds), mirroring [_SettingsRowFocusTarget].
  late final FushiFocusId _fallbackFocusId = FushiFocusId(
    'settings-textfield-${identityHashCode(this)}',
  );

  @override
  Widget build(BuildContext context) {
    return FushiTextField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      initialValue: widget.initialValue,
      hintText: widget.hintText,
      labelText: widget.labelText,
      obscureText: widget.obscureText,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      suffixIcon: widget.suffixIcon,
      focusId: widget.focusId ?? _fallbackFocusId,
    );
  }
}

class AdaptiveSettingsStepperRow extends StatelessWidget {
  const AdaptiveSettingsStepperRow({
    required this.title,
    required this.value,
    required this.step,
    required this.min,
    required this.max,
    required this.format,
    required this.onChanged,
    super.key,
    this.subtitle,
    this.icon,
    this.showIcon = false,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;

  /// 见 [AdaptiveSettingsSwitchRow.showIcon]。
  final bool showIcon;
  final double value;
  final double step;
  final double min;
  final double max;
  final String Function(double) format;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return AdaptiveSettingsRow(
      title: title,
      subtitle: subtitle,
      icon: icon,
      showIcon: showIcon,
      // BUG-2550：stepper 是最宽的自尺寸 trailing，把实宽报给行，让「窄到标题
      // 放不下」时真的堆叠，而不是把标题削成一个字。
      trailingWidth: kSettingsStepperTrailingWidth,
      trailing: _KeyboardStepper(
        value: value,
        step: step,
        min: min,
        max: max,
        format: format,
        onChanged: onChanged,
      ),
    );
  }
}

class _AdjustUpIntent extends Intent {
  const _AdjustUpIntent();
}

class _AdjustDownIntent extends Intent {
  const _AdjustDownIntent();
}

/// Wraps a value control (stepper / slider / seek bar) as a SINGLE keyboard &
/// gamepad focus stop whose Left/Right adjust the value in place instead of
/// moving focus. The control's own descendants are removed from focus traversal
/// ([ExcludeFocus]) so this wrapper is the one stop; they stay mouse-clickable.
///
/// Up/Down deliberately do NOT adjust the value — they fall through so the user
/// can move focus to the next/previous row. Binding Up/Down to adjust would trap
/// vertical navigation and silently change the focused control's value while the
/// user is only trying to scroll past it.
///
/// On desktop/Apple the gamepad D-pad arrives as a [GamepadButtonIntent] (not
/// arrow keys): Left/Right adjust + consume (return true) so focus does NOT
/// move; Up/Down (and others) are NOT consumed (return false) so the press
/// falls through to directional focus traversal between rows. On Android the
/// engine delivers the D-pad as arrow keys, handled by the [Shortcuts] below —
/// which mirror that contract: only Left/Right are bound.
class _GamepadAdjustableValue extends StatefulWidget {
  const _GamepadAdjustableValue({
    required this.focusIdPrefix,
    required this.onIncrement,
    required this.onDecrement,
    required this.child,
    this.focusId,
  });

  final String focusIdPrefix;
  final FushiFocusId? focusId;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final Widget child;

  @override
  State<_GamepadAdjustableValue> createState() =>
      _GamepadAdjustableValueState();
}

class _GamepadAdjustableValueState extends State<_GamepadAdjustableValue> {
  late final FushiFocusId _fallbackFocusId = FushiFocusId(
    '${widget.focusIdPrefix}-${identityHashCode(this)}',
  );

  @override
  Widget build(BuildContext context) {
    return Actions(
      actions: <Type, Action<Intent>>{
        _AdjustUpIntent: CallbackAction<_AdjustUpIntent>(
          onInvoke: (_) {
            widget.onIncrement();
            return null;
          },
        ),
        _AdjustDownIntent: CallbackAction<_AdjustDownIntent>(
          onInvoke: (_) {
            widget.onDecrement();
            return null;
          },
        ),
        // 只消费 D-pad 左/右（调值），其余按键**显式转发**给祖先，让它们真的到得了
        // 页面（Y 聚焦搜索、LT/RT 换 tab、D-pad 上下在行间移焦）。原先那句「Flutter
        // 停在第一个 ENABLED 的 action」不成立：Actions.maybeInvoke 上溯停在第一个
        // **注册了该 Intent 类型**的层，enabled 只决定要不要 invoke，所以靠 isEnabled
        // 让位实际是把这些按键静默吞掉。见 [GamepadButtonForwardingAction]。
        GamepadButtonIntent: GamepadButtonForwardingAction(
          ancestorContext: context,
          handle: (GamepadButton button) {
            if (button == GamepadButton.dpadRight) {
              widget.onIncrement();
              return true;
            }
            if (button == GamepadButton.dpadLeft) {
              widget.onDecrement();
              return true;
            }
            return false;
          },
        ),
      },
      child: Shortcuts(
        // Left/Right only — Up/Down are left unbound so they bubble to
        // directional focus traversal (move between rows). See class doc.
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.arrowRight): _AdjustUpIntent(),
          SingleActivator(LogicalKeyboardKey.arrowLeft): _AdjustDownIntent(),
        },
        child: FushiFocusTarget(
          id: widget.focusId ?? _fallbackFocusId,
          child: ExcludeFocus(child: widget.child),
        ),
      ),
    );
  }
}

/// The +/- controls of a stepper row, wrapped as a SINGLE keyboard/gamepad
/// focus stop. Tab lands here once (not once per button), and Left/Right
/// (D-pad or arrow keys) adjust the value in place (Right increment, Left
/// decrement) instead of leaking into directional focus traversal; Up/Down stay
/// free for row-to-row navigation. The inner buttons stay
/// mouse-clickable but are removed from focus traversal so they never become
/// separate, value-less tab stops.
///
/// The focus highlight comes from the app-wide [FushiFocusRing] (drawn around
/// whichever widget holds primary focus in keyboard/gamepad mode), so no local
/// border is reserved here — the control's layout is unchanged.
class _KeyboardStepper extends StatelessWidget {
  const _KeyboardStepper({
    required this.value,
    required this.step,
    required this.min,
    required this.max,
    required this.format,
    required this.onChanged,
  });

  final double value;
  final double step;
  final double min;
  final double max;
  final String Function(double) format;
  final ValueChanged<double> onChanged;

  void _increment() => onChanged((value + step).clamp(min, max));

  void _decrement() => onChanged((value - step).clamp(min, max));

  @override
  Widget build(BuildContext context) {
    final double clampedUp = (value + step).clamp(min, max);
    final double clampedDown = (value - step).clamp(min, max);
    // Expose a single "adjustable" node so screen readers (TalkBack / VoiceOver
    // / Narrator) can raise and lower the value via the platform increment /
    // decrement actions — the keyboard arrow shortcuts below are invisible to
    // assistive tech, and the +/- buttons are no longer separate focus stops.
    // excludeSemantics collapses the inner buttons/label into this one node.
    return _GamepadAdjustableValue(
      focusIdPrefix: 'settings-stepper',
      onIncrement: _increment,
      onDecrement: _decrement,
      child: Semantics(
        container: true,
        slider: true,
        value: format(value),
        increasedValue: format(clampedUp),
        decreasedValue: format(clampedDown),
        onIncrease: value < max ? _increment : null,
        onDecrease: value > min ? _decrement : null,
        excludeSemantics: true,
        child: Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 4,
          runSpacing: 4,
          children: [
            _SettingsStepButton(
              icon: Icons.remove,
              onPressed: _decrement,
              tooltip: t.decrease,
            ),
            SizedBox(
              width: kSettingsStepperValueWidth,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.center,
                child: Text(
                  format(value),
                  textAlign: TextAlign.center,
                  softWrap: false,
                  maxLines: 1,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            ),
            _SettingsStepButton(
              icon: Icons.add,
              onPressed: _increment,
              tooltip: t.increase,
            ),
          ],
        ),
      ),
    );
  }
}

/// The slider equivalent of [_KeyboardStepper]: a single keyboard/gamepad focus
/// stop whose Left/Right (D-pad or arrow keys) nudge the slider by one step,
/// while the slider stays draggable by mouse/touch. Up/Down are left free for
/// row-to-row focus navigation.
class _KeyboardSlider extends StatelessWidget {
  const _KeyboardSlider({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.divisions,
    this.label,
    this.onChangeEnd,
    this.step,
  });

  final double value;
  final double min;
  final double max;
  final int? divisions;
  final String? label;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeEnd;
  final double? step;

  /// One D-pad/arrow nudge: an explicit [step], else one division, else 1/20 of
  /// the range (a sensible default for continuous sliders).
  double get _step =>
      step ?? (divisions != null ? (max - min) / divisions! : (max - min) / 20);

  void _adjust(double delta) {
    final double next = (value + delta).clamp(min, max);
    onChanged(next);
    onChangeEnd?.call(next);
  }

  @override
  Widget build(BuildContext context) {
    return _GamepadAdjustableValue(
      focusIdPrefix: 'settings-slider',
      onIncrement: () => _adjust(_step),
      onDecrement: () => _adjust(-_step),
      child: Semantics(
        container: true,
        slider: true,
        onIncrease: value < max ? () => _adjust(_step) : null,
        onDecrease: value > min ? () => _adjust(-_step) : null,
        excludeSemantics: true,
        child: adaptiveSlider(
          context: context,
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          label: label,
          onChanged: onChanged,
          onChangeEnd: onChangeEnd,
        ),
      ),
    );
  }
}

class AdaptiveSettingsSliderRow extends StatelessWidget {
  const AdaptiveSettingsSliderRow({
    required this.title,
    required this.value,
    required this.onChanged,
    super.key,
    this.subtitle,
    this.icon,
    this.showIcon = false,
    this.min = 0,
    this.max = 1,
    this.divisions,
    this.label,
    this.onChangeEnd,
    this.step,
    this.readout,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;

  /// 见 [AdaptiveSettingsSwitchRow.showIcon]。
  final bool showIcon;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final String? label;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeEnd;

  /// Optional explicit gamepad/keyboard nudge step (overrides the
  /// division/default-based step) — for sliders whose natural increment differs
  /// from one division.
  final double? step;

  /// Optional live value readout appended to the displayed title as
  /// `Title (readout)` — fine-grained steps are pointless without a visible
  /// readout. Kept separate from [title] so the bare title remains the row's
  /// stable identity for focus-driven coverage tests and finders.
  final String? readout;

  @override
  Widget build(BuildContext context) {
    return AdaptiveSettingsRow(
      title: readout == null ? title : '$title ($readout)',
      subtitle: subtitle,
      icon: icon,
      showIcon: showIcon,
      controlBelow: true,
      trailing: _KeyboardSlider(
        value: value,
        min: min,
        max: max,
        divisions: divisions,
        label: label,
        onChanged: onChanged,
        onChangeEnd: onChangeEnd,
        step: step,
      ),
    );
  }
}

class AdaptiveSettingsNavigationRow extends StatelessWidget {
  const AdaptiveSettingsNavigationRow({
    required this.title,
    required this.onTap,
    super.key,
    this.subtitle,
    this.icon,
    this.showIcon = false,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final bool showIcon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color color = Theme.of(context).colorScheme.onSurfaceVariant;
    return AdaptiveSettingsRow(
      title: title,
      subtitle: subtitle,
      icon: icon,
      showIcon: showIcon && icon != null,
      onTap: onTap,
      trailing: Icon(
        Icons.chevron_right,
        size: 20,
        color: color,
      ),
    );
  }
}

class _SettingsLabel extends StatelessWidget {
  const _SettingsLabel({
    required this.title,
    this.subtitle,
    this.titleMaxLines,
    this.subtitleMaxLines,
  });

  final String title;
  final String? subtitle;
  final int? titleMaxLines;
  final int? subtitleMaxLines;

  @override
  Widget build(BuildContext context) {
    final TextStyle? titleStyle = Theme.of(context).textTheme.bodyMedium;
    final Color subtitleColor = Theme.of(context).colorScheme.onSurfaceVariant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          title,
          style: titleStyle,
          overflow: TextOverflow.ellipsis,
          maxLines: titleMaxLines ?? kSettingsRowTitleMaxLines,
        ),
        if (subtitle != null && subtitle!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              subtitle!,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: subtitleColor),
              // BUG-1184：null = 不钳行数，说明文字整段显示（见
              // [AdaptiveSettingsRow.subtitleMaxLines]）。
              //
              // overflow 必须跟着 maxLines 走，不能恒为 ellipsis：Flutter 的
              // ellipsis 在 maxLines 缺省时并不是「不生效」，而是把整段压成
              // **单行** + 省略号（RenderParagraph 实测：同一段文字 clip 排 8 行、
              // ellipsis 只排 1 行且 didExceedMaxLines=true）。BUG-1184 把默认从
              // 3 行改成 null 却留着 ellipsis，等于把说明文字从 3 行钳到 1 行——
              // 比修复前更糟。null 时交回 DefaultTextStyle（clip），换行显示整段。
              overflow: subtitleMaxLines == null ? null : TextOverflow.ellipsis,
              maxLines: subtitleMaxLines,
            ),
          ),
      ],
    );
  }
}

class _SettingsIcon extends StatelessWidget {
  const _SettingsIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return FushiBadge(
      icon: icon,
      background: scheme.secondaryContainer,
      foreground: scheme.onSecondaryContainer,
      padding: const EdgeInsets.all(6),
      size: 18,
    );
  }
}

class _SettingsStepButton extends StatelessWidget {
  const _SettingsStepButton({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 18),
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      onPressed: onPressed,
    );
  }
}
