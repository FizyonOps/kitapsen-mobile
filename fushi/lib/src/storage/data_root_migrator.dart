import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:fushi_core/fushi_core.dart';

import 'package:drift/drift.dart' show QueryRow, Variable;

import 'package:fushi/src/models/local_audio_manager.dart'
    show LocalAudioManager;
import 'package:fushi/src/profile/profile_keys.dart' show ProfileKeys;
import 'package:fushi/src/storage/path_rebase_coverage.dart';
import 'package:fushi/src/sync/backup_service.dart'
    show
        joinPrefTag,
        normalizeAudioSourceConfigsJson,
        normalizeLocalAudioDbsJson,
        rebaseFontCatalogJson,
        rebaseFontListJson,
        rebasePath,
        splitPrefTag;

abstract class DataRootMigrator {

  /// 仅供单测（BUG-1174 ④）：在 DB 路径改写事务里、改完 video_books 之后抛错，用来
  /// 确定性验证「整段改写在单事务里，中途失败整体回滚、不留半改状态」。生产恒 false。
  @visibleForTesting
  static bool debugFailMidRebase = false;

  /// 同一段改写，作用在**已经打开**的 [db] 上。
  ///
  /// 抽出来是因为它有第二个调用者：启动期的沙箱重定位自愈
  /// （`sandbox_relocation.dart`）。那条路径里 app 正握着这个库，不能像
  /// [_rebaseDatabasePaths] 那样按目录另开一个 [FushiDatabase] 连接。
  ///
  /// **两条路径必须共用这一份调用清单**——覆盖面的真相源是
  /// `path_rebase_coverage.dart`，各自抄一份表就等于给「新增路径列」留了两个
  /// 会漂开的登记处。
  static Future<void> rebaseOpenDatabasePaths({
    required FushiDatabase db,
    required DocumentsPathRebaser docs,
    required String newSupportRoot,
  }) async {
    await db.transaction(() async {
      await _rebaseEpubBooks(db, docs);
      await _rebaseAudiobooks(db, docs);
      await _rebaseSrtBooks(db, docs);
      await _rebaseVideoBooks(db, docs);
      if (debugFailMidRebase) {
      }
      await _rebaseVideoFileSpecs(db, docs);
      await _rebaseAnidbFileIdentities(db, docs);
      await _rebaseGalgames(db, docs);
      await _rebaseMediaCollections(db, docs);
      await _rebaseCollectionScrapeMeta(db, docs);
      await _rebaseCollectionRelations(db, docs);
      await _rebaseMediaImages(db, docs);
      await _rebaseVideoMetadataExtras(db, docs);
      await _rebaseMediaOpenHistory(db, docs);
      await _rebasePreferences(db, docs, newSupportRoot);
      await _rebaseProfileSettings(db, docs, newSupportRoot);
    });
    // checkpoint 必须在事务**外**：SQLite 不允许在活动事务里 wal_checkpoint。
    await db.customStatement('PRAGMA wal_checkpoint(TRUNCATE)');
  }

  /// epub_books：epubPath / extractDir / coverPath。前者与 coverPath 按声明其实不是
  /// 数据根内路径（裸文件名 / 相对 href），改写是防御性 no-op，保留调用与历史行为一致。
  static Future<void> _rebaseEpubBooks(
    FushiDatabase db,
    DocumentsPathRebaser docs,
  ) async {
    for (final EpubBookRow b in await db.getAllEpubBooks()) {
      await db.updateEpubBookContentPaths(
        b.bookKey,
        epubPath: docs.rebase(b.epubPath),
        extractDir: docs.rebase(b.extractDir),
        coverPath: docs.rebaseNullable(b.coverPath),
      );
    }
  }

  /// audiobooks：audioRoot / audioPathsJson（列表）/ alignmentPath。
  static Future<void> _rebaseAudiobooks(
    FushiDatabase db,
    DocumentsPathRebaser docs,
  ) async {
    for (final AudiobookRow a in await db.getAllAudiobooks()) {
      await db.updateAudiobookPaths(
        a.bookKey,
        audioRoot: docs.rebaseNullable(a.audioRoot),
        audioPathsJson: _rebaseJsonStringList(a.audioPathsJson, docs),
        alignmentPath: docs.rebase(a.alignmentPath),
      );
    }
  }

