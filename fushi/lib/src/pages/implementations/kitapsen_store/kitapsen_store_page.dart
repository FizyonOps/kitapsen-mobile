/// The "Mağaza" tab: search, home shelves and categories of kitapsen.com.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fushi/src/models/app_model.dart';
import 'package:fushi/src/pages/implementations/kitapsen_store/kitapsen_book_list_page.dart';
import 'package:fushi/src/pages/implementations/kitapsen_store/kitapsen_following_page.dart';
import 'package:fushi/src/pages/implementations/kitapsen_store/kitapsen_notifications_page.dart';
import 'package:fushi/src/pages/implementations/kitapsen_store/kitapsen_store_widgets.dart';
import 'package:fushi/src/pages/implementations/kitapsen_store/kitapsen_wishlist_page.dart';
import 'package:fushi/src/sync/kitapsen_store.dart';
import 'package:fushi/utils.dart';

class _StoreHome {
  const _StoreHome({
    required this.newArrivals,
    required this.mostRead,
    required this.staffPicks,
    required this.free,
    required this.stories,
    required this.categories,
  });

  final List<StoreBook> newArrivals;
  final List<StoreBook> mostRead;
  final List<StoreBook> staffPicks;
  final List<StoreBook> free;
  final List<StoreBook> stories;
  final List<StoreCategory> categories;
}

class KitapsenStorePage extends ConsumerStatefulWidget {
  const KitapsenStorePage({super.key});

  @override
  ConsumerState<KitapsenStorePage> createState() => _KitapsenStorePageState();
}

class _KitapsenStorePageState extends ConsumerState<KitapsenStorePage> {
  final TextEditingController _search = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  late Future<(KitapsenStore, _StoreHome)> _load = _fetch();
  int _unread = 0;

