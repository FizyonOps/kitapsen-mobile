/// The "Mağaza" tab, laid out like the kitapsen.com home page on a phone:
/// logo and search, the hero card, the three feature rows, the reading-list
/// shelf with category pills, the book shelves and the "Keşfetmenin tam
/// zamanı" card. No prices anywhere (see `kitapsen_edition.dart`).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fushi/src/models/app_model.dart';
import 'package:fushi/src/models/home_tab.dart';
import 'package:fushi/src/pages/implementations/home_page.dart'
    show homeShellTabNotifier;
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
  late Future<(KitapsenStore, _StoreHome)> _load = _fetch();
  int _unread = 0;

  /// Reading-list category (null = "Tüm Kategoriler") and its books.
  String? _readingCategory;
  Future<List<StoreBook>>? _readingList;

  @override
  void dispose() {
    _search.dispose();
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
      })
      home,
      StoreBookPage free,
      StoreBookPage stories,
      List<StoreCategory> categories,
    ) = await (
      store.home(),
      store.search(freeOnly: true, sort: StoreSort.newest, perPage: 12),
      store.search(serializedOnly: true, sort: StoreSort.newest, perPage: 12),
      store.categories(),
    ).wait;
    _readingList = store.readingList(categorySlug: _readingCategory);
    if (store.signedIn) unawaited(_refreshUnread(store));
    return (
      store,
      _StoreHome(
        newArrivals: home.newArrivals,
        mostRead: home.bestsellers,
        staffPicks: home.staffPicks,
        free: free.books,
        stories: stories.books,
        categories: categories
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

  Future<void> _signIn() async {
    await openKitapsenSignIn(context);
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

  void _selectReadingCategory(KitapsenStore store, String? slug) {
    setState(() {
      _readingCategory = slug;
      _readingList = store.readingList(categorySlug: slug);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: FutureBuilder<(KitapsenStore, _StoreHome)>(
          future: _load,
          builder:
              (
                BuildContext context,
                AsyncSnapshot<(KitapsenStore, _StoreHome)> snapshot,
              ) {
                if (snapshot.hasError) {
                  return Column(
                    children: <Widget>[
                      _header(context, null),
                      Expanded(
                        child: StoreLoadError(
                          onRetry: () => unawaited(_reload()),
                        ),
                      ),
                    ],
                  );
                }
                final (KitapsenStore, _StoreHome)? data = snapshot.data;
                return RefreshIndicator(
                  onRefresh: _reload,
                  child: ListView(
                    padding: withBottomSafeInset(
                      context,
                      const EdgeInsets.only(bottom: 24),
                    ),
                    children: <Widget>[
                      _header(context, data?.$1),
                      if (data == null)
                        const Padding(
                          padding: EdgeInsets.all(48),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else
                        ..._sections(context, data.$1, data.$2),
                    ],
                  ),
                );
              },
        ),
      ),
    );
  }

  /// Logo and account actions, then the rounded search box — the website's
  /// phone header.
  Widget _header(BuildContext context, KitapsenStore? store) {
    final StoreColors c = StoreColors.of(context);
    final FushiDesignTokens tokens = FushiDesignTokens.of(context);
    final bool signedIn = store?.signedIn ?? false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: EdgeInsets.fromLTRB(tokens.spacing.page, 8, 8, 8),
          child: Row(
            children: <Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.asset(
                  'assets/meta/icon.png',
                  width: 44,
                  height: 44,
                ),
              ),
              const Spacer(),
              if (signedIn) ...<Widget>[
                IconButton(
                  key: const ValueKey<String>('kitapsen-store-following'),
                  tooltip: t.kitapsen_following_title,
                  icon: Icon(Icons.people_outline, color: c.ink),
                  onPressed: () => _push(const KitapsenFollowingPage()),
                ),
                IconButton(
                  key: const ValueKey<String>('kitapsen-store-wishlist'),
                  tooltip: t.kitapsen_wishlist_title,
                  icon: Icon(Icons.favorite_border, color: c.ink),
                  onPressed: () => _push(const KitapsenWishlistPage()),
                ),
                IconButton(
                  key: const ValueKey<String>('kitapsen-store-notifications'),
                  tooltip: t.kitapsen_notifications_title,
                  icon: Badge(
                    isLabelVisible: _unread > 0,
                    label: Text('$_unread'),
                    backgroundColor: c.accent,
                    child: Icon(Icons.notifications_none, color: c.ink),
                  ),
                  onPressed: () => _push(const KitapsenNotificationsPage()),
                ),
              ] else
                IconButton(
                  key: const ValueKey<String>('kitapsen-store-sign-in'),
                  tooltip: t.kitapsen_account_sign_in,
                  icon: Icon(Icons.person_outline, color: c.ink),
                  onPressed: _signIn,
                ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            tokens.spacing.page,
            0,
            tokens.spacing.page,
            12,
          ),
          child: TextField(
            key: const ValueKey<String>('kitapsen-store-search'),
            controller: _search,
            textInputAction: TextInputAction.search,
            onSubmitted: (String q) {
              if (q.trim().isEmpty) return;
              _openList(q.trim(), query: q.trim());
            },
            decoration: InputDecoration(
              hintText: t.search,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 14,
              ),
              suffixIcon: Icon(Icons.search, color: c.muted),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(999),
                borderSide: BorderSide(color: c.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(999),
                borderSide: BorderSide(color: c.border),
              ),
            ),
          ),
        ),
        Divider(height: 1, color: c.border),
        const SizedBox(height: 20),
      ],
    );
  }

  List<Widget> _sections(
    BuildContext context,
    KitapsenStore store,
    _StoreHome home,
  ) {
    final StoreColors c = StoreColors.of(context);
    final FushiDesignTokens tokens = FushiDesignTokens.of(context);
    final List<StoreBook> heroBooks = <StoreBook>[
      ...home.mostRead,
      ...home.newArrivals,
    ].where((StoreBook b) => b.coverUrl != null).take(6).toList();
    return <Widget>[
      _HeroCard(
        books: heroBooks,
        onExplore: () =>
            _openList(t.kitapsen_store_explore_books, sort: StoreSort.newest),
        onStartFree: () => _openList(
          t.kitapsen_store_free_books,
          freeOnly: true,
          sort: StoreSort.newest,
        ),
      ),
      const SizedBox(height: 16),
      _featureRow(
        context,
        icon: Icons.local_library_outlined,
        title: t.kitapsen_store_start_free,
        body: t.kitapsen_store_start_free_body,
        onTap: () => _openList(
          t.kitapsen_store_free_books,
          freeOnly: true,
          sort: StoreSort.newest,
        ),
      ),
      _featureRow(
        context,
        icon: Icons.menu_book_outlined,
        title: t.kitapsen_store_library_always,
        body: t.kitapsen_store_library_always_body,
        onTap: () => homeShellTabNotifier.value = HomeTab.books,
      ),
      _featureRow(
        context,
        icon: Icons.people_outline,
        title: t.kitapsen_store_meet_authors,
        body: t.kitapsen_store_meet_authors_body,
        onTap: () =>
            store.signedIn ? _push(const KitapsenFollowingPage()) : _signIn(),
      ),
      Padding(
        padding: EdgeInsets.symmetric(horizontal: tokens.spacing.page),
        child: Divider(height: 40, color: c.border),
      ),
      ..._readingListSection(context, store, home),
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
        title: t.kitapsen_store_most_read,
        books: home.mostRead,
        onSeeAll: () =>
            _openList(t.kitapsen_store_most_read, sort: StoreSort.bestselling),
      ),
      StoreShelf(
        title: t.kitapsen_store_new_arrivals,
        books: home.newArrivals,
        badge: StoreBadge(t.kitapsen_store_badge_new, c.blueText),
        onSeeAll: () =>
            _openList(t.kitapsen_store_new_arrivals, sort: StoreSort.newest),
      ),
      _DiscoverCard(
        books: heroBooks,
        onDiscover: () =>
            _openList(t.kitapsen_store_explore_books, sort: StoreSort.newest),
      ),
      StoreShelf(title: t.kitapsen_store_staff_picks, books: home.staffPicks),
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
          padding: EdgeInsets.symmetric(horizontal: tokens.spacing.page),
          child: StoreSectionHeader(title: t.kitapsen_store_categories),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: tokens.spacing.page),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final StoreCategory cat in home.categories)
                StorePill(
                  label: cat.name,
                  onTap: () => _openList(cat.name, categorySlug: cat.slug),
                ),
            ],
          ),
        ),
      ],
    ];
  }

  Widget _featureRow(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String body,
    required VoidCallback onTap,
  }) {
    final StoreColors c = StoreColors.of(context);
    final FushiDesignTokens tokens = FushiDesignTokens.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: tokens.spacing.page,
          vertical: 12,
        ),
        child: Row(
          children: <Widget>[
            Icon(icon, color: c.ink, size: 26),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: TextStyle(
                      color: c.ink,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(body, style: TextStyle(color: c.muted, fontSize: 13)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: c.ink),
          ],
        ),
      ),
    );
  }

  List<Widget> _readingListSection(
    BuildContext context,
    KitapsenStore store,
    _StoreHome home,
  ) {
    final FushiDesignTokens tokens = FushiDesignTokens.of(context);
    final String? selected = _readingCategory;
    final StoreCategory? selectedCategory = selected == null
        ? null
        : home.categories
              .where((StoreCategory cat) => cat.slug == selected)
              .firstOrNull;
    return <Widget>[
      Padding(
        padding: EdgeInsets.symmetric(horizontal: tokens.spacing.page),
        child: StoreSectionHeader(
          title: t.kitapsen_store_reading_list,
          trailing: StoreSeeAll(
            onTap: () => _openList(
              selectedCategory?.name ?? t.kitapsen_store_explore_books,
              categorySlug: selected,
              sort: StoreSort.newest,
            ),
          ),
        ),
      ),
      const SizedBox(height: 12),
      SizedBox(
        height: 44,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: tokens.spacing.page),
          children: <Widget>[
            StorePill(
              label: t.kitapsen_store_all_categories,
              selected: selected == null,
              onTap: () => _selectReadingCategory(store, null),
            ),
            for (final StoreCategory cat in home.categories) ...<Widget>[
              const SizedBox(width: 8),
              StorePill(
                label: cat.name,
                selected: selected == cat.slug,
                onTap: () => _selectReadingCategory(store, cat.slug),
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 16),
      FutureBuilder<List<StoreBook>>(
        future: _readingList,
        builder: (BuildContext context, AsyncSnapshot<List<StoreBook>> s) {
          final List<StoreBook>? books = s.data;
          if (books == null) {
            return SizedBox(
              height: StoreBookCard.heightFor(context, StoreShelf.cardWidth),
              child: s.hasError
                  ? Center(child: Text(t.kitapsen_store_no_results))
                  : const Center(child: CircularProgressIndicator()),
            );
          }
          if (books.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Center(child: Text(t.kitapsen_store_no_results)),
            );
          }
          return StoreBookRow(books: books);
        },
      ),
      SizedBox(height: tokens.spacing.section * 1.5),
    ];
  }
}

