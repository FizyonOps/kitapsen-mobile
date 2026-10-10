/// "Hesabım": the website's account menu (profile, library, collections,
/// notebooks, goals, feed, clubs, settings) plus the blog, publishers and
/// authors. Left out on purpose: orders, payment, subscriptions, deals and
/// gift cards (prices / purchases, see `kitapsen_edition.dart`).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fushi/src/models/app_model.dart';
import 'package:fushi/src/models/home_tab.dart';
import 'package:fushi/src/pages/implementations/home_page.dart'
    show homeShellTabNotifier;
import 'package:fushi/src/pages/implementations/kitapsen_store/kitapsen_account_page.dart';
import 'package:fushi/src/pages/implementations/kitapsen_store/kitapsen_blog_pages.dart';
import 'package:fushi/src/pages/implementations/kitapsen_store/kitapsen_clubs_pages.dart';
import 'package:fushi/src/pages/implementations/kitapsen_store/kitapsen_collections_pages.dart';
import 'package:fushi/src/pages/implementations/kitapsen_store/kitapsen_directory_pages.dart';
import 'package:fushi/src/pages/implementations/kitapsen_store/kitapsen_feed_page.dart';
import 'package:fushi/src/pages/implementations/kitapsen_store/kitapsen_following_page.dart';
import 'package:fushi/src/pages/implementations/kitapsen_store/kitapsen_goals_page.dart';
import 'package:fushi/src/pages/implementations/kitapsen_store/kitapsen_notebooks_pages.dart';
import 'package:fushi/src/pages/implementations/kitapsen_store/kitapsen_notifications_page.dart';
import 'package:fushi/src/pages/implementations/kitapsen_store/kitapsen_profile_page.dart';
import 'package:fushi/src/pages/implementations/kitapsen_store/kitapsen_store_widgets.dart';
import 'package:fushi/src/pages/implementations/kitapsen_store/kitapsen_user_page.dart';
import 'package:fushi/src/pages/implementations/kitapsen_store/kitapsen_wishlist_page.dart';
import 'package:fushi/src/sync/kitapsen_community.dart';
import 'package:fushi/src/sync/kitapsen_store.dart';
import 'package:fushi/utils.dart';

class KitapsenAccountHubPage extends ConsumerStatefulWidget {
  const KitapsenAccountHubPage({super.key});

  @override
  ConsumerState<KitapsenAccountHubPage> createState() =>
      _KitapsenAccountHubPageState();
}

