/// kitapsen.com's blog: the post list with category pills, and a post.
/// Links inside posts are not followed: they can lead to the web store
/// (store policy, see `kitapsen_edition.dart`).
library;

import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fushi/src/models/app_model.dart';
import 'package:fushi/src/pages/implementations/kitapsen_store/kitapsen_store_widgets.dart';
import 'package:fushi/src/sync/kitapsen_community.dart';
import 'package:fushi/src/sync/kitapsen_store.dart';
import 'package:fushi/src/utils/net/app_http_image.dart';
import 'package:fushi/utils.dart';

class KitapsenBlogPage extends ConsumerStatefulWidget {
  const KitapsenBlogPage({super.key});

  @override
  ConsumerState<KitapsenBlogPage> createState() => _KitapsenBlogPageState();
}

class _KitapsenBlogPageState extends ConsumerState<KitapsenBlogPage> {
  String? _category;
  late Future<(List<String>, List<StoreBlogPost>)> _load = _fetch();

  Future<(List<String>, List<StoreBlogPost>)> _fetch() async {
    final KitapsenStore store = await KitapsenStore.open(
      ref.read(appProvider).database,
    );
    final (
      List<String> categories,
      ({List<StoreBlogPost> posts, int total}) page,
    ) = await (
      store.blogCategories(),
      store.blogPosts(category: _category),
    ).wait;
    return (categories, page.posts);
  }

  @override
  Widget build(BuildContext context) {
    final StoreColors c = StoreColors.of(context);
    final FushiDesignTokens tokens = FushiDesignTokens.of(context);
    return FushiPageScaffold(
      title: t.kitapsen_blog_title,
      body: FutureBuilder<(List<String>, List<StoreBlogPost>)>(
        future: _load,
        builder: (_, AsyncSnapshot<(List<String>, List<StoreBlogPost>)> s) =>
            storeAsync(
              s,
              onRetry: () => setState(() => _load = _fetch()),
              builder: ((List<String>, List<StoreBlogPost>) d) => ListView(
                padding: withBottomSafeInset(
                  context,
                  EdgeInsets.all(tokens.spacing.page),
                ),
                children: <Widget>[
                  Text(
                    t.kitapsen_blog_subtitle,
                    style: TextStyle(color: c.body, fontSize: 15),
                  ),
                  const SizedBox(height: 16),
                  if (d.$1.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        StorePill(
                          label: t.kitapsen_store_all_categories,
                          selected: _category == null,
                          onTap: () => setState(() {
                            _category = null;
                            _load = _fetch();
                          }),
                        ),
                        for (final String cat in d.$1)
                          StorePill(
                            label: cat,
                            selected: _category == cat,
                            onTap: () => setState(() {
                              _category = cat;
                              _load = _fetch();
                            }),
                          ),
                      ],
                    ),
                  const SizedBox(height: 16),
                  if (d.$2.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(child: Text(t.kitapsen_blog_empty)),
                    ),
                  for (final StoreBlogPost p in d.$2) _PostCard(post: p),
                ],
              ),
            ),
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  const _PostCard({required this.post});

  final StoreBlogPost post;

  @override
  Widget build(BuildContext context) {
    final StoreColors c = StoreColors.of(context);
    final String? image = post.imageUrl;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.of(context).push(
            adaptivePageRoute<void>(
              context: context,
              builder: (_) => KitapsenBlogPostPage(slug: post.slug),
            ),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: c.border),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                if (image != null)
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Image(
                        image: AppCachedHttpImage(image),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => ColoredBox(color: c.tile),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      if (post.category != null)
                        Text(
                          post.category!,
                          style: TextStyle(
                            color: c.accent,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      const SizedBox(height: 6),
                      Text(
                        post.title,
                        style: TextStyle(
                          color: c.ink,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          height: 1.3,
                        ),
                      ),
                      if (post.excerpt != null) ...<Widget>[
                        const SizedBox(height: 8),
                        Text(
                          post.excerpt!,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: c.body, height: 1.5),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Text(
                        <String>[
                          if (post.authorName != null) post.authorName!,
                          storeDate(post.publishedAt),
                        ].where((String s) => s.isNotEmpty).join(' · '),
                        style: TextStyle(color: c.muted, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class KitapsenBlogPostPage extends ConsumerStatefulWidget {
  const KitapsenBlogPostPage({super.key, required this.slug});

  final String slug;

  @override
  ConsumerState<KitapsenBlogPostPage> createState() =>
      _KitapsenBlogPostPageState();
}

class _KitapsenBlogPostPageState extends ConsumerState<KitapsenBlogPostPage> {
  late Future<StoreBlogPost> _load = _fetch();

  Future<StoreBlogPost> _fetch() async => (await KitapsenStore.open(
    ref.read(appProvider).database,
  )).blogPost(widget.slug);

  @override
  Widget build(BuildContext context) {
    final StoreColors c = StoreColors.of(context);
    final FushiDesignTokens tokens = FushiDesignTokens.of(context);
    return FushiPageScaffold(
      title: '',
      body: FutureBuilder<StoreBlogPost>(
        future: _load,
        builder: (_, AsyncSnapshot<StoreBlogPost> s) => storeAsync(
          s,
          onRetry: () => setState(() => _load = _fetch()),
          builder: (StoreBlogPost p) => ListView(
            padding: withBottomSafeInset(
              context,
              EdgeInsets.all(tokens.spacing.page),
            ),
            children: <Widget>[
              if (p.category != null)
                Text(
                  p.category!,
                  style: TextStyle(
                    color: c.accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              const SizedBox(height: 8),
              Text(
                p.title,
                style: TextStyle(
                  color: c.ink,
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                <String>[
                  if (p.authorName != null) p.authorName!,
                  storeDate(p.publishedAt),
                ].where((String s) => s.isNotEmpty).join(' · '),
                style: TextStyle(color: c.muted),
              ),
              if (p.imageUrl != null) ...<Widget>[
                const SizedBox(height: 20),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image(
                    image: AppCachedHttpImage(p.imageUrl!),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Html(
                data: p.content ?? '',
                style: <String, Style>{
                  'body': Style(
                    margin: Margins.zero,
                    color: c.body,
                    fontSize: FontSize(16),
                    lineHeight: const LineHeight(1.65),
                  ),
                  'h1': Style(color: c.ink),
                  'h2': Style(color: c.ink),
                  'h3': Style(color: c.ink),
                  'a': Style(
                    color: c.body,
                    textDecoration: TextDecoration.none,
                  ),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
