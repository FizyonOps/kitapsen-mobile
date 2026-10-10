/// The rest of kitapsen.com's reader features, on top of [KitapsenStore]:
/// account settings, publishers, the blog, the author directory, private
/// collections, notebooks, reading goals, the social feed, public reader
/// profiles and book clubs. Same store policy as `kitapsen_store.dart`: no
/// prices, no purchase links.
library;

import 'package:fushi/src/sync/kitapsen_client.dart';
import 'package:fushi/src/sync/kitapsen_store.dart';

int? _int(Object? v) => v is num ? v.toInt() : int.tryParse('$v');

double _double(Object? v) =>
    v is num ? v.toDouble() : double.tryParse('$v') ?? 0;

String? _text(Object? v) {
  if (v is! String) return null;
  final String trimmed = v.trim();
  return trimmed.isEmpty ? null : trimmed;
}

DateTime? _date(Object? v) => v is String ? DateTime.tryParse(v) : null;

List<Map<String, dynamic>> _rows(Object? decoded) {
  final Object? list = decoded is Map<String, dynamic>
      ? decoded['data']
      : decoded;
  return <Map<String, dynamic>>[
    if (list is List<dynamic>)
      for (final dynamic item in list)
        if (item is Map<String, dynamic>) item,
  ];
}

/// The signed-in account (`/users/me`), without the fields the app never
/// shows (DRM key material, payment ids).
class StoreMe {
  const StoreMe({
    required this.id,
    required this.name,
    required this.username,
    required this.email,
    required this.isPrivate,
    required this.newFollowerEmail,
    required this.newCommentEmail,
    required this.newSaleEmail,
  });

  final int id;
  final String name;
  final String username;
  final String email;
  final bool isPrivate;
  final bool newFollowerEmail;
  final bool newCommentEmail;
  final bool newSaleEmail;
}

class StorePublisher {
  const StorePublisher({
    required this.id,
    required this.name,
    required this.slug,
    required this.bookCount,
    this.description,
    this.logoUrl,
    this.verified = false,
  });

  final int id;
  final String name;
  final String slug;
  final int bookCount;
  final String? description;
  final String? logoUrl;
  final bool verified;
}

class StoreBlogPost {
  const StoreBlogPost({
    required this.slug,
    required this.title,
    this.excerpt,
    this.imageUrl,
    this.category,
    this.authorName,
    this.publishedAt,
    this.content,
  });

  final String slug;
  final String title;
  final String? excerpt;
  final String? imageUrl;
  final String? category;
  final String? authorName;
  final DateTime? publishedAt;

  /// HTML; only the single-post endpoint carries it.
  final String? content;
}

/// A person or a credited name in the author directory. [username] is set
/// only for authors with an account (they have a profile page).
class StoreDirectoryAuthor {
  const StoreDirectoryAuthor({
    required this.name,
    this.username,
    this.imageUrl,
    this.bookCount,
  });

  final String name;
  final String? username;
  final String? imageUrl;
  final int? bookCount;
}

class StoreCollectionItem {
  const StoreCollectionItem({
    required this.id,
    required this.bookId,
    required this.title,
    this.coverUrl,
  });

  final int id;
  final int bookId;
  final String title;
  final String? coverUrl;
}

class StoreCollection {
  const StoreCollection({
    required this.id,
    required this.name,
    required this.itemCount,
    this.description,
    this.items = const <StoreCollectionItem>[],
  });

  final int id;
  final String name;
  final int itemCount;
  final String? description;
  final List<StoreCollectionItem> items;
}

class StoreNotebookEntry {
  const StoreNotebookEntry({
    required this.id,
    required this.content,
    this.createdAt,
  });

  final int id;
  final String content;
  final DateTime? createdAt;
}

class StoreNotebook {
  const StoreNotebook({
    required this.id,
    required this.name,
    required this.entryCount,
    this.entries = const <StoreNotebookEntry>[],
  });

  final int id;
  final String name;
  final int entryCount;
  final List<StoreNotebookEntry> entries;
}

