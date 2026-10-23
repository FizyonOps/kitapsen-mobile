import 'dart:convert';

import 'package:fushi_core/fushi_core.dart';

/// Kitapsen 账号在 `preferences` 表里的存取，外加「设备本地 key」清单。
class SyncRepository {
  SyncRepository(this._db);

  final FushiDatabase _db;

  static const _keyKitapsenUrl = 'sync_kitapsen_url';
  static const _keyKitapsenUsername = 'sync_kitapsen_username';
  static const _keyKitapsenPassword = 'sync_kitapsen_password';
  static const _keyKitapsenToken = 'sync_kitapsen_token';

  // ── Kitapsen account ──────────────────────────────────────────────

  /// 已登录的 Kitapsen 账号；地址、用户名与凭据（密码或 app token）缺一即视为未登录。
  /// A Google / Apple account has a [token] and an empty password.
  Future<({String url, String username, String password, String? token})?>
      getKitapsenAccount() async {
    final String? url = await _getStringOrNull(_keyKitapsenUrl);
    final String? username = await _getStringOrNull(_keyKitapsenUsername);
    final String? encoded = await _getStringOrNull(_keyKitapsenPassword);
    final String? encodedToken = await _getStringOrNull(_keyKitapsenToken);
    if (url == null || username == null) return null;
    if (encoded == null && encodedToken == null) return null;
    return (
      url: url,
      username: username,
      password: encoded == null ? '' : _decodeSecret(encoded),
      token: encodedToken == null ? null : _decodeSecret(encodedToken),
    );
  }

  /// Stores a password account, or with [token] a Google / Apple account.
  Future<void> setKitapsenAccount({
    required String url,
    required String username,
    String password = '',
    String? token,
  }) async {
    await _setString(_keyKitapsenUrl, url);
    await _setString(_keyKitapsenUsername, username);
    if (token != null) {
      await _setString(_keyKitapsenToken, _encodeSecret(token));
      await _deleteKey(_keyKitapsenPassword);
    } else {
      await _setString(_keyKitapsenPassword, _encodeSecret(password));
      await _deleteKey(_keyKitapsenToken);
    }
  }

  Future<void> clearKitapsenAccount() async {
    await (_db.delete(_db.preferences)
          ..where((t) => t.key.isIn(<String>[
                _keyKitapsenUrl,
                _keyKitapsenUsername,
                _keyKitapsenPassword,
                _keyKitapsenToken,
              ])))
        .go();
  }

  // ── Encoding ─────────────────────────────────────────────────────

  static String _encodeSecret(String value) => base64Encode(utf8.encode(value));

  static String _decodeSecret(String encoded) {
    try {
      return utf8.decode(base64Decode(encoded));
    } catch (_) {
      return encoded;
    }
  }

  /// 只属于这台设备、绝不进 Profile 快照的 key（见 `PrefRedactionPolicy`）。
  static const List<String> deviceLocalPrefKeys = <String>[
    kStatLegacyProfileIdPrefKey,
    _keyKitapsenUrl,
    _keyKitapsenUsername,
    _keyKitapsenPassword,
    _keyKitapsenToken,
  ];

  Future<void> _deleteKey(String key) async {
    await (_db.delete(_db.preferences)..where((t) => t.key.equals(key))).go();
  }

  Future<String?> _getStringOrNull(String key) async {
    final row = await (_db.select(_db.preferences)
          ..where((t) => t.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  Future<void> _setString(String key, String value) async {
    await _db.into(_db.preferences).insertOnConflictUpdate(
          PreferencesCompanion.insert(key: key, value: value),
        );
  }
}