  /// srt_books（独立 SRT/有声书，无 epub 背书）：四列都在 documents 根下。
  static Future<void> _rebaseSrtBooks(
    FushiDatabase db,
    DocumentsPathRebaser docs,
  ) async {
    for (final SrtBookRow s in await db.getAllSrtBooks()) {
      await db.customStatement(
        'UPDATE srt_books SET '
        'audio_root = ?, audio_paths_json = ?, srt_path = ?, cover_path = ? '
        'WHERE id = ?',
        <Object?>[
          docs.rebaseNullable(s.audioRoot),
          _rebaseJsonStringList(s.audioPathsJson, docs),
          docs.rebase(s.srtPath),
          docs.rebaseNullable(s.coverPath),
          s.id,
        ],
      );
    }
  }

  /// video_books：video_path / playlist_json / cover_path / subtitle_source ×2。
  ///
  /// - cover_path 是应用自有资产（`<documents>/video_covers`），TODO-1255 补的漏项。
  /// - **subtitle_source / secondary_subtitle_source 是 BUG-1174 补的漏项**：四态编码
  ///   里只有「外挂绝对路径」态该改写，`embedded:<n>` / `off:` 两个哨兵显式判掉。
  ///   `video_subtitles/` 在搬移白名单里，不改写 = 所有外挂字幕失联。
  static Future<void> _rebaseVideoBooks(
    FushiDatabase db,
    DocumentsPathRebaser docs,
  ) async {
    for (final VideoBookRow v in await db.allVideoBooks()) {
      final String newVideoPath = docs.rebase(v.videoPath);
      final String? newPlaylist = _rebasePlaylistJson(v.playlistJson, docs);
      final String? newCover = docs.rebaseNullable(v.coverPath);
      final String? newSubtitle = rebaseSubtitleSource(v.subtitleSource, docs);
      final String? newSecondary =
          rebaseSubtitleSource(v.secondarySubtitleSource, docs);
      if (newVideoPath == v.videoPath &&
          newPlaylist == v.playlistJson &&
          newCover == v.coverPath &&
          newSubtitle == v.subtitleSource &&
          newSecondary == v.secondarySubtitleSource) {
        continue;
      }
      await db.customStatement(
        'UPDATE video_books SET video_path = ?, playlist_json = ?, '
        'cover_path = ?, subtitle_source = ?, secondary_subtitle_source = ? '
        'WHERE book_uid = ?',
        <Object?>[
          newVideoPath,
          newPlaylist,
          newCover,
          newSubtitle,
          newSecondary,
          v.bookUid,
        ],
      );
    }
  }

  /// video_file_specs：file_path（v95 规格探测缓存的**主键**）。
  ///
  /// 这张表是可重建缓存，理论上不改写也不会丢数据——但键指向旧路径就永远命不中，用户
  /// 换完数据位置后整个库的清晰度/HDR 角标会集体消失，然后几百个文件挨个重新 ffprobe
  /// 才慢慢长回来。改写只是一条 UPDATE，没有理由让用户白等这一轮。
  ///
  /// 用 `UPDATE OR REPLACE`：主键改写理论上可能撞上一条已存在的目标行（旧根与新根
  /// 嵌套时两条路径可能归一到同一新值），撞了就让后写的覆盖，**不让整个迁移事务因为
  /// 一条缓存行的主键冲突而回滚**——缓存的正确性远低于迁移本身。
  static Future<void> _rebaseVideoFileSpecs(
    FushiDatabase db,
    DocumentsPathRebaser docs,
  ) async {
    final List<QueryRow> rows =
        await db.customSelect('SELECT file_path FROM video_file_specs').get();
    for (final QueryRow row in rows) {
      final String oldPath = row.read<String>('file_path');
      final String newPath = docs.rebase(oldPath);
      if (newPath == oldPath) continue;
      await db.customStatement(
        'UPDATE OR REPLACE video_file_specs SET file_path = ? '
        'WHERE file_path = ?',
        <Object?>[newPath, oldPath],
      );
    }
  }

