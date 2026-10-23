// GENERATED-NOTE: extracted from reader_fushi_history_page.dart (TODO-587).
part of '../reader_fushi_history_page.dart';

/// books domain methods extracted via part-of (TODO-587); shared private scope.
extension _ReaderHistoryBooks on _ReaderFushiHistoryPageState {
  /// 全选 / 反选的候选散卡键 = **屏幕上真的画出来的那些散卡**，直接取每帧
  /// [MediaSelectionController.setVisibleOrder] 登记的可见散卡序（那份就是按
  /// `groupByCollections` 折叠后剩下的散卡组逐项推出来的）。
  ///
  /// 此前这里自推一遍资格（`!_isEpubCollectionMember` / `!_isSrtCollectionMember`，
  /// 两个方法已随之删除，免得又被当成判据捡回来），与登记可见序的那份口径是两处
  /// 推导、已经漂开了：`collectionIdOf` 要求合集**当前还存在**才算折叠，那两个
  /// 方法却只查归属键在不在。于是合集行被删、成员行还在的孤儿条目在墙上按散卡
  /// 渲染、进得了可见序，却被判成合集成员排除出候选——单击能勾、全选勾不上、
  /// 反选也还不掉。视频库同一处已收敛到真相源，这里跟上。
  Set<String> _selectableLooseKeys() => _selection.visibleLooseKeys.toSet();

  void _selectAll() {
    _rebuild(() => _selection.selectAll(
          loose: _selectableLooseKeys(),
          collections: _visibleCollectionIds,
        ));
  }

  void _invertSelection() {
    _rebuild(() => _selection.invert(
          loose: _selectableLooseKeys(),
          collections: _visibleCollectionIds,
        ));
  }

  Widget _buildBatchActionBar() {
    // 块2/3/4：计数与按钮可用态涵盖散卡选中集 + 合集选中集。
    // BUG-2458：散卡选中集里混着远端占位键——「已选 N」计全部，但组合 / 打标签 /
    // 删除三个本地动作只按本地键判可用态与取目标；远端键只喂「下载」。
    final Set<String> localKeys = _selectedLocalKeys;
    final Set<String> remoteKeys = _selectedRemoteKeys;
    final int selectedCount =
        _selectedKeys.length + _selectedCollectionIds.length;
    final bool hasLocalSelection =
        localKeys.isNotEmpty || _selectedCollectionIds.isNotEmpty;
    // 复查 #5：组合按钮 noop 档（0 合集 0 散卡 / 仅 1 合集且无散卡）不再当启用态死按钮，
    // 只在真能组合（新建 / 并入 / 合并）时才可点，与 [_batchCombineIntoSeries] 同判据。
    final bool canCombine = classifyCombine(
          collectionCount: _selectedCollectionIds.length,
          looseCount: localKeys.length,
        ) !=
        CombineTier.noop;
    return BatchActionBar(
      selectedCount: selectedCount,
      onSelectAll: _selectAll,
      onInvertSelection: _invertSelection,
      actions: <Widget>[
        FushiIconButton(
          key: const ValueKey<String>('reader_shelf_batch_download'),
          enabled: remoteKeys.isNotEmpty,
          onTap: _batchDownloadSelectedRemote,
          icon: Icons.download_outlined,
          tooltip: t.remote_book_download,
        ),
        FushiIconButton(
          key: const ValueKey<String>('reader_shelf_batch_combine'),
          enabled: canCombine,
          onTap: _batchCombineIntoSeries,
          // 组合成系列用 playlist_add，与页头「收藏夹」入口的
          // collections_bookmark_outlined 区分开（二者语义无关，避免同图标歧义）。
          icon: Icons.playlist_add,
          tooltip: t.combine_into_series,
        ),
        FushiIconButton(
          // 打标签只作用于散卡媒体（合集无直接标签），故按本地散卡选中集可用态。
          enabled: localKeys.isNotEmpty,
          onTap: _batchShowTagPicker,
          icon: Icons.sell_outlined,
          tooltip: t.tag_label,
        ),
        FushiIconButton(
          key: const ValueKey<String>('reader_shelf_batch_delete'),
          enabled: hasLocalSelection,
          onTap: _batchDeleteConfirm,
          icon: Icons.delete_outline,
          tooltip: t.dialog_delete,
          enabledColor: theme.colorScheme.error,
        ),
      ],
    );
  }

