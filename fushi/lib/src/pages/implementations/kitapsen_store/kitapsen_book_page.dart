/// A store book: details, the library action (read / get for free), wishlist,
/// chapters of a serialized story, and reviews.
///
/// No price and no purchase path (store policy, see [kKitapsenEdition]): a
/// paid book that is not in the library only offers the wishlist.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fushi_core/fushi_core.dart';

import 'package:fushi/src/media/media_item.dart';
import 'package:fushi/src/media/sources/reader_fushi_source.dart';
import 'package:fushi/src/models/app_model.dart';
import 'package:fushi/src/models/home_tab.dart';
import 'package:fushi/src/pages/implementations/home_page.dart'
    show homeShellTabNotifier;
import 'package:fushi/src/pages/implementations/kitapsen_store/kitapsen_author_page.dart';
import 'package:fushi/src/pages/implementations/kitapsen_store/kitapsen_book_list_page.dart';
import 'package:fushi/src/pages/implementations/kitapsen_store/kitapsen_chapter_page.dart';
import 'package:fushi/src/pages/implementations/kitapsen_store/kitapsen_store_widgets.dart';
import 'package:fushi/src/sync/kitapsen_store.dart';
import 'package:fushi/src/sync/remote_library_cache.dart';
import 'package:fushi/src/sync/remote_library_source.dart';
import 'package:fushi/src/sync/sync_backend.dart'
    show SyncAuthError, SyncBackendError;
import 'package:fushi/utils.dart';

class _BookState {
  _BookState({
    required this.store,
    required this.detail,
    required this.owned,
    required this.wishlisted,
    required this.localBookKey,
    required this.chapters,
  });

  final KitapsenStore store;
  final StoreBookDetail detail;
  bool owned;
  bool wishlisted;

  /// Set when the book is already downloaded to this device.
  final String? localBookKey;
  final List<StoreChapter> chapters;
}

class KitapsenBookPage extends ConsumerStatefulWidget {
  const KitapsenBookPage({super.key, required this.bookId});

  final int bookId;

  @override
  ConsumerState<KitapsenBookPage> createState() => _KitapsenBookPageState();
}

class _KitapsenBookPageState extends ConsumerState<KitapsenBookPage> {
  late Future<_BookState> _load = _fetch();
  final List<StoreReview> _reviews = <StoreReview>[];
  int _reviewPage = 0;
  bool _moreReviews = false;
  bool _busy = false;

  Future<_BookState> _fetch() async {
    final KitapsenStore store = await KitapsenStore.open(
      ref.read(appProvider).database,
    );
    final StoreBookDetail detail = await store.book(widget.bookId);
    bool owned = false;
    bool wishlisted = false;
    String? localBookKey;
    if (store.signedIn) {
      (owned, wishlisted) = await (
        store.owns(widget.bookId),
        store.inWishlist(widget.bookId),
      ).wait;
      for (final ({int bookId, EpubBookRow book}) d
          in await store.client!.downloadedBooks()) {
        if (d.bookId == widget.bookId) localBookKey = d.book.bookKey;
      }
    }
    final List<StoreChapter> chapters = detail.isSerialized
        ? await store.chapters(widget.bookId)
        : const <StoreChapter>[];
    _reviews.clear();
    _reviewPage = 0;
    unawaited(_loadReviews(store));
    return _BookState(
      store: store,
      detail: detail,
      owned: owned,
      wishlisted: wishlisted,
      localBookKey: localBookKey,
      chapters: chapters,
    );
  }

  Future<void> _loadReviews(KitapsenStore store) async {
    try {
      final ({List<StoreReview> reviews, bool hasMore}) page = await store
          .reviews(widget.bookId, page: _reviewPage + 1);
      if (!mounted) return;
      setState(() {
        _reviews.addAll(page.reviews);
        _moreReviews = page.hasMore;
        _reviewPage++;
      });
    } catch (e, stack) {
      ErrorLogService.instance.log('KitapsenBookPage.reviews', e, stack);
    }
  }

  void _reload() => setState(() => _load = _fetch());

