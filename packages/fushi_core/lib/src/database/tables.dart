import 'package:drift/drift.dart';

// ── media_open_history（v80：取代 jidoujisho 血统的 media_items） ────
/// 「最近打开流」：一行 = 一个媒体条目最近一次被打开的事实。旧 media_items 把
/// 身份（uniqueKey/mediaIdentifier 双轨）、展示快照（title/author/**base64 图片
/// 进 SQLite 行**）、播放状态（position/duration）、UI 能力位（canDelete/canEdit）
/// 四种东西摊成 19 列；本表只留身份 + 时刻 + 排序/换算要用的两个进度数，其余
/// 全部收进 [snapshotJson]（重开外部媒体的必要载荷——在线漫画/网页/流媒体没有
/// 库表行可 join，title/封面/源参数只能随历史行走；库内媒体的快照只是打开当时
/// 的展示缓存，真相仍在专表）。
///
/// 主键 (mediaSource, mediaId) 与旧 uniqueKey（'$source/$id'）同构，去掉自增
/// id 与派生列。UI 能力位回归运行时按 source 推导，不再持久化。新写入不再产生
/// base64 图片（无活写入方）；v80 前遗留的 base64 随 snapshot 平移，随行被
/// trim 自然消亡。
@DataClassName('MediaOpenHistoryRow')
class MediaOpenHistory extends Table {
  /// 媒体类型 key（冻结值域 = 旧 mediaTypeIdentifier：'reader' / 'player' / …）。
  TextColumn get mediaType => text()();

  /// 媒体源 key（旧 mediaSourceIdentifier）。
  TextColumn get mediaSource => text()();

  /// 源内身份（旧 mediaIdentifier：库内 = bookKey 派生 URI，外部 = URL）。
  TextColumn get mediaId => text()();

  /// 最后打开毫秒戳（排序与 trim 的键；旧 imported_at 平移）。
  IntColumn get openedAt => integer().withDefault(const Constant(0))();

  /// 进度两数（互联 host 的百分比换算要在 SQL 面上可用，故留列不进 JSON）。
  IntColumn get position => integer().withDefault(const Constant(0))();
  IntColumn get duration => integer().withDefault(const Constant(0))();

  /// 其余展示/重开载荷（MediaItem.toJson 去掉列化字段后的 JSON）。
  TextColumn get snapshotJson => text().withDefault(const Constant('{}'))();

  @override
  Set<Column> get primaryKey => {mediaSource, mediaId};
}

// ── reader_positions ────────────────────────────────────────────────
@DataClassName('ReaderPositionRow')
class ReaderPositions extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// v82 起的书稳定身份:epub 书 = EpubBooks.uid(本机稳定,标题改名不丢位置);
  /// 非 epub 域(SRT 书等)沿用其既有稳定键。刻意无 FK——本表跨书族,孤儿防线
  /// 在应用层(host service 写入闸门 + deleteEpubBook 显式清理)。
  TextColumn get bookUid => text().unique()();
  IntColumn get sectionIndex => integer()();
  IntColumn get normCharOffset => integer()();
  // BUG-162: section 内精确绝对字符偏移（退出再进的恢复锚）。-1 = 无精确偏移
  // （恢复回退 normCharOffset 分数）。取代了原 ttuCharOffset（sync 精确缓存列，
  // 已随云同步精度退化为 normCharOffset 分数而删除，合并为单一阅读位置精确列）。
  IntColumn get charOffset => integer().withDefault(const Constant(-1))();
  IntColumn get updatedAt => integer()();
}

// ── bookmarks ─────────────────────────────────────────────────────
@DataClassName('BookmarkRow')
class Bookmarks extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// v82:= EpubBooks.uid。无 SQL FK(uid 唯一性是 partial 索引,FK 会
  /// mismatch);删书清理走 deleteEpubBook 显式级联,守卫测试兜底。
  TextColumn get bookUid => text()();
  IntColumn get sectionIndex => integer()();
  IntColumn get normCharOffset => integer()();
  TextColumn get label => text()();
  IntColumn get createdAt => integer()();
  TextColumn get bookTitle => text().nullable()();
  IntColumn get pageInChapter => integer().nullable()();
  IntColumn get totalPagesInChapter => integer().nullable()();
}

// ── reading_statistics ──────────────────────────────────────────────
@DataClassName('ReadingStatisticRow')
class ReadingStatistics extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  TextColumn get dateKey => text()();
  IntColumn get charactersRead => integer()();
  IntColumn get readingTimeMs => integer()();

  /// v60：当日读过的**页数**（漫画 / PDF 这类以页为单位的书；EPUB 恒 0）。
  ///
  /// 页数与字数是两个独立量纲，绝不互相顶替：漫画既落 OCR 字符数（与 EPUB 同口径）
  /// 又落页数，统计页两个维度分别展示。旧库迁移补 0，跨设备聚合同步的 wire 契约
  /// 不带此列（[StatBucket] 要求两端字段集一致，加字段会让新旧端互相抛错），页数
  /// 随整库备份/恢复走。
  IntColumn get pagesRead => integer().withDefault(const Constant(0))();
  IntColumn get lastStatisticModified => integer()();

  @override
  List<Set<Column>> get uniqueKeys => [
        {title, dateKey},
      ];
}

