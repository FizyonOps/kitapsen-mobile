import 'package:fushi_engine/stats/study_sessions.dart';
import 'package:fushi_core/fushi_core.dart';
// 引擎只准 import 纯 Dart 子 barrel（全 barrel 会导出 just_audio 等插件，
// 把 Flutter 拖进无头服务端的 AOT 编译）。
import 'package:fushi_reading/fushi_reading.dart';

/// 一条学习统计事实的统一形状（v92 统计域重构）。
///
/// 读取侧只认这一种行：`study_segments`（v92 起唯一写入面）与两张 legacy 投影表
/// （`reading_statistics` / `reading_hourly_logs`，v92 前的历史数据、冻结不再写）
/// 都映射到它。页面 / 首页 / 活动流不再各自读表、各自累加。
///
/// 身份：[mediaKey] = 书 bookKey；legacy 行里没有身份的（按 title 反查库表失败）为 ''，
/// 读取端按 [title] 回退分组（沿用 v76 的 [groupStatRowsByIdentity] 契约）。
class StatFact {
  const StatFact({
    required this.mediaKind,
    required this.mediaKey,
    required this.title,
    required this.format,
    required this.dateKey,
    required this.hour,
    required this.ms,
    required this.chars,
    required this.pages,
  });

  /// 'book' | 'video' | 'game'（[ActivityMediaKind.dbValue]）。
  final String mediaKind;

  /// 稳定媒体身份；'' = legacy 无身份行。
  final String mediaKey;

  /// 展示快照 / 无身份行的回退分组键。
  final String title;

  /// 'epub' | 'pdf' | 'manga' | ''（非书面或 legacy 未区分）。
  final String format;

  final String dateKey;

  /// 本地小时；日面事实（legacy 日行）为 -1。
  final int hour;

  final int ms;
  final int chars;
  final int pages;

  bool get isBook => mediaKind == kActivityMediaBook;

}

/// 收藏句计数事实（学习事实面之外的**计数面**）。
///
/// 与 [StatFact] 严格分列：收藏句没有时长 / 字数 / 页数，混进日面就会被所有按
/// ms / chars 求和的消费方当成零行，还会污染排行与热力图。只按 dateKey 分桶
/// （`bucketActivityByDateKey`）。
class StatCounterFacts {
  const StatCounterFacts({
    this.favoriteSentences = const <FavoriteSentence>[],
  });

  static const StatCounterFacts empty = StatCounterFacts();

  /// 收藏句（`FavoriteSentenceRepository`，偏好里的 JSON 列表）。
  final List<FavoriteSentence> favoriteSentences;

  /// 收藏句事件流。[source] 为 null = 全取；阅读域取视频 / 游戏以外的全部
  /// （与阅读统计页历史判据一致）。
  ///
  /// BUG-893：dateKey 缺失（写入端补 dateKey 之前的老条目）回退按 createdAt 归日，
  /// 否则老收藏全被滤掉、统计恒 0。
  Iterable<(String, int)> favoriteSentenceEvents({StatSourceKind? source}) =>
      favoriteSentences.map((FavoriteSentence s) => (
                s.dateKey ?? FushiDatabase.statDateKeyOf(s.createdAt),
                1,
              ));
}

/// 库表按 title 分桶（BUG-2216：legacy 阅读行只有 title，反查库表补身份时同名
/// ≥2 本不能贴给任意一本——宁可留成无身份组也不错贴）。
Map<String, List<EpubBookMeta>> _booksByTitle(Iterable<EpubBookMeta> rows) {
  final Map<String, List<EpubBookMeta>> out = <String, List<EpubBookMeta>>{};
  for (final EpubBookMeta r in rows) {
    out.putIfAbsent(r.title, () => <EpubBookMeta>[]).add(r);
  }
  return out;
}

/// title → bookKey 的**唯一**反查表：库里恰好一本叫这个名字才进表。页面给 legacy
/// 无身份行 / 无身份 tile 反查 bookKey（合集归属、override 书名、删除）都只许用它。
Map<String, String> uniqueBookKeyByTitle(Iterable<EpubBookMeta> rows) =>
    <String, String>{
      for (final MapEntry<String, List<EpubBookMeta>> e
          in _booksByTitle(rows).entries)
        if (e.value.length == 1) e.key: e.value.single.bookKey,
    };