/// `BOOKS`, `PAGES`, `HOURS` or `DAYS`, as the server stores them.
class StoreReadingGoal {
  const StoreReadingGoal({
    required this.id,
    required this.type,
    required this.target,
    required this.progress,
    required this.percent,
    required this.endDate,
    this.startDate,
    this.completed = false,
  });

  final int id;
  final String type;
  final double target;
  final double progress;
  final double percent;
  final DateTime endDate;
  final DateTime? startDate;
  final bool completed;
}

class StoreReadingStats {
  const StoreReadingStats({
    required this.currentStreak,
    required this.longestStreak,
    required this.booksRead,
    required this.booksFinished,
    required this.pagesRead,
  });

  final int currentStreak;
  final int longestStreak;
  final int booksRead;
  final int booksFinished;
  final int pagesRead;
}

/// One social feed line: who did what to which book or person.
class StoreFeedEntry {
  const StoreFeedEntry({
    required this.id,
    required this.username,
    required this.action,
    required this.targetType,
    this.targetId,
    this.targetTitle,
    this.targetCoverUrl,
    this.targetUsername,
    this.avatarUrl,
    this.progressPercent,
    this.createdAt,
  });

  final int id;
  final String username;

  /// `started_reading`, `finished_book`, `reviewed_book`, `followed_author`,
  /// `followed_user`, ...
  final String action;
  final String targetType;
  final int? targetId;
  final String? targetTitle;
  final String? targetCoverUrl;
  final String? targetUsername;
  final String? avatarUrl;
  final double? progressPercent;
  final DateTime? createdAt;
}

class StoreUser {
  const StoreUser({
    required this.username,
    required this.name,
    this.imageUrl,
    this.isPrivate = false,
    this.createdAt,
  });

  final String username;
  final String name;
  final String? imageUrl;
  final bool isPrivate;
  final DateTime? createdAt;
}

class StoreUserStatus {
  const StoreUserStatus({
    required this.following,
    required this.followers,
    required this.followingCount,
    required this.blockedByMe,
    required this.blockedMe,
  });

  final bool following;
  final int followers;
  final int followingCount;
  final bool blockedByMe;
  final bool blockedMe;
}

/// A book on a reader's public shelf.
class StorePublicProgress {
  const StorePublicProgress({
    required this.bookId,
    required this.title,
    required this.percent,
    this.coverUrl,
  });

  final int bookId;
  final String title;
  final double percent;
  final String? coverUrl;
}

/// A review on a reader's profile, with the book it is about.
class StoreUserReview {
  const StoreUserReview({
    required this.rating,
    required this.bookId,
    required this.bookTitle,
    this.title,
    this.content,
    this.bookCoverUrl,
    this.createdAt,
  });

  final int rating;
  final int bookId;
  final String bookTitle;
  final String? title;
  final String? content;
  final String? bookCoverUrl;
  final DateTime? createdAt;
}

class StoreBookClub {
  const StoreBookClub({
    required this.id,
    required this.name,
    required this.memberCount,
    required this.ownerId,
    required this.memberIds,
    this.description,
    this.currentBookId,
  });

  final int id;
  final String name;
  final int memberCount;
  final int ownerId;

  /// User ids of the members, to tell whether the reader is one.
  final Set<int> memberIds;
  final String? description;
  final int? currentBookId;
}

class StoreClubMember {
  const StoreClubMember({
    required this.username,
    required this.role,
    this.name,
    this.imageUrl,
  });

  final String username;
  final String role;
  final String? name;
  final String? imageUrl;
}

class StoreClubMessage {
  const StoreClubMessage({
    required this.id,
    required this.content,
    this.username,
    this.createdAt,
  });

  final int id;
  final String content;
  final String? username;
  final DateTime? createdAt;
}

extension KitapsenCommunity on KitapsenStore {
  String? _url(Object? v) {
    final String? path = _text(v);
    return path == null ? null : KitapsenClient.absoluteUrl(apiBase, path);
  }

  StoreUser _user(Map<String, dynamic> j) => StoreUser(
    username: _text(j['username']) ?? '',
    name: _text(j['name']) ?? _text(j['display_name']) ?? '',
    imageUrl: _url(j['profile_image_url'] ?? j['avatar_url']),
    isPrivate: j['is_private'] == true,
    createdAt: _date(j['created_at']),
  );