  void _toast(String msg, {ToastSeverity severity = ToastSeverity.neutral}) =>
      FushiToast.show(msg: msg, severity: severity);

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (e, stack) {
      ErrorLogService.instance.log('KitapsenBookPage.action', e, stack);
      _toast(t.kitapsen_book_action_failed, severity: ToastSeverity.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _claim(_BookState s) => _run(() async {
    await s.store.claimFree(widget.bookId);
    ref
        .read(remoteLibraryCacheProvider)
        .invalidateSource(kKitapsenRemoteLibrarySourceId);
    if (!mounted) return;
    setState(() => s.owned = true);
    _toast(t.kitapsen_book_claimed, severity: ToastSeverity.success);
  });

  /// Opens a downloaded book in the reader; otherwise hands the download to
  /// the Books tab, which owns the download pipeline and its progress card.
  Future<void> _read(_BookState s) async {
    final String? key = s.localBookKey;
    if (key != null) {
      final AppModel appModel = ref.read(appProvider);
      final MediaItem? item = await ReaderFushiSource.instance
          .mediaItemForBookKey(key);
      if (item != null && mounted) {
        await appModel.openMedia(
          ref: ref,
          mediaSource: item.getMediaSource(appModel: appModel),
          item: item,
        );
        return;
      }
    }
    if (!mounted) return;
    ref
        .read(remoteLibraryCacheProvider)
        .invalidateSource(kKitapsenRemoteLibrarySourceId);
    kitapsenShelfDownloadRequest.value = '${widget.bookId}';
    Navigator.of(context).popUntil((Route<dynamic> r) => r.isFirst);
    homeShellTabNotifier.value = HomeTab.books;
    _toast(t.kitapsen_book_downloading);
  }

  Future<void> _toggleWishlist(_BookState s) => _run(() async {
    await s.store.setWishlisted(widget.bookId, !s.wishlisted);
    if (mounted) setState(() => s.wishlisted = !s.wishlisted);
  });

  Future<void> _signIn() async {
    await openKitapsenSignIn(context);
    if (mounted) _reload();
  }

  Future<void> _writeReview(_BookState s) async {
    final ({int rating, String title, String content})? review =
        await showAppDialog<({int rating, String title, String content})>(
          context: context,
          builder: (_) => const _ReviewDialog(),
        );
    if (review == null || !mounted) return;
    try {
      await s.store.addReview(
        widget.bookId,
        rating: review.rating,
        title: review.title,
        content: review.content,
      );
      _toast(t.kitapsen_review_sent, severity: ToastSeverity.success);
      _reviews.clear();
      _reviewPage = 0;
      await _loadReviews(s.store);
    } on SyncAuthError catch (e) {
      _toast(
        e.isForbidden
            ? t.kitapsen_review_not_allowed
            : t.kitapsen_book_action_failed,
        severity: ToastSeverity.error,
      );
    } on SyncBackendError catch (e) {
      _toast(
        e.message.contains('HTTP 422')
            ? t.kitapsen_review_already
            : t.kitapsen_book_action_failed,
        severity: ToastSeverity.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_BookState>(
      future: _load,
      builder: (BuildContext context, AsyncSnapshot<_BookState> snapshot) {
        final _BookState? s = snapshot.data;
        return FushiPageScaffold(
          title: s?.detail.book.title ?? '',
          body: snapshot.hasError
              ? StoreLoadError(onRetry: _reload)
              : s == null
              ? const Center(child: CircularProgressIndicator())
              : _content(context, s),
        );
      },
    );
  }

  Widget _content(BuildContext context, _BookState s) {
    final FushiDesignTokens tokens = FushiDesignTokens.of(context);
    final StoreBookDetail d = s.detail;
    return ListView(
      padding: withBottomSafeInset(
        context,
        EdgeInsets.all(tokens.spacing.page),
      ),
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SizedBox(width: 120, child: StoreCover(url: d.book.coverUrl)),
            SizedBox(width: tokens.spacing.page),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(d.book.title, style: tokens.type.pageTitle),
                  if (d.subtitle != null)
                    Text(d.subtitle!, style: tokens.type.listSubtitle),
                  if (d.book.authorName != null) ...<Widget>[
                    const SizedBox(height: 6),
                    InkWell(
                      // The author's page when the credited author is the
                      // uploading account, otherwise their other books.
                      onTap: () => Navigator.of(context).push(
                        adaptivePageRoute<void>(
                          context: context,
                          builder: (_) => d.authorUsername != null
                              ? KitapsenAuthorPage(username: d.authorUsername!)
                              : KitapsenBookListPage(
                                  title: d.book.authorName!,
                                  authorName: d.book.authorName,
                                ),
                        ),
                      ),
                      child: Text(
                        d.book.authorName!,
                        style: tokens.type.listTitle.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                  if (d.book.ratingCount > 0) ...<Widget>[
                    const SizedBox(height: 6),
                    StoreRating(
                      rating: d.book.averageRating,
                      count: d.book.ratingCount,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: tokens.spacing.section),
        _actions(context, s),
        if (d.description != null) ...<Widget>[
          SizedBox(height: tokens.spacing.section),
          Text(t.kitapsen_book_about, style: tokens.type.sectionLabel),
          const SizedBox(height: 6),
          Text(d.description!),
        ],
        SizedBox(height: tokens.spacing.section),
        _facts(context, d),
        if (d.categories.isNotEmpty) ...<Widget>[
          SizedBox(height: tokens.spacing.gap),
          Wrap(
            spacing: tokens.spacing.gap,
            runSpacing: tokens.spacing.gap,
            children: <Widget>[
              for (final ({String name, String slug}) c in d.categories)
                ActionChip(
                  label: Text(c.name),
                  onPressed: () => Navigator.of(context).push(
                    adaptivePageRoute<void>(
                      context: context,
                      builder: (_) => KitapsenBookListPage(
                        title: c.name,
                        categorySlug: c.slug,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
        if (d.isSerialized) ..._chapters(context, s),
        ..._reviewSection(context, s),
      ],
    );
  }

  Widget _actions(BuildContext context, _BookState s) {
    final StoreBookDetail d = s.detail;
    final FushiDesignTokens tokens = FushiDesignTokens.of(context);
    if (!s.store.signedIn) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(t.kitapsen_book_sign_in_prompt, style: tokens.type.metadata),
          const SizedBox(height: 8),
          FilledButton.icon(
            key: const ValueKey<String>('kitapsen-book-sign-in'),
            onPressed: _signIn,
            icon: const Icon(Icons.login),
            label: Text(t.kitapsen_account_sign_in),
          ),
        ],
      );
    }
    final Widget? primary = d.isSerialized
        ? null
        : s.owned
        ? FilledButton.icon(
            key: const ValueKey<String>('kitapsen-book-read'),
            onPressed: _busy ? null : () => _read(s),
            icon: const Icon(Icons.chrome_reader_mode_outlined),
            label: Text(t.kitapsen_book_read),
          )
        : d.isFree
        ? FilledButton.icon(
            key: const ValueKey<String>('kitapsen-book-get-free'),
            onPressed: _busy ? null : () => _claim(s),
            icon: const Icon(Icons.library_add_outlined),
            label: Text(t.kitapsen_book_get_free),
          )
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (!d.isSerialized)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: <Widget>[
                Icon(
                  s.owned ? Icons.check_circle_outline : Icons.info_outline,
                  size: 18,
                  color: tokens.surfaces.onVariant,
                ),
                const SizedBox(width: 6),
                Text(
                  s.owned
                      ? t.kitapsen_book_in_library
                      : t.kitapsen_book_not_in_library,
                  style: tokens.type.metadata,
                ),
              ],
            ),
          ),
        ?primary,
        if (!s.owned) ...<Widget>[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            key: const ValueKey<String>('kitapsen-book-wishlist'),
            onPressed: _busy ? null : () => _toggleWishlist(s),
            icon: Icon(s.wishlisted ? Icons.favorite : Icons.favorite_border),
            label: Text(
              s.wishlisted
                  ? t.kitapsen_book_wishlist_remove
                  : t.kitapsen_book_wishlist_add,
            ),
          ),
        ],
      ],
    );
  }

  Widget _facts(BuildContext context, StoreBookDetail d) {
    final FushiDesignTokens tokens = FushiDesignTokens.of(context);
    final List<(String, String)> rows = <(String, String)>[
      if (d.publisherName != null)
        (t.kitapsen_book_publisher, d.publisherName!),
      if (d.pageCount != null && d.pageCount! > 0)
        (t.kitapsen_book_pages, '${d.pageCount}'),
      if (d.language != null)
        (t.kitapsen_book_language, d.language!.toUpperCase()),
      if (d.publishingDate != null)
        (t.kitapsen_book_published, d.publishingDate!.split('T').first),
    ];
    return Column(
      children: <Widget>[
        for (final (String label, String value) in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: <Widget>[
                SizedBox(
                  width: 110,
                  child: Text(label, style: tokens.type.metadata),
                ),
                Expanded(child: Text(value)),
              ],
            ),
          ),
      ],
    );
  }

  List<Widget> _chapters(BuildContext context, _BookState s) {
    final FushiDesignTokens tokens = FushiDesignTokens.of(context);
    return <Widget>[
      SizedBox(height: tokens.spacing.section),
      Text(t.kitapsen_story_chapters, style: tokens.type.sectionLabel),
      if (s.chapters.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            t.kitapsen_story_no_chapters,
            style: tokens.type.metadata,
          ),
        ),
      for (int i = 0; i < s.chapters.length; i++)
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Text(
            '${s.chapters[i].number}.',
            style: tokens.type.listTitle,
          ),
          title: Text(s.chapters[i].title),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(
            adaptivePageRoute<void>(
              context: context,
              builder: (_) => KitapsenChapterPage(
                store: s.store,
                bookId: widget.bookId,
                bookTitle: s.detail.book.title,
                chapters: s.chapters,
                index: i,
              ),
            ),
          ),
        ),
    ];
  }

  List<Widget> _reviewSection(BuildContext context, _BookState s) {
    final FushiDesignTokens tokens = FushiDesignTokens.of(context);
    return <Widget>[
      SizedBox(height: tokens.spacing.section),
      Row(
        children: <Widget>[
          Expanded(
            child: Text(
              t.kitapsen_book_reviews,
              style: tokens.type.sectionLabel,
            ),
          ),
          // The server takes reviews only from readers holding a license.
          if (s.store.signedIn && s.owned)
            TextButton.icon(
              key: const ValueKey<String>('kitapsen-book-write-review'),
              onPressed: () => _writeReview(s),
              icon: const Icon(Icons.rate_review_outlined),
              label: Text(t.kitapsen_book_write_review),
            ),
        ],
      ),
      if (_reviews.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(t.kitapsen_book_no_reviews, style: tokens.type.metadata),
        ),
      for (final StoreReview r in _reviews)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  StoreRating(rating: r.rating.toDouble(), size: 14),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      r.userName,
                      style: tokens.type.metadata,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (r.verified)
                    Text(
                      t.kitapsen_review_verified,
                      style: tokens.type.metadata,
                    ),
                ],
              ),
              if (r.title != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(r.title!, style: tokens.type.listTitle),
                ),
              if (r.content != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(r.content!),
                ),
            ],
          ),
        ),
      if (_moreReviews)
        TextButton(
          onPressed: () => _loadReviews(s.store),
          child: Text(t.kitapsen_review_more),
        ),
    ];
  }
}

