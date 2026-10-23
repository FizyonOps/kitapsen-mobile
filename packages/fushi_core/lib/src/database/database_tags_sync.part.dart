// 标签全域 / CSS 与揭开状态同步 / 删除传播 / Profile / 基线 / v16 重键（God 类拆分 2026-08：part+mixin，仓库 reader_fushi
// part 先例；mixin 是真类成员——可被测试子类 override、虚分派正常
// （extension 方案在此翻车过）；私有 mixin 不进公共 API 面。
part of 'database.dart';

mixin _FushiDbTagsSync on _$FushiDatabase, _FushiDbInfra {
  // ── book tags ───────────────────────────────────────────────────
  Future<List<BookTagRow>> getAllTags() => (select(bookTags)
        ..orderBy([
          (t) => OrderingTerm.asc(t.sortOrder),
          (t) => OrderingTerm.asc(t.createdAt),
        ]))
      .get();

  // ── tag_assignments 通用内核（v77 五表合一）───────────────────────
  // 五种宿主的公开 API 保持类型化签名（addTagToBook / addTagToGame / ...），
  // 内脏统一走这四个泛型内核——语义差异（谁写墓碑、谁进 sync）留在公开方法层，
  // 数据形状只有一份。

  /// 宿主当前标签（按 createdAt 升序，五域一致）。
  Future<List<BookTagRow>> _tagsForHost(TagHostKind kind, String entryKey) {
    final query = select(bookTags).join([
      innerJoin(tagAssignments, tagAssignments.tagId.equalsExp(bookTags.id)),
    ])
      ..where(tagAssignments.mediaKind.equals(kind.dbValue) &
          tagAssignments.entryKey.equals(entryKey))
      ..orderBy([OrderingTerm.asc(bookTags.createdAt)]);
    return query.map((row) => row.readTable(bookTags)).get();
  }

  /// upsert 一条映射并写 [addedAt]（无则插入，有则刷新 addedAt——LWW add 时钟）。
  Future<void> _upsertAssignmentWithTime(
      TagHostKind kind, String entryKey, int tagId, int addedAt) async {
    await into(tagAssignments).insert(
      TagAssignmentsCompanion.insert(
        mediaKind: kind.dbValue,
        entryKey: entryKey,
        tagId: tagId,
        addedAt: Value(addedAt),
      ),
      onConflict: DoUpdate(
        (old) => TagAssignmentsCompanion(addedAt: Value(addedAt)),
        target: [
          tagAssignments.mediaKind,
          tagAssignments.entryKey,
          tagAssignments.tagId,
        ],
      ),
    );
  }

  Future<void> _deleteAssignment(
          TagHostKind kind, String entryKey, int tagId) =>
      (delete(tagAssignments)
            ..where((t) =>
                t.mediaKind.equals(kind.dbValue) &
                t.entryKey.equals(entryKey) &
                t.tagId.equals(tagId)))
          .go();

  /// 含【全部】选中标签的宿主键（AND 语义）。空集返回空。
  Future<Set<String>> _entryKeysForAllTags(
      TagHostKind kind, Set<int> tagIds) async {
    if (tagIds.isEmpty) return <String>{};
    final int tagCount = tagIds.length;
    final String placeholders = List.generate(tagCount, (_) => '?').join(',');
    final rows = await customSelect(
      'SELECT entry_key FROM tag_assignments '
      'WHERE media_kind = ? AND tag_id IN ($placeholders) '
      'GROUP BY entry_key '
      'HAVING COUNT(DISTINCT tag_id) = ?',
      variables: <Variable>[
        Variable<String>(kind.dbValue),
        ...tagIds.map((id) => Variable<int>(id)),
        Variable<int>(tagCount),
      ],
    ).get();
    return rows.map((row) => row.read<String>('entry_key')).toSet();
  }

  /// 宿主删除路径的映射清理（v77 起五表 cascade 由显式清理取代——逻辑外键，
  /// 同 ShelfEntries 惯例）。
  Future<void> deleteTagAssignmentsForHost(TagHostKind kind, String entryKey) =>
      (delete(tagAssignments)
            ..where((t) =>
                t.mediaKind.equals(kind.dbValue) & t.entryKey.equals(entryKey)))
          .go();

  /// 某 kind 的全部映射行（SQL 面过滤——PK 前缀白拿的索引，别在调用方全表
  /// 扫再 Dart 滤，review5-8）。
  Future<List<TagAssignmentRow>> getTagAssignmentsForKind(TagHostKind kind) =>
      (select(tagAssignments)..where((t) => t.mediaKind.equals(kind.dbValue)))
          .get();

  Future<List<BookTagRow>> getTagsForBook(String bookKey) =>
      _tagsForHost(TagHostKind.epub, bookKey);

  Future<int> createTag(String name, int colorValue) async {
    final maxQuery = selectOnly(bookTags)
      ..addColumns([bookTags.sortOrder.max()]);
    final maxRow = await maxQuery.getSingleOrNull();
    final int nextOrder = (maxRow?.read(bookTags.sortOrder.max()) ?? 0) + 1;
    return into(bookTags).insert(
      BookTagsCompanion.insert(
        name: name,
        colorValue: Value(colorValue),
        sortOrder: Value(nextOrder),
        createdAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  /// 改标签名 / 颜色。
  Future<void> updateTag(int id, {String? name, int? colorValue}) =>
      (update(bookTags)..where((t) => t.id.equals(id))).write(
        BookTagsCompanion(
          name: name != null ? Value(name) : const Value.absent(),
          colorValue:
              colorValue != null ? Value(colorValue) : const Value.absent(),
        ),
      );


  /// 删标签（映射随 FK cascade 消失）。
  Future<int> deleteTag(int id) =>
      (delete(bookTags)..where((t) => t.id.equals(id))).go();


  /// 本机用户给宿主加标签（写 addedAt = now）。各宿主共用。
  Future<void> _addTagClocked(
      TagHostKind kind, String entryKey, int tagId) async {
    final int now = DateTime.now().millisecondsSinceEpoch;
    await _upsertAssignmentWithTime(kind, entryKey, tagId, now);
  }

  /// 本机用户从宿主移除标签。
  Future<void> _removeTagClocked(
      TagHostKind kind, String entryKey, int tagId) async {
    await _deleteAssignment(kind, entryKey, tagId);
  }

  Future<void> addTagToBook(String bookKey, int tagId) =>
      _addTagClocked(TagHostKind.epub, bookKey, tagId);

  Future<void> removeTagFromBook(String bookKey, int tagId) =>
      _removeTagClocked(TagHostKind.epub, bookKey, tagId);

  Future<Set<String>> getBookKeysForAllTags(Set<int> tagIds) =>
      _entryKeysForAllTags(TagHostKind.epub, tagIds);

  Future<void> reorderTags(List<int> orderedTagIds) => transaction(() async {
        for (int i = 0; i < orderedTagIds.length; i++) {
          await (update(bookTags)..where((t) => t.id.equals(orderedTagIds[i])))
              .write(BookTagsCompanion(sortOrder: Value(i)));
        }
      });

  /// 某标签下的条目数量 = EPUB + 有声书(SRT) + 视频 + 游戏命中该 tagId 的映射
  /// 行数（合集刻意不计：合集是容器而非条目）。v77 合表后一条 COUNT 搞定——
  /// 旧实现逐表 COUNT 漏表的 bug 形状（BUG-1113）在结构上不可能再犯。
  Future<int> countBooksForTag(int tagId) async {
    final cnt = countAll();
    final row = await (selectOnly(tagAssignments)
          ..where(tagAssignments.tagId.equals(tagId) &
              tagAssignments.mediaKind
                  .equals(TagHostKind.collection.dbValue)
                  .not())
          ..addColumns([cnt]))
        .getSingle();
    return row.read(cnt) ?? 0;
  }

  // ── srt book tags ───────────────────────────────────────────────
  // v77 起宿主键换 SrtBooks.uid（跨设备稳定），弃本机自增 int id。

  // ── video book tags ─────────────────────────────────────────────

  // ── 合集标签（复用 BookTags 池）──────────────────────────────────────
  // 互联标签同步（tag_sync_engine）起合集标签与书/视频同一套 LWW 时钟 + 移除墓碑；
  // 合集清单里无时钟的 tagNames 只经 [mergeRemoteCollectionTagNames] 弱并入。

  /// 合集当前挂的标签（按 createdAt 升序，与 getTagsForBook 一致）。
  Future<List<BookTagRow>> getTagsForCollection(int collectionId) =>
      _tagsForHost(TagHostKind.collection, collectionTagEntryKey(collectionId));

  /// 给合集加标签（幂等；清同名移除墓碑）。
  Future<void> addTagToCollection(int collectionId, int tagId) =>
      _addTagClocked(
          TagHostKind.collection, collectionTagEntryKey(collectionId), tagId);

  /// 从合集移除标签（写移除墓碑，经互联标签同步传播到对端）。
  Future<void> removeTagFromCollection(int collectionId, int tagId) =>
      _removeTagClocked(
          TagHostKind.collection, collectionTagEntryKey(collectionId), tagId);

  /// 含【全部】选中标签的合集 id（AND 语义，仿 getBookKeysForAllTags）。空集返回空。
  Future<Set<int>> getCollectionIdsForAllTags(Set<int> tagIds) async {
    final Set<String> keys =
        await _entryKeysForAllTags(TagHostKind.collection, tagIds);
    return <int>{
      for (final String key in keys)
        if (collectionIdOfTagEntryKey(key) case final int id) id,
    };
  }

  // ── 游戏标签（v59 / BUG-1113；复用 BookTags 池）────────────────────────
  // 宿主键是本机 galgames.id；跨设备经 GameIdentityIndex 换算成游戏跨端身份。

  // ── tags 跨端同步（LWW-element-set：added_at vs 墓碑 deleted_at）──────────────
  // 标签跨设备身份 = name。sync 合并按名并集两端「当前标签(带 addedAt)」与「移除墓碑
  // (带 deletedAt)」，逐名 max(addedAt) vs max(deletedAt) 裁决 present/removed，防复活/
  // 防误删。UI 加/删标签写 addedAt/墓碑，让本地操作也进入同一 LWW 时钟。


  // ── per-book 自定义 CSS 跨端同步（LWW by updatedAt）──────────────────────────

  /// 记录/刷新书 [bookUid]（v82 起 = 书稳定 uid）的 CSS 文件 [relativePath] 自定义内容（保存时调，updatedAt=now）。
  Future<void> upsertBookCss(
          String bookUid, String relativePath, String content, int updatedAt) =>
      into(bookCustomCss).insertOnConflictUpdate(BookCustomCssRow(
        bookUid: bookUid,
        relativePath: relativePath,
        content: content,
        deleted: false,
        updatedAt: updatedAt,
      ));

  /// 记录书 [bookUid] 的 CSS 文件 [relativePath] 已重置回原始（重置墓碑，updatedAt=now）。
  /// 使「reset」跨端传播（LWW 较新的重置让他端也 reset）。
  Future<void> markBookCssReset(
          String bookUid, String relativePath, int updatedAt) =>
      into(bookCustomCss).insertOnConflictUpdate(BookCustomCssRow(
        bookUid: bookUid,
        relativePath: relativePath,
        content: '',
        deleted: true,
        updatedAt: updatedAt,
      ));

  // ── 图片防剧透遮罩揭开状态（持久 per-book；书内↔图片库双向同步，BUG-898）──────────

  /// 标记书 [bookUid] 的图片 [imageKey]（extractDir 相对、解码、正斜杠归一路径）已揭开
  /// 遮罩。幂等 upsert（重复揭开刷新 [revealedAt]）。阅读器点击/手柄/音频跨图、图片库
  /// 点开都调它，DB 是唯一真相源。
  Future<void> markImageRevealed(
          String bookUid, String imageKey, int revealedAt) =>
      into(revealedImages).insertOnConflictUpdate(RevealedImageRow(
        bookUid: bookUid,
        imageKey: imageKey,
        revealedAt: revealedAt,
      ));

  /// 撤销书 [bookUid] 图片 [imageKey] 的揭开状态（插图册长按「恢复遮罩」）。删行而不是
  /// 写一条「未揭开」标记：本表的语义就是「在册即已揭开」，补一个否定态会让同一事实有
  /// 两种表示，同步与迁移都得再判一次。行不存在是正常入参（幂等）。
  Future<void> unmarkImageRevealed(String bookUid, String imageKey) =>
      (delete(revealedImages)
            ..where((t) =>
                t.bookUid.equals(bookUid) & t.imageKey.equals(imageKey)))
          .go();

  /// 书 [bookUid] 全部已揭开图片 key 集合。阅读器打开时读它灌入会话集、图片库渲染时读它
  /// 判断哪些图不遮罩。
  Future<Set<String>> getRevealedImageKeys(String bookUid) async {
    final List<RevealedImageRow> rows = await (select(revealedImages)
          ..where((t) => t.bookUid.equals(bookUid)))
        .get();
    return rows.map((RevealedImageRow r) => r.imageKey).toSet();
  }

  // ── profiles ──────────────────────────────────────────────────────
  Future<List<ProfileRow>> getAllProfiles() =>
      (select(profiles)..orderBy([(t) => OrderingTerm.asc(t.createdAt)])).get();

  Future<ProfileRow?> getProfileById(int id) =>
      (select(profiles)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<int> insertProfile(ProfilesCompanion p) => into(profiles).insert(p);

  // ── Profile 分区（v105：统计按 Profile 隔离）────────────────────
  // 住这一层而不是 _FushiDbStatistics：删除原语在 _FushiDbContentMisc、写入 /
  // 读取在 _FushiDbStatistics，mixin 只能向下看，公共解析点必须在两者之下。

  Future<String?> _prefValueOf(String key) async {
    final PreferenceRow? row =
        await (select(preferences)..where((t) => t.key.equals(key)))
            .getSingleOrNull();
    return row?.value;
  }

  /// 当前激活的 Profile id（统计分区键的**唯一**解析点）。
  ///
  /// 读 `active_profile_id` 偏好并验证该 Profile 还在；不在 / 缺失时退到最早建的
  /// Profile（与 fushi 层 `ensureDefaultProfile` 的兜底同序）；库里一个 Profile
  /// 都没有时返回 0——只在纯 DB 测试里出现（app 启动即 `ensureDefaultProfile`），
  /// 此时写入盖 0、读取滤 0，测试里写读自洽。**不在这里建 Profile**：建
  /// Profile 必须连带快照设置（`snapshotCurrentSettings`，在 fushi 层），DB 层
  /// 造一个空快照的 Profile 会让下次 `applyProfile` 把全部偏好剪光。
  Future<int> resolveActiveProfileId() async {
    final String? raw = await _prefValueOf(kActiveProfileIdPrefKey);
    final int fromPref = int.tryParse(raw ?? '') ?? -1;
    if (fromPref > 0 && await getProfileById(fromPref) != null) {
      return fromPref;
    }
    final List<ProfileRow> all = await getAllProfiles();
    return all.isEmpty ? 0 : all.first.id;
  }

  /// legacy 统计家族归属的 Profile id（[kStatLegacyProfileIdPrefKey]）；null =
  /// 无归属 = 对所有 Profile 可见。
  Future<int?> getStatLegacyProfileId() async {
    final String? raw = await _prefValueOf(kStatLegacyProfileIdPrefKey);
    final int? id = int.tryParse(raw ?? '');
    return id != null && id > 0 ? id : null;
  }

  /// legacy 统计行对 [profileId] 是否可见（读取面与「清空全部」的 legacy 删行
  /// 共用同一判据：看不见的历史不能被另一个 Profile 的清空连带删掉）。
  Future<bool> legacyStatsVisibleTo(int profileId) async {
    final int? owner = await getStatLegacyProfileId();
    return owner == null || owner == profileId;
  }

  /// 缺席 `profileId` 的段补上当前激活 Profile（写入方不用知道 Profile）。
  Future<StudySegmentsCompanion> _stampStudySegmentProfile(
    StudySegmentsCompanion row,
  ) async =>
      row.profileId.present
          ? row
          : row.copyWith(profileId: Value(await resolveActiveProfileId()));

  // ── profile settings ─────────────────────────────────────────────
  Future<List<ProfileSettingRow>> getProfileSettings(int profileId) =>
      (select(profileSettings)..where((t) => t.profileId.equals(profileId)))
          .get();

  Future<void> replaceProfileSettings(
          int profileId, List<ProfileSettingsCompanion> settings) =>
      transaction(() async {
        await (delete(profileSettings)
              ..where((t) => t.profileId.equals(profileId)))
            .go();
        await batch((b) {
          for (final s in settings) {
            b.insert(profileSettings, s);
          }
        });
      });

  // ── media type profiles ──────────────────────────────────────────
  Future<List<MediaTypeProfileRow>> getAllMediaTypeProfiles() =>
      select(mediaTypeProfiles).get();

  Future<MediaTypeProfileRow?> getMediaTypeProfile(String mediaType) =>
      (select(mediaTypeProfiles)..where((t) => t.mediaType.equals(mediaType)))
          .getSingleOrNull();

  // ── language profiles ────────────────────────────────────────────
  // 键是**归一化后**的语言标签（`normalizeLanguageBinding`），不是内容语言列里
  // 的原始 BCP-47 串。归一在 fushi 侧的 ProfileRepository 做，这层只存取。
  Future<List<LanguageProfileRow>> getAllLanguageProfiles() =>
      select(languageProfiles).get();

  Future<LanguageProfileRow?> getLanguageProfile(String languageTag) =>
      (select(languageProfiles)
            ..where((t) => t.languageTag.equals(languageTag)))
          .getSingleOrNull();

  // ── book profiles ────────────────────────────────────────────────
  Future<BookProfileRow?> getBookProfile(String bookKey) =>
      (select(bookProfiles)..where((t) => t.bookKey.equals(bookKey)))
          .getSingleOrNull();

  Future<void> setBookProfile(String bookKey, int profileId) =>
      into(bookProfiles).insertOnConflictUpdate(
        BookProfilesCompanion.insert(
          bookKey: bookKey,
          profileId: profileId,
        ),
      );

  Future<int> deleteBookProfile(String bookKey) =>
      (delete(bookProfiles)..where((t) => t.bookKey.equals(bookKey))).go();

  // ── v16 book-key migration ──────────────────────────────────────
  // Legacy uid prefix that wrapped the int book id in audiobooks/audio_cues/
  // book_profiles and in the uid-style audiobook_pos_ prefs. Single literal so
  // the migration's int-extraction matches what buildLegacyBookUid produced.
}
