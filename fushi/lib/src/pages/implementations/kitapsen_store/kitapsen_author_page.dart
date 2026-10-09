/// An author's page, laid out like the website's: square photo, serif name
/// with the verified badge, "Yazar @username", the follow button ("Yeni
/// kitaplarını haber ver"), counts, the "Hakkında" card and the author's own
/// books.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fushi/src/models/app_model.dart';
import 'package:fushi/src/pages/implementations/kitapsen_store/kitapsen_store_widgets.dart';
import 'package:fushi/src/sync/kitapsen_store.dart';
import 'package:fushi/src/utils/net/app_http_image.dart';
import 'package:fushi/utils.dart';

class KitapsenAuthorPage extends ConsumerStatefulWidget {
  const KitapsenAuthorPage({super.key, required this.username});

  final String username;

  @override
  ConsumerState<KitapsenAuthorPage> createState() => _KitapsenAuthorPageState();
}

class _KitapsenAuthorPageState extends ConsumerState<KitapsenAuthorPage> {
  late Future<(KitapsenStore, StoreAuthor, List<StoreBook>)> _load = _fetch();
  bool _following = false;
  int _followers = 0;
  bool _liked = false;
  int _likes = 0;
  bool _busy = false;
  bool _bioExpanded = false;

  Future<(KitapsenStore, StoreAuthor, List<StoreBook>)> _fetch() async {
    final KitapsenStore store = await KitapsenStore.open(
      ref.read(appProvider).database,
    );
    final (
      StoreAuthor author,
      ({bool following, int followers}) status,
      ({bool liked, int likes}) likes,
      List<StoreBook> books,
    ) = await (
      store.author(widget.username),
      store.followStatus(widget.username),
      store.authorLikes(widget.username),
      store.authorBooks(widget.username),
    ).wait;
    _following = status.following;
    _followers = status.followers;
    _liked = likes.liked;
    _likes = likes.likes;
    return (store, author, books);
  }

