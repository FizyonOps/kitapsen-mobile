/// 设置 › 在线服务 › Kitapsen：书店账号的登录 / 退出。登录后书架远端区列出该账号
/// 已购的书（[KitapsenClient]），阅读进度与 kitapsen.com 双向同步。
/// Sign-in is by password, Google, or Apple (iOS only); a signed-in account
/// can also be deleted here (App Store 5.1.1(v): the app creates accounts).
library;

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fushi_core/fushi_core.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart'
    show SignInWithAppleButton, SignInWithAppleButtonStyle;

import 'package:fushi/src/media/sources/reader_fushi_source.dart';
import 'package:fushi/src/models/app_model.dart';
import 'package:fushi/src/pages/implementations/tag_filter_sheet.dart'
    show bookTagMapProvider, srtBookTagMapProvider;
import 'package:fushi/src/pages/implementations/source_toggle_section.dart';
import 'package:fushi/src/sync/kitapsen_client.dart';
import 'package:fushi/src/sync/remote_library_cache.dart';
import 'package:fushi/src/sync/remote_library_source.dart';
import 'package:fushi/src/sync/sync_backend.dart' show SyncAuthError;
import 'package:fushi/src/sync/sync_repository.dart';
import 'package:fushi/utils.dart';

class KitapsenAccountSettingsSection extends ConsumerStatefulWidget {
  const KitapsenAccountSettingsSection({super.key});

  @override
  ConsumerState<KitapsenAccountSettingsSection> createState() =>
      _KitapsenAccountSettingsSectionState();
}

