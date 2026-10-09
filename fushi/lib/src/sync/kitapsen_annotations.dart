/// Bookmarks, highlights and notes of one Kitapsen store book, kept in step
/// with kitapsen.com (`/api/v1/reading/{bookmarks,highlights,notes}`).
///
/// Bookmarks live in the device's Bookmarks table and highlights in its
/// favorite sentences (both rendered by the reader as before); notes have no
/// device store and are read from the server. Each synced local item is linked
/// to its server row by a pref (`kitapsen_bm__<storeId>__<localId>` /
/// `kitapsen_hl__<storeId>__<favoriteId>` → server id), which is how a
/// deletion on either side is told apart from an item that was never synced.
///
/// Locations are book-wide percentages ([KitapsenClient.percentLocation]);
/// web-made ones are CFIs, read back by their spine step.
library;

import 'package:fushi_audio/fushi_audio.dart';
import 'package:fushi_core/fushi_core.dart';

import 'package:fushi/src/sync/kitapsen_client.dart';
import 'package:fushi/src/utils/misc/error_log_service.dart';

String? _text(Object? v) {
  if (v is! String) return null;
  final String trimmed = v.trim();
  return trimmed.isEmpty ? null : trimmed;
}

int? _int(Object? v) => v is num ? v.toInt() : int.tryParse('$v');

/// A server note of the book.
class KitapsenNote {
  const KitapsenNote({
    required this.id,
    required this.content,
    this.location,
    this.createdAt,
  });

  final int id;
  final String content;
  final String? location;
  final DateTime? createdAt;
}

/// Highlight colors the app renders; anything else (the web's hex values)
/// shows in the default color.
const Set<String> _appColors = <String>{'green', 'blue', 'pink', 'purple'};

class KitapsenAnnotations {
  KitapsenAnnotations._(this._db, this._client, this.storeBookId, this.book);

  final FushiDatabase _db;
  final KitapsenClient _client;
  final int storeBookId;
  final EpubBookRow book;

  /// Null unless [bookKey] is a downloaded store book and someone is signed in.
  static Future<KitapsenAnnotations?> forBook(
    FushiDatabase db,
    String bookKey,
  ) async {
    final KitapsenClient? client = await KitapsenClient.restore(db);
    if (client == null) return null;
    final EpubBookRow? book = await db.getEpubBook(bookKey);
    if (book == null) return null;
    final int? storeId = await client.storeBookIdOf(book);
    if (storeId == null) return null;
    return KitapsenAnnotations._(db, client, storeId, book);
  }

  /// Best-effort sync of bookmarks and highlights (reader open / close).
  static Future<void> syncBook(FushiDatabase db, String bookKey) async {
    try {
      await (await forBook(db, bookKey))?.sync();
    } catch (e, stack) {
      ErrorLogService.instance.log('KitapsenAnnotations.syncBook', e, stack);
    }
  }

  Future<void> sync() async {
    await syncBookmarks();
    await syncHighlights();
  }

  String get _bookmarkPrefix => 'kitapsen_bm__${storeBookId}__';
  String get _highlightPrefix => 'kitapsen_hl__${storeBookId}__';

  Future<List<Map<String, dynamic>>> _list(
    String path, {
    Map<String, String>? query,
  }) async {
    final Object? decoded = await _client.requestJson(
      'GET',
      path,
      query: query,
    );
    return <Map<String, dynamic>>[
      if (decoded is List<dynamic>)
        for (final dynamic item in decoded)
          if (item is Map<String, dynamic> && _int(item['id']) != null) item,
    ];
  }

  // ── Bookmarks ─────────────────────────────────────────────────────

