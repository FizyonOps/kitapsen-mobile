/// A reader's public profile, as on the website (/users/:username): follow,
/// block, followers / following, their shared reading, reviews and activity.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fushi/src/models/app_model.dart';
import 'package:fushi/src/pages/implementations/kitapsen_store/kitapsen_feed_page.dart';
import 'package:fushi/src/pages/implementations/kitapsen_store/kitapsen_store_widgets.dart';
import 'package:fushi/src/sync/kitapsen_community.dart';
import 'package:fushi/src/sync/kitapsen_store.dart';
import 'package:fushi/utils.dart';

class _Profile {
  const _Profile({
    required this.store,
    required this.user,
    required this.status,
    required this.reading,
    required this.finished,
    required this.reviews,
    required this.activity,
    required this.isMe,
  });

  final KitapsenStore store;
  final StoreUser user;
  final StoreUserStatus status;
  final List<StorePublicProgress> reading;
  final List<StorePublicProgress> finished;
  final List<StoreUserReview> reviews;
  final List<StoreFeedEntry> activity;
  final bool isMe;
}

class KitapsenUserPage extends ConsumerStatefulWidget {
  const KitapsenUserPage({super.key, required this.username});

  final String username;

  @override
  ConsumerState<KitapsenUserPage> createState() => _KitapsenUserPageState();
}

class _KitapsenUserPageState extends ConsumerState<KitapsenUserPage> {
  late Future<_Profile> _load = _fetch();
  int _tab = 0;
  bool _busy = false;

  /// The profile's parts load on their own: a private or blocked profile
  /// answers 403 for some of them, which leaves those parts empty.
  Future<T> _orEmpty<T>(Future<T> f, T empty) async {
    try {
      return await f;
    } catch (_) {
      return empty;
    }
  }

  Future<_Profile> _fetch() async {
    final KitapsenStore store = await KitapsenStore.open(
      ref.read(appProvider).database,
    );
    final String u = widget.username;
    final (
      StoreUser user,
      StoreUserStatus status,
      ({List<StorePublicProgress> reading, List<StorePublicProgress> finished})
      shelf,
      List<StoreUserReview> reviews,
      List<StoreFeedEntry> activity,
    ) = await (
      store.user(u),
      store.userStatus(u),
      _orEmpty(store.publicReading(u), (
        reading: const <StorePublicProgress>[],
        finished: const <StorePublicProgress>[],
      )),
      _orEmpty(store.userReviews(u), const <StoreUserReview>[]),
      _orEmpty(store.userActivity(u), const <StoreFeedEntry>[]),
    ).wait;
    // The stored sign-in name may be an email address; ask the server.
    final StoreMe? me = store.signedIn
        ? await _orEmpty<StoreMe?>(store.me(), null)
        : null;
    return _Profile(
      store: store,
      user: user,
      status: status,
      reading: shelf.reading,
      finished: shelf.finished,
      reviews: reviews,
      activity: activity,
      isMe: me != null && me.username == user.username,
    );
  }