  @override
  void dispose() {
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<(KitapsenStore, _StoreHome)> _fetch() async {
    final KitapsenStore store = await KitapsenStore.open(
      ref.read(appProvider).database,
    );
    final (
      ({
        List<StoreBook> newArrivals,
        List<StoreBook> bestsellers,
        List<StoreBook> staffPicks,
      }),
      StoreBookPage,
      StoreBookPage,
      List<StoreCategory>,
    )
    results = await (
      store.home(),
      store.search(freeOnly: true, sort: StoreSort.newest, perPage: 12),
      store.search(serializedOnly: true, sort: StoreSort.newest, perPage: 12),
      store.categories(),
    ).wait;
    if (store.signedIn) unawaited(_refreshUnread(store));
    return (
      store,
      _StoreHome(
        newArrivals: results.$1.newArrivals,
        mostRead: results.$1.bestsellers,
        staffPicks: results.$1.staffPicks,
        free: results.$2.books,
        stories: results.$3.books,
        categories: results.$4
            .where((StoreCategory c) => c.totalBookCount > 0)
            .toList(),
      ),
    );
  }

  Future<void> _refreshUnread(KitapsenStore store) async {
    try {
      final int unread = await store.unreadNotificationCount();
      if (mounted) setState(() => _unread = unread);
    } catch (e, stack) {
      ErrorLogService.instance.log('KitapsenStorePage.unread', e, stack);
    }
  }

  Future<void> _reload() async {
    final Future<(KitapsenStore, _StoreHome)> load = _fetch();
    setState(() => _load = load);
    await load;
  }

  Future<void> _push(Widget page) async {
    await Navigator.of(
      context,
    ).push(adaptivePageRoute<void>(context: context, builder: (_) => page));
    // Signing in / out, claiming a book or reading notifications on the way
    // changes what this page shows.
    if (mounted) unawaited(_reload());
  }

  void _openList(
    String title, {
    String? query,
    String? categorySlug,
    bool freeOnly = false,
    bool serializedOnly = false,
    StoreSort? sort,
  }) {
    unawaited(
      _push(
        KitapsenBookListPage(
          title: title,
          query: query,
          categorySlug: categorySlug,
          freeOnly: freeOnly,
          serializedOnly: serializedOnly,
          initialSort: sort,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<(KitapsenStore, _StoreHome)>(
        future: _load,
        builder:
            (
              BuildContext context,
              AsyncSnapshot<(KitapsenStore, _StoreHome)> snapshot,
            ) {
              final KitapsenStore? store = snapshot.data?.$1;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  FushiPageHeader(
                    title: t.kitapsen_nav_store,
                    actions: <Widget>[
                      if (store != null && store.signedIn) ...<Widget>[
                        FushiIconButton(
                          key: const ValueKey<String>(
                            'kitapsen-store-following',
                          ),
                          icon: Icons.people_outline,
                          tooltip: t.kitapsen_following_title,
                          onTap: () => _push(const KitapsenFollowingPage()),
                        ),
                        FushiIconButton(
                          key: const ValueKey<String>(
                            'kitapsen-store-wishlist',
                          ),
                          icon: Icons.favorite_border,
                          tooltip: t.kitapsen_wishlist_title,
                          onTap: () => _push(const KitapsenWishlistPage()),
                        ),
                        Badge(
                          isLabelVisible: _unread > 0,
                          label: Text('$_unread'),
                          child: FushiIconButton(
                            key: const ValueKey<String>(
                              'kitapsen-store-notifications',
                            ),
                            icon: Icons.notifications_none,
                            tooltip: t.kitapsen_notifications_title,
                            onTap: () =>
                                _push(const KitapsenNotificationsPage()),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Expanded(child: _body(context, snapshot)),
                ],
              );
            },
      ),
    );
  }

  Widget _body(
    BuildContext context,
    AsyncSnapshot<(KitapsenStore, _StoreHome)> snapshot,
  ) {
    final FushiDesignTokens tokens = FushiDesignTokens.of(context);
    if (snapshot.hasError) {
      return StoreLoadError(onRetry: () => unawaited(_reload()));
    }
    final _StoreHome? home = snapshot.data?.$2;
    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        padding: withBottomSafeInset(
          context,
          EdgeInsets.only(bottom: tokens.spacing.section),
        ),
        children: <Widget>[
          Padding(
            padding: EdgeInsets.fromLTRB(
              tokens.spacing.page,
              0,
              tokens.spacing.page,
              tokens.spacing.section,
            ),
            child: FushiSearchField(
              controller: _search,
              focusNode: _searchFocus,
              hintText: t.kitapsen_store_search_hint,
              onChanged: (_) {},
              onSubmitted: (String q) {
                if (q.trim().isEmpty) return;
                _openList(q.trim(), query: q.trim());
              },
            ),
          ),
          if (home == null)
            const Padding(
              padding: EdgeInsets.all(48),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...<Widget>[
            StoreShelf(
              title: t.kitapsen_store_new_arrivals,
              books: home.newArrivals,
              onSeeAll: () => _openList(
                t.kitapsen_store_new_arrivals,
                sort: StoreSort.newest,
              ),
            ),
            StoreShelf(
              title: t.kitapsen_store_most_read,
              books: home.mostRead,
              onSeeAll: () => _openList(
                t.kitapsen_store_most_read,
                sort: StoreSort.bestselling,
              ),
            ),
            StoreShelf(
              title: t.kitapsen_store_staff_picks,
              books: home.staffPicks,
            ),
            StoreShelf(
              title: t.kitapsen_store_free_books,
              books: home.free,
              onSeeAll: () => _openList(
                t.kitapsen_store_free_books,
                freeOnly: true,
                sort: StoreSort.newest,
              ),
            ),
            StoreShelf(
              title: t.kitapsen_store_stories,
              books: home.stories,
              onSeeAll: () => _openList(
                t.kitapsen_store_stories,
                serializedOnly: true,
                sort: StoreSort.newest,
              ),
            ),
            if (home.categories.isNotEmpty) ...<Widget>[
              Padding(
                padding: EdgeInsets.fromLTRB(
                  tokens.spacing.page,
                  0,
                  tokens.spacing.page,
                  tokens.spacing.gap,
                ),
                child: Text(
                  t.kitapsen_store_categories,
                  style: tokens.type.sectionLabel,
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: tokens.spacing.page),
                child: Wrap(
                  spacing: tokens.spacing.gap,
                  runSpacing: tokens.spacing.gap,
                  children: <Widget>[
                    for (final StoreCategory c in home.categories)
                      ActionChip(
                        label: Text(c.name),
                        onPressed: () =>
                            _openList(c.name, categorySlug: c.slug),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
