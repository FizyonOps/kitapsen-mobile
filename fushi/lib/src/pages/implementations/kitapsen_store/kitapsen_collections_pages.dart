/// Private collections ("Koleksiyonlar"), as on the website: create, rename
/// and delete them, open one, remove books; books are added from their page
/// ([showAddToCollectionSheet]).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fushi/src/models/app_model.dart';
import 'package:fushi/src/pages/implementations/kitapsen_store/kitapsen_store_widgets.dart';
import 'package:fushi/src/sync/kitapsen_community.dart';
import 'package:fushi/src/sync/kitapsen_store.dart';
import 'package:fushi/utils.dart';

class KitapsenCollectionsPage extends ConsumerStatefulWidget {
  const KitapsenCollectionsPage({super.key});

  @override
  ConsumerState<KitapsenCollectionsPage> createState() =>
      _KitapsenCollectionsPageState();
}

class _KitapsenCollectionsPageState
    extends ConsumerState<KitapsenCollectionsPage> {
  late Future<(KitapsenStore, List<StoreCollection>)> _load = _fetch();

  Future<(KitapsenStore, List<StoreCollection>)> _fetch() async {
    final KitapsenStore store = await KitapsenStore.open(
      ref.read(appProvider).database,
    );
    return (store, await store.collections());
  }

  void _reload() => setState(() => _load = _fetch());

  Future<void> _edit(KitapsenStore store, [StoreCollection? existing]) async {
    final ({String text, String? extra})? r = await showStoreTextDialog(
      context,
      title: existing == null
          ? t.kitapsen_collections_new
          : t.kitapsen_common_edit,
      label: t.kitapsen_collections_name,
      initial: existing?.name ?? '',
      extraLabel: t.kitapsen_collections_description,
      initialExtra: existing?.description ?? '',
    );
    if (r == null) return;
    try {
      if (existing == null) {
        await store.createCollection(r.text, description: r.extra);
      } else {
        await store.updateCollection(existing.id, r.text, r.extra);
      }
      _reload();
    } catch (e, stack) {
      storeActionFailed(e, stack, 'KitapsenCollectionsPage.edit');
    }
  }

  Future<void> _delete(KitapsenStore store, StoreCollection c) async {
    if (!await showStoreConfirm(
      context,
      t.kitapsen_collections_delete_confirm,
      action: t.dialog_delete,
      destructive: true,
    )) {
      return;
    }
    try {
      await store.deleteCollection(c.id);
      _reload();
    } catch (e, stack) {
      storeActionFailed(e, stack, 'KitapsenCollectionsPage.delete');
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<(KitapsenStore, List<StoreCollection>)>(
      future: _load,
      builder: (_, AsyncSnapshot<(KitapsenStore, List<StoreCollection>)> s) {
        final KitapsenStore? store = s.data?.$1;
        return FushiPageScaffold(
          title: t.kitapsen_collections_title,
          actions: <Widget>[
            if (store != null)
              IconButton(
                key: const ValueKey<String>('kitapsen-collections-new'),
                tooltip: t.kitapsen_collections_new,
                icon: const Icon(Icons.add),
                onPressed: () => _edit(store),
              ),
          ],
          body: storeAsync(
            s,
            onRetry: _reload,
            isEmpty: ((KitapsenStore, List<StoreCollection>) d) => d.$2.isEmpty,
            emptyIcon: Icons.collections_bookmark_outlined,
            emptyMessage: t.kitapsen_collections_empty,
            builder: ((KitapsenStore, List<StoreCollection>) d) => ListView(
              padding: withBottomSafeInset(context, EdgeInsets.zero),
              children: <Widget>[
                for (final StoreCollection c in d.$2)
                  ListTile(
                    leading: const Icon(Icons.collections_bookmark_outlined),
                    title: Text(c.name),
                    subtitle: Text(
                      <String>[
                        t.kitapsen_store_author_books_count(n: c.itemCount),
                        if (c.description != null) c.description!,
                      ].join(' · '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (String v) =>
                          v == 'edit' ? _edit(d.$1, c) : _delete(d.$1, c),
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
                              KitapsenCollectionPage(collectionId: c.id),
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

class KitapsenCollectionPage extends ConsumerStatefulWidget {
  const KitapsenCollectionPage({super.key, required this.collectionId});

  final int collectionId;

  @override
  ConsumerState<KitapsenCollectionPage> createState() =>
      _KitapsenCollectionPageState();
}

class _KitapsenCollectionPageState
    extends ConsumerState<KitapsenCollectionPage> {
  late Future<(KitapsenStore, StoreCollection)> _load = _fetch();

  Future<(KitapsenStore, StoreCollection)> _fetch() async {
    final KitapsenStore store = await KitapsenStore.open(
      ref.read(appProvider).database,
    );
    return (store, await store.collection(widget.collectionId));
  }

  Future<void> _remove(KitapsenStore store, StoreCollectionItem item) async {
    if (!await showStoreConfirm(
      context,
      t.kitapsen_collections_remove_confirm(title: item.title),
      action: t.kitapsen_collections_remove,
    )) {
      return;
    }
    try {
      await store.removeFromCollection(widget.collectionId, item.id);
      if (mounted) setState(() => _load = _fetch());
    } catch (e, stack) {
      storeActionFailed(e, stack, 'KitapsenCollectionPage.remove');
    }
  }

  @override
  Widget build(BuildContext context) {
    final StoreColors c = StoreColors.of(context);
    final FushiDesignTokens tokens = FushiDesignTokens.of(context);
    return FutureBuilder<(KitapsenStore, StoreCollection)>(
      future: _load,
      builder: (_, AsyncSnapshot<(KitapsenStore, StoreCollection)> s) =>
          FushiPageScaffold(
            title: s.data?.$2.name ?? '',
            body: storeAsync(
              s,
              onRetry: () => setState(() => _load = _fetch()),
              builder: ((KitapsenStore, StoreCollection) d) => CustomScrollView(
                slivers: <Widget>[
                  SliverPadding(
                    padding: EdgeInsets.all(tokens.spacing.page),
                    sliver: SliverToBoxAdapter(
                      child: Text(
                        d.$2.items.isEmpty
                            ? t.kitapsen_collections_items_empty
                            : d.$2.description ??
                                  t.kitapsen_collections_long_press,
                        style: TextStyle(color: c.body),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: EdgeInsets.symmetric(
                      horizontal: tokens.spacing.page,
                    ),
                    sliver: SliverGrid(
                      gridDelegate: storeGridDelegate(context),
                      delegate: SliverChildBuilderDelegate((_, int i) {
                        final StoreCollectionItem item = d.$2.items[i];
                        return GestureDetector(
                          onLongPress: () => _remove(d.$1, item),
                          child: StoreBookCard(
                            book: StoreBook(
                              id: item.bookId,
                              title: item.title,
                              coverUrl: item.coverUrl,
                            ),
                          ),
                        );
                      }, childCount: d.$2.items.length),
                    ),
                  ),
                  SliverPadding(
                    padding: withBottomSafeInset(
                      context,
                      const EdgeInsets.only(bottom: 24),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }
}

/// "Koleksiyona ekle" from a book page: pick a collection (or make one).
Future<void> showAddToCollectionSheet(
  BuildContext context,
  KitapsenStore store,
  int bookId,
) async {
  final List<StoreCollection> collections;
  try {
    collections = await store.collections();
  } catch (e, stack) {
    storeActionFailed(e, stack, 'showAddToCollectionSheet.load');
    return;
  }
  if (!context.mounted) return;
  final Object? picked = await showModalBottomSheet<Object>(
    context: context,
    showDragHandle: true,
    builder: (BuildContext sheet) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              t.kitapsen_collections_add_title,
              style: Theme.of(sheet).textTheme.titleMedium,
            ),
          ),
          for (final StoreCollection c in collections)
            ListTile(
              leading: const Icon(Icons.collections_bookmark_outlined),
              title: Text(c.name),
              subtitle: Text(
                t.kitapsen_store_author_books_count(n: c.itemCount),
              ),
              onTap: () => Navigator.pop(sheet, c),
            ),
          ListTile(
            leading: const Icon(Icons.add),
            title: Text(t.kitapsen_collections_new),
            onTap: () => Navigator.pop(sheet, 'new'),
          ),
        ],
      ),
    ),
  );
  if (picked == null || !context.mounted) return;
  try {
    int collectionId;
    if (picked is StoreCollection) {
      collectionId = picked.id;
    } else {
      final ({String text, String? extra})? r = await showStoreTextDialog(
        context,
        title: t.kitapsen_collections_new,
        label: t.kitapsen_collections_name,
      );
      if (r == null) return;
      await store.createCollection(r.text);
      final List<StoreCollection> after = await store.collections();
      collectionId = after
          .firstWhere(
            (StoreCollection c) => c.name == r.text,
            orElse: () => after.first,
          )
          .id;
    }
    await store.addToCollection(collectionId, bookId);
    FushiToast.show(
      msg: t.kitapsen_collections_added,
      severity: ToastSeverity.success,
    );
  } catch (e, stack) {
    storeActionFailed(e, stack, 'showAddToCollectionSheet.add');
  }
}
