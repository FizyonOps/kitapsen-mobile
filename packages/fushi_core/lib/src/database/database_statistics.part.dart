// 统计域：阅读 / 视频 / 活动事件 / 游戏库 / 收藏 / 制卡 / 计数（God 类拆分 2026-08：part+mixin，仓库 reader_fushi
// part 先例；mixin 是真类成员——可被测试子类 override、虚分派正常
// （extension 方案在此翻车过）；私有 mixin 不进公共 API 面。
part of 'database.dart';

/// 视频「已看过的片内区间并集」偏好键前缀（BUG-2108：观看时长只计首次覆盖）。值是
/// `WatchCoverage.toJson()`；按视频稳定身份 bookUid 键控，删该视频统计时连带删。
const String kVideoWatchCoveragePrefPrefix = 'video_watch_coverage_';

/// 「统计日」重置整点的偏好键（int 0..23，默认 0）。见
/// [FushiDatabase.statDayResetHour]。
const String kStatDayResetHourPrefKey = 'stats_day_reset_hour';

/// 激活 Profile 的偏好键（与 fushi 层 `ProfileRepository` 同一把 key）。统计
/// 分区键 `profile_id` 的写入时来源，见 [FushiDatabase.resolveActiveProfileId]。
const String kActiveProfileIdPrefKey = 'active_profile_id';

/// v105：legacy 统计家族（`reading_statistics` / `video_watch_statistics` /
/// `*_hourly_logs` / `activity_events` 的 read|watch|game 行）归属的 Profile id。
/// legacy 表冻结不加列，升级那一刻激活的 Profile 认领全部旧历史；读取面只对这个
/// Profile 露出 legacy 行。缺失（fresh 库从没升级过）= 没有归属 = 对所有 Profile
/// 可见（legacy 行只可能经旧端同步 / 备份进来，本就无从归属）。
///
/// 设备本地键：值是本库自增 id，绝不随 Profile 快照 / 备份 / 同步出境
/// （fushi 层 `ProfileKeys` / `SyncRepository.deviceLocalPrefKeys` 各排除一次）。
const String kStatLegacyProfileIdPrefKey = 'stats_legacy_profile_id';

