/// A paged grid of catalog books: search results, a category, or a shelf's
/// "See all". Laid out like the website: a big heading (`"q" için sonuçlar`
/// for a search, with its own search box and the "Eşleşen yazarlar" cards),
/// then the cards.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fushi/src/models/app_model.dart';
import 'package:fushi/src/pages/implementations/kitapsen_store/kitapsen_author_page.dart';
import 'package:fushi/src/pages/implementations/kitapsen_store/kitapsen_store_widgets.dart';
import 'package:fushi/src/sync/kitapsen_store.dart';
import 'package:fushi/utils.dart';

String storeSortLabel(StoreSort sort) => switch (sort) {
  StoreSort.relevance => t.kitapsen_sort_relevance,
  StoreSort.newest => t.kitapsen_sort_newest,
  StoreSort.bestselling => t.kitapsen_sort_most_read,
  StoreSort.rating => t.kitapsen_sort_rating,
  StoreSort.title => t.kitapsen_sort_title,
};

class KitapsenBookListPage extends ConsumerStatefulWidget {
  const KitapsenBookListPage({
    super.key,
    required this.title,
    this.query,
    this.categorySlug,
    this.authorUserId,
    this.authorName,
    this.publisherId,
    this.freeOnly = false,
    this.serializedOnly = false,
    this.initialSort,
  });

  final String title;
  final String? query;
  final String? categorySlug;
  final int? authorUserId;

  /// Exact credited author name (books whose author has no account).
  final String? authorName;
  final int? publisherId;
  final bool freeOnly;
  final bool serializedOnly;
  final StoreSort? initialSort;

  @override
  ConsumerState<KitapsenBookListPage> createState() =>
      _KitapsenBookListPageState();
}

class _KitapsenBookListPageState extends ConsumerState<KitapsenBookListPage> {
  static const int _perPage = 30;

