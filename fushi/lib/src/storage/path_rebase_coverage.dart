/// BUG-1174：数据根迁移「哪些持久化字段承载绝对路径、迁移要不要改写」的**单一真相源**。
///
/// 历史上这份知识只活在 [DataRootMigrator] 的一串 UPDATE 语句里，于是每加一列存路径的
/// 字段就漏一次：TODO-1255 漏了 video_books.cover_path（迁移后视频封面全占位），
/// BUG-1174 又一次性发现漏了 galgames.cover_path、video_books.subtitle_source ×2、
/// media_items.image_url、整张 profile_settings 和 5 个 pref key。注释拦不住这种遗漏
/// ——注释不会红。把清单**声明化**并由源码扫描守卫
/// （test/storage/path_rebase_coverage_guard_test.dart）比对：新增路径列而忘了登记就在
/// CI 上红，而不是等用户数据坏了才发现。
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

  /// 落在 **support（数据库）根**下的绝对路径 —— 迁移必须重挂到新 support 根
  /// （按文件名，见 LocalAudioManager.resolveInternalPath）。
  supportRooted,

  /// 用户自选的**外部**绝对路径（外部素材目录 / 游戏安装位置 / 系统工具 / 文件选择器
  /// 上次目录）—— 不在数据根内，迁移**绝不能**动它，动了就让外部资源失联。
  externalUserPath,

  /// 不是文件系统绝对路径：相对 href、裸文件名、成员引用、远端 URL、枚举/编码值、
  /// 与路径无关的结构化 JSON。
  notAPath,
}

/// pref 值承载路径的形态（决定用哪个改写器）。
enum PathValueShape {
  /// 裸绝对路径（空串 = 未设置）。
  bare,

  /// JSON 字符串数组，每个元素是绝对路径。
  jsonStringList,

  /// JSON map，value 是 subtitleSource 四态编码（本地已下载 = 绝对路径）。
  subtitleSourceMapJson,

  /// 字体 catalog：{version, fonts:[{id,name,path}]}。
  fontCatalogJson,

  /// 字体列表：[{name,path,enabled}]。
  fontListJson,

  /// 本地发音库列表（PrefCodec s: tag + JSON 对象数组，按**文件名**重挂）。
  localAudioDbsJson,

  /// typed 音频来源配置（PrefCodec j: tag + JSON 对象数组，仅 localAudio 条目带 path）。
  audioSourceConfigsJson,

  /// v55 legacy 游戏库 JSON 数组，仅 coverPath 字段是数据根内路径。
  legacyGalgameLibraryJson,

  /// 不承载数据根内路径。
  none,
}

/// 一个 Drift preferences / profile_settings KV 键的迁移处置声明。
@immutable
class PathRebasePref {
  const PathRebasePref(this.key, this.kind, this.shape, this.reason);