/// The website's light hero card: serif headline, the two calls to action
/// and a swipeable row of covers.
class _HeroCard extends StatefulWidget {
  const _HeroCard({
    required this.books,
    required this.onExplore,
    required this.onStartFree,
  });

  final List<StoreBook> books;
  final VoidCallback onExplore;
  final VoidCallback onStartFree;

  @override
  State<_HeroCard> createState() => _HeroCardState();
}

class _HeroCardState extends State<_HeroCard> {
  final PageController _pages = PageController(viewportFraction: 0.42);
  int _index = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final StoreColors c = StoreColors.of(context);
    final FushiDesignTokens tokens = FushiDesignTokens.of(context);
    final List<StoreBook> books = widget.books;
    final StoreBook? current = books.isEmpty
        ? null
        : books[_index.clamp(0, books.length - 1)];
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: tokens.spacing.page),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: c.hero,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                t.kitapsen_store_hero_title,
                style: TextStyle(
                  fontFamily: kStoreSerif,
                  fontFamilyFallback: kStoreSerifFallback,
                  color: c.ink,
                  fontSize: 32,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                t.kitapsen_store_hero_body,
                style: TextStyle(color: c.body, fontSize: 16, height: 1.55),
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 16,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  FilledButton(
                    key: const ValueKey<String>('kitapsen-store-explore'),
                    style: FilledButton.styleFrom(
                      backgroundColor: c.accent,
                      foregroundColor: c.onAccent,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: widget.onExplore,
                    child: Text(t.kitapsen_store_explore_books),
                  ),
                  InkWell(
                    onTap: widget.onStartFree,
                    child: Text(
                      t.kitapsen_store_start_free,
                      style: TextStyle(
                        color: c.ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
              if (current != null) ...<Widget>[
                const SizedBox(height: 28),
                SizedBox(
                  height: 220,
                  child: PageView.builder(
                    controller: _pages,
                    itemCount: books.length,
                    onPageChanged: (int i) => setState(() => _index = i),
                    itemBuilder: (_, int i) => AnimatedScale(
                      scale: i == _index ? 1 : 0.82,
                      duration: const Duration(milliseconds: 200),
                      child: GestureDetector(
                        onTap: () => openStoreBook(context, books[i].id),
                        child: Center(
                          child: StoreCover(
                            url: books[i].coverUrl,
                            shadow: true,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    current.title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: c.ink,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (current.authorName != null)
                  Center(
                    child: Text(
                      current.authorName!,
                      style: TextStyle(color: c.muted, fontSize: 13),
                    ),
                  ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    for (int i = 0; i < books.length; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: i == _index ? 22 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: i == _index ? c.accent : c.border,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The website's dark "Keşfetmenin tam zamanı" card with fanned covers.
class _DiscoverCard extends StatelessWidget {
  const _DiscoverCard({required this.books, required this.onDiscover});

  final List<StoreBook> books;
  final VoidCallback onDiscover;

  @override
  Widget build(BuildContext context) {
    final StoreColors c = StoreColors.of(context);
    final FushiDesignTokens tokens = FushiDesignTokens.of(context);
    final List<StoreBook> fan = books.take(5).toList();
    return Padding(
      padding: EdgeInsets.fromLTRB(
        tokens.spacing.page,
        0,
        tokens.spacing.page,
        tokens.spacing.section * 1.5,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: ColoredBox(
          color: c.navy,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      t.kitapsen_store_discover_title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      t.kitapsen_store_discover_body,
                      style: const TextStyle(
                        color: Color(0xFFCBD5E1),
                        fontSize: 15,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: c.navy,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: onDiscover,
                      child: Text(t.kitapsen_store_discover_now),
                    ),
                  ],
                ),
              ),
              if (fan.isNotEmpty)
                SizedBox(
                  height: 170,
                  child: LayoutBuilder(
                    builder: (BuildContext context, BoxConstraints box) {
                      const double coverWidth = 92;
                      final double step = fan.length > 1
                          ? (box.maxWidth - coverWidth - 16) / (fan.length - 1)
                          : 0;
                      return Stack(
                        clipBehavior: Clip.hardEdge,
                        children: <Widget>[
                          for (int i = 0; i < fan.length; i++)
                            Positioned(
                              left: 8 + i * step,
                              bottom: -24,
                              width: coverWidth,
                              child: Transform.rotate(
                                angle: (i - (fan.length - 1) / 2) * 0.08,
                                child: StoreCover(
                                  url: fan[i].coverUrl,
                                  shadow: true,
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