  late final TextEditingController _queryField = TextEditingController(
    text: widget.query,
  );
  late String? _query = widget.query;
  late StoreSort _sort =
      widget.initialSort ??
      (widget.query != null ? StoreSort.relevance : StoreSort.newest);
  late bool _freeOnly = widget.freeOnly;
  final List<StoreBook> _books = <StoreBook>[];
  List<StoreAuthorMatch> _authors = const <StoreAuthorMatch>[];
  KitapsenStore? _store;
  int _total = 0;
  int _page = 0;
  bool _loading = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadMore(reset: true));
  }

  @override
  void dispose() {
    _queryField.dispose();
    super.dispose();
  }

  Future<void> _loadMore({bool reset = false}) async {
    if (_loading) return;
    if (!reset && _page > 0 && _books.length >= _total) return;
    setState(() {
      _loading = true;
      _failed = false;
      if (reset) {
        _books.clear();
        _authors = const <StoreAuthorMatch>[];
        _page = 0;
        _total = 0;
      }
    });
    try {
      final KitapsenStore store = _store ??= await KitapsenStore.open(
        ref.read(appProvider).database,
      );
      final StoreBookPage page = await store.search(
        query: _query,
        categorySlug: widget.categorySlug,
        authorUserId: widget.authorUserId,
        authorName: widget.authorName,
        publisherId: widget.publisherId,
        freeOnly: _freeOnly,
        serializedOnly: widget.serializedOnly,
        sort: _sort,
        page: _page + 1,
        perPage: _perPage,
      );
      if (!mounted) return;
      setState(() {
        _books.addAll(page.books);
        if (_page == 0) _authors = page.authors;
        _total = page.total;
        _page++;
        // A short page means the end even if `total` disagrees.
        if (page.books.length < _perPage) _total = _books.length;
      });
    } catch (e, stack) {
      ErrorLogService.instance.log('KitapsenBookListPage.load', e, stack);
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openAuthor(StoreAuthorMatch a) => Navigator.of(context).push(
    adaptivePageRoute<void>(
      context: context,
      builder: (_) => a.username != null
          ? KitapsenAuthorPage(username: a.username!)
          : KitapsenBookListPage(title: a.name, authorName: a.name),
    ),
  );

  Widget _heading(BuildContext context) {
    final StoreColors c = StoreColors.of(context);
    final String? q = _query;
    return Text(
      q != null ? t.kitapsen_store_results_for(q: q) : widget.title,
      style: TextStyle(
        color: c.ink,
        fontSize: 26,
        fontWeight: FontWeight.w700,
        height: 1.25,
      ),
    );
  }

  Widget _searchBox(BuildContext context) {
    final StoreColors c = StoreColors.of(context);
    final OutlineInputBorder border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: c.border),
    );
    return TextField(
      key: const ValueKey<String>('kitapsen-results-search'),
      controller: _queryField,
      textInputAction: TextInputAction.search,
      onSubmitted: (String q) {
        if (q.trim().isEmpty) return;
        _query = q.trim();
        unawaited(_loadMore(reset: true));
      },
      decoration: InputDecoration(
        prefixIcon: Icon(Icons.search, color: c.muted),
        suffixIcon: IconButton(
          tooltip: t.dialog_cancel,
          icon: Icon(Icons.close, color: c.muted),
          onPressed: _queryField.clear,
        ),
        border: border,
        enabledBorder: border,
      ),
    );
  }

  Widget _filters(BuildContext context) {
    final StoreColors c = StoreColors.of(context);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: c.border),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: DropdownButton<StoreSort>(
              value: _sort,
              underline: const SizedBox.shrink(),
              borderRadius: BorderRadius.circular(12),
              style: TextStyle(color: c.ink, fontSize: 14),
              items: <DropdownMenuItem<StoreSort>>[
                for (final StoreSort s in StoreSort.values)
                  if (s != StoreSort.relevance || _query != null)
                    DropdownMenuItem<StoreSort>(
                      value: s,
                      child: Text(storeSortLabel(s)),
                    ),
              ],
              onChanged: (StoreSort? s) {
                if (s == null || s == _sort) return;
                _sort = s;
                unawaited(_loadMore(reset: true));
              },
            ),
          ),
        ),
        if (!widget.serializedOnly)
          StorePill(
            label: t.kitapsen_store_free_only,
            selected: _freeOnly,
            onTap: () {
              _freeOnly = !_freeOnly;
              unawaited(_loadMore(reset: true));
            },
          ),
      ],
    );
  }

  /// The website's "Eşleşen yazarlar" card.
  Widget _authorCard(BuildContext context, StoreAuthorMatch a) {
    final StoreColors c = StoreColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: c.border),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      StoreInitialAvatar(
                        name: a.name,
                        imageUrl: a.imageUrl,
                        radius: 40,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              a.name,
                              style: TextStyle(
                                color: c.ink,
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              t.kitapsen_store_author_books_count(
                                n: a.bookCount,
                              ),
                              style: TextStyle(color: c.muted, fontSize: 15),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    t.kitapsen_store_author_cta,
                    style: TextStyle(color: c.body, fontSize: 15, height: 1.5),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: c.accent,
                      foregroundColor: c.onAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () => _openAuthor(a),
                    child: Text(t.kitapsen_store_see_author_books),
                  ),
                ],
              ),
            ),
            if (a.books.isNotEmpty) ...<Widget>[
              Divider(height: 1, color: c.border),
              ColoredBox(
                color: Theme.of(context).brightness == Brightness.dark
                    ? c.tile
                    : const Color(0xFFF9FAFB),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: StoreSectionHeader(
                          title: t.kitapsen_store_authors_books,
                          trailing: StoreSeeAll(onTap: () => _openAuthor(a)),
                        ),
                      ),
                      const SizedBox(height: 8),
                      StoreBookRow(
                        books: a.books,
                        cardWidth: 120,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final FushiDesignTokens tokens = FushiDesignTokens.of(context);
    final StoreColors c = StoreColors.of(context);
    final EdgeInsets side = EdgeInsets.symmetric(
      horizontal: tokens.spacing.page,
    );
    return FushiPageScaffold(
      title: '',
      body: NotificationListener<ScrollNotification>(
        onNotification: (ScrollNotification n) {
          if (n.metrics.extentAfter < 600) unawaited(_loadMore());
          return false;
        },
        child: CustomScrollView(
          slivers: <Widget>[
            SliverPadding(
              padding: side,
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _heading(context),
                    const SizedBox(height: 16),
                    if (widget.query != null) ...<Widget>[
                      _searchBox(context),
                      const SizedBox(height: 16),
                    ],
                    _filters(context),
                    const SizedBox(height: 20),
                    if (_authors.isNotEmpty) ...<Widget>[
                      Text(
                        t.kitapsen_store_matching_authors,
                        style: TextStyle(
                          color: c.ink,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      for (final StoreAuthorMatch a in _authors)
                        _authorCard(context, a),
                      const SizedBox(height: 8),
                    ],
                  ],
                ),
              ),
            ),
            if (_books.isEmpty && _failed)
              SliverFillRemaining(
                hasScrollBody: false,
                child: StoreLoadError(
                  onRetry: () => unawaited(_loadMore(reset: true)),
                ),
              )
            else if (_books.isEmpty && !_loading)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: FushiPlaceholderMessage(
                    icon: Icons.search_off,
                    message: t.kitapsen_store_no_results,
                  ),
                ),
              )
            else
              SliverPadding(
                padding: side,
                sliver: SliverGrid(
                  gridDelegate: storeGridDelegate(context),
                  delegate: SliverChildBuilderDelegate(
                    (_, int i) => StoreBookCard(book: _books[i]),
                    childCount: _books.length,
                  ),
                ),
              ),
            SliverPadding(
              padding: withBottomSafeInset(context, const EdgeInsets.all(24)),
              sliver: SliverToBoxAdapter(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
