import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import 'package:fushi_reading/fushi_reading.dart';
import 'package:fushi_core/fushi_core.dart';
import 'package:fushi/src/epub/book_file_location.dart';
import 'package:fushi/src/pages/base_source_page.dart';
import 'package:fushi/src/pdf/pdf_engine.dart';
import 'package:fushi/src/startup/exit_flush_registry.dart';
import 'package:fushi/src/stats/read_unit_ledger.dart';
import 'package:fushi/utils.dart';
import 'package:fushi/src/media/reader_exit_flush.dart';

/// PDF 阅读器页面（Phase 1 渲染 / Phase 2 点选查词 / Phase 3 页码进度 / Phase 4 制卡）。
///
/// 与 EPUB 的 [ReaderFushiPage] 平行：那边是 WebView + JS 选区 + 章内字符偏移，这边是
/// pdfrx（PDFium）+ 字符级 `charRects` + **页码**。两者最终汇到同一批共享设施：
/// [BaseSourcePageState.searchDictionaryResult]（查词弹窗/朗读）、[ReaderPositionRepository]
/// （阅读位置）、[StudyClock]（时长统计）、[AnkiMiningContext]（制卡）。
///
/// PDF 绝对路径由 `EpubBooks` 行经 `bookMainFilePath` 还原（唯一真相源，不自拼）。
class ReaderPdfPage extends BaseSourcePage {
  const ReaderPdfPage({
    super.key,
    required super.item,
    required this.bookKey,
  });

  final String bookKey;

  @override
  BaseSourcePageState<ReaderPdfPage> createState() => _ReaderPdfPageState();
}

