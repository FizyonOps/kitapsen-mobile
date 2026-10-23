
import 'package:fushi_core/fushi_core.dart';

// ── 术语约定（命名统一轮审计词表）────────────────────────────────────────────
//
// 本文件（及互联域）的角色词汇统一如下，doc 注释里的「host …」均按此读：
// * **peer / 对端**：已配对的另一台设备（对称概念，不指角色）。
// * **host**：一次交互里**提供库**的角色（开着内嵌 server、被拉取清单/内容的一侧）。
// * **client**：一次交互里消费库的角色（拉清单、下载、上报进度的一侧）。
// * **Remote\***：从消费端视角描述「对端数据」的 wire DTO——类名的 Remote 指
//   「对端（通常是 host 角色）的条目」，`RemoteBookInfo` = 对端 host 书库里的一本书。
//   host 端 materialize 自己的库为同一 DTO 下发，client 端 fromJson 消费。

// ── 书籍 push 的元数据 header（BUG-1503）────────────────────────────────────
//
// `PUT /api/library/books/<title>` 的 body 是**裸 .epub 字节流**（无 multipart、
// 无 sidecar、无 query），所以随行元数据只能走自定义 header——沿用视频推送
// `X-Hibiki-Video-Title` 的既有先例。两侧共用这两个常量，避免字面量各写一份漂开。
//
// ⚠️ header 值只收 ASCII：写侧必须 `Uri.encodeComponent`，读侧 `Uri.decodeComponent`
// （日文书名直接塞进 header 会抛）。additive：没改过名就不发，旧 host 对未知 header
// 静默忽略，旧 client 不发 → 新 host 读到 null，两个方向都零破坏。

// ── 键集 union diff（本地音频 / 有声书 / 词典共享）──────────────────────────

// ── 本地音频 ──────────────────────────────────────────────────────────────────

// ── 有声书包 ──────────────────────────────────────────────────────────────────

// ── 词典 ──────────────────────────────────────────────────────────────────────

// ── 合集归属（多端库联合视图 §2.3 任务5.1）────────────────────────────────────

/// 一条目在 host 端的**主合集归属**（跟随 [FushiDatabase.getPrimaryCollectionIdByEntry]
/// 的「最小 collectionId」折叠语义：一条目可属多合集，只带它折进的那一张）。
///
/// 远端占位卡据此归进对应合集行（UI 批任务 8-10 消费）：[collectionName] +
/// [collectionType] 是合集自然键（与合集清单 / 备份合并的 (name, collection_type) 对齐），
/// [sortIndex] 是该条目在该合集里的组内序（= `MediaCollectionItems.sortIndex`，与本地卡
/// `groupByCollections` 的 memberSortIndex 同源）。[RemoteBookInfo.collection] /
/// [RemoteVideoInfo.collection] 缺省 null = 该条目不属任何合集（散卡）。
abstract class RemoteCollectionMembership {

}

// ── Books ──────────────────────────────────────────────────────────────────

/// host 实时书籍的清单条目。
///
/// [title]      书名（与 DB `epub_books.title` 列一致）。**身份用**：`downloadId`
///              / `bookKey` 派生 / 去重全走它，永远是 raw 列值。
/// [displayTitle] 用户在 host 上改过的显示名（BUG-1488）。**只给人看**，绝不参与
///              任何键派生。null = host 没改过名 / 旧 host 不带该字段。
/// [hasContent] 存在可导出的 EPUB 根目录时为 true——表示该书可被导出。
///              无内容的书（extractDir 丢失或空）不应被 pull（与 orchestrator
///              `importRemoteBooks` 的跳过语义一致）。
class RemoteBookInfo {
  const RemoteBookInfo({
    required this.title,
    required this.hasContent,
    this.displayTitle,
    this.displayTitleAt = 0,
    this.bookKey,
    this.hasEmbeddedCover = false,
    this.coverUrl,
    this.coverPath,
    this.hasAudiobook = false,
    this.tags = const <String>[],
    this.tagsAddedAt = const <String, int>{},
    this.tagTombstones = const <String, int>{},
    this.collection,
    this.progressPercent = 0,
    this.progressUpdatedAtMs = 0,
    this.importedAt,
    this.kind = MediaKind.epub,
    this.format = 'epub',
    this.hasMangaContent = false,
    this.hasMangaChapters = false,
    this.mangaReadingMode,
    this.mangaReaderOverrides = const <String, Object?>{},
    this.mangaReaderOverrideUpdatedAt = 0,
    this.mangaReaderOverrideDeleted = false,
  });

