// 视频域：刮削资料 / 元数据 / 相关作品 / 图组 / 下载流水线（God 类拆分 2026-08：part+mixin，仓库 reader_fushi
// part 先例；mixin 是真类成员——可被测试子类 override、虚分派正常
// （extension 方案在此翻车过）；私有 mixin 不进公共 API 面。
part of 'database.dart';

mixin _FushiDbVideoDomain
    on _$FushiDatabase, _FushiDbLibrary, _FushiDbTagsSync {
  // ── video_scrape_meta（条目刮削资料，v54）─────────────────────────

  /// 全量条目刮削资料（TODO-2486 视频首页年份筛选）。库页一次拉全表内存建
  /// uid → 行映射，替代逐本 [getVideoScrapeMeta] 的 N+1。
  Future<List<VideoScrapeMetaRow>> getAllVideoScrapeMeta() =>
      select(videoScrapeMeta).get();

  // ── collection_scrape_meta（合集级刮削资料，schema v64 / BUG-1310）────────

  /// 取合集刮削资料；未刮过返回 null（详情页据此回落到「只有标题 + 进度」的旧形态）。
  Future<CollectionScrapeMetaRow?> getCollectionScrapeMeta(int collectionId) =>
      (select(collectionScrapeMeta)
            ..where(($CollectionScrapeMetaTable t) =>
                t.collectionId.equals(collectionId)))
          .getSingleOrNull();

  // ── collection_relations（合集相关作品，schema v66 / TODO-2484）──────

  /// 按展示顺序（sortIndex → id）列出某合集的相关作品。
  Future<List<CollectionRelationRow>> getCollectionRelations(
    int collectionId,
  ) =>
      (select(collectionRelations)
            ..where(($CollectionRelationsTable t) =>
                t.collectionId.equals(collectionId))
            ..orderBy([
              ($CollectionRelationsTable t) =>
                  OrderingTerm(expression: t.sortIndex),
              ($CollectionRelationsTable t) => OrderingTerm(expression: t.id),
            ]))
          .get();

  // ── media_images（媒体附加图组，schema v68 / Jellyfin 图组对齐）──────

  /// 某合集的附加图组（kind 组内按 position 升序，backdrop 轮换序即此序）。
  Future<List<MediaImageRow>> getMediaImagesForCollection(int collectionId) =>
      (select(mediaImages)
            ..where(
                ($MediaImagesTable t) => t.collectionId.equals(collectionId))
            ..orderBy([
              ($MediaImagesTable t) => OrderingTerm(expression: t.kind),
              ($MediaImagesTable t) => OrderingTerm(expression: t.position),
            ]))
          .get();

  /// 全表附加图组（库页/首页批量预取，替代逐归属查询的 N+1；调用方按
  /// collectionId / bookUid 内存分组）。
  Future<List<MediaImageRow>> getAllMediaImages() => (select(mediaImages)
        ..orderBy([
          ($MediaImagesTable t) => OrderingTerm(expression: t.kind),
          ($MediaImagesTable t) => OrderingTerm(expression: t.position),
        ]))
      .get();

  // ── video metadata（schema v69 / 来源规范刮削）────────────────────

  // ── video_episode_binding_overrides（v111，Shoko UserVerified）──

  // ── video source scrape settings / runs / sidecar artifacts ───────

  Future<VideoSourceScrapeSettingRow?> getVideoSourceScrapeSettings(
    int sourceId,
  ) =>
      (select(videoSourceScrapeSettings)
            ..where(($VideoSourceScrapeSettingsTable t) =>
                t.sourceId.equals(sourceId)))
          .getSingleOrNull();

  Future<void> upsertVideoSourceScrapeSettings(
    VideoSourceScrapeSettingsCompanion settings,
  ) =>
      into(videoSourceScrapeSettings).insertOnConflictUpdate(settings);

  Future<List<VideoSourceScrapeRunRow>> getVideoSourceScrapeRuns({
    int? sourceId,
    int limit = 50,
  }) {
    final SimpleSelectStatement<$VideoSourceScrapeRunsTable,
        VideoSourceScrapeRunRow> query = select(videoSourceScrapeRuns);
    if (sourceId != null) {
      query.where(
          ($VideoSourceScrapeRunsTable t) => t.sourceId.equals(sourceId));
    }
    query
      ..orderBy(<OrderingTerm Function($VideoSourceScrapeRunsTable)>[
        ($VideoSourceScrapeRunsTable t) => OrderingTerm.desc(t.startedAt),
        ($VideoSourceScrapeRunsTable t) => OrderingTerm.desc(t.id),
      ])
      ..limit(limit);
    return query.get();
  }

  /// 更新视频封面图绝对路径（用户在书架/视频库长按菜单手动设置）。
  Future<void> updateVideoBookCover(String bookUid, String coverPath) =>
      (update(videoBooks)..where((t) => t.bookUid.equals(bookUid)))
          .write(VideoBooksCompanion(coverPath: Value(coverPath)));

  /// 在**一个事务**里批量删视频书（BUG-2754），返回删前快照的行（不存在的 uid
  /// 不在返回值里）。
  ///
  /// 覆盖单条删的全部清理：audio_cues、shelf_entry、标签映射、规格缓存
  /// （v95，按主视频 + 播放列表各集路径）、**本地花絮行**、行本身；
  /// [removeFromCollections] 为真时再同事务清合集成员（等价
  /// [removeEntriesFromAllCollections]，被清空的合集随之删除）。
  ///
  /// 本地花絮必须先删：`video_metadata_extras.book_uid` 的外键是 `SET NULL`，
  /// 而 CHECK 要求 `source_kind='local'` 的行 `book_uid` 非空——让 FK 去置空，
  /// CHECK 当场失败、整个删除事务回滚（BUG-2754：被扫描器挂成 `Extras/` 花絮的
  /// 视频永远删不掉）。本地花絮就是这条视频本身，视频没了它也该没；在线花絮
  /// 不挂 book_uid，不受影响。
  ///
  /// 所有 `IN (...)` 按 [_kVideoDeleteChunkSize] 分块，避开旧 SQLite 的 999 绑定
  /// 变量上限（全选几千条是真实场景）。
  Future<List<VideoBookRow>> deleteVideoBooks(
    Iterable<String> bookUids, {
    bool removeFromCollections = true,
  }) {
    final List<String> uids = bookUids.toSet().toList(growable: false);
    if (uids.isEmpty) return Future<List<VideoBookRow>>.value(<VideoBookRow>[]);
    return transaction(() async {
      final List<List<String>> uidChunks =
          _chunkForSqlVariables<String>(uids, _kVideoDeleteChunkSize);
      // v95：规格缓存以**文件路径**为键、与 book 无 FK，不在这里清就永远不会被
      // 清——`video_file_specs` 会随「每个曾经扫描过的文件」单调增长，删片子也
      // 不缩。路径须在删行前取（主视频 + 播放列表里的每一集）。
      final List<VideoBookRow> rows = <VideoBookRow>[];
      for (final List<String> chunk in uidChunks) {
        rows.addAll(await (select(videoBooks)
              ..where((t) => t.bookUid.isIn(chunk)))
            .get());
      }
      for (final List<String> chunk in uidChunks) {
        // cue 的 owner key 对有声书/SRT/视频共用，无法挂 FK（BUG-276）。
        await (delete(audioCues)..where((t) => t.bookKey.isIn(chunk))).go();
        // TODO-616：同事务清 shelf_entry（mediaType='video'、entryKey=bookUid）。
        await (delete(shelfEntries)
              ..where((t) =>
                  t.mediaType.equals(MediaKind.video.dbValue) &
                  t.entryKey.isIn(chunk)))
            .go();
        await (delete(tagAssignments)
              ..where((t) =>
                  t.mediaKind.equals(TagHostKind.video.dbValue) &
                  t.entryKey.isIn(chunk)))
            .go();
        await (delete(videoMetadataExtras)
              ..where((t) =>
                  t.sourceKind.equals('local') & t.bookUid.isIn(chunk)))
            .go();
      }
      final List<String> filePaths = <String>{
        for (final VideoBookRow row in rows) ...videoBookFilePaths(row),
      }.toList(growable: false);
      for (final List<String> chunk
          in _chunkForSqlVariables<String>(filePaths, _kVideoDeleteChunkSize)) {
        await (delete(videoFileSpecs)..where((t) => t.filePath.isIn(chunk)))
            .go();
      }
      await removeEntriesFromAllCollections(MediaKind.video, uids);
      for (final List<String> chunk in uidChunks) {
        await (delete(videoBooks)..where((t) => t.bookUid.isIn(chunk))).go();
      }
      return rows;
    });
  }

  // ── video_file_specs（v95 规格探测缓存）────────────────────────────

  // ── anidb_file_identities（v106 AniDB 文件级身份）────────────────────

}

