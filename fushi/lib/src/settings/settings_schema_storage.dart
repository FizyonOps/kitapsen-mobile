import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:fushi_core/fushi_core.dart';

import 'package:fushi/src/media/sources/reader_fushi_source.dart';
import 'package:fushi/src/pages/implementations/storage_usage_view.dart';
import 'package:fushi/src/pages/implementations/tag_filter_sheet.dart'
    show bookTagMapProvider;
import 'package:fushi/src/settings/settings_context.dart';
import 'package:fushi/src/settings/settings_destination.dart';
import 'package:fushi/src/storage/app_paths.dart';
import 'package:fushi/src/storage/storage_usage_service.dart';
import 'package:fushi/utils.dart';

/// 「存储」一级设置分类：磁盘占用总览（每个类目都可展开明细，书可单条删除）。
///
/// 正文经 [SettingsDestination.body] 逃生口渲染 [StorageUsageView]；所有删除
/// 都在这里接到各域既有路径（书 `ReaderFushiSource.deleteBook`），widget 自身零裸
/// 磁盘删除。
SettingsDestination buildStorageDestination() {
  return SettingsDestination(
    id: SettingsDestinationId.storage,
    title: t.settings_destination_storage,
    summary: t.settings_destination_storage_summary,
    icon: Icons.sd_storage_outlined,
    sections: const <SettingsSection>[],
    body: (SettingsContext c) => StorageUsageView(
      service: StorageUsageService(),
      booksProvider: () async {
        final List<EpubBookRow> rows = await c.appModel.database
            .getAllEpubBooks();
        return <StorageBookRef>[
          for (final EpubBookRow row in rows)
            StorageBookRef(
              id: row.bookKey,
              title: row.title,
              extractDir: row.extractDir,
            ),
        ];
      },
      deleteBook: (String bookKey) async {
        final DeleteBookResult result = await ReaderFushiSource.instance
            .deleteBook(
              db: c.appModel.database,
              bookKey: bookKey,
              appModel: c.appModel,
            );
        if (result.deleted) {
          // 与书架删除路径同款缓存失效（books.part.dart），否则书架/首页里
          // 这本书要等那些页自己刷新才消失（审查 M3）。invalidate 整个
          // family，不假设学习语言。
          c.ref.invalidate(fushiBooksProvider);
          c.ref.invalidate(bookTagMapProvider);
        }
        return result.deleted ? null : result.failureReason;
      },
      // BUG-1870：主库快照残留的删除原语在 fushi_core（与扫描侧识别口径同源）。
      deleteDatabaseSnapshots: () async =>
          deleteDatabaseSnapshotFiles(await AppPaths.supportRootDirectory()),
      // 派生/缓存类明细（封面缩略图、临时文件）的删除原语。这些路径没有任何
      // DB 行引用，裸删不绕过墓碑/引用护栏；服务层只扫不删，删只在这一处发生。
      // 已经不在磁盘上 = 目标状态已达成，按成功处理。
      deleteFiles: (List<String> paths) async {
        for (final String path in paths) {
          try {
            final FileSystemEntityType type = await FileSystemEntity.type(path);
            switch (type) {
              case FileSystemEntityType.directory:
                await Directory(path).delete(recursive: true);
              case FileSystemEntityType.notFound:
                break;
              default:
                await File(path).delete();
            }
          } catch (e) {
            return '${p.basename(path)}: $e';
          }
        }
        return null;
      },
    ),
    bodySearchEntries: <SettingsBodySearchEntry>[
      SettingsBodySearchEntry(
        id: 'storage.overview',
        title: t.storage_overview_section,
        subtitle: t.storage_overview_total,
      ),
    ],
  );
}
