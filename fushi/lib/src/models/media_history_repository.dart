import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:fushi_core/fushi_core.dart';

import 'package:fushi/src/media/media_item.dart';

class MediaHistoryRepository extends ChangeNotifier {
  MediaHistoryRepository(this._db);

  final FushiDatabase _db;

  List<MediaItem> _mediaItemsCache = [];

  Future<void> loadFromDb() async {
    final miRows = await _db.getAllMediaOpenHistory();
    _mediaItemsCache = miRows.map(_rowToMediaItem).toList();
  }

  // ── row conversion（v80：身份/时刻/进度是列，其余走 snapshot JSON。
  // 编解码复用 MediaItem 的 json_serializable 生成码——key 集只在生成码一处
  // 定义，MediaItem 加字段自动跟上（review-reuse-1）。身份/进度/能力位不进
  // snapshot：写侧剥掉，读侧从列注回。）─────────────────────────────────

  static MediaItem _rowToMediaItem(MediaOpenHistoryRow r) {
    Map<String, dynamic> snapshot;
    try {
      snapshot = jsonDecode(r.snapshotJson) as Map<String, dynamic>;
    } catch (_) {
      snapshot = <String, dynamic>{};
    }
    final MediaItem item = MediaItem.fromJson(<String, dynamic>{
      'title': '',
      ...snapshot,
      'mediaIdentifier': r.mediaId,
      'mediaTypeIdentifier': r.mediaType,
      'mediaSourceIdentifier': r.mediaSource,
      'position': r.position,
      'duration': r.duration,
      // v80：能力位不再持久化，运行时按 source 语义推导。全部现存构造点取
      // canDelete:false / canEdit:true（历史条目可改覆盖标题、删除走
      // removeFromReadingList 语义），照实注入（review5-7：此前硬编码成了
      // 反值，会砍掉自定义标题覆盖并凭空长出删除动作）。
      'canDelete': false,
      'canEdit': true,
    });
    return item;
  }

  Future<void> deleteMediaItemById(MediaItem item) async {
    _mediaItemsCache.removeWhere((m) => m.uniqueKey == item.uniqueKey);
    await _db.deleteMediaOpenHistory(
        item.mediaSourceIdentifier, item.mediaIdentifier);
  }

}
