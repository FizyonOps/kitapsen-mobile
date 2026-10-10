/// Notebooks ("Not Defterleri"), as on the website: free-form notebooks
/// with dated notes, kept on kitapsen.com.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fushi/src/models/app_model.dart';
import 'package:fushi/src/pages/implementations/kitapsen_store/kitapsen_store_widgets.dart';
import 'package:fushi/src/sync/kitapsen_community.dart';
import 'package:fushi/src/sync/kitapsen_store.dart';
import 'package:fushi/utils.dart';

class KitapsenNotebooksPage extends ConsumerStatefulWidget {
  const KitapsenNotebooksPage({super.key});

  @override
  ConsumerState<KitapsenNotebooksPage> createState() =>
      _KitapsenNotebooksPageState();
}

class _KitapsenNotebooksPageState extends ConsumerState<KitapsenNotebooksPage> {
  late Future<(KitapsenStore, List<StoreNotebook>)> _load = _fetch();

  Future<(KitapsenStore, List<StoreNotebook>)> _fetch() async {
    final KitapsenStore store = await KitapsenStore.open(
      ref.read(appProvider).database,
    );
    return (store, await store.notebooks());
  }

  void _reload() => setState(() => _load = _fetch());

  Future<void> _name(KitapsenStore store, [StoreNotebook? existing]) async {
    final ({String text, String? extra})? r = await showStoreTextDialog(
      context,
      title: existing == null
          ? t.kitapsen_notebooks_new
          : t.kitapsen_common_edit,
      label: t.kitapsen_notebooks_name,
      initial: existing?.name ?? '',
    );
    if (r == null) return;
    try {
      if (existing == null) {
        await store.createNotebook(r.text);
      } else {
        await store.renameNotebook(existing.id, r.text);
      }
      _reload();
    } catch (e, stack) {
      storeActionFailed(e, stack, 'KitapsenNotebooksPage.name');
    }
  }

