/// The website's directories: publishers ("Yayınevleri" and a publisher's
/// page, with follow / like) and authors ("Yazarlar").
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fushi/src/models/app_model.dart';
import 'package:fushi/src/pages/implementations/kitapsen_store/kitapsen_author_page.dart';
import 'package:fushi/src/pages/implementations/kitapsen_store/kitapsen_book_list_page.dart';
import 'package:fushi/src/pages/implementations/kitapsen_store/kitapsen_store_widgets.dart';
import 'package:fushi/src/sync/kitapsen_community.dart';
import 'package:fushi/src/sync/kitapsen_store.dart';
import 'package:fushi/src/utils/net/app_http_image.dart';
import 'package:fushi/utils.dart';

Future<void> _push(BuildContext context, Widget page) => Navigator.of(
  context,
).push(adaptivePageRoute<void>(context: context, builder: (_) => page));

/// A publisher's logo, or the website's building placeholder.
class _PublisherLogo extends StatelessWidget {
  const _PublisherLogo({required this.url, required this.size});

  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final StoreColors c = StoreColors.of(context);
    final String? src = url;
    final Widget placeholder = ColoredBox(
      color: c.avatar,
      child: Icon(Icons.domain, color: c.accent, size: size / 2),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(size / 6),
      child: SizedBox.square(
        dimension: size,
        child: src == null
            ? placeholder
            : Image(
                image: AppCachedHttpImage(src),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => placeholder,
              ),
      ),
    );
  }
}

class KitapsenPublishersPage extends ConsumerStatefulWidget {
  const KitapsenPublishersPage({super.key});

  @override
  ConsumerState<KitapsenPublishersPage> createState() =>
      _KitapsenPublishersPageState();
}

