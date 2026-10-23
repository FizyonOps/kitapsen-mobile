/// 阅读器顶栏 / 底栏按钮的可视化布局模型（与视频页 `VideoControlLayout` 同一套
/// 泛型骨架 `ControlLayout<S, I>`，用户 2026-09-13 要求「和视频一样支持可视化调整」）。
///
/// 六个可见槽位 + hidden：顶栏左 / 中 / 右、底栏左 / 中 / 右。顶栏中间只放书名；
/// 书名也只能在顶栏中间（或移出）。返回与设置是必需项：任何平台都不能移出——返回是
/// 退书的唯一可见入口（BUG-2230 同一口径），设置是其它所有面板的入口。
///
/// 悬浮球不是这里的槽：它的按钮在 设置 → 悬浮球 → 阅读器 里勾选
/// （`docs/specs/2026-09-28-floating-ball.md`）。旧版布局 JSON 里的 `floatingBall`
/// 槽解码时按未知槽丢弃，里面的按钮回落到出厂位置（有声书传输键在托盘）。
///
/// 持久化键 `reader_control_layout`，JSON `{version:1, slots:{...}, removed:[...]}`
/// （与视频 v3 同形；阅读器没有历史布局，不需要迁移）。
library;

import 'dart:convert';

import 'package:fushi/src/controls/control_layout.dart';

enum ReaderControlSlot implements ControlSlotSpec {
  topLeft('topLeft'),
  topCenter('topCenter'),
  topRight('topRight'),
  bottomLeft('bottomLeft'),
  bottomCenter('bottomCenter'),
  bottomRight('bottomRight'),
  hidden('hidden');

  const ReaderControlSlot(this.storageValue);

  @override
  final String storageValue;

  bool get isTop =>
      this == ReaderControlSlot.topLeft ||
      this == ReaderControlSlot.topCenter ||
      this == ReaderControlSlot.topRight;

  bool get isBottom =>
      this == ReaderControlSlot.bottomLeft ||
      this == ReaderControlSlot.bottomCenter ||
      this == ReaderControlSlot.bottomRight;

}

enum ReaderControlItem implements ControlItemSpec<ReaderControlSlot> {
  /// ← 退书（maybePop → PopScope 落位置 / 关书同步）。必需。
  back('back', pinnedRequired: true, recoverySlot: ReaderControlSlot.topLeft),

  /// 目录 / 搜索 / 收藏（左侧导航抽屉）。
  navigation('navigation', recoverySlot: ReaderControlSlot.topLeft),

  /// 插图册。
  gallery('gallery', recoverySlot: ReaderControlSlot.topLeft),

  /// 书内统计侧栏。
  statistics('statistics', recoverySlot: ReaderControlSlot.topLeft),

  /// 暂停 / 继续阅读统计计时（与状态行计时键、快捷键 P 同一入口）。出厂在托盘，
  /// 悬浮球出厂带上它（见 设置 → 悬浮球 → 阅读器）；可拖去顶栏 / 底栏。
  studyTimer('studyTimer', recoverySlot: ReaderControlSlot.topRight),

  /// 书名（只能在顶栏中间）。
  title('title', recoverySlot: ReaderControlSlot.topCenter),

  /// 外观 / 阅读设置抽屉。必需。
  settings(
    'settings',
    pinnedRequired: true,
    recoverySlot: ReaderControlSlot.topRight,
  );

  const ReaderControlItem(
    this.storageValue, {
    this.pinnedRequired = false,
    required this.recoverySlot,
  });

  @override
  final String storageValue;

  final bool pinnedRequired;

  /// 阅读器没有「触屏才必需」的按钮：触屏与桌面共用同一套 chrome。
  bool get pinnedOnTouch => false;

  /// 所有阅读器按钮都是单实例（同一颗不该出现在两处）。
  bool get isSingleInstance => true;

  @override
  final ReaderControlSlot recoverySlot;

  @override
  bool canMoveToSlot(ReaderControlSlot target, {bool isTouchControls = false}) {
    if (target == ReaderControlSlot.hidden) return !pinnedRequired;
    // 顶栏中间只收书名；书名只去顶栏中间。
    if (this == ReaderControlItem.title) {
      return target == ReaderControlSlot.topCenter;
    }
    return target != ReaderControlSlot.topCenter;
  }

