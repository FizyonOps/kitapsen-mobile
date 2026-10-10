/// Book clubs ("Kitap Kulüpleri"), the working part of the website's
/// community area: create, join or leave a club, see its members and chat.
/// (Challenges, events and Q&A are left out: they are broken on the website
/// itself.)
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fushi/src/models/app_model.dart';
import 'package:fushi/src/pages/implementations/kitapsen_store/kitapsen_store_widgets.dart';
import 'package:fushi/src/pages/implementations/kitapsen_store/kitapsen_user_page.dart';
import 'package:fushi/src/sync/kitapsen_community.dart';
import 'package:fushi/src/sync/kitapsen_store.dart';
import 'package:fushi/utils.dart';

class KitapsenClubsPage extends ConsumerStatefulWidget {
  const KitapsenClubsPage({super.key});

  @override
  ConsumerState<KitapsenClubsPage> createState() => _KitapsenClubsPageState();
}

class _KitapsenClubsPageState extends ConsumerState<KitapsenClubsPage> {
  late Future<(KitapsenStore, StoreMe, List<StoreBookClub>)> _load = _fetch();
  bool _busy = false;

  Future<(KitapsenStore, StoreMe, List<StoreBookClub>)> _fetch() async {
    final KitapsenStore store = await KitapsenStore.open(
      ref.read(appProvider).database,
    );
    final (StoreMe me, List<StoreBookClub> clubs) = await (
      store.me(),
      store.bookClubs(),
    ).wait;
    return (store, me, clubs);
  }

  void _reload() => setState(() => _load = _fetch());

  Future<void> _create(KitapsenStore store) async {
    final ({String text, String? extra})? r = await showStoreTextDialog(
      context,
      title: t.kitapsen_clubs_create,
      label: t.kitapsen_clubs_name,
      extraLabel: t.kitapsen_collections_description,
    );
    if (r == null) return;
    try {
      await store.createBookClub(r.text, description: r.extra);
      _reload();
    } catch (e, stack) {
      storeActionFailed(e, stack, 'KitapsenClubsPage.create');
    }
  }