class _KitapsenAccountSettingsSectionState
    extends ConsumerState<KitapsenAccountSettingsSection> {
  final TextEditingController _url = TextEditingController(
    text: kKitapsenDefaultUrl,
  );
  final TextEditingController _username = TextEditingController();
  final TextEditingController _password = TextEditingController();

  /// null = 还没读出存储的账号；空串 = 未登录。
  String? _signedInAs;
  bool _busy = false;
  String? _error;

  /// Failure of a Google / Apple sign-in, shown under those buttons rather
  /// than under the password field.
  String? _providerError;

  @override
  void initState() {
    super.initState();
    _loadAccount();
  }

  @override
  void dispose() {
    _url.dispose();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  FushiDatabase get _db => ref.read(appProvider).database;

  Future<void> _loadAccount() async {
    final ({String url, String username, String password, String? token})?
    stored = await SyncRepository(_db).getKitapsenAccount();
    if (!mounted) return;
    setState(() {
      _signedInAs = stored?.username ?? '';
      if (stored != null) _url.text = stored.url;
    });
  }

  /// The store address. Release builds always use [kKitapsenDefaultUrl]; the
  /// editable field exists only in debug / profile builds for local testing
  /// (e.g. http://10.0.2.2:8000 from the Android emulator).
  String get _serverUrl => !kReleaseMode && _url.text.trim().isNotEmpty
      ? _url.text.trim()
      : kKitapsenDefaultUrl;

  Future<void> _signIn() async {
    final KitapsenAccount account = KitapsenAccount(
      url: _serverUrl,
      username: _username.text.trim(),
      password: _password.text,
    );
    if (account.username.isEmpty || account.password.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
      _providerError = null;
    });
    try {
      await _signInAs(account);
    } on SyncAuthError {
      if (mounted) setState(() => _error = t.kitapsen_account_sign_in_rejected);
    } catch (e, stack) {
      ErrorLogService.instance.log('KitapsenAccountSettings.signIn', e, stack);
      if (mounted) setState(() => _error = t.kitapsen_account_sign_in_failed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Google / Apple: [flow] returns the account holding its app token, or
  /// null when the person backed out of the browser / Apple sheet.
  Future<void> _signInWithProvider(
    Future<KitapsenAccount?> Function(String url) flow,
  ) async {
    setState(() {
      _busy = true;
      _error = null;
      _providerError = null;
    });
    try {
      final KitapsenAccount? account = await flow(_serverUrl);
      if (account != null) await _signInAs(account);
    } on SyncAuthError catch (e) {
      if (mounted) {
        setState(
          () => _providerError = e.isForbidden
              ? t.kitapsen_account_deleted
              : t.kitapsen_account_social_sign_in_failed,
        );
      }
    } catch (e, stack) {
      ErrorLogService.instance.log(
        'KitapsenAccountSettings.signInWithProvider',
        e,
        stack,
      );
      if (mounted) {
        setState(
          () => _providerError = t.kitapsen_account_social_sign_in_failed,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signInAs(KitapsenAccount account) async {
    // 先真登录一次，凭据被接受才落盘：存下一份登不进去的凭据，书架只会静默空着。
    await KitapsenClient(db: _db, account: account).signIn();
    await SyncRepository(_db).setKitapsenAccount(
      url: account.url,
      username: account.username,
      password: account.password,
      token: account.token,
    );
    ref
        .read(remoteLibraryCacheProvider)
        .invalidateSource(kKitapsenRemoteLibrarySourceId);
    if (!mounted) return;
    _password.clear();
    setState(() => _signedInAs = account.username);
  }

  Future<void> _signOut() async {
    // Store books are licensed to the account, so signing out removes the
    // downloaded ones from this device; confirm once when there are any.
    final Set<String> storeBookUids = await kitapsenBookUids(_db);
    if (!mounted) return;
    if (storeBookUids.isNotEmpty) {
      final bool? confirmed = await showAppDialog<bool>(
        context: context,
        builder: (BuildContext dialogContext) => AlertDialog(
          content: Text(t.kitapsen_sign_out_removes_books),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(t.dialog_cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(t.kitapsen_account_sign_out),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    setState(() => _busy = true);
    try {
      final KitapsenClient? client = await KitapsenClient.restore(_db);
      await client?.signOut();
      await _forgetAccount(storeBookUids);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteAccount() async {
    final bool? confirmed = await showAppDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        content: Text(t.kitapsen_account_delete_confirm),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(t.dialog_cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
              foregroundColor: Theme.of(dialogContext).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(t.kitapsen_account_delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final KitapsenClient? client = await KitapsenClient.restore(_db);
      await client?.deleteAccount();
      await client?.signOut();
      await _forgetAccount(await kitapsenBookUids(_db));
    } catch (e, stack) {
      ErrorLogService.instance.log(
        'KitapsenAccountSettings.deleteAccount',
        e,
        stack,
      );
      if (mounted) setState(() => _error = t.kitapsen_account_delete_failed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Drops the stored account and the store books downloaded with it.
  Future<void> _forgetAccount(Set<String> storeBookUids) async {
    await SyncRepository(_db).clearKitapsenAccount();
    await _removeStoreBooks(storeBookUids);
    ref
        .read(remoteLibraryCacheProvider)
        .invalidateSource(kKitapsenRemoteLibrarySourceId);
    if (mounted) setState(() => _signedInAs = '');
  }

  /// Deletes every downloaded store book through the shelf's own deletion
  /// path (DB rows, reader positions, extracted files, cover overrides) and
  /// drops its store link. A failing book is logged and skipped; reading
  /// statistics are kept, as on the shelf's default delete.
  Future<void> _removeStoreBooks(Set<String> uids) async {
    if (uids.isEmpty) return;
    final AppModel appModel = ref.read(appProvider);
    for (final String uid in uids) {
      try {
        final EpubBookRow? book = await _db.getEpubBookByUid(uid);
        if (book != null) {
          final DeleteBookResult result = await ReaderFushiSource.instance
              .deleteBook(db: _db, bookKey: book.bookKey, appModel: appModel);
          if (!result.deleted) {
            ErrorLogService.instance.logDiagnostic(
              'KitapsenAccountSettings.removeStoreBook',
              '$uid: ${result.failureReason ?? 'not deleted'}',
            );
          }
        }
        await forgetKitapsenBook(_db, uid);
      } catch (e, stack) {
        ErrorLogService.instance.log(
          'KitapsenAccountSettings.removeStoreBook',
          e,
          stack,
        );
      }
    }
    ref.invalidate(fushiBooksProvider);
    ref.invalidate(bookTagMapProvider);
    ref.invalidate(srtBookTagMapProvider);
  }

  @override
  Widget build(BuildContext context) {
    final String? signedInAs = _signedInAs;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: FushiDesignTokens.of(context).spacing.rowHorizontal,
      ),
      child: Column(
        key: const ValueKey<String>('kitapsen-account-settings'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SourceSectionHeading(
            title: t.kitapsen_account_title,
            hint: t.kitapsen_account_hint,
            icon: Icons.storefront_outlined,
          ),
          if (signedInAs == null)
            const SizedBox.shrink()
          else if (signedInAs.isNotEmpty)
            _signedIn(signedInAs)
          else
            _signInForm(),
        ],
      ),
    );
  }

  Widget _signedIn(String username) {
    return FushiCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.account_circle_outlined),
            title: Text(username),
            subtitle: Text(_url.text),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              key: const ValueKey<String>('kitapsen-sign-out'),
              onPressed: _busy ? null : _signOut,
              icon: const Icon(Icons.logout),
              label: Text(t.kitapsen_account_sign_out),
            ),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const ValueKey<String>('kitapsen-delete-account'),
              onPressed: _busy ? null : _deleteAccount,
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              icon: const Icon(Icons.delete_forever_outlined),
              label: Text(t.kitapsen_account_delete),
            ),
          ),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
    );
  }

  Widget _signInForm() {
    return FushiCard(
      padding: const EdgeInsets.all(12),
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // Server address: debug / profile builds only (local backends).
            if (!kReleaseMode) ...<Widget>[
              TextField(
                key: const ValueKey<String>('kitapsen-url'),
                controller: _url,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(
                  labelText: t.kitapsen_account_server_url,
                ),
              ),
              const SizedBox(height: 8),
            ],
            TextField(
              key: const ValueKey<String>('kitapsen-username'),
              controller: _username,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const <String>[
                AutofillHints.email,
                AutofillHints.username,
              ],
              decoration: InputDecoration(
                labelText: t.kitapsen_account_username,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const ValueKey<String>('kitapsen-password'),
              controller: _password,
              obscureText: true,
              autofillHints: const <String>[AutofillHints.password],
              onSubmitted: _busy ? null : (_) => _signIn(),
              decoration: InputDecoration(
                labelText: t.kitapsen_account_password,
                errorText: _error,
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                key: const ValueKey<String>('kitapsen-sign-in'),
                onPressed: _busy ? null : _signIn,
                icon: _busy
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.login),
                label: Text(t.kitapsen_account_sign_in),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    t.kitapsen_account_or,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                const Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: const ValueKey<String>('kitapsen-sign-in-google'),
              onPressed: _busy
                  ? null
                  : () => _signInWithProvider(KitapsenClient.signInWithGoogle),
              icon: Image.asset(
                'assets/meta/kitapsen_google_g.png',
                width: 18,
                height: 18,
              ),
              label: Text(t.kitapsen_account_continue_with_google),
            ),
            if (Platform.isIOS) ...<Widget>[
              const SizedBox(height: 8),
              SignInWithAppleButton(
                key: const ValueKey<String>('kitapsen-sign-in-apple'),
                onPressed: _busy
                    ? null
                    : () => _signInWithProvider(KitapsenClient.signInWithApple),
                text: t.kitapsen_account_continue_with_apple,
                height: 40,
                style: Theme.of(context).brightness == Brightness.dark
                    ? SignInWithAppleButtonStyle.white
                    : SignInWithAppleButtonStyle.black,
                borderRadius: const BorderRadius.all(Radius.circular(20)),
              ),
            ],
            if (_providerError != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                _providerError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
