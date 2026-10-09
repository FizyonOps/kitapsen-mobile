import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' show sha256;
import 'package:drift/drift.dart' show Value;
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:fushi/src/media/sources/reader_fushi_source.dart';
import 'package:fushi/src/sync/remote_book_client.dart';
import 'package:fushi/src/sync/kitapsen_annotations.dart';
import 'package:fushi/src/sync/remote_cover_fetcher.dart';
import 'package:fushi/src/sync/remote_library_source.dart';
import 'package:fushi/src/sync/sync_backend.dart'
    show SyncAuthError, SyncAuthFailureKind, SyncBackendError;
import 'package:fushi/src/sync/sync_repository.dart';
import 'package:fushi/src/utils/misc/error_log_service.dart';
import 'package:fushi_core/fushi_core.dart';
import 'package:fushi_engine/sync/fushi_library_host_service.dart';
import 'package:fushi_engine/sync/ttu_filename.dart';
import 'package:fushi_engine/utils/net/app_http.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// Default store address; the API lives under `/api/v1` on the same origin.
const String kKitapsenDefaultUrl = 'https://kitapsen.com';

/// Local book uid of a downloaded Kitapsen book, keyed by the store book id.
const String _kBookUidPrefPrefix = 'kitapsen_book_uid__';

/// Store book id of a downloaded Kitapsen book, keyed by the local book uid.
const String _kUidBookPrefPrefix = 'kitapsen_uid_book__';

/// Whether the local book with uid [bookUid] was downloaded from the Kitapsen
/// store.
///
/// Store books are licensed for reading inside this app only, so every path
/// that would copy their content out (backup archives, cloud / interconnect
/// uploads, the LAN host, share sheets) must skip them. The link is written
/// right after import ([KitapsenClient.recordDownloaded]); the Kitapsen
/// edition additionally hides those features for all books, which covers the
/// short window before the link exists.
Future<bool> isKitapsenBook(FushiDatabase db, String bookUid) async {
  if (bookUid.isEmpty) return false;
  final String? mapped = await db.getPref('$_kUidBookPrefPrefix$bookUid');
  return mapped != null && mapped.isNotEmpty;
}

/// Uids of every local book downloaded from the Kitapsen store.
Future<Set<String>> kitapsenBookUids(FushiDatabase db) async {
  final Map<String, String> links = await db.getPrefsByPrefix(
    _kUidBookPrefPrefix,
  );
  return <String>{
    for (final MapEntry<String, String> link in links.entries)
      if (link.value.isNotEmpty)
        link.key.startsWith(_kUidBookPrefPrefix)
            ? link.key.substring(_kUidBookPrefPrefix.length)
            : link.key,
  };
}

/// Drops the store-book link of local book [bookUid] (both directions).
Future<void> forgetKitapsenBook(FushiDatabase db, String bookUid) async {
  final String key = '$_kUidBookPrefPrefix$bookUid';
  final String? storeId = await db.getPref(key);
  await db.deletePref(key);
  if (storeId != null && storeId.isNotEmpty) {
    await db.deletePref('$_kBookUidPrefPrefix$storeId');
  }
}

/// Credentials of a Kitapsen account (stored by
/// [SyncRepository.setKitapsenAccount]): a password, or for an account that
/// signed in with Google / Apple the app [token] kitapsen.com handed out.
class KitapsenAccount {
  const KitapsenAccount({
    required this.url,
    required this.username,
    this.password = '',
    this.token,
  });

  final String url;
  final String username;
  final String password;
  final String? token;

  /// `https://kitapsen.com` → `https://kitapsen.com/api/v1`. An address that
  /// already ends in `/api/v1` is kept as is.
  String get apiBase {
    String base = url.trim();
    while (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    if (!base.contains('://')) base = 'https://$base';
    return base.endsWith('/api/v1') ? base : '$base/api/v1';
  }
}

class _KitapsenSession {
  const _KitapsenSession({required this.sessionId, required this.csrfToken});

  final String sessionId;
  final String csrfToken;
}

/// The Kitapsen store as a remote book library: the books the account owns
/// (`GET /orders/library`) show up on the shelf, download through the in-app
/// reading endpoint (`GET /books/{id}/content`) and import like any other
/// remote book, and reading progress goes to `PUT /reading/sync`.
///
/// Auth is the web app's own cookie session: `POST /auth/login` returns a
/// `session_id` cookie plus a CSRF token that every write repeats in
/// `X-CSRF-Token`. Sessions expire after 30 idle minutes, so a 401 (or a
/// rejected CSRF token on a write) logs in again once and retries.
///
/// Progress mapping: Fushi stores a position as chapter + offset inside the
/// chapter, the web reader as an EPUB CFI. The shared currency is the
/// book-wide percentage, which the web reader already accepts in
/// `current_location` from other devices (anything that is not an
/// `epubcfi(...)` is read as a percentage). CFIs written by the web reader
/// are not mapped; `progress_percent` stands in for them.
///
/// HARD-protected books are included: this app is the licensed Kitapsen
/// reader, and a downloaded book is kept in app-private storage with every
/// export / share / backup / sync path closed for it (see [isKitapsenBook]).
///
/// PDF-only books download as PDF; their progress counts pages. Out of
/// scope here: bookmark / highlight / note sync.
class KitapsenClient implements RemoteBookClient, RemoteCoverFetcher {
  KitapsenClient({required FushiDatabase db, required this.account}) : _db = db;

