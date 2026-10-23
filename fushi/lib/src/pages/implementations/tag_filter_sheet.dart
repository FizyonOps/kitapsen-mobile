import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fushi_core/fushi_core.dart';
import 'package:fushi/src/models/app_model.dart';

final selectedTagIdsProvider = StateProvider<Set<int>>((_) => {});

final filteredBookIdsProvider = FutureProvider<Set<String>?>((ref) async {
  final tagIds = ref.watch(selectedTagIdsProvider);
  if (tagIds.isEmpty) return null;
  final db = ref.watch(appProvider).database;
  return db.getBookKeysForAllTags(tagIds);
});

final allTagsProvider = FutureProvider<List<BookTagRow>>((ref) async {
  final db = ref.watch(appProvider).database;
  return db.getAllTags();
});

/// v79 合表后的通用组装：某 kind 的「entryKey → 标签列表」。kind 过滤在 SQL
/// 面（PK 前缀白拿索引；review5-8：书架同屏 watch 三个 kind 的 provider，全表
/// 扫描三遍再 Dart 滤是纯浪费）。
Future<Map<String, List<BookTagRow>>> _tagMapForKind(
    FushiDatabase db, TagHostKind kind) async {
  final tags = await db.getAllTags();
  final tagById = {for (final t in tags) t.id: t};
  final Map<String, List<BookTagRow>> result = {};
  for (final TagAssignmentRow m in await db.getTagAssignmentsForKind(kind)) {
    final tag = tagById[m.tagId];
    if (tag != null) {
      result.putIfAbsent(m.entryKey, () => []).add(tag);
    }
  }
  return result;
}

final bookTagMapProvider =
    FutureProvider<Map<String, List<BookTagRow>>>((ref) async {
  return _tagMapForKind(ref.watch(appProvider).database, TagHostKind.epub);
});

/// SRT 书 → 标签列表（v77 起 keyed by SrtBooks.uid，弃本机自增 int id）。
final srtBookTagMapProvider =
    FutureProvider<Map<String, List<BookTagRow>>>((ref) async {
  return _tagMapForKind(ref.watch(appProvider).database, TagHostKind.srt);
});

/// 合集 → 标签列表（keyed by collectionId）。与 [bookTagMapProvider] 等同形，
/// 共用同一 [BookTags] 标签池。让书架/视频列表里的合集行也能展示已打的标签 chip
/// （详情页早有展示，列表行此前没有——用户实报「打了标签但列表上看不见」）。
final collectionTagMapProvider =
    FutureProvider<Map<int, List<BookTagRow>>>((ref) async {
  final byKey = await _tagMapForKind(
      ref.watch(appProvider).database, TagHostKind.collection);
  return <int, List<BookTagRow>>{
    for (final MapEntry<String, List<BookTagRow>> e in byKey.entries)
      if (collectionIdOfTagEntryKey(e.key) case final int id) id: e.value,
  };
});

/// v77 起返回 srt uid 集合（弃 int id）。
final filteredSrtBookUidsProvider = FutureProvider<Set<String>?>((ref) async {
  final tagIds = ref.watch(selectedTagIdsProvider);
  if (tagIds.isEmpty) return null;
  final db = ref.watch(appProvider).database;
  return db.getSrtUidsForAllTags(tagIds);
});

/// 含【全部】选中标签的合集 id（无选中标签时 null = 不过滤）。合集卡按此显隐。
final filteredCollectionIdsProvider = FutureProvider<Set<int>?>((ref) async {
  final Set<int> tagIds = ref.watch(selectedTagIdsProvider);
  if (tagIds.isEmpty) return null;
  final db = ref.watch(appProvider).database;
  return db.getCollectionIdsForAllTags(tagIds);
});
