// GENERATED-NOTE: extracted from reader_fushi_history_page.dart (TODO-587).
part of '../reader_fushi_history_page.dart';

/// remote domain methods extracted via part-of (TODO-587); shared private scope.
extension _ReaderHistoryRemote on _ReaderFushiHistoryPageState {
  Future<RemoteBookClient?> _resolveRemoteBookClient() async {
    final Future<RemoteBookClient?> Function()? injected =
        _pageWidget.remoteBookClientLoader;
    if (injected != null) return injected();

    // Kitapsen 书店账号已登录时，书架远端区展示该账号已购的书（书店是本应用的
    // 书源本体，优先于互联与云备份）。未登录（未配置）才往下走互联 / 云。
    final KitapsenClient? kitapsen =
        await KitapsenClient.restore(appModel.database);
    if (kitapsen != null) return kitapsen;
    // Kitapsen: the store is the only remote library (no interconnect / cloud).
    return null;
  }

  Future<_RemoteBookState?> _loadRemoteBooks(
      {bool forceRefresh = false}) async {
    final RemoteBookClient? client = await _resolveRemoteBookClient();
    _remoteBookClient = client;
    _kitapsenSignedIn = client is KitapsenClient;
    if (client == null) {
      // 没有远端来源（如退出了 Kitapsen 账号）≠ 正在加载：清掉缓存的上次远端态，
      // 否则 build 的 waiting 兜底会继续显示已退出账号的占位卡。
      _lastRemoteState = null;
      return null;
    }
    try {
      // BUG-1180：经共享缓存取清单——切回书架 tab（[_onShellTabActivated]）不再必然
      // 打一轮网络，TTL 内直接复用；首页 dashboard 刚拉过的同一份列表也在这里命中。
      // 缓存只包住「问对端要清单」这一步，下面的本地库查询与去重仍每次照跑，所以本地
      // 新增/删除的书立即反映在混排网格里。
      // 槽 = 来源身份 + 域（BUG-1202）：互联对端与云盘书库都往 books 域写，共用一个
      // 槽会让「关掉互联开关 / 换云盘后端」之后 TTL 内看到上一个来源的书。
      final List<RemoteBookInfo> books = await _remoteCache.read(
        sourceId: client.remoteLibrarySourceId,
        key: RemoteLibraryCacheKeys.books,
        forceRefresh: forceRefresh,
        fetch: client.listRemoteBooks,
      );
      // #6: 远端与本地是同一本书时（同 bookKey）不在混排网格重复展示（只显示本地卡）。
      final List<EpubBookMeta> localBooks =
          await appModel.database.getEpubBookMetas();
      final Set<String> localKeys = <String>{
        ...localBooks.map((EpubBookMeta r) => r.bookKey),
        // Kitapsen：EPUB 内的书名可能与书店书名不同，按标题去重会漏；已下载的书
        // 按「书店 id → 本地 uid」映射认领。
        if (client is KitapsenClient)
          ...await client.downloadedTitleKeys(books),
      };
      // 书架只放可下载的书（hasContent）。
      final List<RemoteBookInfo> withContent = books.where((RemoteBookInfo book) => book.hasContent).toList();
      final List<RemoteBookInfo> shelfBooks = dedupeRemoteBooks(
        remote: withContent,
        localBookKeys: localKeys,
        keyOf: sanitizeTtuFilename,
      );
      _consumeKitapsenDownloadRequest(shelfBooks);
      return _RemoteBookState(books: shelfBooks);
    } catch (e) {
      // spec §2.4 离线语义：拉取失败 → 占位卡不出现（failed 门控），只剩本地库。
      debugPrint('[reader-shelf] remote book list failed: $e');
      return _RemoteBookState(
        books: const <RemoteBookInfo>[],
        failed: true,
      );
    }
  }