  static ReaderControlItem? fromStorage(String value) {
    for (final ReaderControlItem item in values) {
      if (item.storageValue == value) return item;
    }
    return null;
  }
}

/// 顶栏中间只有书名：其它按钮误进 topCenter 时挪回各自的 recoverySlot。
void _readerPostNormalize(
  Map<ReaderControlSlot, List<ReaderControlItem>> slots,
  Set<ReaderControlItem> removed,
) {
  final List<ReaderControlItem> center = slots[ReaderControlSlot.topCenter]!;
  for (final ReaderControlItem item in List<ReaderControlItem>.of(center)) {
    if (item == ReaderControlItem.title) continue;
    center.remove(item);
    final List<ReaderControlItem> home = slots[item.recoverySlot]!;
    if (!home.contains(item)) home.add(item);
  }
  for (final ReaderControlSlot slot in ReaderControlSlot.values) {
    if (slot == ReaderControlSlot.topCenter) continue;
    slots[slot]!.remove(ReaderControlItem.title);
  }
}

const ControlLayoutScheme<ReaderControlSlot, ReaderControlItem>
    kReaderControlScheme =
    ControlLayoutScheme<ReaderControlSlot, ReaderControlItem>(
  slots: ReaderControlSlot.values,
  hiddenSlot: ReaderControlSlot.hidden,
  items: ReaderControlItem.values,
  postNormalize: _readerPostNormalize,
);

/// 阅读器按钮布局：`ControlLayout` 的薄包装，负责出厂布局与 JSON 编解码。
class ReaderControlLayout {
  const ReaderControlLayout._(this.core);

  final ControlLayout<ReaderControlSlot, ReaderControlItem> core;

  /// 出厂布局：左「← / 目录 / 插图 / 统计」，中「书名」，右「设置」；底栏三槽为空。
  static final ReaderControlLayout defaults = ReaderControlLayout._(
    ControlLayout<ReaderControlSlot, ReaderControlItem>.fromSlots(
      kReaderControlScheme,
      <ReaderControlSlot, List<ReaderControlItem>>{
        ReaderControlSlot.topLeft: <ReaderControlItem>[
          ReaderControlItem.back,
          ReaderControlItem.navigation,
          ReaderControlItem.gallery,
          ReaderControlItem.statistics,
        ],
        ReaderControlSlot.topCenter: <ReaderControlItem>[
          ReaderControlItem.title,
        ],
        ReaderControlSlot.topRight: <ReaderControlItem>[
          ReaderControlItem.settings,
        ],
      },
    ),
  );

  static Map<ReaderControlItem, ReaderControlSlot> _defaultAssignments() =>
      <ReaderControlItem, ReaderControlSlot>{
        for (final ReaderControlItem item in ReaderControlItem.values)
          item: defaults.core.slotOf(item),
      };

  List<ReaderControlItem> itemsIn(ReaderControlSlot slot) => core.itemsIn(slot);

  bool get showsTitle => core
      .itemsIn(ReaderControlSlot.topCenter)
      .contains(ReaderControlItem.title);

  /// 空 / 坏 JSON → 出厂布局；一个可见按钮都没有 → 出厂布局。
  static ReaderControlLayout decode(String json) {
    if (json.trim().isEmpty) return defaults;
    try {
      final Object? raw = jsonDecode(json);
      if (raw is! Map<String, dynamic>) return defaults;
      final Object? slotsRaw = raw['slots'];
      if (slotsRaw is! Map<String, dynamic>) return defaults;
      final ControlLayout<ReaderControlSlot, ReaderControlItem>? core =
          ControlLayout.decodeSlots<ReaderControlSlot, ReaderControlItem>(
        kReaderControlScheme,
        slotsRaw,
        removedRaw: raw['removed'],
        fallbackAssignments: _defaultAssignments(),
      );
      return core == null ? defaults : ReaderControlLayout._(core);
    } catch (_) {
      return defaults;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is ReaderControlLayout && other.core == core;

  @override
  int get hashCode => core.hashCode;
}