  // ── Account ───────────────────────────────────────────────────────

  Future<StoreMe> me() async {
    final Object? d = await send('GET', '/users/me');
    final Map<String, dynamic> j = d is Map<String, dynamic>
        ? d
        : const <String, dynamic>{};
    return StoreMe(
      id: _int(j['id']) ?? 0,
      name: _text(j['name']) ?? '',
      username: _text(j['username']) ?? '',
      email: _text(j['email']) ?? '',
      isPrivate: j['is_private'] == true,
      newFollowerEmail: j['new_follower_email'] != false,
      newCommentEmail: j['new_comment_email'] != false,
      newSaleEmail: j['new_sale_email'] != false,
    );
  }

  /// PATCH `/users/me` with the given fields (`name`, `email`, `is_private`,
  /// `new_follower_email`, ...).
  Future<void> updateMe(Map<String, Object> fields) =>
      send('PATCH', '/users/me', jsonBody: fields);

  Future<void> changePassword(String current, String next) => send(
    'POST',
    '/users/me/change-password',
    jsonBody: <String, String>{
      'current_password': current,
      'new_password': next,
    },
  );

  /// Whether the reader's reading progress shows on their public profile
  /// (true when any book is shared, like the website's toggle).
  Future<bool> readingShared() async {
    final Object? d = await send('GET', '/reading/progress');
    return _rows(d).any((Map<String, dynamic> r) => r['is_public'] == true);
  }

  /// Shares or hides every book's progress on the public profile.
  Future<void> setReadingShared(bool shared) async {
    final Object? d = await send('GET', '/reading/progress');
    for (final Map<String, dynamic> r in _rows(d)) {
      final int? bookId = _int(r['book_id']);
      if (bookId == null || (r['is_public'] == true) == shared) continue;
      await send(
        'PATCH',
        '/reading/progress',
        jsonBody: <String, Object>{'book_id': bookId, 'is_public': shared},
      );
    }
  }

  Future<List<StoreUser>> blockedUsers() async => <StoreUser>[
    for (final Map<String, dynamic> j in _rows(await send('GET', '/blocks/')))
      _user(j),
  ];

  Future<void> setBlocked(String username, bool blocked) => send(
    blocked ? 'POST' : 'DELETE',
    '/blocks/${Uri.encodeComponent(username)}',
  );

  // ── Publishers ────────────────────────────────────────────────────

  StorePublisher _publisher(Map<String, dynamic> j) => StorePublisher(
    id: _int(j['id']) ?? 0,
    name: _text(j['name']) ?? '',
    slug: _text(j['slug']) ?? '',
    bookCount: _int(j['book_count']) ?? 0,
    description: _text(j['description']),
    logoUrl: _url(j['logo_url']),
    verified: j['is_verified'] == true,
  );

  /// Approved publishers that have books (the directory also holds empty
  /// test brands).
  Future<List<StorePublisher>> publishers() async => <StorePublisher>[
    for (final Map<String, dynamic> j in _rows(
      await getJson('/publishers/approved'),
    ))
      if ((_int(j['book_count']) ?? 0) > 0) _publisher(j),
  ];

  Future<StorePublisher> publisher(String slug) async {
    final Object? d = await getJson(
      '/publishers/slug/${Uri.encodeComponent(slug)}',
    );
    return _publisher(
      d is Map<String, dynamic> ? d : const <String, dynamic>{},
    );
  }

  ({int followers, int likes, bool following, bool liked}) _engagement(
    Object? d,
  ) {
    final Map<String, dynamic> j = d is Map<String, dynamic>
        ? (d['data'] is Map<String, dynamic>
              ? d['data'] as Map<String, dynamic>
              : d)
        : const <String, dynamic>{};
    return (
      followers: _int(j['followers']) ?? 0,
      likes: _int(j['likes']) ?? 0,
      following: j['following'] == true,
      liked: j['liked'] == true,
    );
  }

  Future<({int followers, int likes, bool following, bool liked})>
  publisherEngagement(int id) async =>
      _engagement(await getJson('/publishers/$id/engagement'));

