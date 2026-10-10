/// The kitapsen.com catalog as the store tab sees it: home shelves, search,
/// categories, book pages, reviews, authors, wishlist and notifications.
///
/// Store policy (Apple 3.1.1 / 3.1.3(a), Google Play payments, see
/// [kKitapsenEdition]): nothing here carries a price or a purchase link. A
/// book is either in the reader's library (read it), free (claim it into the
/// library), or neither (wishlist only).
library;

import 'package:flutter/foundation.dart';
import 'package:fushi_core/fushi_core.dart';

import 'package:fushi/src/sync/kitapsen_client.dart';
import 'package:fushi/src/sync/sync_backend.dart' show SyncBackendError;

/// Store book id the store tab asked the Books tab to download. The shelf
/// clears it once it starts that download (`reader_history/remote.part.dart`).
final ValueNotifier<String?> kitapsenShelfDownloadRequest =
    ValueNotifier<String?>(null);

int? _int(Object? v) => v is num ? v.toInt() : int.tryParse('$v');

double _double(Object? v) => v is num ? v.toDouble() : 0;

/// Turkish-aware case folding for comparing names.
String _foldTr(String s) =>
    s.trim().replaceAll('İ', 'i').replaceAll('I', 'ı').toLowerCase();

String? _text(Object? v) {
  if (v is! String) return null;
  final String trimmed = v.trim();
  return trimmed.isEmpty ? null : trimmed;
}

/// A book as a store card shows it.
class StoreBook {
  const StoreBook({
    required this.id,
    required this.title,
    this.authorName,
    this.coverUrl,
    this.averageRating = 0,
    this.ratingCount = 0,
    this.isFree,
  });

  final int id;
  final String title;
  final String? authorName;
  final String? coverUrl;
  final double averageRating;
  final int ratingCount;

  /// From the row's effective price when it carries one (catalog rows do,
  /// author and wishlist rows may not). Only "free" is ever shown — never a
  /// price.
  final bool? isFree;

  static StoreBook? fromJson(Map<String, dynamic> json, String apiBase) {
    // Wishlist rows carry their own `id` next to `book_id`; catalog rows
    // only have the book's `id`.
    final int? id = _int(json['book_id'] ?? json['id']);
    final String? title = _text(json['title']);
    if (id == null || title == null) return null;
    final String? cover = _text(json['cover_image_url']);
    return StoreBook(
      id: id,
      title: title,
      authorName: _text(json['author_name']),
      coverUrl: cover == null
          ? null
          : KitapsenClient.absoluteUrl(apiBase, cover),
      averageRating: _double(json['average_rating']),
      ratingCount: _int(json['rating_count']) ?? 0,
      isFree: json['effective_price'] is num
          ? (json['effective_price'] as num) <= 0
          : null,
    );
  }
}

class StoreCategory {
  const StoreCategory({
    required this.name,
    required this.slug,
    required this.bookCount,
    required this.children,
  });

  final String name;
  final String slug;
  final int bookCount;
  final List<StoreCategory> children;

  /// Books in the category and all its subcategories (the search by slug
  /// covers subcategories too).
  int get totalBookCount => children.fold<int>(
    bookCount,
    (int sum, StoreCategory c) => sum + c.totalBookCount,
  );

  static StoreCategory? fromJson(Map<String, dynamic> json) {
    final String? name = _text(json['name']);
    final String? slug = _text(json['slug']);
    if (name == null || slug == null) return null;
    return StoreCategory(
      name: name,
      slug: slug,
      bookCount: _int(json['book_count']) ?? 0,
      children: <StoreCategory>[
        for (final dynamic c in json['children'] as List<dynamic>? ?? const [])
          if (c is Map<String, dynamic>)
            if (StoreCategory.fromJson(c) case final StoreCategory cat) cat,
      ],
    );
  }
}

class StoreBookDetail {
  const StoreBookDetail({
    required this.book,
    this.subtitle,
    this.description,
    this.authorUsername,
    this.publisherName,
    this.publisherSlug,
    this.language,
    this.pageCount,
    this.publishingDate,
    this.categories = const <({String name, String slug})>[],
    this.isFree = false,
    this.isSerialized = false,
    this.isbn,
    this.format,
    this.authorBio,
  });

  final StoreBook book;
  final String? isbn;
  final String? format;