// ── reading_hourly_logs ────────────────────────────���────────────────
@DataClassName('ReadingHourlyLogRow')
class ReadingHourlyLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get dateKey => text()();
  IntColumn get hour => integer()();
  IntColumn get readingTimeMs => integer()();

  /// v67：写入面身份（`BookFormat.dbValue`：'epub' / 'pdf' / 'manga'）。此前没有
  /// 任何身份列，EPUB / PDF / 漫画同一小时的时长在写入时就被加成一行，永久分不开；
  /// 日级 `reading_statistics` 靠 title→format 反查能拆，时段表拆不开只因缺这列。
  /// `''` = v67 前的历史行（写入时信息已丢，如实标未区分）以及云同步里旧端贡献的
  /// 无法归因差额（见 aggregate_sync_service 的 deficit-lift）。
  TextColumn get format => text().withDefault(const Constant(''))();

  @override
  List<Set<Column>> get uniqueKeys => [
        {dateKey, hour, format},
      ];
}

// ── activity_events ─────────────────────────────────────────────────
/// v49（首页活动时间轴）：精确时间戳的事件流，喂新首页 [HomeDashboardPage] 的
/// Activity 面板（对齐 ReinaManager「8 小时前 · 1 session」精度）。与按天聚合的
/// [ReadingStatistics] / [VideoWatchStatistics] 互补——那些是「每天总量」，这张是
/// 「每次 session 一行」，保留精确时刻用于相对时间与按类别筛选。追加式，只增不改。
@DataClassName('ActivityEventRow')
class ActivityEvents extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// 事件语义：'read'（读完一段）/ 'watch'（看了一段视频）/ 'added'（导入了媒体）
  /// / 'game'（galgame 游玩：时长行由前台窗口计时器写，字符行由 hook 文本累计器写）。
  TextColumn get eventType => text()();

  /// 媒体种类：'book' / 'video' / 'game'。与 [eventType] 分开，未来可扩展
  /// （如 'added' 的媒体既可能是 book 也可能是 video）。
  TextColumn get mediaType => text()();

  /// 展示标题（书名 / 视频名）。
  TextColumn get title => text()();

  /// 点击活动条打开媒体用的稳定身份：书=bookKey，视频=bookUid，导入不一定有。
  TextColumn get mediaKey => text().nullable()();

  /// 冗余的按天分组键（'YYYY-MM-DD'，本地时区），避免读取端为分组再从
  /// [timestampMs] 反算。与统计表 dateKey 同源（[statDateKey]）。
  TextColumn get dateKey => text()();

  /// 精确发生时刻（epoch 毫秒），Activity 相对时间与排序的真值。
  IntColumn get timestampMs => integer()();

  /// 本次 session 时长（毫秒），read/watch 有；added 为 null。
  IntColumn get durationMs => integer().nullable()();

  /// 本次读/看的字符数（阅读=字数，视频=字幕字数），added 为 null。
  IntColumn get charsDelta => integer().nullable()();
}

// ── preferences (key-value) ─────────────────────────────���───────────
@DataClassName('PreferenceRow')
class Preferences extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  /// 该行最后一次写入的毫秒戳（v84 / BUG-1502）——**跨端 LWW 的比较键**。
  ///
  /// 绝大多数偏好是设备设置、从不跨端合并，这一列对它们只是无害的记账。它存在
  /// 是因为**有些偏好行是内容**：书的改名（`override_title://` 覆盖行，BUG-1488）
  /// 跟着书走、必须跨端合并，而 `preferences` 原先只有 key/value 两列，合并端
  /// 无从判断「谁更新」，只能退化成 insert-if-absent —— 母设备**第二次**改名
  /// 就传不到已有 override 的子设备了。
  ///
  /// **默认 0 = 「时刻未知」，是刻意的取舍**：v84 迁移不给存量行填迁移时刻。
  /// 填迁移时刻会让「谁赢」由两台设备各自的升级时间决定（后升级的一侧无条件
  /// 覆盖先升级的一侧，用户什么都没做却发生覆盖）；取 0 则存量行彼此平局，
  /// 而 LWW 的平局规则是「保留本机」——正好等于升级前的 insert-if-absent 行为，
  /// 零回归；任何一侧**真正改过一次名**之后（时刻 > 0）立刻胜出。同理，旧对端
  /// 发来的无时刻数据一律按 0 收，永远不会覆盖本机改过的名字。
  ///
  /// 写入方：[FushiDatabase.setPref] / `setPrefs` / `compareAndSetPref` 填
  /// `now`；跨端采纳走 [FushiDatabase.setPrefIfNewer]，**填对端的时刻而不是
  /// now**（填 now 会让本机永远最新，母设备的下一次改名再也传不进来）。
  IntColumn get updatedAt => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {key};
}

// ── clipboard_history ───────────────────────────────────────────────
// 桌面「剪贴板复制历史」——查词面板/瞬态浮窗的历史按钮读取。position 保存内存
// List 的顺序（tail=最新），content=去重后的复制文本，copiedAt=复制时刻毫秒戳。
// 建表由 database.dart onUpgrade v50 负责；写入走 ClipboardHistoryRepository 的
// replaceAll（delete + batch insert），无需 autoIncrement id。
// ── epub_books ─────────────────────────────────────────────────────
@DataClassName('EpubBookRow')
class EpubBooks extends Table {
  // bookKey = sanitizeTtuFilename(title): the cross-device book identity.
  TextColumn get bookKey => text()();