  /// 块4：批量删除区分解散/删媒体。
  /// - 选中合集 → 解散（[FushiDatabase.deleteMediaCollection]：只解除分组，不删媒体本体）；
  /// - 选中散卡 → 删媒体本体；
  /// - 混选 → 确认框文案写明「删 N 个媒体、解散 M 个合集」。
  Future<void> _batchDeleteConfirm() async {
    // 先剔幽灵键再取数：确认框里的 N / M 必须是真会被删的条数。
    if (!await _pruneStaleSelection() || !mounted) return;
    // **在弹确认框之前就把目标定死**：选中集是只暴露当前可见项的派生视图，弹窗
    // 期间任何一次改变可见序的重建（筛选 provider 解析完成、书架刷新）都会让它
    // 自己变，跨 await 两侧各读一次会让确认框的数字与实际删除量对不上。
    final Set<String> targetKeys = _selectedLocalKeys;
    final Set<int> targetCollectionIds = Set<int>.of(_selectedCollectionIds);
    final int mediaCount = targetKeys.length;
    final int collectionCount = targetCollectionIds.length;
    if (mediaCount == 0 && collectionCount == 0) return;
    final String baseMessage = collectionCount == 0
        ? t.batch_delete_confirm(n: mediaCount)
        : mediaCount == 0
            ? t.batch_dissolve_confirm(m: collectionCount)
            : t.batch_delete_mixed_confirm(n: mediaCount, m: collectionCount);
    // 勾过但被当前搜索/标签筛选挡住的那些不会被删，必须说出来。
    // 只数本地键：远端占位键不是删除对象（BUG-2458 审查 #4）。
    final int hidden = _selection.hiddenSelectedCountWhere(
      (String key) => !_isRemoteSelectionKey(key),
    );
    final String message = hidden == 0
        ? baseMessage
        : '$baseMessage\n\n${t.batch_hidden_by_filter_note(n: hidden)}';
    // 「同时删除统计数据」只在选中散卡里至少有一本**带 bookKey** 的书时摆出来；
    // 全是纯字幕书就不摆（执行时也跳过它们，见下面的删除循环）。
    final bool anyStatisticsTarget =
        mediaCount > 0 && await _selectionHasStatisticsTarget(targetKeys);
    if (!mounted) return;
    final DeleteDecision? decision = await showAppDialog<DeleteDecision>(
      context: context,
      builder: (ctx) => ReaderHistoryDeleteDialog(
        title: t.dialog_delete,
        message: message,
        // 纯解散合集（mediaCount==0）不碰媒体本体，不能挂「会删解压目录/有声书」
        // 的披露；只有真删散卡时才披露真实删除范围。
        disclosure: mediaCount == 0
            ? null
            : buildDeletionDisclosure(),
        // 纯解散合集不删任何书，统计无从谈起；全是纯字幕书同样不摆。
        statisticsSubtitle: anyStatisticsTarget ? _statisticsSubtitle : null,
        onConfirm: (DeleteDecision d) => Navigator.pop(ctx, d),
      ),
    );
    if (decision == null || !mounted) return;
    final bool deleteStatistics = decision.deleteStatistics;

    // 先解散选中合集（只删合集容器 + 成员引用行，绝不删媒体本体）。
    // 用确认框弹出前定死的那份目标，不重新读选中集。
    final Set<int> toDissolve = targetCollectionIds;
    int dissolved = 0;
    for (final int id in toDissolve) {
      final int removed =
          await deleteMediaCollectionWithAssets(appModel.database, id);
      if (removed > 0) dissolved++;
    }

    int deleted = 0;
    // 目标集在确认框弹出前就定死（[targetKeys]），不重新读 `_selectedKeys`。
    final Set<String> toDelete = targetKeys;
    for (final key in toDelete) {
      final String? bookKey = _parseBookKey(key);
      if (bookKey != null) {
        final DeleteBookResult result =
            await ReaderFushiSource.instance.deleteBook(
          db: appModel.database,
          bookKey: bookKey,
          deleteStatistics: deleteStatistics,
        );
        if (result.deleted) deleted++;
      }
    }
    if (!mounted) return;
    _refreshRemoteBooks();
    ref.invalidate(fushiBooksProvider);
    ref.invalidate(bookTagMapProvider);
    // 解散后合集映射失效，重取（合集行随之消失）。
    _shelfMapsFuture = _loadShelfMaps();
    _exitSelectionMode();
    // 复查 #7：零成功（deleted==0 且 dissolved==0）时兜底文案按「选择构成」诚实分派——
    // 只选散卡（collectionCount==0）说「已删除 0 本」，否则说「已解散 0 个合集」；不再
    // 无条件谎报解散类别（对齐 BUG-439 诚实计数精神）。
    final String successMsg = deleted > 0 && dissolved > 0
        ? t.batch_delete_mixed_success(n: deleted, m: dissolved)
        : deleted > 0
            ? t.batch_delete_success(n: deleted)
            : collectionCount == 0
                ? t.batch_delete_success(n: deleted)
                : t.batch_dissolve_success(m: dissolved);
    FushiToast.show(
      msg: successMsg,
      severity: deleted > 0 || dissolved > 0
          ? ToastSeverity.success
          : ToastSeverity.warning,
    );
  }