class _ReaderPdfPageState extends BaseSourcePageState<ReaderPdfPage>
    with WidgetsBindingObserver {
  final PdfViewerController _pdfController = PdfViewerController();

  late final Future<_PdfBookLoad?> _loadFuture = _load();

  /// 打开时读回的书行（标题/总页数）与已保存页码，供恢复与进度落库使用。
  EpubBookRow? _bookRow;

  /// v82：位置/书签子表键（= [_bookRow] 的 `uid`，_load 时一次解析）。null =
  /// 书行缺失或旧行无 uid——相关读写跳过，不拿 bookKey 兜底写孤儿行。
  String? _bookUid;
  int _restorePageIndex = 0;

  /// 当前页（0-based）。pdfrx 的 `pageNumber` 是 1-based，落库统一 0-based
  /// （与 `ReaderPositions.sectionIndex` 的 EPUB 章 index 口径一致）。
  int _currentPageIndex = 0;
  int _lastSavedPageIndex = -1;

  /// 「读过」判据的唯一账本（2026-09-06 裁定，三域共用，见
  /// `docs/plans/2026-09-06-read-unit-ledger.md`）：**翻走即计 + 会话覆盖并集**。
  /// 单元 = 页号半开区间 `[page, page+1)`；离开一页那一刻把它（若本会话未覆盖）
  /// 记进时钟当前段的页数。跳 N 页只计跳走前那页、跳过的从未成为当前单元；往回翻 /
  /// 回到已读页并集已覆盖 → 0；无存档预置（续读时存档页是当前单元，翻走计一次）。
  /// 此前是标量水位 `_sessionMaxPageIndex`（BUG-2222：跳 N 页计 N 页），已废。
  late final ReadUnitLedger _readLedger = ReadUnitLedger(
    onCredit: (List<(int, int)> fresh) =>
        _studyClock?.addPages(readUnitsLength(fresh)),
    onRetract: (List<(int, int)> retracted) =>
        _studyClock?.retractPages(readUnitsLength(retracted)),
  );
  Timer? _saveDebounce;
  bool _restoreDone = false;

  /// v92：本页唯一的阅读时钟兼累计器（同 EPUB 侧 `_studyClock`）。页面不再持有
  /// 任何会话时长字段——旧的 `_sessionReadingMs` / `_sessionStartTime` 形态整个消失。
  StudyClock? _studyClock;

  /// PDF 自带目录（outline），懒加载一次；空列表 = 已加载但该 PDF 无目录。
  List<PdfOutlineNode>? _outline;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 进程退出兜底：把未落盘的页码 + 学习段 flush 掉（与 EPUB 阅读器同纪律）。
    ExitFlushRegistry.instance.register(_flushForExit);
  }

  @override
  void dispose() {
    ExitFlushRegistry.instance.unregister(_flushForExit);
    WidgetsBinding.instance.removeObserver(this);
    _saveDebounce?.cancel();
    // 崩溃 / 异常拆栈的兜底（正常退出走 onSourcePagePop 的 await 路径）：dispose
    // 是同步的，这里**一笔 DB 写都不许发起**——无人 await 的事务与随后的
    // `db.close()` 互等。关书不是翻走：站着的那页不结算（`ReadUnitLedger` 类文档），
    // detach 只停表，攒下的写和最后的位置一起交给退出汇合点统一 await。
    // 时钟为空 = 本页从没开始计时，整段跳过。
    _studyClock?.detach();
    ExitFlushRegistry.instance.defer(_flushPosition);
    super.dispose();
  }

  /// 进程退出 / 退后台的统一 flush（[ExitFlushRegistry]）：只落位置。退出不是翻走，
  /// 站着的那页不结算（`ReadUnitLedger` 类文档）；学习段由时钟 stop / detach 写穿。
  Future<void> _flushForExit() async {
    await _flushPosition();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // 切屏 / 进后台自动暂停阅读计时（BUG-892）：stop 先结算失焦瞬间的部分窗口再
      // 封段落库；顺序同 EPUB 侧。
      unawaited(_studyClock?.stop());
      unawaited(_flushPosition());
    } else if (state == AppLifecycleState.resumed) {
      // BUG-892 / BUG-1052: 后台那段靠「时钟停着」丢弃，不再重锚墙钟基准。
      _studyClock?.start();
    }
  }

  @override
  Future<void> onSourcePagePop() async {
    // 关书不是翻走：站着的那页不结算（`ReadUnitLedger` 类文档），只落盘 + 停表。
    // 返回书架的正常路径：await 落盘，保证书架 recency/进度立刻正确。
    await _flushPosition();
    await _studyClock?.stop();
  }

  // ── 加载 / 恢复 ───────────────────────────────────────────────────────

  Future<_PdfBookLoad?> _load() async {
    await PdfEngine.ensureInitialized();
    final FushiDatabase db = appModel.database;
    final EpubBookRow? row = await db.getEpubBook(widget.bookKey);
    if (row == null) return null;
    final String path = bookMainFilePath(row);
    if (!File(path).existsSync()) return null;

    _bookRow = row;
    // v82：位置/书签键 = EpubBooks.uid（行在手直接取；空 uid 视同缺失，读写跳过）。
    _bookUid = row.uid.isEmpty ? null : row.uid;

    // 读回已保存页码（sectionIndex = 0-based 页）。越界守卫按总页数。
    final ReaderPosition? saved = _bookUid == null
        ? null
        : await ReaderPositionRepository(db).findByBookUid(_bookUid!);
    if (saved != null &&
        saved.sectionIndex >= 0 &&
        saved.sectionIndex < row.chapterCount) {
      _restorePageIndex = saved.sectionIndex;
      _currentPageIndex = saved.sectionIndex;
      _lastSavedPageIndex = saved.sectionIndex;
    }

    // v92：唯一时钟（同 EPUB 侧）；空闲门 + 生命周期前台门只对阅读面生效。
    _studyClock ??= StudyClock(
      database: db,
      mediaKind: kActivityMediaBook,
      mediaKey: widget.bookKey,
      title: row.title,
      format: BookFormat.pdf.dbValue,
      idleTimeout: appModel.readingIdleTimeout,
      onWriteError: (Object e, StackTrace st) =>
          ErrorLogService.instance.log('StudyClock.write(pdf)', e, st),
      deferWrite: ExitFlushRegistry.instance.defer,
    );
    _studyClock!.start();
    return _PdfBookLoad(path: path, row: row);
  }

  void _onViewerReady() {
    if (_restoreDone) return;
    _restoreDone = true;
    if (_restorePageIndex <= 0) return;
    // pdfrx 页码是 1-based。
    unawaited(_pdfController.goToPage(pageNumber: _restorePageIndex + 1));
  }

  // ── 页码进度 ──────────────────────────────────────────────────────────

  void _onPageChanged(int? pageNumber) {
    if (pageNumber == null) return;
    final int pageIndex = pageNumber - 1;
    if (pageIndex < 0) return;
    // v92 阅读空闲门：翻页 = 用户输入。
    _studyClock?.touch();
    // 翻走即计：到达新页 = 离开上一页，账本结算上一页（首次覆盖才 addPages，与时长
    // 同段同 uid）；本页要等下次翻走才计。
    _readLedger.arrive(pageIndex, pageIndex + 1);
    _currentPageIndex = pageIndex;
    // 500ms debounce（与 EPUB 阅读器同口径）：连续翻页只落最后一次。
    if (pageIndex == _lastSavedPageIndex) return;
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 500), () {
      unawaited(_persistPosition(pageIndex));
    });
  }

  Future<void> _persistPosition(int pageIndex) async {
    _lastSavedPageIndex = pageIndex;
    final FushiDatabase db = appModel.database;
    // v82：uid 缺失时只跳过位置写入（不拿 bookKey 兜底造孤儿行）；下方「已读完」
    // 标记走 bookKey 键的 epub_books 表，照常执行。
    final String? bookUid = _bookUid;
    if (bookUid != null) {
      try {
        await ReaderPositionRepository(db).save(
          bookUid: bookUid,
          sectionIndex: pageIndex,
          normCharOffset: 0,
          // PDF 无章内字符偏移。**必须显式传值**（传 null 会掉进 EPUB 专用的
          // 「跨 section 精确锚失效」启发式）。
          charOffset: 0,
        );
      } catch (e, stack) {
        ErrorLogService.instance
            .log('ReaderPdfPage._persistPosition', e, stack);
      }
    }
    // 翻到最后一页 → 幂等写「已读完」（判据用总页数，PDF 无 chapters）。
    final int pageCount = _bookRow?.chapterCount ?? 0;
    if (pageCount > 0 && pageIndex >= pageCount - 1) {
      try {
        await db.markEpubBookCompletedIfUnset(widget.bookKey, DateTime.now());
      } catch (e, stack) {
        ErrorLogService.instance.log('ReaderPdfPage.markCompleted', e, stack);
      }
    }
  }

  Future<void> _flushPosition() async {
    _saveDebounce?.cancel();
    if (_bookRow == null) return;
    if (_currentPageIndex != _lastSavedPageIndex) {
      await _persistPosition(_currentPageIndex);
    }
    await _flushReadingStats();
  }

  /// 把「上一次 tick 到现在」的部分窗口结算并落库（不停表）。PDF 无字数，时钟只记
  /// 时长；「页数」绝不塞进字数口径。
  Future<void> _flushReadingStats() async {
    await _studyClock?.flushNow();
  }

  // ── Phase 2：点选查词 ─────────────────────────────────────────────────

  // ── Phase 5：书签（复用 EPUB 的 Bookmarks 表）───────────────────────

  /// 在当前页加书签。PDF 复用同一张 `Bookmarks` 表：`sectionIndex` 存 0-based 页码
  /// （与 [ReaderPositions] 同口径），`normCharOffset` 恒 0。键 = 书 uid（v82），
  /// PDF 行已在 `EpubBooks`，删书时由 `deleteEpubBook` 显式级联清掉，零额外接线。
  Future<void> _addBookmarkAtCurrentPage() async {
    final EpubBookRow? row = _bookRow;
    final String? bookUid = _bookUid;
    if (row == null || bookUid == null) return;
    try {
      await BookmarkRepository(appModel.database).addBookmark(
        bookUid,
        Bookmark(
          sectionIndex: _currentPageIndex,
          normCharOffset: 0,
          // 标签用页序（1-based，与页码指示器一致）；纯数字免 i18n。
          label: 'P.${_currentPageIndex + 1}',
          createdAt: DateTime.now(),
          bookUid: bookUid,
          bookTitle: row.title,
        ),
      );
      if (!mounted) return;
      FushiToast.show(
          msg: t.pdf_bookmark_added, severity: ToastSeverity.success);
    } catch (e, stack) {
      ErrorLogService.instance.log('ReaderPdfPage.addBookmark', e, stack);
    }
  }

  Future<void> _showBookmarks() async {
    final String? bookUid = _bookUid;
    if (bookUid == null) return;
    List<Bookmark> bookmarks;
    try {
      // legacyBookKey：`bookmarks_<bookKey>` 遗留偏好一次性迁进 DB（键换 uid）。
      bookmarks = await BookmarkRepository(appModel.database)
          .getBookmarks(bookUid, legacyBookKey: widget.bookKey);
    } catch (e, stack) {
      ErrorLogService.instance.log('ReaderPdfPage.getBookmarks', e, stack);
      return;
    }
    if (!mounted) return;
    if (bookmarks.isEmpty) {
      FushiToast.show(msg: t.pdf_bookmarks_empty, severity: ToastSeverity.info);
      return;
    }
    await showAppDialog<void>(
      context: context,
      builder: (BuildContext context) => _PdfBookmarkSheet(
        bookmarks: bookmarks,
        onSelect: (Bookmark bookmark) {
          Navigator.of(context).pop();
          unawaited(
            _pdfController.goToPage(pageNumber: bookmark.sectionIndex + 1),
          );
        },
        onDelete: (Bookmark bookmark) async {
          final int? id = bookmark.id;
          if (id == null) return;
          try {
            await BookmarkRepository(appModel.database).removeBookmarkById(id);
          } catch (e, stack) {
            ErrorLogService.instance
                .log('ReaderPdfPage.removeBookmark', e, stack);
          }
        },
      ),
    );
  }

  // ── Phase 5：目录（PDF outline）导航 ──────────────────────────────────

  /// 打开 PDF 自带目录（outline / bookmarks）。懒加载：只在用户点开时解析一次。
  Future<void> _showOutline() async {
    if (!_pdfController.isReady) return;
    List<PdfOutlineNode> outline = _outline ?? const <PdfOutlineNode>[];
    if (_outline == null) {
      try {
        outline = await _pdfController.document.loadOutline();
        _outline = outline;
      } catch (e, stack) {
        ErrorLogService.instance.log('ReaderPdfPage.loadOutline', e, stack);
        _outline = const <PdfOutlineNode>[];
        outline = _outline!;
      }
    }
    if (!mounted) return;
    if (outline.isEmpty) {
      FushiToast.show(msg: t.pdf_outline_empty, severity: ToastSeverity.info);
      return;
    }
    await showAppDialog<void>(
      context: context,
      builder: (BuildContext context) => _PdfOutlineSheet(
        nodes: outline,
        onSelect: (PdfOutlineNode node) {
          Navigator.of(context).pop();
          if (node.dest != null) {
            unawaited(_pdfController.goToDest(node.dest));
          }
        },
      ),
    );
  }

  // ── Phase 4：制卡 ─────────────────────────────────────────────────────

  // ── UI ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final String title = widget.item?.title ?? _bookRow?.title ?? '';
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (didPop) return;
        // 与外部导航收页（closeActive）/ 连按返回共用单飞门，退出只跑一遍。
        if (!claimSourceExit()) return;
        final NavigatorState navigator = Navigator.of(context);
        // BUG-2119 口径（视频页 / 阅读器同此）：**退出不等落库**。onWillPop 是位置
        // flush + closeMedia 两笔 drift 写，一条 SQLITE_BUSY 后未 reset 的写语句能让
        // 整条连接上每次 COMMIT 都抛错（2026-09-04 真机），旧写法 `await onWillPop()`
        // 一挂住，navigator.pop() 就永远到不了——AppBar 的返回键与被 `canPop: false`
        // 掐掉的侧滑走的是同一条链，iOS 上按了没反应就等于出不去。
        exitAfterPersist(
          persist: onWillPop,
          exit: () => navigator.pop(),
          onPersistError: (Object error, StackTrace stack) =>
              ErrorLogService.instance.log('ReaderPdf.exitFlush', error, stack),
        );
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
          actions: <Widget>[
            _buildPageIndicator(),
            IconButton(
              tooltip: t.pdf_bookmarks,
              icon: const Icon(Icons.bookmark_add_outlined),
              onPressed: () => unawaited(_addBookmarkAtCurrentPage()),
            ),
            IconButton(
              tooltip: t.pdf_bookmarks,
              icon: const Icon(Icons.bookmarks_outlined),
              onPressed: () => unawaited(_showBookmarks()),
            ),
            IconButton(
              tooltip: t.pdf_outline,
              icon: const Icon(Icons.list_alt_outlined),
              onPressed: () => unawaited(_showOutline()),
            ),
          ],
        ),
        body: _buildViewer(),
      ),
    );
  }

  /// 页码指示器「12 / 345」。纯数字，无需 i18n。
  Widget _buildPageIndicator() {
    return AnimatedBuilder(
      animation: _pdfController,
      builder: (BuildContext context, Widget? child) {
        if (!_pdfController.isReady) return const SizedBox.shrink();
        final int? page = _pdfController.pageNumber;
        if (page == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Center(
            child: Text(
              '$page / ${_pdfController.pageCount}',
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
        );
      },
    );
  }

  Widget _buildViewer() {
    return FutureBuilder<_PdfBookLoad?>(
      future: _loadFuture,
      builder: (BuildContext context, AsyncSnapshot<_PdfBookLoad?> snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return buildLoading();
        }
        final _PdfBookLoad? load = snapshot.data;
        if (load == null) {
          return Center(child: Text(t.book_file_not_found));
        }
        return PdfViewer.file(
          load.path,
          controller: _pdfController,
          params: PdfViewerParams(
            backgroundColor: const Color(0xFF3A3A3A),
            onViewerReady: (_, __) => _onViewerReady(),
            onPageChanged: _onPageChanged,
            // 单击正文即查词；返回 true 吃掉 tap，阻止 pdfrx 默认清选区行为。
            onGeneralTap: (
              BuildContext context,
              PdfViewerController controller,
              PdfViewerGeneralTapHandlerDetails details,
            ) {
              // Kitapsen has no dictionary: taps keep pdfrx's own behaviour.
              return false;
            },
          ),
        );
      },
    );
  }
}