class _KitapsenAccountHubPageState
    extends ConsumerState<KitapsenAccountHubPage> {
  late Future<(KitapsenStore, StoreMe)> _load = _fetch();

  Future<(KitapsenStore, StoreMe)> _fetch() async {
    final KitapsenStore store = await KitapsenStore.open(
      ref.read(appProvider).database,
    );
    return (store, await store.me());
  }

  Future<void> _push(Widget page) async {
    await Navigator.of(
      context,
    ).push(adaptivePageRoute<void>(context: context, builder: (_) => page));
    if (mounted) setState(() => _load = _fetch());
  }

  /// Settings › Kitapsen account (sign out, delete). Signed out on return:
  /// this menu has nothing left to show.
  Future<void> _openSignInSettings() async {
    await openKitapsenSignIn(context);
    if (!mounted) return;
    final KitapsenStore store = await KitapsenStore.open(
      ref.read(appProvider).database,
    );
    if (!mounted) return;
    if (store.signedIn) {
      setState(() => _load = _fetch());
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FushiPageScaffold(
      title: t.kitapsen_hub_title,
      body: FutureBuilder<(KitapsenStore, StoreMe)>(
        future: _load,
        builder: (_, AsyncSnapshot<(KitapsenStore, StoreMe)> s) => storeAsync(
          s,
          onRetry: () => setState(() => _load = _fetch()),
          builder: ((KitapsenStore, StoreMe) data) => _menu(context, data.$2),
        ),
      ),
    );
  }

  Widget _menu(BuildContext context, StoreMe me) {
    final StoreColors c = StoreColors.of(context);
    final FushiDesignTokens tokens = FushiDesignTokens.of(context);
    return ListView(
      padding: withBottomSafeInset(context, EdgeInsets.zero),
      children: <Widget>[
        Padding(
          padding: EdgeInsets.fromLTRB(
            tokens.spacing.page,
            tokens.spacing.gap,
            tokens.spacing.page,
            tokens.spacing.gap,
          ),
          child: Row(
            children: <Widget>[
              StoreInitialAvatar(
                name: me.name.isEmpty ? me.username : me.name,
                radius: 28,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      me.name.isEmpty ? me.username : me.name,
                      style: TextStyle(
                        color: c.ink,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '@${me.username}',
                      style: TextStyle(color: c.muted, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        StoreSectionLabel(t.kitapsen_hub_reading),
        StoreMenuRow(
          icon: Icons.menu_book_outlined,
          title: t.kitapsen_hub_library,
          onTap: () {
            homeShellTabNotifier.value = HomeTab.books;
            Navigator.of(context).popUntil((Route<dynamic> r) => r.isFirst);
          },
        ),
        StoreMenuRow(
          icon: Icons.favorite_border,
          title: t.kitapsen_wishlist_title,
          onTap: () => _push(const KitapsenWishlistPage()),
        ),
        StoreMenuRow(
          icon: Icons.collections_bookmark_outlined,
          title: t.kitapsen_collections_title,
          onTap: () => _push(const KitapsenCollectionsPage()),
        ),
        StoreMenuRow(
          icon: Icons.edit_note_outlined,
          title: t.kitapsen_notebooks_title,
          onTap: () => _push(const KitapsenNotebooksPage()),
        ),
        StoreMenuRow(
          icon: Icons.flag_outlined,
          title: t.kitapsen_goals_title,
          onTap: () => _push(const KitapsenGoalsPage()),
        ),
        StoreSectionLabel(t.kitapsen_hub_social),
        StoreMenuRow(
          icon: Icons.dynamic_feed_outlined,
          title: t.kitapsen_feed_title,
          onTap: () => _push(const KitapsenFeedPage()),
        ),
        StoreMenuRow(
          icon: Icons.people_outline,
          title: t.kitapsen_following_title,
          onTap: () => _push(const KitapsenFollowingPage()),
        ),
        StoreMenuRow(
          icon: Icons.groups_outlined,
          title: t.kitapsen_clubs_title,
          onTap: () => _push(const KitapsenClubsPage()),
        ),
        StoreMenuRow(
          icon: Icons.notifications_none,
          title: t.kitapsen_notifications_title,
          onTap: () => _push(const KitapsenNotificationsPage()),
        ),
        StoreMenuRow(
          icon: Icons.public,
          title: t.kitapsen_hub_public_profile,
          onTap: () => _push(KitapsenUserPage(username: me.username)),
        ),
        StoreSectionLabel(t.kitapsen_hub_discover),
        StoreMenuRow(
          icon: Icons.article_outlined,
          title: t.kitapsen_blog_title,
          onTap: () => _push(const KitapsenBlogPage()),
        ),
        StoreMenuRow(
          icon: Icons.domain_outlined,
          title: t.kitapsen_publishers_title,
          onTap: () => _push(const KitapsenPublishersPage()),
        ),
        StoreMenuRow(
          icon: Icons.person_search_outlined,
          title: t.kitapsen_authors_title,
          onTap: () => _push(const KitapsenAuthorsPage()),
        ),
        StoreSectionLabel(t.kitapsen_hub_account),
        StoreMenuRow(
          icon: Icons.badge_outlined,
          title: t.kitapsen_profile_title,
          onTap: () => _push(const KitapsenProfilePage()),
        ),
        StoreMenuRow(
          icon: Icons.manage_accounts_outlined,
          title: t.kitapsen_settings_title,
          onTap: () => _push(const KitapsenAccountPage()),
        ),
        StoreMenuRow(
          icon: Icons.logout,
          title: t.kitapsen_hub_sign_in_settings,
          onTap: () => unawaited(_openSignInSettings()),
        ),
      ],
    );
  }
}