/// 一本视频书涉及的全部本地文件路径：主视频 + 播放列表里的每一集。
///
/// 规格缓存以**文件路径**为键、与 `video_books` 之间没有外键（键的粒度本就比 book 细，
/// 见 `video_file_specs` 表注释），所以删书时必须由调用方按这份清单去清，否则那些行
/// 永远没人回收。
///
/// `playlistJson` 是 `[{title, path}]` 数组，其中 `path` 与 `videoPath` 同语义。
/// **坏 JSON 只当作「没有播放列表」**：删书事务绝不能因为一条脏缓存键而整个回滚。
List<String> videoBookFilePaths(VideoBookRow row) {
  final Set<String> out = <String>{};
  if (row.videoPath.isNotEmpty) out.add(row.videoPath);
  final String? playlist = row.playlistJson;
  if (playlist != null && playlist.isNotEmpty) {
    try {
      final Object? decoded = jsonDecode(playlist);
      if (decoded is List) {
        for (final Object? item in decoded) {
          if (item is! Map) continue;
          final Object? path = item['path'];
          if (path is String && path.isNotEmpty) out.add(path);
        }
      }
    } catch (_) {
      // 见上：只清主视频，不抛。
    }
  }
  return List<String>.unmodifiable(out);
}

/// 批量删除类 `IN (...)` 每块的绑定变量数。低于旧 SQLite（Android 老系统库）
/// 999 的上限并给同条语句里其余谓词留余量，与 sidecar ledger 清理同一口径。
const int _kVideoDeleteChunkSize = 400;

/// 把 [items] 切成至多 [size] 个一块（最后一块可以更短；空输入返回空列表）。
List<List<T>> _chunkForSqlVariables<T>(List<T> items, int size) {
  final List<List<T>> chunks = <List<T>>[];
  for (int offset = 0; offset < items.length; offset += size) {
    final int end =
        offset + size < items.length ? offset + size : items.length;
    chunks.add(items.sublist(offset, end));
  }
  return chunks;
}