  Future<void> _delete(KitapsenStore store, StoreNotebook n) async {
    if (!await showStoreConfirm(
      context,
      t.kitapsen_notebooks_delete_confirm,
      action: t.dialog_delete,
      destructive: true,
    )) {
      return;
    }
    try {
      await store.deleteNotebook(n.id);
      _reload();
    } catch (e, stack) {
      storeActionFailed(e, stack, 'KitapsenNotebooksPage.delete');
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<(KitapsenStore, List<StoreNotebook>)>(
      future: _load,
      builder: (_, AsyncSnapshot<(KitapsenStore, List<StoreNotebook>)> s) {
        final KitapsenStore? store = s.data?.$1;
        return FushiPageScaffold(
          title: t.kitapsen_notebooks_title,
          actions: <Widget>[
            if (store != null)
              IconButton(
                key: const ValueKey<String>('kitapsen-notebooks-new'),
                tooltip: t.kitapsen_notebooks_new,
                icon: const Icon(Icons.add),
                onPressed: () => _name(store),
              ),
          ],
          body: storeAsync(
            s,
            onRetry: _reload,
            isEmpty: ((KitapsenStore, List<StoreNotebook>) d) => d.$2.isEmpty,
            emptyIcon: Icons.edit_note_outlined,
            emptyMessage: t.kitapsen_notebooks_empty,
            builder: ((KitapsenStore, List<StoreNotebook>) d) => ListView(
              padding: withBottomSafeInset(context, EdgeInsets.zero),
              children: <Widget>[
                for (final StoreNotebook n in d.$2)
                  ListTile(
                    leading: const Icon(Icons.edit_note_outlined),
                    title: Text(n.name),
                    subtitle: Text(t.kitapsen_notebooks_count(n: n.entryCount)),
                    trailing: PopupMenuButton<String>(
                      onSelected: (String v) =>
                          v == 'edit' ? _name(d.$1, n) : _delete(d.$1, n),
                      itemBuilder: (_) => <PopupMenuEntry<String>>[
                        PopupMenuItem<String>(
                          value: 'edit',
                          child: Text(t.kitapsen_common_edit),
                        ),
                        PopupMenuItem<String>(
                          value: 'delete',
                          child: Text(t.dialog_delete),
                        ),
                      ],
                    ),
                    onTap: () async {
                      await Navigator.of(context).push(
                        adaptivePageRoute<void>(
                          context: context,
                          builder: (_) =>
                              KitapsenNotebookPage(notebookId: n.id),
                        ),
                      );
                      if (mounted) _reload();
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class KitapsenNotebookPage extends ConsumerStatefulWidget {
  const KitapsenNotebookPage({super.key, required this.notebookId});

  final int notebookId;

  @override
  ConsumerState<KitapsenNotebookPage> createState() =>
      _KitapsenNotebookPageState();
}

class _KitapsenNotebookPageState extends ConsumerState<KitapsenNotebookPage> {
  final TextEditingController _entry = TextEditingController();
  late Future<(KitapsenStore, StoreNotebook)> _load = _fetch();
  bool _busy = false;

  @override
  void dispose() {
    _entry.dispose();
    super.dispose();
  }

  Future<(KitapsenStore, StoreNotebook)> _fetch() async {
    final KitapsenStore store = await KitapsenStore.open(
      ref.read(appProvider).database,
    );
    return (store, await store.notebook(widget.notebookId));
  }

  Future<void> _add(KitapsenStore store) async {
    final String text = _entry.text.trim();
    if (text.isEmpty) return;
    setState(() => _busy = true);
    try {
      await store.addNotebookEntry(widget.notebookId, text);
      _entry.clear();
      if (mounted) setState(() => _load = _fetch());
    } catch (e, stack) {
      storeActionFailed(e, stack, 'KitapsenNotebookPage.add');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(KitapsenStore store, StoreNotebookEntry e) async {
    if (!await showStoreConfirm(
      context,
      t.kitapsen_notebooks_entry_delete_confirm,
      action: t.dialog_delete,
      destructive: true,
    )) {
      return;
    }
    try {
      await store.deleteNotebookEntry(widget.notebookId, e.id);
      if (mounted) setState(() => _load = _fetch());
    } catch (err, stack) {
      storeActionFailed(err, stack, 'KitapsenNotebookPage.delete');
    }
  }

  @override
  Widget build(BuildContext context) {
    final StoreColors c = StoreColors.of(context);
    final FushiDesignTokens tokens = FushiDesignTokens.of(context);
    return FutureBuilder<(KitapsenStore, StoreNotebook)>(
      future: _load,
      builder: (_, AsyncSnapshot<(KitapsenStore, StoreNotebook)> s) =>
          FushiPageScaffold(
            title: s.data?.$2.name ?? '',
            body: storeAsync(
              s,
              onRetry: () => setState(() => _load = _fetch()),
              builder: ((KitapsenStore, StoreNotebook) d) => Column(
                children: <Widget>[
                  Expanded(
                    child: d.$2.entries.isEmpty
                        ? Center(
                            child: FushiPlaceholderMessage(
                              icon: Icons.notes,
                              message: t.kitapsen_notebooks_entries_empty,
                            ),
                          )
                        : ListView(
                            padding: EdgeInsets.all(tokens.spacing.page),
                            children: <Widget>[
                              for (final StoreNotebookEntry e
                                  in d.$2.entries.reversed)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: c.tile,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        16,
                                        12,
                                        4,
                                        12,
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: <Widget>[
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: <Widget>[
                                                SelectableText(
                                                  e.content,
                                                  style: TextStyle(
                                                    color: c.ink,
                                                    height: 1.5,
                                                  ),
                                                ),
                                                const SizedBox(height: 6),
                                                Text(
                                                  storeDate(e.createdAt),
                                                  style: TextStyle(
                                                    color: c.muted,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          IconButton(
                                            tooltip: t.dialog_delete,
                                            icon: const Icon(
                                              Icons.delete_outline,
                                            ),
                                            onPressed: () => _delete(d.$1, e),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                  ),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        tokens.spacing.page,
                        8,
                        8,
                        8,
                      ),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: TextField(
                              key: const ValueKey<String>(
                                'kitapsen-notebook-entry',
                              ),
                              controller: _entry,
                              minLines: 1,
                              maxLines: 5,
                              decoration: InputDecoration(
                                hintText: t.kitapsen_notebooks_entry_hint,
                              ),
                            ),
                          ),
                          IconButton(
                            key: const ValueKey<String>(
                              'kitapsen-notebook-add',
                            ),
                            tooltip: t.kitapsen_notebooks_add,
                            onPressed: _busy ? null : () => _add(d.$1),
                            icon: Icon(Icons.send, color: c.accent),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }
}