  Future<void> _membership(
    KitapsenStore store,
    StoreBookClub club,
    bool join,
  ) async {
    setState(() => _busy = true);
    try {
      await store.setClubMember(club.id, join);
      _reload();
    } catch (e, stack) {
      storeActionFailed(e, stack, 'KitapsenClubsPage.membership');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final FushiDesignTokens tokens = FushiDesignTokens.of(context);
    return FutureBuilder<(KitapsenStore, StoreMe, List<StoreBookClub>)>(
      future: _load,
      builder:
          (_, AsyncSnapshot<(KitapsenStore, StoreMe, List<StoreBookClub>)> s) {
            final KitapsenStore? store = s.data?.$1;
            return FushiPageScaffold(
              title: t.kitapsen_clubs_title,
              actions: <Widget>[
                if (store != null)
                  IconButton(
                    key: const ValueKey<String>('kitapsen-clubs-new'),
                    tooltip: t.kitapsen_clubs_create,
                    icon: const Icon(Icons.add),
                    onPressed: () => _create(store),
                  ),
              ],
              body: storeAsync(
                s,
                onRetry: _reload,
                isEmpty: ((KitapsenStore, StoreMe, List<StoreBookClub>) d) =>
                    d.$3.isEmpty,
                emptyIcon: Icons.groups_outlined,
                emptyMessage: t.kitapsen_clubs_empty,
                builder: ((KitapsenStore, StoreMe, List<StoreBookClub>) d) =>
                    ListView(
                      padding: withBottomSafeInset(
                        context,
                        EdgeInsets.all(tokens.spacing.page),
                      ),
                      children: <Widget>[
                        for (final StoreBookClub club in d.$3)
                          _card(context, d.$1, d.$2, club),
                      ],
                    ),
              ),
            );
          },
    );
  }

  Widget _card(
    BuildContext context,
    KitapsenStore store,
    StoreMe me,
    StoreBookClub club,
  ) {
    final StoreColors c = StoreColors.of(context);
    final bool member = club.memberIds.contains(me.id);
    final bool owner = club.ownerId == me.id;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () async {
            await Navigator.of(context).push(
              adaptivePageRoute<void>(
                context: context,
                builder: (_) => KitapsenClubPage(club: club, member: member),
              ),
            );
            if (mounted) _reload();
          },
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: c.border),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          club.name,
                          style: TextStyle(
                            color: c.ink,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (owner)
                        StoreBadgeChip(
                          label: t.kitapsen_clubs_owner,
                          color: c.accent,
                        ),
                    ],
                  ),
                  if (club.description != null) ...<Widget>[
                    const SizedBox(height: 6),
                    Text(
                      club.description!,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: c.body),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: <Widget>[
                      Icon(Icons.groups_outlined, size: 18, color: c.muted),
                      const SizedBox(width: 6),
                      Text(
                        t.kitapsen_clubs_members_count(n: club.memberCount),
                        style: TextStyle(color: c.muted),
                      ),
                      const Spacer(),
                      if (!owner)
                        member
                            ? OutlinedButton(
                                onPressed: _busy
                                    ? null
                                    : () => _membership(store, club, false),
                                child: Text(t.kitapsen_clubs_leave),
                              )
                            : FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: c.accent,
                                  foregroundColor: c.onAccent,
                                ),
                                onPressed: _busy
                                    ? null
                                    : () => _membership(store, club, true),
                                child: Text(t.kitapsen_clubs_join),
                              ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class KitapsenClubPage extends ConsumerStatefulWidget {
  const KitapsenClubPage({super.key, required this.club, required this.member});

  final StoreBookClub club;
  final bool member;

  @override
  ConsumerState<KitapsenClubPage> createState() => _KitapsenClubPageState();
}

class _KitapsenClubPageState extends ConsumerState<KitapsenClubPage> {
  final TextEditingController _message = TextEditingController();
  late Future<(KitapsenStore, List<StoreClubMember>, List<StoreClubMessage>)>
  _load = _fetch();
  bool _busy = false;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<(KitapsenStore, List<StoreClubMember>, List<StoreClubMessage>)>
  _fetch() async {
    final KitapsenStore store = await KitapsenStore.open(
      ref.read(appProvider).database,
    );
    final int id = widget.club.id;
    final (
      List<StoreClubMember> members,
      List<StoreClubMessage> messages,
    ) = await (
      store.clubMembers(id),
      widget.member
          ? store.clubMessages(id)
          : Future<List<StoreClubMessage>>.value(const <StoreClubMessage>[]),
    ).wait;
    return (store, members, messages);
  }

  Future<void> _send(KitapsenStore store) async {
    final String text = _message.text.trim();
    if (text.isEmpty) return;
    setState(() => _busy = true);
    try {
      await store.postClubMessage(widget.club.id, text);
      _message.clear();
      if (mounted) setState(() => _load = _fetch());
    } catch (e, stack) {
      storeActionFailed(e, stack, 'KitapsenClubPage.send');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final StoreColors c = StoreColors.of(context);
    final FushiDesignTokens tokens = FushiDesignTokens.of(context);
    return FushiPageScaffold(
      title: widget.club.name,
      body:
          FutureBuilder<
            (KitapsenStore, List<StoreClubMember>, List<StoreClubMessage>)
          >(
            future: _load,
            builder:
                (
                  _,
                  AsyncSnapshot<
                    (
                      KitapsenStore,
                      List<StoreClubMember>,
                      List<StoreClubMessage>,
                    )
                  >
                  s,
                ) => storeAsync(
                  s,
                  onRetry: () => setState(() => _load = _fetch()),
                  builder:
                      (
                        (
                          KitapsenStore,
                          List<StoreClubMember>,
                          List<StoreClubMessage>,
                        )
                        d,
                      ) => Column(
                        children: <Widget>[
                          Expanded(
                            child: ListView(
                              padding: EdgeInsets.all(tokens.spacing.page),
                              children: <Widget>[
                                if (widget.club.description != null)
                                  Text(
                                    widget.club.description!,
                                    style: TextStyle(
                                      color: c.body,
                                      height: 1.5,
                                    ),
                                  ),
                                const SizedBox(height: 16),
                                StoreSectionHeader(
                                  title: t.kitapsen_clubs_members,
                                ),
                                SizedBox(
                                  height: 84,
                                  child: ListView(
                                    scrollDirection: Axis.horizontal,
                                    children: <Widget>[
                                      for (final StoreClubMember m in d.$2)
                                        InkWell(
                                          onTap: () =>
                                              Navigator.of(context).push(
                                                adaptivePageRoute<void>(
                                                  context: context,
                                                  builder: (_) =>
                                                      KitapsenUserPage(
                                                        username: m.username,
                                                      ),
                                                ),
                                              ),
                                          child: Padding(
                                            padding: const EdgeInsets.only(
                                              right: 12,
                                              top: 8,
                                            ),
                                            child: Column(
                                              children: <Widget>[
                                                StoreInitialAvatar(
                                                  name: m.name ?? m.username,
                                                  imageUrl: m.imageUrl,
                                                  radius: 22,
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  m.username,
                                                  style: TextStyle(
                                                    color: c.muted,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                                StoreSectionHeader(
                                  title: t.kitapsen_clubs_chat,
                                ),
                                const SizedBox(height: 8),
                                if (!widget.member)
                                  Text(
                                    t.kitapsen_clubs_join_to_chat,
                                    style: TextStyle(color: c.muted),
                                  )
                                else if (d.$3.isEmpty)
                                  Text(
                                    t.kitapsen_clubs_no_messages,
                                    style: TextStyle(color: c.muted),
                                  ),
                                for (final StoreClubMessage m in d.$3)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: <Widget>[
                                        StoreInitialAvatar(
                                          name: m.username ?? '?',
                                          radius: 16,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: <Widget>[
                                              Text(
                                                '@${m.username ?? '?'} · ${storeDate(m.createdAt)}',
                                                style: TextStyle(
                                                  color: c.muted,
                                                  fontSize: 12,
                                                ),
                                              ),
                                              Text(
                                                m.content,
                                                style: TextStyle(
                                                  color: c.ink,
                                                  height: 1.4,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (widget.member)
                            SafeArea(
                              top: false,
                              child: Padding(
                                padding: EdgeInsets.fromLTRB(
                                  tokens.spacing.page,
                                  8,
                                  8,
                                  8,
                                ),
                                child: Row(
                                  children: <Widget>[
                                    Expanded(
                                      child: TextField(
                                        controller: _message,
                                        minLines: 1,
                                        maxLines: 4,
                                        decoration: InputDecoration(
                                          hintText:
                                              t.kitapsen_clubs_message_hint,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: t.kitapsen_clubs_send,
                                      onPressed: _busy
                                          ? null
                                          : () => _send(d.$1),
                                      icon: Icon(Icons.send, color: c.accent),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                ),
          ),
    );
  }
}
