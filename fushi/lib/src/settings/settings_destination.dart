import 'dart:async';

import 'package:flutter/material.dart';
import 'package:fushi/src/settings/settings_context.dart';

enum SettingsDestinationId {
  appearance,
  reading,
  services,
  storage,
  system,
  readerQuickSettings,
}

/// 书内快捷面板的分组维度，与全局 [SettingsDestinationId] 正交。
/// 一个设置项可以同时出现在全局某 destination 和书内某 [ReaderGroup]。
///
/// TODO-802/774：原「外观」组（appearance）已删——字体/行高/缩进早已并入
/// [layout]（TODO-774），最后只剩主题选择器，亦并入 [layout]（主题改的也是阅读
/// 显示），外观组整个不再存在。
enum ReaderGroup { layout, behavior }

/// 描述某个 [SettingsItem] 在书内快捷面板里的放置位置。
/// 为 null 表示该项不出现在书内面板（仅全局可见）。
class ReaderPlacement {
  const ReaderPlacement({required this.group, required this.order});

  final ReaderGroup group;

  /// 在所属 [group] 内的升序排序键（仅组内有效，可有间隔）。
  final int order;
}

typedef SettingsVisibility = bool Function(SettingsContext context);

/// 渲染时求值的副标题。返回 null = 用静态 [SettingsItem.subtitle]。
///
/// 与 [SettingsItem.titleBuilder] 同一条纪律：schema 树按 locale 缓存、构造期求值，
/// 任何运行期状态都不许插进 `subtitle` 字面量（守卫见 settings_schema_cache_test 的
/// 「静态文案逐字不变」）。副标题要随运行期状态变，只能走这个闭包。
typedef SettingsSubtitleBuilder = String? Function(SettingsContext context);
typedef SettingsItemAction = FutureOr<void> Function(SettingsContext context);
typedef SettingsItemBuilder = Widget Function(SettingsContext context);
typedef SettingsValueGetter<T extends Object> =
    T Function(SettingsContext context);
typedef SettingsValueChanged<T extends Object> =
    FutureOr<void> Function(SettingsContext context, T value);
typedef SettingsSwitchGetter = bool Function(SettingsContext context);
typedef SettingsSwitchChanged =
    FutureOr<void> Function(SettingsContext context, bool value);
typedef SettingsDoubleFormatter = String Function(double value);

class SettingsDestination {
  const SettingsDestination({
    required this.id,
    required this.title,
    required this.icon,
    required this.sections,
    this.summary,
    this.visible,
    this.body,
    this.bodyBeforeSections = false,
    this.bodySearchEntries = const <SettingsBodySearchEntry>[],
  });

  final SettingsDestinationId id;
  final String title;
  final IconData icon;
  final String? summary;
  final SettingsVisibility? visible;
  final List<SettingsSection> sections;

  /// 可选的「整页正文」逃生口：非空时，渲染器在渲染完 [sections] 后把
  /// `body(context)` 接在同一个滚动容器里。用于把原本藏在子级菜单（独立路由
  /// 页）的复杂正文——Anki 设置、Profile 管理——直接平铺进本 destination 详情页，
  /// 消掉一层多余跳转。返回的 widget 必须自带 [AdaptiveSettingsSection] 布局且
  /// **不得**自带脚手架/独立滚动（外层渲染器已提供滚动与内边距）。
  final SettingsItemBuilder? body;

  /// Allows an existing grouped form to precede navigation without nesting its
  /// surfaces inside a synthetic schema row.
  final bool bodyBeforeSections;

  /// 自绘正文的搜索元数据。索引器沿子页路径递归收集；声明 hasRevealTarget 的
  /// 行使用真实 SettingsSearchTarget 定位，其余兼容条目只导航到所在页。
  final List<SettingsBodySearchEntry> bodySearchEntries;

  bool isVisible(SettingsContext context) => visible?.call(context) ?? true;

  List<SettingsSection> visibleSections(SettingsContext context) {
    return sections
        .where((SettingsSection section) => section.isVisible(context))
        .map((SettingsSection section) => section.visibleCopy(context))
        .where((SettingsSection section) => section.items.isNotEmpty)
        .toList(growable: false);
  }
}