  /// 书身份格式（`EpubBooks.format` 值域：'epub'/'pdf'/'manga'，见 [BookFormat]）。
  /// additive wire 字段 `'format'`：epub 缺省不写键（旧清单 wire 字节不变），缺失
  /// /未知回落 'epub'。与 [kind]（MediaKind 轴）正交——manga 行 kind 仍是 epub
  /// （EpubBooks 表身份），格式轴才区分漫画。
  final String format;

  /// 漫画内容可下载（format=='manga' 且 host 书目录根有 manga.json）。与
  /// [hasContent]（EPUB 内容树）**分键**是向后兼容的关键：旧 client 只认
  /// hasContent，漫画对它保持 false（完全无感知，行为与从前一致）；新 client 用
  /// 本字段在漫画架渲染远端占位卡 + 走同一 books 端点下载漫画包。
  final bool hasMangaContent;

  /// host 端这本在线漫画（Mihon / Aidoku 书架条目）有**已下载的章**可以经互联漫画源
  /// 逐章翻页（BUG-2474）。与 [hasMangaContent] 互斥的另一半：在线条目的书目录根
  /// 只有占位 `manga.json`（pages 为空），按 hasMangaContent 判永远是 false——修复前
  /// 它们因此从对端的漫画架整体消失。additive 键 `hasMangaChapters`：旧 client 不认
  /// 识就当 false（行为与从前一致），新 client 据此把它当多章在线作品加进本机书架，
  /// 章节表走 `/api/library/manga/<bookKey>/manifest` 的 `chapters`。
  final bool hasMangaChapters;

  /// host 端该漫画的按本阅读模式（`EpubBooks.mangaReadingMode`；null = 跟随自动
  /// 判定）。additive；下载落地时作为初始值带过来（无持续 LWW——列无时间戳，
  /// 后续调整各端各自记忆）。
  final String? mangaReadingMode;
  final Map<String, Object?> mangaReaderOverrides;
  final int mangaReaderOverrideUpdatedAt;
  final bool mangaReaderOverrideDeleted;

  /// 该书的媒体种类（BUG-1119）。additive wire 字段 `'kind'`：epub 缺省**不写键**
  /// （旧书清单 wire 字节完全不变），缺失/未知一律回落 [MediaKind.epub]（旧 host
  /// 兼容）。视频走独立 `/api/library/videos` 清单，天然 video，无此字段。
  final MediaKind kind;

  /// host 端阅读进度百分比（0..100，来自 host `MediaItems.position/duration`，
  /// 与本地首页「继续」条目同源同算）；0 = 未读/旧 host 未带。additive 字段：
  /// 旧 client 忽略、旧 host 不发——供新首页仪表盘把 host 在读书并进「继续」。
  final int progressPercent;

  /// host 端该书最近阅读时刻（epoch 毫秒，来自 host `reader_positions.updatedAt`）；
  /// 0 = 无记录/旧 host。仪表盘「继续」混排排序用。
  final int progressUpdatedAtMs;

  /// host 端 `EpubBooks.importedAt`（epoch 毫秒；null = 旧 host 不带该字段）。
  ///
  /// 与 [RemoteVideoInfo.importedAt] 同范式、同理由：缺了它，client 书架的远端
  /// 占位卡没有入库时刻，「导入时间」排序只能给它们造一个负数假戳去占位——于是
  /// 无论选哪种排序，远端书恒堆在本地书之后（用户实报「合集外排序不对」）。
  ///
  /// 旧 host 不带 → null → 与改动前逐字节同行为（排序回落假值）。
  final int? importedAt;

  final String title;