/// 库里同名 ≥2 本的 title 集合：喂 `groupStatFactsByIdentity` 的吸收否决（库表判
/// 同名时，legacy 无身份行不许吸进任何身份组）。
Set<String> ambiguousBookTitles(Iterable<EpubBookMeta> rows) => <String>{
      for (final MapEntry<String, List<EpubBookMeta>> e
          in _booksByTitle(rows).entries)
        if (e.value.length >= 2) e.key,
    };

/// 一次加载得到的全部统计事实，分**两面**：
///  * [daily]：日总量 / per-media / 热力图 / 趋势用——legacy 日汇总行 + 全部段；
///  * [hourly]：今日按小时图用——legacy 小时行 + 全部段。
///
/// 同一个段在两面各出现一次；legacy 的日行与小时行是同一段时间的两个**不相交**投影
/// （一个有 title 没 hour，一个有 hour 没 title），所以绝不能并进同一列表求和——
/// 两面分列，读方按用途只挑一面，结构上杜绝双计。
/// 某条阅读域事实是否属于这本书：有身份看 mediaKey，legacy 无身份行按 title 回退
/// （与阅读统计页按书分组同一规则）。唯一判据，别在页面里再拼一遍。
bool statFactBelongsToBook(
  StatFact f, {
  required String bookKey,
  String? title,
}) {
  if (f.mediaKey.isNotEmpty) return f.mediaKey == bookKey;
  return title != null && title.isNotEmpty && f.title == title;
}

class StatFacts {
  const StatFacts({
    required this.daily,
    required this.hourly,
    required this.segments,
    required this.legacyActivity,
    required this.epubRows,
    this.counters = StatCounterFacts.empty,
    this.activityLimit = 200,
  });

  static const StatFacts empty = StatFacts(
    daily: <StatFact>[],
    hourly: <StatFact>[],
    segments: <StudySegmentRow>[],
    legacyActivity: <ActivityEventRow>[],
    epubRows: <EpubBookMeta>[],
  );

  /// 收藏计数面（只在 `loadStatFacts(includeCounters: true)` 时装载，否则是
  /// [StatCounterFacts.empty]——首页时间轴不需要）。
  final StatCounterFacts counters;

  /// [activityRows] 的条数上限（与 legacy 行的取数上限同值）。
  final int activityLimit;

  /// **活动流的唯一数据源**：legacy 活动行 ∪ 段合成行，按精确时刻倒序、截到
  /// [activityLimit]。首页时间轴只吃它。
  List<ActivityEventRow> get activityRows {
    final List<ActivityEventRow> all = <ActivityEventRow>[
      ...legacyActivity,
      ...segmentsAsActivityRows(segments),
    ]..sort(
        (ActivityEventRow a, ActivityEventRow b) =>
            b.timestampMs.compareTo(a.timestampMs),
      );
    return all.length <= activityLimit ? all : all.sublist(0, activityLimit);
  }

  /// **会话流的唯一数据源**（统计中心 + 按媒体的会话列表都吃它）：段按
  /// [kStudySessionGap] 归并，按结束时刻倒序；写零的段不进。
  List<StudySession> get sessions => deriveStudySessions(segments: segments);

  final List<StatFact> daily;
  final List<StatFact> hourly;

  /// 原始段（活动流的 session 归并需要 startAt / endAt）。
  final List<StudySegmentRow> segments;

  /// legacy `activity_events` 行（v92 前的学习行 + 至今仍在写的
  /// `added` 导入事件）。活动流把它与 [segmentsAsActivityRows] 并集。
  final List<ActivityEventRow> legacyActivity;

  /// 加载 legacy 阅读行身份时顺带取的书表瘦投影（页面复用：title→bookKey /
  /// uid / importedAt / format），不带章节 JSON 大列。
  final List<EpubBookMeta> epubRows;

  Iterable<StatFact> get dailyBooks => daily.where((StatFact f) => f.isBook);
}