  /// v81（P3 Stage 1，数据层重构 2026-08）：书的**本机稳定身份**。bookKey 由
  /// 用户可见可改的标题派生（改名 = 身份变 = 十来张子表连坐改键，这正是它当
  /// 头号根因的原因）；本列是导入时生成一次、此后永不变的机器局域 uid
  /// （`book_<rowid/时刻>` 形，[generateEpubBookUid]），为后续把
  /// ReaderPositions/Bookmarks/RevealedImages/BookCustomCss 等子表键切过来
  /// （Stage 1b）与最终支持改名铺地基——v39 给视频先落 bookUid 列、v76 展示层
  /// 才收尾的同款两步走。**wire/sync/备份仍走 bookKey**（title 派生键契约冻
  /// 结），本列不进 wire；跨库合并经 bookKey 对齐后各自保留本机 uid。
  /// 唯一性由独立唯一索引保证（迁移路径 ADD COLUMN 不能带 UNIQUE）；插入时
  /// 未携带则由 [insertEpubBook] 单点自动生成，调用方零改动。
  TextColumn get uid => text().withDefault(const Constant(''))();
  TextColumn get title => text()();
  TextColumn get author => text().nullable()();
  TextColumn get coverPath => text().nullable()();
  TextColumn get epubPath => text()();
  TextColumn get extractDir => text()();
  IntColumn get chapterCount => integer()();
  TextColumn get chaptersJson => text()();
  TextColumn get tocJson => text().nullable()();
  TextColumn get sourceMetadata => text().nullable()();
  IntColumn get importedAt => integer()();

  /// v87：书的内容语言（BCP-47，如 `ja` / `zh-Hant`），决定正文用哪条字体链。
  ///
  /// 导入时从 EPUB OPF 的 `dc:language` 回填（`EpubParser` 早就解析出来了，此前
  /// 无人消费）；用户可在书籍设置里手动改，手动值压过自动值。null = 既没解析到
  /// 也没指定 → 阅读器不写 `font-family`，保持浏览器默认（不猜，见
  /// `content_font_chain.dart`）。
  TextColumn get language => text().nullable()();

  /// 书身份格式判别（PDF 阅读器 Phase 1）：`'epub'`（默认，含 EPUB / TextToEpub /
  /// 有声书配对壳）、`'pdf'`（pdfrx 渲染的真 PDF）或 `'manga'`（漫画 OCR，第三种书）。
  /// 默认 `'epub'` 让既有全部行零破坏（Never break userspace，v51 迁移 addColumn 自动
  /// 回填），书架/进度/删除按此列区分而非另建平行表。PDF 行：`format='pdf'`、
  /// `epubPath`=PDF 绝对路径、`extractDir`=占位、`chapterCount`=页数、`chaptersJson`=`'[]'`。
  TextColumn get format => text().withDefault(const Constant('epub'))();

  /// 书「读完」的时间戳（用户手动标记，或读到全书末尾自动写入）；null = 未完成。
  /// 镜像 [VideoBooks.completedAt]，书架概览「Completed」统计用。跳过后记/附录的
  /// 读者靠手动标记即可计入完成，不再受「必须读到最后一字」限制。
  DateTimeColumn get completedAt => dateTime().nullable()();

  /// v115（排行榜作品匹配）：OPF `dc:identifier` 里解析出的 ISBN，**统一存 ISBN-13**
  /// （ISBN-10 转换后存），校验位不对的一律不存。null = 包里没有合法 ISBN、或是
  /// v115 前导入且尚未回填（`backfillEpubIsbns` 只读 OPF 回填，不重新导入）。
  /// 规范化唯一口径见 `fushi_engine/epub/isbn.dart` 的 `normalizeIsbn13`。
  TextColumn get isbn => text().nullable()();

  @override
  Set<Column> get primaryKey => {bookKey};
}

// ── book_tags ──────────────────────────────────────────────────────
@DataClassName('BookTagRow')
class BookTags extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().unique()();
  IntColumn get colorValue =>
      integer().withDefault(const Constant(0xFF9E9E9E))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  IntColumn get createdAt => integer()();
}

// ── tag_assignments（v79：五张标签映射表合一） ─────────────────────
/// 标签 ↔ 宿主 的统一多对多映射，取代 v79 前的五张同形表
/// （book/srt/video/collection/galgame *_tag_mappings）。标签定义仍是共享的
/// [BookTags] 池。
///
/// 设计拍板（2026-08 数据层重构，用户令合并并重新决策差异）：
///  - **[mediaKind] + [entryKey] 逻辑外键**（仓库既定惯例，同
///    [ShelfEntries].entryKey / [MediaCollectionItems].entryKey）：epub=bookKey /
///    srt=SrtBooks.uid（v79 起弃本机自增 int id，换跨设备稳定的 uid）/
///    video=bookUid / collection=MediaCollections.id 字符串化 / game=Galgames.id。
///    宿主删除经各删除路径显式清理（不再依赖五张表各自的 DB cascade），读取期
///    过滤兜底；[tagId] 对 [BookTags] 的真 FK 保留（删标签仍 cascade）。
///  - **[addedAt] 统一都记**：记的是「何时打的标签」这一事实，写入成本为零。
///    旧决策让 game/collection 不带时钟（怕被误读成在同步），代价是把「不进
///    sync」编码进表的形状里、真要同步时只能回填 0 丢失真实时间。五个 kind
///    现在都进互联标签同步（`fushi_engine/sync/tag_sync.dart`，game 经游戏跨端
///    身份换算、collection 按合集自然键）。旧行迁移填 0（最古 add，语义同旧
///    book/video 表）。
///  - 墓碑不变：[BookTagMembershipTombstones] 本就是 (itemKey, mediaType,
///    tagName) 通用形，天然覆盖全部 kind。
@DataClassName('TagAssignmentRow')
class TagAssignments extends Table {
  /// 宿主种类：'epub' | 'srt' | 'video' | 'collection' | 'game'。
  TextColumn get mediaKind => text()();