  /// anidb_file_identities：file_path（v106 文件级 AniDB 身份的路径提示，非主键）。
  ///
  /// 主键是 (ed2k, file_size)，路径只服务「同路径同大小同 mtime 免重算哈希」的快路径。
  /// 不改写不丢身份（哈希后按内容键仍命中），但数据根搬家后每个文件都要重算一遍
  /// ED2K——几十 GB 的顺序读——才能命中；改写只是一条 UPDATE。
  static Future<void> _rebaseAnidbFileIdentities(
    FushiDatabase db,
    DocumentsPathRebaser docs,
  ) async {
    final List<QueryRow> rows = await db
        .customSelect(
            'SELECT ed2k, file_size, file_path FROM anidb_file_identities '
            'WHERE file_path IS NOT NULL')
        .get();
    for (final QueryRow row in rows) {
      final String oldPath = row.read<String>('file_path');
      final String newPath = docs.rebase(oldPath);
      if (newPath == oldPath) continue;
      await db.customStatement(
        'UPDATE anidb_file_identities SET file_path = ? '
        'WHERE ed2k = ? AND file_size = ?',
        <Object?>[
          newPath,
          row.read<String>('ed2k'),
          row.read<int>('file_size')
        ],
      );
    }
  }

  /// galgames：cover_path（`<documents>/game_covers/<id>.<ext>`）。BUG-1174 漏项，与
  /// TODO-1255 的 video_books.cover_path 完全同型 —— 不改写 = 整个游戏库封面退化成默认
  /// 手柄图标。exe_path / workdir / launch_args 是用户外部安装位置，**绝不**改写。
  static Future<void> _rebaseGalgames(
    FushiDatabase db,
    DocumentsPathRebaser docs,
  ) async {
    for (final GalgameRow g in await db.getAllGalgames()) {
      final String? newCover = docs.rebaseNullable(g.coverPath);
      if (newCover == g.coverPath) continue;
      await db.customStatement(
        'UPDATE galgames SET cover_path = ? WHERE id = ?',
        <Object?>[newCover, g.id],
      );
    }
  }

  /// media_collections：cover_path（`<documents>/video_covers/collections/<id>.jpg`）。
  /// BUG-1211 合集自有封面，与 video_books.cover_path / galgames.cover_path 同型 ——
  /// 不改写 = 换过封面的合集在换数据根后全部退回「借成员封面」，用户看到封面自己变了。
  /// cover_source 是成员引用不是路径，绝不改写。
  static Future<void> _rebaseMediaCollections(
    FushiDatabase db,
    DocumentsPathRebaser docs,
  ) async {
    for (final MediaCollectionRow c in await db.getAllMediaCollections()) {
      final String? newCover = docs.rebaseNullable(c.coverPath);
      if (newCover == c.coverPath) continue;
      await db.customStatement(
        'UPDATE media_collections SET cover_path = ? WHERE id = ?',
        <Object?>[newCover, c.id],
      );
    }
  }

  /// collection_scrape_meta：backdrop_path
  /// （`<documents>/video_covers/collections/<id>_backdrop.jpg`）。BUG-1310 合集横版
  /// 背景，与上面的 media_collections.cover_path 同目录同型 —— 不改写 = 换数据根后
  /// 详情页 hero 背景变死链，静默退回海报模糊垫底，用户看到背景「自己没了」。
  /// source / tags_json / infobox_json / detail_url 不是本机路径，绝不改写。
  static Future<void> _rebaseCollectionScrapeMeta(
    FushiDatabase db,
    DocumentsPathRebaser docs,
  ) async {
    for (final MediaCollectionRow c in await db.getAllMediaCollections()) {
      final CollectionScrapeMetaRow? meta =
          await db.getCollectionScrapeMeta(c.id);
      if (meta == null) continue;
      final String? newBackdrop = docs.rebaseNullable(meta.backdropPath);
      if (newBackdrop == meta.backdropPath) continue;
      await db.customStatement(
        'UPDATE collection_scrape_meta SET backdrop_path = ? '
        'WHERE collection_id = ?',
        <Object?>[newBackdrop, c.id],
      );
    }
  }

  /// media_images：path（v68 附加图组：`<documents>/video_covers/collections/`
  /// 与 `<documents>/video_covers/images/` 两个目录族，与合集封面同型）。
  /// 不改写 = 换数据根后 hero 背景/logo、续播横卡全部变死链，静默退回海报模糊
  /// 垫底。kind / source_url 不是本机路径，绝不改写。
  static Future<void> _rebaseMediaImages(
    FushiDatabase db,
    DocumentsPathRebaser docs,
  ) async {
    for (final MediaImageRow row in await db.getAllMediaImages()) {
      final String? newPath = docs.rebaseNullable(row.path);
      if (newPath == null || newPath == row.path) continue;
      await db.customStatement(
        'UPDATE media_images SET path = ? WHERE id = ?',
        <Object?>[newPath, row.id],
      );
    }
  }