  final FushiDatabase _db;
  final KitapsenAccount account;

  /// Sessions are shared by every client instance of the same account: the
  /// shelf builds a new client per refresh, and a login per refresh would
  /// leave a trail of server sessions.
  static final Map<String, _KitapsenSession> _sessions =
      <String, _KitapsenSession>{};

  static HttpClient? _httpClient;

  static HttpClient _client() => _httpClient ??= createAppHttpClient();

  /// The client for the signed-in account, or null when nobody is signed in.
  static Future<KitapsenClient?> restore(FushiDatabase db) async {
    final ({String url, String username, String password, String? token})?
    stored = await SyncRepository(db).getKitapsenAccount();
    if (stored == null) return null;
    return KitapsenClient(
      db: db,
      account: KitapsenAccount(
        url: stored.url,
        username: stored.username,
        password: stored.password,
        token: stored.token,
      ),
    );
  }

  String get _sessionKey => '${account.apiBase}|${account.username}';

  @override
  String get remoteLibrarySourceId => kKitapsenRemoteLibrarySourceId;

  @override
  RemoteBookSourceKind get remoteSourceKind => RemoteBookSourceKind.cloud;

  @override
  String get coverCacheNamespace =>
      'kitapsen:${Uri.parse(account.apiBase).host}:${account.username}';

  // ── Session ───────────────────────────────────────────────────────

  /// Logs in with the stored credentials (the password, or the app token of a
  /// Google / Apple account). Throws [SyncAuthError] when the server rejects
  /// them.
  Future<void> signIn() async {
    _sessions.remove(_sessionKey);
    final String? token = account.token;
    final HttpClientRequest request = await _client().postUrl(
      Uri.parse(
        '${account.apiBase}${token == null ? '/auth/login' : '/auth/mobile/session'}',
      ),
    );
    request.followRedirects = false;
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    if (token != null) {
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(<String, String>{'token': token}));
    } else {
      request.headers.contentType = ContentType(
        'application',
        'x-www-form-urlencoded',
        charset: 'utf-8',
      );
      request.write(
        Uri(
          queryParameters: <String, String>{
            'username': account.username,
            'password': account.password,
          },
        ).query,
      );
    }
    final HttpClientResponse response = await request.close();
    final String body = await utf8.decodeStream(response);
    if (response.statusCode == HttpStatus.unauthorized ||
        response.statusCode == HttpStatus.forbidden ||
        response.statusCode == HttpStatus.tooManyRequests) {
      throw SyncAuthError(
        'Kitapsen sign-in rejected',
        serverReason: _detail(body),
      );
    }
    _checkStatus(response.statusCode, body);

    String? sessionId;
    String? csrfCookie;
    for (final Cookie cookie in response.cookies) {
      if (cookie.name == 'session_id') sessionId = cookie.value;
      if (cookie.name == 'csrf_token') csrfCookie = cookie.value;
    }
    final Object? decoded = _decodeJson(body);
    final String? csrfToken = decoded is Map<String, dynamic>
        ? decoded['csrf_token'] as String? ?? csrfCookie
        : csrfCookie;
    if (sessionId == null || csrfToken == null) {
      throw SyncBackendError('Kitapsen sign-in returned no session');
    }
    _sessions[_sessionKey] = _KitapsenSession(
      sessionId: sessionId,
      csrfToken: csrfToken,
    );
  }

  /// Ends the server session and revokes the app token of a Google / Apple
  /// account (both best effort), and forgets the session locally.
  Future<void> signOut() async {
    final _KitapsenSession? session = _sessions.remove(_sessionKey);
    final String? token = account.token;
    try {
      if (session != null) {
        final HttpClientRequest request = await _client().postUrl(
          Uri.parse('${account.apiBase}/auth/logout'),
        );
        _authorize(request, session, isWrite: true);
        await (await request.close()).drain<void>();
      }
      if (token != null) {
        await _postJson(
          account.apiBase,
          '/auth/mobile/revoke',
          <String, String>{'token': token},
        );
      }
    } catch (e, stack) {
      ErrorLogService.instance.log('KitapsenClient.signOut', e, stack);
    }
  }