  /// 宿主稳定身份（值域见类 doc）。
  TextColumn get entryKey => text()();

  IntColumn get tagId =>
      integer().references(BookTags, #id, onDelete: KeyAction.cascade)();

  /// 该映射被加入的毫秒戳（epub/video 域是 LWW-element-set 的 add 时钟——与
  /// [BookTagMembershipTombstones].deletedAt 比较决定 add-wins/remove-wins）。
  IntColumn get addedAt => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {mediaKind, entryKey, tagId};
}

// ── profiles ────────────────────────────────────────────────────────
@DataClassName('ProfileRow')
class Profiles extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().unique()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
}

// ── profile_settings ────────────────────────────────────────────────
@DataClassName('ProfileSettingRow')
class ProfileSettings extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get profileId =>
      integer().references(Profiles, #id, onDelete: KeyAction.cascade)();
  TextColumn get category => text()();
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  List<Set<Column>> get uniqueKeys => [
        {profileId, category, key},
      ];
}

// ── media_type_profiles ─────────────────────────────────────────────
@DataClassName('MediaTypeProfileRow')
class MediaTypeProfiles extends Table {
  TextColumn get mediaType => text()();
  IntColumn get profileId =>
      integer().references(Profiles, #id, onDelete: KeyAction.cascade)();

  @override
  Set<Column> get primaryKey => {mediaType};
}

// ── book_profiles ───────────────────────────────────────────────────
@DataClassName('BookProfileRow')
class BookProfiles extends Table {
  TextColumn get bookKey => text()();
  IntColumn get profileId =>
      integer().references(Profiles, #id, onDelete: KeyAction.cascade)();

  @override
  Set<Column> get primaryKey => {bookKey};
}

// ── language_profiles ───────────────────────────────────────────────
// 「这种内容语言用哪个 Profile」。与 [MediaTypeProfiles] 同构、同性质：都是
// Profile 的自动解析绑定，只是路由键不同（语言 vs 媒体类型）。
//
// [languageTag] 是**归一化后**的键（`normalizeLanguageBinding`：保留 language +
// script、丢 region，如 `ja` / `zh-Hant`），不是内容语言列里的原始 BCP-47 串。
// 写入与查询两侧都必须过那个函数，否则用户绑了 `ja` 而书里写 `ja-JP` 会静默
// 不生效。
@DataClassName('LanguageProfileRow')
class LanguageProfiles extends Table {
  TextColumn get languageTag => text()();
  IntColumn get profileId =>
      integer().references(Profiles, #id, onDelete: KeyAction.cascade)();

  @override
  Set<Column> get primaryKey => {languageTag};
}

// ── sync_baselines ──────────────────────────────────────────────────
// 每本书每个同步维度「上次同步成功时双方一致的版本」（共同祖先），
// 用于三方分叉检测。assetKey = sanitizeTtuFilename(book.title)（跨设备稳定）。
// （v79：video_book_tag_mappings / collection_tag_mappings 已并入
// [TagAssignments]，旧表只活在迁移阶梯的冻结 SQL 里。）

// ── series ───────────────────────────────────
// TODO-616 A 合集/系列：把多本独立书 / 多个视频条目折叠成一张「系列卡片」。
// 仿 [MediaSources] 范式（自增 id + sortOrder + createdAt int 毫秒戳）。
@DataClassName('SeriesRow')
class Series extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// 系列名（必填）。
  TextColumn get name => text()();

  /// 系列封面来源：NULL = 自动取系列内 sortOrder 最小成员封面（拍板「首卷自动」）；
  /// 非空 = 手动指定（预留，本期恒 NULL）。不存首卷 entryKey 快照——首卷随增删 / 重排
  /// 变化，渲染时纯函数推导。
  TextColumn get coverSource => text().nullable()();

  /// 系列卡片之间的排序权重（同 [MediaSources].sortOrder 范式）。
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  /// 创建时间（毫秒戳，同 [EpubBooks].importedAt int 范式）。
  IntColumn get createdAt => integer()();
}

// ── shelf_entries ───────────────────────────────
// TODO-616 B 排序 + A 归属：以 (mediaType, entryKey) 为稳定身份统管本地 + 远端条目
// 的自定义排序权重与系列归属。三大媒体表不加 seriesId/sortOrder 列（避免双真相源）；
// 远端-only 条目无本地 row 可挂列，故用独立映射表。
@DataClassName('ShelfEntryRow')
class ShelfEntries extends Table {
  /// 媒体种类：'epub' | 'srt' | 'video'（'game' 不写本表——游戏库排序走
  /// `galgame_library_query.dart` 的视图偏好，合集归属见 [MediaCollectionItems]）。
  TextColumn get mediaType => text()();

  /// 条目稳定身份（v83 起 epub 域 = epub_books.uid,导入时刻定死、改标题不再
  /// 漂移,旧的下载后改键迁移已删）：本地 = epubUid / srtUid / videoBookUid；
  /// 远端 = 对端 bookKey（照抄透传,本地无行）/ video.id。**逻辑外键**（不对
  /// 本地三表加 FK：远端 entryKey 无本地表行，写 FK 会在插远端归属时违反
  /// 约束）。孤儿由删除路径主动清理 + 读取期过滤兜底。
  TextColumn get entryKey => text()();