/// [SettingsDestination.bodySearchEntries] 的一条：body 逃生口正文里某个设置行
/// 的搜索元数据（标题用与正文行一致的 i18n 文案；[subtitle] 参与元数据打分）。
/// [visible] 为 null 表示恒可搜；否则与渲染同款谓词求值，平台/状态下不显示的
/// 行不会进搜索索引。
class SettingsBodySearchEntry {
  const SettingsBodySearchEntry({
    required this.id,
    required this.title,
    this.subtitle,
    this.visible,
    this.hasRevealTarget = false,
  });

  /// 全局唯一 id（如 `card_creation.anki.deck`），与真实正文挂点使用相同身份。
  final String id;
  final String title;
  final String? subtitle;
  final SettingsVisibility? visible;

  /// True only when the real body row is wrapped in SettingsSearchTarget.
  final bool hasRevealTarget;

  bool isVisible(SettingsContext context) => visible?.call(context) ?? true;
}

/// 测试钩子：为 true 时，渲染器忽略每个 section 的 [SettingsSection.collapsedByDefault]，
/// 把所有可折叠 section 一律按展开渲染。默认折叠会把折叠 section 的行移出 widget 树，
/// 而 `settings_schema_coverage_test` 以 Tab 焦点遍历逐行驱动——够不到的行会被静默跳过、
/// 削弱这道覆盖守卫。凡「枚举/驱动全部设置行」的测试须在 setUp 里置 true、tearDown 复位。
bool debugSettingsForceExpandAllSections = false;

/// Core controls remain visible; secondary groups explicitly opt into folding.
enum SettingsSectionPresentation { alwaysExpanded, expanded, collapsed }

class SettingsSection {
  const SettingsSection({
    required this.items,
    this.id,
    this.title,
    this.footer,
    this.visible,
    bool collapsedByDefault = false,
    SettingsSectionPresentation? presentation,
    this.summaryBuilder,
  }) : presentation =
           presentation ??
           (collapsedByDefault
               ? SettingsSectionPresentation.collapsed
               : SettingsSectionPresentation.alwaysExpanded);

  /// Stable identity independent of translated titles or visible row positions.
  final String? id;
  final SettingsSectionPresentation presentation;
  final SettingsSubtitleBuilder? summaryBuilder;

  final String? title;
  final String? footer;
  final SettingsVisibility? visible;
  final List<SettingsItem> items;

  bool isVisible(SettingsContext context) => visible?.call(context) ?? true;

  SettingsSection visibleCopy(SettingsContext context) {
    return SettingsSection(
      id: id ?? (items.isEmpty ? null : 'section.${items.first.id}'),
      title: title,
      footer: footer,
      visible: visible,
      presentation: presentation,
      summaryBuilder: summaryBuilder,
      items: items
          .where((SettingsItem item) => item.isVisible(context))
          .toList(growable: false),
    );
  }
}

sealed class SettingsItem {
  const SettingsItem({
    required this.id,
    required this.title,
    this.titleBuilder,
    this.subtitle,
    this.subtitleBuilder,
    this.icon,
    this.visible,
    this.reader,
  });

  final String id;

  /// 静态标题。schema 树按 locale 缓存（见 settings_schema.dart 的
  /// `_SettingsSchemaCache`），故本字段在**构造期**求值一次——它只能是 i18n 常量，
  /// 不得插值任何运行期状态。标题要随状态变（计数、当前值），用 [titleBuilder]。
  final String title;

  /// 渲染时求值的标题；非空时覆盖 [title]。
  ///
  /// 存在的理由：`title` 是这个数据结构里唯一「只能构造期求值」的字段，而
  /// `value` / `visible` / `onChanged` 全是渲染时求值的闭包。诊断分区那三行
  /// （错误日志 / 崩溃转储 / 调试日志）需要在标题里带实时条数，此前只能靠
  /// 「每次 build 重建整棵 schema」来刷新——这正是全量重建的成因之一，而且顺带让
  /// 崩溃转储行每帧做一次同步目录扫描。补上这个闭包后标题与其它字段对称，动态
  /// 标题在渲染时算、缓存树保持纯净。
  ///
  /// 目前只有 [SettingsNavigationItem] 透传；其它 item 类型需要时照此加
  /// `super.titleBuilder` 即可。
  final SettingsValueGetter<String>? titleBuilder;

  final String? subtitle;

