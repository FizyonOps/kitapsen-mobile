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
import 'package:fushi/src/pages/implementations/kitapsen_store/kitapsen_collections_pages.dart';
import 'package:fushi/src/pages/implementations/kitapsen_store/kitapsen_directory_pages.dart';
import 'package:fushi/src/pages/implementations/kitapsen_store/kitapsen_chapter_page.dart';
import 'package:fushi/src/pages/implementations/kitapsen_store/kitapsen_comments_page.dart';
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

  /// Serialized stories only.
  ({int followers, bool following})? storyFollow;
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

  /// Likes changed on this page, by review id (the list itself is not
  /// reloaded for a like).
  final Map<int, ({int likes, bool liked})> _likes =
      <int, ({int likes, bool liked})>{};
  bool _moreReviews = false;
  bool _busy = false;

  /// The reader's own account id (no "Bildir" on their own reviews) and the
  /// reviews they reported on this page.
  int? _viewerId;
  final Set<int> _reportedReviews = <int>{};

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
    final ({int followers, bool following})? storyFollow = detail.isSerialized
        ? await store.storyFollow(widget.bookId)
        : null;
    _reviews.clear();
    _reviewPage = 0;
    unawaited(_loadReviews(store));
    unawaited(
      store.viewerId().then((int? id) {
        if (mounted && id != null) setState(() => _viewerId = id);
      }),
    );
    return _BookState(
      store: store,
      detail: detail,
      owned: owned,
      wishlisted: wishlisted,
      localBookKey: localBookKey,
      chapters: chapters,
    )..storyFollow = storyFollow;
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

  Future<void> _claimAndRead(_BookState s) async {
    await _claim(s);
    if (mounted && s.owned) await _read(s);
  }

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

  Future<void> _toggleLike(KitapsenStore store, StoreReview r) =>
      _run(() async {
        final ({int likes, bool liked}) state = await store.toggleReviewLike(
          r.id,
        );
        if (mounted) setState(() => _likes[r.id] = state);
      });

  Future<void> _reportReview(KitapsenStore store, StoreReview r) async {
    final bool sent = await showStoreReport(
      context,
      (String? reason) => store.reportReview(r.id, reason),
    );
    if (sent && mounted) setState(() => _reportedReviews.add(r.id));
  }

  Future<void> _openComments({
    required Future<List<StoreComment>> Function() load,
    Future<void> Function(String)? add,
    Future<void> Function(int commentId, String? reason)? report,
    Future<int?>? viewerId,
    String? subtitle,
  }) => Navigator.of(context).push(
    adaptivePageRoute<void>(
      context: context,
      builder: (_) => KitapsenCommentsPage(
        load: load,
        add: add,
        report: report,
        viewerId: viewerId,
        subtitle: subtitle,
      ),
    ),
  );

  Future<void> _toggleStoryFollow(_BookState s) => _run(() async {
    final bool follow = !(s.storyFollow?.following ?? false);
    await s.store.setStoryFollow(widget.bookId, follow);
    final ({int followers, bool following}) now = await s.store.storyFollow(
      widget.bookId,
    );
    if (mounted) setState(() => s.storyFollow = now);
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
        // The title sits under the cover, as on the website.
        return FushiPageScaffold(
          title: '',
          body: snapshot.hasError
              ? StoreLoadError(onRetry: _reload)
              : s == null
              ? const Center(child: CircularProgressIndicator())
              : _content(context, s),
        );
      },
    );
  }

  void _openAuthor(StoreBookDetail d) => Navigator.of(context).push(
    adaptivePageRoute<void>(
      context: context,
      // The author's page when the credited author is the uploading
      // account, otherwise their other books.
      builder: (_) => d.authorUsername != null
          ? KitapsenAuthorPage(username: d.authorUsername!)
          : KitapsenBookListPage(
              title: d.book.authorName!,
              authorName: d.book.authorName,
            ),
    ),
  );

  /// Website heading style (bold, ink) for the page's sections.
  Widget _heading(BuildContext context, String text) => Text(
    text,
    style: TextStyle(
      color: StoreColors.of(context).ink,
      fontSize: 20,
      fontWeight: FontWeight.w700,
    ),
  );

  Widget _content(BuildContext context, _BookState s) {
    final StoreColors c = StoreColors.of(context);
    final FushiDesignTokens tokens = FushiDesignTokens.of(context);
    final StoreBookDetail d = s.detail;
    final double coverWidth =
        (MediaQuery.sizeOf(context).width - 2 * tokens.spacing.page)
            .clamp(0, 320)
            .toDouble();
    return ListView(
      padding: withBottomSafeInset(
        context,
        EdgeInsets.all(tokens.spacing.page),
      ),
      children: <Widget>[
        Center(
          child: SizedBox(
            width: coverWidth,
            child: StoreCover(url: d.book.coverUrl, shadow: true),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          d.book.title,
          style: TextStyle(
            color: c.ink,
            fontSize: 26,
            fontWeight: FontWeight.w700,
            height: 1.25,
          ),
        ),
        if (d.subtitle != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              d.subtitle!,
              style: TextStyle(color: c.body, fontSize: 16),
            ),
          ),
        if (d.book.authorName != null) ...<Widget>[
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: Material(
              color: c.tile,
              borderRadius: BorderRadius.circular(999),
              child: InkWell(
                key: const ValueKey<String>('kitapsen-book-author'),
                borderRadius: BorderRadius.circular(999),
                onTap: () => _openAuthor(d),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(6, 6, 16, 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      StoreInitialAvatar(name: d.book.authorName!),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          d.book.authorName!,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: c.ink,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        StoreRating(rating: d.book.averageRating, count: d.book.ratingCount),
        const SizedBox(height: 20),
        _actions(context, s),
        const SizedBox(height: 24),
        _facts(context, d),
        if (d.description != null) ...<Widget>[
          const SizedBox(height: 28),
          _heading(context, t.kitapsen_book_description),
          const SizedBox(height: 12),
          Text(
            d.description!,
            style: TextStyle(color: c.body, fontSize: 16, height: 1.6),
          ),
        ],
        if (d.authorBio != null) ...<Widget>[
          const SizedBox(height: 28),
          DecoratedBox(
            decoration: BoxDecoration(
              color: c.tile,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: c.border),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _heading(context, t.kitapsen_book_about_author),
                  if (d.book.authorName != null) ...<Widget>[
                    const SizedBox(height: 12),
                    Text(
                      d.book.authorName!,
                      style: TextStyle(
                        color: c.ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    d.authorBio!,
                    style: TextStyle(color: c.body, fontSize: 14, height: 1.5),
                  ),
                ],
              ),
            ),
          ),
        ],
        if (d.categories.isNotEmpty) ...<Widget>[
          const SizedBox(height: 24),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final ({String name, String slug}) cat in d.categories)
                StorePill(
                  label: cat.name,
                  onTap: () => Navigator.of(context).push(
                    adaptivePageRoute<void>(
                      context: context,
                      builder: (_) => KitapsenBookListPage(
                        title: cat.name,
                        categorySlug: cat.slug,
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

  /// The website's purchase card, minus the price: "Şimdi Oku" (green),
  /// "Ücretsiz Edin" for a free book not yet in the library, and the
  /// "Favoriler" (wishlist) toggle.
  Widget _actions(BuildContext context, _BookState s) {
    final StoreColors c = StoreColors.of(context);
    final StoreBookDetail d = s.detail;
    final ButtonStyle readStyle = FilledButton.styleFrom(
      backgroundColor: c.green,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
    final ButtonStyle outlineStyle = OutlinedButton.styleFrom(
      foregroundColor: c.ink,
      side: BorderSide(color: c.border),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
    final List<Widget> children;
    if (!s.store.signedIn) {
      children = <Widget>[
        Text(
          t.kitapsen_book_sign_in_prompt,
          style: TextStyle(color: c.body, fontSize: 14),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          key: const ValueKey<String>('kitapsen-book-sign-in'),
          style: FilledButton.styleFrom(
            backgroundColor: c.accent,
            foregroundColor: c.onAccent,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: _signIn,
          icon: const Icon(Icons.login),
          label: Text(t.kitapsen_account_sign_in),
        ),
      ];
    } else {
      children = <Widget>[
        if (d.isFree && !d.isSerialized) ...<Widget>[
          Text(
            t.kitapsen_store_badge_free,
            style: TextStyle(
              color: c.greenText,
              fontSize: 26,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
        ] else if (!d.isSerialized) ...<Widget>[
          Row(
            children: <Widget>[
              Icon(
                s.owned ? Icons.check_circle_outline : Icons.info_outline,
                size: 18,
                color: s.owned ? c.greenText : c.muted,
              ),
              const SizedBox(width: 6),
              Text(
                s.owned
                    ? t.kitapsen_book_in_library
                    : t.kitapsen_book_not_in_library,
                style: TextStyle(color: c.body, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            if (!d.isSerialized && (s.owned || d.isFree))
              FilledButton.icon(
                key: const ValueKey<String>('kitapsen-book-read'),
                style: readStyle,
                // A free book not yet in the library is claimed on the way.
                onPressed: _busy
                    ? null
                    : () => s.owned ? _read(s) : _claimAndRead(s),
                icon: const Icon(Icons.menu_book_outlined, size: 18),
                label: Text(t.kitapsen_book_read_now),
              ),
            if (!d.isSerialized && !s.owned && d.isFree)
              OutlinedButton.icon(
                key: const ValueKey<String>('kitapsen-book-get-free'),
                style: outlineStyle,
                onPressed: _busy ? null : () => _claim(s),
                icon: const Icon(Icons.library_add_outlined, size: 18),
                label: Text(t.kitapsen_book_get_free_web),
              ),
            OutlinedButton.icon(
              key: const ValueKey<String>('kitapsen-book-collection'),
              style: outlineStyle,
              onPressed: _busy
                  ? null
                  : () => showAddToCollectionSheet(
                      context,
                      s.store,
                      widget.bookId,
                    ),
              icon: const Icon(Icons.playlist_add, size: 18),
              label: Text(t.kitapsen_collections_add),
            ),
            if (!s.owned)
              OutlinedButton.icon(
                key: const ValueKey<String>('kitapsen-book-wishlist'),
                style: outlineStyle,
                onPressed: _busy ? null : () => _toggleWishlist(s),
                icon: Icon(
                  s.wishlisted ? Icons.favorite : Icons.favorite_border,
                  size: 18,
                  color: s.wishlisted ? c.accent : null,
                ),
                label: Text(t.kitapsen_book_favorites),
              ),
          ],
        ),
      ];
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? c.tile
            : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }

  /// Label-over-value rows, as in the website's details panel.
  Widget _facts(BuildContext context, StoreBookDetail d) {
    final StoreColors c = StoreColors.of(context);
    final List<(String, String)> rows = <(String, String)>[
      // The publisher row links to the publisher's page, built below.
      if (d.publisherName != null)
        (t.kitapsen_book_publisher, d.publisherName!),
      if (d.language != null) (t.kitapsen_book_language, d.language!),
      if (d.pageCount != null && d.pageCount! > 0)
        (t.kitapsen_book_pages, '${d.pageCount}'),
      if (d.format != null) (t.kitapsen_book_format, d.format!),
      if (d.isbn != null) (t.kitapsen_book_isbn, d.isbn!),
      if (d.publishingDate != null)
        (t.kitapsen_book_published, d.publishingDate!.split('T').first),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (final (String label, String value) in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              onTap:
                  label == t.kitapsen_book_publisher && d.publisherSlug != null
                  ? () => Navigator.of(context).push(
                      adaptivePageRoute<void>(
                        context: context,
                        builder: (_) =>
                            KitapsenPublisherPage(slug: d.publisherSlug!),
                      ),
                    )
                  : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(label, style: TextStyle(color: c.muted, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      color:
                          label == t.kitapsen_book_publisher &&
                              d.publisherSlug != null
                          ? c.accent
                          : c.ink,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  List<Widget> _chapters(BuildContext context, _BookState s) {
    final FushiDesignTokens tokens = FushiDesignTokens.of(context);
    final ({int followers, bool following})? follow = s.storyFollow;
    return <Widget>[
      SizedBox(height: tokens.spacing.section),
      Row(
        children: <Widget>[
          Expanded(child: _heading(context, t.kitapsen_story_chapters)),
          if (s.store.signedIn && follow != null)
            follow.following
                ? OutlinedButton(
                    key: const ValueKey<String>('kitapsen-story-unfollow'),
                    onPressed: _busy ? null : () => _toggleStoryFollow(s),
                    child: Text(
                      '${t.kitapsen_author_following} · ${follow.followers}',
                    ),
                  )
                : FilledButton.tonal(
                    key: const ValueKey<String>('kitapsen-story-follow'),
                    onPressed: _busy ? null : () => _toggleStoryFollow(s),
                    child: Text(t.kitapsen_story_follow),
                  ),
        ],
      ),
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
          Expanded(child: _heading(context, t.kitapsen_book_reviews)),
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
              Row(
                children: <Widget>[
                  TextButton.icon(
                    onPressed: !s.store.signedIn || _busy
                        ? null
                        : () => _toggleLike(s.store, r),
                    icon: Icon(
                      _likes[r.id]?.liked ?? false
                          ? Icons.thumb_up
                          : Icons.thumb_up_outlined,
                      size: 16,
                    ),
                    label: Text('${_likes[r.id]?.likes ?? r.likeCount}'),
                  ),
                  TextButton.icon(
                    onPressed: () => _openComments(
                      load: () => s.store.reviewComments(r.id),
                      add: s.store.signedIn
                          ? (String c) => s.store.addReviewComment(r.id, c)
                          : null,
                      report: s.store.signedIn
                          ? (int id, String? reason) =>
                                s.store.reportReviewComment(id, reason)
                          : null,
                      viewerId: s.store.viewerId(),
                      subtitle: r.title ?? r.userName,
                    ),
                    icon: const Icon(Icons.chat_bubble_outline, size: 16),
                    label: Text('${r.commentCount}'),
                  ),
                  const Spacer(),
                  if (s.store.signedIn &&
                      (r.userId == null || r.userId != _viewerId))
                    StoreReportButton(
                      key: ValueKey<String>('kitapsen-review-report-${r.id}'),
                      reported: _reportedReviews.contains(r.id),
                      onPressed: () => _reportReview(s.store, r),
                    ),
                ],
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