  /// 自定义排序权重（拖拽回写）。无行的旧条目退化为 importedAt 倒序（向后兼容）。
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  /// 归属系列（NULL = 散书）。onDelete:setNull：移除系列时
  /// 成员归 NULL（散回书架），不连坐删条目。
  IntColumn get seriesId => integer()
      .nullable()
      .references(Series, #id, onDelete: KeyAction.setNull)();

  /// 复合主键：一条目一行。
  @override
  Set<Column> get primaryKey => {mediaType, entryKey};
}

// ── media_collections (统一合集：Jellyfin BoxSet/Playlist 式容器) ──────
// 取代旧 [Series] + [ShelfEntries.seriesId]（两者自 v38 起冻结为遗留残留，勿再读写
// 系列语义；[ShelfEntries.sortOrder] 书架排序职责保留）。collection = 无序跨媒体合集
// （展示时按成员 sortIndex → importedAt 排序）；playlist = 有序播放列表（sortIndex 即
// 播放序，点任一成员从该处连播）。删容器 cascade 只删成员引用 [MediaCollectionItems]，
// 绝不删条目本身（Jellyfin「删 BoxSet 不删 LinkedChild」语义）。
@DataClassName('MediaCollectionRow')
class MediaCollections extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// 目录自动合集的本机目录身份（schema v98）；NULL 表示非目录自动合集。
  /// 与来源根一样属于用户外部路径，不跨端同步，不据合集名称推断归属。
  TextColumn get sourceFolderPath => text().nullable()();

  /// 合集名（必填）。
  TextColumn get name => text()();

  /// 'collection' | 'playlist'。
  TextColumn get collectionType =>
      text().withDefault(const Constant('collection'))();

  /// 自定义封面成员 `'<mediaType>|<entryKey>'`；NULL = 自动（playlist 取前 4 成员封面
  /// 2×2 拼贴；collection 取首成员封面堆叠）。不存快照——成员增删/重排后渲染时纯函数推导。
  TextColumn get coverSource => text().nullable()();

  /// **合集自己的**封面图绝对路径（schema v61，BUG-1211）。与 [coverSource] 正交：
  /// 后者是「借哪个成员的封面」，本列是「合集自有一张图」，落在
  /// `<documents>/video_covers/collections/<id>.jpg`（[AppPaths.videoCoversDirectory]
  /// 的子目录 —— 与成员封面同池不同目录，文件名不可能与 `videoCoverFileName(bookUid)`
  /// 撞车）。
  ///
  /// 存在的理由：合集卡封面原先只能「遍历成员借第一张」，于是「给合集换封面」被迫
  /// 退化成「把同一张封面写进每一集」；用户明确否决该语义（BUG-1211：「匹配的是合集
  /// 的封面，谁说应用到本机里面的视频了」）。有了自有列，换合集封面就是改这一列，
  /// 一个成员都不动。
  ///
  /// 无损迁移：nullable 无 default → 旧库既有行全 NULL；渲染端 NULL 时**继续**走原来
  /// 的成员借用链（首个有本地封面的成员 → 远端成员 → 占位），老合集封面逐像素不变
  /// （Never break userspace）。
  ///
  /// 机器本地绝对路径：随数据根迁移改写（`data_root_migrator.dart`，与
  /// [VideoBooks].coverPath / [Galgames].coverPath 同型），且**不跨端同步**。
  TextColumn get coverPath => text().nullable()();

  /// 合集卡自身在库网格中的排序权重（与散条目同层混排，语义同旧 [Series.sortOrder]）。
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  /// 创建时间（毫秒戳，同 [EpubBooks].importedAt int 范式）。
  IntColumn get createdAt => integer()();