  /// 选中散卡里是否至少有一本能安全删统计的书：EPUB / PDF / 漫画（bookKey 选择
  /// 键），或配对了 EPUB 的字幕书（bookKey 非空）。纯字幕书（bookKey 空）不算——
  /// 它的 legacy 统计与墓碑只能按 title 定位，删它会连坐同名 EPUB 的统计。
  Future<bool> _selectionHasStatisticsTarget(Set<String> keys) async {
    for (final String key in keys) {
      if (_parseBookKey(key) != null) return true;
      continue;
    }
    return false;
  }

  /// 批量操作前把选中集收敛到真实存在的条目上，真剔掉了就明说。
  ///
  /// 与视频库同一纪律（见 `home_video_page._pruneStaleSelection`）：选中集不随库
  /// 变化剪枝，多选态期间同步下架 / 别处删除都会留下幽灵键，落库时撞外键——打标签
  /// 会把弹窗卡死在 loading、组合会静默失败、确认框数字是虚数。
  ///
  /// 存在性全集取**全库**而非可见集：被搜索或标签筛掉的书仍然存在，用户先勾后筛
  /// 是合法用法，不该被悄悄剔掉。
  ///
  /// 返回剔完后是否还有东西可做。
  Future<bool> _pruneStaleSelection() async {
    if (_selection.isEmpty) return false;
    final FushiDatabase db = appModel.database;
    // 存在性真值必须取自**书架选择键的来源表**，不是名字相近的 `media_items`：
    // 书架 EPUB 卡的选择键是 `ReaderFushiSource.mediaIdentifierFor(bookKey)`，
    // bookKey 的真值在 `epub_books`（`fushiBooksProvider` 也是从这里取的）；
    // `getAllMediaItems()` 是另一张表、另一套 mediaIdentifier 语义，拿它做判据
    // 会把全部选中项误判成幽灵键而整批剔光。
    final List<EpubBookMeta> epubBooks = await db.getEpubBookMetas();
    // v83：合集成员表 epub entryKey = `epub_books.uid`，而选择键解码出的身份仍是
    // bookKey。批量组合/加合集都在本剪枝之后立即落库，借同一批行顺带刷新
    // bookKey→uid 换算表（[_loadShelfMaps] 同款口径），保证写库前换算不吃旧值。
    _epubUidByKey = <String, String>{
      for (final EpubBookMeta row in epubBooks)
        if (row.uid.isNotEmpty) row.bookKey: row.uid,
    };
    final List<MediaCollectionRow> collections =
        await db.getAllMediaCollections();
    if (!mounted) return false;
    // BUG-2458：远端占位键的存在性真值是最近一次拉到的远端目录（占位卡就是从它
    // 渲染的），不在本地表里；不纳入就会被当幽灵键整批剔光。
    final _RemoteBookState? remoteState = _lastRemoteState;
    final int dropped = _selection.retainExisting(
      loose: <String>{
        for (final EpubBookMeta row in epubBooks)
          ReaderFushiSource.mediaIdentifierFor(row.bookKey),
        if (remoteState != null) ...<String>[
          for (final RemoteBookInfo book in remoteState.books)
            _remoteBookSelectionKey(book),
        ],
      },
      collections: <int>{for (final MediaCollectionRow c in collections) c.id},
    );
    if (dropped == 0) return _selection.isNotEmpty;
    _rebuild(() {});
    FushiToast.show(
      msg: t.batch_selection_stale_skipped(
        n: dropped + _selection.length,
        m: dropped,
      ),
      severity: ToastSeverity.warning,
    );
    return _selection.isNotEmpty;
  }