  /// host 端用户自定义的显示名（BUG-1488；host `preferences` 表的
  /// `override_title://` 覆盖层，写入方 `MediaSource.setOverrideTitleFromMediaItem`）。
  ///
  /// additive wire 字段 `'displayTitle'`：**只在与 [title] 不同时才写键**，所以
  /// 「没改过名」的书清单 wire 字节完全不变、旧 client 忽略、旧 host 不发。
  /// 消费恒走 [displayName]——直接读本字段的调用点在旧 host 上会拿到 null。
  ///
  /// ⚠️ 身份红线：[downloadId] / `bookKey` / 去重键一律用 [title]，本字段永不参与。
  final String? displayTitle;

  /// [displayTitle] 的最后修改毫秒戳（BUG-1502，host `preferences.updated_at`）。
  ///
  /// additive wire 字段 `'displayTitleAt'`：只在 `> 0` 且真发了 [displayTitle]
  /// 时写键。**0 = 「时刻未知」**，涵盖两种对端：不带该键的旧 host（BUG-1488 那
  /// 一代只发名字不发时刻），以及 host 上 v84 迁移前就改好、之后没再动过的存量行。
  ///
  /// 收下 0 的一方按 LWW 平局处理 → 保留本机（见 `setPrefIfNewer`），所以旧对端
  /// 永远不会覆盖本机用户刚改的名字；本机没有 override 时仍照常采纳。
  final int displayTitleAt;

  final bool hasContent;
  final String? bookKey;

  /// host 端存在**书内封面文件**（EPUB 内嵌封面解析到磁盘存在的绝对路径，见
  /// [resolveEpubCoverFilePath]）。注意与 wire key `'hasCover'` 同名不同义：wire
  /// 上写的是 [hasDisplayCover]（内嵌封面 ∨ coverUrl ∨ coverPath 任一可用），
  /// 本字段只是其中「内嵌封面」一支——故 Dart 侧改名消歧，wire key 不动。
  final bool hasEmbeddedCover;
  final String? coverUrl;
  final String? coverPath;

  /// 该书在 host 端是否已配有有声书（bookKey 出现在 Audiobooks 表）。远端书卡据此
  /// 渲染类型徽章（耳机 / 书本），与本地书卡 `_getAudiobookInfo` 同源（TODO-655a）。
  final bool hasAudiobook;

  /// 该书在 host 端的标签名列表（TODO-1165）。标签是每设备本地数据，只传
  /// 名不传本地 id；client 下载后 getOrCreateTagByName + addTagToBook 重建映射。
  final List<String> tags;

  /// tags 稳健档 LWW：标签「名→加入戳」（client mergeRemoteBookTags 用）。空 = 旧 host
  /// 未带（退化为按 [tags] 名单只增 + 尊重本地移除墓碑）。
  final Map<String, int> tagsAddedAt;

  /// tags 稳健档 LWW：标签移除墓碑「名→移除戳」（host 移除标签跨端传播、防复活）。
  final Map<String, int> tagTombstones;

  /// 该书在 host 端的主合集归属（多端库联合视图 §2.3 任务5.1；null = 散卡）。
  /// 远端占位卡据此归进对应合集行（UI 批任务 10）。
  final RemoteCollectionMembership? collection;

  String get downloadId => _isNonEmpty(bookKey) ? bookKey! : title;

  /// 该书**给人看**的名字：host 改过名用改后的，否则回落 raw [title]。
  /// 一切 UI 上屏点必须走这里（与本地书的 `displayTitleForBook` 门面对称）。
  String get displayName => _isNonEmpty(displayTitle) ? displayTitle! : title;

  bool get hasDisplayCover =>
      hasEmbeddedCover || _isNonEmpty(coverUrl) || _isNonEmpty(coverPath);