  /// pref key 的**字面值**。经编码器生成的键（dbSourcePrefKey(kReaderSourcePersistedKey, ...)）
  /// 也写展开后的字面值，守卫按字面值比对。
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
/// 键。守卫比对 preferences_repository.dart 里的路径形 key 字面量。
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
  PathRebasePref(dbSourcePrefKey(kReaderSourcePersistedKey, 'dict_fonts'),
      PathRebaseKind.documentsRooted, PathValueShape.fontListJson, '同上（词典字体）。'),
  PathRebasePref(
      dbSourcePrefKey(kReaderSourcePersistedKey, 'video_sub_fonts'),
      PathRebaseKind.documentsRooted,
      PathValueShape.fontListJson,
      '同上（视频字幕字体）。'),
  PathRebasePref(
      dbSourcePrefKey(kReaderSourcePersistedKey, 'game_lookup_fonts'),
      PathRebaseKind.documentsRooted,
      PathValueShape.fontListJson,
      '同上（游戏查词窗口字体）。'),
  PathRebasePref(
      'local_audio_dbs',
      PathRebaseKind.supportRooted,
      PathValueShape.localAudioDbsJson,
      '内部副本 local_audio_<ts>.db 落 support 根；按**文件名**重挂（天然幂等），外部'
          '引用（BUG-483）原样保留。'),
  PathRebasePref(
      'audio_source_configs',
      PathRebaseKind.supportRooted,
      PathValueShape.audioSourceConfigsJson,
      'typed 音频来源配置，仅 localAudio 条目带 path；必须与 local_audio_dbs 同步重挂，'
          '否则 AppModel 的 path 相等匹配会断（TODO-1171）。'),
  PathRebasePref(
      'local_audio_db_path',
      PathRebaseKind.supportRooted,
      PathValueShape.bare,
      'BUG-1174 漏项：旧单库绝对路径。只要用户从未调过 setEntries，local_audio_dbs 为空'
          '时它仍被当回退读（local_audio_manager.dart:140-146）。与 local_audio_dbs 同款'
          '按文件名重挂。'),
  PathRebasePref(
      'galgame_library',
      PathRebaseKind.documentsRooted,
      PathValueShape.legacyGalgameLibraryJson,
      'BUG-1174 漏项：v55 legacy 游戏库 JSON，其中 coverPath 指 <documents>/game_covers。'
          'v55 迁移刻意只读不删（回滚兜底，database.dart:1523-1526），所以存量数据里它'
          '还在。同条目的 exePath / workdir 是外部路径，作用域谓词天然跳过。'),
  PathRebasePref(
      'video_remote_subtitle',
      PathRebaseKind.documentsRooted,
      PathValueShape.subtitleSourceMapJson,
      'BUG-1174 漏项（原调研清单未列出，实查补入）：远端/流媒体视频手选字幕来源 map，'
          'value 是 subtitleSource 四态编码，本地已下载态是 <documents>/video_subtitles '
          '下的绝对路径（jimaku_batch_dialog.dart:268 等）。与 video_books.subtitle_source '
          '同型，只是落在 KV 而非列上。'),
  PathRebasePref(
      'download_save_root',
      PathRebaseKind.documentsRooted,
      PathValueShape.bare,
      'BUG-1174 漏项：下载保存根。空串 = 用默认 <documents>/anime_downloads/content；'
          '用户第一次改设置时那个 documents 派生的默认值会被显式写进来。anime_downloads '
          '在搬移白名单里（会被物理搬走），不改写就指向不存在的旧位置。用户挑的外部盘不在'
          '旧根下 → 作用域谓词天然跳过。'),
  PathRebasePref(
      'download_save_root_history',
      PathRebaseKind.documentsRooted,
      PathValueShape.jsonStringList,
      'BUG-1174 漏项：下载根历史（JSON 字符串数组），含被压栈的旧默认根；不改写 → 迁移后'
          '这些历史根下的老任务在下载页整批失认。'),
  PathRebasePref(
      'video_download_backend_path_mappings',
      PathRebaseKind.externalUserPath,
      PathValueShape.none,
      'qBittorrent remoteRoot→localRoot 显式映射；localRoot 是用户/后端外部文件系统路径，'
          '与 MediaSources.rootPath 同语义，不能随 Hibiki 应用数据根改写。'),
  PathRebasePref('video_mpv_shader_dir', PathRebaseKind.externalUserPath,
      PathValueShape.none, '用户本机 mpv 着色器目录，外部路径，不随数据根走。'),
  PathRebasePref(
      'audiobook_material_dirs',
      PathRebaseKind.externalUserPath,
      PathValueShape.none,
      '有声书素材库目录（JSON 字符串数组）。用户自己挑的字幕/正文库位置——通常是外接盘'
          '或下载目录，不在 Hibiki 数据根下，跟着数据根改写只会把有效路径改坏。'
          '目录没了不影响已入库的书（素材在导入时已复制进书的存储），设置页按'
          'missingDirs 如实提示。'),
  PathRebasePref('manga_external_mokuro_path', PathRebaseKind.externalUserPath,
      PathValueShape.none, '系统安装的 mokuro 可执行文件路径，外部路径。'),
  PathRebasePref(
      'manga_reading_direction',
      PathRebaseKind.notAPath,
      PathValueShape.none,
      '阅读方向枚举（dir 是 direction 不是 directory）。守卫的 key 正则刻意宽松、宁可'
          '多要求几条声明，也不放过一个真路径 key。'),
  PathRebasePref('active_profile_id', PathRebaseKind.notAPath,
      PathValueShape.none, '当前 Profile 的自增 id（撞正则是因为 profile 里含 file）。不是路径。'),
  PathRebasePref('local_audio_db_display_name', PathRebaseKind.notAPath,
      PathValueShape.none, '旧单库显示名（与 local_audio_db_path 同族），不是路径。'),
];

/// 按 key 查处置；未登记返回 null。
PathRebasePref? pathRebasePrefFor(String key) {
  for (final PathRebasePref pref in kPathRebasePrefs) {
    if (pref.key == key) return pref;
  }
  return null;
}