  /// Biography of the credited author, typed with the book.
  final String? authorBio;
  final String? subtitle;
  final String? description;

  /// The uploading account, only when it is the credited author (a
  /// publishing house uploads every title under one staff account, so the
  /// account is not "the author" in general — same rule as the website).
  final String? authorUsername;
  final String? publisherName;

  /// The publisher's page (`/publishers/slug/{slug}`).
  final String? publisherSlug;
  final String? language;
  final int? pageCount;
  final String? publishingDate;
  final List<({String name, String slug})> categories;
  final bool isFree;
  final bool isSerialized;
}

class StoreReview {
  const StoreReview({
    required this.id,
    required this.rating,
    required this.userName,
    this.title,
    this.content,
    this.createdAt,
    this.verified = false,
    this.likeCount = 0,
    this.commentCount = 0,
  });

  final int id;
  final int rating;
  final String userName;
  final String? title;
  final String? content;
  final DateTime? createdAt;
  final bool verified;
  final int likeCount;
  final int commentCount;
}

/// A comment under a review or a chapter.
class StoreComment {
  const StoreComment({
    required this.id,
    required this.userName,
    required this.content,
    this.createdAt,
  });

  final int id;
  final String userName;
  final String content;
  final DateTime? createdAt;

  static StoreComment? fromJson(Map<String, dynamic> json) {
    final int? id = _int(json['id']);
    final String? content = _text(json['content']);
    if (id == null || content == null) return null;
    return StoreComment(
      id: id,
      userName: _text(json['user_name']) ?? _text(json['username']) ?? '—',
      content: content,
      createdAt: DateTime.tryParse('${json['created_at']}'),
    );
  }
}

/// An author the reader follows.
class StoreFollowedAuthor {
  const StoreFollowedAuthor({
    required this.username,
    required this.name,
    this.imageUrl,
  });

  final String username;
  final String name;
  final String? imageUrl;
}

class StoreAuthor {
  const StoreAuthor({
    required this.userId,
    required this.username,
    required this.name,
    this.bio,
    this.imageUrl,
    this.verified = false,
    this.bookCount = 0,
  });

  final int userId;
  final String username;
  final String name;
  final String? bio;
  final String? imageUrl;
  final bool verified;
  final int bookCount;
}

class StoreNotification {
  const StoreNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.isRead,
    this.createdAt,
    this.bookId,
  });

  final int id;
  final String title;
  final String message;
  final bool isRead;
  final DateTime? createdAt;

  /// Set when the notification is about a book (`link` = `/book/{id}`).
  final int? bookId;
}

class StoreChapter {
  const StoreChapter({
    required this.id,
    required this.number,
    required this.title,
    this.content,
  });

  final int id;
  final int number;
  final String title;

  /// Markdown; only set when a single chapter was fetched.
  final String? content;

  static StoreChapter? fromJson(Map<String, dynamic> json) {
    final int? id = _int(json['id']);
    if (id == null) return null;
    final int number = _int(json['chapter_number']) ?? 0;
    return StoreChapter(
      id: id,
      number: number,
      title: _text(json['title']) ?? '$number',
      content: json['content'] as String?,
    );
  }
}

/// An author whose name matched a search (website "Eşleşen yazarlar").
class StoreAuthorMatch {
  const StoreAuthorMatch({
    required this.name,
    required this.bookCount,
    required this.books,
    this.username,
    this.imageUrl,
  });

  final String name;
  final int bookCount;
  final List<StoreBook> books;

  /// Set when the author has an account (and so an author page).
  final String? username;
  final String? imageUrl;
}

/// A page of books from the catalog search.
class StoreBookPage {
  const StoreBookPage(
    this.books,
    this.total, {
    this.authors = const <StoreAuthorMatch>[],
  });
  final List<StoreBook> books;
  final int total;
  final List<StoreAuthorMatch> authors;
}

/// Sort orders of the catalog search offered in the app (no price sorts).
enum StoreSort { relevance, newest, bestselling, rating, title }

/// kitapsen.com store API. Uses the signed-in session when there is one (so
/// owner-only and personal endpoints work), anonymous requests otherwise.
class KitapsenStore {
  KitapsenStore._(this.apiBase, this.client);

  final String apiBase;
  final KitapsenClient? client;

  bool get signedIn => client != null;