  /// Deletes the Kitapsen account itself (`DELETE /users/me`, the website's
  /// own account deletion). The caller still signs the app out.
  Future<void> deleteAccount() async {
    final HttpClientResponse response = await _send('DELETE', '/users/me');
    _checkStatus(response.statusCode, await utf8.decodeStream(response));
    _sessions.remove(_sessionKey);
  }

  // ── Google / Apple sign-in ────────────────────────────────────────

  /// Callback scheme kitapsen.com ends the Google sign-in browser on
  /// (`kitapsen://auth?code=…` or `?error=…`).
  static const String _authCallbackScheme = 'kitapsen';

  /// Signs in with Google in the system browser (ASWebAuthenticationSession /
  /// Custom Tabs) through kitapsen.com's own Google client, and returns the
  /// account holding the app token. Null when the person closes the browser.
  ///
  /// The browser returns a one-time code bound to a PKCE challenge, so the
  /// app token never travels through the URL.
  static Future<KitapsenAccount?> signInWithGoogle(String url) async {
    final String apiBase = KitapsenAccount(url: url, username: '').apiBase;
    final Random random = Random.secure();
    final String verifier = base64Url
        .encode(List<int>.generate(48, (_) => random.nextInt(256)))
        .replaceAll('=', '');
    final String challenge = base64Url
        .encode(sha256.convert(ascii.encode(verifier)).bytes)
        .replaceAll('=', '');
    final String result;
    try {
      result = await FlutterWebAuth2.authenticate(
        url: Uri.parse('$apiBase/auth/mobile/oauth/google')
            .replace(
              queryParameters: <String, String>{'code_challenge': challenge},
            )
            .toString(),
        callbackUrlScheme: _authCallbackScheme,
      );
    } on PlatformException catch (e) {
      if (e.code == 'CANCELED') return null;
      rethrow;
    }
    final Map<String, String> params = Uri.parse(result).queryParameters;
    final String? code = params['code'];
    // Cancel on Google's consent screen: same as closing the browser.
    if (params['error'] == 'access_denied') return null;
    if (code == null) {
      throw SyncAuthError(
        'Kitapsen Google sign-in failed',
        kind: params['error'] == 'account_deleted'
            ? SyncAuthFailureKind.forbidden
            : SyncAuthFailureKind.credentials,
        serverReason: params['error'],
      );
    }
    return _accountFromSignIn(
      url,
      await _postJson(apiBase, '/auth/mobile/google', <String, String>{
        'code': code,
        'code_verifier': verifier,
      }),
    );
  }