  /// 合集内手动序（成员 sortIndex）最后一次人为改动的毫秒戳（schema v40，多端库
  /// 联合视图 §2.3）。仅 [FushiDatabase.reorderCollectionItems]（用户拖拽落盘）
  /// bump 为 now；同步应用对端顺序时**镜像对端时间戳而非 now**（否则同步会伪装成
  /// 更新的人为改序，两端时间戳互相追赶）。跨端手动序整合集 LWW 的比较键：新者
  /// 整表覆盖成员 sortIndex。默认 0 = 从未手动排序，任何真实改序都能盖过它。
  IntColumn get orderUpdatedAt => integer().withDefault(const Constant(0))();
}

// ── media_collection_items (合集成员引用 = Jellyfin LinkedChildren) ────
// 复合主键 (collectionId, mediaType, entryKey) 按合集去重：**同一条目可属于多个
// 合集**；删合集 cascade 只删本表引用行。entryKey 是逻辑外键（epub=bookKey / srt=uid /
// video=bookUid / game=galgames.id），不加本地媒体表 DB FK——与 [ShelfEntries].entryKey
// 同理由（远端条目无本地行，写 FK 会违反约束）。孤儿由删除路径主动清理 + 读取期过滤兜底。
@DataClassName('MediaCollectionItemRow')
class MediaCollectionItems extends Table {
  /// 所属合集（[MediaCollections].id）。onDelete:cascade = 删合集连带删本引用行。
  IntColumn get collectionId => integer()
      .references(MediaCollections, #id, onDelete: KeyAction.cascade)();

  /// 媒体种类：'epub' | 'srt' | 'video' | 'game'（前三者同 [ShelfEntries].mediaType
  /// 值域；'game' 仅存在于本表——游戏库无书架排序行）。自由 TextColumn，无 CHECK。
  TextColumn get mediaType => text()();

  /// 条目稳定身份：epub=bookKey / srt=uid / video=bookUid / game=galgames.id
  /// （game 的 id 是添加时刻微秒时间戳字符串，**本机局域身份**：跨端同步时经
  /// `GameIdentityIndex` 换成外部 id / exe 路径 / 标题等跨端身份，对端解析不到
  /// 本机游戏则透传保存、静默不渲染）。
  TextColumn get entryKey => text()();

  /// 合集内序：playlist 的播放顺序 / collection 的展示顺序。
  IntColumn get sortIndex => integer().withDefault(const Constant(0))();

  /// 复合主键：同一合集内一条目一行（允许跨合集重复）。
  @override
  Set<Column> get primaryKey => {collectionId, mediaType, entryKey};
}

// ── collection_member_tombstones (合集成员移出/合集删除墓碑) ──────────
// schema v40（多端库联合视图 §2.3）：合集是跨端并集同步（成员 UNION），没有墓碑则
// A 端移出的成员会被 B 端并集复活——与书删除墓碑（[BookTombstones]）同一律。键用
// 合集**自然键 (collectionName, collectionType)** 而非自增 collection_id：两端 id
// 必冲突且无跨端意义（同 backup_merge_engine 的自然键对齐语义），且墓碑必须在
// 合集行被删（移空自删/显式删除）后继续存活。
//
// 两种行共用一张表（spec §2.3「合集级墓碑用同表哨兵」）：
//  - 成员移出墓碑：mediaType/entryKey = 真实成员键，deletedAt = 移出毫秒戳；
//  - 合集删除墓碑：mediaType = entryKey = ''（空哨兵，真实成员键恒非空，无歧义），
//    deletedAt = 删除毫秒戳。
//
// 主键不含 deletedAt（spec 原文把该时间戳列进复合键，但同一成员保留多条移出
// 事件对「防复活 + 重加清墓碑」毫无增益——同步只比较最新一条，重加要清的也是全部；
// 范式仿 [BookTombstones] 单行 LWW：重复移出 upsert 刷新 deletedAt）。
// v57 前列名 removed_at；v57 统一为 deleted_at（与 [BookTombstones] 等墓碑表对齐；
// sync 清单 wire JSON 的 `removedAt` 键是冻结的 wire 契约，与本列名解耦）。
// 重新加入清同键墓碑（[FushiDatabase.addToCollection]）；重建同名合集清合集级
// 墓碑（[FushiDatabase.createMediaCollection]），同插书清书墓碑一律。
// ── fushi_paired_peers ─────────────────────────────
// TODO-1017 阶段1：互联（Fushi server 局域网配对）的 per-peer 授权凭据表。每个
// 已配对设备一行，token 是该设备访问本机 Fushi server 的长期凭据。范式仿
// [MediaSources]（自增 id + text().unique() 身份列 + int 毫秒戳时间列）。
// SQL 表名走 drift 默认 snake_case（fushi_paired_peers）；旧名 hibiki_paired_peers
// 由 v69 迁移一次性 ALTER TABLE RENAME（终局清算：运行时/持久化零旧名，旧名只
// 允许活在迁移步里）。
// ── book_tombstones ─────────────────────────────────────────────────
// TODO-1195 part B：已删书墓碑。用户从书架删除一本书时记一条 book_key（+删除时刻），
// 供备份「合并导入」跳过——避免把用户已删的书从旧备份里复活（reported bug：导入备份出现
// 不该有的书）。重新导入/新增同 book_key 的书会清除其墓碑（见 [insertEpubBook]）。仅
// 合并导入消费；覆盖导入是整库替换（用户明确选择用备份替换），故不看墓碑（Never break
// userspace：覆盖语义不变）。范式仿 [BookProfiles]（text book_key 主键 + int 毫秒戳）。
// ── statistics_tombstones ───────────────────────────────────────────
// TODO-1204 后续：per-book/video 统计删除墓碑。用户在统计页长按某本书/视频那一行
// 确认「删除该项统计」时，记一条 (title, sourceType) 墓碑（+删除时刻）。统计聚合表
// （reading_statistics / video_watch_statistics / lookup_mining_counters）都按
// title 聚合、跨设备/备份走 MAX-union 只增不减，若只本地删行、下次云同步 / 备份合并
// 会把 peer 快照里的旧数字加回来（复活）。墓碑让 aggregate_sync 的
// applySnapshotToLocal 与 backup_merge_engine 的 MAX-union INSERT 跳过被删的
// (title, sourceType)，删掉的书统计不复活。用户又读该书 / 查词（addReadingStatistic
// / addVideoWatchStatistic / addLookupCount / addMineCountPerBook 新建当日行）会清
// 除其墓碑，让该书统计重新生效（范式仿 [BookTombstones] 的插书清墓碑）。sourceType
// 与统计来源同值（'book' | 'video'）——同名书与视频各自独立立碑 / 清碑。
// ── book_tag_membership_tombstones ──────────────────────────────────
// tags 稳健档跨端同步（LWW-element-set）：用户从一本书/视频移除某标签时记一条
// (itemKey, mediaType, tagName) 墓碑（+移除时刻 deletedAt）。sync 合并按名把两端
// 当前标签并集，再用「该标签的最大 addedAt vs 最大 deletedAt」逐名裁决 add-wins/
// remove-wins——避免「A 移除标签 → B 没移除 → B 下轮把标签又并回 A」的复活，也避免
// 误删并发新增。重新给同一 (itemKey, tagName) 加标签会清除其墓碑（[addTagToBook]/
// [addTagToVideoBook]/[setTagsForBook]/[setTagsForVideoBook] 内清碑），让重加生效。
// 范式仿 [CollectionMemberTombstones]（自然键 + 单行 LWW deletedAt，重加清碑）。
// v57 前列名 removed_at；v57 统一为 deleted_at（与其余墓碑表对齐）。
// ── book_custom_css ─────────────────────────────────────────────────
// per-book 自定义 CSS 跨端同步的时间戳载体。磁盘真相源是 extractDir 里被改写的 .css
// 文件（+ `.original` 备份，见 BookCssRepository），但磁盘无跨设备可比较的版本；本表按
// (bookKey, relativePath) 记录用户自定义的 CSS 文本 + updatedAt，让 sync 走 LWW（按
// updatedAt 取较新，整块文本不能并集）。[deleted]=true 表「已重置回原始」的墓碑（updatedAt
// 记重置时刻），使「reset」也能跨端传播（否则删行无法与「从未自定义」区分）。空表 =
// 从未自定义 = sync 零命中（Never break userspace）。范式仿 [BookProfiles]（text 复合键 +
// int 毫秒戳）。
@DataClassName('BookCustomCssRow')
class BookCustomCss extends Table {
  /// 书稳定身份（v82 起 = EpubBooks.uid，本机稳定；跨设备/备份合并经
  /// epub_books 双侧 JOIN 换键）。删书清理走 deleteEpubBook 显式级联。
  TextColumn get bookUid => text()();

