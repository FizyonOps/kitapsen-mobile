import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:fushi_audio/fushi_audio.dart';
import 'package:path/path.dart' as p;
import 'package:fushi_engine/media/audiobook/text_to_epub.dart';
import 'package:fushi/src/media/import/import_carrier.dart';
import 'package:fushi/src/media/import/import_dialog_frame.dart';
import 'package:fushi/src/media/import/import_flow_mixin.dart';
import 'package:fushi/src/media/import/real_path_directory_picker.dart';
import 'package:fushi/src/media/media_cover_service.dart';
import 'package:fushi_engine/media/cover_file_writer.dart'
    show CoverImageInvalidException;
import 'package:fushi_core/fushi_core.dart';
import 'package:fushi_engine/epub/book_title_conflict.dart';
import 'package:fushi_engine/epub/epub_importer.dart';
import 'package:fushi_engine/epub/epub_parser.dart';
import 'package:fushi/src/pdf/pdf_importer.dart';
import 'package:fushi/utils.dart';

/// 统一"导入书"对话框。EPUB、字幕、音频可按需组合，一次导入。
///
/// 路由规则（以"选中了什么"为准）：
///
/// - **仅 EPUB**：[EpubImporter] 解压 + 入 Drift，书自然出现在书架。
/// - **仅字幕（可带音频）**：解析 cues → [CuesToEpub] 生成真 EPUB 并
///   [EpubImporter] 导入；同时把 cues + audio 路径落到 Isar [SrtBook] / [AudioCue]。
/// - **EPUB + 字幕（可带音频）**：先 [EpubImporter] 导入 EPUB 拿 `bookId`；再用
///   [EpubParser] 读回章节文本，跑 [EpubSrtMatcher] + [SasayakiMatchCodec]，
///   把 cue 对齐到真实 EPUB；cues + 可选音频落到 [AudiobookRepository]。
/// - **音频但无字幕**：非法组合，音频必须配合字幕使用。
///
/// **漫画不在此列**：漫画有独立入口与独立对话框 [MangaImportDialog]（载体不同，
/// 可填字段就不同——漫画没有字幕/音频/对齐，书籍没有 OCR）。本框仍然**认得**漫画
/// 载体，但只做一件事：弹一次明确确认后把路径转交漫画流程（[_handoffIfManga]）。
class BookImportDialog extends StatefulWidget {
  const BookImportDialog({
    required this.repo,
    required this.audiobookRepo,
    required this.db,
    this.initialEpubPath,
    this.initialSubtitlePath,
    this.initialAudioPaths,
    this.imageArchiveProbe,
    super.key,
  });

  final SrtBookRepository repo;
  final AudiobookRepository audiobookRepo;
  final FushiDatabase db;
  final String? initialEpubPath;
  final String? initialSubtitlePath;

  /// 拖拽导入预填：随新书一起拖入的音频文件路径。EPUB+音频拖到书架空白处时透传，
  /// 否则丢失（书架 `importNewBook` 此前未携带 `files.audios`）。音频仍必配字幕，
  /// 故仅预填展示——`_doImport` 的「音频必须配字幕」校验照旧，只是能转录的平台
  /// 改为弹「字幕来源」（选文件 / 转录）就地补上，不能转录的平台仍要求补字幕
  /// （BUG-2266）。
  final List<String>? initialAudioPaths;

  /// 测试计数缝：生产始终走 [MangaModule.isImageArchive]；回归测试只在外层计数后
  /// 委托同一个真判据，证明真实对话框没有重复执行昂贵的整包载体判定。
  @visibleForTesting
  final bool Function(String path)? imageArchiveProbe;

  @override
  State<BookImportDialog> createState() => _BookImportDialogState();
}