  /// [follow] true sets follow, false sets like; [value] turns it on or off.
  Future<({int followers, int likes, bool following, bool liked})>
  setPublisherEngagement(
    int id, {
    required bool follow,
    required bool value,
  }) async => _engagement(
    await send(
      'POST',
      '/publishers/$id/${follow ? 'follow' : 'like'}',
      jsonBody: <String, bool>{'value': value},
    ),
  );

  // ── Blog ──────────────────────────────────────────────────────────

  StoreBlogPost _post(Map<String, dynamic> j) => StoreBlogPost(
    slug: _text(j['slug']) ?? '',
    title: _text(j['title']) ?? '',
    excerpt: _text(j['excerpt']),
    imageUrl: _url(j['featured_image_url']),
    category: _text(j['category']),
    authorName: _text(j['author_name']),
    publishedAt: _date(j['published_at'] ?? j['created_at']),
    content: j['content'] as String?,
  );

  Future<({List<StoreBlogPost> posts, int total})> blogPosts({
    String? category,
    int skip = 0,
  }) async {
    final Object? d = await getJson(
      '/blog/',
      query: <String, String>{
        'skip': '$skip',
        'limit': '20',
        if (category != null) 'category': category,
      },
    );
    return (
      posts: <StoreBlogPost>[
        for (final Map<String, dynamic> j in _rows(d))
          if (_text(j['slug']) != null) _post(j),
      ],
      total: d is Map<String, dynamic> ? _int(d['total']) ?? 0 : 0,
    );
  }

  Future<List<String>> blogCategories() async {
    final Object? d = await getJson('/blog/categories');
    final Object? list = d is Map<String, dynamic> ? d['data'] : d;
    return <String>[
      if (list is List<dynamic>)
        for (final dynamic c in list)
          if (_text(c is Map<String, dynamic> ? c['name'] ?? c['category'] : c)
              case final String name)
            name,
    ];
  }

  Future<StoreBlogPost> blogPost(String slug) async {
    final Object? d = await getJson('/blog/${Uri.encodeComponent(slug)}');
    return _post(d is Map<String, dynamic> ? d : const <String, dynamic>{});
  }

  // ── Author directory ──────────────────────────────────────────────

  /// Authors with a profile first (they have a page), then the other
  /// credited names, like the website's /authors.
  Future<List<StoreDirectoryAuthor>> authorDirectory() async {
    final (Object? profiles, Object? credited) = await (
      getJson(
        '/authors/',
        query: const <String, String>{'items_per_page': '100'},
      ),
      getJson('/authors/credited'),
    ).wait;
    final List<StoreDirectoryAuthor> out = <StoreDirectoryAuthor>[];
    final Set<String> seen = <String>{};
    for (final Map<String, dynamic> j in _rows(profiles)) {
      final String? username = _text(j['username']);
      final String? name =
          _text(j['shown_author_name']) ??
          _text(j['pen_name']) ??
          _text(j['name']);
      if (username == null || name == null) continue;
      seen.add(name.toLowerCase());
      out.add(
        StoreDirectoryAuthor(
          name: name,
          username: username,
          imageUrl: _url(j['author_image_url']),
          bookCount: _int(j['book_count']),
        ),
      );
    }
    for (final Map<String, dynamic> j in _rows(credited)) {
      final String? name = _text(j['name']);
      if (name == null || !seen.add(name.toLowerCase())) continue;
      out.add(
        StoreDirectoryAuthor(name: name, bookCount: _int(j['book_count'])),
      );
    }
    return out;
  }

  // ── Collections ───────────────────────────────────────────────────

  StoreCollection _collection(Map<String, dynamic> j) => StoreCollection(
    id: _int(j['id']) ?? 0,
    name: _text(j['name']) ?? '',
    itemCount: _int(j['item_count']) ?? 0,
    description: _text(j['description']),
    items: <StoreCollectionItem>[
      for (final dynamic i in j['items'] as List<dynamic>? ?? const <dynamic>[])
        if (i is Map<String, dynamic>)
          StoreCollectionItem(
            id: _int(i['id']) ?? 0,
            bookId: _int(i['book_id']) ?? 0,
            title: _text(i['title']) ?? '',
            coverUrl: _url(i['cover_image_url']),
          ),
    ],
  );

