/// Store-native update prompts for the Kitapsen edition.
///
/// Replaces Fushi's GitHub release updater, which must never run in a store
/// build (it would offer upstream Fushi builds):
///
/// - Android: Google Play In-App Updates. A flexible update starts when Play
///   reports one; once it has downloaded, a snack bar offers the restart that
///   installs it. Builds not installed from Play (sideload, emulator, debug)
///   make the Play API throw, which is ignored.
/// - iOS: the public iTunes lookup for [kKitapsenBundleId]. A newer App Store
///   version shows a small dismissible dialog linking to the store page; a
///   dismissed version is not offered again.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fushi/i18n/strings.g.dart';
import 'package:fushi/src/models/kitapsen_edition.dart';
import 'package:fushi_engine/utils/net/app_http.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

const String _kDismissedVersionKey = 'kitapsen_store_update_dismissed';

/// Checks the platform store once (call it after the first frame).
Future<void> checkStoreUpdate(BuildContext context) async {
  if (kDebugMode) return;
  try {
    if (Platform.isAndroid) {
      await _checkPlayUpdate(context);
    } else if (Platform.isIOS) {
      await _checkAppStoreUpdate(context);
    }
  } on Object catch (e) {
    // Off-store installs and offline starts end here; nothing to tell the user.
    debugPrint('[Kitapsen] store update check skipped: $e');
  }
}

Future<void> _checkPlayUpdate(BuildContext context) async {
  final AppUpdateInfo info = await InAppUpdate.checkForUpdate();
  if (info.updateAvailability != UpdateAvailability.updateAvailable ||
      !info.flexibleUpdateAllowed) {
    return;
  }
  final AppUpdateResult result = await InAppUpdate.startFlexibleUpdate();
  if (result != AppUpdateResult.success || !context.mounted) return;
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
    SnackBar(
      content: Text(t.update_available),
      duration: const Duration(seconds: 30),
      action: SnackBarAction(
        label: t.app_store_update_open,
        onPressed: () => unawaited(InAppUpdate.completeFlexibleUpdate()),
      ),
    ),
  );
}

Future<void> _checkAppStoreUpdate(BuildContext context) async {
  final ({String version, Uri url})? store = await _appStoreRelease();
  if (store == null) return;
  final PackageInfo package = await PackageInfo.fromPlatform();
  if (!_isNewer(store.version, package.version)) return;
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  if (prefs.getString(_kDismissedVersionKey) == store.version) return;
  if (!context.mounted) return;
  final bool? open = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) => AlertDialog(
      title: Text(t.update_available),
      content: Text(t.app_store_update_body(version: store.version)),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(t.app_store_update_later),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(t.app_store_update_open),
        ),
      ],
    ),
  );
  if (open == true) {
    await launchUrl(store.url, mode: LaunchMode.externalApplication);
  } else {
    await prefs.setString(_kDismissedVersionKey, store.version);
  }
}

/// The live App Store version and page. The lookup defaults to the US
/// storefront, so a Turkey-only listing is retried with `country=tr`.
Future<({String version, Uri url})?> _appStoreRelease() async {
  final HttpClient client = createAppHttpClient()
    ..connectionTimeout = const Duration(seconds: 10);
  try {
    for (final String? country in <String?>[null, 'tr']) {
      final Uri lookup = Uri.https(
        'itunes.apple.com',
        '/lookup',
        <String, String>{
          'bundleId': kKitapsenBundleId,
          if (country != null) 'country': country,
        },
      );
      final HttpClientRequest request = await client.getUrl(lookup);
      final HttpClientResponse response = await request.close().timeout(
        const Duration(seconds: 15),
      );
      if (response.statusCode != HttpStatus.ok) {
        await response.drain<void>();
        continue;
      }
      final Object? decoded = jsonDecode(await utf8.decodeStream(response));
      if (decoded is! Map<String, dynamic>) continue;
      final List<dynamic> results =
          decoded['results'] as List<dynamic>? ?? const <dynamic>[];
      if (results.isEmpty || results.first is! Map<String, dynamic>) continue;
      final Map<String, dynamic> app = results.first as Map<String, dynamic>;
      final String? version = app['version'] as String?;
      final Uri? url = Uri.tryParse(app['trackViewUrl'] as String? ?? '');
      if (version == null || url == null || !url.hasScheme) continue;
      return (version: version, url: url);
    }
    return null;
  } finally {
    client.close(force: true);
  }
}

/// Dotted numeric comparison (`1.10.0` > `1.9.3`); unparsable parts count 0.
bool _isNewer(String store, String installed) {
  List<int> parts(String v) => v
      .split('+')
      .first
      .split('.')
      .map((String p) => int.tryParse(p.trim()) ?? 0)
      .toList();
  final List<int> a = parts(store);
  final List<int> b = parts(installed);
  for (int i = 0; i < a.length || i < b.length; i++) {
    final int x = i < a.length ? a[i] : 0;
    final int y = i < b.length ? b[i] : 0;
    if (x != y) return x > y;
  }
  return false;
}
