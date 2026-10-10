/// "Profilim", as on the website: the display name, whether reading activity
/// shows on the public profile, and a link to that profile.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fushi/src/models/app_model.dart';
import 'package:fushi/src/pages/implementations/kitapsen_store/kitapsen_store_widgets.dart';
import 'package:fushi/src/pages/implementations/kitapsen_store/kitapsen_user_page.dart';
import 'package:fushi/src/sync/kitapsen_community.dart';
import 'package:fushi/src/sync/kitapsen_store.dart';
import 'package:fushi/utils.dart';

class KitapsenProfilePage extends ConsumerStatefulWidget {
  const KitapsenProfilePage({super.key});

  @override
  ConsumerState<KitapsenProfilePage> createState() =>
      _KitapsenProfilePageState();
}

class _KitapsenProfilePageState extends ConsumerState<KitapsenProfilePage> {
  final TextEditingController _name = TextEditingController();
  late Future<(KitapsenStore, StoreMe, bool)> _load = _fetch();
  bool _shared = false;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<(KitapsenStore, StoreMe, bool)> _fetch() async {
    final KitapsenStore store = await KitapsenStore.open(
      ref.read(appProvider).database,
    );
    final (StoreMe me, bool shared) = await (
      store.me(),
      store.readingShared(),
    ).wait;
    _name.text = me.name;
    _shared = shared;
    return (store, me, shared);
  }

  Future<void> _run(Future<void> Function() action, {String? done}) async {
    setState(() => _busy = true);
    try {
      await action();
      if (done != null) {
        FushiToast.show(msg: done, severity: ToastSeverity.success);
      }
    } catch (e, stack) {
      storeActionFailed(e, stack, 'KitapsenProfilePage');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FushiPageScaffold(
      title: t.kitapsen_profile_title,
      body: FutureBuilder<(KitapsenStore, StoreMe, bool)>(
        future: _load,
        builder: (_, AsyncSnapshot<(KitapsenStore, StoreMe, bool)> s) =>
            storeAsync(
              s,
              onRetry: () => setState(() => _load = _fetch()),
              builder: ((KitapsenStore, StoreMe, bool) d) =>
                  _form(context, d.$1, d.$2),
            ),
      ),
    );
  }

  Widget _form(BuildContext context, KitapsenStore store, StoreMe me) {
    final StoreColors c = StoreColors.of(context);
    final FushiDesignTokens tokens = FushiDesignTokens.of(context);
    return ListView(
      padding: withBottomSafeInset(
        context,
        EdgeInsets.all(tokens.spacing.page),
      ),
      children: <Widget>[
        Row(
          children: <Widget>[
            StoreInitialAvatar(
              name: me.name.isEmpty ? me.username : me.name,
              radius: 32,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '@${me.username}',
                    style: TextStyle(
                      color: c.ink,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(me.email, style: TextStyle(color: c.muted)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        TextField(
          key: const ValueKey<String>('kitapsen-profile-name'),
          controller: _name,
          maxLength: 30,
          decoration: InputDecoration(labelText: t.kitapsen_profile_name),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton(
            key: const ValueKey<String>('kitapsen-profile-save'),
            onPressed: _busy
                ? null
                : () {
                    final String name = _name.text.trim();
                    if (name.length < 2) {
                      FushiToast.show(
                        msg: t.kitapsen_register_name_invalid,
                        severity: ToastSeverity.error,
                      );
                      return;
                    }
                    _run(
                      () => store.updateMe(<String, Object>{'name': name}),
                      done: t.kitapsen_common_saved,
                    );
                  },
            child: Text(t.kitapsen_common_save),
          ),
        ),
        const SizedBox(height: 24),
        SwitchListTile(
          key: const ValueKey<String>('kitapsen-profile-sharing'),
          contentPadding: EdgeInsets.zero,
          value: _shared,
          title: Text(t.kitapsen_profile_sharing),
          subtitle: Text(t.kitapsen_profile_sharing_hint),
          onChanged: _busy
              ? null
              : (bool v) => _run(() async {
                  await store.setReadingShared(v);
                  if (mounted) setState(() => _shared = v);
                }),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () => Navigator.of(context).push(
            adaptivePageRoute<void>(
              context: context,
              builder: (_) => KitapsenUserPage(username: me.username),
            ),
          ),
          icon: const Icon(Icons.public),
          label: Text(t.kitapsen_hub_public_profile),
        ),
      ],
    );
  }
}
