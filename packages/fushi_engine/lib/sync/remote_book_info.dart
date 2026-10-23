import 'package:fushi_core/fushi_core.dart';

// Wire DTOs for a remote (Kitapsen store) book shown on the shelf.

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
    this.coverUrl,
    this.coverPath,
    this.tags = const <String>[],
    this.progressPercent = 0,
    this.progressUpdatedAtMs = 0,
    this.importedAt,
    this.format = 'epub',
  });

  /// 书身份格式（`EpubBooks.format` 值域：'epub'/'pdf'，见 [BookFormat]）。
  final String format;

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

  final String? coverUrl;
  final String? coverPath;

  /// 该书在 host 端的标签名列表（TODO-1165）。标签是每设备本地数据，只传
  /// 名不传本地 id；client 下载后 getOrCreateTagByName + addTagToBook 重建映射。
  final List<String> tags;

  String get downloadId => _isNonEmpty(bookKey) ? bookKey! : title;

  /// 该书**给人看**的名字：host 改过名用改后的，否则回落 raw [title]。
  /// 一切 UI 上屏点必须走这里（与本地书的 `displayTitleForBook` 门面对称）。
  String get displayName => _isNonEmpty(displayTitle) ? displayTitle! : title;

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