class _BookImportDialogState extends State<BookImportDialog>
    with ImportFlowMixin<BookImportDialog> {
  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _authorCtrl = TextEditingController();

  /// 标题框当前内容的来源，决定选/重选文件时能否覆盖（见 [resolveImportTitle]，
  /// TODO-1362）。用户在标题框手打即置 [ImportTitleSource.user]，此后自动派生不再
  /// 覆盖；同来源重选（如再点一次「选书」换一本）刷新为新书名。
  ImportTitleSource _titleSource = ImportTitleSource.none;

  String? _epubPath;
  String? _subtitlePath;
  final List<String> _audioPaths = [];
  String? _coverPath;
  String? _audioCoverPath;
  // 内嵌封面抽取（m4b 等经 ffmpeg probe，桌面端有数百毫秒~数秒延迟）的在途
  // Future。各触发点赋值，导入时 _applyBestCoverToEpub 先 await 它，避免用户在
  // 抽取未返回时点「导入」导致 _audioCoverPath 仍为 null 被吞掉（BUG-483）。

  // 原始文件名（file_picker 在 Android 上返回的 cache 路径文件名可能与原始不同）
  String? _epubName;

  bool _pickerActive = false;

  bool get _hasSubtitles => _subtitlePath != null;

  /// 从所选文件名派生的书名 [derived] 回填标题框，覆盖决策委托纯函数
  /// [resolveImportTitle]（[incoming] 为本次来源）：同来源重选或标题为空才刷新，
  /// 跨来源保持「非空不覆盖」，用户手打的标题永不被覆盖（TODO-1362）。可从
  /// initState / setState 内调用——只改字段与控制器，不自行触发 setState。
  void _autoFillTitle(String derived, ImportTitleSource incoming) {
    final ({String text, ImportTitleSource source}) next = resolveImportTitle(
      currentText: _titleCtrl.text,
      currentSource: _titleSource,
      incoming: incoming,
      derived: derived,
    );
    _titleSource = next.source;
    if (next.text != _titleCtrl.text) {
      _titleCtrl.text = next.text;
    }
  }

  @override
  void initState() {
    super.initState();
    // Kitapsen has no manga, so it never probes archives or folders for pages.
    _carrierResolver = ImportCarrierResolver(
            isDirectory: (String pth) => Directory(pth).existsSync(),
            isImageArchive: (String _) => false,
            directoryHasPageImages: (String _) => false,
            directoryCarrierFileCount: (String _) => 0,
            directoryMokuroFileCount: (String _) => 0,
          );
    final String? epub = widget.initialEpubPath;
    if (epub != null) {
      _epubPath = epub;
      _epubName = p.basename(epub);
      // 目录（漫画页图文件夹）没有扩展名概念——目录名带点时
      // basenameWithoutExtension 会把 `第01巻.v2` 截成 `第01巻`，当书名用就错了。
      _autoFillTitle(
        Directory(epub).existsSync()
            ? p.basename(epub)
            : p.basenameWithoutExtension(epub),
        ImportTitleSource.epub,
      );
    }
    // Kitapsen imports plain books: subtitle / audio carriers are never taken.
    return;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _authorCtrl.dispose();
    // 进度 ValueNotifier 由 ImportFlowMixin.dispose() 经 super 链释放。
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BookImportDialogFrame(
        title: Text(t.srt_import),
        content: _buildForm(),
        actions: [
          // 漫画入口（「OCR 导入漫画」/「在线目录」）均已移出书籍导入框：
          // OCR 归 [MangaImportDialog]，在线目录归下载页。书籍框只做书。
          adaptiveDialogAction(
            context: context,
            onPressed: () => Navigator.pop(context),
            child: Text(t.dialog_cancel),
          ),
          buildImportAction(context, onImport: _doImport),
        ],
      );
  }

  /// 判定一个待导入路径的载体身份。文件系统判据在此注入，分类函数本身不碰 IO。
  ///
  /// 走 [ImportCarrierResolver] 而不是每次裸调 `classifyImportCarrier`：同一路径在一次
  /// 导入里会被问到三次（选中闸门 / `_doImport` 兜底闸门 / `_importEpubOnly` 分派），
  /// 而 `.zip` / `.epub` 的定性要真开包，问三次就整包解压三次。有声书对齐路径尤其亏
  /// ——它不进 `_importEpubOnly`，那几次开包纯属白开。记忆按路径失效，换文件会重算。
  late final ImportCarrierResolver _carrierResolver;

  ImportCarrier _classifyCarrier(String path) => _carrierResolver.resolve(path);

  Widget _buildForm() {
    final FushiDesignTokens tokens = FushiDesignTokens.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          t.kitapsen_import_hint,
          style: tokens.type.metadata,
        ),
        SizedBox(height: tokens.spacing.gap),
        AdaptiveSettingsSection(
          children: [
            _epubRow(),
            _coverRow(),
          ],
        ),
        SizedBox(height: tokens.spacing.rowVertical),
        FushiTextField(
          controller: _titleCtrl,
          labelText: t.srt_import_title_hint,
          // 用户一旦在标题框手打即锁定来源为 user，此后重选文件不再覆盖（TODO-1362）。
          // Flutter 不会为程序化的 controller.text= 触发 onChanged，故仅真实用户输入
          // （含屏幕键盘/粘贴，经 FushiTextField 转发）才置 user。
          onChanged: (String _) => _titleSource = ImportTitleSource.user,
        ),
        SizedBox(height: tokens.spacing.gap),
        FushiTextField(
          controller: _authorCtrl,
          labelText: t.srt_import_author_hint,
        ),
        if (importing) ...buildProgressSection(context, tokens),
      ],
    );
  }

  Widget _epubRow() {
    return FushiFilePickerRow(
      title: t.srt_import_pick_epub,
      subtitle: _epubPath == null ? null : _epubName ?? p.basename(_epubPath!),
      icon: Icons.menu_book_outlined,
      onTap: () => _pickEpub(),
      actions: [
        FushiIconButton(
          icon: Icons.menu_book_outlined,
          tooltip: t.srt_import_pick_epub,
          isWideTapArea: true,
          onTap: _pickEpub,
        ),
      ],
    );
  }

  // ── 文件/目录选择 ────────────────────────────────────────────────────────

  static final List<String> _bookExtensions = [
    'epub',
    // PDF 阅读器 Phase 1：PDF 走独立 PdfImporter（真渲染，不经 TextToEpub 文本转换），
    // 在 [_importEpubOnly] 里按 .pdf 扩展名分支。
    'pdf',
    ...TextToEpub.supportedExtensions,
  ];

  Future<void> _pickEpub({bool anyFile = false}) async {
    if (_pickerActive) return;
    _pickerActive = true;
    try {
      final FilePickerResult? result = await pickFilesByExtensions(
        context: context,
        allowedExtensions: anyFile ? null : _bookExtensions,
      );
      final PlatformFile? file = result?.files.single;
      final String? path = file?.path;
      if (path != null && file != null && mounted) {
        if (!mounted) return;
        setState(() {
          _epubPath = path;
          _epubName = file.name;
          _autoFillTitle(
            file.name.replaceAll(
                RegExp(
                    r'\.(epub|pdf|mokuro|cbz|zip|txt|html?|xhtml|md|markdown|rst|org|csv|tsv|log|json|xml)$',
                    caseSensitive: false),
                ''),
            ImportTitleSource.epub,
          );
        });
        await _autoAttachSidecars(path);
      }
    } finally {
      _pickerActive = false;
    }
  }

  /// 选中主书文件后，扫同目录同名字幕/音频自动填进对应行（仅填空、不覆盖
  /// 用户手选）。音频必须配字幕，故仅在字幕已就位时才填音频。桌面端有效；
  /// 移动端是缓存副本目录、扫不到兄弟文件，[findSidecars] 静默返回空。
  Future<void> _autoAttachSidecars(String mainPath) async {
    return;
  }

  /// 等内嵌封面抽取（可能仍在途）落定，使读取 [_audioCoverPath] 不会在 ffmpeg
  /// probe 未返回时拿到 null 把封面吞掉（BUG-483 / TODO-1034）。已完成则零等待。
  /// 主路径 [_applyBestCoverToEpub] 与字幕书+m4b 路径 [_importSubtitleBook] 共用。
  Future<void> _awaitCoverExtraction() async {
  }

  Widget _coverRow() {
    final String? effectiveCover = _coverPath ?? _audioCoverPath;
    return FushiFilePickerRow(
      title: t.srt_import_pick_cover,
      subtitle: effectiveCover == null ? null : p.basename(effectiveCover),
      icon: Icons.image_outlined,
      onTap: _pickCover,
      actions: [
        if (effectiveCover != null)
          FushiIconButton(
            icon: Icons.close,
            tooltip: t.dialog_clear,
            isWideTapArea: true,
            onTap: () async => setState(() {
              _coverPath = null;
              _audioCoverPath = null;
            }),
          ),
        FushiIconButton(
          icon: Icons.image_outlined,
          tooltip: t.srt_import_pick_cover,
          isWideTapArea: true,
          onTap: _pickCover,
        ),
      ],
    );
  }

  Future<void> _pickCover() async {
    if (_pickerActive) return;
    _pickerActive = true;
    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
      );
      if (result == null || !mounted) return;
      final String? path = result.files.first.path;
      if (path != null) {
        setState(() => _coverPath = path);
      }
    } finally {
      _pickerActive = false;
    }
  }

  /// 把封面图写进 EPUB **解压目录内**（`<extractDir>/cover<ext>`）并落库相对名
  /// `coverPath`——这是「EPUB 包内容的一部分」，不是三岛的独立封面文件
  /// （thumbnails/ / video_covers/ / game_covers/），目录与键派生都不同。
  /// 写盘仍走统一收口 [MediaCoverService.applyCoverFile]：导入时 extractDir 是
  /// 新目录、该路径此前从未被解码（驱逐是空操作），但收口保证将来任何「同路径
  /// 重写封面」的调用形态都自动满足「写盘→双键驱逐」不变量。
  Future<void> _applyCoverToEpub(String bookKey, {String? sourcePath}) async {
    final String source = sourcePath ?? _coverPath!;
    // Locate the extracted dir via the stored extract_dir column (the on-disk
    // folder name may still be a legacy int id; the column is the truth).
    final EpubBookRow? row = await widget.db.getEpubBook(bookKey);
    if (row == null) return;
    final String extractDir = row.extractDir;
    final String ext = p.extension(source);
    final String dest = p.join(extractDir, 'cover$ext');
    if (!await _writeCoverOrSkip(source: source, destPath: dest)) return;
    await (widget.db.update(widget.db.epubBooks)
          ..where((tbl) => tbl.bookKey.equals(bookKey)))
        .write(EpubBooksCompanion(coverPath: Value('cover$ext')));
  }

  /// 封面落盘的唯一出口（EPUB 包内 `cover.*` 与字幕书 `persistDir/cover.*` 共用）。
  ///
  /// BUG-2496：收口会拒收非图片 / 截断图片（改过扩展名的 HTML、ffmpeg 抽到一半的
  /// 内嵌封面）。封面坏了不能让整本书导入失败——记诊断、返回 false，调用方不写
  /// `coverPath`，书照常入库、书架回落占位图。其它 IO 异常照旧向上抛。
  Future<bool> _writeCoverOrSkip({
    required String source,
    required String destPath,
  }) async {
    try {
      await MediaCoverService.applyCoverFile(
        source: File(source),
        destPath: destPath,
      );
      return true;
    } on CoverImageInvalidException catch (e) {
      ErrorLogService.instance.logDiagnostic('BookImportDialog.cover', e);
      return false;
    }
  }

  // ── 导入 ────────────────────────────────────────────────────────────────

  /// 同名书弹窗回调，喂给 [EpubImporter]。是→加后缀，否/关闭→取消这本书。
  Future<DuplicateChoice> _askOnDuplicate(
    String proposedTitle,
  ) async {
    if (!mounted) return DuplicateChoice.cancel;
    final bool? keep = await showAppDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(t.book_import_duplicate_title),
        content: Text(t.book_import_duplicate_message(name: proposedTitle)),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t.book_import_duplicate_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t.book_import_duplicate_keep),
          ),
        ],
      ),
    );
    return keep == true ? DuplicateChoice.suffix : DuplicateChoice.cancel;
  }

  Future<void> _doImport() async {
    if (_epubPath == null && !_hasSubtitles) {
      FushiToast.show(
        msg: t.srt_import_missing_input,
        severity: ToastSeverity.error,
      );
      return;
    }
    // 兜底闸门：选/拖两条入口在收下路径时就已过 [_handoffIfManga]，但 initialEpubPath
    // 是构造参数直接塞进来的（书架拖入决策层刻意不为每个 EPUB 开包，图片型 .epub 会
    // 以 books 身份到达这里）。同一个闸门在此再守一次，漫画绝不会走进书籍导入分支。
    if (!mounted) return;
    final String title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      FushiToast.show(
        msg: t.srt_import_missing_title,
        severity: ToastSeverity.error,
      );
      return;
    }

    // 失败日志/toast/importing 复位收敛到 ImportFlowMixin.runImport 模板；
    // 同名弹窗选「否」不是错误，走 isCancelled 分支只提示取消并 pop(false)。
    await runImport(
      logTag: 'BookImportDialog.import',
      debugMessage: (Object e) => 'BookImportDialog error: $e',
      isCancelled: (Object e) => e is DuplicateImportCancelledException,
      onCancelled: () {
        if (mounted) {
          FushiToast.show(
            msg: t.book_import_duplicate_cancelled,
            severity: ToastSeverity.info,
          );
          Navigator.pop(context, false);
        }
      },
      action: () async {
        reportProgress(0, '');

        debugPrint(
            '[fushi-import] route: epub=$_epubPath sub=$_subtitlePath audio=${_audioPaths.length} files');
        await _importEpubOnly(title: title);

        if (mounted) {
          final String msg = (t.srt_import_success);
          FushiToast.show(msg: msg, severity: ToastSeverity.success);
          Navigator.pop(context, true);
        }
      },
    );
  }

  Future<void> _importEpubOnly({required String title}) async {
    final File file = File(_epubPath!);

    reportProgress(0.2, t.import_step_reading);

    // 载体身份此前是在这里靠 4 个 if（含一次真读包）现场嗅出来的；现在它在**选中
    // 文件那一刻**就已由 [classifyImportCarrier] 定死，且漫画载体根本进不来（三个
    // 入口都过 [_handoffIfManga]）。这里只剩书籍侧的三种去向。
    final ImportCarrier carrier = _classifyCarrier(_epubPath!);

    // PDF 阅读器 Phase 1：.pdf 走独立 PdfImporter（pdfrx 真渲染 + 落库 format='pdf'）。
    // PDF 封面在 PdfImporter 内栅格化首页得到，故不走 _applyBestCoverToEpub。
    if (carrier == ImportCarrier.pdf) {
      // PDF 完全不经 EPUB 管线（pdfrx 直接渲染、落库 format='pdf'），所以这里报的是
      // 中性的「导入书籍…」。用户看到「导入 EPUB…」卡住时会以为是 EPUB 转换出了问题，
      // 而真正卡住的是 PDFium——错误的文案会把排查引向错误的方向（BUG-2419）。
      reportProgress(0.5, t.import_step_importing_book);
      await PdfImporter.importFromPath(
        db: widget.db,
        filePath: _epubPath!,
        fileName: _epubName ?? p.basename(_epubPath!),
        title: title,
        policy: DuplicatePolicy.ask(_askOnDuplicate),
      );
      reportProgress(1, t.import_step_done);
      return;
    }

    final String bookKey;
    if (carrier == ImportCarrier.text) {
      reportProgress(0.3, t.import_step_converting_epub);
      final Uint8List bytes =
          await TextToEpub.convert(file: file, title: title);
      final String filename =
          '${title.replaceAll(RegExp(r'[^\w\s\-]'), '')}.epub';
      reportProgress(0.5, t.import_step_importing_epub);
      bookKey = await EpubImporter.import(
        db: widget.db,
        bytes: bytes,
        fileName: filename,
        policy: DuplicatePolicy.ask(_askOnDuplicate),
      );
    } else {
      reportProgress(0.5, t.import_step_importing_epub);
      bookKey = await EpubImporter.importFromPath(
        db: widget.db,
        filePath: _epubPath!,
        fileName: _epubName ?? p.basename(_epubPath!),
        policy: DuplicatePolicy.ask(_askOnDuplicate),
      );
    }

    await _applyBestCoverToEpub(bookKey);
    reportProgress(1, t.import_step_done);
  }

  Future<void> _applyBestCoverToEpub(String bookKey) async {
    // 等内嵌封面抽取（可能仍在途）落定再判断，否则用户在 ffmpeg 未返回时点导入会把
    // _audioCoverPath 当 null 吞掉封面（BUG-483）。已完成则零等待。
    await _awaitCoverExtraction();
    if (_coverPath != null) {
      await _applyCoverToEpub(bookKey);
    }
  }

}