  static Future<KitapsenStore> open(FushiDatabase db) async {
    final KitapsenClient? client = await KitapsenClient.restore(db);
    return KitapsenStore._(
      client?.account.apiBase ??
          const KitapsenAccount(url: kKitapsenDefaultUrl, username: '').apiBase,
      client,
    );
  }

  Future<Object?> _get(String path, {Map<String, String>? query}) {
    final KitapsenClient? c = client;
    return c == null
        ? KitapsenClient.publicGetJson(apiBase, path, query: query)
        : c.requestJson('GET', path, query: query);
  }

  KitapsenClient get _signedIn {
    final KitapsenClient? c = client;
    if (c == null) throw SyncBackendError('Not signed in to Kitapsen');
    return c;
  }

  /// GET for the store's other API files (`kitapsen_community.dart`):
  /// signed in when someone is, anonymous otherwise.
  Future<Object?> getJson(String path, {Map<String, String>? query}) =>
      _get(path, query: query);

  /// Signed-in request for the store's other API files; throws when nobody
  /// is signed in.
  Future<Object?> send(
    String method,
    String path, {
    Map<String, String>? query,
    Object? jsonBody,
  }) => _signedIn.requestJson(method, path, query: query, jsonBody: jsonBody);

  List<StoreBook> booksFrom(Object? list) => _books(list);

  List<StoreBook> _books(Object? list) => <StoreBook>[
    if (list is List<dynamic>)
      for (final dynamic item in list)
        if (item is Map<String, dynamic>)
          if (StoreBook.fromJson(item, apiBase) case final StoreBook book) book,
  ];

  // ── Catalog ───────────────────────────────────────────────────────

  /// Home shelves. `editors_choice` is left out: it holds discounted books
  /// only, and a discount is a price signal.
  Future<
    ({
      List<StoreBook> newArrivals,
      List<StoreBook> bestsellers,
      List<StoreBook> staffPicks,
    })
  >
  home() async {
    final Object? decoded = await _get(
      '/recommendations/home',
      query: const <String, String>{'per_section': '12'},
    );
    final Map<String, dynamic> map = decoded is Map<String, dynamic>
        ? decoded
        : const <String, dynamic>{};
    return (
      newArrivals: _books(map['new_arrivals']),
      bestsellers: _books(map['trending']),
      staffPicks: _books(map['staff_picks']),
    );
  }

  Future<StoreBookPage> search({
    String? query,
    String? categorySlug,
    int? authorUserId,
    String? authorName,
    int? publisherId,
    bool freeOnly = false,
    bool serializedOnly = false,
    StoreSort sort = StoreSort.relevance,
    int page = 1,
    int perPage = 30,
  }) async {
    final Object? decoded = await _get(
      '/search/',
      query: <String, String>{
        if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
        if (categorySlug != null) 'category': categorySlug,
        if (authorUserId != null) 'author_ids': '$authorUserId',
        if (authorName != null) 'author_name': authorName,
        if (publisherId != null) 'publisher_ids': '$publisherId',
        if (freeOnly) 'is_free': 'true',
        if (serializedOnly) 'is_serialized': 'true',
        'sort': switch (sort) {
          StoreSort.relevance => 'relevance',
          StoreSort.newest => 'newest',
          StoreSort.bestselling => 'bestselling',
          StoreSort.rating => 'rating',
          StoreSort.title => 'title',
        },
        'page': '$page',
        'items_per_page': '$perPage',
      },
    );
    if (decoded is! Map<String, dynamic>) {
      return const StoreBookPage(<StoreBook>[], 0);
    }
    return StoreBookPage(
      _books(decoded['results']),
      _int(decoded['total']) ?? 0,
      authors: <StoreAuthorMatch>[
        for (final dynamic a
            in decoded['author_matches'] as List<dynamic>? ?? const <dynamic>[])
          if (a is Map<String, dynamic> && _text(a['name']) != null)
            StoreAuthorMatch(
              name: _text(a['name'])!,
              bookCount: _int(a['book_count']) ?? 0,
              books: _books(a['books']),
              username: _text(a['username']),
              imageUrl: _text(a['author_image_url']) == null
                  ? null
                  : KitapsenClient.absoluteUrl(
                      apiBase,
                      _text(a['author_image_url'])!,
                    ),
            ),
      ],
    );
  }