  /// Store › "Oku" on a book that is in the library but not on this device:
  /// the store tab names it in [kitapsenShelfDownloadRequest] and switches
  /// here (which reloads this list); the download starts once the list
  /// holding it has loaded.
  void _consumeKitapsenDownloadRequest(List<RemoteBookInfo> books) {
    final String? requested = kitapsenShelfDownloadRequest.value;
    if (requested == null) return;
    for (final RemoteBookInfo book in books) {
      if (book.bookKey != requested) continue;
      kitapsenShelfDownloadRequest.value = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_downloadRemoteBook(book));
      });
      return;
    }
  }

  /// 非强制的远端书重载：切回书架 tab（BUG-992）、本地书列表变动等「可能只是本地
  /// 变了」的信号走这里。远端清单本身经 [RemoteLibraryCache] 的 TTL 判断是否真要联网，
  /// 所以切页面不会再变成一轮网络往返（BUG-1180）。要**强制**穿透缓存只有一个入口：
  /// 用户显式下拉刷新（[_pullToRefreshBooks]）。
  void _refreshRemoteBooks() {
    _rebuild(() {
      _remoteBooksFuture = _loadRemoteBooks();
    });
  }

  /// 下拉刷新 = **手动同步**：先跑一遍同步，再强制重拉远端书列表（并失效本地书列表
  /// provider 一并重读），await 全程完成后指示器才收起。
  ///
  /// 顶层 tab 保活（[HomePage] 的 `_keepAliveTabs`）后，切回书架不再隐式重拉远端，
  /// 故给用户一个**显式**强制刷新入口——对端设备 / 云盘新增的书，不重启 app 也能刷出来。
  ///
  /// 同步必须排在重读列表**之前**：同步会往本地库里落新书和新进度，先刷列表就会漏掉
  /// 本次同步的产物，用户得再下拉一次才看得见。没配同步后端时
  /// [runManualSyncWithFeedback] 直接返回 notConfigured（且不弹提示），退化成纯列表
  /// 刷新——与加同步之前的行为一字不差。
  /// [_loadRemoteBooks] 内部吞异常返回 failed 态，await 不会抛，指示器必定收起；
  /// 失败态在 await 后消费成一条可见 SnackBar（BUG-1693 批审计 P1——此前
  /// `failed:true` 置了没人读，显式下拉失败与成功在 UI 上一模一样）。
  Future<void> _pullToRefreshBooks() async {
    if (!mounted) return;
    ref.invalidate(fushiBooksProvider);
    // 显式下拉 = 用户要最新的：强制穿透 [RemoteLibraryCache] 的 TTL（BUG-1180）。
    final Future<_RemoteBookState?> future = _loadRemoteBooks(
      forceRefresh: true,
    );
    _rebuild(() {
      _remoteBooksFuture = future;
      // 合集折叠映射也一并重载：下拉刷新前若后台同步落了新合集成员，只失效书列表
      // 而不重载 _shelfMapsFuture 会让新成员仍不成组（合集不渲染）。
      _shelfMapsFuture = _loadShelfMaps();
    });
    final _RemoteBookState? state = await future;
    if (!mounted) return;
    // 对齐视频侧 [_pullToRefresh]：显式刷新失败必须可见。只给一句本地化、可执行
    // 的友好提示；原始异常（TimeoutException / SocketException 等开发者文本）绝不
    // 进 UI，只留在 [_loadRemoteBooks] 的 debugPrint 供排查。
    if (state != null && state.anyFailed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.remote_book_list_failed)),
      );
    }
  }

  /// 多端库联合视图占位卡（spec 2026-07-12 §2.1）：正常书卡尺寸 + 远端封面 +
  /// 云角标 ☁（[_remoteBookCoverWithCloudBadge]），混排进书架主网格（[_ShelfBookSlot.remote]
  /// → [_buildShelfGroupCard] 散卡路径）。短按/下载按钮复用现有下载→入库链
  /// （[_downloadRemoteBook]），完成后原地变正常卡（下载后 dedup 去重隐藏占位）。
  ///
  /// [selectable]（默认 true）= 多选态可勾选（BUG-2458：勾选后经批量栏「下载」一起
  /// 下）；合集行成员卡传 false，与本地成员卡同规则。壳（[_bookCardShell]）在多选
  /// 态把点击接成勾选，只有非多选态点击才走下载。
  /// [focusIdPrefix]：合集详情页渲染路径传 'collection-detail-' 隔离焦点 id 命名
  /// 空间（BUG-1009——详情页 push 在书架之上，两条路由同时存活，同名 focusId 会被
  /// 焦点注册表按 id 覆盖）；书架路径恒空串（id 不变）。
  Widget _buildRemoteBookCard(RemoteBookInfo book,
      {bool selectable = true, String focusIdPrefix = ''}) {
    final String safeKey = _safeRemoteBookKey(book.title);
    return _bookCardShell(
      slotAspectRatio: kShelfBookCardAspectRatio,
      cardKey: ValueKey<String>('remote_book_card_$safeKey'),
      focusId:
          FushiFocusId('${focusIdPrefix}reader-shelf-remote-book-$safeKey'),
      selectionKey: selectable ? _remoteBookSelectionKey(book) : null,
      onTap: () => _downloadRemoteBook(book),
      // 短按仍直接下载（无本地副本不能直接读，下载合理）；长按 / 桌面右键
      // （_bookCardShell.onSecondaryTap 同绑 onLongPress）改弹选项面板，与本地
      // 书卡长按一致（TODO-768 / BUG-416）。
      onLongPress: () => _showRemoteBookDialog(book),
      child: _bookCardLayout(
        // BUG-1488：上屏名走 host 下发的显示名（host 改过名即用改后的），身份键
        // （safeKey / _downloadingBooks / downloadId）仍恒用 raw title。
        title: book.displayName,
        cover: _remoteBookCoverWithCloudBadge(book, safeKey),
        // TODO-655a：远端书卡右上角是下载按钮 / 下载进度，类型徽章（有声书耳机 /
        // 普通书本）放左上角，与本地书卡（buildMediaItemContent）的类型语义一致。
        // 多选态左上角被壳的勾选框占用（同位同尺寸），可勾选时让位不画。
        leadingBadge: _selectionMode && selectable
            ? null
            : _buildRemoteBookTypeBadge(book, safeKey),
        coverBadge: _remoteBookTaskBadge(
              taskId: RemoteBookDownloadManager.bookTaskId(book.downloadId),
              safeKey: safeKey,
              keyPrefix: 'remote_book',
            ) ??
            IconButton.filledTonal(
              key: ValueKey<String>('remote_book_download_$safeKey'),
              tooltip: t.remote_book_download,
              iconSize: 18,
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.download_outlined),
              // 多选态卡内子按钮叠在壳 InkWell 之上、不经 handleTap；置空让点击
              // 穿到壳走勾选，否则点到右上角仍是「没勾选直接下载」（审查 #1）。
              onPressed: _selectionMode && selectable
                  ? null
                  : () => _downloadRemoteBook(book),
            ),
      ),
    );
  }

  /// BUG-2458：批量栏「下载」——把选中的远端占位卡逐个交给既有单本下载链
  /// （[_downloadRemoteBook]，任务归 [RemoteBookDownloadManager] 所有、与本页生命周期无关），先退出
  /// 多选态；进度 / 失败落在各卡角标上（[_remoteBookTaskBadge]）。
  ///
  /// 选中键只是身份，占位对象要回到最近一次远端目录里找：目录已刷新、该书已
  /// 下载入库被去重隐藏的键自然找不到，跳过即可。
  ///
  /// **串行**：管理器只按 id 去重、无并发上限，「全选 → 下载」若一帧内扇出 N 个
  /// 并行 HTTP + N 个并行导入落库，对手机端互联 host 是真实压力；逐本 await
  /// 让批量与用户逐张点的节奏等价。服务不可达在进循环前判一次，只提示一次
  /// （单本路径每次各弹一条）。
  Future<void> _batchDownloadSelectedRemote() async {
    final Set<String> keys = _selectedRemoteKeys;
    if (keys.isEmpty) return;
    final _RemoteBookState? state = _lastRemoteState;
    _exitSelectionMode();
    if (state == null) return;
    if (_remoteBookClient == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.remote_book_unavailable)),
      );
      return;
    }
    // 页面卸载后停止派发：已起的任务归管理器继续跑到底，未起的不再用已 dispose
    // 的 ref 去起。
    for (final RemoteBookInfo book in state.books) {
      if (!keys.contains(_remoteBookSelectionKey(book))) continue;
      if (!mounted) return;
      await _downloadRemoteBook(book);
    }
  }

  /// 远端占位卡右上角的下载态角标（BUG-1561 书侧补齐）：进行中 → 进度环，失败 →
  /// 失败角标（tooltip 带 [RemoteBookDownloadManager] 存的本地化失败原因），
  /// 其余（无任务 / 已完成）→ null，调用方回落成下载按钮。
  ///
  /// 下载任务的所有者是 app 级管理器、与本页生命周期无关；失败态此前**只**通过
  /// 下载方法里的 SnackBar 出现，页面已 dispose 时被 `if (!mounted) return;` 吃掉
  /// → 用户永远不知道下载挂了。角标让失败态落在卡片上，重进页面照样看得到；
  /// 再点一次下载即重试（新任务顶掉旧失败态）。与视频侧
  /// `_remoteDownloadBadge`（home_video_page.dart）同范式。
  Widget? _remoteBookTaskBadge({
    required String taskId,
    required String safeKey,
    required String keyPrefix,
  }) {
    final RemoteBookDownloadTask? task =
        ref.watch(remoteBookDownloadManagerProvider).taskFor(taskId);
    if (task == null) return null;
    switch (task.status) {
      case RemoteBookDownloadStatus.running:
        return RemoteDownloadProgressBadge(
          key: ValueKey<String>('${keyPrefix}_downloading_$safeKey'),
          progress: task.progress,
          tooltip: t.remote_book_downloading,
        );
      case RemoteBookDownloadStatus.failed:
        return RemoteDownloadFailedBadge(
          key: ValueKey<String>('${keyPrefix}_download_failed_$safeKey'),
          tooltip: task.error == null || task.error!.isEmpty
              ? t.remote_book_download_failed
              : '${t.remote_book_download_failed}: ${task.error}',
        );
      case RemoteBookDownloadStatus.completed:
        return null;
    }
  }

  /// 长按 / 桌面右键远端书卡：弹出与本地书卡一致的封面背景动作面板
  /// （[MediaItemDialogFrame] 复用，不重写），列出可对该远端书执行的动作。
  ///
  /// 动作：
  /// * 「下载」→ 复用 [_downloadRemoteBook]（与短按、封面下载按钮同一入口，
  ///   内部已对重复下载去重）。
  void _showRemoteBookDialog(RemoteBookInfo book) {
    showAppDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => MediaItemDialogFrame(
        cover: _buildRemoteBookCover(book),
        title: book.displayName,
        showLaunchAction: false,
        quickActions: <DialogQuickAction>[
          DialogQuickAction(
            label: t.remote_book_download,
            icon: Icons.download_outlined,
            onPressed: () {
              Navigator.pop(dialogContext);
              _downloadRemoteBook(book);
            },
          ),
        ],
        dangerActions: const <DialogDangerAction>[],
      ),
    );
  }

  /// 远端书卡左上角类型徽章：普通书本徽章（与本地 _cardBadge 一致），带稳定 key。
  Widget _buildRemoteBookTypeBadge(RemoteBookInfo book, String safeKey) {
    final ColorScheme cs = theme.colorScheme;
    final Widget badge = (_cardBadge(
            icon: Icons.menu_book_outlined,
            background: cs.surfaceContainerHighest,
            foreground: cs.onSurfaceVariant,
          ));
    return KeyedSubtree(
      key: ValueKey<String>('remote_book_type_badge_$safeKey'),
      child: badge,
    );
  }

  /// 远端封面 + 云角标 ☁（spec §2.1）：封面右上角是下载按钮/进度徽章、左上角是类型
  /// 徽章，故云角标叠在**左下角**（互不遮挡）。带稳定 key 供 widget 测试定位占位卡。
  Widget _remoteBookCoverWithCloudBadge(RemoteBookInfo book, String safeKey) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        _buildRemoteBookCover(book),
        PositionedDirectional(
          bottom: 6,
          start: 6,
          child: _remoteCloudBadge(
            key: ValueKey<String>('remote_book_cloud_badge_$safeKey'),
          ),
        ),
      ],
    );
  }

  Widget _buildRemoteBookCover(RemoteBookInfo book) {
    final String safeKey = _safeRemoteBookKey(book.title);
    final String? coverUrl = book.coverUrl;
    // TODO-1235（TODO-961 回归）：封面走互联同款钉扎客户端拉取，不再用 Image.network
    // （Flutter 内部 HttpClient 无 badCertificateCallback，https 自签握手必失败）。
    final RemoteCoverFetcher? fetcher =
        remoteCoverFetcherFor(_remoteBookClient);
    if (coverUrl != null && coverUrl.isNotEmpty && fetcher != null) {
      return Image(
        // BUG-847：按稳定书 identifier（title）磁盘缓存，冷启动/滚动不重下。
        image: RemoteCoverImage(coverUrl, fetcher, cacheKey: book.title),
        key: ValueKey<String>('remote_book_cover_$safeKey'),
        alignment: Alignment.topCenter,
        fit: _bookCardCoverFit,
        errorBuilder: (_, __, ___) =>
            _coverPlaceholderIcon(Icons.menu_book_outlined),
      );
    }
    return _coverPlaceholderIcon(Icons.menu_book_outlined);
  }

  /// 下载远端书。任务本体挂在 app 级 [RemoteBookDownloadManager]（BUG-1561
  /// 视频侧范式的书侧补齐）：下载/导入全程与本页生命周期无关，切 tab / 退页后
  /// 照样推进到底；失败态存在管理器里，由占位卡上的失败角标
  /// （[_remoteBookTaskBadge]）恒定可见，不再只靠会被 `!mounted` 吃掉的 SnackBar。
  Future<void> _downloadRemoteBook(RemoteBookInfo book) async {
    final RemoteBookClient? client = _remoteBookClient;
    // #3: 服务不可达 / 未鉴权时给明确提示，不再静默 return（用户点了像没反应）。
    if (client == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.remote_book_unavailable)),
      );
      return;
    }
    final RemoteBookDownloadManager manager =
        ref.read(remoteBookDownloadManagerProvider);
    // 同一本书已在下载中：忽略重复点击（卡片 tap/长按/按钮都指向这里；管理器
    // 自身也对同键 running 任务去重）。
    if (manager
        .isRunning(RemoteBookDownloadManager.bookTaskId(book.downloadId))) {
      return;
    }
    final File dest = await _remoteBookDestination(book);
    try {
      await manager.startBookDownload(
        downloadId: book.downloadId,
        title: book.displayName,
        dest: dest,
        run: (File target, {void Function(double progress)? onProgress}) =>
            _runRemoteBookDownload(book, client, target,
                onProgress: onProgress),
      );
    } catch (e, stack) {
      ErrorLogService.instance
          .log('ReaderFushiHistoryPage.downloadRemoteBook', e, stack);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.remote_book_download_failed)),
      );
      return;
    }
    if (!mounted) return;
    ref.invalidate(fushiBooksProvider);
    _refreshRemoteBooks();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(t.remote_book_downloaded)),
    );
  }

  /// 远端书下载任务本体（在 [RemoteBookDownloadManager] 的任务里跑，**不得
  /// 依赖本页存活**）：拉书 → 导入落库 → 回填显示名 / 进度。DB 写入经 [appModel]
  /// （dispose 后回落缓存实例，见 base_page.dart），与页面生命周期无关。
  Future<void> _runRemoteBookDownload(
    RemoteBookInfo book,
    RemoteBookClient client,
    File dest, {
    void Function(double progress)? onProgress,
  }) async {
    try {
      await client.getRemoteBook(
        book.downloadId,
        dest,
        onProgress: (double progress) {
          onProgress?.call(progress);
        },
      );
      // 已经落地的书必须复用实际行。
      final EpubBookRow? existingBook =
          await appModel.database.getEpubBook(book.downloadId);
      final bool hasExistingContent = existingBook != null &&
          (resolveExtractedEpubRoot(existingBook.extractDir) != null);
      final String? localBookKey = (hasExistingContent ? existingBook.bookKey : null) ??
          await _importRemoteBookFile(dest, titleHint: book.title);
      if (localBookKey != null) {
        // 记下书店 id ↔ 本地书，供进度同步与书架去重（在下面的进度回填之前）。
        if (client is KitapsenClient) {
          await client.recordDownloaded(book, localBookKey);
        }
      }
      // BUG-1488：把书店书名一并落成本地 override，否则下载后的本地卡又变回原始
      // 书名（本地书的显示名只认 override 偏好，raw title 来自 EPUB 元数据）。
      await _adoptRemoteBookDisplayTitle(book, localBookKey);
      // BUG-813：把该书的阅读进度一并拉回本地，下载远端书时不再丢「阅读记录」。
      await _downloadRemoteBookProgress(book, client, localBookKey);
    } finally {
      // A Kitapsen store EPUB is licensed to this app only: once imported (or
      // on failure) the downloaded file must not linger in the temp folder.
      try {
        if (await dest.exists()) await dest.delete();
      } on FileSystemException catch (e, stack) {
        ErrorLogService.instance
            .log('ReaderFushiHistoryPage.deleteKitapsenDownload', e, stack);
      }
    }
  }

  /// EPUB 导入成功后，把 host 端用户改过的书名落成本地 override（BUG-1488）。
  ///
  /// 本地书的显示名唯一来源是 `override_title://` 偏好；下载落库的 raw title 来自
  /// EPUB 元数据（还可能因同名冲突加了 `(2)` 后缀），所以不落 override 的话，母
  /// 设备改的名字在子设备上永远看不到。
  ///
  /// 裁决走 last-write-wins（BUG-1502）：host 的改名戳（`displayTitleAt`）严格晚于
  /// 本机这行的戳才覆盖，平局保留本机，本机没有 override 则无条件采纳。所以 host
  /// 的**第二次**改名也能落到「本机也改过名」的这台设备上，而旧 host（不带时刻 →
  /// 0）退化成原来的 insert-if-absent，绝不覆盖本机用户刚改的名字。
  /// host 没改过名（[RemoteBookInfo.displayTitle] 为 null）时是纯 no-op。
  Future<void> _adoptRemoteBookDisplayTitle(
    RemoteBookInfo book,
    String? localBookKey,
  ) async {
    final String? remoteTitle = book.displayTitle;
    if (localBookKey == null || remoteTitle == null || remoteTitle.isEmpty) {
      return;
    }
    try {
      final ReaderFushiSource source = ReaderFushiSource.instance;
      await source.adoptOverrideTitleIfNewer(
        item: source.overrideTitleMediaItemForBookKey(localBookKey),
        title: remoteTitle,
        updatedAt: book.displayTitleAt,
      );
    } catch (e, stack) {
      ErrorLogService.instance
          .log('ReaderFushiHistoryPage.adoptRemoteBookDisplayTitle', e, stack);
    }
  }

  /// EPUB 导入成功后，把该书在 host 端的**阅读进度**（reader_positions）与**有声书
  /// 播放断点**（prefs）拉回本地（BUG-813）。此前进度双向同步只在整库「立即同步」
  /// sweep 里对**已在本地**的书跑（[SyncOrchestrator._syncBookProgressLive] /
  /// `_syncAudiobookPositionLive`），手动下载动作本身零回填 → 下到的书「没有阅读记录」。
  ///
  /// 契约与 sweep 同源：用 host 端真实 key [RemoteBookInfo.downloadId] 拉取，写本地用
  /// 刚导入的 [localBookKey]（标题派生 key 可能漂移，BUG-414）。live progress API 仅
  /// 存在于互联后端；云盘后端跳过（真实能力边界）。新下载的书本地无既有进度，host
  /// 侧有记录（updatedAtMs>0）即直接落库。书进度与有声书断点各自 try/catch 吞错，
  /// 绝不阻断主下载。
  Future<void> _downloadRemoteBookProgress(
    RemoteBookInfo book,
    RemoteBookClient client,
    String? localBookKey,
  ) async {
    if (localBookKey == null) return;

    // 书阅读进度 → reader_positions（新书本地无行，host 有记录即落）。
    // `remoteBookProgress` 是 [RemoteBookClient] 接口方法（互联 + 云盘后端都实现），
    // 故不按后端类型门控——两种远端来源下载都能带回阅读进度。
    try {
      final RemoteBookProgress remote =
          await client.remoteBookProgress(book.downloadId);
      // v82：子表键 = 书 uid。刚导入的书必有行，反查不到（异常路径）直接跳过。
      final String? localUid =
          await appModel.database.resolveEpubBookUid(localBookKey);
      if (remote.updatedAtMs > 0 && localUid != null) {
        await appModel.database.upsertReaderPosition(ReaderPositionsCompanion(
          bookUid: Value(localUid),
          sectionIndex: Value(remote.sectionIndex),
          normCharOffset: Value(remote.normCharOffset),
          charOffset: Value(remote.charOffset),
          updatedAt: Value(remote.updatedAtMs),
        ));
      }
    } catch (e, stack) {
      ErrorLogService.instance
          .log('ReaderFushiHistoryPage.downloadRemoteBookProgress', e, stack);
    }

  }

  Future<File> _remoteBookDestination(RemoteBookInfo book) async {
    final Directory temp = await getTemporaryDirectory();
    final Directory dir = Directory(p.join(temp.path, 'remote_books'));
    await dir.create(recursive: true);
    return File(p.join(dir.path, '${_safeRemoteBookKey(book.title)}.epub'));
  }

  /// 导入下载到本地的 EPUB，返回本地入库的 bookKey（= `sanitizeTtuFilename`
  /// 后的存储标题，可能因同名冲突重命名而与远端书名派生 key 不同）。注入的测试
  /// importer 不返回 key 时返回 null（音频接线据此降级跳过 override 绑定）。
  Future<String?> _importRemoteBookFile(File file,
      {String? titleHint}) async {
    // A Kitapsen book without an EPUB arrives as its PDF.
    if (await _isPdfFile(file)) {
      return PdfImporter.importFromPath(
        db: appModel.database,
        filePath: file.path,
        fileName: p.setExtension(p.basename(file.path), '.pdf'),
        title: titleHint ?? p.basenameWithoutExtension(file.path),
      );
    }
    return EpubImporter.importFromPath(
      db: appModel.database,
      filePath: file.path,
      fileName: p.basename(file.path),
    );
  }

  Future<bool> _isPdfFile(File file) async {
    final RandomAccessFile raf = await file.open();
    try {
      return String.fromCharCodes(await raf.read(5)) == '%PDF-';
    } finally {
      await raf.close();
    }
  }

  String _safeRemoteBookKey(String title) =>
      sanitizeTtuFilename(title).replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');

  /// 云角标 ☁：共享 [CoverBadge]（PR-0 收口的封面角标胶囊，统一各处手抄的
  /// alpha/圆角/eink 实底）。多端库联合视图占位卡的「远端 / 未下载」标识（spec §2.1）。
  Widget _remoteCloudBadge({Key? key}) {
    return CoverBadge(key: key, icon: Icons.cloud_outlined, iconSize: 13);
  }
}

class _RemoteBookState {
  const _RemoteBookState({
    required this.books,
    this.failed = false,
  });

  final List<RemoteBookInfo> books;

  /// 远端目录拉取失败（离线/未配对/后端不可达）：占位卡不渲染（spec §2.4）。
  final bool failed;

  /// 远端清单拉取失败——下拉刷新失败提示的口径。
  bool get anyFailed => failed;
}
