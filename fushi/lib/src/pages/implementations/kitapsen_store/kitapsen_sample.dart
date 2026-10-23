/// Reading samples of paid store books (book page › "Örneği oku"), and the
/// whole-book copy an admin reads to review a book (book page › "Şimdi Oku"
/// on a book the admin does not own, published or not).
///
/// A sample is imported for one reading session and deleted when the reader
/// closes. Left on the shelf it would carry the full book's title, so once
/// the book is bought the shelf would hold two copies and the cut one could
/// be opened by mistake. It is never linked to its store id
/// ([KitapsenClient.recordDownloaded]), so its progress and annotations are
/// not synced: those belong to the full book.
///
/// The reader keeps no position for it either. The reader pops before its
/// exit save lands (`exitAfterPersist`) and saves once more when the app next
/// goes to the background, both after the delete below, so a saved position
/// would outlive the book as an orphan row.
library;

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fushi_reading/fushi_reading.dart';
import 'package:fushi_core/fushi_core.dart';
import 'package:fushi_engine/epub/epub_importer.dart';
import 'package:fushi_engine/epub/epub_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:fushi/src/media/media_item.dart';
import 'package:fushi/src/media/sources/reader_fushi_source.dart';
import 'package:fushi/src/models/app_model.dart';
import 'package:fushi/src/pdf/pdf_importer.dart';
import 'package:fushi/src/sync/kitapsen_client.dart';
import 'package:fushi/utils.dart';

/// The bookKey of the sample on this device while one is open, so a sample
/// left behind by a killed app is removed at the next start.
const String _kSampleBookKeyPref = 'kitapsen_sample_book_key';

/// Downloads the sample of store book [bookId] (or, with [fullBook], an
/// admin's review copy of the whole book), opens it in the reader and
/// removes it again once the reader is closed.
Future<void> readKitapsenSample({
  required WidgetRef ref,
  required KitapsenClient client,
  required int bookId,
  required String title,
  bool fullBook = false,
}) async {
  final AppModel appModel = ref.read(appProvider);
  final FushiDatabase db = appModel.database;
  await removeKitapsenSample(db);
  final Directory temp = await getTemporaryDirectory();
  final File file = File(p.join(temp.path, 'kitapsen_sample_$bookId'));
  try {
    if (fullBook) {
      await client.getReviewCopy(bookId, file);
    } else {
      await client.getSample(bookId, file);
    }
    final String bookKey = await _importSample(db, file, title);
    await db.setPref(_kSampleBookKeyPref, bookKey);
    final MediaItem? item = await ReaderFushiSource.instance
        .mediaItemForBookKey(bookKey);
    if (item == null) {
      throw StateError('Kitapsen sample $bookId: imported book not found');
    }
    await appModel.openMedia(
      ref: ref,
      mediaSource: item.getMediaSource(appModel: appModel),
      item: item,
      // Opens at the start and, like a jump from a collection, never saves
      // the reading position (BUG-459's preserveSavedPosition).
      initialBookmarkJump: Bookmark(
        sectionIndex: 0,
        normCharOffset: 0,
        label: '',
        createdAt: DateTime.now(),
        preserveSavedPosition: true,
      ),
      // The book is gone once the reader closes; history would point nowhere.
    );
  } finally {
    if (file.existsSync()) await file.delete();
    await removeKitapsenSample(db);
  }
}

/// Removes the sample left on this device, if any: the book row with
/// everything the database hangs off it, its extracted files and its
/// "added" activity.
Future<void> removeKitapsenSample(FushiDatabase db) async {
  final String? bookKey = await db.getPref(_kSampleBookKeyPref);
  if (bookKey == null || bookKey.isEmpty) return;
  try {
    final EpubBookRow? row = await db.getEpubBook(bookKey);
    if (row != null) {
      // No tombstone: the bought book may later be imported under this key.
      await db.deleteEpubBook(bookKey);
      await EpubStorage.deleteBookDir(row.extractDir);
      await db.deleteActivityEventsForTitle(row.title);
    }
    await db.deletePref(_kSampleBookKeyPref);
  } catch (e, stack) {
    ErrorLogService.instance.log('KitapsenSample.remove', e, stack);
  }
}

/// Imports the downloaded sample like the shelf imports a full download:
/// a PDF-only book arrives as its PDF, anything else is an EPUB.
Future<String> _importSample(FushiDatabase db, File file, String title) async {
  final RandomAccessFile raf = await file.open();
  final bool isPdf;
  try {
    isPdf = String.fromCharCodes(await raf.read(5)) == '%PDF-';
  } finally {
    await raf.close();
  }
  // The file name is the title fallback for an EPUB without one.
  final String name = title.replaceAll(RegExp(r'[/\\]'), ' ');
  return isPdf
      ? PdfImporter.importFromPath(
          db: db,
          filePath: file.path,
          fileName: '$name.pdf',
          title: title,
        )
      : EpubImporter.importFromPath(
          db: db,
          filePath: file.path,
          fileName: '$name.epub',
        );
}