  /// Website home "Okuma listenize yeni bir kitap", optionally for one
  /// category (an unknown slug answers 404).
  Future<List<StoreBook>> readingList({String? categorySlug}) async => _books(
    await _get(
      '/recommendations/reading-list',
      query: <String, String>{
        'limit': '12',
        if (categorySlug != null) 'category': categorySlug,
      },
    ),
  );

  /// The author's own books (credited to the account), as the website's
  /// author page lists them.
  Future<List<StoreBook>> authorBooks(String username) async {
    final Object? decoded = await _get(
      '/authors/books/${Uri.encodeComponent(username)}',
      query: const <String, String>{'items_per_page': '100'},
    );
    return _books(decoded is Map<String, dynamic> ? decoded['data'] : null);
  }

  Future<List<StoreCategory>> categories() async {
    final Object? decoded = await _get('/categories/tree');
    return <StoreCategory>[
      if (decoded is List<dynamic>)
        for (final dynamic c in decoded)
          if (c is Map<String, dynamic>)
            if (StoreCategory.fromJson(c) case final StoreCategory cat) cat,
    ];
  }

  Future<StoreBookDetail> book(int id) async {
    final Object? decoded = await _get('/books/$id');
    if (decoded is! Map<String, dynamic>) {
      throw SyncBackendError('Kitapsen book $id: unexpected response');
    }
    final StoreBook? book = StoreBook.fromJson(decoded, apiBase);
    if (book == null) {
      throw SyncBackendError('Kitapsen book $id: no title');
    }
    final Object? price = decoded['price'];
    // No price row means free; so does a zero effective price.
    final bool isFree =
        price is! Map<String, dynamic> ||
        price['is_free'] == true ||
        _double(price['effective_price']) <= 0;
    final List<dynamic> authors =
        decoded['authors'] as List<dynamic>? ?? const <dynamic>[];
    final Object? uploader = authors.isEmpty ? null : authors.first;
    final String? credited = _text(decoded['author_name']);
    final bool creditIsUploader =
        uploader is Map<dynamic, dynamic> &&
        (credited == null ||
            <Object?>[
              uploader['name'],
              uploader['username'],
            ].whereType<String>().map(_foldTr).contains(_foldTr(credited)));
    final Object? publisher = decoded['publisher'];
    return StoreBookDetail(
      book: book,
      subtitle: _text(decoded['subtitle']),
      description: _text(decoded['description']),
      authorUsername: creditIsUploader ? _text(uploader['username']) : null,
      publisherName: publisher is Map<String, dynamic>
          ? _text(publisher['name'])
          : _text(decoded['publisher_name']),
      publisherSlug: publisher is Map<String, dynamic>
          ? _text(publisher['slug'])
          : null,
      language: _text(decoded['language']),
      pageCount: _int(decoded['page_count']),
      publishingDate: _text(decoded['publishing_date']),
      categories: <({String name, String slug})>[
        for (final dynamic c
            in decoded['categories'] as List<dynamic>? ?? const <dynamic>[])
          if (c is Map<String, dynamic> &&
              _text(c['name']) != null &&
              _text(c['slug']) != null)
            (name: _text(c['name'])!, slug: _text(c['slug'])!),
      ],
      isFree: isFree,
      isSerialized: decoded['is_serialized'] == true,
      isbn: _text(decoded['isbn']),
      format: _text(decoded['format']),
      authorBio: _text(decoded['author_bio']),
    );
  }

  // ── Serialized stories ────────────────────────────────────────────

  Future<List<StoreChapter>> chapters(int bookId) async {
    final Object? decoded = await _get('/books/$bookId/chapters');
    final List<StoreChapter> chapters = <StoreChapter>[
      if (decoded is List<dynamic>)
        for (final dynamic c in decoded)
          if (c is Map<String, dynamic>)
            if (StoreChapter.fromJson(c) case final StoreChapter chapter)
              chapter,
    ];
    chapters.sort(
      (StoreChapter a, StoreChapter b) => a.number.compareTo(b.number),
    );
    return chapters;
  }

  Future<StoreChapter> chapter(int bookId, int chapterId) async {
    final Object? decoded = await _get('/books/$bookId/chapters/$chapterId');
    final StoreChapter? chapter = decoded is Map<String, dynamic>
        ? StoreChapter.fromJson(decoded)
        : null;
    if (chapter == null) {
      throw SyncBackendError(
        'Kitapsen chapter $chapterId: unexpected response',
      );
    }
    return chapter;
  }