  Future<void> syncBookmarks() async {
    final BookmarkRepository repo = BookmarkRepository(_db);
    final Map<int, Bookmark> local = <int, Bookmark>{
      for (final Bookmark b in await repo.getBookmarks(book.uid))
        if (b.id != null) b.id!: b,
    };
    final Map<int, Map<String, dynamic>> remote = <int, Map<String, dynamic>>{
      for (final Map<String, dynamic> r in await _list(
        '/reading/bookmarks',
        query: <String, String>{'book_id': '$storeBookId'},
      ))
        _int(r['id'])!: r,
    };
    final Map<int, int> links = await _links(_bookmarkPrefix);

    for (final MapEntry<int, int> link in links.entries) {
      final bool hasLocal = local.containsKey(link.key);
      final bool hasRemote = remote.containsKey(link.value);
      if (hasLocal && !hasRemote) {
        await repo.removeBookmarkById(link.key);
      } else if (!hasLocal && hasRemote) {
        await _client.requestJson('DELETE', '/reading/bookmarks/${link.value}');
      }
      if (!(hasLocal && hasRemote)) {
        await _db.deletePref('$_bookmarkPrefix${link.key}');
      }
    }

    final Set<int> linkedLocal = links.keys.toSet();
    final Set<int> linkedRemote = links.values.toSet();
    for (final Bookmark b in local.values) {
      if (linkedLocal.contains(b.id)) continue;
      final Object? created = await _client.requestJson(
        'POST',
        '/reading/bookmarks',
        jsonBody: <String, Object>{
          'book_id': storeBookId,
          'location': KitapsenClient.percentLocation(
            book,
            b.sectionIndex,
            b.normCharOffset / 10000,
          ),
          if (b.label.isNotEmpty) 'label': _clip(b.label, 200),
        },
      );
      final int? serverId = created is Map<String, dynamic>
          ? _int(created['id'])
          : null;
      if (serverId != null) {
        await _db.setPref('$_bookmarkPrefix${b.id}', '$serverId');
      }
    }
    for (final MapEntry<int, Map<String, dynamic>> r in remote.entries) {
      if (linkedRemote.contains(r.key)) continue;
      final ({int section, double fraction})? at = KitapsenClient.positionAt(
        book,
        _text(r.value['location']) ?? '',
      );
      if (at == null) continue;
      final int localId = await repo.addBookmark(
        book.uid,
        Bookmark(
          sectionIndex: at.section,
          normCharOffset: (at.fraction * 10000).round(),
          label: _text(r.value['label']) ?? '',
          createdAt:
              DateTime.tryParse('${r.value['created_at']}') ?? DateTime.now(),
          bookTitle: book.title,
        ),
      );
      await _db.setPref('$_bookmarkPrefix$localId', '${r.key}');
    }
  }

  // ── Highlights ────────────────────────────────────────────────────