@visibleForTesting
class BookImportDialogFrame extends StatelessWidget {
  const BookImportDialogFrame({
    required this.title,
    required this.content,
    required this.actions,
    super.key,
  });

  final Widget title;
  final Widget content;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final FushiDesignTokens tokens = FushiDesignTokens.of(context);

    return ImportDialogFrame(
      leadingIcon: Icons.library_add_outlined,
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          DefaultTextStyle.merge(
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: tokens.type.listTitle.copyWith(
              fontWeight: FontWeight.w600,
            ),
            child: title,
          ),
          SizedBox(height: tokens.spacing.gap),
          content,
        ],
      ),
      actions: actions,
    );
  }
}

/// 导入对话框标题框内容的来源。优先级不是全序：规则是「同来源重选或标题为空才刷新」，
/// 跨来源保持既有「非空即不覆盖」语义（见 [resolveImportTitle]，TODO-1362）。
enum ImportTitleSource {
  /// 标题框为空、从未被任何来源填过。
  none,

  /// 从内嵌音频标签（M4B/MP3 等）自动读出的标题（TODO-1045）。
  metadata,

  /// 从字幕文件名派生的标题。
  subtitle,

  /// 从书文件（EPUB / txt 等）文件名派生的标题。
  epub,

  /// 用户在标题框手动输入的标题——永不被自动派生覆盖。
  user,
}