  Future<void> _batchShowTagPicker() async {
    // 幽灵键会让 bookTags 外键插入抛异常，弹窗把落库 await 在 loading 态里，
    // 一抛就永远转圈（卡死）。必须在开弹窗前剔干净。
    if (!await _pruneStaleSelection() || !mounted) return;
    final allTags = ref.read(allTagsProvider).valueOrNull;
    if (allTags == null || allTags.isEmpty) {
      FushiToast.show(msg: t.tag_no_tags_hint, severity: ToastSeverity.info);
      return;
    }
    await showAppDialog<void>(
      context: context,
      builder: (_) => _BatchTagPickerDialog(
        allTags: allTags,
        selectedKeys: _selectedLocalKeys,
        database: appModel.database,
        parseBookKey: _parseBookKey,
      ),
    );
    if (!mounted) return;
    ref.invalidate(bookTagMapProvider);
    ref.invalidate(filteredBookIdsProvider);
  }

  /// v83：合集成员表的 epub entryKey 已切 `epub_books.uid`；选区解码身份
  /// （[shelfSelectionToEntry]）与标题/封面映射仍在 bookKey 域。排序、标题匹配
  /// 全程留在 bookKey 域，只在**落库那一步**经本函数单向换算；换算不上（书行
  /// 被并发删除的残余竞态）沿用原值——与 addToCollection 撞外键的既有剪枝兜底
  /// 一致，不静默丢条目。其它种类的键本就是稳定 uid，原样透传。
  String _collectionEntryKeyFor(ShelfEntryRef ref) =>
      ref.mediaType == MediaKind.epub
          ? (_epubUidByKey[ref.entryKey] ?? ref.entryKey)
          : ref.entryKey;