  Future<List<StoreCollection>> collections() async => <StoreCollection>[
    for (final Map<String, dynamic> j in _rows(
      await send(
        'GET',
        '/collections/',
        query: const <String, String>{'items_per_page': '100'},
      ),
    ))
      _collection(j),
  ];

  Future<StoreCollection> collection(int id) async {
    final Object? d = await send('GET', '/collections/$id');
    return _collection(
      d is Map<String, dynamic> ? d : const <String, dynamic>{},
    );
  }

  Future<void> createCollection(String name, {String? description}) => send(
    'POST',
    '/collections/',
    jsonBody: <String, Object>{
      'name': name,
      if (description != null && description.isNotEmpty)
        'description': description,
    },
  );

  Future<void> updateCollection(int id, String name, String? description) =>
      send(
        'PATCH',
        '/collections/$id',
        jsonBody: <String, Object?>{'name': name, 'description': description},
      );

  Future<void> deleteCollection(int id) => send('DELETE', '/collections/$id');

  Future<void> addToCollection(int collectionId, int bookId) => send(
    'POST',
    '/collections/$collectionId/items',
    query: <String, String>{'book_id': '$bookId'},
  );

  Future<void> removeFromCollection(int collectionId, int itemId) =>
      send('DELETE', '/collections/$collectionId/items/$itemId');

  // ── Notebooks ─────────────────────────────────────────────────────

  StoreNotebook _notebook(Map<String, dynamic> j) => StoreNotebook(
    id: _int(j['id']) ?? 0,
    name: _text(j['name']) ?? '',
    entryCount: _int(j['entry_count']) ?? 0,
    entries: <StoreNotebookEntry>[
      for (final dynamic e
          in j['entries'] as List<dynamic>? ?? const <dynamic>[])
        if (e is Map<String, dynamic> && _text(e['content']) != null)
          StoreNotebookEntry(
            id: _int(e['id']) ?? 0,
            content: _text(e['content'])!,
            createdAt: _date(e['created_at']),
          ),
    ],
  );

  Future<List<StoreNotebook>> notebooks() async => <StoreNotebook>[
    for (final Map<String, dynamic> j in _rows(
      await send(
        'GET',
        '/notebooks/',
        query: const <String, String>{'items_per_page': '100'},
      ),
    ))
      _notebook(j),
  ];

  Future<StoreNotebook> notebook(int id) async {
    final Object? d = await send('GET', '/notebooks/$id');
    return _notebook(d is Map<String, dynamic> ? d : const <String, dynamic>{});
  }

  Future<void> createNotebook(String name) =>
      send('POST', '/notebooks/', jsonBody: <String, String>{'name': name});

  Future<void> renameNotebook(int id, String name) =>
      send('PATCH', '/notebooks/$id', jsonBody: <String, String>{'name': name});

  Future<void> deleteNotebook(int id) => send('DELETE', '/notebooks/$id');

  Future<void> addNotebookEntry(int id, String content) => send(
    'POST',
    '/notebooks/$id/entries',
    jsonBody: <String, String>{'content': content},
  );

  Future<void> deleteNotebookEntry(int id, int entryId) =>
      send('DELETE', '/notebooks/$id/entries/$entryId');

  // ── Reading goals ─────────────────────────────────────────────────

  Future<List<StoreReadingGoal>> readingGoals() async => <StoreReadingGoal>[
    for (final Map<String, dynamic> j in _rows(
      await send('GET', '/reading-goals/'),
    ))
      if (DateTime.tryParse('${j['end_date']}') case final DateTime end)
        StoreReadingGoal(
          id: _int(j['id']) ?? 0,
          type: _text(j['goal_type']) ?? 'BOOKS',
          target: _double(j['target']),
          progress: _double(j['current_progress']),
          percent: _double(j['progress_percent']),
          endDate: end,
          startDate: _date(j['start_date']),
          completed: j['completed_at'] != null,
        ),
  ];