class _ReviewDialog extends StatefulWidget {
  const _ReviewDialog();

  @override
  State<_ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<_ReviewDialog> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _content = TextEditingController();
  int _rating = 0;

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color color = Theme.of(context).colorScheme.primary;
    return AlertDialog(
      title: Text(t.kitapsen_book_write_review),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                for (int i = 1; i <= 5; i++)
                  IconButton(
                    key: ValueKey<String>('kitapsen-review-star-$i'),
                    onPressed: () => setState(() => _rating = i),
                    icon: Icon(
                      _rating >= i ? Icons.star : Icons.star_border,
                      color: color,
                    ),
                  ),
              ],
            ),
            TextField(
              controller: _title,
              maxLength: 200,
              decoration: InputDecoration(
                labelText: t.kitapsen_review_title_hint,
              ),
            ),
            TextField(
              controller: _content,
              minLines: 3,
              maxLines: 8,
              decoration: InputDecoration(
                labelText: t.kitapsen_review_content_hint,
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(t.dialog_cancel),
        ),
        FilledButton(
          onPressed: _rating == 0
              ? null
              : () => Navigator.pop(context, (
                  rating: _rating,
                  title: _title.text,
                  content: _content.text,
                )),
          child: Text(t.kitapsen_review_submit),
        ),
      ],
    );
  }
}
