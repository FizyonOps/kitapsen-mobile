// 基础设施：表/列存在性探测与幂等索引（God 类拆分 2026-08）。
part of 'database.dart';

mixin _FushiDbInfra on _$FushiDatabase {
  static final RegExp _identifierRe = RegExp(r'^[a-zA-Z_]\w*$');

  Future<bool> _tableExists(String tableName) async {
    if (!_identifierRe.hasMatch(tableName)) {
      throw ArgumentError.value(
          tableName, 'tableName', 'not a valid identifier');
    }
    final rows = await customSelect(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
      variables: [Variable<String>(tableName)],
    ).get();
    return rows.isNotEmpty;
  }

  /// Creates all secondary indexes idempotently. Called from onCreate (fresh
  /// install) and onUpgrade — NOT on every open. Each index is guarded by a
  /// table-existence check so an older file that lacks a table never fails.
  Future<void> _ensureIndexes() async {
    const List<List<String>> indexes = <List<String>>[
      [
        'profile_settings',
        'CREATE INDEX IF NOT EXISTS idx_profile_settings_profile ON profile_settings (profile_id)'
      ],
      [
        'media_type_profiles',
        'CREATE INDEX IF NOT EXISTS idx_media_type_profiles_profile ON media_type_profiles (profile_id)'
      ],
      [
        'book_profiles',
        'CREATE INDEX IF NOT EXISTS idx_book_profiles_profile ON book_profiles (profile_id)'
      ],
      [
        'language_profiles',
        'CREATE INDEX IF NOT EXISTS idx_language_profiles_profile ON language_profiles (profile_id)'
      ],
      // bookmarks 索引（book_uid 列）不在本清单：onCreate 内联创建。
      // tag_id lookups（v77 合表后一条索引服务全部 kind）：countBooksForTag /
      // _entryKeysForAllTags 按 tag_id 过滤，PK (media_kind, entry_key, tag_id)
      // 服务不了 tag_id 单列查询。
      [
        'tag_assignments',
        'CREATE INDEX IF NOT EXISTS idx_tag_assignments_tag_id '
            'ON tag_assignments (tag_id)'
      ],
      // v49：首页 Activity 面板按 timestamp_ms DESC 取最近 N 条（可按 event_type
      // 过滤），主排序列建索引避免全表扫描 + 排序。
      [
        'activity_events',
        'CREATE INDEX IF NOT EXISTS idx_activity_events_timestamp '
            'ON activity_events (timestamp_ms DESC)'
      ],
    ];
    for (final List<String> entry in indexes) {
      if (await _tableExists(entry[0])) {
        await customStatement(entry[1]);
      }
    }
  }
}