  Future<void> createReadingGoal({
    required String type,
    required double target,
    required DateTime start,
    required DateTime end,
  }) {
    String day(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    return send(
      'POST',
      '/reading-goals/',
      jsonBody: <String, Object>{
        'goal_type': type,
        'target': target,
        'start_date': day(start),
        'end_date': day(end),
      },
    );
  }

  Future<void> deleteReadingGoal(int id) =>
      send('DELETE', '/reading-goals/$id');

  Future<StoreReadingStats> readingStats() async {
    final Object? d = await send('GET', '/reading/stats/summary');
    final Map<String, dynamic> j = d is Map<String, dynamic>
        ? d
        : const <String, dynamic>{};
    return StoreReadingStats(
      currentStreak: _int(j['current_streak']) ?? 0,
      longestStreak: _int(j['longest_streak']) ?? 0,
      booksRead: _int(j['total_books_read']) ?? 0,
      booksFinished: _int(j['books_finished']) ?? 0,
      pagesRead: _int(j['total_pages_read']) ?? 0,
    );
  }

  // ── Social feed ───────────────────────────────────────────────────

  List<StoreFeedEntry> _feed(Object? d) => <StoreFeedEntry>[
    for (final Map<String, dynamic> j in _rows(d))
      StoreFeedEntry(
        id: _int(j['id']) ?? 0,
        username: _text(j['username']) ?? '',
        action: _text(j['action_type']) ?? '',
        targetType: _text(j['target_type']) ?? '',
        targetId: _int(j['target_id']),
        targetTitle: _text(j['target_title']),
        targetCoverUrl: _url(j['target_cover_url']),
        targetUsername: _text(j['target_username']),
        avatarUrl: _url(j['user_avatar_url']),
        progressPercent: j['metadata'] is Map<String, dynamic>
            ? (j['metadata'] as Map<String, dynamic>)['progress_percent'] is num
                  ? ((j['metadata'] as Map<String, dynamic>)['progress_percent']
                            as num)
                        .toDouble()
                  : null
            : null,
        createdAt: _date(j['created_at']),
      ),
  ];

  /// What the people the reader follows did ([mine]: the reader's own).
  Future<List<StoreFeedEntry>> feed({bool mine = false, int page = 1}) async =>
      _feed(
        await send(
          'GET',
          mine ? '/social-feed/my' : '/social-feed/',
          query: <String, String>{'page': '$page', 'items_per_page': '30'},
        ),
      );

  // ── Reader profiles ───────────────────────────────────────────────

  Future<StoreUser> user(String username) async {
    final Object? d = await getJson('/users/${Uri.encodeComponent(username)}');
    return _user(d is Map<String, dynamic> ? d : const <String, dynamic>{});
  }

  StoreUserStatus _status(Object? d) {
    final Map<String, dynamic> j = d is Map<String, dynamic>
        ? d
        : const <String, dynamic>{};
    return StoreUserStatus(
      following: j['following'] == true,
      followers: _int(j['follower_count']) ?? 0,
      followingCount: _int(j['following_count']) ?? 0,
      blockedByMe: j['blocked_by_me'] == true,
      blockedMe: j['blocked_me'] == true,
    );
  }

  Future<StoreUserStatus> userStatus(String username) async => _status(
    await getJson('/user-follow/${Uri.encodeComponent(username)}/status'),
  );

  Future<void> setUserFollowing(String username, bool follow) => send(
    follow ? 'POST' : 'DELETE',
    '/user-follow/${Uri.encodeComponent(username)}/follow',
  );

  /// A reader's public shelf; empty when they share nothing.
  Future<
    ({List<StorePublicProgress> reading, List<StorePublicProgress> finished})
  >
  publicReading(String username) async {
    final Object? d = await getJson(
      '/reading/public/${Uri.encodeComponent(username)}',
    );
    List<StorePublicProgress> list(Object? v) => <StorePublicProgress>[
      if (v is List<dynamic>)
        for (final dynamic p in v)
          if (p is Map<String, dynamic> && _int(p['book_id']) != null)
            StorePublicProgress(
              bookId: _int(p['book_id'])!,
              title: _text(p['title']) ?? '',
              percent: _double(p['progress_percent']),
              coverUrl: _url(p['cover_image_url']),
            ),
    ];
    final Map<String, dynamic> j = d is Map<String, dynamic>
        ? d
        : const <String, dynamic>{};
    return (
      reading: list(j['currently_reading']),
      finished: list(j['finished']),
    );
  }

  Future<List<StoreUserReview>> userReviews(String username) async {
    final Object? d = await getJson(
      '/reviews/user/${Uri.encodeComponent(username)}',
    );
    final Object? list = d is Map<String, dynamic> ? d['reviews'] : null;
    return <StoreUserReview>[
      if (list is List<dynamic>)
        for (final dynamic r in list)
          if (r is Map<String, dynamic> && r['book'] is Map<String, dynamic>)
            StoreUserReview(
              rating: _int(r['rating']) ?? 0,
              bookId: _int((r['book'] as Map<String, dynamic>)['id']) ?? 0,
              bookTitle:
                  _text((r['book'] as Map<String, dynamic>)['title']) ?? '',
              bookCoverUrl: _url(
                (r['book'] as Map<String, dynamic>)['cover_image_url'],
              ),
              title: _text(r['title']),
              content: _text(r['content']),
              createdAt: _date(r['created_at']),
            ),
    ];
  }

  Future<List<StoreFeedEntry>> userActivity(String username) async => _feed(
    await getJson('/social-feed/user/${Uri.encodeComponent(username)}'),
  );

  /// Who follows [username] ([following]: whom they follow).
  Future<List<StoreUser>> userConnections(
    String username, {
    required bool following,
  }) async => <StoreUser>[
    for (final Map<String, dynamic> j in _rows(
      await getJson(
        '/user-follow/${Uri.encodeComponent(username)}/${following ? 'following' : 'followers'}',
      ),
    ))
      _user(j),
  ];

  // ── Book clubs ────────────────────────────────────────────────────

  StoreBookClub _club(Map<String, dynamic> j) => StoreBookClub(
    id: _int(j['id']) ?? 0,
    name: _text(j['name']) ?? '',
    memberCount: _int(j['member_count']) ?? 0,
    ownerId: _int(j['owner_id']) ?? 0,
    memberIds: <int>{
      for (final dynamic m
          in j['members'] as List<dynamic>? ?? const <dynamic>[])
        if (m is Map<String, dynamic> && _int(m['user_id']) != null)
          _int(m['user_id'])!,
    },
    description: _text(j['description']),
    currentBookId: _int(j['current_book_id']),
  );

  Future<List<StoreBookClub>> bookClubs() async => <StoreBookClub>[
    for (final Map<String, dynamic> j in _rows(
      await send(
        'GET',
        '/community/book-clubs',
        query: const <String, String>{'items_per_page': '100'},
      ),
    ))
      _club(j),
  ];

  Future<void> createBookClub(String name, {String? description}) => send(
    'POST',
    '/community/book-clubs',
    jsonBody: <String, Object>{
      'name': name,
      if (description != null && description.isNotEmpty)
        'description': description,
      'is_public': true,
    },
  );

  Future<void> setClubMember(int clubId, bool join) =>
      send('POST', '/community/book-clubs/$clubId/${join ? 'join' : 'leave'}');

  Future<List<StoreClubMember>> clubMembers(int clubId) async =>
      <StoreClubMember>[
        for (final Map<String, dynamic> j in _rows(
          await send('GET', '/community/book-clubs/$clubId/members'),
        ))
          if (_text(j['username']) != null)
            StoreClubMember(
              username: _text(j['username'])!,
              role: _text(j['role']) ?? 'member',
              name: _text(j['display_name']),
              imageUrl: _url(j['avatar_url']),
            ),
      ];

  Future<List<StoreClubMessage>> clubMessages(int clubId) async =>
      <StoreClubMessage>[
        for (final Map<String, dynamic> j in _rows(
          await send(
            'GET',
            '/community/book-clubs/$clubId/discussions',
            query: const <String, String>{'items_per_page': '100'},
          ),
        ))
          if (_text(j['content']) != null)
            StoreClubMessage(
              id: _int(j['id']) ?? 0,
              content: _text(j['content'])!,
              username: _text(j['username']),
              createdAt: _date(j['created_at']),
            ),
      ];

  Future<void> postClubMessage(int clubId, String content) => send(
    'POST',
    '/community/book-clubs/$clubId/discussions',
    jsonBody: <String, String>{'content': content},
  );
}
