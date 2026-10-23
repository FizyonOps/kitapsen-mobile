import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fushi_reading/fushi_reading.dart';
import 'package:fushi/media.dart';
import 'package:fushi/models.dart';
import 'package:fushi/pages.dart';
import 'package:fushi/utils.dart';

/// PDF 书的媒体源（PDF 阅读器 Phase 1）。
///
/// 设计要点（Linus 式「PDF 只是第二种书身份」）：
/// - PDF 与 EPUB **共用一张 `EpubBooks` 表、一块书架、一套删除/进度管线**。书架列书仍走
///   [ReaderFushiSource.getBooksFromDb]（列全部行，format-agnostic）；PDF 行靠
///   `EpubBooks.format=='pdf'` 在 [ReaderFushiSource] 的 `_bookToMediaItem` 里被打上
///   `mediaSourceIdentifier: `[kUniqueKey]，从而在**打开时**被路由到本源、进 [ReaderPdfPage]，
///   而不是 EPUB 的 [ReaderFushiPage]。
/// - PDF 复用 EPUB 的媒体标识方案（`hoshi://book/<bookKey>`，bookKey 是 `EpubBooks` 主键，
///   与 format 无关）——路由只认 `mediaSourceIdentifier`，标识前缀无需另立一套。
/// - 阅读器设置（翻页/查词等偏好）统一读 `ReaderFushiSource.instance`，本源不重复一套。
///
/// 本源只在打开一本 PDF 时被 `item.getMediaSource` 解析并短暂成为 `_currentMediaSource`；
/// 书架页头/搜索/源切换 UI 恒用默认的 [ReaderFushiSource]（源切换器当前未接线），故本源的
/// [getActions]/[buildHistoryPage] 极少被触达，实现取与 EPUB 源一致的安全回退。
class ReaderPdfSource extends ReaderMediaSource {
  ReaderPdfSource._()
      : super(
          uniqueKey: kUniqueKey,
          description: t.kitapsen_source_description_epub,
          icon: Icons.picture_as_pdf_outlined,
        );

  /// 媒体源唯一键（持久化标识，永不复用 `reader_fushi`）。[ReaderFushiSource] 的
  /// `_bookToMediaItem` 用它把 `format=='pdf'` 的行路由到本源。
  static const String kUniqueKey = 'reader_pdf';

  static ReaderPdfSource get instance => _instance;
  static final ReaderPdfSource _instance = ReaderPdfSource._();

  @override
  Future<void> onSourceExit({
    required AppModel appModel,
    required WidgetRef ref,
  }) async {
    // 与 EPUB 源同点失效：关书回书架时刷新书列表与「最近阅读」recency（bookKey 同源）。
    ref.invalidate(fushiBooksProvider);
    ref.invalidate(bookLastReadAtProvider);
  }

  @override
  Widget buildLaunchPage({
    MediaItem? item,
    Bookmark? initialBookmarkJump,
  }) {
    final String bookKey =
        ReaderFushiSource.parseBookKey(item?.mediaIdentifier ?? '') ?? '';
    return FushiAppUiScaleNeutralizer(
      child: ReaderPdfPage(item: item, bookKey: bookKey),
    );
  }

  @override
  BasePage buildHistoryPage({MediaItem? item, Widget? navigation}) {
    return ReaderFushiHistoryPage(navigation: navigation);
  }
}