  /// 块3：批量「组合」按钮三档自适应（[classifyCombine]）。书架选择键经
  /// shelfSelectionToEntry 解码成 (mediaType, entryKey)：
  /// - 仅散卡 → 命名弹窗新建合集（[_combineCreateNew]）；
  /// - 恰 1 合集 + 若干散卡 → 散卡并入该合集（[_combineAddToExisting]，不弹命名）；
  /// - ≥2 合集（可带散卡）→ 合并成一个（[_combineMergeCollections]，默认名=成员最多合集名）。
  Future<void> _batchCombineIntoSeries() async {
    // 幽灵键会让 addToCollection 撞外键且无人 catch（用户只看到「点了没反应」）。
    if (!await _pruneStaleSelection() || !mounted) return;
    final List<int> collectionIds = _selectedCollectionIds.toList()..sort();
    // 成员序按显示标题自然序落盘（`卷1 < 卷2 < 卷10`），不用 `_selectedKeys` 的
    // 点选顺序——否则框选一套书建出来的合集内部是乱的（BUG-1436）。标题走
    // display-title 门面，与用户看到的一致。
    // 键带 mediaType，裸 entryKey 做映射键有撞键风险。
    final Map<String, String> titleByRef = <String, String>{
      for (final MediaItem item in _visibleEpubBooks)
        if (shelfSelectionToEntry(item.mediaIdentifier)
            case final ShelfEntryRef ref)
          '${ref.mediaType}|${ref.entryKey}':
              displayTitleForBook(item: item, rawTitle: item.title),
    };
    final List<ShelfEntryRef> looseRefs = sortNewCollectionMembersNaturally(
      <ShelfEntryRef>[
        for (final String key in _selectedLocalKeys)
          if (shelfSelectionToEntry(key)
              case final ShelfEntryRef ref)
            ref,
      ],
      titleOf: (ShelfEntryRef r) =>
          titleByRef['${r.mediaType}|${r.entryKey}'] ?? r.entryKey,
    );
    final CombineTier tier = classifyCombine(
      collectionCount: collectionIds.length,
      looseCount: looseRefs.length,
    );
    switch (tier) {
      case CombineTier.noop:
        return;
      case CombineTier.createNew:
        await _combineCreateNew(looseRefs);
      case CombineTier.addToExisting:
        await _combineAddToExisting(collectionIds.single, looseRefs);
      case CombineTier.mergeCollections:
        await _combineMergeCollections(collectionIds, looseRefs);
    }
  }

  /// 档1：仅散卡 → 命名弹窗新建合集，逐条 addToCollection。
  Future<void> _combineCreateNew(List<ShelfEntryRef> refs) async {
    // TODO-1125 B：预填合集默认名——收集选中条目标题（按 mediaIdentifier 与选择键
    // 匹配），经 deriveSeriesDefaultName 剥卷号取公共前缀；
    // 推导为空则兜底 t.series_default_name（「新系列」）。
    // P4：标题过 display-title 门面——用户看到的默认合集名应是改名后的新名
    // （合集成员身份 entryKey 仍是 raw，不受影响）。
    final List<String> memberTitles = <String>[
      for (final MediaItem item in _visibleEpubBooks)
        if (_selectedKeys.contains(item.mediaIdentifier))
          displayTitleForBook(item: item, rawTitle: item.title),
    ];
    final String defaultName = deriveSeriesDefaultName(
      memberTitles,
      fallback: t.series_default_name,
    );
    // TODO-947：把选中的前 4 本书封面传进命名弹窗，铺成手机文件夹式网格缩略预览，
    // 让用户在确认合并时直观看到「我把哪几本合并进去了」。
    final List<Widget> previewCovers = <Widget>[
      for (final MediaItem item in _visibleEpubBooks)
        if (_selectedKeys.contains(item.mediaIdentifier))
          _slotCover(
            _ShelfBookSlot(epub: item),
            _epubCoverUrisByBookKey,
          ),
    ].take(4).toList();
    final String? name = await showCollectionNameDialog(
      context: context,
      title: t.create_series,
      initialName: defaultName,
      previewCovers: previewCovers,
    );
    if (name == null || !mounted) return;
    final int collectionId =
        await appModel.database.createMediaCollection(name);
    for (final ShelfEntryRef ref in refs) {
      // v83：epub 落库键 = uid（[_collectionEntryKeyFor]，剪枝时已刷新换算表）。
      await appModel.database.addToCollection(
          collectionId, ref.mediaType, _collectionEntryKeyFor(ref));
    }
    if (!mounted) return;
    _exitSelectionMode();
    _shelfMapsFuture = _loadShelfMaps();
    _rebuild(() {});
    FushiToast.show(msg: t.series_created, severity: ToastSeverity.success);
  }