  Future<void> _toggleFollow(KitapsenStore store) async {
    if (!store.signedIn) {
      await openKitapsenSignIn(context);
      if (mounted) setState(() => _load = _fetch());
      return;
    }
    setState(() => _busy = true);
    try {
      final ({bool following, int followers}) status = await store.setFollowing(
        widget.username,
        !_following,
      );
      if (mounted) {
        setState(() {
          _following = status.following;
          _followers = status.followers;
        });
      }
    } catch (e, stack) {
      ErrorLogService.instance.log('KitapsenAuthorPage.follow', e, stack);
      FushiToast.show(
        msg: t.kitapsen_book_action_failed,
        severity: ToastSeverity.error,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleLike(KitapsenStore store) async {
    if (!store.signedIn) {
      await openKitapsenSignIn(context);
      if (mounted) setState(() => _load = _fetch());
      return;
    }
    setState(() => _busy = true);
    try {
      final ({bool liked, int likes}) state = await store.setAuthorLike(
        widget.username,
        !_liked,
      );
      if (mounted) {
        setState(() {
          _liked = state.liked;
          _likes = state.likes;
        });
      }
    } catch (e, stack) {
      ErrorLogService.instance.log('KitapsenAuthorPage.like', e, stack);
      FushiToast.show(
        msg: t.kitapsen_book_action_failed,
        severity: ToastSeverity.error,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final FushiDesignTokens tokens = FushiDesignTokens.of(context);
    return FutureBuilder<(KitapsenStore, StoreAuthor, List<StoreBook>)>(
      future: _load,
      builder:
          (
            BuildContext context,
            AsyncSnapshot<(KitapsenStore, StoreAuthor, List<StoreBook>)>
            snapshot,
          ) {
            final (KitapsenStore, StoreAuthor, List<StoreBook>)? data =
                snapshot.data;
            return FushiPageScaffold(
              title: '',
              body: snapshot.hasError
                  ? StoreLoadError(
                      onRetry: () => setState(() => _load = _fetch()),
                    )
                  : data == null
                  ? const Center(child: CircularProgressIndicator())
                  : CustomScrollView(
                      slivers: <Widget>[
                        SliverPadding(
                          padding: EdgeInsets.all(tokens.spacing.page),
                          sliver: SliverToBoxAdapter(
                            child: _profile(
                              context,
                              data.$1,
                              data.$2,
                              data.$3.length,
                            ),
                          ),
                        ),
                        SliverPadding(
                          padding: EdgeInsets.symmetric(
                            horizontal: tokens.spacing.page,
                          ),
                          sliver: SliverGrid(
                            gridDelegate: storeGridDelegate(context),
                            delegate: SliverChildBuilderDelegate(
                              (_, int i) => StoreBookCard(book: data.$3[i]),
                              childCount: data.$3.length,
                            ),
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
            );
          },
    );
  }

  Widget _profile(
    BuildContext context,
    KitapsenStore store,
    StoreAuthor a,
    int bookCount,
  ) {
    final StoreColors c = StoreColors.of(context);
    final String? image = a.imageUrl;
    final ButtonStyle outline = OutlinedButton.styleFrom(
      foregroundColor: c.ink,
      side: BorderSide(color: c.border),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            width: 160,
            height: 160,
            child: image == null
                ? ColoredBox(
                    color: c.avatar,
                    child: Center(
                      child: Text(
                        a.name.characters.first.toUpperCase(),
                        style: TextStyle(color: c.accent, fontSize: 64),
                      ),
                    ),
                  )
                : Image(image: AppCachedHttpImage(image), fit: BoxFit.cover),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: <Widget>[
            Flexible(
              child: Text(
                a.name,
                style: TextStyle(
                  fontFamily: kStoreSerif,
                  fontFamilyFallback: kStoreSerifFallback,
                  color: c.ink,
                  fontSize: 32,
                ),
              ),
            ),
            if (a.verified) ...<Widget>[
              const SizedBox(width: 8),
              Icon(Icons.verified_outlined, color: c.accent, size: 26),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '${t.kitapsen_author_role}  @${a.username}',
          style: TextStyle(color: c.muted, fontSize: 15),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            OutlinedButton.icon(
              key: ValueKey<String>(
                _following
                    ? 'kitapsen-author-unfollow'
                    : 'kitapsen-author-follow',
              ),
              style: outline,
              onPressed: _busy ? null : () => _toggleFollow(store),
              icon: Icon(
                _following
                    ? Icons.notifications_active
                    : Icons.notifications_none,
                size: 18,
                color: _following ? c.accent : null,
              ),
              label: Text(
                _following
                    ? t.kitapsen_author_following
                    : t.kitapsen_author_notify,
              ),
            ),
            OutlinedButton.icon(
              key: const ValueKey<String>('kitapsen-author-like'),
              style: outline,
              onPressed: _busy ? null : () => _toggleLike(store),
              icon: Icon(
                _liked ? Icons.favorite : Icons.favorite_border,
                size: 18,
                color: _liked ? c.accent : null,
              ),
              label: Text(t.kitapsen_author_like),
            ),
          ],
        ),
        Divider(height: 40, color: c.border),
        Row(
          children: <Widget>[
            _stat(
              context,
              Icons.menu_book_outlined,
              t.kitapsen_author_books,
              bookCount,
            ),
            const SizedBox(width: 32),
            _stat(
              context,
              Icons.people_outline,
              t.kitapsen_author_followers,
              _followers,
            ),
            const SizedBox(width: 32),
            _stat(
              context,
              Icons.favorite_border,
              t.kitapsen_author_likes,
              _likes,
            ),
          ],
        ),
        if (a.bio != null) ...<Widget>[
          const SizedBox(height: 28),
          DecoratedBox(
            decoration: BoxDecoration(
              color: c.tile,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    t.kitapsen_author_about,
                    style: TextStyle(
                      color: c.ink,
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    a.bio!,
                    maxLines: _bioExpanded ? null : 6,
                    overflow: _bioExpanded ? null : TextOverflow.ellipsis,
                    style: TextStyle(color: c.body, fontSize: 15, height: 1.6),
                  ),
                  if (!_bioExpanded && a.bio!.length > 280)
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: c.accent,
                        padding: EdgeInsets.zero,
                      ),
                      onPressed: () => setState(() => _bioExpanded = true),
                      child: Text(t.kitapsen_review_more_bio),
                    ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 28),
        Text(
          t.kitapsen_author_books,
          style: TextStyle(
            color: c.ink,
            fontSize: 21,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }

  Widget _stat(BuildContext context, IconData icon, String label, int value) {
    final StoreColors c = StoreColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(icon, size: 16, color: c.muted),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: c.muted, fontSize: 14)),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '$value',
          style: TextStyle(
            color: c.ink,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