  /// video_metadata_extras：本地 NCOP/NCED 等附加视频的 thumbnail_path
  /// 直接复用 VideoBook.coverPath，必须与 video_books.cover_path 同步重挂。
  /// 在线项只有 remote_url / thumbnail_url，不参与本机路径改写。
  static Future<void> _rebaseVideoMetadataExtras(
    FushiDatabase db,
    DocumentsPathRebaser docs,
  ) async {
    final List<QueryRow> rows = await db
        .customSelect(
          'SELECT extra_key, thumbnail_path FROM video_metadata_extras '
          'WHERE thumbnail_path IS NOT NULL',
        )
        .get();
    for (final QueryRow row in rows) {
      final String key = row.read<String>('extra_key');
      final String? current = row.read<String?>('thumbnail_path');
      final String? rebased = docs.rebaseNullable(current);
      if (rebased == current) continue;
      await db.customStatement(
        'UPDATE video_metadata_extras SET thumbnail_path = ? '
        'WHERE extra_key = ?',
        <Object?>[rebased, key],
      );
    }
  }

  /// collection_relations：cover_path（关联条目封面的本地落盘位，
  /// `<documents>/video_covers/` 目录族，与合集封面同型；schema v66 /
  /// TODO-2484）。当前尚无写入方（封面下载归 UI 接力线程），本改写是
  /// 前置兜底 —— 列一旦开始落值，不改写 = 换数据根后相关作品卡封面死链。
  /// source / cover_url 不是本机路径，绝不改写。
  static Future<void> _rebaseCollectionRelations(
    FushiDatabase db,
    DocumentsPathRebaser docs,
  ) async {
    for (final MediaCollectionRow c in await db.getAllMediaCollections()) {
      for (final CollectionRelationRow r
          in await db.getCollectionRelations(c.id)) {
        final String? newCover = docs.rebaseNullable(r.coverPath);
        if (newCover == r.coverPath) continue;
        await db.customStatement(
          'UPDATE collection_relations SET cover_path = ? WHERE id = ?',
          <Object?>[newCover, r.id],
        );
      }
    }
  }

  /// media_items：image_url（本地书封面存 `file://<绝对路径>` URI）。BUG-1174 漏项 ——
  /// 不改写 = 书架/首页「最近」卡片封面全空白，直到该书被重新打开刷新。远端源的
  /// http(s) URL scheme 非 file，[DocumentsPathRebaser.rebaseFileUri] 原样返回。
  static Future<void> _rebaseMediaOpenHistory(
    FushiDatabase db,
    DocumentsPathRebaser docs,
  ) async {
    for (final MediaOpenHistoryRow m in await db.getAllMediaOpenHistory()) {
      // v80：imageUrl 在 snapshot JSON 里，逐行解码改写（行数被 trim 钉死）。
      Map<String, dynamic> snapshot;
      try {
        snapshot = jsonDecode(m.snapshotJson) as Map<String, dynamic>;
      } catch (_) {
        continue;
      }
      final Object? url = snapshot['imageUrl'];
      if (url is! String) continue;
      final String rebased = docs.rebaseFileUri(url);
      if (rebased == url) continue;
      snapshot['imageUrl'] = rebased;
      await db.customStatement(
        'UPDATE media_open_history SET snapshot_json = ? '
        'WHERE media_source = ? AND media_id = ?',
        <Object?>[jsonEncode(snapshot), m.mediaSource, m.mediaId],
      );
    }
  }

  /// preferences：按 [kPathRebasePrefs] 声明逐 key 改写（字体目录 / 本地发音库 /
  /// 游戏库 legacy JSON / 远端字幕 map / 下载根与历史）。
  static Future<void> _rebasePreferences(
    FushiDatabase db,
    DocumentsPathRebaser docs,
    String newSupportRoot,
  ) async {
    final Map<String, String> prefs = await db.getAllPrefs();
    for (final PathRebasePref spec in kPathRebasePrefs) {
      if (!spec.mustRebase) continue;
      final String? raw = prefs[spec.key];
      if (raw == null) continue;
      final String rebased = rebaseMigratedPrefValue(
        spec.key,
        raw,
        documents: docs,
        newSupportRoot: newSupportRoot,
      );
      if (rebased != raw) await db.setPref(spec.key, rebased);
    }
  }