  Future<void> _act(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) setState(() => _load = _fetch());
    } catch (e, stack) {
      storeActionFailed(e, stack, 'KitapsenUserPage');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _follow(_Profile p) async {
    if (!p.store.signedIn) {
      await openKitapsenSignIn(context);
      if (mounted) setState(() => _load = _fetch());
      return;
    }
    await _act(
      () => p.store.setUserFollowing(widget.username, !p.status.following),
    );
  }

  Future<void> _block(_Profile p) async {
    if (!p.status.blockedByMe &&
        !await showStoreConfirm(
          context,
          t.kitapsen_user_block_confirm(username: widget.username),
          action: t.kitapsen_user_block,
          destructive: true,
        )) {
      return;
    }
    await _act(
      () => p.store.setBlocked(widget.username, !p.status.blockedByMe),
    );
  }

  void _openConnections({required bool following}) =>
      Navigator.of(context).push(
        adaptivePageRoute<void>(
          context: context,
          builder: (_) => KitapsenUserConnectionsPage(
            username: widget.username,
            following: following,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_Profile>(
      future: _load,
      builder: (_, AsyncSnapshot<_Profile> s) {
        final _Profile? p = s.data;
        return FushiPageScaffold(
          title: '',
          actions: <Widget>[
            if (p != null && p.store.signedIn && !p.isMe)
              PopupMenuButton<String>(
                onSelected: (_) => _block(p),
                itemBuilder: (_) => <PopupMenuEntry<String>>[
                  PopupMenuItem<String>(
                    value: 'block',
                    child: Text(
                      p.status.blockedByMe
                          ? t.kitapsen_user_unblock
                          : t.kitapsen_user_block,
                    ),
                  ),
                ],
              ),
          ],
          body: storeAsync(
            s,
            onRetry: () => setState(() => _load = _fetch()),
            builder: (_Profile p) => _body(context, p),
          ),
        );
      },
    );
  }

  Widget _body(BuildContext context, _Profile p) {
    final StoreColors c = StoreColors.of(context);
    final FushiDesignTokens tokens = FushiDesignTokens.of(context);
    final StoreUser u = p.user;
    final String shown = u.name.isEmpty ? u.username : u.name;
    final bool hidden =
        p.status.blockedMe || (u.isPrivate && !p.status.following && !p.isMe);
    return ListView(
      padding: withBottomSafeInset(
        context,
        EdgeInsets.all(tokens.spacing.page),
      ),
      children: <Widget>[
        Row(
          children: <Widget>[
            StoreInitialAvatar(name: shown, imageUrl: u.imageUrl, radius: 36),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    shown,
                    style: TextStyle(
                      fontFamily: kStoreSerif,
                      fontFamilyFallback: kStoreSerifFallback,
                      color: c.ink,
                      fontSize: 26,
                    ),
                  ),
                  Text(
                    '@${u.username}',
                    style: TextStyle(color: c.muted, fontSize: 14),
                  ),
                  if (u.createdAt != null)
                    Text(
                      t.kitapsen_user_member_since(
                        date: storeDate(u.createdAt, dateOnly: true),
                      ),
                      style: TextStyle(color: c.muted, fontSize: 13),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 20,
          runSpacing: 8,
          children: <Widget>[
            InkWell(
              onTap: hidden ? null : () => _openConnections(following: false),
              child: Text(
                t.kitapsen_user_followers(n: p.status.followers),
                style: TextStyle(color: c.ink, fontWeight: FontWeight.w600),
              ),
            ),
            InkWell(
              onTap: hidden ? null : () => _openConnections(following: true),
              child: Text(
                t.kitapsen_user_following(n: p.status.followingCount),
                style: TextStyle(color: c.ink, fontWeight: FontWeight.w600),
              ),
            ),
            Text(
              t.kitapsen_user_finished_count(n: p.finished.length),
              style: TextStyle(color: c.body),
            ),
          ],
        ),
        if (!p.isMe && !p.status.blockedMe) ...<Widget>[
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: p.status.following
                ? OutlinedButton.icon(
                    key: const ValueKey<String>('kitapsen-user-unfollow'),
                    onPressed: _busy ? null : () => _follow(p),
                    icon: const Icon(Icons.check, size: 18),
                    label: Text(t.kitapsen_author_following),
                  )
                : FilledButton.icon(
                    key: const ValueKey<String>('kitapsen-user-follow'),
                    style: FilledButton.styleFrom(
                      backgroundColor: c.accent,
                      foregroundColor: c.onAccent,
                    ),
                    onPressed: _busy || p.status.blockedByMe
                        ? null
                        : () => _follow(p),
                    icon: const Icon(Icons.person_add_alt_1, size: 18),
                    label: Text(t.kitapsen_user_follow),
                  ),
          ),
        ],
        const SizedBox(height: 20),
        if (p.status.blockedMe)
          _notice(context, t.kitapsen_user_blocked_you)
        else if (hidden)
          _notice(context, t.kitapsen_user_private)
        else ...<Widget>[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final (int i, String label) in <(int, String)>[
                (0, t.kitapsen_user_tab_reading),
                (1, t.kitapsen_user_tab_reviews),
                (2, t.kitapsen_user_tab_activity),
              ])
                StorePill(
                  label: label,
                  selected: _tab == i,
                  onTap: () => setState(() => _tab = i),
                ),
            ],
          ),
          const SizedBox(height: 16),
          ...switch (_tab) {
            0 => _reading(context, p),
            1 => _reviews(context, p),
            _ => <Widget>[
              if (p.activity.isEmpty)
                _notice(context, t.kitapsen_user_no_activity),
              for (final StoreFeedEntry e in p.activity)
                StoreFeedTile(entry: e),
            ],
          },
        ],
      ],
    );
  }

  Widget _notice(BuildContext context, String text) {
    final StoreColors c = StoreColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.tile,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Text(text, style: TextStyle(color: c.body, height: 1.5)),
      ),
    );
  }

  List<Widget> _reading(BuildContext context, _Profile p) {
    if (p.reading.isEmpty && p.finished.isEmpty) {
      return <Widget>[_notice(context, t.kitapsen_user_no_reading)];
    }
    Widget row(StorePublicProgress b, {required bool finished}) => ListTile(
      contentPadding: EdgeInsets.zero,
      leading: SizedBox(width: 40, child: StoreCover(url: b.coverUrl)),
      title: Text(b.title),
      subtitle: Text(
        finished
            ? t.kitapsen_feed_finished_badge
            : t.kitapsen_feed_percent(n: b.percent.round()),
      ),
      onTap: () => openStoreBook(context, b.bookId),
    );
    return <Widget>[
      if (p.reading.isNotEmpty) ...<Widget>[
        StoreSectionHeader(title: t.kitapsen_user_currently_reading),
        for (final StorePublicProgress b in p.reading) row(b, finished: false),
        const SizedBox(height: 16),
      ],
      if (p.finished.isNotEmpty) ...<Widget>[
        StoreSectionHeader(title: t.kitapsen_user_finished),
        for (final StorePublicProgress b in p.finished) row(b, finished: true),
      ],
    ];
  }

  List<Widget> _reviews(BuildContext context, _Profile p) {
    final StoreColors c = StoreColors.of(context);
    if (p.reviews.isEmpty) {
      return <Widget>[_notice(context, t.kitapsen_user_no_reviews)];
    }
    return <Widget>[
      for (final StoreUserReview r in p.reviews)
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: InkWell(
            onTap: () => openStoreBook(context, r.bookId),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SizedBox(width: 48, child: StoreCover(url: r.bookCoverUrl)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        r.bookTitle,
                        style: TextStyle(
                          color: c.ink,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      StoreRating(rating: r.rating.toDouble(), size: 14),
                      if (r.title != null)
                        Text(
                          r.title!,
                          style: TextStyle(
                            color: c.ink,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      if (r.content != null)
                        Text(r.content!, style: TextStyle(color: c.body)),
                      Text(
                        storeDate(r.createdAt),
                        style: TextStyle(color: c.muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
    ];
  }
}

/// Followers or followed readers of [username].
class KitapsenUserConnectionsPage extends ConsumerStatefulWidget {
  const KitapsenUserConnectionsPage({
    super.key,
    required this.username,
    required this.following,
  });

  final String username;
  final bool following;

  @override
  ConsumerState<KitapsenUserConnectionsPage> createState() =>
      _KitapsenUserConnectionsPageState();
}

class _KitapsenUserConnectionsPageState
    extends ConsumerState<KitapsenUserConnectionsPage> {
  late Future<List<StoreUser>> _load = _fetch();

  Future<List<StoreUser>> _fetch() async => (await KitapsenStore.open(
    ref.read(appProvider).database,
  )).userConnections(widget.username, following: widget.following);

  @override
  Widget build(BuildContext context) => FushiPageScaffold(
    title: widget.following
        ? t.kitapsen_user_following_title
        : t.kitapsen_user_followers_title,
    body: FutureBuilder<List<StoreUser>>(
      future: _load,
      builder: (_, AsyncSnapshot<List<StoreUser>> s) => storeAsync(
        s,
        onRetry: () => setState(() => _load = _fetch()),
        isEmpty: (List<StoreUser> l) => l.isEmpty,
        emptyIcon: Icons.people_outline,
        emptyMessage: t.kitapsen_user_no_connections,
        builder: (List<StoreUser> users) => ListView(
          padding: withBottomSafeInset(context, EdgeInsets.zero),
          children: <Widget>[
            for (final StoreUser u in users)
              ListTile(
                leading: StoreInitialAvatar(
                  name: u.name.isEmpty ? u.username : u.name,
                  imageUrl: u.imageUrl,
                  radius: 20,
                ),
                title: Text(u.name.isEmpty ? u.username : u.name),
                subtitle: Text('@${u.username}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  adaptivePageRoute<void>(
                    context: context,
                    builder: (_) => KitapsenUserPage(username: u.username),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
