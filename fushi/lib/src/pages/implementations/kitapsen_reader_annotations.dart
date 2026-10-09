/// Reader › navigation sheet › "Yer imleri ve notlar" (Kitapsen edition):
/// add a bookmark or a note at the current position, and jump to or delete
/// the book's bookmarks and notes. Both are kept in step with kitapsen.com
/// ([KitapsenAnnotations]); highlights have their own list in the same sheet.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:fushi_audio/fushi_audio.dart';
import 'package:fushi_core/fushi_core.dart';

import 'package:fushi/src/sync/kitapsen_annotations.dart';
import 'package:fushi/src/sync/kitapsen_client.dart';
import 'package:fushi/utils.dart';

/// Where the reader is: the section, the fraction (0..1) into it, and the
/// chapter label shown next to a bookmark.
typedef ReaderPositionGetter =
    Future<({int section, double fraction, String label})> Function();

class KitapsenReaderAnnotations extends StatefulWidget {
  const KitapsenReaderAnnotations({
    super.key,
    required this.db,
    required this.bookKey,
    required this.currentPosition,
    required this.onJump,
  });

  final FushiDatabase db;
  final String bookKey;
  final ReaderPositionGetter currentPosition;
  final Future<void> Function(int section, double fraction) onJump;

  @override
  State<KitapsenReaderAnnotations> createState() =>
      _KitapsenReaderAnnotationsState();
}

