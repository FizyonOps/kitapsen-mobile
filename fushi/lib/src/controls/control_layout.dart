/// 媒体页「控制按钮布局」的泛型模型：槽位（slot）× 按钮（item）的有序放置 +
/// 显式「已移除」集。纯 Dart，无 Flutter 依赖。
///
/// 视频页的 `VideoControlLayout` 是它的第一个宿主；阅读器工具栏复用同一份不变式
/// 与写操作，只提供自己的槽位枚举 / 按钮枚举 / 默认布局 / 域特判。
///
/// 不变式（由归一化构造与 pinned 守卫维护）：
///   - 每个按钮在同一个可见槽内最多出现一次（跨槽允许多份副本）；
///   - 按钮不在任何可见槽 ⇔ 它在 [ControlLayout.removedItems]（除必需项）；
///   - 老 / 残缺载荷可按 fallback assignment 回填缺失按钮；
///   - [ControlItemSpec.pinnedRequired] 的按钮不可移除，落空时回到
///     [ControlItemSpec.recoverySlot]。
library;

/// 槽位契约：持久化名。`isOnPlayer` 不放这里——由 [ControlLayoutScheme.hiddenSlot]
/// 决定，避免每个槽位枚举各写一遍「除 hidden 之外都可见」。
abstract interface class ControlSlotSpec {
  String get storageValue;
}

/// 按钮契约。宿主枚举实现它即可放进 [ControlLayout]。
abstract interface class ControlItemSpec<S> {
  String get storageValue;

  /// 必需项被错误移除后回落的槽位。
  S get recoverySlot;

  bool canMoveToSlot(S target, {bool isTouchControls = false});
}

/// 归一化后置钩子：宿主的域特判（例如视频的 volume 只能在底栏、title 只能在顶栏）。
/// 在去重 + 回填之后、最终 removed 清理之前调用，直接原地改 [slots] / [removed]。
typedef ControlLayoutPostNormalize<S, I> = void Function(
    Map<S, List<I>> slots, Set<I> removed);

/// 一个宿主的槽位全集 / 按钮全集 / hidden 槽位 / 后置钩子。[slots] 与 [items] 的
/// 顺序就是所有遍历、编码与 [ControlLayout.removedItems] 的顺序。
class ControlLayoutScheme<S extends ControlSlotSpec,
    I extends ControlItemSpec<S>> {
  const ControlLayoutScheme({
    required this.slots,
    required this.hiddenSlot,
    required this.items,
    this.postNormalize,
  });

  final List<S> slots;
  final S hiddenSlot;
  final List<I> items;
  final ControlLayoutPostNormalize<S, I>? postNormalize;

  bool isOnPlayer(S slot) => slot != hiddenSlot;

  /// 持久化模型允许把该按钮从播放器上拿掉（跨平台、无触屏门）。
  bool canBeRemoved(I item) => item.canMoveToSlot(hiddenSlot);

  S? parseSlot(String value) {
    for (final S slot in slots) {
      if (slot.storageValue == value) return slot;
    }
    return null;
  }

  I? parseItem(String value) {
    for (final I item in items) {
      if (item.storageValue == value) return item;
    }
    return null;
  }

  Map<S, List<I>> emptySlotMap() => <S, List<I>>{
        for (final S slot in slots) slot: <I>[],
      };
}

class _NormalizedControlLayoutData<S, I> {
  const _NormalizedControlLayoutData({
    required this.slots,
    required this.removed,
  });

  final Map<S, List<I>> slots;
  final Set<I> removed;
}

/// 逐槽有序的按钮布局（不可变；每个写操作返回新实例）。
class ControlLayout<S extends ControlSlotSpec, I extends ControlItemSpec<S>> {
  ControlLayout._(this.scheme, this._slots, Set<I> removed)
      : _removed = Set<I>.unmodifiable(removed);

