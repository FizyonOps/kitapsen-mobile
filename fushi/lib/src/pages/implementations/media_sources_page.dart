import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fushi_audio/fushi_audio.dart';

import 'package:fushi/media.dart';
import 'package:fushi/models.dart';
import 'package:fushi/src/media/audiobook/book_import_dialog.dart';
import 'package:fushi/src/media/import/quick_import_section.dart';
import 'package:fushi/utils.dart';

/// 书架导航壳里的「导入」视图：单本书导入入口（[QuickImportSection]）。
class MediaSourcesPage extends ConsumerStatefulWidget {
  const MediaSourcesPage({
    required this.navigation,
    super.key,
  });

  /// 库页视图导航条（由 [MediaLibraryShell] 传入，作为页头主内容）。
  final Widget navigation;

  @override
  ConsumerState<MediaSourcesPage> createState() => _MediaSourcesPageState();
}

class _MediaSourcesPageState extends ConsumerState<MediaSourcesPage> {
  /// BUG-513 同款纪律：AppModel 在 initState 捕获，async gap 之后不再 `ref.read`。
  late final AppModel _appModel = ref.read(appProvider);

  @override
  Widget build(BuildContext context) {
    final FushiDesignTokens tokens = FushiDesignTokens.of(context);
    // 与书架库页同构：DesktopContentLayout + FushiPageHeader，外层 Scaffold 由
    // HomePage 提供。
    return DesktopContentLayout(
      kind: DesktopContentKind.readerShelf,
      child: Column(
        children: <Widget>[
          FushiPageHeader.customTitle(title: widget.navigation),
          Expanded(
            // 正文自带内边距：留白取 spacing.page，与上方 [FushiPageHeader] 的
            // 横向内边距同源，标题与正文左边缘对齐。
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                tokens.spacing.page,
                0,
                tokens.spacing.page,
                tokens.spacing.page,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  QuickImportSection(
                    actions: <QuickImportAction>[
                      QuickImportAction(
                        icon: Icons.upload_file_outlined,
                        label: t.srt_import,
                        onTap: _importBookFile,
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 单本书导入：与旧书架页头按钮同一个对话框（EPUB/PDF/文本/字幕/有声书对齐）。
  Future<void> _importBookFile() async {
    final bool? imported = await showAppDialog<bool>(
      context: context,
      builder: (_) => BookImportDialog(
        repo: SrtBookRepository(_appModel.database),
        audiobookRepo: AudiobookRepository(_appModel.database),
        db: _appModel.database,
      ),
    );
    if (imported != true || !mounted) return;
    ref.invalidate(fushiBooksProvider);
    ref.invalidate(srtBooksProvider);
  }
}