class _KitapsenReaderAnnotationsState extends State<KitapsenReaderAnnotations> {
  KitapsenAnnotations? _annotations;
  List<Bookmark> _bookmarks = const <Bookmark>[];
  List<KitapsenNote> _notes = const <KitapsenNote>[];
  bool _loaded = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load(syncFirst: true));
  }

  Future<void> _load({bool syncFirst = false}) async {
    try {
      final KitapsenAnnotations? a = _annotations ??=
          await KitapsenAnnotations.forBook(widget.db, widget.bookKey);
      if (a == null) {
        if (mounted) setState(() => _loaded = true);
        return;
      }
      if (syncFirst) await a.syncBookmarks();
      final (List<Bookmark> bookmarks, List<KitapsenNote> notes) = await (
        BookmarkRepository(widget.db).getBookmarks(a.book.uid),
        a.notes(),
      ).wait;
      if (!mounted) return;
      setState(() {
        _bookmarks = bookmarks
          ..sort((Bookmark x, Bookmark y) => _order(x).compareTo(_order(y)));
        _notes = notes;
        _loaded = true;
      });
    } catch (e, stack) {
      ErrorLogService.instance.log('KitapsenReaderAnnotations.load', e, stack);
      if (mounted) setState(() => _loaded = true);
    }
  }

  double _order(Bookmark b) => b.sectionIndex + b.normCharOffset / 10000;

  Future<void> _run(Future<void> Function() action, {String? done}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      await _load();
      if (done != null) {
        FushiToast.show(msg: done, severity: ToastSeverity.success);
      }
    } catch (e, stack) {
      ErrorLogService.instance.log(
        'KitapsenReaderAnnotations.action',
        e,
        stack,
      );
      FushiToast.show(
        msg: t.kitapsen_book_action_failed,
        severity: ToastSeverity.error,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addBookmark(KitapsenAnnotations a) => _run(() async {
    final ({int section, double fraction, String label}) at = await widget
        .currentPosition();
    await BookmarkRepository(widget.db).addBookmark(
      a.book.uid,
      Bookmark(
        sectionIndex: at.section,
        normCharOffset: (at.fraction * 10000).round(),
        label: at.label,
        createdAt: DateTime.now(),
        bookTitle: a.book.title,
      ),
    );
    await a.syncBookmarks();
  }, done: t.kitapsen_bookmark_added);

  Future<void> _deleteBookmark(KitapsenAnnotations a, Bookmark b) =>
      _run(() async {
        await BookmarkRepository(widget.db).removeBookmarkById(b.id!);
        await a.syncBookmarks();
      });

  Future<void> _addNote(KitapsenAnnotations a) async {
    final String? content = await showAppDialog<String>(
      context: context,
      builder: (_) => const _NoteDialog(),
    );
    if (content == null || content.trim().isEmpty || !mounted) return;
    await _run(() async {
      final ({int section, double fraction, String label}) at = await widget
          .currentPosition();
      await a.addNote(
        content,
        section: at.section,
        fraction: at.fraction,
        title: at.label,
      );
    }, done: t.kitapsen_note_saved);
  }

  Future<void> _jump(int section, double fraction) async {
    Navigator.of(context).maybePop();
    await widget.onJump(section, fraction);
  }

  String _percent(KitapsenAnnotations a, int section, double fraction) =>
      '${double.parse(KitapsenClient.percentLocation(a.book, section, fraction)).toStringAsFixed(1)}%';

  @override
  Widget build(BuildContext context) {
    final KitapsenAnnotations? a = _annotations;
    if (!_loaded || a == null) return const SizedBox.shrink();
    final FushiDesignTokens tokens = FushiDesignTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(t.kitapsen_annotations_title, style: tokens.type.sectionLabel),
        const SizedBox(height: 8),
        Wrap(
          spacing: tokens.spacing.gap,
          runSpacing: tokens.spacing.gap,
          children: <Widget>[
            OutlinedButton.icon(
              key: const ValueKey<String>('kitapsen-reader-add-bookmark'),
              onPressed: _busy ? null : () => _addBookmark(a),
              icon: const Icon(Icons.bookmark_add_outlined),
              label: Text(t.kitapsen_bookmark_add),
            ),
            OutlinedButton.icon(
              key: const ValueKey<String>('kitapsen-reader-add-note'),
              onPressed: _busy ? null : () => _addNote(a),
              icon: const Icon(Icons.note_add_outlined),
              label: Text(t.kitapsen_note_add),
            ),
          ],
        ),
        if (_bookmarks.isEmpty && _notes.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              t.kitapsen_annotations_empty,
              style: tokens.type.metadata,
            ),
          ),
        for (final Bookmark b in _bookmarks)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.bookmark_outline),
            title: Text(b.label.isEmpty ? '—' : b.label),
            subtitle: Text(
              _percent(a, b.sectionIndex, b.normCharOffset / 10000),
            ),
            onTap: () => _jump(b.sectionIndex, b.normCharOffset / 10000),
            trailing: IconButton(
              tooltip: t.dialog_delete,
              icon: const Icon(Icons.delete_outline),
              onPressed: _busy || b.id == null
                  ? null
                  : () => _deleteBookmark(a, b),
            ),
          ),
        for (final KitapsenNote n in _notes)
          Builder(
            builder: (BuildContext context) {
              final ({int section, double fraction})? at = n.location == null
                  ? null
                  : KitapsenClient.positionAt(a.book, n.location!);
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.sticky_note_2_outlined),
                title: Text(
                  n.content,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: at == null
                    ? null
                    : Text(_percent(a, at.section, at.fraction)),
                onTap: at == null ? null : () => _jump(at.section, at.fraction),
                trailing: IconButton(
                  tooltip: t.dialog_delete,
                  icon: const Icon(Icons.delete_outline),
                  onPressed: _busy
                      ? null
                      : () => _run(() => a.deleteNote(n.id)),
                ),
              );
            },
          ),
      ],
    );
  }
}

class _NoteDialog extends StatefulWidget {
  const _NoteDialog();

  @override
  State<_NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends State<_NoteDialog> {
  final TextEditingController _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(t.kitapsen_note_add),
    content: TextField(
      key: const ValueKey<String>('kitapsen-note-input'),
      controller: _text,
      autofocus: true,
      minLines: 3,
      maxLines: 8,
      decoration: InputDecoration(hintText: t.kitapsen_note_hint),
    ),
    actions: <Widget>[
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(t.dialog_cancel),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _text.text),
        child: Text(t.kitapsen_review_submit),
      ),
    ],
  );
}