  /// 书内 CSS 文件相对路径（extractDir 内，正斜杠归一，同 [CssFileEntry].relativePath）。
  TextColumn get relativePath => text()();

  /// 用户自定义的 CSS 全文（[deleted]=true 时无意义，留空）。
  TextColumn get content => text().withDefault(const Constant(''))();

  /// true = 已重置回原始（重置墓碑）；false = 有自定义内容。
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();

  /// 最后修改毫秒戳（LWW 比较键；保存/重置都刷新）。
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {bookUid, relativePath};
}

// ── revealed_images ─────────────────────────────────────────────────
// 图片防剧透遮罩「已揭开」状态的持久真相源。per-(bookKey, imageKey)：imageKey =
// extractDir 相对、解码、正斜杠归一的图片路径（如 `OEBPS/images/foo.jpg`）。阅读器
// WebView（JS __fushiImageRevealKey）与图片库 IllustrationsViewerPage（File 相对路径）
// 都归一到这同一个 key，实现「书内揭开↔图片库揭开」双向同步（同一张图只存一行）。
// 揭开即 insertOnConflictUpdate 一行（幂等）；空表 = 全部保持遮罩（旧库升级后行为与旧版
// 完全一致，Never break userspace）。删书经 EpubBooks FK cascade 连带清本表。范式仿
// [BookCustomCss]（text 复合键 + int 毫秒戳，为将来 sync/backup 留 LWW 口）。
@DataClassName('RevealedImageRow')
class RevealedImages extends Table {
  /// 书稳定身份（v82 起 = EpubBooks.uid）。无 SQL FK（uid 唯一性是 partial
  /// 索引），删书清理走 deleteEpubBook 显式级联，守卫测试兜底。
  TextColumn get bookUid => text()();

  /// 图片稳定 key（extractDir 相对、解码、正斜杠路径，如 `OEBPS/images/foo.jpg`）。
  TextColumn get imageKey => text()();

  /// 揭开毫秒戳（LWW 比较键；备份合并取较新）。
  IntColumn get revealedAt => integer()();

  @override
  Set<Column> get primaryKey => {bookUid, imageKey};
}

// ── study_segments ──────────────────────────────────────────────────
/// v92（统计域根本性重构）：学习时长 / 字数 / 页数的**唯一事实表**。
///
/// 此前同一段学习被并行写进 `reading_statistics` / `video_watch_statistics`（日聚合）、
/// `reading_hourly_logs` / `video_hourly_logs`（小时桶）、`activity_events`（session
/// 行）三种投影，全部 `+=` 累加、无任何幂等键——任何写入路径 flush 两次（dispose 与
/// 进程退出并发、生命周期抖动、hot restart）日汇总就永久翻倍，且身份用 title
/// （同名书 / 裸集号 `S01E01` 跨作品互串）。本表照 [GalgameSessions] 的模式重做：
/// 一段一行、按稳定媒体身份键控、**绝对值 upsert**。
///
/// 写法只有一种：[FushiDatabase.upsertStudySegment] —— `INSERT ... ON CONFLICT(uid)
/// DO UPDATE` 写**绝对值**。写入方持有自己当前打开段的内存累计器，每个 tick 把绝对值
/// 写回同一 [uid]；重复 flush = 同值覆盖 = no-op，重复计数在数据结构上不可能。
///
/// 段不跨本地小时边界（写入方在边界换新 uid），故 [dateKey] / [hour] 精确，小时图与
/// 日总量从同一批行派生、永不打架。一个 3 小时 session ≈ 3~4 行，年级数据千行量级，
/// 读取端直接 GROUP BY。
///
/// 旧四张投影表**冻结为 legacy**：v92 起本地写入面永不再写（守卫测试钉死），读取侧
/// 把 legacy 行（v92 前日期）与本表并集（时间上不相交，零合成零双计）。不迁移旧数据：
/// 日汇总行没 hour、小时行没 title，任何合成都得丢一维或双计。
@DataClassName('StudySegmentRow')
class StudySegments extends Table {
  /// 写入方生成的幂等键（32 位 hex，见 [FushiDatabase.newStudySegmentUid]）。
  TextColumn get uid => text()();