  /// Counts a read of the chapter and, when signed in, remembers it as the
  /// place to resume the story (best effort: the caller ignores failures).
  Future<void> recordChapterRead(int bookId, int chapterId) async {
    await KitapsenClient.publicPostJson(
      apiBase,
      '/books/$bookId/chapters/$chapterId/read',
    );
    await client?.requestJson(
      'POST',
      '/books/$bookId/chapters/$chapterId/reading-state',
    );
  }

  Future<({int votes, bool voted})> chapterVotes(
    int bookId,
    int chapterId,
  ) async {
    final Object? decoded = await _get(
      '/books/$bookId/chapters/$chapterId/votes',
    );
    final Map<String, dynamic> map = decoded is Map<String, dynamic>
        ? decoded
        : const <String, dynamic>{};
    return (votes: _int(map['votes']) ?? 0, voted: map['voted'] == true);
  }

  Future<void> setChapterVote(int bookId, int chapterId, bool vote) =>
      _signedIn.requestJson(
        vote ? 'POST' : 'DELETE',
        '/books/$bookId/chapters/$chapterId/vote',
      );

  Future<List<StoreComment>> chapterComments(int bookId, int chapterId) async {
    final Object? decoded = await _get(
      '/books/$bookId/chapters/$chapterId/comments',
      query: const <String, String>{'sort': 'oldest', 'limit': '100'},
    );
    return _comments(decoded is Map<String, dynamic> ? decoded['items'] : null);
  }

  Future<void> addChapterComment(int bookId, int chapterId, String content) =>
      _signedIn.requestJson(
        'POST',
        '/books/$bookId/chapters/$chapterId/comments',
        jsonBody: <String, String>{'content': content.trim()},
      );

  Future<({int followers, bool following})> storyFollow(int bookId) async {
    final Object? decoded = await _get('/books/$bookId/follow');
    final Map<String, dynamic> map = decoded is Map<String, dynamic>
        ? decoded
        : const <String, dynamic>{};
    return (
      followers: _int(map['followers']) ?? 0,
      following: map['following'] == true,
    );
  }

  Future<void> setStoryFollow(int bookId, bool follow) => _signedIn.requestJson(
    follow ? 'POST' : 'DELETE',
    '/books/$bookId/follow',
  );

  /// Stories the reader follows, with their unread chapter count.
  Future<List<({StoreBook book, int unread})>> followedStories() async {
    final Object? decoded = await _signedIn.requestJson(
      'GET',
      '/books/stories/following',
    );
    return <({StoreBook book, int unread})>[
      if (decoded is List<dynamic>)
        for (final dynamic item in decoded)
          if (item is Map<String, dynamic>)
            if (StoreBook.fromJson(item, apiBase) case final StoreBook book)
              (book: book, unread: _int(item['unread']) ?? 0),
    ];
  }

  // ── Library ───────────────────────────────────────────────────────

  Future<bool> owns(int bookId) async {
    final Object? decoded = await _signedIn.requestJson(
      'GET',
      '/orders/library/$bookId/check',
    );
    return decoded is Map<String, dynamic> && decoded['has_license'] == true;
  }

  /// Adds free book [bookId] to the library (idempotent).
  Future<void> claimFree(int bookId) =>
      _signedIn.requestJson('POST', '/orders/library/$bookId/claim');

  // ── Wishlist ──────────────────────────────────────────────────────

  Future<bool> inWishlist(int bookId) async {
    final Object? decoded = await _signedIn.requestJson(
      'GET',
      '/wishlist/check/$bookId',
    );
    return decoded is Map<String, dynamic> && decoded['in_wishlist'] == true;
  }

  Future<void> setWishlisted(int bookId, bool wishlisted) => wishlisted
      ? _signedIn.requestJson(
          'POST',
          '/wishlist/',
          jsonBody: <String, int>{'book_id': bookId},
        )
      : _signedIn.requestJson('DELETE', '/wishlist/book/$bookId');

  Future<List<StoreBook>> wishlist() async {
    final List<StoreBook> books = <StoreBook>[];
    for (int page = 1; page <= 20; page++) {
      final Object? decoded = await _signedIn.requestJson(
        'GET',
        '/wishlist/',
        query: <String, String>{'page': '$page', 'items_per_page': '100'},
      );
      if (decoded is! Map<String, dynamic>) break;
      final List<StoreBook> items = _books(decoded['data']);
      books.addAll(items);
      if (decoded['has_more'] != true || items.isEmpty) break;
    }
    return books;
  }