  /// profile_settings：每个 Profile 的 pref 快照副本。**必须覆盖所有 Profile**，用与
  /// [_rebasePreferences] 完全相同的改写函数。
  ///
  /// 为什么选「迁移时一起改」而不是「让路径 pref 不进快照」：后者会改掉 Profile 的既有
  /// 语义（字体目录、发音库配置现在确实是**每 Profile** 的），等于为了修迁移去动一个与
  /// 迁移无关的功能契约——爆炸半径大得多，且会破坏已按 Profile 分别配字体的用户。
  /// 迁移时一起改是纯增量、零语义变更。
  static Future<void> _rebaseProfileSettings(
    FushiDatabase db,
    DocumentsPathRebaser docs,
    String newSupportRoot,
  ) async {
    final List<QueryRow> rows = await db.customSelect(
      'SELECT id, key, value FROM profile_settings WHERE category = ?',
      variables: <Variable<Object>>[
        Variable<String>(ProfileKeys.categoryPref),
      ],
    ).get();
    for (final QueryRow row in rows) {
      final String key = row.read<String>('key');
      final String value = row.read<String>('value');
      final String rebased = rebaseMigratedPrefValue(
        key,
        value,
        documents: docs,
        newSupportRoot: newSupportRoot,
      );
      if (rebased == value) continue;
      await db.customStatement(
        'UPDATE profile_settings SET value = ? WHERE id = ?',
        <Object?>[rebased, row.read<int>('id')],
      );
    }
  }

  /// rebase 一个「JSON 字符串数组」里每个绝对路径（如 audioPathsJson）。非 JSON 列表
  /// 原样返回（一个坏行不该中断整次迁移）。
  static String? _rebaseJsonStringList(
    String? json,
    DocumentsPathRebaser docs,
  ) {
    if (json == null) return null;
    return rebaseJsonStringListWith(json, docs);
  }

  /// rebase 视频 playlist JSON 里每个 `path`。结构同 backup_service 的同名逻辑。
  static String? _rebasePlaylistJson(
    String? playlistJson,
    DocumentsPathRebaser docs,
  ) {
    if (playlistJson == null || playlistJson.isEmpty) return playlistJson;
    try {
      final dynamic decoded = jsonDecode(playlistJson);
      if (decoded is! List) return playlistJson;
      bool changed = false;
      final List<dynamic> out = decoded.map<dynamic>((dynamic entry) {
        if (entry is! Map) return entry;
        final Map<String, dynamic> row = Map<String, dynamic>.from(entry);
        final Object? path = row['path'];
        if (path is! String) return row;
        final String rebased = docs.rebase(path);
        if (rebased != path) {
          row['path'] = rebased;
          changed = true;
        }
        return row;
      }).toList();
      return changed ? jsonEncode(out) : playlistJson;
    } catch (_) {
      return playlistJson;
    }
  }
}

/// BUG-1174 ③：数据根迁移期的 documents 根路径改写器。**本质幂等**。
///
/// 旧写法的判据是 `startsWith(oldRoot)`。当新根落在旧根**内部**时（正是
/// `<Documents>` → `<Documents>/Hibiki/data` 这种形态），一条已经改写过的路径**仍然**
/// 以旧根开头，再跑一次就变成 `Documents/Hibiki/data/Hibiki/data/...` —— 全库路径当场
/// 作废、且不抛任何异常，**静默毁库**。同型的坑在 iOS 容器重定位上已经踩过一次
/// （BUG-1115）。
///
/// 这里不靠「保证只跑一次」的流程来回避（那是把正确性押在流程上），而是**把判据改对**：
/// 作用域谓词收窄为「相对旧根的**首段**命中 [scopeTopLevelNames]」，也就是**本次搬移
/// 真正会动的那些顶层项**。`Hibiki` 不在白名单里（`isSafeNestedTargetInSharedDocuments`
/// 靠的就是这一点），所以已改写过的路径首段是 `Hibiki` → 天然跳过。「跑没跑过」这个
/// 问题因此**消失**，而不是被判断掩盖。
///
/// [scopeTopLevelNames] 必须与 `DataRootMigrationRequest.documentsTopLevelIncludeNames`
/// **同源**：改写作用域与搬移作用域一旦漂开，就会出现「文件搬走了但路径没改」或反过来
/// 「路径改了但文件还在旧位置」。`null`（Hibiki 专属根的整树搬移语义）= 无首段限制；
/// 那条路径上 `_validateTarget` 已禁止新根落在旧根内部，故同样幂等。
@immutable
class DocumentsPathRebaser {
  const DocumentsPathRebaser({
    required this.oldRoot,
    required this.newRoot,
    required this.scopeTopLevelNames,
  });