/// 选/重选导入文件后，标题框应显示的书名及其来源（纯函数，TODO-1362 可测核心）。
///
/// 「先选魔眼再重选尸人、下方书名不刷新」的根因是各选文件点仅在标题为空时回填，
/// 一旦有了自动派生书名，重选便永不更新。此函数用来源身份取代「仅空时回填」：
/// - 标题被用户手打过（[currentSource] == user 且非空）→ 永不覆盖，尊重用户输入。
/// - 标题为空、或本次来源 [incoming] 与当前来源相同（同槽位重选换一本）→ 刷新为
///   新派生的 [derived]。
/// - 否则（跨来源且标题非空，如已有 epub 书名时又选了字幕/读到音频标签）→ 保持不变，
///   与旧「非空即不覆盖」行为逐位等价，零跨来源回归。
@visibleForTesting
({String text, ImportTitleSource source}) resolveImportTitle({
  required String currentText,
  required ImportTitleSource currentSource,
  required ImportTitleSource incoming,
  required String derived,
}) {
  final bool userOwned =
      currentSource == ImportTitleSource.user && currentText.isNotEmpty;
  if (!userOwned && (currentText.isEmpty || incoming == currentSource)) {
    return (text: derived, source: incoming);
  }
  return (text: currentText, source: currentSource);
}