  /// Signs in with Apple (native, iOS) and returns the account holding the
  /// app token. Null when the person cancels the Apple sheet.
  static Future<KitapsenAccount?> signInWithApple(String url) async {
    final AuthorizationCredentialAppleID credential;
    try {
      credential = await SignInWithApple.getAppleIDCredential(
        scopes: <AppleIDAuthorizationScopes>[
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) return null;
      rethrow;
    }
    final String? identityToken = credential.identityToken;
    if (identityToken == null) {
      throw SyncAuthError('Apple returned no identity token');
    }
    // Apple shares the name only on the first authorization, and only with
    // the app, so it travels next to the token.
    return _accountFromSignIn(
      url,
      await _postJson(
        KitapsenAccount(url: url, username: '').apiBase,
        '/auth/mobile/apple',
        <String, String>{
          'identity_token': identityToken,
          if (credential.givenName != null) 'given_name': credential.givenName!,
          if (credential.familyName != null)
            'family_name': credential.familyName!,
        },
      ),
    );
  }

  static KitapsenAccount _accountFromSignIn(String url, Object? body) {
    if (body is! Map<String, dynamic> || body['token'] is! String) {
      throw SyncBackendError('Kitapsen sign-in returned no token');
    }
    return KitapsenAccount(
      url: url,
      username: body['email'] as String? ?? body['username'] as String,
      token: body['token'] as String,
    );
  }

  /// Unauthenticated JSON POST (the sign-in endpoints).
  static Future<Object?> _postJson(
    String apiBase,
    String path,
    Map<String, String> payload,
  ) async {
    final HttpClientRequest request = await _client().postUrl(
      Uri.parse('$apiBase$path'),
    );
    request.followRedirects = false;
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    request.headers.contentType = ContentType.json;
    request.write(jsonEncode(payload));
    final HttpClientResponse response = await request.close();
    final String body = await utf8.decodeStream(response);
    _checkStatus(response.statusCode, body);
    return _decodeJson(body);
  }

  void _authorize(
    HttpClientRequest request,
    _KitapsenSession session, {
    required bool isWrite,
  }) {
    request.cookies
      ..add(Cookie('session_id', session.sessionId))
      ..add(Cookie('csrf_token', session.csrfToken));
    if (isWrite) request.headers.set('X-CSRF-Token', session.csrfToken);
  }

  /// Sends an authenticated request; logs in first when there is no session
  /// and once more when the server rejects the one it has.
  Future<HttpClientResponse> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Object? jsonBody,
  }) async {
    final Uri uri = Uri.parse(
      '${account.apiBase}$path',
    ).replace(queryParameters: query);
    final bool isWrite = method != 'GET';
    for (int attempt = 0; ; attempt++) {
      _KitapsenSession? session = _sessions[_sessionKey];
      if (session == null) {
        await signIn();
        session = _sessions[_sessionKey]!;
      }
      final HttpClientRequest request = await _client().openUrl(method, uri);
      request.followRedirects = false;
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      _authorize(request, session, isWrite: isWrite);
      if (jsonBody != null) {
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode(jsonBody));
      }
      final HttpClientResponse response = await request.close();
      // An expired session answers 401; an expired CSRF token on a write
      // answers 403. Both are cured by a fresh login, nothing else is.
      final bool sessionRejected =
          response.statusCode == HttpStatus.unauthorized ||
          (isWrite && response.statusCode == HttpStatus.forbidden);
      if (sessionRejected && attempt == 0) {
        await response.drain<void>();
        _sessions.remove(_sessionKey);
        continue;
      }
      return response;
    }
  }

  Future<Object?> _getJson(String path, {Map<String, String>? query}) async {
    final HttpClientResponse response = await _send('GET', path, query: query);
    final String body = await utf8.decodeStream(response);
    _checkStatus(response.statusCode, body);
    return _decodeJson(body);
  }

  // ── Store API (store tab, book pages, wishlist, notifications) ────

  /// Signed-in JSON request against [path] under `/api/v1`; same session and
  /// re-login handling as the library calls. Throws [SyncAuthError] /
  /// [SyncBackendError] on a non-2xx answer.
  Future<Object?> requestJson(
    String method,
    String path, {
    Map<String, String>? query,
    Object? jsonBody,
  }) async {
    final HttpClientResponse response = await _send(
      method,
      path,
      query: query,
      jsonBody: jsonBody,
    );
    final String body = await utf8.decodeStream(response);
    _checkStatus(response.statusCode, body);
    return _decodeJson(body);
  }

  /// Anonymous POST without a body (counters such as a chapter read).
  static Future<void> publicPostJson(String apiBase, String path) async {
    final HttpClientRequest request = await _client().postUrl(
      Uri.parse('$apiBase$path'),
    );
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    final HttpClientResponse response = await request.close();
    _checkStatus(response.statusCode, await utf8.decodeStream(response));
  }

  /// Anonymous GET of a public store endpoint (catalog, book, reviews), for
  /// when nobody is signed in.
  static Future<Object?> publicGetJson(
    String apiBase,
    String path, {
    Map<String, String>? query,
  }) async {
    final HttpClientRequest request = await _client().getUrl(
      Uri.parse('$apiBase$path').replace(queryParameters: query),
    );
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    final HttpClientResponse response = await request.close();
    final String body = await utf8.decodeStream(response);
    _checkStatus(response.statusCode, body);
    return _decodeJson(body);
  }

  static void _checkStatus(int status, String body) {
    if (status >= 200 && status < 300) return;
    if (status == HttpStatus.unauthorized) {
      throw SyncAuthError(
        'Kitapsen session rejected',
        serverReason: _detail(body),
      );
    }
    if (status == HttpStatus.forbidden) {
      throw SyncAuthError(
        'Kitapsen request refused',
        kind: SyncAuthFailureKind.forbidden,
        serverReason: _detail(body),
      );
    }
    throw SyncBackendError(
      'Kitapsen HTTP $status: ${_detail(body) ?? ''}',
      isRetryable: status >= 500,
    );
  }

  static Object? _decodeJson(String body) {
    if (body.isEmpty) return null;
    try {
      return jsonDecode(body);
    } on FormatException {
      return null;
    }
  }

  /// FastAPI puts the reason in `detail` (a string, or an object with
  /// `message`).
  static String? _detail(String body) {
    final Object? decoded = _decodeJson(body);
    if (decoded is! Map<String, dynamic>) return null;
    final Object? detail = decoded['detail'];
    if (detail is String) return detail;
    if (detail is Map<String, dynamic>) return detail['message'] as String?;
    return null;
  }

  // ── Library ───────────────────────────────────────────────────────

  @override
  Future<List<RemoteBookInfo>> listRemoteBooks() async {
    final List<RemoteBookInfo> books = <RemoteBookInfo>[];
    const int pageSize = 50;
    // The library pages by license; 40 pages bounds a broken `has_more`.
    for (int page = 1; page <= 40; page++) {
      final Object? decoded = await _getJson(
        '/orders/library',
        query: <String, String>{'page': '$page', 'items_per_page': '$pageSize'},
      );
      if (decoded is! Map<String, dynamic>) break;
      final List<dynamic> items =
          decoded['data'] as List<dynamic>? ?? const <dynamic>[];
      for (final dynamic item in items) {
        if (item is! Map<String, dynamic>) continue;
        final RemoteBookInfo? book = _bookFromLibraryItem(item);
        if (book != null) books.add(book);
      }
      if (decoded['has_more'] != true || items.isEmpty) break;
    }
    return books;
  }

  RemoteBookInfo? _bookFromLibraryItem(Map<String, dynamic> item) {
    final int? bookId = (item['book_id'] as num?)?.toInt();
    final String title = (item['title'] as String? ?? '').trim();
    if (bookId == null || title.isEmpty) return null;
    // Every protection level (NONE / SOCIAL / HARD) is listed: this app is the
    // licensed Kitapsen reader, and a downloaded book never leaves it (see
    // [isKitapsenBook]).
    final List<String> formats = <String>[
      for (final dynamic f
          in item['formats'] as List<dynamic>? ?? const <dynamic>[])
        if (f is String) f.toLowerCase(),
    ];
    // EPUB when the book has one, else its PDF (`getRemoteBook` asks for EPUB
    // and the server falls back to the PDF).
    if (!formats.contains('epub') && !formats.contains('pdf')) return null;
    final String? cover = item['cover_image_url'] as String?;
    final int? grantedAt = _parseServerTime(item['granted_at'] as String?);
    return RemoteBookInfo(
      // Raw store title: the shelf dedupes and labels by it.
      title: title,
      // The EPUB's own metadata title is often a bare file name; the store
      // title becomes the local name unless the reader renamed the book later.
      displayTitle: title,
      displayTitleAt: grantedAt ?? 0,
      hasContent: true,
      // The store id is the download / progress key, never the title.
      bookKey: '$bookId',
      format: formats.contains('epub')
          ? BookFormat.epub.dbValue
          : BookFormat.pdf.dbValue,
      coverUrl: cover == null || cover.isEmpty ? null : _absoluteUrl(cover),
      importedAt: grantedAt,
    );
  }

  /// Covers come back as site-relative paths (`/api/v1/files/covers/…`).
  String _absoluteUrl(String url) => absoluteUrl(account.apiBase, url);

  static String absoluteUrl(String apiBase, String url) {
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    return Uri.parse(apiBase).resolve(url).toString();
  }

  @override
  Future<Uint8List> fetchRemoteCover(String coverUrl) async {
    final HttpClientRequest request = await _client().getUrl(
      Uri.parse(coverUrl),
    );
    final HttpClientResponse response = await request.close();
    if (response.statusCode != HttpStatus.ok) {
      await response.drain<void>();
      throw SyncBackendError('Kitapsen cover HTTP ${response.statusCode}');
    }
    final BytesBuilder bytes = BytesBuilder(copy: false);
    await response.forEach(bytes.add);
    return bytes.takeBytes();
  }

  /// Downloads store book [downloadId] to [destination]: its EPUB, or its PDF
  /// when it has no EPUB. Import is the shelf's job (`_importRemoteBookFile`,
  /// which tells the two apart by content).
  @override
  Future<void> getRemoteBook(
    String downloadId,
    File destination, {
    void Function(double progress)? onProgress,
  }) async {
    final int? bookId = await _storeBookId(downloadId);
    if (bookId == null) {
      throw SyncBackendError('Not a Kitapsen book: $downloadId');
    }
    final HttpClientResponse response = await _send(
      'GET',
      '/books/$bookId/content',
      query: const <String, String>{'format': 'epub'},
    );
    if (response.statusCode != HttpStatus.ok) {
      _checkStatus(response.statusCode, await utf8.decodeStream(response));
    }
    // Without an EPUB upload the endpoint falls back to the first file;
    // uploads are EPUB or PDF only.
    final String? served = response.headers.value('x-book-format');
    if (served != null &&
        !<String>{'epub', 'pdf'}.contains(served.toLowerCase())) {
      await response.drain<void>();
      throw SyncBackendError('Kitapsen book $bookId: unsupported $served');
    }
    final int total = response.contentLength;
    int received = 0;
    final IOSink sink = destination.openWrite();
    try {
      await for (final List<int> chunk in response) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) onProgress?.call(received / total);
      }
    } finally {
      await sink.close();
    }
    onProgress?.call(1);
  }

  // ── Downloaded books ──────────────────────────────────────────────

  /// Links store book [book] to the local book it was imported as, so its
  /// progress can be synced and the shelf stops offering it for download
  /// even when the EPUB's own title differs from the store title.
  Future<void> recordDownloaded(
    RemoteBookInfo book,
    String localBookKey,
  ) async {
    final String? bookId = book.bookKey;
    final String? uid = await _db.resolveEpubBookUid(localBookKey);
    if (bookId == null || uid == null) return;
    await _db.setPref('$_kBookUidPrefPrefix$bookId', uid);
    await _db.setPref('$_kUidBookPrefPrefix$uid', bookId);
  }

  /// Dedupe keys (`sanitizeTtuFilename(title)`) of the [books] that are
  /// already on this device.
  Future<Set<String>> downloadedTitleKeys(List<RemoteBookInfo> books) async {
    final Set<String> keys = <String>{};
    for (final RemoteBookInfo book in books) {
      if (await _localBookFor(book.bookKey) != null) {
        keys.add(sanitizeTtuFilename(book.title));
      }
    }
    return keys;
  }

  Future<EpubBookRow?> _localBookFor(String? bookId) async {
    if (bookId == null) return null;
    final String? uid = await _db.getPref('$_kBookUidPrefPrefix$bookId');
    if (uid == null || uid.isEmpty) return null;
    return _db.getEpubBookByUid(uid);
  }

  /// [key] is either a store id (the remote card's `downloadId`) or the
  /// local bookKey of a downloaded book.
  Future<int?> _storeBookId(String key) async {
    final int? direct = int.tryParse(key);
    if (direct != null) return direct;
    final String? uid = await _db.resolveEpubBookUid(key);
    if (uid == null) return null;
    final String? mapped = await _db.getPref('$_kUidBookPrefPrefix$uid');
    return mapped == null ? null : int.tryParse(mapped);
  }

  /// Store id of a local book, or null when it did not come from Kitapsen.
  Future<int?> storeBookIdOf(EpubBookRow book) async {
    final String? mapped = await _db.getPref('$_kUidBookPrefPrefix${book.uid}');
    return mapped == null ? null : int.tryParse(mapped);
  }

  /// Every local book that came from this store, with its store id.
  Future<List<({int bookId, EpubBookRow book})>> downloadedBooks() async {
    final Map<String, String> links = await _db.getPrefsByPrefix(
      _kUidBookPrefPrefix,
    );
    final List<({int bookId, EpubBookRow book})> result =
        <({int bookId, EpubBookRow book})>[];
    for (final MapEntry<String, String> link in links.entries) {
      final int? bookId = int.tryParse(link.value);
      final EpubBookRow? book = await _db.getEpubBookByUid(
        link.key.substring(_kUidBookPrefPrefix.length),
      );
      if (bookId != null && book != null) {
        result.add((bookId: bookId, book: book));
      }
    }
    return result;
  }

  // ── Reading progress ──────────────────────────────────────────────

  @override
  Future<RemoteBookProgress> remoteBookProgress(String bookKey) async {
    final int? bookId = await _storeBookId(bookKey);
    if (bookId == null) return RemoteBookProgress.empty;
    final EpubBookRow? book = await _localBookFor('$bookId');
    if (book == null) return RemoteBookProgress.empty;
    return _fetchProgress(bookId, book);
  }

  Future<RemoteBookProgress> _fetchProgress(
    int bookId,
    EpubBookRow book,
  ) async {
    final Object? decoded = await _getJson('/reading/progress/$bookId');
    if (decoded is! Map<String, dynamic>) return RemoteBookProgress.empty;
    final double? percent = _percentOf(decoded);
    final int updatedAtMs =
        _parseServerTime(decoded['last_read_at'] as String?) ?? 0;
    if (percent == null || updatedAtMs == 0) return RemoteBookProgress.empty;
    return _positionAtPercent(_sectionChars(book), percent, updatedAtMs);
  }

  /// A percentage written by another app (`current_location`), else the
  /// server's own `progress_percent` (the only usable value when the web
  /// reader stored a CFI).
  static double? _percentOf(Map<String, dynamic> progress) {
    final String? location = progress['current_location'] as String?;
    if (location != null && !location.startsWith('epubcfi(')) {
      final double? parsed = double.tryParse(location);
      if (parsed != null) return parsed.clamp(0, 100).toDouble();
    }
    return (progress['progress_percent'] as num?)
        ?.toDouble()
        .clamp(0, 100)
        .toDouble();
  }

  @override
  Future<void> putRemoteBookProgress(
    String bookKey,
    RemoteBookProgress progress,
  ) async {
    final int? bookId = await _storeBookId(bookKey);
    if (bookId == null) return;
    final EpubBookRow? book = await _localBookFor('$bookId');
    if (book == null) return;
    await _putProgress(bookId, book, progress);
  }

  Future<void> _putProgress(
    int bookId,
    EpubBookRow book,
    RemoteBookProgress progress,
  ) async {
    final ({int position, int duration}) at = computeBookProgress(
      sectionChars: _sectionChars(book),
      sectionIndex: progress.sectionIndex,
      charOffset: progress.charOffset,
      normCharOffset: progress.normCharOffset,
    );
    final double percent = at.duration > 0
        ? at.position * 100 / at.duration
        : 0;
    final String location = percent.clamp(0, 100).toStringAsFixed(2);
    final HttpClientResponse response = await _send(
      'PUT',
      '/reading/sync',
      jsonBody: <String, Object?>{
        'book_id': bookId,
        'current_location': location,
        'progress_percent': double.parse(location),
        'device_type': 'mobile',
        'client_timestamp': DateTime.fromMillisecondsSinceEpoch(
          progress.updatedAtMs,
          isUtc: true,
        ).toIso8601String(),
      },
    );
    _checkStatus(response.statusCode, await utf8.decodeStream(response));
  }

  /// Last-write-wins between this device and the store for one downloaded
  /// book: the newer side is copied to the other, equal sides are left alone.
  Future<void> syncProgress(int bookId, EpubBookRow book) async {
    final ReaderPositionRow? local = await _db.getReaderPosition(book.uid);
    final RemoteBookProgress remote = await _fetchProgress(bookId, book);
    final int localAt = local?.updatedAt ?? 0;
    if (remote.updatedAtMs > localAt) {
      await _db.upsertReaderPosition(
        ReaderPositionsCompanion(
          bookUid: Value(book.uid),
          sectionIndex: Value(remote.sectionIndex),
          normCharOffset: Value(remote.normCharOffset),
          charOffset: Value(remote.charOffset),
          updatedAt: Value(remote.updatedAtMs),
        ),
      );
    } else if (local != null && localAt > remote.updatedAtMs) {
      await _putProgress(
        bookId,
        book,
        RemoteBookProgress(
          sectionIndex: local.sectionIndex,
          normCharOffset: local.normCharOffset,
          charOffset: local.charOffset,
          updatedAtMs: local.updatedAt,
        ),
      );
    }
  }

  // ── Annotation locations ──────────────────────────────────────────

  /// The location string of an annotation at [fraction] (0..1) into section
  /// [section]: a book-wide percentage with four decimals, the convention
  /// reading progress already uses (the web reader jumps to it with
  /// goToPercent; four decimals keep it within a character or so).
  static String percentLocation(
    EpubBookRow book,
    int section,
    double fraction,
  ) {
    final List<int> chars = _sectionChars(book);
    final int total = chars.fold<int>(0, (int a, int b) => a + b);
    if (total <= 0) return '0.0000';
    final int s = section.clamp(0, chars.length - 1);
    final int before = chars.take(s).fold<int>(0, (int a, int b) => a + b);
    final double at = before + fraction.clamp(0.0, 1.0) * chars[s];
    return (at * 100 / total).clamp(0, 100).toStringAsFixed(4);
  }

  /// Section and in-section fraction of an annotation location: a
  /// percentage written by this app, an `epubcfi(…)` from the web reader
  /// (its spine step; the app's sections are the spine), or the web reader's
  /// `chapter-N` fallback. Null when it cannot be read.
  static ({int section, double fraction})? positionAt(
    EpubBookRow book,
    String location,
  ) {
    final int last = book.chapterCount > 0 ? book.chapterCount - 1 : 0;
    if (location.startsWith('epubcfi(')) {
      final RegExpMatch? m = RegExp(r'^epubcfi\(/6/(\d+)').firstMatch(location);
      if (m == null) return null;
      return (section: (int.parse(m[1]!) ~/ 2 - 1).clamp(0, last), fraction: 0);
    }
    if (location.startsWith('chapter-')) {
      final int? n = int.tryParse(location.substring('chapter-'.length));
      return n == null ? null : (section: n.clamp(0, last), fraction: 0);
    }
    final double? percent = double.tryParse(location);
    if (percent == null) return null;
    final RemoteBookProgress at = _positionAtPercent(
      _sectionChars(book),
      percent.clamp(0, 100),
      0,
    );
    return (section: at.sectionIndex, fraction: at.normCharOffset / 10000);
  }

  /// Character count of section [section] in the units highlights measure
  /// their offset in.
  static int sectionLength(EpubBookRow book, int section) {
    final List<int> chars = _sectionChars(book);
    return section >= 0 && section < chars.length ? chars[section] : 0;
  }

  /// Per-chapter character counts, the unit Fushi measures positions in. A
  /// PDF's sections are its pages, each weighted the same.
  static List<int> _sectionChars(EpubBookRow book) {
    if (book.format == BookFormat.pdf.dbValue) {
      return List<int>.filled(book.chapterCount, 1);
    }
    if (book.chaptersJson.isEmpty) return const <int>[];
    try {
      return <int>[
        for (final dynamic c in jsonDecode(book.chaptersJson) as List<dynamic>)
          ((c as Map<String, dynamic>)['characters'] as num?)?.toInt() ?? 0,
      ];
    } catch (e, stack) {
      ErrorLogService.instance.log('KitapsenClient.sectionChars', e, stack);
      return const <int>[];
    }
  }

  /// The inverse of [computeBookProgress]: the chapter and in-chapter
  /// fraction that sit at [percent] of the book. No exact anchor
  /// (`charOffset: -1`), so the reader restores from the fraction.
  static RemoteBookProgress _positionAtPercent(
    List<int> sectionChars,
    double percent,
    int updatedAtMs,
  ) {
    final double fraction = percent / 100;
    final int total = sectionChars.fold<int>(0, (int a, int b) => a + b);
    if (total <= 0) {
      // No character counts: chapter granularity, like computeBookProgress.
      final int section = sectionChars.isEmpty
          ? 0
          : (fraction * sectionChars.length).floor().clamp(
              0,
              sectionChars.length - 1,
            );
      return RemoteBookProgress(
        sectionIndex: section,
        normCharOffset: 0,
        charOffset: -1,
        updatedAtMs: updatedAtMs,
      );
    }
    final double target = fraction * total;
    int before = 0;
    for (int i = 0; i < sectionChars.length; i++) {
      final int size = sectionChars[i];
      final bool last = i == sectionChars.length - 1;
      if (target < before + size || last) {
        final double intra = size > 0 ? (target - before) / size : 0;
        return RemoteBookProgress(
          sectionIndex: i,
          normCharOffset: (intra * 10000).round().clamp(0, 10000),
          charOffset: -1,
          updatedAtMs: updatedAtMs,
        );
      }
      before += size;
    }
    return RemoteBookProgress.empty;
  }

  /// Server times are UTC; a value without an offset is read as UTC too.
  static int? _parseServerTime(String? value) {
    if (value == null || value.isEmpty) return null;
    final bool hasZone =
        value.endsWith('Z') || RegExp(r'[+-]\d\d:?\d\d$').hasMatch(value);
    return DateTime.tryParse(
      hasZone ? value : '${value}Z',
    )?.millisecondsSinceEpoch;
  }
}