  /// 档2：恰 1 合集 + 若干散卡 → 散卡并入该合集（不弹命名）。
  Future<void> _combineAddToExisting(
    int collectionId,
    List<ShelfEntryRef> refs,
  ) async {
    for (final ShelfEntryRef ref in refs) {
      // v83：epub 落库键 = uid（[_collectionEntryKeyFor]，剪枝时已刷新换算表）。
      await appModel.database.addToCollection(
          collectionId, ref.mediaType, _collectionEntryKeyFor(ref));
    }
    if (!mounted) return;
    _exitSelectionMode();
    _shelfMapsFuture = _loadShelfMaps();
    _rebuild(() {});
    FushiToast.show(
        msg: t.batch_add_to_collection_success(n: refs.length),
        severity: ToastSeverity.success);
  }

  /// 档3：≥2 合集（可带散卡）→ 合并成一个。目标 = 成员最多合集（其名作默认名，
  /// 确认框可改名）；目标吸收其余合集成员（addToCollection）+ 散卡加入，其余合集
  /// deleteMediaCollection 解散（只解除分组，不删媒体本体）。
  Future<void> _combineMergeCollections(
    List<int> collectionIds,
    List<ShelfEntryRef> refs,
  ) async {
    final FushiDatabase db = appModel.database;
    final Map<int, List<MediaCollectionItemRow>> itemsById =
        <int, List<MediaCollectionItemRow>>{};
    for (final int id in collectionIds) {
      itemsById[id] = await db.getCollectionItems(id);
    }
    final MergeTargetChoice choice = chooseMergeTarget(
      <({int id, String name, int memberCount})>[
        for (final int id in collectionIds)
          (
            id: id,
            name: _collectionsById[id]?.name ?? '',
            memberCount: itemsById[id]!.length,
          ),
      ],
    );
    if (!mounted) return;
    final String? name = await showCollectionNameDialog(
      context: context,
      title: t.collection_merge_title,
      initialName: choice.defaultName,
    );
    if (name == null || !mounted) return;
    final int targetId = choice.targetId;
    // 复查 #6（TOCTOU）：成员快照上面是在命名确认框「之前」取的，框开着期间若有新成员
    // 同步进源合集，用旧快照迁移会漏掉这些新成员，随后 deleteMediaCollection 把它们连
    // 同源合集一起删掉 → 分组丢失。确认后、迁移前对每个源合集「重取」最新成员再迁移，
    // addToCollection 幂等去重，重复成员无副作用。
    for (final int id in collectionIds) {
      if (id == targetId) continue;
      final List<MediaCollectionItemRow> members =
          await db.getCollectionItems(id);
      for (final MediaCollectionItemRow m in members) {
        // 原样搬家现有成员行：行值可能是对端未知种类，走 raw 版防静默丢成员。
        await db.addToCollectionRaw(targetId, m.mediaType, m.entryKey);
      }
      await deleteMediaCollectionWithAssets(db, id);
    }
    for (final ShelfEntryRef ref in refs) {
      // v83：epub 落库键 = uid（[_collectionEntryKeyFor]，剪枝时已刷新换算表）。
      await db.addToCollection(
          targetId, ref.mediaType, _collectionEntryKeyFor(ref));
    }
    await db.renameMediaCollection(targetId, name);
    if (!mounted) return;
    _exitSelectionMode();
    _shelfMapsFuture = _loadShelfMaps();
    _rebuild(() {});
    FushiToast.show(msg: t.collection_merged, severity: ToastSeverity.success);
  }

