/// A paged grid of catalog books: search results, a category, or a shelf's
/// "See all".
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fushi/src/models/app_model.dart';
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
    this.freeOnly = false,
    this.serializedOnly = false,
    this.initialSort,
    this.embedded = false,
  });

  final String title;
  final String? query;
  final String? categorySlug;
  final int? authorUserId;

  /// Exact credited author name (books whose author has no account).
  final String? authorName;
  final bool freeOnly;
  final bool serializedOnly;
  final StoreSort? initialSort;

  /// Only the grid, for a page that has its own scaffold (the author page).
  final bool embedded;

  @override
  ConsumerState<KitapsenBookListPage> createState() =>
      _KitapsenBookListPageState();
}

class _KitapsenBookListPageState extends ConsumerState<KitapsenBookListPage> {
  static const int _perPage = 30;

  late StoreSort _sort =
      widget.initialSort ??
      (widget.query != null ? StoreSort.relevance : StoreSort.newest);
  late bool _freeOnly = widget.freeOnly;
  final List<StoreBook> _books = <StoreBook>[];
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

  Future<void> _loadMore({bool reset = false}) async {
    if (_loading) return;
    if (!reset && _page > 0 && _books.length >= _total) return;
    setState(() {
      _loading = true;
      _failed = false;
      if (reset) {
        _books.clear();
        _page = 0;
        _total = 0;
      }
    });
    try {
      final KitapsenStore store = _store ??= await KitapsenStore.open(
        ref.read(appProvider).database,
      );
      final StoreBookPage page = await store.search(
        query: widget.query,
        categorySlug: widget.categorySlug,
        authorUserId: widget.authorUserId,
        authorName: widget.authorName,
        freeOnly: _freeOnly,
        serializedOnly: widget.serializedOnly,
        sort: _sort,
        page: _page + 1,
        perPage: _perPage,
      );
      if (!mounted) return;
      setState(() {
        _books.addAll(page.books);
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

  Widget _filters(BuildContext context) {
    final FushiDesignTokens tokens = FushiDesignTokens.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        tokens.spacing.page,
        0,
        tokens.spacing.page,
        tokens.spacing.gap,
      ),
      child: Wrap(
        spacing: tokens.spacing.gap,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          DropdownButton<StoreSort>(
            value: _sort,
            underline: const SizedBox.shrink(),
            items: <DropdownMenuItem<StoreSort>>[
              for (final StoreSort s in StoreSort.values)
                if (s != StoreSort.relevance || widget.query != null)
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
          if (!widget.serializedOnly)
            FilterChip(
              label: Text(t.kitapsen_store_free_only),
              selected: _freeOnly,
              onSelected: (bool v) {
                _freeOnly = v;
                unawaited(_loadMore(reset: true));
              },
            ),
        ],
      ),
    );
  }

  Widget _grid(BuildContext context) {
    final FushiDesignTokens tokens = FushiDesignTokens.of(context);
    if (_books.isEmpty && _failed) {
      return StoreLoadError(onRetry: () => unawaited(_loadMore(reset: true)));
    }
    if (_books.isEmpty && !_loading) {
      return Center(
        child: FushiPlaceholderMessage(
          icon: Icons.search_off,
          message: t.kitapsen_store_no_results,
        ),
      );
    }
    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification n) {
        if (n.metrics.extentAfter < 600) unawaited(_loadMore());
        return false;
      },
      child: CustomScrollView(
        slivers: <Widget>[
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: tokens.spacing.page),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _filters(context),
        Expanded(child: _grid(context)),
      ],
    );
    if (widget.embedded) return content;
    return FushiPageScaffold(title: widget.title, body: content);
  }
}