/// Book closed or app backgrounded: send this book's position to Kitapsen
/// (when it came from there and this device read it last).
Future<void> syncKitapsenBookProgress(
  FushiDatabase db,
  String mediaIdentifier,
) async {
  try {
    final String? bookKey = ReaderFushiSource.parseBookKey(mediaIdentifier);
    if (bookKey == null) return;
    final KitapsenClient? client = await KitapsenClient.restore(db);
    if (client == null) return;
    final EpubBookRow? book = await db.getEpubBook(bookKey);
    if (book == null) return;
    final int? bookId = await client.storeBookIdOf(book);
    if (bookId == null) return;
    await client.syncProgress(bookId, book);
    // Bookmarks and highlights made in this session (EPUB and PDF alike).
    await KitapsenAnnotations.syncBook(db, bookKey);
  } catch (e, stack) {
    ErrorLogService.instance.log('KitapsenClient.syncBookProgress', e, stack);
  }
}

/// Last library-wide progress pass; the home page fires its sync entry every
/// minute, the store needs a visit far less often.
DateTime? _lastLibraryProgressSync;
bool _libraryProgressSyncRunning = false;
const Duration _kLibraryProgressSyncCooldown = Duration(minutes: 5);

/// App opened: bring every downloaded Kitapsen book's position up to date,
/// so a page turned on kitapsen.com is where the book opens here.
Future<void> syncKitapsenLibraryProgress(FushiDatabase db) async {
  final DateTime now = DateTime.now();
  final DateTime? last = _lastLibraryProgressSync;
  if (_libraryProgressSyncRunning ||
      (last != null && now.difference(last) < _kLibraryProgressSyncCooldown)) {
    return;
  }
  final KitapsenClient? client = await KitapsenClient.restore(db);
  if (client == null) return;
  _libraryProgressSyncRunning = true;
  _lastLibraryProgressSync = now;
  try {
    for (final ({int bookId, EpubBookRow book}) entry
        in await client.downloadedBooks()) {
      try {
        await client.syncProgress(entry.bookId, entry.book);
      } on SyncAuthError {
        rethrow;
      } catch (e, stack) {
        ErrorLogService.instance.log(
          'KitapsenClient.syncLibraryProgress',
          e,
          stack,
        );
      }
    }
  } catch (e, stack) {
    ErrorLogService.instance.log(
      'KitapsenClient.syncLibraryProgress',
      e,
      stack,
    );
  } finally {
    _libraryProgressSyncRunning = false;
  }
}