  /// 直接从「槽位 → 有序按钮」构建，**不跨槽去重**（同一按钮可在多个槽）。不在任何
  /// 可见槽的按钮按 [assignments] 回填，除非它在 [removedItems]；pinned 守卫照常。
  factory ControlLayout.fromSlots(
    ControlLayoutScheme<S, I> scheme,
    Map<S, List<I>> slotItems, {
    Map<I, S>? assignments,
    Set<I>? removedItems,
  }) {
    final Map<S, List<I>> slots = scheme.emptySlotMap();
    final Set<I> removed = <I>{...?removedItems};
    final Set<I> seen = <I>{};
    for (final S slot in scheme.slots) {
      for (final I item in slotItems[slot] ?? const <Never>[]) {
        // 只在槽内去重；跨槽的同一按钮允许。
        if (slots[slot]!.contains(item)) continue;
        final bool placed = _placeRawItem(scheme, slots, removed, item, slot);
        if (placed) seen.add(item);
      }
    }
    for (final I item in scheme.items) {
      if (seen.contains(item)) continue;
      if (removed.contains(item) && scheme.canBeRemoved(item)) continue;
      final S slot = assignments?[item] ?? scheme.hiddenSlot;
      _placeRawItem(scheme, slots, removed, item, slot);
    }
    return _fromRaw(
      scheme,
      slots,
      removedItems: removed,
      fallbackAssignments: assignments,
    );
  }

  /// 解码持久化的「槽位名 → 按钮名列表」表。hidden 槽键下列出的按钮一律视作
  /// 已移除（这是 v2 → v3 迁移语义，也是唯一合理的通用解释：hidden 不是渲染面）。
  /// 一个可见按钮都没有且 removed 为空 ⇒ 返回 null，由宿主决定兜底布局。
  static ControlLayout<S, I>?
      decodeSlots<S extends ControlSlotSpec, I extends ControlItemSpec<S>>(
    ControlLayoutScheme<S, I> scheme,
    Map<String, dynamic> slotsRaw, {
    Object? removedRaw,
    Map<I, S>? fallbackAssignments,
  }) {
    final Map<S, List<I>> explicitOrder = <S, List<I>>{};
    final Set<I> removed = <I>{};
    if (removedRaw is List) {
      for (final Object? rawItem in removedRaw) {
        if (rawItem is! String) continue;
        final I? item = scheme.parseItem(rawItem);
        if (item != null && scheme.canBeRemoved(item)) {
          removed.add(item);
        }
      }
    }
    int visibleItemCount = 0;
    for (final MapEntry<String, dynamic> entry in slotsRaw.entries) {
      final S? slot = scheme.parseSlot(entry.key);
      final Object? listRaw = entry.value;
      if (slot == null || listRaw is! List) continue;
      if (slot == scheme.hiddenSlot) {
        for (final Object? rawItem in listRaw) {
          if (rawItem is! String) continue;
          final I? item = scheme.parseItem(rawItem);
          if (item != null && scheme.canBeRemoved(item)) removed.add(item);
        }
        continue;
      }
      final List<I> items = <I>[];
      for (final Object? rawItem in listRaw) {
        if (rawItem is! String) continue;
        final I? item = scheme.parseItem(rawItem);
        if (item == null) continue;
        if (!item.canMoveToSlot(slot)) continue;
        items.add(item);
      }
      visibleItemCount += items.length;
      explicitOrder[slot] = items;
    }
    if (visibleItemCount == 0 && removed.isEmpty) return null;
    return ControlLayout<S, I>.fromSlots(
      scheme,
      explicitOrder,
      assignments: fallbackAssignments,
      removedItems: removed,
    );
  }

  static bool
      _placeRawItem<S extends ControlSlotSpec, I extends ControlItemSpec<S>>(
    ControlLayoutScheme<S, I> scheme,
    Map<S, List<I>> slots,
    Set<I> removed,
    I item,
    S slot,
  ) {
    if (slot == scheme.hiddenSlot) {
      if (scheme.canBeRemoved(item)) {
        removed.add(item);
      }
      return false;
    }
    if (!item.canMoveToSlot(slot)) return false;
    slots[slot]!.add(item);
    removed.remove(item);
    return true;
  }

  static ControlLayout<S, I>
      _fromRaw<S extends ControlSlotSpec, I extends ControlItemSpec<S>>(
    ControlLayoutScheme<S, I> scheme,
    Map<S, List<I>> slots, {
    Set<I> removedItems = const <Never>{},
    Map<I, S>? fallbackAssignments,
  }) {
    final _NormalizedControlLayoutData<S, I> data = _normalize(
      scheme,
      slots,
      removedItems: removedItems,
      fallbackAssignments: fallbackAssignments,
    );
    return ControlLayout<S, I>._(scheme, data.slots, data.removed);
  }