/// 从 DB 加载统一事实面（**唯一**读取入口；统计页与首页都走它）。
///
/// [activityLimit] 是 legacy 活动行的条数上限（首页时间轴只看最近 200 条）；统计页
/// 不需要活动行可传 0。
///
/// legacy 活动行里属于「学习统计」的事件类型（v92 前的 read / watch / game 行）：
/// v105 起只对 legacy 归属 Profile 露出；其余类型（`added` 导入事件）是库事件，
/// 库不按 Profile 分，对谁都露出。
const Set<String> kLegacyStudyActivityTypes = <String>{kActivityRead};

/// v105（统计按 Profile 隔离）：只装载 [profileId]（null = 当前激活 Profile）的
/// 事实。v92 段按 `profile_id` 列过滤；legacy 两表 + legacy 活动行没有
/// Profile 维度，只在 [profileId] 是 legacy 归属 Profile
/// （[FushiDatabase.getStatLegacyProfileId]，无归属 = 所有人）时装载，否则整批为空。
Future<StatFacts> loadStatFacts(
  FushiDatabase db, {
  int activityLimit = 200,
  bool includeCounters = false,
  int? profileId,
}) async {
  final int scope = profileId ?? await db.resolveActiveProfileId();
  final bool legacyVisible = await db.legacyStatsVisibleTo(scope);
  // 全表读互不依赖（[includeCounters] 时再挂计数面）：一次全部发出去让 Drift 后台
  // 执行器流水线化，而不是每个都等上一个往返回来。先 Future.wait 挂上监听，某个
  // 失败时其余错误不会成为无人接的未处理异常。
  final Future<List<EpubBookMeta>> epubRowsF = db.getEpubBookMetas();
  final Future<List<ReadingStatisticRow>> readingF = legacyVisible
      ? db.getAllReadingStatistics()
      : Future<List<ReadingStatisticRow>>.value(<ReadingStatisticRow>[]);
  final Future<List<ReadingHourlyLogRow>> readingHourlyF = legacyVisible
      ? db.getAllReadingHourlyLogs()
      : Future<List<ReadingHourlyLogRow>>.value(<ReadingHourlyLogRow>[]);
  final Future<List<ActivityEventRow>> activityF =
      db.getRecentActivityEvents(limit: activityLimit);
  final Future<List<StudySegmentRow>> segmentsF =
      db.getStudySegments(profileId: scope);
  final Future<StatCounterFacts> countersF = includeCounters
      ? _loadCounterFacts(db)
      : Future<StatCounterFacts>.value(StatCounterFacts.empty);
  await Future.wait<Object?>(<Future<Object?>>[
    epubRowsF,
    readingF,
    readingHourlyF,
    activityF,
    segmentsF,
    countersF,
  ]);

  final List<EpubBookMeta> epubRows = await epubRowsF;
  // BUG-2216：同名 ≥2 本时不反查（后者覆盖前者 = 把一本书的历史错贴给另一本）。
  final Map<String, EpubBookMeta> bookByTitle = <String, EpubBookMeta>{
    for (final MapEntry<String, List<EpubBookMeta>> e
        in _booksByTitle(epubRows).entries)
      if (e.value.length == 1) e.key: e.value.single,
  };
  final List<StatFact> daily = <StatFact>[];
  final List<StatFact> hourly = <StatFact>[];

  // legacy 日行：阅读按 title 反查库表补身份与 format（查不到 = 书已删或同名歧义，
  // 身份 ''、format ''，读取端按 unique-title 吸收 / 无身份分组）。
  for (final ReadingStatisticRow r in await readingF) {
    final EpubBookMeta? book = bookByTitle[r.title];
    daily.add(
      StatFact(
        mediaKind: kActivityMediaBook,
        mediaKey: book?.bookKey ?? '',
        title: r.title,
        format: book?.format ?? '',
        dateKey: r.dateKey,
        hour: -1,
        ms: r.readingTimeMs,
        chars: r.charactersRead,
        pages: r.pagesRead,
      ),
    );
  }
  // legacy 小时行（无身份、无 title）。
  for (final ReadingHourlyLogRow h in await readingHourlyF) {
    hourly.add(
      StatFact(
        mediaKind: kActivityMediaBook,
        mediaKey: '',
        title: '',
        format: h.format,
        dateKey: h.dateKey,
        hour: h.hour,
        ms: h.readingTimeMs,
        chars: 0,
        pages: 0,
      ),
    );
  }
  // v105：legacy 学习行只给归属 Profile；`added` 等库事件不分 Profile。
  final List<ActivityEventRow> activity = legacyVisible
      ? await activityF
      : <ActivityEventRow>[
          for (final ActivityEventRow e in await activityF)
            if (!kLegacyStudyActivityTypes.contains(e.eventType)) e,
        ];

  // v92 段：两面各一份。
  final List<StudySegmentRow> segments = await segmentsF;
  for (final StudySegmentRow s in segments) {
    // **写零的段不进事实面**。`zeroStudySegmentsOnDays`（时段明细里长按删除走的那条）
    // 只把行写成零而不删行——必须删的是同步语义：真删行会被对端的旧数据按 LWW 复活，
    // 写零才能跨端传播「这段不算了」。
    //
    // 于是过滤责任落在读侧。不过滤的话，被删掉的那条会以「0 字」原地复活：sheet 聚合
    // 侧对任何命中该 dateKey 的 fact 都建 entry，渲染侧 ms==0 就走 formatStatChars(0)。
    // 用户看到的就是「删了、刷新、它又回来了」。零行同样会污染排行、热力图等所有吃
    // StatFacts.daily 的消费方。
    //
    // 判据与 [segmentsAsActivityRows] 逐字一致——**同一件事只能有一条判据**，
    // 两处分别写就是给「活动流干净、统计页脏」这种半修好状态留门。
    if (s.durationMs <= 0 && s.chars <= 0 && s.pages <= 0) continue;
    final StatFact fact = StatFact(
      mediaKind: s.mediaKind,
      mediaKey: s.mediaKey,
      title: s.title,
      format: s.format,
      dateKey: s.dateKey,
      hour: s.hour,
      ms: s.durationMs,
      chars: s.chars,
      pages: s.pages,
    );
    daily.add(fact);
    hourly.add(fact);
  }
  return StatFacts(
    daily: daily,
    hourly: hourly,
    segments: segments,
    legacyActivity: activity,
    epubRows: epubRows,
    counters: await countersF,
    activityLimit: activityLimit,
  );
}