  /// 渲染时求值的副标题；返回非 null 时覆盖 [subtitle]。见 [SettingsSubtitleBuilder]。
  ///
  /// 目前只有 [SettingsSwitchItem] / [SettingsActionItem] 透传（游戏内查词要按 hook
  /// 报上来的准入状态说明为什么开关被灰了，并把游戏 exe 摘要摆出来）；其它 item
  /// 类型需要时照此加 `super.subtitleBuilder`。
  final SettingsSubtitleBuilder? subtitleBuilder;

  final IconData? icon;
  final SettingsVisibility? visible;

  /// 书内快捷面板放置；null = 仅全局可见。
  final ReaderPlacement? reader;

  bool isVisible(SettingsContext context) => visible?.call(context) ?? true;

  /// 渲染 / 搜索展示用的标题：有 [titleBuilder] 就用它，否则用静态 [title]。
  String resolveTitle(SettingsContext context) =>
      titleBuilder?.call(context) ?? title;

  /// 渲染 / 搜索展示用的副标题：有 [subtitleBuilder] 且它给了值就用它，否则用静态
  /// [subtitle]。
  String? resolveSubtitle(SettingsContext context) =>
      subtitleBuilder?.call(context) ?? subtitle;
}

class SettingsNavigationItem extends SettingsItem {
  const SettingsNavigationItem({
    required super.id,
    required super.title,
    super.titleBuilder,
    this.builder,
    this.onTap,
    this.child,
    this.showIcon = false,
    super.subtitle,
    super.subtitleBuilder,
    super.icon,
    super.visible,
    super.reader,
  }) : assert(builder != null || onTap != null || child != null);

  final WidgetBuilder? builder;
  final SettingsItemAction? onTap;

  /// 子 schema 页：点本行推一个与顶层分类同一套详情壳的 [SettingsDestination]
  /// （`SettingsDetailPage.subPage`）。与 [builder] / [SettingsDestination.body]
  /// 逃生口的区别：子页的行是真正的 schema item——进设置搜索索引（命中后先进父页
  /// 再推子页定位）、进焦点覆盖遍历，不需要 `bodySearchEntries` 手工登记。
  ///
  /// 子页共用父分类的 [SettingsDestination.id]（枚举不为子页扩容）；它靠本闭包而非
  /// id 取新鲜树，所以闭包必须是零参、构造期只读 i18n 常量（与顶层分类同一条
  /// `settings_schema_cache_test` 纪律）。
  final SettingsDestination Function()? child;
  final bool showIcon;
}

class SettingsActionItem extends SettingsItem {
  const SettingsActionItem({
    required super.id,
    required super.title,
    required this.onTap,
    super.subtitle,
    super.subtitleBuilder,
    super.icon,
    super.visible,
    super.reader,
  });

  final SettingsItemAction onTap;
}

class SettingsSwitchItem extends SettingsItem {
  const SettingsSwitchItem({
    required super.id,
    required super.title,
    required this.value,
    required this.onChanged,
    super.subtitle,
    super.subtitleBuilder,
    super.icon,
    super.visible,
    super.reader,
  });

  final SettingsSwitchGetter value;
  final SettingsSwitchChanged onChanged;
}

class SettingsSegmentOption<T extends Object> {
  const SettingsSegmentOption({
    required this.value,
    required this.label,
    this.icon,
    this.tooltip,
  });

  final T value;
  final String label;
  final IconData? icon;
  final String? tooltip;
}

class SettingsSegmentedItem<T extends Object> extends SettingsItem {
  const SettingsSegmentedItem({
    required super.id,
    required super.title,
    required this.options,
    required this.selected,
    required this.onChanged,
    super.subtitle,
    super.icon,
    super.visible,
    super.reader,
    this.controlBelow = true,
  });

  final List<SettingsSegmentOption<T>> options;
  final SettingsValueGetter<T> selected;
  final SettingsValueChanged<T> onChanged;
  final bool controlBelow;

  /// 渲染器持有的是 `SettingsSegmentedItem<Object>`，静态读 [onChanged]（实际签名
  /// `(ctx, T)`）会因函数参数逆变抛 `_TypeError`——故在真实 [T] 上下文里转回再调。
  FutureOr<void> dispatchChange(SettingsContext context, Object value) =>
      onChanged(context, value as T);
}