  final ControlLayoutScheme<S, I> scheme;
  final Map<S, List<I>> _slots;
  final Set<I> _removed;

  /// 槽内有序按钮（不可变副本）。
  List<I> itemsIn(S slot) =>
      List<I>.unmodifiable(_slots[slot] ?? const <Never>[]);

  /// 按钮所在的第一个槽位；不在任何可见槽 ⇒ hidden。
  S slotOf(I item) {
    for (final S slot in scheme.slots) {
      if (_slots[slot]!.contains(item)) return slot;
    }
    return scheme.hiddenSlot;
  }

  /// 归一化不变式维护者：
  ///   1. 同一可见槽内按钮至多一次；
  ///   2. 按钮缺席播放器 ⇔ 显式移除；
  ///   3. 老 / 残缺载荷按 [fallbackAssignments] 回填；
  ///   4. 必需项不可移除；
  ///   5. 宿主后置钩子跑在最终 removed 清理之前。
  static _NormalizedControlLayoutData<S, I>
      _normalize<S extends ControlSlotSpec, I extends ControlItemSpec<S>>(
    ControlLayoutScheme<S, I> scheme,
    Map<S, List<I>> rawSlots, {
    Set<I> removedItems = const <Never>{},
    Map<I, S>? fallbackAssignments,
  }) {
    final Map<S, List<I>> slots = scheme.emptySlotMap();
    final Set<I> removed = <I>{
      for (final I item in removedItems)
        if (scheme.canBeRemoved(item)) item,
    };
    for (final S slot in scheme.slots) {
      for (final I item in rawSlots[slot] ?? const <Never>[]) {
        _placeRawItem(scheme, slots, removed, item, slot);
      }
    }
    for (final S slot in scheme.slots) {
      final Set<I> seen = <I>{};
      slots[slot]!.removeWhere((I item) => !seen.add(item));
    }

    final Set<I> visible = <I>{
      for (final S slot in scheme.slots)
        if (scheme.isOnPlayer(slot)) ...slots[slot]!,
    };
    removed.removeWhere(
      (I item) => visible.contains(item) || !scheme.canBeRemoved(item),
    );

    for (final I item in scheme.items) {
      if (visible.contains(item)) continue;
      if (removed.contains(item)) continue;
      final S? fallback = fallbackAssignments?[item];
      if (fallback != null) {
        final bool placed = _placeRawItem(
          scheme,
          slots,
          removed,
          item,
          fallback,
        );
        if (placed) {
          visible.add(item);
          continue;
        }
        if (removed.contains(item)) continue;
      }
      if (scheme.canBeRemoved(item)) {
        removed.add(item);
      } else {
        _placeRawItem(scheme, slots, removed, item, item.recoverySlot);
        visible.add(item);
      }
    }
    scheme.postNormalize?.call(slots, removed);
    removed.removeWhere(
      (I item) =>
          !scheme.canBeRemoved(item) ||
          scheme.slots.any(
            (S slot) => scheme.isOnPlayer(slot) && slots[slot]!.contains(item),
          ),
    );
    slots[scheme.hiddenSlot]!.clear();
    return _NormalizedControlLayoutData<S, I>(slots: slots, removed: removed);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ControlLayout<S, I>) return false;
    for (final S slot in scheme.slots) {
      final List<I> a = _slots[slot]!;
      final List<I> b = other._slots[slot]!;
      if (a.length != b.length) return false;
      for (int i = 0; i < a.length; i++) {
        if (a[i] != b[i]) return false;
      }
    }
    if (_removed.length != other._removed.length) return false;
    return _removed.containsAll(other._removed);
  }

  @override
  int get hashCode {
    return Object.hashAll(<Object>[
      for (final S slot in scheme.slots) ...<Object>[slot, ..._slots[slot]!],
      'removed',
      for (final I item in scheme.items)
        if (_removed.contains(item)) item,
    ]);
  }
}