  /// 产生本段的设备（`sync_device_id` 偏好，见 [FushiDatabase.getOrCreateStudyDeviceId]）。
  /// 同步 v2 按 (uid) 并集时它是 provenance，不进任何合并判据。
  TextColumn get deviceId => text()();

  /// 'book' | 'video' | 'game'（[ActivityMediaKind.dbValue] 同值域）。
  TextColumn get mediaKind => text()();

  /// 稳定媒体身份：书=bookKey，视频=bookUid，游戏=galgames.id。**永不用 title**。
  TextColumn get mediaKey => text()();

  /// 写入面：'epub' | 'pdf' | 'manga'（[BookFormat.dbValue]），非书面 ''。
  TextColumn get format => text().withDefault(const Constant(''))();

  /// 展示快照：库表 join 不到（媒体已删）时回退显示，不参与任何分组。
  TextColumn get title => text()();

  /// 段起始 / 结束毫秒戳。[endAt] 随 tick 前进；`endAt - startAt >= durationMs`。
  IntColumn get startAt => integer()();
  IntColumn get endAt => integer()();

  /// [startAt] 的本地 `yyyy-MM-dd` 与小时（段不跨小时边界，故两者精确）。
  TextColumn get dateKey => text()();
  IntColumn get hour => integer()();

  /// 活跃时长（毫秒，已过前台 / 播放态 / 空闲 / 断档守卫）。
  IntColumn get durationMs => integer().withDefault(const Constant(0))();

  /// 字数（书 / 漫画 OCR = 实义字符；视频 = 字幕字符；游戏 = hook 文本）。
  IntColumn get chars => integer().withDefault(const Constant(0))();

  /// 页数（漫画 / PDF；EPUB 恒 0）。
  IntColumn get pages => integer().withDefault(const Constant(0))();

  /// 最后写入毫秒戳：同步 v2 同 uid 取大者（LWW），墓碑仲裁用它与 deletedAt 比。
  IntColumn get updatedAt => integer()();

  /// v105（统计按 Profile 隔离）：开段时激活的 Profile（`profiles.id`）。
  ///
  /// 分区键：读取面（`loadStatFacts` / 最近观看 / 删除 / 清空）一律只看当前激活
  /// Profile 的行，各 Profile 之间互不可见。**只在插入时盖戳、冲突更新不改**——
  /// 段的归属在它开始那一刻就定了，中途切 Profile 不把已开的段挪走（下一段自然
  /// 归新 Profile）。写入方（StudyClock / galgame hook）不用知道 Profile：缺席时
  /// DAO 从 `active_profile_id` 偏好解析（[FushiDatabase.resolveActiveProfileId]）。
  /// 0 = 库里还没有 Profile（只在纯 DB 测试里出现；app 启动即 ensureDefaultProfile）。
  ///
  /// 不做 FK：删 Profile 不 cascade 删历史（同步对端可能还持有这些段，本机静默
  /// 消失又回灌是最坏形态），行留着、对任何 Profile 都不可见即可。同步 wire 不
  /// 传本机自增 id，传 Profile **名字**（`profileName`），对端按名字落到自己的
  /// 同名 Profile。
  IntColumn get profileId => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {uid};
}

// ── study_segment_tombstones ────────────────────────────────────────
/// v92：按**媒体身份**的统计删除墓碑，取代按 (title, sourceType) 的
/// [StatisticsTombstones]（那张只为 legacy 表的 title 粒度 wire 服务，冻结）。
///
/// 删某媒体统计 = 删其全部 [StudySegments] + 立本碑。仲裁（BUG-2214 / BUG-2220）：
/// 段 `startAt < deletedAt` → 被压制（同步 / 备份里的旧段不复活）；`startAt >= deletedAt`
/// 的段（删后又读）照常存活。**碑永不退场**、时间戳只增不减——旧口径「段
/// `updatedAt > deletedAt` 则段胜」已废：同步回写会刷新 `updatedAt`，让删掉的旧段
/// 借道复活。真实实现见 `database_statistics.part.dart` 的 `_isStudySegmentTombstoned`
/// 与 `aggregate_merge_service.dart`。
///
/// 自 v105 起碑也按 Profile 分区（主键加 [profileId]，重建表）——A Profile 删某书
/// 统计，不能把 B Profile 同一本书的历史一起压死；同步落地时只压制**同 Profile**
/// 的段。
@DataClassName('StudySegmentTombstoneRow')
class StudySegmentTombstones extends Table {
  /// 立碑时的 Profile（`profiles.id`），语义同 [StudySegments.profileId]。
  IntColumn get profileId => integer().withDefault(const Constant(0))();
  TextColumn get mediaKind => text()();
  TextColumn get mediaKey => text()();
  IntColumn get deletedAt => integer()();

  @override
  Set<Column> get primaryKey => {profileId, mediaKind, mediaKey};
}

// （v79：galgame_tag_mappings 已并入 [TagAssignments]。与游戏**元数据标签**
// （bgm/vndb 刮削字符串，存 [GalgameSources].dataJson + [Galgames].customDataJson）
// 仍是两条正交轴，刻意不合并：元数据标签是外部事实、动辄上百个且随刮削变动，
// 塞进用户标签池会污染书/视频共享的那份手工标签。游戏用户标签经互联标签同步
// 跨端（游戏跨端身份见 fushi_engine 的 GameIdentityIndex）；
// 备份合并导入自 `BackupCategory.games` 起经游戏身份映射（同 id / 刮削身份 /
// exe 路径）落到本机游戏行上，见 backup_merge_engine.dart 的 `_buildGameIdMap`。）
