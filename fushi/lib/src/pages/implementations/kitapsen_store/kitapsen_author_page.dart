/// An author's page: profile, follow, and their books.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fushi/src/models/app_model.dart';
import 'package:fushi/src/pages/implementations/kitapsen_store/kitapsen_book_list_page.dart';
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
  late Future<(KitapsenStore, StoreAuthor)> _load = _fetch();
  bool _following = false;
  int _followers = 0;
  bool _busy = false;

  Future<(KitapsenStore, StoreAuthor)> _fetch() async {
    final KitapsenStore store = await KitapsenStore.open(
      ref.read(appProvider).database,
    );
    final (
      StoreAuthor author,
      ({bool following, int followers}) status,
    ) = await (
      store.author(widget.username),
      store.followStatus(widget.username),
    ).wait;
    _following = status.following;
    _followers = status.followers;
    return (store, author);
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

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<(KitapsenStore, StoreAuthor)>(
      future: _load,
      builder:
          (
            BuildContext context,
            AsyncSnapshot<(KitapsenStore, StoreAuthor)> snapshot,
          ) {
            final StoreAuthor? author = snapshot.data?.$2;
            return FushiPageScaffold(
              title: author?.name ?? t.kitapsen_author_open,
              body: snapshot.hasError
                  ? StoreLoadError(
                      onRetry: () => setState(() => _load = _fetch()),
                    )
                  : author == null
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        _header(context, snapshot.data!.$1, author),
                        Expanded(
                          child: KitapsenBookListPage(
                            title: author.name,
                            authorUserId: author.userId,
                            embedded: true,
                          ),
                        ),
                      ],
                    ),
            );
          },
    );
  }

  Widget _header(BuildContext context, KitapsenStore store, StoreAuthor a) {
    final FushiDesignTokens tokens = FushiDesignTokens.of(context);
    final String? image = a.imageUrl;
    return Padding(
      padding: EdgeInsets.all(tokens.spacing.page),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              CircleAvatar(
                radius: 32,
                backgroundImage: image == null
                    ? null
                    : AppCachedHttpImage(image),
                child: image == null ? const Icon(Icons.person) : null,
              ),
              SizedBox(width: tokens.spacing.page),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Flexible(
                          child: Text(a.name, style: tokens.type.pageTitle),
                        ),
                        if (a.verified) ...<Widget>[
                          const SizedBox(width: 4),
                          Icon(
                            Icons.verified,
                            size: 18,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ],
                      ],
                    ),
                    Text(
                      '$_followers ${t.kitapsen_author_followers}',
                      style: tokens.type.metadata,
                    ),
                  ],
                ),
              ),
              _following
                  ? OutlinedButton(
                      key: const ValueKey<String>('kitapsen-author-unfollow'),
                      onPressed: _busy ? null : () => _toggleFollow(store),
                      child: Text(t.kitapsen_author_following),
                    )
                  : FilledButton(
                      key: const ValueKey<String>('kitapsen-author-follow'),
                      onPressed: _busy ? null : () => _toggleFollow(store),
                      child: Text(t.kitapsen_author_follow),
                    ),
            ],
          ),
          if (a.bio != null) ...<Widget>[
            SizedBox(height: tokens.spacing.gap),
            Text(a.bio!, maxLines: 6, overflow: TextOverflow.ellipsis),
          ],
          SizedBox(height: tokens.spacing.gap),
          Text(t.kitapsen_author_books, style: tokens.type.sectionLabel),
        ],
      ),
    );
  }
}
