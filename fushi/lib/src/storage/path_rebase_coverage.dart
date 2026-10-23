/// BUG-1174：数据根迁移「哪些 pref 承载绝对路径、迁移要不要改写」的**单一真相源**。
///
/// 历史上这份知识只活在 [DataRootMigrator] 的一串 UPDATE 语句里，于是每加一个存路径的
/// 字段就漏一次。把清单**声明化**：新增路径 pref 时在这里登记。
///
/// 与 sync/pref_redaction_policy.dart 同款骨架：一份声明 + 一个谓词 + 多处消费。
library;

import 'package:flutter/foundation.dart';

import 'package:fushi/src/media/media_source.dart' show dbSourcePrefKey;
import 'package:fushi/src/media/sources/reader_fushi_source.dart';

/// 一个持久化字段在数据根迁移里的处置。
enum PathRebaseKind {
  /// 落在 **documents（内容/书库）根**下的绝对路径 —— 迁移必须 rebase 到新 documents 根。
  documentsRooted,

  /// 落在 **support（数据库）根**下的绝对路径 —— 迁移必须重挂到新 support 根。
  supportRooted,

  /// 不是文件系统绝对路径：相对 href、裸文件名、成员引用、远端 URL、枚举/编码值、
  /// 与路径无关的结构化 JSON。
  notAPath,
}

/// pref 值承载路径的形态（决定用哪个改写器）。
enum PathValueShape {
  /// 字体 catalog：{version, fonts:[{id,name,path}]}。
  fontCatalogJson,

  /// 字体列表：[{name,path,enabled}]。
  fontListJson,

  /// 不承载数据根内路径。
  none,
}

/// 一个 Drift preferences / profile_settings KV 键的迁移处置声明。
@immutable
class PathRebasePref {
  const PathRebasePref(this.key, this.kind, this.shape, this.reason);

  /// pref key 的**字面值**。经编码器生成的键（dbSourcePrefKey(kReaderSourcePersistedKey, ...)）
  /// 也写展开后的字面值。
  final String key;

  final PathRebaseKind kind;
  final PathValueShape shape;
  final String reason;

  bool get mustRebase =>
      kind == PathRebaseKind.documentsRooted ||
      kind == PathRebaseKind.supportRooted;

  @override
  String toString() => '$key($kind/$shape)';
}

/// Drift preferences（以及它在 profile_settings 里的每 Profile 快照副本）中承载路径的
/// 键。
/// **不是 const**：字体 key 必须经单一真相编码器 [dbSourcePrefKey] 生成，绝不硬编码
/// media_source 的私有 key 前缀格式（守卫 `test/media/db_source_pref_key_test.dart`）。
final List<PathRebasePref> kPathRebasePrefs = <PathRebasePref>[
  PathRebasePref(
      dbSourcePrefKey(kReaderSourcePersistedKey, 'font_catalog'),
      PathRebaseKind.documentsRooted,
      PathValueShape.fontCatalogJson,
      '自定义字体 catalog，path 落 <documents>/custom_fonts。无 PrefCodec tag。'),
  PathRebasePref(
      dbSourcePrefKey(kReaderSourcePersistedKey, 'custom_fonts'),
      PathRebaseKind.documentsRooted,
      PathValueShape.fontListJson,
      '旧影子字体列表，path 落 <documents>/custom_fonts。'),
  PathRebasePref(
      dbSourcePrefKey(kReaderSourcePersistedKey, 'app_ui_fonts'),
      PathRebaseKind.documentsRooted,
      PathValueShape.fontListJson,
      '同上（App UI 字体）。'),
  PathRebasePref('active_profile_id', PathRebaseKind.notAPath,
      PathValueShape.none, '当前 Profile 的自增 id（撞正则是因为 profile 里含 file）。不是路径。'),
];

/// 按 key 查处置；未登记返回 null。
PathRebasePref? pathRebasePrefFor(String key) {
  for (final PathRebasePref pref in kPathRebasePrefs) {
    if (pref.key == key) return pref;
  }
  return null;
}