  // ── Reviews ───────────────────────────────────────────────────────

  Future<({List<StoreReview> reviews, bool hasMore})> reviews(
    int bookId, {
    int page = 1,
  }) async {
    final Object? decoded = await _get(
      '/reviews/book/$bookId',
      query: <String, String>{
        'page': '$page',
        'items_per_page': '20',
        'sort': 'newest',
      },
    );
    if (decoded is! Map<String, dynamic>) {
      return (reviews: const <StoreReview>[], hasMore: false);
    }
    return (
      reviews: <StoreReview>[
        for (final dynamic r
            in decoded['reviews'] as List<dynamic>? ?? const <dynamic>[])
          if (r is Map<String, dynamic> && _int(r['id']) != null)
            StoreReview(
              id: _int(r['id'])!,
              rating: _int(r['rating']) ?? 0,
              userName: _text(r['user_name']) ?? _text(r['username']) ?? '—',
              title: _text(r['title']),
              content: _text(r['content']),
              createdAt: DateTime.tryParse('${r['created_at']}'),
              verified: r['is_verified_purchase'] == true,
              likeCount: _int(r['like_count']) ?? 0,
              commentCount: _int(r['comment_count']) ?? 0,
            ),
      ],
      hasMore: decoded['has_more'] == true,
    );
  }

  Future<void> addReview(
    int bookId, {
    required int rating,
    String? title,
    String? content,
  }) => _signedIn.requestJson(
    'POST',
    '/reviews/',
    jsonBody: <String, Object>{
      'book_id': bookId,
      'rating': rating,
      if (title != null && title.trim().isNotEmpty) 'title': title.trim(),
      if (content != null && content.trim().isNotEmpty)
        'content': content.trim(),
    },
  );

  /// Likes or unlikes review [reviewId] (the endpoint toggles).
  Future<({int likes, bool liked})> toggleReviewLike(int reviewId) async {
    final Object? decoded = await _signedIn.requestJson(
      'POST',
      '/reviews/$reviewId/like',
    );
    final Map<String, dynamic> map = decoded is Map<String, dynamic>
        ? decoded
        : const <String, dynamic>{};
    return (
      likes: _int(map['like_count']) ?? 0,
      liked: map['is_liked'] == true,
    );
  }

  List<StoreComment> _comments(Object? list) => <StoreComment>[
    if (list is List<dynamic>)
      for (final dynamic c in list)
        if (c is Map<String, dynamic>)
          if (StoreComment.fromJson(c) case final StoreComment comment) comment,
  ];

  Future<List<StoreComment>> reviewComments(int reviewId) async {
    final Object? decoded = await _get('/reviews/$reviewId/comments');
    return _comments(
      decoded is Map<String, dynamic> ? decoded['comments'] : null,
    );
  }

  Future<void> addReviewComment(int reviewId, String content) =>
      _signedIn.requestJson(
        'POST',
        '/reviews/$reviewId/comments',
        jsonBody: <String, String>{'content': content.trim()},
      );

  // ── Authors ───────────────────────────────────────────────────────

  Future<StoreAuthor> author(String username) async {
    final Object? decoded = await _get(
      '/authors/user/${Uri.encodeComponent(username)}',
    );
    final Object? data = decoded is Map<String, dynamic>
        ? decoded['data']
        : null;
    if (data is! Map<String, dynamic> || _int(data['user_id']) == null) {
      throw SyncBackendError('Kitapsen author $username: unexpected response');
    }
    final String? image = _text(data['author_image_url']);
    return StoreAuthor(
      userId: _int(data['user_id'])!,
      username: _text(data['username']) ?? username,
      name:
          _text(data['shown_author_name']) ??
          _text(data['pen_name']) ??
          _text(data['name']) ??
          username,
      bio: _text(data['bio']),
      imageUrl: image == null
          ? null
          : KitapsenClient.absoluteUrl(apiBase, image),
      verified: data['verified'] == true,
      bookCount: _int(data['book_count']) ?? 0,
    );
  }