class _KitapsenPublishersPageState
    extends ConsumerState<KitapsenPublishersPage> {
  late Future<List<StorePublisher>> _load = _fetch();

  Future<List<StorePublisher>> _fetch() async =>
      (await KitapsenStore.open(ref.read(appProvider).database)).publishers();

  @override
  Widget build(BuildContext context) {
    final StoreColors c = StoreColors.of(context);
    return FushiPageScaffold(
      title: t.kitapsen_publishers_title,
      body: FutureBuilder<List<StorePublisher>>(
        future: _load,
        builder: (_, AsyncSnapshot<List<StorePublisher>> s) => storeAsync(
          s,
          onRetry: () => setState(() => _load = _fetch()),
          isEmpty: (List<StorePublisher> l) => l.isEmpty,
          emptyIcon: Icons.domain_outlined,
          builder: (List<StorePublisher> list) => ListView(
            padding: withBottomSafeInset(context, EdgeInsets.zero),
            children: <Widget>[
              for (final StorePublisher p in list)
                ListTile(
                  leading: _PublisherLogo(url: p.logoUrl, size: 48),
                  title: Row(
                    children: <Widget>[
                      Flexible(
                        child: Text(
                          p.name,
                          style: TextStyle(
                            color: c.ink,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (p.verified) ...<Widget>[
                        const SizedBox(width: 6),
                        Icon(Icons.verified, size: 16, color: c.accent),
                      ],
                    ],
                  ),
                  subtitle: Text(
                    t.kitapsen_store_author_books_count(n: p.bookCount),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () =>
                      _push(context, KitapsenPublisherPage(slug: p.slug)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class KitapsenPublisherPage extends ConsumerStatefulWidget {
  const KitapsenPublisherPage({super.key, required this.slug});

  final String slug;

  @override
  ConsumerState<KitapsenPublisherPage> createState() =>
      _KitapsenPublisherPageState();
}

class _KitapsenPublisherPageState extends ConsumerState<KitapsenPublisherPage> {
  late Future<(KitapsenStore, StorePublisher, StoreBookPage)> _load = _fetch();
  ({int followers, int likes, bool following, bool liked}) _eng = (
    followers: 0,
    likes: 0,
    following: false,
    liked: false,
  );
  bool _busy = false;

  Future<(KitapsenStore, StorePublisher, StoreBookPage)> _fetch() async {
    final KitapsenStore store = await KitapsenStore.open(
      ref.read(appProvider).database,
    );
    final StorePublisher p = await store.publisher(widget.slug);
    final (
      ({int followers, int likes, bool following, bool liked}) eng,
      StoreBookPage books,
    ) = await (
      store.publisherEngagement(p.id),
      store.search(publisherId: p.id, sort: StoreSort.newest, perPage: 24),
    ).wait;
    _eng = eng;
    return (store, p, books);
  }

  Future<void> _toggle(
    KitapsenStore store,
    StorePublisher p, {
    required bool follow,
  }) async {
    if (!store.signedIn) {
      await openKitapsenSignIn(context);
      if (mounted) setState(() => _load = _fetch());
      return;
    }
    setState(() => _busy = true);
    try {
      final ({int followers, int likes, bool following, bool liked}) eng =
          await store.setPublisherEngagement(
            p.id,
            follow: follow,
            value: follow ? !_eng.following : !_eng.liked,
          );
      if (mounted) setState(() => _eng = eng);
    } catch (e, stack) {
      storeActionFailed(e, stack, 'KitapsenPublisherPage.engagement');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final FushiDesignTokens tokens = FushiDesignTokens.of(context);
    return FushiPageScaffold(
      title: '',
      body: FutureBuilder<(KitapsenStore, StorePublisher, StoreBookPage)>(
        future: _load,
        builder:
            (
              _,
              AsyncSnapshot<(KitapsenStore, StorePublisher, StoreBookPage)> s,
            ) => storeAsync(
              s,
              onRetry: () => setState(() => _load = _fetch()),
              builder: ((KitapsenStore, StorePublisher, StoreBookPage) d) =>
                  CustomScrollView(
                    slivers: <Widget>[
                      SliverPadding(
                        padding: EdgeInsets.all(tokens.spacing.page),
                        sliver: SliverToBoxAdapter(
                          child: _header(context, d.$1, d.$2, d.$3.total),
                        ),
                      ),
                      if (d.$3.books.isEmpty)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: tokens.spacing.page,
                            ),
                            child: Text(t.kitapsen_publisher_no_books),
                          ),
                        )
                      else
                        SliverPadding(
                          padding: EdgeInsets.symmetric(
                            horizontal: tokens.spacing.page,
                          ),
                          sliver: SliverGrid(
                            gridDelegate: storeGridDelegate(context),
                            delegate: SliverChildBuilderDelegate(
                              (_, int i) => StoreBookCard(book: d.$3.books[i]),
                              childCount: d.$3.books.length,
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
            ),
      ),
    );
  }

  Widget _header(
    BuildContext context,
    KitapsenStore store,
    StorePublisher p,
    int total,
  ) {
    final StoreColors c = StoreColors.of(context);
    final ButtonStyle outline = OutlinedButton.styleFrom(
      foregroundColor: c.ink,
      side: BorderSide(color: c.border),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _PublisherLogo(url: p.logoUrl, size: 96),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Flexible(
                        child: Text(
                          p.name,
                          style: TextStyle(
                            color: c.ink,
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (p.verified) ...<Widget>[
                        const SizedBox(width: 8),
                        Icon(Icons.verified, color: c.accent, size: 22),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    t.kitapsen_publisher_role,
                    style: TextStyle(color: c.muted, fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (p.description != null) ...<Widget>[
          const SizedBox(height: 16),
          Text(
            p.description!,
            style: TextStyle(color: c.body, fontSize: 15, height: 1.5),
          ),
        ],
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            OutlinedButton.icon(
              key: const ValueKey<String>('kitapsen-publisher-follow'),
              style: outline,
              onPressed: _busy ? null : () => _toggle(store, p, follow: true),
              icon: Icon(
                _eng.following
                    ? Icons.notifications_active
                    : Icons.notifications_none,
                size: 18,
                color: _eng.following ? c.accent : null,
              ),
              label: Text(
                _eng.following
                    ? t.kitapsen_author_following
                    : t.kitapsen_author_notify,
              ),
            ),
            OutlinedButton.icon(
              key: const ValueKey<String>('kitapsen-publisher-like'),
              style: outline,
              onPressed: _busy ? null : () => _toggle(store, p, follow: false),
              icon: Icon(
                _eng.liked ? Icons.favorite : Icons.favorite_border,
                size: 18,
                color: _eng.liked ? c.accent : null,
              ),
              label: Text(t.kitapsen_author_like),
            ),
          ],
        ),
        Divider(height: 40, color: c.border),
        Row(
          children: <Widget>[
            _Stat(label: t.kitapsen_author_books, value: total),
            const SizedBox(width: 32),
            _Stat(label: t.kitapsen_author_followers, value: _eng.followers),
            const SizedBox(width: 32),
            _Stat(label: t.kitapsen_author_likes, value: _eng.likes),
          ],
        ),
        const SizedBox(height: 28),
        StoreSectionHeader(
          title: t.kitapsen_author_books,
          trailing: total > 24
              ? StoreSeeAll(
                  onTap: () => _push(
                    context,
                    KitapsenBookListPage(title: p.name, publisherId: p.id),
                  ),
                )
              : null,
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final StoreColors c = StoreColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: TextStyle(color: c.muted, fontSize: 14)),
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

class KitapsenAuthorsPage extends ConsumerStatefulWidget {
  const KitapsenAuthorsPage({super.key});

  @override
  ConsumerState<KitapsenAuthorsPage> createState() =>
      _KitapsenAuthorsPageState();
}

class _KitapsenAuthorsPageState extends ConsumerState<KitapsenAuthorsPage> {
  late Future<List<StoreDirectoryAuthor>> _load = _fetch();
  String _filter = '';

  Future<List<StoreDirectoryAuthor>> _fetch() async =>
      (await KitapsenStore.open(
        ref.read(appProvider).database,
      )).authorDirectory();

  @override
  Widget build(BuildContext context) {
    final FushiDesignTokens tokens = FushiDesignTokens.of(context);
    return FushiPageScaffold(
      title: t.kitapsen_authors_title,
      body: FutureBuilder<List<StoreDirectoryAuthor>>(
        future: _load,
        builder: (_, AsyncSnapshot<List<StoreDirectoryAuthor>> s) => storeAsync(
          s,
          onRetry: () => setState(() => _load = _fetch()),
          isEmpty: (List<StoreDirectoryAuthor> l) => l.isEmpty,
          builder: (List<StoreDirectoryAuthor> all) {
            final String f = _filter.trim().toLowerCase();
            final List<StoreDirectoryAuthor> shown = f.isEmpty
                ? all
                : all
                      .where(
                        (StoreDirectoryAuthor a) =>
                            a.name.toLowerCase().contains(f),
                      )
                      .toList();
            return ListView.builder(
              padding: withBottomSafeInset(context, EdgeInsets.zero),
              itemCount: shown.length + 1,
              itemBuilder: (_, int i) {
                if (i == 0) {
                  return Padding(
                    padding: EdgeInsets.all(tokens.spacing.page),
                    child: TextField(
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search),
                        hintText: t.search,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onChanged: (String v) => setState(() => _filter = v),
                    ),
                  );
                }
                final StoreDirectoryAuthor a = shown[i - 1];
                return ListTile(
                  leading: StoreInitialAvatar(
                    name: a.name,
                    imageUrl: a.imageUrl,
                    radius: 22,
                  ),
                  title: Text(a.name),
                  subtitle: a.bookCount == null
                      ? null
                      : Text(
                          t.kitapsen_store_author_books_count(n: a.bookCount!),
                        ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _push(
                    context,
                    a.username != null
                        ? KitapsenAuthorPage(username: a.username!)
                        : KitapsenBookListPage(
                            title: a.name,
                            authorName: a.name,
                          ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
