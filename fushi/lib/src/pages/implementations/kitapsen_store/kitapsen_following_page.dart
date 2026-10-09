/// Authors and serialized stories the reader follows.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fushi/src/models/app_model.dart';
import 'package:fushi/src/pages/implementations/kitapsen_store/kitapsen_author_page.dart';
import 'package:fushi/src/pages/implementations/kitapsen_store/kitapsen_store_widgets.dart';
import 'package:fushi/src/sync/kitapsen_store.dart';
import 'package:fushi/src/utils/net/app_http_image.dart';
import 'package:fushi/utils.dart';

class KitapsenFollowingPage extends ConsumerStatefulWidget {
  const KitapsenFollowingPage({super.key});

  @override
  ConsumerState<KitapsenFollowingPage> createState() =>
      _KitapsenFollowingPageState();
}

class _KitapsenFollowingPageState extends ConsumerState<KitapsenFollowingPage> {
  late Future<(List<StoreFollowedAuthor>, List<({StoreBook book, int unread})>)>
  _load = _fetch();

  Future<(List<StoreFollowedAuthor>, List<({StoreBook book, int unread})>)>
  _fetch() async {
    final KitapsenStore store = await KitapsenStore.open(
      ref.read(appProvider).database,
    );
    return (store.followedAuthors(), store.followedStories()).wait;
  }

  Future<void> _push(Widget page) async {
    await Navigator.of(
      context,
    ).push(adaptivePageRoute<void>(context: context, builder: (_) => page));
    if (mounted) setState(() => _load = _fetch());
  }

  @override
  Widget build(BuildContext context) {
    final FushiDesignTokens tokens = FushiDesignTokens.of(context);
    return FushiPageScaffold(
      title: t.kitapsen_following_title,
      body:
          FutureBuilder<
            (List<StoreFollowedAuthor>, List<({StoreBook book, int unread})>)
          >(
            future: _load,
            builder:
                (
                  BuildContext context,
                  AsyncSnapshot<
                    (
                      List<StoreFollowedAuthor>,
                      List<({StoreBook book, int unread})>,
                    )
                  >
                  s,
                ) {
                  if (s.hasError) {
                    return StoreLoadError(
                      onRetry: () => setState(() => _load = _fetch()),
                    );
                  }
                  final (
                    List<StoreFollowedAuthor>,
                    List<({StoreBook book, int unread})>,
                  )?
                  data = s.data;
                  if (data == null) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final (
                    List<StoreFollowedAuthor> authors,
                    List<({StoreBook book, int unread})> stories,
                  ) = data;
                  if (authors.isEmpty && stories.isEmpty) {
                    return Center(
                      child: FushiPlaceholderMessage(
                        icon: Icons.people_outline,
                        message: t.kitapsen_following_empty,
                      ),
                    );
                  }
                  return ListView(
                    padding: withBottomSafeInset(context, EdgeInsets.zero),
                    children: <Widget>[
                      if (authors.isNotEmpty) ...<Widget>[
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            tokens.spacing.page,
                            tokens.spacing.gap,
                            tokens.spacing.page,
                            0,
                          ),
                          child: Text(
                            t.kitapsen_following_authors,
                            style: tokens.type.sectionLabel,
                          ),
                        ),
                        for (final StoreFollowedAuthor a in authors)
                          ListTile(
                            leading: CircleAvatar(
                              backgroundImage: a.imageUrl == null
                                  ? null
                                  : AppCachedHttpImage(a.imageUrl!),
                              child: a.imageUrl == null
                                  ? const Icon(Icons.person)
                                  : null,
                            ),
                            title: Text(a.name),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () =>
                                _push(KitapsenAuthorPage(username: a.username)),
                          ),
                      ],
                      if (stories.isNotEmpty) ...<Widget>[
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            tokens.spacing.page,
                            tokens.spacing.section,
                            tokens.spacing.page,
                            0,
                          ),
                          child: Text(
                            t.kitapsen_following_stories,
                            style: tokens.type.sectionLabel,
                          ),
                        ),
                        for (final ({StoreBook book, int unread}) story
                            in stories)
                          ListTile(
                            leading: SizedBox(
                              width: 36,
                              child: StoreCover(url: story.book.coverUrl),
                            ),
                            title: Text(story.book.title),
                            subtitle: story.book.authorName == null
                                ? null
                                : Text(story.book.authorName!),
                            trailing: Badge(
                              isLabelVisible: story.unread > 0,
                              label: Text('${story.unread}'),
                              child: const Icon(Icons.chevron_right),
                            ),
                            onTap: () => openStoreBook(context, story.book.id),
                          ),
                      ],
                    ],
                  );
                },
          ),
    );
  }
}
