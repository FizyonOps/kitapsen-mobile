/// "Hesap Ayarları", as on the website: email, private profile, email
/// notifications, password, blocked users. The price-drop switches are left
/// out (a price signal); deleting the account stays in Settings › Kitapsen
/// account.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fushi/src/models/app_model.dart';
import 'package:fushi/src/pages/implementations/kitapsen_store/kitapsen_store_widgets.dart';
import 'package:fushi/src/sync/kitapsen_community.dart';
import 'package:fushi/src/sync/kitapsen_store.dart';
import 'package:fushi/src/sync/sync_backend.dart' show SyncBackendError;
import 'package:fushi/src/sync/sync_repository.dart';
import 'package:fushi/utils.dart';

class KitapsenAccountPage extends ConsumerStatefulWidget {
  const KitapsenAccountPage({super.key});

  @override
  ConsumerState<KitapsenAccountPage> createState() =>
      _KitapsenAccountPageState();
}

class _KitapsenAccountPageState extends ConsumerState<KitapsenAccountPage> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _current = TextEditingController();
  final TextEditingController _next = TextEditingController();
  final TextEditingController _repeat = TextEditingController();
  late Future<(KitapsenStore, StoreMe, List<StoreUser>)> _load = _fetch();
  late StoreMe _me;
  List<StoreUser> _blocked = const <StoreUser>[];
  bool _busy = false;
  String? _passwordError;

  @override
  void dispose() {
    _email.dispose();
    _current.dispose();
    _next.dispose();
    _repeat.dispose();
    super.dispose();
  }

  Future<(KitapsenStore, StoreMe, List<StoreUser>)> _fetch() async {
    final KitapsenStore store = await KitapsenStore.open(
      ref.read(appProvider).database,
    );
    final (StoreMe me, List<StoreUser> blocked) = await (
      store.me(),
      store.blockedUsers(),
    ).wait;
    _me = me;
    _blocked = blocked;
    _email.text = me.email;
    return (store, me, blocked);
  }

  Future<bool> _run(Future<void> Function() action, {String? done}) async {
    setState(() => _busy = true);
    try {
      await action();
      if (done != null) {
        FushiToast.show(msg: done, severity: ToastSeverity.success);
      }
      return true;
    } catch (e, stack) {
      storeActionFailed(e, stack, 'KitapsenAccountPage');
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Turns one notification / privacy switch and keeps the rest as they are.
  Future<void> _setFlag(KitapsenStore store, String field, bool value) async {
    if (await _run(() => store.updateMe(<String, Object>{field: value}))) {
      final StoreMe m = _me;
      setState(
        () => _me = StoreMe(
          id: m.id,
          name: m.name,
          username: m.username,
          email: m.email,
          isPrivate: field == 'is_private' ? value : m.isPrivate,
          newFollowerEmail: field == 'new_follower_email'
              ? value
              : m.newFollowerEmail,
          newCommentEmail: field == 'new_comment_email'
              ? value
              : m.newCommentEmail,
          newSaleEmail: field == 'new_sale_email' ? value : m.newSaleEmail,
        ),
      );
    }
  }

  Future<void> _changePassword(KitapsenStore store) async {
    setState(() => _passwordError = null);
    if (_next.text.length < 8) {
      setState(() => _passwordError = t.kitapsen_register_password_short);
      return;
    }
    if (_next.text != _repeat.text) {
      setState(() => _passwordError = t.kitapsen_settings_passwords_differ);
      return;
    }
    setState(() => _busy = true);
    try {
      await store.changePassword(_current.text, _next.text);
      // A password sign-in keeps the password to sign in again when the
      // session expires; keep it current. (Google / Apple sign-ins hold an
      // app token instead and are unaffected.)
      final SyncRepository repo = SyncRepository(
        ref.read(appProvider).database,
      );
      final ({String url, String username, String password, String? token})?
      stored = await repo.getKitapsenAccount();
      if (stored != null && stored.token == null) {
        await repo.setKitapsenAccount(
          url: stored.url,
          username: stored.username,
          password: _next.text,
        );
      }
      _current.clear();
      _next.clear();
      _repeat.clear();
      FushiToast.show(
        msg: t.kitapsen_settings_password_changed,
        severity: ToastSeverity.success,
      );
    } on SyncBackendError catch (e, stack) {
      // A wrong current password answers 400.
      ErrorLogService.instance.log('KitapsenAccountPage.password', e, stack);
      if (mounted) {
        setState(() => _passwordError = t.kitapsen_settings_password_failed);
      }
    } catch (e, stack) {
      storeActionFailed(e, stack, 'KitapsenAccountPage.password');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FushiPageScaffold(
      title: t.kitapsen_settings_title,
      body: FutureBuilder<(KitapsenStore, StoreMe, List<StoreUser>)>(
        future: _load,
        builder:
            (_, AsyncSnapshot<(KitapsenStore, StoreMe, List<StoreUser>)> s) =>
                storeAsync(
                  s,
                  onRetry: () => setState(() => _load = _fetch()),
                  builder: ((KitapsenStore, StoreMe, List<StoreUser>) d) =>
                      _settings(context, d.$1),
                ),
      ),
    );
  }

  Widget _settings(BuildContext context, KitapsenStore store) {
    final StoreColors c = StoreColors.of(context);
    final FushiDesignTokens tokens = FushiDesignTokens.of(context);
    final EdgeInsets side = EdgeInsets.symmetric(
      horizontal: tokens.spacing.page,
    );
    return ListView(
      padding: withBottomSafeInset(context, EdgeInsets.zero),
      children: <Widget>[
        StoreSectionLabel(t.kitapsen_settings_profile),
        Padding(
          padding: side,
          child: TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            decoration: InputDecoration(labelText: t.kitapsen_register_email),
          ),
        ),
        Padding(
          padding: side.copyWith(top: 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: FilledButton(
              onPressed: _busy
                  ? null
                  : () {
                      final String email = _email.text.trim();
                      if (!RegExp(
                        r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                      ).hasMatch(email)) {
                        FushiToast.show(
                          msg: t.kitapsen_register_email_invalid,
                          severity: ToastSeverity.error,
                        );
                        return;
                      }
                      _run(
                        () => store.updateMe(<String, Object>{'email': email}),
                        done: t.kitapsen_common_saved,
                      );
                    },
              child: Text(t.kitapsen_common_save),
            ),
          ),
        ),
        StoreSectionLabel(t.kitapsen_settings_privacy),
        SwitchListTile(
          value: _me.isPrivate,
          title: Text(t.kitapsen_settings_private),
          subtitle: Text(t.kitapsen_settings_private_hint),
          onChanged: _busy
              ? null
              : (bool v) => _setFlag(store, 'is_private', v),
        ),
        StoreSectionLabel(t.kitapsen_settings_notifications),
        SwitchListTile(
          value: _me.newFollowerEmail,
          title: Text(t.kitapsen_settings_follower_email),
          onChanged: _busy
              ? null
              : (bool v) => _setFlag(store, 'new_follower_email', v),
        ),
        SwitchListTile(
          value: _me.newCommentEmail,
          title: Text(t.kitapsen_settings_comment_email),
          onChanged: _busy
              ? null
              : (bool v) => _setFlag(store, 'new_comment_email', v),
        ),
        SwitchListTile(
          value: _me.newSaleEmail,
          title: Text(t.kitapsen_settings_sale_email),
          subtitle: Text(t.kitapsen_settings_author_emails),
          onChanged: _busy
              ? null
              : (bool v) => _setFlag(store, 'new_sale_email', v),
        ),
        StoreSectionLabel(t.kitapsen_settings_password),
        Padding(
          padding: side,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                TextField(
                  controller: _current,
                  obscureText: true,
                  autofillHints: const <String>[AutofillHints.password],
                  decoration: InputDecoration(
                    labelText: t.kitapsen_settings_current_password,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _next,
                  obscureText: true,
                  autofillHints: const <String>[AutofillHints.newPassword],
                  decoration: InputDecoration(
                    labelText: t.kitapsen_settings_new_password,
                    helperText: t.kitapsen_register_password_hint,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _repeat,
                  obscureText: true,
                  autofillHints: const <String>[AutofillHints.newPassword],
                  decoration: InputDecoration(
                    labelText: t.kitapsen_settings_repeat_password,
                    errorText: _passwordError,
                    errorMaxLines: 3,
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton(
                    onPressed: _busy ? null : () => _changePassword(store),
                    child: Text(t.kitapsen_settings_change_password),
                  ),
                ),
              ],
            ),
          ),
        ),
        StoreSectionLabel(t.kitapsen_settings_blocked),
        if (_blocked.isEmpty)
          Padding(
            padding: side.copyWith(top: 4, bottom: 8),
            child: Text(
              t.kitapsen_settings_no_blocked,
              style: TextStyle(color: c.muted),
            ),
          ),
        for (final StoreUser u in _blocked)
          ListTile(
            leading: StoreInitialAvatar(
              name: u.name.isEmpty ? u.username : u.name,
              imageUrl: u.imageUrl,
              radius: 18,
            ),
            title: Text(u.name.isEmpty ? u.username : u.name),
            subtitle: Text('@${u.username}'),
            trailing: TextButton(
              onPressed: _busy
                  ? null
                  : () async {
                      if (await _run(
                        () => store.setBlocked(u.username, false),
                      )) {
                        setState(
                          () => _blocked = <StoreUser>[
                            for (final StoreUser b in _blocked)
                              if (b.username != u.username) b,
                          ],
                        );
                      }
                    },
              child: Text(t.kitapsen_user_unblock),
            ),
          ),
        const SizedBox(height: 24),
      ],
    );
  }
}