/// [_ReaderPdfPageState._load] 的结果：PDF 磁盘路径 + 其 `EpubBooks` 行。
class _PdfBookLoad {
  const _PdfBookLoad({required this.path, required this.row});

  final String path;
  final EpubBookRow row;
}

/// PDF 书签弹层：列出本书书签（按创建时间倒序），点击跳页、删除即时从列表移除。
class _PdfBookmarkSheet extends StatefulWidget {
  const _PdfBookmarkSheet({
    required this.bookmarks,
    required this.onSelect,
    required this.onDelete,
  });

  final List<Bookmark> bookmarks;
  final void Function(Bookmark bookmark) onSelect;
  final Future<void> Function(Bookmark bookmark) onDelete;

  @override
  State<_PdfBookmarkSheet> createState() => _PdfBookmarkSheetState();
}

class _PdfBookmarkSheetState extends State<_PdfBookmarkSheet> {
  late final List<Bookmark> _items = List<Bookmark>.of(widget.bookmarks);

  @override
  Widget build(BuildContext context) {
    return FushiDialogFrame(
      maxWidth: 520,
      maxHeightFactor: 0.82,
      scrollable: false,
      child: FushiModalSheetFrame(
        title: t.pdf_bookmarks,
        leadingIcon: Icons.bookmarks_outlined,
        body: _items.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(24),
                child: Center(child: Text(t.pdf_bookmarks_empty)),
              )
            : ListView.builder(
                shrinkWrap: true,
                itemCount: _items.length,
                itemBuilder: (BuildContext context, int index) {
                  final Bookmark bookmark = _items[index];
                  return FushiListItem(
                    leading: const Icon(Icons.bookmark_outline),
                    title: Text(bookmark.label),
                    trailing: IconButton(
                      tooltip: t.dialog_delete,
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        await widget.onDelete(bookmark);
                        if (!mounted) return;
                        setState(() => _items.removeAt(index));
                      },
                    ),
                    onTap: () => widget.onSelect(bookmark),
                  );
                },
              ),
      ),
    );
  }
}

