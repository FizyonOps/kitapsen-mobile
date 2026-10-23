// 词典 / 剪贴板 / EPUB 书目 / 书与统计墓碑（God 类拆分 2026-08：part+mixin，仓库 reader_fushi
// part 先例；mixin 是真类成员——可被测试子类 override、虚分派正常
// （extension 方案在此翻车过）；私有 mixin 不进公共 API 面。
part of 'database.dart';

mixin _FushiDbContentMisc
    on _$FushiDatabase, _FushiDbLibrary, _FushiDbTagsSync {
  // ── epub books ──────────────────────────────────────────────────
  Future<List<EpubBookRow>> getAllEpubBooks() =>
      (select(epubBooks)..orderBy([(t) => OrderingTerm.desc(t.importedAt)]))
          .get();

  /// 全部书的瘦投影（[EpubBookMeta]，与 [getAllEpubBooks] 同序：importedAt 降序）。
  ///
  /// 只要 title / uid / importedAt / format 等小列的调用方（书架映射、统计事实面、
  /// 导入重复检查、远端去重）走这里，不再把每本几十 KB 的 `chaptersJson` / `tocJson`
  /// 整库拉一遍再丢掉。
  Future<List<EpubBookMeta>> getEpubBookMetas() async {
    final JoinedSelectStatement<HasResultSet, dynamic> query =
        selectOnly(epubBooks)
          ..addColumns(<Expression<Object>>[
            epubBooks.bookKey,
            epubBooks.uid,
            epubBooks.title,
            epubBooks.format,
            epubBooks.importedAt,
            epubBooks.extractDir,
            epubBooks.completedAt,
          ])
          ..orderBy(<OrderingTerm>[OrderingTerm.desc(epubBooks.importedAt)]);
    final List<TypedResult> rows = await query.get();
    return rows
        .map(
          (TypedResult row) => EpubBookMeta(
            bookKey: row.read(epubBooks.bookKey)!,
            uid: row.read(epubBooks.uid)!,
            title: row.read(epubBooks.title)!,
            format: row.read(epubBooks.format)!,
            importedAt: row.read(epubBooks.importedAt)!,
            extractDir: row.read(epubBooks.extractDir)!,
            completedAt: row.read(epubBooks.completedAt),
          ),
        )
        .toList(growable: false);
  }

  /// 监听 EPUB 书 bookKey 集合，供书架在任意导入路径落库后自动刷新（同
  /// [watchVideoBookUids]，BUG-793）。消费方按集合 `.distinct` 去重，改作者/封面等
  /// 纯列更新（集合不变）不触发重算。
  ///
  /// 只投影 bookKey 列：这条流在 `epub_books` 每次写入时都重跑，之前是全列
  /// `select` 把整库 `chaptersJson` 拉出来只为取 key（批量导入 N 本 = N 次全库大列读）。
  Stream<List<String>> watchEpubBookKeys() => (selectOnly(epubBooks)
        ..addColumns(<Expression<Object>>[epubBooks.bookKey]))
      .watch()
      .map(
        (List<TypedResult> rows) => rows
            .map((TypedResult row) => row.read(epubBooks.bookKey)!)
            .toList(growable: false),
      );

  Future<EpubBookRow?> getEpubBook(String bookKey) =>
      (select(epubBooks)..where((t) => t.bookKey.equals(bookKey)))
          .getSingleOrNull();

  /// 按 extractDir 反查书（CSS 编辑器只有 extractDir，需拿 bookKey 记 book_custom_css）。
  Future<EpubBookRow?> getEpubBookByExtractDir(String extractDir) =>
      (select(epubBooks)
            ..where((t) => t.extractDir.equals(extractDir))
            ..limit(1))
          .getSingleOrNull();

  /// 把 [bookKey] 的书标记为「已读完」（[at] 非 null）或清除完成（[at] == null）。
  /// 书架卡菜单手动切换「标记为已读完/取消」时调用。返回受影响行数。有声书共用同一列
  /// （其配对 EpubBooks 行的 bookKey），故无需 SRT 专用方法。
  Future<int> setEpubBookCompleted(String bookKey, DateTime? at) =>
      (update(epubBooks)..where((t) => t.bookKey.equals(bookKey)))
          .write(EpubBooksCompanion(completedAt: Value(at)));

  /// 读到全书末尾时自动写完成时间戳——仅在当前未完成（completed_at IS NULL）时写入，
  /// 幂等：已手动/已自动完成过的书重复读到末尾不刷新时间戳，绝不覆盖用户已手动清除的
  /// 状态（用户取消完成后再读到末尾会重新自动置上，属预期）。返回受影响行数。
  Future<int> markEpubBookCompletedIfUnset(String bookKey, DateTime at) =>
      (update(epubBooks)
            ..where((t) => t.bookKey.equals(bookKey) & t.completedAt.isNull()))
          .write(EpubBooksCompanion(completedAt: Value(at)));

  /// 当前所有「已完成」书的 bookKey 集合（completed_at 非 null），供书架概览
  /// 「Completed」统计与卡片完成角标一次性取用（EPUB 小说卡按自身 bookKey、有声书
  /// SRT 卡按其配对 bookKey 命中同一集合）。
  Future<Set<String>> getCompletedEpubBookKeys() async {
    final query = selectOnly(epubBooks)
      ..addColumns([epubBooks.bookKey])
      ..where(epubBooks.completedAt.isNotNull());
    final List<TypedResult> rows = await query.get();
    return rows.map((TypedResult row) => row.read(epubBooks.bookKey)!).toSet();
  }

  /// Inserts a book; returns its bookKey (the primary key) on success.
  ///
  /// v81：companion 未携带（或空）本机稳定 uid 时在此**单点自动生成**——
  /// 全部导入方（epub/manga/pdf/远端下载/格式重建）零改动即获得身份列。
  Future<String> insertEpubBook(EpubBooksCompanion book) async {
    final EpubBooksCompanion withUid =
        (book.uid.present && book.uid.value.isNotEmpty)
            ? book
            : book.copyWith(uid: Value(generateEpubBookUid()));
    await into(epubBooks).insert(withUid);
    return book.bookKey.value;
  }

  /// 按本机稳定 uid 取书（v81；身份与展示解耦的读取口）。
  Future<EpubBookRow?> getEpubBookByUid(String uid) =>
      (select(epubBooks)..where((t) => t.uid.equals(uid))).getSingleOrNull();

  /// bookKey → 本机稳定 uid 换算口（v82；wire/备份/旧偏好等 bookKey 面貌
  /// 冻结的通道在落 uid 键子表前经此换算）。书不在库返回 null——调用方沿用
  /// no-op 语义（host service 写入闸门同款），不得用 bookKey 兜底写入。
  Future<String?> resolveEpubBookUid(String bookKey) async {
    final String? uid = await (selectOnly(epubBooks)
          ..addColumns([epubBooks.uid])
          ..where(epubBooks.bookKey.equals(bookKey)))
        .map((r) => r.read(epubBooks.uid))
        .getSingleOrNull();
    return (uid == null || uid.isEmpty) ? null : uid;
  }

  /// 写入 / 抬高一条按身份墓碑：同键只在 [deletedAt] 严格更大时覆盖（碑戳只增
  /// 不减，BUG-2220）。本机删除与同步 / 备份落地都经这里。
  ///
  /// v105：碑按 [profileId]（null = 当前激活 Profile）分区。
  Future<void> upsertStudySegmentTombstone({
    required String mediaKind,
    required String mediaKey,
    required int deletedAt,
    int? profileId,
  }) async {
    final int scope = profileId ?? await resolveActiveProfileId();
    await into(studySegmentTombstones).insert(
      StudySegmentTombstonesCompanion.insert(
        profileId: Value(scope),
        mediaKind: mediaKind,
        mediaKey: mediaKey,
        deletedAt: deletedAt,
      ),
      onConflict: DoUpdate(
        (old) => StudySegmentTombstonesCompanion(deletedAt: Value(deletedAt)),
        target: [
          studySegmentTombstones.profileId,
          studySegmentTombstones.mediaKind,
          studySegmentTombstones.mediaKey,
        ],
        where: (old) => old.deletedAt.isSmallerThanValue(deletedAt),
      ),
    );
  }

  /// v92：删某媒体的 `study_segments` 事实 + 立按身份的墓碑（同一事务）。墓碑
  /// 语义（BUG-2214 / BUG-2220）：压制 `startAt < deletedAt` 的段——删除之后开始的
  /// 新段（时钟下一次开段）自然存活，墓碑不需要清、也永不退场；碑戳只增不减
  /// （重复删只抬高、绝不倒退）。
  ///
  /// v105：只删 [profileId]（null = 当前激活 Profile）的段、只立该 Profile 的碑。
  Future<int> deleteStudySegmentsForMedia({
    required String mediaKind,
    required String mediaKey,
    int? profileId,
  }) =>
      transaction(() async {
        final int scope = profileId ?? await resolveActiveProfileId();
        final int removed = await (delete(studySegments)
              ..where((t) =>
                  t.profileId.equals(scope) &
                  t.mediaKind.equals(mediaKind) &
                  t.mediaKey.equals(mediaKey)))
            .go();
        await upsertStudySegmentTombstone(
          mediaKind: mediaKind,
          mediaKey: mediaKey,
          deletedAt: DateTime.now().millisecondsSinceEpoch,
          profileId: scope,
        );
        return removed;
      });

  /// v92：清空某媒体种类的全部段（统计页「清空全部」）。BUG-2215：清空前对该种类
  /// **每个身份**逐一立碑（`deletedAt = now`）再删行——否则互联 / 云同步下次聚合把
  /// 对端持有的全部历史整批回灌。新墓碑语义只压制 `startAt < deletedAt` 的段，立碑
  /// 不再「毒化身份空间」：之后再读同一本书开的新段照常存活。返回删掉的段数。
  ///
  /// v105：只清 [profileId]（null = 当前激活 Profile）的段与碑。
  Future<int> clearStudySegments(String mediaKind, {int? profileId}) =>
      transaction(() async {
        final int scope = profileId ?? await resolveActiveProfileId();
        final int now = DateTime.now().millisecondsSinceEpoch;
        final List<QueryRow> keys = await customSelect(
          'SELECT DISTINCT media_key FROM study_segments '
          'WHERE profile_id = ? AND media_kind = ?',
          variables: [Variable.withInt(scope), Variable.withString(mediaKind)],
          readsFrom: {studySegments},
        ).get();
        for (final QueryRow row in keys) {
          await upsertStudySegmentTombstone(
            mediaKind: mediaKind,
            mediaKey: row.read<String>('media_key'),
            deletedAt: now,
            profileId: scope,
          );
        }
        return (delete(studySegments)
              ..where((t) =>
                  t.profileId.equals(scope) & t.mediaKind.equals(mediaKind)))
            .go();
      });

  /// 用户在时段明细里删某媒体某几天的统计：段**写零**而不是删行——零值就是一次新的
  /// 绝对值写（`updatedAt = now`），经既有 LWW 同步（`upsertStudySegmentsIfNewer` /
  /// 聚合 merge 同 uid 取 updatedAt 大者）自然传到对端，不需要 per-uid 墓碑或新 wire
  /// 字段；读取端对零行本就无贡献（活动流过滤、日面求和为 0、最近观看排除）。
  /// 返回改写的行数。
  ///
  /// v105：只写零当前激活 Profile 的段（时段明细里看到的就是这一份）。
  Future<int> zeroStudySegmentsOnDays({
    required String mediaKind,
    required String mediaKey,
    required Set<String> dateKeys,
  }) async {
    if (dateKeys.isEmpty || mediaKey.isEmpty) return 0;
    final int profileId = await resolveActiveProfileId();
    return (update(studySegments)
          ..where((t) =>
              t.profileId.equals(profileId) &
              t.mediaKind.equals(mediaKind) &
              t.mediaKey.equals(mediaKey) &
              t.dateKey.isIn(dateKeys)))
        .write(StudySegmentsCompanion(
      durationMs: const Value(0),
      chars: const Value(0),
      pages: const Value(0),
      updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
    ));
  }

  /// 按 uid 写零（会话流「删这一次会话」的段侧原语，与 [zeroStudySegmentsOnDays]
  /// 同语义：零值 = 一次新的绝对值写，经 uid LWW 同步传到对端；**不**立按身份的
  /// 墓碑——墓碑压制 `startAt < deletedAt` 的全部段，会连这本书的整段历史一起压死）。
  /// 返回改写的行数。
  Future<int> zeroStudySegmentsByUids(Set<String> uids) {
    if (uids.isEmpty) return Future<int>.value(0);
    return (update(studySegments)..where((t) => t.uid.isIn(uids)))
        .write(StudySegmentsCompanion(
      durationMs: const Value(0),
      chars: const Value(0),
      pages: const Value(0),
      updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
    ));
  }

  /// 删一次学习会话（统计页会话流每行的垃圾桶）：组成它的段写零（同步安全）。
  /// 不动收藏 / 制卡历史 / 查词计数、不立墓碑（与按天删同一「只清纯统计」边界）。
  Future<void> deleteStudySession({
    required Set<String> segmentUids,
  }) =>
      zeroStudySegmentsByUids(segmentUids);

  /// 批量删学习会话（统计页会话区块的「清除全部会话」）：语义与 [deleteStudySession]
  /// 逐条调用逐字节一致（段写零、不立墓碑），只是收进**一个**事务
  /// ——会话流常年几十上百条，逐条一个事务在移动端能卡住整个 UI 帧。
  Future<void> deleteStudySessions({
    required Set<String> segmentUids,
  }) =>
      transaction(() => zeroStudySegmentsByUids(segmentUids));

  /// 编辑一次学习会话（统计页会话流每行的铅笔）：按 uid 逐段写**绝对值**
  /// （起止时刻 / dateKey / hour / 字数）。同一事务。
  ///
  /// 与 [deleteStudySession] 同一条纪律：调用方**不要**直接进这里，走
  /// `fushi/lib/src/stats/study_sessions.dart` 的 `applyStudySessionEdit`——它先让
  /// 段 uid 在在跑的 `StudyClock` 上退役，否则时钟下一个 tick 会把刚改完的段按旧
  /// 绝对值原样写回去（「改了又弹回来」）。
  ///
  /// 段墓碑（`startAt < deletedAt` 压制）在这里**不**拦：编辑是用户的显式绝对值写。
  /// 只有「先清空该媒体统计立了碑、又把老会话往更早的日期改」这一条极窄路径能撞上
  /// ——那种行本地存活、下次同步落地时被碑压掉，与手动改早任何一段的结果一致。
  Future<void> updateStudySession({
    required List<StudySegmentsCompanion> segments,
  }) =>
      transaction(() async {
        for (final StudySegmentsCompanion row in segments) {
          await (update(studySegments)..where((t) => t.uid.equals(row.uid.value)))
              .write(row);
        }
      });

  /// 时段明细 sheet 的「删这一条」（BUG-2108 用户诉求：看着不对的数据要能删）：
  /// 删某媒体在 [dateKeys] 这几天的**全部统计事实**——正是 sheet 那一行求和用到的
  /// 行集，不多不少。
  ///  * v92 段：按 uid 写零（[zeroStudySegmentsOnDays]，同步安全）；
  ///  * legacy 日行：阅读按 title 删行；legacy wire 是 title 粒度 MAX-union，对端
  ///    若还持有这几行会复活——旧数据的旧口径已知边界，单机无影响。
  /// 不动收藏 / 制卡历史 / 查词计数（与按媒体删同一「只清纯统计」边界）；不立墓碑
  /// （按天删不是「忘掉这部」）。
  Future<void> deleteStatFactsOnDays({
    required String mediaKind,
    required String mediaKey,
    required String title,
    required Set<String> dateKeys,
  }) =>
      transaction(() async {
        if (dateKeys.isEmpty) return;
        await zeroStudySegmentsOnDays(
          mediaKind: mediaKind,
          mediaKey: mediaKey,
          dateKeys: dateKeys,
        );
        // v105：legacy 行只有归属 Profile 看得见，别的 Profile 的 sheet 里根本没有
        // 这几行可删（不再另设门）。
        if (mediaKind != kActivityMediaBook) return;
        final int profileId = await resolveActiveProfileId();
        if (!await legacyStatsVisibleTo(profileId)) return;
        await (delete(readingStatistics)
              ..where((t) => t.title.equals(title) & t.dateKey.isIn(dateKeys)))
            .go();
      });

  /// 删除某本书（按 [title] 聚合）的**纯统计**：阅读时长/字数（reading_statistics）。
  /// 同一事务内立一条 book 墓碑，防止云同步 / 备份合并把 peer / 旧备份里的旧数字复活。
  ///
  /// **不触碰用户内容**：不删 favorite_sentences（收藏）。小时日志（reading_hourly_logs）
  /// 只按 (dateKey, hour) 聚合、不带 title，无法按书精确清理，故不动（全局时段分布仍
  /// 含该书历史贡献，属已知精度边界）。
  ///
  /// v92：[bookKey] 非空时同一事务连带删该书的 `study_segments` 事实并立按身份的
  /// 墓碑（legacy 行仍按 title 删、按 (title, sourceType) 立碑——两套墓碑各管各的
  /// wire 家族）。
  Future<void> deleteReadingStatisticsForTitle(
    String title, {
    String? bookKey,
  }) =>
      transaction(() async {
        if (bookKey != null && bookKey.isNotEmpty) {
          await deleteStudySegmentsForMedia(
              mediaKind: kActivityMediaBook, mediaKey: bookKey);
        }
        await (delete(readingStatistics)..where((t) => t.title.equals(title)))
            .go();
      });

  /// TODO-1322: 一键清空**全部阅读统计**（book 域纯统计数字）：阅读时长 / 字数
  /// (reading_statistics) 与按小时时段日志 (reading_hourly_logs)。一次事务原子清空。
  ///
  /// **绝不触碰用户内容**：收藏句 (favorite_sentences)、书籍本体一律保留（与 per-book
  /// [deleteReadingStatisticsForTitle] 同一「只清纯统计」边界）。
  ///
  /// 与 per-book 删除不同：这是**本地整体重置**，legacy 家族不逐标题写墓碑——title
  /// 墓碑是定向删除的防同步复活机制，全量重置若逐 title 立碑会永久毒化标题命名空间、
  /// 阻断以后重新导入这些书的统计；legacy 行云同步下次聚合仍可能从云端 MAX-union 回灌
  /// （旧数据的旧口径，已知边界）。v92 段则**逐身份立碑**（[clearStudySegments]，
  /// BUG-2215）：新墓碑语义只压制清空之前开始的段，之后再读照常计。
  ///
  /// v105：v92 段只清当前激活 Profile 的；legacy 家族与计数面没有 Profile 维度，
  /// 只在当前 Profile 看得见 legacy 行（[legacyStatsVisibleTo]）时才连带清——
  /// 别的 Profile 看不见的历史不能被它的「清空全部」抹掉。
  Future<void> clearAllReadingStatistics() => transaction(() async {
        final int profileId = await resolveActiveProfileId();
        await clearStudySegments(kActivityMediaBook, profileId: profileId);
        if (!await legacyStatsVisibleTo(profileId)) return;
        await delete(readingStatistics).go();
        await delete(readingHourlyLogs).go();
      });

  /// Update a book's author (BUG-220). Unlike a title rename (which would
  /// change the primary key bookKey = sanitized title and require a cascading
  /// re-key), the author column is NOT the primary key, so this is a plain
  /// UPDATE with no cascading re-key. Pass a blank/empty [author] to clear
  /// it (stored as NULL) so the detail dialog hides the author line.
  Future<void> updateEpubBookAuthor(String bookKey, String? author) {
    final String? trimmed = author?.trim();
    final String? value = (trimmed == null || trimmed.isEmpty) ? null : trimmed;
    return (update(epubBooks)..where((t) => t.bookKey.equals(bookKey)))
        .write(EpubBooksCompanion(author: Value(value)));
  }

  /// v87：改写一本书的内容语言（BCP-47），决定正文用哪条字体链。
  ///
  /// null 是**有意义的取值**（= 未知，阅读器不写 `font-family`，保持浏览器默认），
  /// 所以无条件写穿，不沿用「null = 不变」的约定——与相邻 [updateEpubBookFormat]
  Future<void> updateEpubBookLanguage(String bookKey, String? language) =>
      (update(epubBooks)..where((t) => t.bookKey.equals(bookKey)))
          .write(EpubBooksCompanion(language: Value(language)));

  /// TODO-1192: 重写一本书的 `chaptersJson`（每章元数据 + `characters` 计数 +
  /// `charCaliber` 口径版本）。开书时若发现落库计数是旧口径（含标点/括号/空白），
  /// 按新口径 `countStudyChars` 后台重算后回写，使书架总字数与后续统计对齐
  /// hoshi。`chaptersJson` 不是主键（bookKey = sanitized title），plain UPDATE，
  /// 无级联 re-key。
  Future<void> updateEpubBookChaptersJson(
          String bookKey, String chaptersJson) =>
      (update(epubBooks)..where((t) => t.bookKey.equals(bookKey)))
          .write(EpubBooksCompanion(chaptersJson: Value(chaptersJson)));

  // ── manga_chapter_states（v89）─────────────────────────────────────
  //
  // 「章」的读取状态。为什么不并进 reader_positions：那张表 bookUid 是
  // unique()，一本书恒一条，表达不了「这本书的第 37 章读到第 8 页」。

  /// Rewrites a book's on-disk content paths (full-data backup restore rebases
  /// absolute paths to this device's roots). Only supplied fields are written;
  /// null leaves a column unchanged.
  Future<void> updateEpubBookContentPaths(
    String bookKey, {
    String? epubPath,
    String? extractDir,
    String? coverPath,
  }) =>
      (update(epubBooks)..where((t) => t.bookKey.equals(bookKey))).write(
        EpubBooksCompanion(
          epubPath: epubPath == null ? const Value.absent() : Value(epubPath),
          extractDir:
              extractDir == null ? const Value.absent() : Value(extractDir),
          coverPath:
              coverPath == null ? const Value.absent() : Value(coverPath),
        ),
      );

  /// Deletes a book and all of its dependent rows in one transaction.
  Future<int> deleteEpubBook(String bookKey) =>
      transaction(() async {
        // v82：uid 键子表（reader_positions/bookmarks/book_custom_css/
        // revealed_images）按书行 uid 显式清理——这些表刻意无 SQL FK（uid 唯一
        // 性是 partial 索引，FK 会 mismatch），本函数即全量级联的唯一真相源，
        // 与 runtime foreign_keys pragma 状态无关。
        final String? bookUid = await (selectOnly(epubBooks)
              ..addColumns([epubBooks.uid])
              ..where(epubBooks.bookKey.equals(bookKey)))
            .map((r) => r.read(epubBooks.uid))
            .getSingleOrNull();
        if (bookUid != null && bookUid.isNotEmpty) {
          await (delete(readerPositions)
                ..where((t) => t.bookUid.equals(bookUid)))
              .go();
          await (delete(bookmarks)..where((t) => t.bookUid.equals(bookUid)))
              .go();
          await (delete(bookCustomCss)..where((t) => t.bookUid.equals(bookUid)))
              .go();
          await (delete(revealedImages)
                ..where((t) => t.bookUid.equals(bookUid)))
              .go();
        }
        // v77：标签映射是逻辑外键，随宿主显式清理。
        await deleteTagAssignmentsForHost(TagHostKind.epub, bookKey);
        // TODO-616：同事务清 shelf_entry。v83 起 epub 域 entryKey = uid。
        if (bookUid != null && bookUid.isNotEmpty) {
          await deleteShelfEntry(MediaKind.epub, bookUid);
          // v83 顺手修的历史缺口：epub 删除此前不清合集成员行 → 计数虚高、
          // 移空自删失效、孤儿被 sync 原样发布。与 video/game 删除路径对齐。
          await removeEntryFromAllCollections(MediaKind.epub, bookUid);
        }
        return (delete(epubBooks)..where((t) => t.bookKey.equals(bookKey)))
            .go();
      });
}