  Future<({bool following, int followers})> followStatus(
    String username,
  ) async {
    final Object? decoded = await _get(
      '/authors/user/${Uri.encodeComponent(username)}/follow-status',
    );
    final Map<String, dynamic> map = decoded is Map<String, dynamic>
        ? decoded
        : const <String, dynamic>{};
    return (
      following: map['following'] == true,
      followers: _int(map['follower_count']) ?? 0,
    );
  }

  /// The author's "Beğen" count and whether the reader likes them. A like
  /// sends the author no notification (unlike following).
  Future<({bool liked, int likes})> authorLikes(String username) async =>
      _likeState(
        await _get('/authors/user/${Uri.encodeComponent(username)}/likes'),
      );

  Future<({bool liked, int likes})> setAuthorLike(
    String username,
    bool like,
  ) async => _likeState(
    await _signedIn.requestJson(
      'POST',
      '/authors/user/${Uri.encodeComponent(username)}/like',
      jsonBody: <String, Object>{'value': like},
    ),
  );

  ({bool liked, int likes}) _likeState(Object? decoded) {
    final Map<String, dynamic> map = decoded is Map<String, dynamic>
        ? decoded
        : const <String, dynamic>{};
    return (liked: map['liked'] == true, likes: _int(map['likes']) ?? 0);
  }

  Future<({bool following, int followers})> setFollowing(
    String username,
    bool follow,
  ) async {
    final Object? decoded = await _signedIn.requestJson(
      follow ? 'POST' : 'DELETE',
      '/authors/user/${Uri.encodeComponent(username)}/follow',
    );
    final Map<String, dynamic> map = decoded is Map<String, dynamic>
        ? decoded
        : const <String, dynamic>{};
    return (
      following: map['following'] == true,
      followers: _int(map['follower_count']) ?? 0,
    );
  }

  Future<List<StoreFollowedAuthor>> followedAuthors() async {
    final Object? decoded = await _signedIn.requestJson(
      'GET',
      '/authors/me/following',
      query: const <String, String>{'items_per_page': '100'},
    );
    final Object? list = decoded is Map<String, dynamic>
        ? decoded['authors']
        : null;
    return <StoreFollowedAuthor>[
      if (list is List<dynamic>)
        for (final dynamic a in list)
          if (a is Map<String, dynamic> && _text(a['username']) != null)
            StoreFollowedAuthor(
              username: _text(a['username'])!,
              name: _text(a['display_name']) ?? _text(a['username'])!,
              imageUrl: _text(a['author_image_url']) == null
                  ? null
                  : KitapsenClient.absoluteUrl(
                      apiBase,
                      _text(a['author_image_url'])!,
                    ),
            ),
    ];
  }

  // ── Notifications ─────────────────────────────────────────────────

  static final RegExp _bookLink = RegExp(r'^/book/(\d+)');

  Future<({List<StoreNotification> items, bool hasMore})> notifications({
    int page = 1,
  }) async {
    final Object? decoded = await _signedIn.requestJson(
      'GET',
      '/notifications/',
      query: <String, String>{'page': '$page', 'items_per_page': '30'},
    );
    if (decoded is! Map<String, dynamic>) {
      return (items: const <StoreNotification>[], hasMore: false);
    }
    return (
      items: <StoreNotification>[
        for (final dynamic n
            in decoded['data'] as List<dynamic>? ?? const <dynamic>[])
          if (n is Map<String, dynamic> && _int(n['id']) != null)
            StoreNotification(
              id: _int(n['id'])!,
              title: _text(n['title']) ?? '',
              message: _text(n['message']) ?? _text(n['content']) ?? '',
              isRead: n['is_read'] == true,
              createdAt: DateTime.tryParse('${n['created_at']}'),
              bookId: _int(
                _bookLink.firstMatch(_text(n['link']) ?? '')?.group(1),
              ),
            ),
      ],
      hasMore: decoded['has_more'] == true,
    );
  }

  Future<int> unreadNotificationCount() async {
    final Object? decoded = await _signedIn.requestJson(
      'GET',
      '/notifications/unread-count',
    );
    return decoded is Map<String, dynamic>
        ? _int(decoded['unread_count']) ?? 0
        : 0;
  }

  Future<void> markNotificationRead(int id) =>
      _signedIn.requestJson('PATCH', '/notifications/$id/read');

  Future<void> markAllNotificationsRead() =>
      _signedIn.requestJson('PATCH', '/notifications/read-all');
}
