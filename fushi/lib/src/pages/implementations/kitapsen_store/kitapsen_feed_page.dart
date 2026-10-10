/// The social feed ("Akış"), as on the website: what the readers and authors
/// the reader follows did, and the reader's own activity.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fushi/src/models/app_model.dart';
import 'package:fushi/src/pages/implementations/kitapsen_store/kitapsen_author_page.dart';
import 'package:fushi/src/pages/implementations/kitapsen_store/kitapsen_store_widgets.dart';
import 'package:fushi/src/pages/implementations/kitapsen_store/kitapsen_user_page.dart';
import 'package:fushi/src/sync/kitapsen_community.dart';
import 'package:fushi/src/sync/kitapsen_store.dart';
import 'package:fushi/utils.dart';

class KitapsenFeedPage extends ConsumerStatefulWidget {
  const KitapsenFeedPage({super.key});

  @override
  ConsumerState<KitapsenFeedPage> createState() => _KitapsenFeedPageState();
}

class _KitapsenFeedPageState extends ConsumerState<KitapsenFeedPage> {
  bool _mine = false;
  late Future<List<StoreFeedEntry>> _load = _fetch();

  Future<List<StoreFeedEntry>> _fetch() async => (await KitapsenStore.open(
    ref.read(appProvider).database,
  )).feed(mine: _mine);

  @override
  Widget build(BuildContext context) {
    final FushiDesignTokens tokens = FushiDesignTokens.of(context);
    return FushiPageScaffold(
      title: t.kitapsen_feed_title,
      body: Column(
        children: <Widget>[
          Padding(
            padding: EdgeInsets.fromLTRB(
              tokens.spacing.page,
              8,
              tokens.spacing.page,
              8,
            ),
            child: SegmentedButton<bool>(
              segments: <ButtonSegment<bool>>[
                ButtonSegment<bool>(
                  value: false,
                  label: Text(t.kitapsen_feed_followed),
                ),
                ButtonSegment<bool>(
                  value: true,
                  label: Text(t.kitapsen_feed_mine),
                ),
              ],
              selected: <bool>{_mine},
              onSelectionChanged: (Set<bool> v) => setState(() {
                _mine = v.first;
                _load = _fetch();
              }),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<StoreFeedEntry>>(
              future: _load,
              builder: (_, AsyncSnapshot<List<StoreFeedEntry>> s) => storeAsync(
                s,
                onRetry: () => setState(() => _load = _fetch()),
                isEmpty: (List<StoreFeedEntry> l) => l.isEmpty,
                emptyIcon: Icons.dynamic_feed_outlined,
                emptyMessage: _mine
                    ? t.kitapsen_feed_empty_mine
                    : t.kitapsen_feed_empty_followed,
                builder: (List<StoreFeedEntry> list) => RefreshIndicator(
                  onRefresh: () async {
                    final Future<List<StoreFeedEntry>> f = _fetch();
                    setState(() => _load = f);
                    await f;
                  },
                  child: ListView(
                    padding: withBottomSafeInset(
                      context,
                      EdgeInsets.symmetric(horizontal: tokens.spacing.page),
                    ),
                    children: <Widget>[
                      for (final StoreFeedEntry e in list)
                        StoreFeedTile(entry: e),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One feed line, shared with the reader profile's "Etkinlik" tab.
class StoreFeedTile extends StatelessWidget {
  const StoreFeedTile({super.key, required this.entry});

  final StoreFeedEntry entry;

  String get _action {
    final String target = entry.targetTitle ?? entry.targetUsername ?? '';
    return switch (entry.action) {
      'started_reading' => t.kitapsen_feed_started(target: target),
      'finished_book' => t.kitapsen_feed_finished(target: target),
      'reviewed' => t.kitapsen_feed_reviewed(target: target),
      'followed_user' => t.kitapsen_feed_followed_user(target: target),
      'followed_author' => t.kitapsen_feed_followed_author(target: target),
      _ => t.kitapsen_feed_shared(target: target),
    };
  }

  void _openTarget(BuildContext context) {
    final String? username = entry.targetUsername;
    final Widget? page = switch (entry.targetType) {
      'user' when username != null => KitapsenUserPage(username: username),
      'author' when username != null => KitapsenAuthorPage(username: username),
      _ => null,
    };
    if (page != null) {
      Navigator.of(
        context,
      ).push(adaptivePageRoute<void>(context: context, builder: (_) => page));
    } else if (entry.targetType == 'book' && entry.targetId != null) {
      openStoreBook(context, entry.targetId!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final StoreColors c = StoreColors.of(context);
    final double? percent = entry.progressPercent;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _openTarget(context),
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: c.border),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  GestureDetector(
                    onTap: entry.username.isEmpty
                        ? null
                        : () => Navigator.of(context).push(
                            adaptivePageRoute<void>(
                              context: context,
                              builder: (_) =>
                                  KitapsenUserPage(username: entry.username),
                            ),
                          ),
                    child: StoreInitialAvatar(
                      name: entry.username,
                      imageUrl: entry.avatarUrl,
                      radius: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text.rich(
                          TextSpan(
                            children: <InlineSpan>[
                              TextSpan(
                                text: '@${entry.username} ',
                                style: TextStyle(
                                  color: c.ink,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              TextSpan(
                                text: _action,
                                style: TextStyle(color: c.body),
                              ),
                            ],
                          ),
                        ),
                        if (percent != null || entry.action == 'finished_book')
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              entry.action == 'finished_book'
                                  ? t.kitapsen_feed_finished_badge
                                  : t.kitapsen_feed_percent(
                                      n: percent!.round(),
                                    ),
                              style: TextStyle(
                                color: entry.action == 'finished_book'
                                    ? c.greenText
                                    : c.muted,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        const SizedBox(height: 4),
                        Text(
                          storeDate(entry.createdAt),
                          style: TextStyle(color: c.muted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  if (entry.targetType == 'book' &&
                      entry.targetCoverUrl != null) ...<Widget>[
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 44,
                      child: StoreCover(url: entry.targetCoverUrl),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