mixin _FushiDbStatistics
    on
        _$FushiDatabase,
        _FushiDbPrefsMedia,
        _FushiDbContentMisc,
        _FushiDbTagsSync {
  // ── reading statistics ──────────────────────────────────────────

  Future<List<ReadingStatisticRow>> getAllReadingStatistics() =>
      select(readingStatistics).get();

  // ── reading hourly logs ─────────────────────────────────────────

  /// 逐行读取全部阅读小时日志，供云聚合同步 materialize 快照（TODO-1056 phase B）。
  Future<List<ReadingHourlyLogRow>> getAllReadingHourlyLogs() =>
      select(readingHourlyLogs).get();

  // ── video watch statistics ──────────────────────────────────────
  Future<List<VideoWatchStatisticRow>> getAllVideoWatchStatistics() =>
      select(videoWatchStatistics).get();

  // ── activity events (v49) ───────────────────────────────────────
  /// 追加一条活动事件（每次阅读/观看 session 结束或导入完成时写一行）。纯追加，
  /// 不去重、不累加——同书同日多次 session = 多行，读取端按需分组/计数。
  /// 「统计日」重置整点（0..23，默认 0 = 本地午夜）。用户可配「今日从几点开始」
  /// （对齐 Hoshi Reader Android 的 `statisticsResetMinutes`，但只取整点：v92 学习段
  /// 不跨整点边界，天边界落在整点上就永远不会撕裂一个段）。偏好键
  /// [kStatDayResetHourPrefKey]，app 层加载偏好 / 用户改设置时写入这里；
  /// [statDateKeyOf] 派生 dateKey 时按它把 `[reset, 次日 reset)` 归到起始那个日历日。
  ///
  /// 写入时定 dateKey（与 Hoshi 同）：改设置只影响之后写入的段，历史段保留写入时
  /// 的 dateKey；`hour` 列保留真实本地小时，需要时可按 (dateKey, hour) 重分桶。
  /// 跨设备同步的段带的是**写入设备**当时的 dateKey。
  static int get statDayResetHour => _statDayResetHour;
  static set statDayResetHour(int hour) {
    _statDayResetHour = hour.clamp(0, 23);
  }

  static int _statDayResetHour = 0;

  /// 统计日分组键（`yyyy-MM-dd`）：时刻 [d] 所属的**统计日**——按本地墙钟把小时
  /// 减去 [statDayResetHour] 后取日历日（墙钟减法而不是 Duration 减法，DST 切换日
  /// 不会多算 / 少算一小时）。与 app 层 `statDateKey` / fushi_audio 的小时桶 dateKey
  /// 同构——[recordReadingSession] 在 DB 层派生 dateKey 的单一来源，别再让调用方
  /// 自算一份传进来。
  ///
  /// **只给时刻用**。要拿「某个日历日」的键（热力图格子 / 近 N 天 / streak 回溯）
  /// 走 [statDateKeyPlusDays] 做键算术或 [statCalendarDayKeyOf]，别把 `DateTime(y,m,d)`
  /// 这种合成的午夜塞进来——重置整点非 0 时它会落到前一天。
  static String statDateKeyOf(DateTime d) => statCalendarDayKeyOf(
        DateTime(d.year, d.month, d.day, d.hour - _statDayResetHour, d.minute),
      );

  /// 日历日 → `yyyy-MM-dd`（不看重置整点，只取年月日）。
  static String statCalendarDayKeyOf(DateTime day) =>
      '${day.year}-${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';

  /// dateKey → 该统计日对应的日历日（本地午夜的 DateTime；只用于日历算术，
  /// 如求星期几 / 与另一个键相差几天）。非法键抛 [FormatException]。
  static DateTime statDateKeyToDay(String dateKey) {
    final List<String> parts = dateKey.split('-');
    if (parts.length != 3) throw FormatException('bad dateKey', dateKey);
    return DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }

  /// 键算术：[dateKey] 往后 [days] 天（负数往前）的 dateKey，按日历加减、跨月跨年
  /// 自动进位。近 N 天窗口 / streak 回溯 / 热力图格子一律走这里，不经时刻换算。
  static String statDateKeyPlusDays(String dateKey, int days) {
    final DateTime day = statDateKeyToDay(dateKey);
    return statCalendarDayKeyOf(DateTime(day.year, day.month, day.day + days));
  }

  /// 从 [now] 起到下一个统计日边界（下一次 `statDayResetHour:00`）的时长，恒 > 0。
  /// 统计页 / 首页用它排一次性 Timer：跨边界后整页重聚合（BUG-2181）。按日历取
  /// 下一个整点（DST 切换日不是恰 24h）。
  static Duration untilNextStatDayBoundary(DateTime now) {
    DateTime next = DateTime(now.year, now.month, now.day, _statDayResetHour);
    if (!next.isAfter(now)) {
      next = DateTime(now.year, now.month, now.day + 1, _statDayResetHour);
    }
    return next.difference(now);
  }

  Future<void> addActivityEvent({
    required String eventType,
    required String mediaType,
    required String title,
    required String dateKey,
    required int timestampMs,
    String? mediaKey,
    int? durationMs,
    int? charsDelta,
  }) =>
      into(activityEvents).insert(
        ActivityEventsCompanion.insert(
          eventType: eventType,
          mediaType: mediaType,
          title: title,
          dateKey: dateKey,
          timestampMs: timestampMs,
          mediaKey: Value(mediaKey),
          durationMs: Value(durationMs),
          charsDelta: Value(charsDelta),
        ),
      );

  /// 取最近 [limit] 条活动事件，按精确时刻倒序（首页 Activity 面板消费）。
  /// [eventTypes] 非空时只取这些类别（如只看 'read'），null = 全部类别。
  Future<List<ActivityEventRow>> getRecentActivityEvents({
    int limit = 200,
    List<String>? eventTypes,
  }) {
    final SimpleSelectStatement<$ActivityEventsTable, ActivityEventRow> query =
        select(activityEvents)
          ..orderBy([
            (t) => OrderingTerm(
                  expression: t.timestampMs,
                  mode: OrderingMode.desc,
                ),
          ])
          ..limit(limit);
    if (eventTypes != null && eventTypes.isNotEmpty) {
      query.where((t) => t.eventType.isIn(eventTypes));
    }
    return query.get();
  }

  // ── 活动事件的删除对称性(P4 B2,2026-08-10 用户拍板) ──────────────
  // 决策:活动时间轴是**历史事实日志**,不是现存库的视图——删书/删视频
  // **不**连带删其活动事件("我上个月读过什么"的历史不随删库改写)。
  // 下面两个清理函数因此**刻意零生产调用**,不是漏接线;保留是给将来
  // 可能的显式清理入口(用户主动"清除活动历史")备用,勿在删除路径接线。

  /// 删除某标题的全部活动事件。刻意无生产调用方(见上方决策注释)。
  Future<int> deleteActivityEventsForTitle(String title) =>
      (delete(activityEvents)..where((t) => t.title.equals(title))).go();

  // ── study_segments (v92 统计域唯一事实表) ───────────────────────
  //
  // 写法只有一种：[upsertStudySegment] 绝对值 upsert（表注释见 tables.dart）。
  // 本地写入面自 v92 起**只写本表**；上面的 reading_statistics /
  // video_watch_statistics / *_hourly_logs / activity_events(read|watch|game) 累加
  // DAO 已删除，剩下的 set* OVERWRITE 版只服务 legacy wire 的同步落地。

  /// `sync_device_id` 偏好键（与 fushi 层 SyncRepository 同一把 key，同一张
  /// preferences 表）：段的 provenance 列从这里取。
  static const String studyDeviceIdPrefKey = 'sync_device_id';

  static final Random _studyUidRandom = Random.secure();

  /// 新段的幂等键：32 位 hex（128 bit 随机）。写入方在**打开段时**生成一次并持有，
  /// 之后每个 tick 用同一 uid 写绝对值。
  static String newStudySegmentUid() {
    final StringBuffer sb = StringBuffer();
    for (int i = 0; i < 16; i++) {
      sb.write(_studyUidRandom.nextInt(256).toRadixString(16).padLeft(2, '0'));
    }
    return sb.toString();
  }

  /// 本机设备身份（段的 provenance）。无则生成并落 `sync_device_id`（与互联 /
  /// 云同步取同一把 key，先到先建，两边格式都是不透明字符串）。
  Future<String> getOrCreateStudyDeviceId() async {
    final String? existing = await getPref(studyDeviceIdPrefKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final String id = newStudySegmentUid();
    await setPref(studyDeviceIdPrefKey, id);
    return id;
  }

  // ── Profile 分区（v105：统计按 Profile 隔离）────────────────────
  // resolveActiveProfileId / getStatLegacyProfileId / legacyStatsVisibleTo /
  // _stampStudySegmentProfile 住 _FushiDbTagsSync（Profile CRUD 所在层；
  // _FushiDbContentMisc 的删除原语也要用，mixin 只能向下看）。

  /// v105 迁移专用：存量统计行认领的 Profile。激活的 > 最早建的 > 新建 'Default'
  /// （迁移里没有 fushi 层，没法连带快照；'Default' 是 `ensureDefaultProfile`
  /// 同名默认，它随后看到已有 Profile 就只校验激活 id，不会再建第二个）。
  /// 只用裸 SQL：迁移时的 drift 生成查询未必与磁盘形态一致。
  Future<int> _statOwnerProfileForV105() async {
    if (!await _tableExists('profiles')) return 0;
    Future<int?> existingId(int id) async {
      final List<QueryRow> rows = await customSelect(
        'SELECT id FROM profiles WHERE id = ?',
        variables: <Variable<Object>>[Variable.withInt(id)],
      ).get();
      return rows.isEmpty ? null : rows.first.read<int>('id');
    }

    if (await _tableExists('preferences')) {
      final List<QueryRow> prefRows = await customSelect(
        'SELECT "value" FROM preferences WHERE "key" = ?',
        variables: <Variable<Object>>[
          Variable.withString(kActiveProfileIdPrefKey),
        ],
      ).get();
      final int fromPref = prefRows.isEmpty
          ? -1
          : (int.tryParse(prefRows.first.read<String>('value')) ?? -1);
      if (fromPref > 0 && await existingId(fromPref) != null) return fromPref;
    }
    final List<QueryRow> first = await customSelect(
      'SELECT id FROM profiles ORDER BY created_at ASC, id ASC LIMIT 1',
    ).get();
    if (first.isNotEmpty) return first.first.read<int>('id');
    final int now = DateTime.now().millisecondsSinceEpoch;
    await customStatement(
      'INSERT INTO profiles (name, created_at, updated_at) VALUES (?, ?, ?)',
      <Object>['Default', now, now],
    );
    final List<QueryRow> created = await customSelect(
      'SELECT id FROM profiles ORDER BY id DESC LIMIT 1',
    ).get();
    final int id = created.first.read<int>('id');
    if (await _tableExists('preferences')) {
      await customStatement(
        'INSERT OR REPLACE INTO preferences ("key", "value", updated_at) '
        'VALUES (?, ?, ?)',
        <Object>[kActiveProfileIdPrefKey, id.toString(), now],
      );
    }
    return id;
  }

  /// **唯一写入口**：按 [uid] 绝对值 upsert。同 uid 重复写同值 = no-op；
  /// 写入方持有段累计器，绝不在这里做 `+=`。
  ///
  /// v105：`profile_id` 缺席时盖当前激活 Profile；**冲突更新不改归属**（段的
  /// Profile 在开段那一刻定死，见 tables.dart）。
  ///
  /// BUG-2214 / BUG-2220：墓碑语义 = 「删除 `startAt < deletedAt` 的段」。同身份
  /// 若有墓碑且本行 `startAt < deletedAt`，本次写**静默丢弃**（返回不抛）：用户删
  /// 该媒体统计时仍在跑的时钟，其开放段（startAt 在删除之前）的后续 tick 不得把已
  /// 删的段写回；时钟下一次开新段（`startAt >= deletedAt`）天然存活，墓碑不需要、
  /// 也永不因后来的段退场。
  Future<void> upsertStudySegment(StudySegmentsCompanion input) =>
      transaction(() async {
        final StudySegmentsCompanion row =
            await _stampStudySegmentProfile(input);
        if (await _isStudySegmentTombstoned(row)) return;
        await into(studySegments).insert(
          row,
          onConflict: DoUpdate(
            (old) => row.copyWith(profileId: const Value.absent()),
            target: [studySegments.uid],
          ),
        );
      });

  /// [row] 是否被**同 Profile** 同身份墓碑压制（`startAt < deletedAt`）。身份 /
  /// startAt 缺席的行不判压制（写入方契约要求三者必填，缺席只会出现在测试桩）；
  /// [row] 须已盖好 profileId（[_stampStudySegmentProfile]）。
  Future<bool> _isStudySegmentTombstoned(StudySegmentsCompanion row) async {
    if (!row.mediaKind.present ||
        !row.mediaKey.present ||
        !row.startAt.present) {
      return false;
    }
    final int profileId = row.profileId.present ? row.profileId.value : 0;
    final StudySegmentTombstoneRow? tomb = await (select(studySegmentTombstones)
          ..where((t) =>
              t.profileId.equals(profileId) &
              t.mediaKind.equals(row.mediaKind.value) &
              t.mediaKey.equals(row.mediaKey.value)))
        .getSingleOrNull();
    return tomb != null && row.startAt.value < tomb.deletedAt;
  }

  /// 闭区间 [fromDateKey, toDateKey]（`yyyy-MM-dd` 字典序即时间序）内的全部段；
  /// 任一端 null = 不设界。
  ///
  /// v105：默认只取 [profileId]（null = 当前激活 Profile）的段；只有同步 / 备份
  /// 导出这种要搬**整库**的调用方传 `allProfiles: true`。
  Future<List<StudySegmentRow>> getStudySegments({
    String? fromDateKey,
    String? toDateKey,
    int? profileId,
    bool allProfiles = false,
  }) async {
    final SimpleSelectStatement<$StudySegmentsTable, StudySegmentRow> q =
        select(studySegments);
    if (!allProfiles) {
      final int scope = profileId ?? await resolveActiveProfileId();
      q.where((t) => t.profileId.equals(scope));
    }
    return q.get();
  }

  /// 按 uid 取段（会话流编辑「这一次会话」时要读回每段的**现有**字数与起止时刻，
  /// 才能把新的总字数按比例分摊、把时刻整体平移；[StudySession] 只带会话级求和）。
  Future<List<StudySegmentRow>> getStudySegmentsByUids(Set<String> uids) {
    // 空集也返回**可增长**的空列表，不是 `const []`：本表其余查询走 drift 的
    // `.get()`，拿到的恒是可变 List，调用方（`applyStudySessionEdit` 拿去 sort）
    // 按那个契约写。返回不可变常量会让「uid 集为空」这条路径——也就是纯时长
    // 游戏会话——在 sort 上抛 `Cannot modify an unmodifiable list`。
    if (uids.isEmpty) {
      return Future<List<StudySegmentRow>>.value(<StudySegmentRow>[]);
    }
    return (select(studySegments)..where((t) => t.uid.isIn(uids))).get();
  }

  // zeroStudySegmentsOnDays / deleteStatFactsOnDays 住 _FushiDbContentMisc（同
  // deleteStudySegmentsForMedia：legacy 删行在那层连带调用，mixin 只能向下看）。

  /// galgame_sessions 按 (game_id, date_key) 的时长合计（秒）：喂统一事实面
  /// （日明细按游戏分节、热力图游戏时长）。
  /// v105：只取 [profileId]（null = 当前激活 Profile）的会话。
  ///
  /// v113：游戏已从库移除的孤儿会话照样计入；[getGalgameSessionTitles] 给它们的
  /// 显示名快照。
  Future<List<(String gameId, String dateKey, int totalSeconds)>>
      getGalgameDailySecondsByGame({int? profileId}) async {
    final int scope = profileId ?? await resolveActiveProfileId();
    final List<QueryRow> rows = await customSelect(
      'SELECT game_id, date_key, COALESCE(SUM(duration_seconds), 0) AS s '
      'FROM galgame_sessions WHERE profile_id = ? GROUP BY game_id, date_key',
      variables: [Variable.withInt(scope)],
      readsFrom: {galgameSessions},
    ).get();
    return <(String, String, int)>[
      for (final QueryRow row in rows)
        (
          row.read<String>('game_id'),
          row.read<String>('date_key'),
          row.read<int>('s'),
        ),
    ];
  }

  /// v113：游玩会话行上的游戏显示名快照（`game_id -> game_title`，只含非空快照，
  /// 即已从库移除的游戏）。统计读取端在库内反查不到游戏时用它显示名字。
  Future<Map<String, String>> getGalgameSessionTitles() async {
    final List<QueryRow> rows = await customSelect(
      'SELECT game_id, MAX(game_title) AS title FROM galgame_sessions '
      "WHERE game_title != '' GROUP BY game_id",
      readsFrom: {galgameSessions},
    ).get();
    return <String, String>{
      for (final QueryRow row in rows)
        row.read<String>('game_id'): row.read<String>('title'),
    };
  }

  // upsertStudySegmentTombstone 住 _FushiDbContentMisc（deleteStudySegmentsForMedia /
  // clearStudySegments 在那层调用，mixin 只能向下看；本层的
  // applyStudySegmentTombstone 向下调它）。

  // ── galgames / galgame_sources / galgame_sessions (v55 游戏库) ──────
  //
  // 设计见 `docs/design/galgame-library-reina-parity.md`。这里刻意没有统计投影表：
  // 时长/次数/最后游玩全部现算 GROUP BY（见下面聚合方法），一次消掉「投影与
  // 事实表不一致」的整类 bug。单机规模是几百游戏 × 几千会话，SQLite 毫秒级。

  /// 全部游戏，按添加时间升序（与旧 JSON 列表的天然顺序一致，Never break userspace）。
  Future<List<GalgameRow>> getAllGalgames() =>
      (select(galgames)..orderBy([(t) => OrderingTerm.asc(t.addedAt)])).get();

  /// 全库元数据源快照，按 gameId 分组（库页一次取全量，避免 N+1）。
  Future<Map<String, List<GalgameSourceRow>>> getAllGalgameSources() async {
    final List<GalgameSourceRow> rows = await select(galgameSources).get();
    final Map<String, List<GalgameSourceRow>> out =
        <String, List<GalgameSourceRow>>{};
    for (final GalgameSourceRow row in rows) {
      (out[row.gameId] ??= <GalgameSourceRow>[]).add(row);
    }
    return out;
  }

  /// 最近 [limit] 条游玩会话（按结束时刻倒序）：v92 起游玩不再写 activity 行，
  /// 首页活动流 / 游戏首页时间线从这里合成「游玩」事件。v105：只看 [profileId]
  /// （null = 当前激活 Profile）。
  Future<List<GalgameSessionRow>> getRecentGalgameSessions({
    int limit = 200,
    int? profileId,
  }) async {
    final int scope = profileId ?? await resolveActiveProfileId();
    return (select(galgameSessions)
          ..where((t) => t.profileId.equals(scope))
          ..orderBy([(t) => OrderingTerm.desc(t.endMs)])
          ..limit(limit))
        .get();
  }

  /// 清空游戏统计，只删除游玩会话事实。
  ///
  /// 游戏库（[galgames]）与首页活动时间线（[activityEvents]）是独立用户数据，
  /// 不能因统计页的「清空」操作被连带删除。
  ///
  /// v105：只清当前激活 Profile 的那份（别的 Profile 的游玩史不是本 Profile 的
  /// 「全部」）。
  Future<int> clearAllGalgameStatistics() => transaction(() async {
        final int profileId = await resolveActiveProfileId();
        // v92：hook 字数段（chars-only）与游玩会话同属「游戏统计」，一起清。
        await clearStudySegments(kActivityMediaGame, profileId: profileId);
        return (delete(galgameSessions)
              ..where((t) => t.profileId.equals(profileId)))
            .go();
      });

  /// 首页仪表盘的「数据变了」信号：activity_events / reading_statistics /
  /// video_watch_statistics / video_books 任一表变更即 emit（不带数据，消费方自行
  /// 重查聚合）。首页据此在阅读/观看/导入落库后**自动刷新**热力图 + 时长 + 活动
  /// 时间轴——否则首页在 pushed 阅读器路由下不重建，读完回来仍是旧数据（用户报
  /// 「打开一本书 Activity 还是空的」）。
  ///
  /// 用手动 [StreamController] + [tableUpdates]，**不用** drift keyed `.watch()`：
  /// 后者取消订阅会遗留缓存保留 `Timer.run`，触发 flutter_test `!timersPending`
  /// 让 flutter_tester 永不退出（BUG-834，见 [watchVideoBookUids] 详注）。
  /// tableUpdates 流取消时不安排该 Timer，widget 测试可正常收敛。
  Stream<void> watchDashboardDataChanges() {
    late final StreamController<void> controller;
    StreamSubscription<void>? updatesSub;
    controller = StreamController<void>(
      onListen: () {
        updatesSub = tableUpdates(
          TableUpdateQuery
              .onAllTables(<ResultSetImplementation<dynamic, dynamic>>[
            activityEvents,
            readingStatistics,
            videoWatchStatistics,
            // v92：学习统计唯一事实表；本地写入面只写它，首页热力图 / 今日 /
            // 活动流全部从它派生。
            studySegments,
            galgameSessions,
            videoBooks,
            // 阅读位置是首页「继续」的数据源（MediaItem.position 与最近阅读时刻
            // 均派生自它）。此前不在表集里：互联/云同步把更远的对端进度写回
            // reader_positions 后，首页「继续」不刷新、要重启 app 才生效——
            // 同步回灌与本机关书是同一张表的写入，理应同一条失效通道。
            readerPositions,
          ]),
        ).listen((_) {
          if (!controller.isClosed) controller.add(null);
        });
      },
      onCancel: () async {
        await updatesSub?.cancel();
      },
    );
    return controller.stream;
  }

  /// 逐行读取全部视频小时日志，供云聚合同步 materialize 快照（TODO-1056 phase B）。
  Future<List<VideoHourlyLogRow>> getAllVideoHourlyLogs() =>
      select(videoHourlyLogs).get();

  // ── favorite words ──────────────────────────────────────────────

  /// 取全部收藏词，按 createdAt 倒序（最近在前），供收藏夹导出（TODO-829）。
  /// 纯 select，不动 schema。
  Future<List<FavoriteWordRow>> getAllFavoriteWords() =>
      (select(favoriteWords)..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .get();

  // ── mining statistics ───────────────────────────────────────────

  /// 逐行读取全部制卡计数行（所有来源），供云聚合同步 materialize 快照
  /// （TODO-1056 phase B）。写回用 [setMiningCount]（MAX 语义、幂等）。
  Future<List<MiningStatisticRow>> getAllMiningStatistics() =>
      select(miningStatistics).get();

  // ── lookup / mining per-book counters (TODO-1204) ────────────────

  /// 逐行读取全部查词/制卡计数行（所有来源），供将来云聚合同步 materialize 快照。
  /// 写回用 [setLookupCount] / [setMineCountPerBook]（MAX 语义、幂等）。
  Future<List<LookupMiningCounterRow>> getAllLookupMiningCounters() =>
      select(lookupMiningCounters).get();

  // ── mined sentences ──────────────────────────────────────────────

}