/// 计数面（与主事实面同一批并发）：收藏句在偏好里（一条 JSON）。
Future<StatCounterFacts> _loadCounterFacts(FushiDatabase db) async =>
    StatCounterFacts(
      favoriteSentences: await FavoriteSentenceRepository(db).getAll(),
    );

/// 把 v92 段映射成活动流行（id=0 哨兵，display-only 不落库——与互联远端行同一
/// 手法），喂既有 [aggregateActivityEvents]：同日同媒体多段按 30 分钟 gap 归并成
/// session 数，时长 / 字数求和。eventType 恒为 read。
List<ActivityEventRow> segmentsAsActivityRows(List<StudySegmentRow> segments) {
  return <ActivityEventRow>[
    for (final StudySegmentRow s in segments)
      if (s.durationMs > 0 || s.chars > 0 || s.pages > 0)
        ActivityEventRow(
          id: 0,
          eventType: kActivityRead,
          mediaType: s.mediaKind,
          title: s.title,
          mediaKey: s.mediaKey,
          dateKey: s.dateKey,
          timestampMs: s.endAt,
          durationMs: s.durationMs,
          charsDelta: s.chars,
        ),
  ];
}

/// 首页「今日目标」与阅读统计页目标卡共用的**同一条**口径：给定日面行的当日字数
/// 合计。传整张日面（[StatFacts.daily]）或某一域的切片（如 [StatFacts.dailyBooks]）；
/// 函数只按 dateKey 求和，域由调用方传的行集决定。目标偏好键沿用
/// `readingGoalDailyChars`（存量持久化名冻结）。
int studyGoalCharsForDay(Iterable<StatFact> daily, String dateKey) {
  int total = 0;
  for (final StatFact f in daily) {
    if (f.dateKey == dateKey) total += f.chars;
  }
  return total;
}