/// PDF 目录弹层：把 pdfrx 的树形 [PdfOutlineNode] 拍平成带缩进的可点列表。
///
/// 用缩进而非可展开树：PDF 目录通常只有 2-3 层且条目不多，拍平一次可见全貌、点一下
/// 就跳，比逐层展开少两次交互。
class _PdfOutlineSheet extends StatelessWidget {
  const _PdfOutlineSheet({required this.nodes, required this.onSelect});

  final List<PdfOutlineNode> nodes;
  final void Function(PdfOutlineNode node) onSelect;

  /// 深度优先拍平，记录每个节点的层级用于缩进。
  static List<({PdfOutlineNode node, int depth})> _flatten(
    List<PdfOutlineNode> nodes, [
    int depth = 0,
  ]) {
    final List<({PdfOutlineNode node, int depth})> out =
        <({PdfOutlineNode node, int depth})>[];
    for (final PdfOutlineNode node in nodes) {
      out.add((node: node, depth: depth));
      if (node.children.isNotEmpty) {
        out.addAll(_flatten(node.children, depth + 1));
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final List<({PdfOutlineNode node, int depth})> flat = _flatten(nodes);
    return FushiDialogFrame(
      maxWidth: 520,
      maxHeightFactor: 0.82,
      scrollable: false,
      child: FushiModalSheetFrame(
        title: t.pdf_outline,
        leadingIcon: Icons.list_alt_outlined,
        body: ListView.builder(
          shrinkWrap: true,
          itemCount: flat.length,
          itemBuilder: (BuildContext context, int index) {
            final ({PdfOutlineNode node, int depth}) entry = flat[index];
            final int? pageNumber = entry.node.dest?.pageNumber;
            return FushiListItem(
              // 层级用左内边距表达（FushiListItem 的 padding 是整体内边距）。
              padding:
                  EdgeInsets.only(left: 8.0 + entry.depth * 16.0, right: 8),
              title: Text(
                entry.node.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              titleMaxLines: 2,
              trailing: pageNumber != null ? Text('$pageNumber') : null,
              onTap: () => onSelect(entry.node),
            );
          },
        ),
      ),
    );
  }
}