  Future<void> _confirmDeleteEpub(MediaItem item, String bookKey) async {
    Navigator.pop(context);
    // P4：确认弹窗给人看，书名过门面（删除本体仍按 raw bookKey 身份执行）。
    final DeleteDecision? decision = await _confirmMediaDelete(
      title: t.epub_delete_title,
      message: t.book_delete_confirm(
        title: displayTitleForBook(item: item, rawTitle: item.title),
      ),
      disclosure: buildDeletionDisclosure(),
      statisticsSubtitle: _statisticsSubtitle,
    );
    if (decision == null) return;

    final DeleteBookResult result = await ReaderFushiSource.instance.deleteBook(
      db: appModel.database,
      bookKey: bookKey,
      deleteStatistics: decision.deleteStatistics,
    );
    if (!mounted) return;
    if (!result.deleted) {
      // TODO-1359：不再只弹笼统的「删除书籍失败」——把 deleteBook 回报的原因（同时已
      // 写入 ErrorLogService，可在日志页导出）拼进 toast，让用户知道为什么删不掉。
      final String reason = result.failureReason ?? '';
      FushiToast.show(
        msg: reason.isEmpty
            ? t.epub_delete_error
            : '${t.epub_delete_error}: $reason',
        severity: ToastSeverity.error,
      );
      return;
    }
    _refreshRemoteBooks();
    ref.invalidate(fushiBooksProvider);
    _rebuild(() {});
  }

  /// 书卡菜单「查看统计」：关掉菜单后按本书身份反查统计（书 / 漫画同走 bookKey）。
  Future<void> _openItemStatistics(MediaItem item, String bookKey) async {
    Navigator.pop(context);
    await showMediaItemStatsDialog(
      context,
      database: appModel.database,
      target: MediaItemStatsTarget(
        mediaKind: kActivityMediaBook,
        mediaKeys: <String>{bookKey},
        title: item.title,
      ),
    );
  }

  Future<void> _openIllustrations(MediaItem item, String bookKey) async {
    Navigator.pop(context);
    final EpubBookRow? row = await appModel.database.getEpubBook(bookKey);
    if (!mounted || row == null) return;
    Navigator.push(
      context,
      adaptivePageRoute(
        context: context,
        builder: (_) => IllustrationsViewerPage(
          // P4：页标题给人看，过门面；插画定位身份走 extractDir + uid（v82：
          // revealed_images 键 = EpubBooks.uid，行在手直接取）。
          bookTitle: displayTitleForBook(item: item, rawTitle: item.title),
          extractDir: row.extractDir,
          bookUid: row.uid,
          database: appModel.database,
          // 「跳到此插图」：画廊已自行 pop，这里按插图所在章 / 章内位置开书
          // （与阅读器内切卷跳章同一条 initialBookmarkJump 路径）。
          onJumpTo: (EpubImageRef image) => appModel.openMedia(
            ref: ref,
            mediaSource: item.getMediaSource(appModel: appModel),
            item: item,
            initialBookmarkJump: Bookmark(
              sectionIndex: image.jumpChapterIndex,
              normCharOffset: image.normCharOffset,
              label: '',
              createdAt: DateTime.now(),
            ),
          ),
        ),
      ),
    );
  }

  /// 书的内容语言选择框。选择器 UI 与词典共用（[showContentLanguagePicker]），
  /// 这里只负责读当前值与写库。
  ///
  /// 写完刷新页面即可——阅读器下次开书时读 EpubBooks.language 建链；书已经开着
  /// 时改语言不即时重渲（正文 CSS 在开书时生成），关掉重开生效。
  Future<void> _openBookLanguagePicker(String bookKey) async {
    Navigator.pop(context);
    final FushiDatabase db = appModel.database;
    final EpubBookRow? row = await db.getEpubBook(bookKey);
    if (!mounted) return;
    final String? current = row?.language;
    await showContentLanguagePicker(
      context: context,
      title: t.book_language_action,
      description: t.book_language_description,
      current: current,
      // 书没有「自动值」可显示：dc:language 在导入时就直接写进了同一列，读回来
      // 分不清是自动回填的还是用户手动指定的。留空 = 只显示「自动」这一项本身。
      autoDetected: '',
      // 写完不刷新书架：语言不出现在卡片上，重建一遍纯属浪费。生效点在阅读器
      // 开书时读这一列建字体链。
      onSelected: (String? tag) => db.updateEpubBookLanguage(bookKey, tag),
    );
  }
}