  final String oldRoot;
  final String newRoot;

  /// 本次搬移真正会动的顶层项基名集合；null = 整树搬移（无首段限制）。
  final Set<String>? scopeTopLevelNames;

  static String _stripTrailingSeparator(String value) =>
      (value.endsWith('/') || value.endsWith('\\'))
          ? value.substring(0, value.length - 1)
          : value;

  /// [path] 是否落在本次改写的作用域内。分隔符归一与边界判据与
  /// `backup_service.dart` 的 `rebasePath` 逐字节一致（`/a/books_extra` 不算在
  /// `/a/books` 下）。首段比较**大小写不敏感**——`p.canonicalize` 在 Windows 上转小写，
  /// 原样比对会让 `hibikiExport` 漏网（它会被搬走、路径却不改 = 数据分家）。在 Linux 上
  /// 大小写不敏感只会更宽松几个名字，而那些名字下本来就没有别人写的 DB 路径。
  bool isInScope(String path) {
    final String root = _stripTrailingSeparator(oldRoot.replaceAll('\\', '/'));
    final String normalized = path.replaceAll('\\', '/');
    if (normalized == root) return true;
    if (!normalized.startsWith('$root/')) return false;
    final Set<String>? scope = scopeTopLevelNames;
    if (scope == null) return true;
    final String first =
        normalized.substring(root.length + 1).split('/').first.toLowerCase();
    return scope.any((String owned) => owned.toLowerCase() == first);
  }

  /// 作用域内 → rebase 到新根；作用域外（用户外部路径 / 已改写过的路径）→ 原样返回。
  String rebase(String path) =>
      isInScope(path) ? rebasePath(path, oldRoot, newRoot) : path;

  String? rebaseNullable(String? path) => path == null ? null : rebase(path);

  /// 改写 `file://<绝对路径>` URI（`media_items.image_url`）。必须先解码成文件路径再
  /// 改写、再重新编码：对 URI 字符串直接做前缀替换，分隔符与百分号编码都不对。
  /// 非 `file:` scheme（远端源的 http(s) 封面）原样返回。
  String rebaseFileUri(String value) {
    final Uri? uri = Uri.tryParse(value);
    if (uri == null || uri.scheme != 'file') return value;
    final String filePath;
    try {
      filePath = uri.toFilePath();
    } catch (_) {
      return value; // 畸形 file URI：不猜、不动。
    }
    final String rebased = rebase(filePath);
    if (rebased == filePath) return value;
    return Uri.file(rebased).toString();
  }
}

/// 改写一个 `subtitleSource` 四态编码值（`video_books.subtitle_source` /
/// `secondary_subtitle_source` 列，以及 `video_remote_subtitle` pref map 的 value）。
///
/// 只有「外挂绝对路径」态参与改写；`embedded:<n>` 与 `off:` 两个哨兵**显式**判掉。
/// 它们本来也不以旧根开头（作用域谓词天然跳过），但那是巧合——显式判掉才是契约。
String? rebaseSubtitleSource(String? stored, DocumentsPathRebaser docs) {
  if (stored == null || stored.isEmpty) return stored;
  return docs.rebase(stored);
}

/// 改写一个「JSON 字符串数组」里每个绝对路径。非 JSON 列表原样返回（一个坏值不该中断
/// 整次迁移）。
String rebaseJsonStringListWith(String json, DocumentsPathRebaser docs) {
  try {
    final dynamic decoded = jsonDecode(json);
    if (decoded is! List) return json;
    return jsonEncode(decoded.whereType<String>().map(docs.rebase).toList());
  } catch (_) {
    return json;
  }
}

/// 改写一个 `{key: subtitleSource 四态编码}` JSON map（`video_remote_subtitle`）。
String rebaseSubtitleSourceMapJson(String json, DocumentsPathRebaser docs) {
  try {
    final dynamic decoded = jsonDecode(json);
    if (decoded is! Map) return json;
    return jsonEncode(decoded.map<String, String>((dynamic k, dynamic v) =>
        MapEntry<String, String>(
            k.toString(), rebaseSubtitleSource(v.toString(), docs)!)));
  } catch (_) {
    return json;
  }
}