class SettingsSliderItem extends SettingsItem {
  const SettingsSliderItem({
    required super.id,
    required super.title,
    required this.value,
    required this.onChanged,
    super.subtitle,
    super.icon,
    super.visible,
    super.reader,
    this.min = 0,
    this.max = 1,
    this.divisions,
    this.label,
    this.onChangeEnd,
    this.step,
    this.titleReadout = false,
    this.commitOnRelease = false,
  }) : assert(
         !commitOnRelease || onChangeEnd == null,
         'commitOnRelease 滑条松手统一走 onChanged 提交，不得再声明 onChangeEnd',
       );

  final double Function(SettingsContext context) value;
  final double min;
  final double max;
  final int? divisions;
  final SettingsDoubleFormatter? label;
  final SettingsValueChanged<double> onChanged;
  final SettingsValueChanged<double>? onChangeEnd;

  /// 键盘 / 手柄左右键单按步进（覆盖默认的「一档 divisions」步进）。
  /// 用于拖动档位（细）与按键步进（粗）需要解耦的滑条。
  final double? step;

  /// 为 true 时渲染器在标题后追加实时读数 `(label(value))`，如「音量 (95%)」。
  /// [title] 本身保持裸标题不变（焦点遍历 / 覆盖测试以裸标题为身份 key）。
  final bool titleReadout;

  /// 为 true 时拖动只更新渲染层本地预览值（跟手 + 读数实时），松手才把最终值经
  /// [onChanged] 提交一次。用于写穿成本高（BUG-963：播放页逐 tick 写穿触发全页
  /// rebuild 掉帧）且拖动过程无实时预览意义的滑条；键盘/手柄步进仍每按即提交。
  /// 与 [onChangeEnd] 互斥（松手提交统一走 [onChanged]）。
  final bool commitOnRelease;
}

class SettingsStepperItem extends SettingsItem {
  const SettingsStepperItem({
    required super.id,
    required super.title,
    required this.value,
    required this.step,
    required this.min,
    required this.max,
    required this.format,
    required this.onChanged,
    super.subtitle,
    super.icon,
    super.visible,
    super.reader,
  });

  final double Function(SettingsContext context) value;
  final double step;
  final double min;
  final double max;
  final SettingsDoubleFormatter format;
  final SettingsValueChanged<double> onChanged;
}

/// 一等文本输入项：字符串值经 getter/setter 闭包同步读写。渲染复用
/// settings_schema_fields 的 [SettingsSecretField] 内部（防抖/提交语义一致），
/// 由共享 SettingsSchemaItem 分发，Material/Cupertino 同路径。
class SettingsTextItem extends SettingsItem {
  const SettingsTextItem({
    required super.id,
    required super.title,
    required this.value,
    required this.onChanged,
    this.secret = false,
    this.debounce = const Duration(milliseconds: 500),
    this.resetValue,
    this.placeholder,
    this.keyboardType,
    super.subtitle,
    super.icon,
    super.visible,
    super.reader,
  });

  final SettingsValueGetter<String> value;
  final SettingsValueChanged<String> onChanged;

  /// true = 敏感值：明文遮蔽渲染 + 行尾眼睛按钮切换显隐（API key 等）。
  final bool secret;

  /// 击键到写穿的防抖间隔；[Duration.zero] = 每次击键立即写。提交（回车）恒立即写。
  final Duration debounce;

  /// 非 null 时行尾提供重置按钮，点击把该值写回并回填输入框。
  final SettingsValueGetter<String>? resetValue;

  /// 输入框占位提示；null = 不显示。
  final String? placeholder;

  /// null 时按 [secret] 取 visiblePassword / text。
  final TextInputType? keyboardType;
}

class SettingsCustomItem extends SettingsItem {
  const SettingsCustomItem({
    required super.id,
    required this.builder,
    super.title = '',
    this.searchTitle,
    super.subtitle,
    super.icon,
    super.visible,
    super.reader,
  });

  final SettingsItemBuilder builder;

  /// 搜索元数据 opt-in：custom 行的 [title] 通常为空（正文由 [builder] 自绘），
  /// 默认不可搜。声明本字段后该行以此标题进入设置搜索（展平/打分/结果展示均用它，
  /// 见 settingsItemSearchTitle）；不影响渲染。
  final String? searchTitle;
}