  Future<void> syncHighlights() async {
    final FavoriteSentenceRepository repo = FavoriteSentenceRepository(_db);
    final Map<String, FavoriteSentence> local = <String, FavoriteSentence>{
      for (final FavoriteSentence f in await repo.getAll())
        if (f.bookKey == book.bookKey) f.id: f,
    };
    final Map<int, Map<String, dynamic>> remote = <int, Map<String, dynamic>>{
      for (final Map<String, dynamic> r in await _list(
        '/reading/highlights/$storeBookId',
      ))
        _int(r['id'])!: r,
    };
    final Map<String, int> links = await _stringLinks(_highlightPrefix);

    for (final MapEntry<String, int> link in links.entries) {
      final bool hasLocal = local.containsKey(link.key);
      final bool hasRemote = remote.containsKey(link.value);
      if (hasLocal && !hasRemote) {
        await repo.removeById(link.key);
      } else if (!hasLocal && hasRemote) {
        await _client.requestJson(
          'DELETE',
          '/reading/highlights/${link.value}',
        );
      }
      if (!(hasLocal && hasRemote)) {
        await _db.deletePref('$_highlightPrefix${link.key}');
      }
    }

    final Set<String> linkedLocal = links.keys.toSet();
    final Set<int> linkedRemote = links.values.toSet();
    for (final FavoriteSentence f in local.values) {
      if (linkedLocal.contains(f.id) || f.text.trim().isEmpty) continue;
      final int section = f.sectionIndex ?? 0;
      final int length = KitapsenClient.sectionLength(book, section);
      final int start = f.normCharOffset ?? 0;
      double fractionOf(int offset) => length > 0 ? offset / length : 0;
      final Object? created = await _client.requestJson(
        'POST',
        '/reading/highlights',
        jsonBody: <String, Object>{
          'book_id': storeBookId,
          'location_start': KitapsenClient.percentLocation(
            book,
            section,
            fractionOf(start),
          ),
          'location_end': KitapsenClient.percentLocation(
            book,
            section,
            fractionOf(start + (f.normCharLength ?? 0)),
          ),
          'text': f.text,
          'color': f.color ?? 'yellow',
        },
      );
      final int? serverId = created is Map<String, dynamic>
          ? _int(created['id'])
          : null;
      if (serverId != null) {
        await _db.setPref('$_highlightPrefix${f.id}', '$serverId');
      }
    }
    for (final MapEntry<int, Map<String, dynamic>> r in remote.entries) {
      if (linkedRemote.contains(r.key)) continue;
      final String? text = _text(r.value['text']);
      final ({int section, double fraction})? at = KitapsenClient.positionAt(
        book,
        _text(r.value['location_start']) ?? '',
      );
      if (text == null || at == null) continue;
      final String? color = _text(r.value['color']);
      // The reader places a highlight by its text within the section; the
      // offset is only a hint, so a web CFI's chapter start is enough.
      final FavoriteSentence fav = FavoriteSentence(
        text: text,
        bookTitle: book.title,
        createdAt:
            DateTime.tryParse('${r.value['created_at']}') ?? DateTime.now(),
        bookKey: book.bookKey,
        sectionIndex: at.section,
        normCharOffset:
            (at.fraction * KitapsenClient.sectionLength(book, at.section))
                .round(),
        normCharLength: text.length,
        color: _appColors.contains(color) ? color : null,
      );
      await repo.add(fav);
      await _db.setPref('$_highlightPrefix${fav.id}', '${r.key}');
    }
  }

  // ── Notes (server only) ───────────────────────────────────────────

  Future<List<KitapsenNote>> notes() async => <KitapsenNote>[
    for (final Map<String, dynamic> n in await _list(
      '/reading/notes/$storeBookId',
    ))
      if (_text(n['content']) != null)
        KitapsenNote(
          id: _int(n['id'])!,
          content: _text(n['content'])!,
          location: _text(n['location']),
          createdAt: DateTime.tryParse('${n['created_at']}'),
        ),
  ];

  Future<void> addNote(
    String content, {
    required int section,
    required double fraction,
    String? title,
  }) => _client.requestJson(
    'POST',
    '/reading/notes',
    jsonBody: <String, Object>{
      'book_id': storeBookId,
      'content': content.trim(),
      'location': KitapsenClient.percentLocation(book, section, fraction),
      if (title != null && title.isNotEmpty) 'title': _clip(title, 300),
    },
  );

  Future<void> deleteNote(int id) =>
      _client.requestJson('DELETE', '/reading/notes/$id');

  // ── Links ─────────────────────────────────────────────────────────

  Future<Map<int, int>> _links(String prefix) async {
    final Map<String, int> raw = await _stringLinks(prefix);
    return <int, int>{
      for (final MapEntry<String, int> e in raw.entries)
        if (int.tryParse(e.key) != null) int.parse(e.key): e.value,
    };
  }

  Future<Map<String, int>> _stringLinks(String prefix) async {
    final Map<String, String> prefs = await _db.getPrefsByPrefix(prefix);
    return <String, int>{
      for (final MapEntry<String, String> e in prefs.entries)
        if (int.tryParse(e.value) != null)
          (e.key.startsWith(prefix) ? e.key.substring(prefix.length) : e.key):
              int.parse(e.value),
    };
  }

  static String _clip(String s, int max) =>
      s.length <= max ? s : s.substring(0, max);
}