/// 改写 v55 legacy `galgame_library` JSON 里每条的 `coverPath`。
/// 同条目的 `exePath` / `workdir` 是用户外部安装位置，**绝不**改写。
String rebaseLegacyGalgameLibraryJson(String json, DocumentsPathRebaser docs) {
  try {
    final dynamic decoded = jsonDecode(json);
    if (decoded is! List) return json;
    bool changed = false;
    final List<dynamic> out = decoded.map<dynamic>((dynamic entry) {
      if (entry is! Map) return entry;
      final Map<String, dynamic> row = Map<String, dynamic>.from(entry);
      final Object? cover = row['coverPath'];
      if (cover is! String) return row;
      final String rebased = docs.rebase(cover);
      if (rebased != cover) {
        row['coverPath'] = rebased;
        changed = true;
      }
      return row;
    }).toList();
    return changed ? jsonEncode(out) : json;
  } catch (_) {
    return json;
  }
}

/// BUG-1174 ②：给定 (pref key, 原始值) 返回改写后的值。**纯函数**。
///
/// `preferences` 与 `profile_settings` 两条路都必须调它。历史教训：把改写逻辑抄两份
/// （备份恢复侧与迁移侧）迟早漂开，`srt_books` 四列与 `video_books.cover_path` 就是这么
/// 漂开的。这里只留一份。
///
/// 未登记（[pathRebasePrefFor] 返回 null）或登记为不改写的 key 一律原样返回——
/// `profile_settings` 里躺着**全部**非排除 pref，绝不能对不认识的 key 乱动。
String rebaseMigratedPrefValue(
  String key,
  String value, {
  required DocumentsPathRebaser documents,
  required String newSupportRoot,
}) {
  final PathRebasePref? spec = pathRebasePrefFor(key);
  if (spec == null || !spec.mustRebase) return value;
  switch (spec.shape) {
    // 字体 JSON 复用 backup_service 的遍历器，但**必须注入作用域改写器**：那两个函数
    // 默认走裸 rebasePath（startsWith 判据），新根落在旧根内部时会把已改写过的 path 再
    // 改一遍 → `.../Hibiki/data/Hibiki/data/custom_fonts/a.ttf`。这是本次被幂等测试
    // **真实抓到**的旁路（BUG-1174 ③）。备份恢复侧不传 rewritePath，行为逐字节不变。
    case PathValueShape.fontCatalogJson:
      return rebaseFontCatalogJson(
        value,
        documents.oldRoot,
        documents.newRoot,
        rewritePath: documents.rebase,
      );
    case PathValueShape.fontListJson:
      return rebaseFontListJson(
        value,
        documents.oldRoot,
        documents.newRoot,
        rewritePath: documents.rebase,
      );
    case PathValueShape.localAudioDbsJson:
      return normalizeLocalAudioDbsJson(value, newSupportRoot);
    case PathValueShape.audioSourceConfigsJson:
      return normalizeAudioSourceConfigsJson(value, newSupportRoot);
    case PathValueShape.legacyGalgameLibraryJson:
      return _withPrefTag(value,
          (String body) => rebaseLegacyGalgameLibraryJson(body, documents));
    case PathValueShape.subtitleSourceMapJson:
      return _withPrefTag(
          value, (String body) => rebaseSubtitleSourceMapJson(body, documents));
    case PathValueShape.jsonStringList:
      return _withPrefTag(
          value, (String body) => rebaseJsonStringListWith(body, documents));
    case PathValueShape.bare:
      // support 根下的旧单库路径按**文件名**重挂（与 local_audio_dbs 同款、天然幂等）；
      // documents 根下的裸路径走作用域改写器。
      return _withPrefTag(
        value,
        (String body) => spec.kind == PathRebaseKind.supportRooted
            ? LocalAudioManager.resolveInternalPath(body, newSupportRoot)
            : documents.rebase(body),
      );
    case PathValueShape.none:
      return value;
  }
}

/// 剥掉 PrefCodec tag（`s:` / `j:`）改写 body 再贴回去。低层 `db.setPref` 写的裸值
/// tag 为空，[joinPrefTag] 原样返回，两种写法都安全。空值直接返回（空串 = 未设置）。
String _withPrefTag(String raw, String Function(String body) rewrite) {
  if (raw.isEmpty) return raw;
  final ({String tag, String body}) split = splitPrefTag(raw);
  if (split.body.isEmpty) return raw;
  return joinPrefTag(split.tag, rewrite(split.body));
}