  Map<String, Object?> toJson() => <String, Object?>{
        'title': title,
        if (_isNonEmpty(displayTitle) && displayTitle != title)
          'displayTitle': displayTitle,
        if (_isNonEmpty(displayTitle) &&
            displayTitle != title &&
            displayTitleAt > 0)
          'displayTitleAt': displayTitleAt,
        if (_isNonEmpty(bookKey)) 'bookKey': bookKey,
        'hasContent': hasContent,
        if (hasDisplayCover) 'hasCover': true,
        if (_isNonEmpty(coverUrl)) 'coverUrl': coverUrl,
        if (hasAudiobook) 'hasAudiobook': true,
        if (tags.isNotEmpty) 'tags': tags,
        if (tagsAddedAt.isNotEmpty) 'tagsAddedAt': tagsAddedAt,
        if (tagTombstones.isNotEmpty) 'tagTombstones': tagTombstones,
        if (progressPercent > 0) 'progressPercent': progressPercent,
        if (progressUpdatedAtMs > 0) 'progressUpdatedAtMs': progressUpdatedAtMs,
        if (importedAt != null) 'importedAt': importedAt,
        if (kind != MediaKind.epub) 'kind': kind.dbValue,
        if (format != 'epub') 'format': format,
        if (hasMangaContent) 'hasMangaContent': true,
        if (hasMangaChapters) 'hasMangaChapters': true,
        if (_isNonEmpty(mangaReadingMode)) 'mangaReadingMode': mangaReadingMode,
        if (mangaReaderOverrides.isNotEmpty || mangaReaderOverrideDeleted)
          'mangaReaderOverrides': mangaReaderOverrides,
        if (mangaReaderOverrideUpdatedAt > 0)
          'mangaReaderOverrideUpdatedAt': mangaReaderOverrideUpdatedAt,
        if (mangaReaderOverrideDeleted) 'mangaReaderOverrideDeleted': true,
      };

}

/// host 端某本书的阅读进度（TODO-767 跨设备书籍进度同步）。
///
/// 字段照 `reader_positions` 列：[sectionIndex]/[normCharOffset]/[charOffset] 是
/// 阅读器恢复锚（[charOffset] = -1 表示无精确偏移，回退 [normCharOffset] 分数），
/// [updatedAtMs] 是该行 `updatedAt`（epoch 毫秒），跨设备冲突解决「取较新时间戳」用它
/// （见 [resolveBookProgressSync]）。[updatedAtMs] = 0 表示 host 无记录（该书从未读过）。
class RemoteBookProgress {
  const RemoteBookProgress({
    required this.sectionIndex,
    required this.normCharOffset,
    required this.charOffset,
    required this.updatedAtMs,
  });

  final int sectionIndex;
  final int normCharOffset;
  final int charOffset;
  final int updatedAtMs;

  /// host 无该书 `reader_positions` 行时的「空」进度（updatedAtMs=0）。
  static const RemoteBookProgress empty = RemoteBookProgress(
    sectionIndex: 0,
    normCharOffset: 0,
    charOffset: -1,
    updatedAtMs: 0,
  );

  Map<String, Object?> toJson() => <String, Object?>{
        'sectionIndex': sectionIndex,
        'normCharOffset': normCharOffset,
        'charOffset': charOffset,
        'updatedAtMs': updatedAtMs,
      };

}

/// 从远端书清单 [remote] 里剔除本端已存在的书（按 [localBookKeys] 去重）。
///
/// 纯函数。远端书的去重键 = `sanitizeTtuFilename(title)`（与 `EpubBooks.bookKey`
/// 派生一致，由调用方算好后传入 [keyOf]）。本端已有同 key 的书就不再在「配对设备」
/// 区重复展示（TODO-033 #6：远端与本地重复同一本书）。
List<RemoteBookInfo> dedupeRemoteBooks({
  required List<RemoteBookInfo> remote,
  required Set<String> localBookKeys,
  required String Function(String title) keyOf,
}) {
  return <RemoteBookInfo>[
    for (final RemoteBookInfo book in remote)
      if (!localBookKeys.contains(keyOf(book.title))) book,
  ];
}

// ── 视频 ──────────────────────────────────────────────────────────────────────

// ── 有声书进度（BUG-471）──────────────────────────────────────────────────────

bool _isNonEmpty(String? value) => value != null && value.isNotEmpty;

// ── Abstract service ───────────────────────────────────────────────────────
