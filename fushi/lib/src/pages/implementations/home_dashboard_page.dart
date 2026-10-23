import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:transparent_image/transparent_image.dart';
import 'package:fushi/media.dart';
import 'package:fushi/utils.dart';
import 'package:fushi/src/models/app_model.dart';
import 'package:fushi/src/media/display_title.dart';
import 'package:fushi/src/media/media_cover_source.dart';
import 'package:fushi/src/pages/base_module_tab_page.dart';
import 'package:fushi/src/pages/implementations/activity_feed.dart';
import 'package:fushi/src/pages/implementations/home_page.dart';
import 'package:fushi/src/pages/implementations/stat_period_detail_sheet.dart';
import 'package:fushi/src/pages/implementations/stat_shared.dart';
import 'package:fushi/src/pages/implementations/statistics_center_page.dart';
import 'package:fushi_engine/stats/stat_facts.dart';
import 'package:fushi/src/stats/stat_window.dart';
import 'package:fushi/src/utils/components/stat_contribution_heatmap.dart';
import 'package:fushi/src/utils/cover_image.dart';
import 'package:fushi_core/fushi_core.dart';

/// 首页仪表盘（阅读向），参考 ReinaManager 首页改造：
///
/// - 区块 1：学习活动热力图（复用 [StatContributionHeatmap]），置顶；带「今日目标」
///   行与点选日明细 sheet。
/// - 区块 2：「继续」——在读的书做成横向滑动卡片行（Jellyfin 式：封面 + 底部进度条 +
///   标题/副标题）。
/// - 区块 3：Activity 时间轴——把 [ActivityEventRow] 事件流经纯函数
///   [aggregateActivityEvents] 聚合成「按日期分组」的时间线，顶部按类别筛选。
///
/// 分栏（BUG-1073 后）：宽屏（`constraints.maxWidth >= 900`）= 主列（flex 3：学习活动
/// → 继续 → 最近添加）+ 侧列（flex 2：Activity 时间轴）；窄屏单列堆叠。书与阅读位置
/// 走 Riverpod provider（响应式）；统计与活动事件在 [initState] 一次性异步载入到本地
/// 状态。
class HomeDashboardPage extends BaseModuleTabPage {
  const HomeDashboardPage({super.key});

  @override
  BaseModuleTabPageState<HomeDashboardPage> createState() =>
      _HomeDashboardPageState();
}

/// 「继续」/「最近添加」横滑行的单条（一本本地书），按 [recentMs] 倒序排列。
class _ContinueEntry {
  const _ContinueEntry({
    required this.title,
    required this.recentMs,
    required this.book,
    this.percent = 0,
    this.progress,
    this.collectionName,
    this.subtitleOverride,
  });

  final String title;

  /// 最近活动时刻（epoch 毫秒），仅用于排序。
  final int recentMs;

  /// 阅读进度百分比（0..100）。
  final int percent;

  /// 封面底部进度条分数（0..1）；null = 无可展示进度不画。
  final double? progress;

  /// 所属主合集名（显示名规则：非合集上下文标题=合集名、副标题=条目名+状态）；
  /// null = 散卡。
  final String? collectionName;

  /// 副标题状态段的覆盖文案（「最近添加」行用「类型 · 相对时间」替代进度状态）；
  /// null = 按 继续区 默认规则（「阅读 · x%」）。
  final String? subtitleOverride;
  final MediaItem book;
}

/// 每日字数目标编辑对话框。独立 StatefulWidget **自持** controller 生命周期：
/// dispose 跟随路由销毁（弹出动画结束后）。此前「await showDialog 返回即
/// dispose」会在退场动画帧触碰已销毁 controller——保存后本页 setState 让仍在
/// 退场的 TextField 重建 addListener 直接断言崩（widget 测试实测复现）。
/// 保存 pop 解析后的字数（空/非法 → 0 = 关闭目标），取消 pop null。
///
/// BUG-1075：此前只有一个裸 TextField（labelText=每日目标），用户「不知道该填
/// 什么、单位是什么、算不算看视频」。现在补齐三件事（不引入加权系统——那是过度
/// 设计，口径说清即可）：输入框带单位后缀 + 口径 helperText、近 7 日日均参考值、
/// 一排快捷预设 chip。
class _DailyGoalDialog extends StatefulWidget {
  const _DailyGoalDialog({
    required this.initialChars,
    required this.recentDailyAverage,
  });

  /// 当前目标（0 = 未设，输入框留空）。
  final int initialChars;

  /// 近 7 日日均字数（全来源合计，与目标同口径）；<=0 不显示参考行。
  final int recentDailyAverage;

  /// 快捷预设（字/天）：点一下直接填进输入框，省得用户凭空想数字。
  static const List<int> presets = <int>[3000, 5000, 10000, 20000];

  @override
  State<_DailyGoalDialog> createState() => _DailyGoalDialogState();
}

class _DailyGoalDialogState extends State<_DailyGoalDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialChars == 0 ? '' : widget.initialChars.toString(),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 预设 chip → 填入输入框（光标置尾，用户可继续改）。
  void _applyPreset(int chars) {
    final String text = chars.toString();
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final FushiDesignTokens tokens = FushiDesignTokens.of(context);
    return AlertDialog(
      title: Text(t.stat_goal_set),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            TextField(
              controller: _controller,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: t.stat_goal_daily,
                // 单位：目标是「每天多少字」。口径说明行按用户要求删除。
                suffixText: t.stat_goal_unit_chars,
              ),
            ),
            if (widget.recentDailyAverage > 0) ...<Widget>[
              SizedBox(height: tokens.spacing.gap),
              Text(
                t.stat_goal_recent_average(n: widget.recentDailyAverage),
                style: tokens.type.metadata,
              ),
            ],
            SizedBox(height: tokens.spacing.gap + 4),
            Text(t.stat_goal_presets, style: tokens.type.metadata),
            SizedBox(height: tokens.spacing.gap / 2),
            Wrap(
              spacing: tokens.spacing.gap,
              runSpacing: tokens.spacing.gap / 2,
              children: <Widget>[
                for (final int preset in _DailyGoalDialog.presets)
                  ActionChip(
                    label: Text(preset.toString()),
                    onPressed: () => _applyPreset(preset),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context)
              .pop(int.tryParse(_controller.text.trim()) ?? 0),
          child: Text(t.dialog_save),
        ),
      ],
    );
  }
}

class _HomeDashboardPageState
    extends BaseModuleTabPageState<HomeDashboardPage> {
  static const int _kActivityPageSize = 24;

  /// 首页主纵向滚动区自己的控制器。滚轮平滑由根部 `SmoothWheelScrollScope`
  /// 统一处理（BUG-2834），这里不再需要特制控制器。
  final ScrollController _dashboardScrollController = ScrollController();

  /// 「继续」横滑行：竖版书封槽。行总高 = 封面 + 标题/副标题两行文字块。
  static const double _kContinueCoverHeight = 132;
  static const double _kContinueCoverWidth = 94; // ≈132×5/7 竖版

  /// 「继续」横滑行的总高：封面 + 两行标题 + 一行副标题 + 行间距。
  ///
  /// BUG-1184：原先是死常量 196，配合标题 `maxLines: 1`。书封宽只有 94px，一行
  /// 只显示得到日文书名的五六个字。放宽到两行就必须同步抬高行高，而且这个高度
  /// 本来也该随文字缩放走——旧的 196 在 textScale≥1.5 时连「单行标题 + 副标题」
  /// 都装不下，会直接竖向溢出。
  double _continueRowHeight(BuildContext context, FushiDesignTokens tokens) {
    final double titleLine = textLineHeight(context, tokens.type.listTitle);
    final double metaLine = textLineHeight(context, tokens.type.metadata);
    return _kContinueCoverHeight +
        tokens.spacing.gap / 2 +
        titleLine * 2 +
        tokens.spacing.gap / 4 +
        metaLine +
        kTextBlockSlack;
  }

  /// Activity 分类筛选：null=全部，否则 [kActivityRead]/[kActivityAdded]（内存里先
  /// 过滤 events 再聚合）。
  String? _activityFilter;

  /// 活动预取与渲染解耦：数据保留完整，widget 树每次只增加一页。
  int _visibleActivityEntryCount = _kActivityPageSize;

  /// [initState] 异步载入的活动事件流（时间轴原始数据）。
  List<ActivityEventRow> _activityEvents = const <ActivityEventRow>[];

  /// 每日阅读字数 / 学习时长（dateKey → 字数 / 毫秒），热力图 + 日明细 sheet。今日
  /// 目标的分子不读这张表——它直接对事实行求和，见 [studyGoalCharsForDay]
  /// （BUG-1993：与阅读统计页同一函数）。
  Map<String, int> _readCharsByDay = const <String, int>{};
  Map<String, int> _readTimeMsByDay = const <String, int>{};

  /// 已加载的统一事实面日行（点选日明细 sheet 按 dateKey 过滤、今日目标分子按
  /// 阅读域求和，免重查）。
  List<StatFact> _readingRows = const <StatFact>[];

  /// 合集归属映射（统计页/书架同源，显示名规则「非合集上下文拼合集名」用）：
  /// - [_collectionNamesById]：collectionId → 合集名。
  /// - [_primaryCollectionByEntry]：'<mediaType>|<entryKey>' → 折叠归属主 collectionId。
  /// - [_bookKeyByTitle]：legacy 阅读事实行无身份（mediaKey ''）时经 epub_books
  ///   按 title 反查 bookKey（v92 段自带 mediaKey，优先直用）。
  /// - [_epubUidByBookKey]：v83 起成员表 epub entryKey = `epub_books.uid`，页面
  ///   手里的 bookKey 查归属映射前经此表换算（书架 `_epubUidByKey` 同款口径）。
  Map<int, String> _collectionNamesById = const <int, String>{};
  Map<String, int> _primaryCollectionByEntry = const <String, int>{};
  Map<String, String> _bookKeyByTitle = const <String, String>{};
  Map<String, String> _epubUidByBookKey = const <String, String>{};

  /// epub bookKey → 导入时刻（epoch 毫秒，`EpubBooks.importedAt`），
  /// 「最近添加」行的排序时间源。
  Map<String, int> _epubImportedAtByKey = const <String, int>{};

  /// 订阅「数据变了」信号（阅读/导入落库）以自动刷新，及其防抖定时器。
  /// 首页不保活、且阅读器是 pushed 路由（读完回来首页不重建 initState），故必须靠
  /// DB 表级变更主动重查，否则「打开一本书读完回来」活动/热力图仍是旧数据。
  StreamSubscription<void>? _dataChangeSub;
  Timer? _reloadDebounce;

  /// **本轮加载时**的统计窗口（今日目标 / 近 7 日日均都用它，BUG-2219：此前目标
  /// 卡在 build 时现算 todayKey，跨午夜后分子对着新的一天、热力图等仍是旧聚合）。
  /// 跨午夜由 [_midnightReload] 触发一次 [_scheduleReload] 整页重拉。
  StatWindow _statWindow = StatWindow(DateTime.now());
  Timer? _midnightReload;

  /// 库里同名 ≥2 本的 title（BUG-2216：日明细 sheet 身份分组的吸收否决）。
  Set<String> _ambiguousBookTitles = const <String>{};

  @override
  void initState() {
    super.initState();
    unawaited(_loadDashboardData());
    // 阅读/观看/导入写库 → 表级变更 → 防抖后重查聚合，首页自动刷新（竞态无关：
    // 信号在写入 commit 后才发，重查读到的是已落库数据）。
    _dataChangeSub = ref
        .read(appProvider)
        .database
        .watchDashboardDataChanges()
        .listen((_) => _scheduleReload());
  }

  /// 表变更后防抖重载（多次连续写只重查一次，避免频繁 setState）。
  void _scheduleReload() {
    _reloadDebounce?.cancel();
    _reloadDebounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      // 「继续」的书侧数据来自缓存 provider（书列表/最近阅读时刻均派生自
      // reader_positions），它们此前只在关书/导入时失效——互联/云同步把更远的
      // 对端进度写回后首页拿不到新值、要重启才生效。表级变更信号（现已含
      // readerPositions）到达时一并失效，让下面的重载 + build 的 ref.watch 读到
      // 新进度。频度由写入端自身的 debounce + 本 400ms 防抖兜住。
      ref.invalidate(fushiBooksProvider);
      ref.invalidate(bookLastReadAtProvider);
      unawaited(_loadDashboardData());
    });
  }

  @override
  void dispose() {
    _reloadDebounce?.cancel();
    _midnightReload?.cancel();
    unawaited(_dataChangeSub?.cancel());
    _dashboardScrollController.dispose();
    super.dispose();
  }

  /// 一次性异步载入统计行 + 活动事件，并派生热力图/时长窗口。
  ///
  /// 整段包 try/catch fail-open：任一 DB 读抛异常也不会让整页卡在 loading 或抛未捕获
  /// 异常（各区块对空数据都有降级），并补 [ErrorLogService] 使「首页空」这类问题线上
  /// 可诊断。
  Future<void> _loadDashboardData() async {
    try {
      await _loadDashboardDataUnsafe();
    } catch (e, stack) {
      ErrorLogService.instance.log('HomeDashboardPage.load', e, stack);
    }
  }

  /// 到下一个本地午夜整页重拉（每次加载重新排一次；页面已卸载则不动）。
  void _armMidnightReload(DateTime now) {
    _midnightReload?.cancel();
    _midnightReload = Timer(StatWindow.untilNextStatDayBoundary(now), () {
      if (mounted) _scheduleReload();
    });
  }

  Future<void> _loadDashboardDataUnsafe() async {
    final AppModel appModel = ref.read(appProvider);
    final FushiDatabase db = appModel.database;
    final DateTime loadedAt = DateTime.now();
    final StatWindow statWindow = StatWindow(loadedAt);
    _armMidnightReload(loadedAt);
    // 统计事实面与合集两张表互不依赖：一次全部发出，让 Drift 后台执行器流水线化。
    final Future<StatFacts> factsF = loadStatFacts(db);
    final Future<List<MediaCollectionRow>> collectionsF =
        db.getAllMediaCollections();
    final Future<Map<String, int>> primaryByEntryF =
        db.getPrimaryCollectionIdByEntry();
    await Future.wait<Object?>(<Future<Object?>>[
      factsF,
      collectionsF,
      primaryByEntryF,
    ]);
    final StatFacts facts = await factsF;
    final List<StatFact> reading = facts.dailyBooks.toList(growable: false);
    // 活动流唯一数据源 [StatFacts.activityRows]：legacy activity_events（含仍在写的
    // added 导入事件）∪ v92 段映射行，按时刻倒序截 200。
    final List<ActivityEventRow> events = facts.activityRows;
    // 合集归属映射（统计页/书架同源）：显示名规则「非合集上下文拼合集名」用。
    final Map<int, String> collectionNamesById = <int, String>{
      for (final MediaCollectionRow c in await collectionsF) c.id: c.name,
    };
    final Map<String, int> primaryByEntry = await primaryByEntryF;
    // legacy 阅读事实行无身份时按 title 反查 bookKey（日明细拼合集前缀，阅读统计
    // 页 _collectionNameForBook 同范式）。书表由事实面加载时顺带取回，同批再取
    // importedAt 喂「最近添加」行（一次查询两用）。
    final List<EpubBookMeta> epubRows = facts.epubRows;
    // BUG-2216：同名 ≥2 本的 title 不进反查表（贴给任意一本都是错贴）。
    final Map<String, String> bookKeyByTitle = uniqueBookKeyByTitle(epubRows);
    final Set<String> ambiguousTitles = ambiguousBookTitles(epubRows);
    final Map<String, int> epubImportedAtByKey = <String, int>{
      for (final EpubBookMeta r in epubRows) r.bookKey: r.importedAt,
    };
    // v83：成员表 epub entryKey = uid，同批行顺带建 bookKey→uid 换算表（空 uid
    // 异常行不进表，查归属时按 bookKey 原样回退）。
    final Map<String, String> epubUidByBookKey = <String, String>{
      for (final EpubBookMeta r in epubRows)
        if (r.uid.isNotEmpty) r.bookKey: r.uid,
    };

    final Map<String, int> readChars = <String, int>{};
    final Map<String, int> readTimeMs = <String, int>{};
    for (final StatFact f in reading) {
      readChars[f.dateKey] = (readChars[f.dateKey] ?? 0) + f.chars;
      readTimeMs[f.dateKey] = (readTimeMs[f.dateKey] ?? 0) + f.ms;
    }

    if (!mounted) return;
    setState(() {
      _statWindow = statWindow;
      _ambiguousBookTitles = ambiguousTitles;
      _activityEvents = events;
      _readCharsByDay = readChars;
      _readTimeMsByDay = readTimeMs;
      _readingRows = reading;
      _collectionNamesById = collectionNamesById;
      _primaryCollectionByEntry = primaryByEntry;
      _bookKeyByTitle = bookKeyByTitle;
      _epubUidByBookKey = epubUidByBookKey;
      _epubImportedAtByKey = epubImportedAtByKey;
    });
  }

  @override
  Widget build(BuildContext context) {
    final FushiDesignTokens tokens = FushiDesignTokens.of(context);
    final AppModel appModel = ref.watch(appProvider);
    final List<MediaItem> books =
        ref.watch(fushiBooksProvider(kShelfBooksKey)).valueOrNull ??
            const <MediaItem>[];
    final Map<String, int> lastReadByKey =
        ref.watch(bookLastReadAtProvider).valueOrNull ?? const <String, int>{};
    // v82：lastReadByKey 的键是书 uid；MediaItem 身份是 bookKey，查前经此表换算。
    final Map<String, String> epubUidByKey =
        ref.watch(epubBookUidByKeyProvider).valueOrNull ??
            const <String, String>{};
    final DateTime now = DateTime.now();

    // 活动条封面/点击直达需要「mediaKey → 本地条目」反查映射（渲染层现算，不
    // 落状态）。
    final Map<String, MediaItem> booksByKey = <String, MediaItem>{};
    for (final MediaItem item in books) {
      final String? key = ReaderFushiSource.parseBookKey(item.mediaIdentifier);
      if (key != null) booksByKey[key] = item;
    }

    final Widget continueCard = _buildContinueSection(
        tokens, appModel, books, lastReadByKey, epubUidByKey);
    final Widget heatmapCard = _buildHeatmapCard(tokens);
    final Widget activityCard =
        _buildActivitySection(tokens, now, appModel, booksByKey);
    final Widget? recentCard =
        _buildRecentlyAddedSection(tokens, appModel, books, now);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool wide = constraints.maxWidth >= 900;
        final Widget body;
        if (wide) {
          // BUG-1073：宽屏改成「主列 + 侧列」两栏。此前是「热力图通栏 → 继续|活动
          // 两栏 → 最近添加通栏」的三明治：热力图和最近添加各自被拉到 1700px 宽
          // （内容却只有几百 px），继续区一行只 4 张卡右侧全空，活动列又比左列高
          // 出一大截。现在把三个「宽度用不满」的区块（学习活动 / 继续 / 最近添加）
          // 竖着塞进主列，天然长的活动时间轴独占侧列，两列高度也就对齐了。
          //
          // 整页在纵向滚动的 ListView 里，Row 收到的高度约束是无界（h=Infinity）；
          // 用 CrossAxisAlignment.start 让两列各自收敛到内容高度，避免 stretch 被
          // 迫无限高在 layout 阶段崩溃。
          body = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    heatmapCard,
                    SizedBox(height: tokens.spacing.card),
                    continueCard,
                    // 空库不占位（用户反馈「底部很空」的填充提案）。
                    if (recentCard != null) ...<Widget>[
                      SizedBox(height: tokens.spacing.card),
                      recentCard,
                    ],
                  ],
                ),
              ),
              SizedBox(width: tokens.spacing.card),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    activityCard,
                  ],
                ),
              ),
            ],
          );
        } else {
          body = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              heatmapCard,
              SizedBox(height: tokens.spacing.card),
              continueCard,
              SizedBox(height: tokens.spacing.card),
              // 与宽屏主列同序（继续 → 最近添加）：窄屏单列把最近添加压在活动
              // 时间轴之下，时间轴天然很长，用户要滚到底才看得见新入库的条目。
              if (recentCard != null) ...<Widget>[
                recentCard,
                SizedBox(height: tokens.spacing.card),
              ],
              activityCard,
            ],
          );
        }
        return ListView(
          controller: _dashboardScrollController,
          padding: EdgeInsets.all(tokens.spacing.card),
          children: <Widget>[
            body,
          ],
        );
      },
    );
  }

  // ── 区块 2：继续 ─────────────────────────────────────────────────────────

  /// 「继续」区块：在读的书（0<position<duration）按最近阅读时刻倒序取前 10 条。
  Widget _buildContinueSection(
    FushiDesignTokens tokens,
    AppModel appModel,
    List<MediaItem> books,
    Map<String, int> lastReadByKey,
    Map<String, String> epubUidByKey,
  ) {
    final List<_ContinueEntry> entries = <_ContinueEntry>[];
    for (final MediaItem item in books) {
      if (item.position > 0 && item.position < item.duration) {
        final String bookKey =
            ReaderFushiSource.parseBookKey(item.mediaIdentifier) ??
                item.mediaIdentifier;
        // v82：位置表键 = uid，bookKey 经换算表转一跳；换算不上（书行已删）保持
        // 原键查询——查不到、recent=0。
        final int recent = lastReadByKey[epubUidByKey[bookKey] ?? bookKey] ?? 0;
        final int percent =
            ((item.position / item.duration) * 100).clamp(0, 100).round();
        entries.add(_ContinueEntry(
          // BUG-1018 (A1)：书名走与书架卡同一 override 通道（编辑对话框改名后
          // 首页「继续」区同步显示新名），不直接读 DB 原名。
          title: ReaderFushiSource.instance.getDisplayTitleFromMediaItem(item),
          recentMs: recent,
          percent: percent,
          progress: percent / 100,
          collectionName: statCollectionName(
            _bookCollectionKey(item),
            _primaryCollectionByEntry,
            _collectionNamesById,
          ),
          book: item,
        ));
      }
    }
    entries.sort(
      (_ContinueEntry a, _ContinueEntry b) => b.recentMs.compareTo(a.recentMs),
    );
    final List<_ContinueEntry> shown = entries.take(10).toList();

    return _sectionCard(
      tokens,
      title: t.home_continue,
      child: shown.isEmpty
          ? Text(t.home_activity_empty, style: tokens.type.metadata)
          : _continueCardsRow(tokens, appModel, shown),
    );
  }

  /// 横滑卡片行本体（「继续」与「最近添加」共用）：定高横向 ListView。
  Widget _continueCardsRow(
    FushiDesignTokens tokens,
    AppModel appModel,
    List<_ContinueEntry> entries,
  ) {
    // BUG-2002 同款几何：悬停放大是纯绘制变换（以卡中心放大），行视口高度恰等于
    // 卡高时，溢出的上下各 (scale-1)/2 会被 ListView 视口裁成平边——横滚行每张卡
    // 都贴着视口上下沿，不像墙格只有视口边缘才裁。行高留出余量、卡片自身尺寸不变；
    // 不能改用 Clip.none：懒加载 cacheExtent 里已构建的卡会画到行外。
    final double rowHeight = _continueRowHeight(context, tokens);
    final double liftHeadroom = rowHeight * (kFushiHoverLiftScale - 1) / 2;
    const double liftSideRoom =
        _kContinueCoverWidth * (kFushiHoverLiftScale - 1) / 2;
    return SizedBox(
      height: rowHeight + liftHeadroom * 2,
      // 桌面默认 MaterialScrollBehavior 的 dragDevices 不含鼠标——横排行
      // 用鼠标左右拖会毫无反应。共享件统一放开 mouse/trackpad/stylus 拖动
      // （与合集行 CollectionShelfRow 同款）；触屏行为不变。
      child: HorizontalDragScrollable(
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          // 卡片不能占满加高后的视口，否则会把放大余量也拉进卡体。
          // 两端留量，首尾卡放大时也能完整显示。
          padding: EdgeInsets.symmetric(
            vertical: liftHeadroom,
            horizontal: liftSideRoom,
          ),
          physics: desktopAwareScrollPhysics(),
          itemCount: entries.length,
          separatorBuilder: (BuildContext _, int __) =>
              SizedBox(width: tokens.spacing.gap),
          itemBuilder: (BuildContext context, int i) =>
              _buildContinueCard(tokens, appModel, entries[i]),
        ),
      ),
    );
  }

  /// 区块 4：「最近添加」横滑行（底部通栏，用户反馈「底部很空」的填充提案）：
  /// 本地书按 epub importedAt 倒序取前 12，复用继续卡组件（不画进度条，副标题=
  /// 「类型 · 相对时间」）。
  /// 无可排条目（空库/无时间戳）返回 null 不占位。
  Widget? _buildRecentlyAddedSection(
    FushiDesignTokens tokens,
    AppModel appModel,
    List<MediaItem> books,
    DateTime now,
  ) {
    final List<_ContinueEntry> entries = <_ContinueEntry>[];
    for (final MediaItem item in books) {
      final String? bookKey =
          ReaderFushiSource.parseBookKey(item.mediaIdentifier);
      final int addedMs =
          bookKey == null ? 0 : (_epubImportedAtByKey[bookKey] ?? 0);
      if (addedMs <= 0) continue;
      entries.add(_ContinueEntry(
        // BUG-1018 (A1)：与继续卡同一 override 显示名通道。
        title: ReaderFushiSource.instance.getDisplayTitleFromMediaItem(item),
        recentMs: addedMs,
        collectionName: statCollectionName(
          _bookCollectionKey(item),
          _primaryCollectionByEntry,
          _collectionNamesById,
        ),
        subtitleOverride:
            '${t.home_filter_read} · ${_relativeTimeLabel(addedMs, now)}',
        book: item,
      ));
    }
    if (entries.isEmpty) return null;
    entries.sort((_ContinueEntry a, _ContinueEntry b) =>
        b.recentMs.compareTo(a.recentMs));
    final List<_ContinueEntry> top = entries.take(12).toList();
    return _sectionCard(
      tokens,
      title: t.home_recently_added,
      child: _continueCardsRow(tokens, appModel, top),
    );
  }

  /// 书 [MediaItem] → 合集归属键：epub 用 uid（v83 成员表键；bookKey 经
  /// [_epubUidByBookKey] 换算，换算不上按 bookKey 回退——与透传成员行同键）；
  /// 识别不出回退 epub 键（查不中合集，安全降级）。
  String _bookCollectionKey(MediaItem item) {
    final String? bookKey =
        ReaderFushiSource.parseBookKey(item.mediaIdentifier);
    if (bookKey != null) {
      return MediaKind.epub.compositeKey(_epubUidByBookKey[bookKey] ?? bookKey);
    }
    // 有意的 miss-key 兜底：entryKey 是完整 hoshi:// 标识而非 bookKey，
    // 查不中合集，安全降级为散卡。
    return MediaKind.epub.compositeKey(item.mediaIdentifier);
  }

  /// 「继续」单卡（Jellyfin 式横滑卡）：上=封面（底部贴进度条），下=标题一行 +
  /// 灰副标题一行。显示名规则（非合集上下文拼合集名）：合集成员标题=合集名、
  /// 副标题=「条目名 · 状态」；散卡标题=条目名、副标题=状态（「阅读 · x%」）。
  ///
  /// 悬停抬升与书架同一个壳 [FushiHoverLift]（内含墨水屏与「减弱动态效果」两处
  /// 降级，以及 BUG-2124 的滚动压制）。
  Widget _buildContinueCard(
    FushiDesignTokens tokens,
    AppModel appModel,
    _ContinueEntry entry,
  ) {
    return FushiHoverLift(
      builder: (BuildContext _, bool __) =>
          _buildContinueCardBody(tokens, appModel, entry),
    );
  }

  Widget _buildContinueCardBody(
    FushiDesignTokens tokens,
    AppModel appModel,
    _ContinueEntry entry,
  ) {
    final bool eink = isEinkTheme(context);
    const double coverWidth = _kContinueCoverWidth;
    // 「最近添加」行覆盖状态段（类型 · 相对时间）；继续区恒 null 走默认。
    final String status =
        entry.subtitleOverride ?? '${t.home_filter_read} · ${entry.percent}%';
    final String? collectionName = entry.collectionName;
    final String title = collectionName ?? entry.title;
    final String subtitle =
        collectionName != null ? '${entry.title} · $status' : status;
    return SizedBox(
      width: coverWidth,
      child: InkWell(
        onTap: () => _openContinueEntry(appModel, entry),
        borderRadius: FushiBorderRadius.card,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ClipRRect(
              borderRadius: FushiBorderRadius.card,
              child: SizedBox(
                width: coverWidth,
                height: _kContinueCoverHeight,
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    _continueCover(tokens, appModel, entry),
                    // 进度条贴封面底部；算不出进度（progress==null）时不画。
                    if (entry.progress case final double progress)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: IgnorePointer(
                          // eink：半透明黑轨道压在封面上是抖动灰，改实心页面底色
                          // 轨道 + 前景色进度，黑白各自一段、无灰阶。
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 3,
                            backgroundColor: eink
                                ? tokens.surfaces.page
                                : Colors.black.withValues(alpha: 0.35),
                            color: eink
                                ? tokens.surfaces.onSurface
                                : tokens.surfaces.primary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            SizedBox(height: tokens.spacing.gap / 2),
            Text(
              title,
              // BUG-1184：书封宽只有 94px，单行放不下日文书名（行高已按两行算出，
              // 见 [_continueRowHeight]）。
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: tokens.type.listTitle,
            ),
            SizedBox(height: tokens.spacing.gap / 4),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tokens.type.metadata,
            ),
          ],
        ),
      ),
    );
  }

  /// 「继续」卡封面本体。
  Widget _continueCover(
    FushiDesignTokens tokens,
    AppModel appModel,
    _ContinueEntry entry,
  ) {
    return _bookCoverImage(
      tokens,
      ReaderFushiSource.instance.getDisplayThumbnailFromMediaItem(
        appModel: appModel,
        item: entry.book,
      ),
    );
  }

  /// 书封面：正常主题 700ms 淡入；eink 下直接出图——淡入是一串灰阶中间帧，
  /// 墨水屏上每帧都是一次局部刷新（残影）。`FadeInImage` 不接受零时长
  /// （TweenSequence 权重断言 > 0），所以不能靠 einkSafeDuration，只能换 widget。
  Widget _bookCoverImage(FushiDesignTokens tokens, ImageProvider image) {
    if (isEinkTheme(context)) {
      return Image(
        image: image,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            _coverPlaceholder(tokens, Icons.menu_book_outlined),
      );
    }
    return FadeInImage(
      placeholder: MemoryImage(kTransparentImage),
      image: image,
      fit: BoxFit.cover,
      imageErrorBuilder: (_, __, ___) =>
          _coverPlaceholder(tokens, Icons.menu_book_outlined),
    );
  }

  /// 封面占位：中性底色 + 图标（eink 下 card 色塌成页面底色，补描边免得只剩
  /// 一枚悬空图标）。
  Widget _coverPlaceholder(FushiDesignTokens tokens, IconData icon) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.surfaces.card,
        border: isEinkTheme(context)
            ? Border.all(color: tokens.surfaces.outline)
            : null,
      ),
      child: Center(child: Icon(icon, color: tokens.type.metadata.color)),
    );
  }

  /// 打开「继续」条目：本地书走 openMedia。
  Future<void> _openContinueEntry(
    AppModel appModel,
    _ContinueEntry entry,
  ) async {
    final MediaItem item = entry.book;
    final MediaSource source = item.getMediaSource(appModel: appModel);
    await appModel.openMedia(ref: ref, mediaSource: source, item: item);
  }

  /// 切到顶层 tab 的**唯一**出口。
  void _goToTab(HomeTab tab) {
    homeShellTabNotifier.value = tab;
  }

  // ── 区块 3：学习活动热力图 ───────────────────────────────────────────────

  /// 学习活动热力图卡（复用 [StatContributionHeatmap]，按每日字数铺格）：header
  /// 右侧进统计中心，格下加「今日目标」行，点选某日弹当日明细 sheet。
  Widget _buildHeatmapCard(FushiDesignTokens tokens) {
    final Map<String, int> charsByDay = _readCharsByDay;
    final Map<String, int> timeMsByDay = _readTimeMsByDay;
    final Widget card = _sectionCard(
      tokens,
      title: t.reading_activity,
      // 统计入口的唯一落点（用户定案 2026-09-01：各媒体页头的「xx统计」全部
      // 撤掉，统一从首页热力图卡右上进统计中心总览）。
      header: Row(
        children: <Widget>[
          const Spacer(),
          FushiIconButton(
            tooltip: t.stat_center_title,
            label: t.stat_center_title,
            icon: Icons.bar_chart_outlined,
            onTap: _openStatisticsCenter,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          StatContributionHeatmap(
            valueByDateKey: charsByDay,
            now: DateTime.now(),
            baseColor: tokens.surfaces.primary,
            // BUG-1073 病灶 1 根因：此前用 surfaces.card，与本卡底色
            // surfaces.group 在暗色主题下几乎同色（两个相邻的 surface 容器
            // 色阶）——「没活动的那些周」等于没画，观感是左边一大片死黑。改用
            // 色阶更高的 surfaces.overlay 才和卡底拉开对比，空周照样是
            // GitHub 式浅格子。BUG-1276：黑色/自定义主题仍可能把 surface 色阶
            // 压得过近，因此再用 outlineVariant 描边兜底；即使填充与卡底同色，
            // 53 周空格也不会重新融进背景。
            emptyColor: tokens.surfaces.overlay,
            emptyBorderColor: tokens.surfaces.outline,
            // 气泡 = 日期 · 字数 · 学习时长（时长为 0 的旧数据/纯导入日不显示
            // 时长段）。
            valueLabel: (String dateKey, int chars) {
              final int timeMs = timeMsByDay[dateKey] ?? 0;
              final String base =
                  '${formatStatHeatmapDay(dateKey)} · ${formatStatChars(chars)}';
              return timeMs > 0 ? '$base · ${formatStatTime(timeMs)}' : base;
            },
            onDaySelected: (String dateKey, int _) =>
                unawaited(_showDayDetailSheet(dateKey)),
          ),
          SizedBox(height: tokens.spacing.gap),
          _buildDailyGoalRow(tokens),
        ],
      ),
    );
    // 热力图是全仪表盘唯一有**天然最大宽度**的区块：网格列数封顶「一年」、格子边长
    // 封顶 maxCell，铺到 [statHeatmapMaxGridWidth]（1110）就到头了。整页 1600 限宽撤
    // 掉后（PR#675），3840 逻辑宽下这张卡被拉到 2244，而网格仍是 1110——右侧空出
    // 1134px，正是 BUG-1073 症状 3 在超宽屏复发。修法不是把整页限宽加回来（用户实报
    // 「首页左右强制的间距」要的就是铺满），而是只给这一块按内容的自然上限封顶，并
    // 左对齐保持与主列其余区块左边缘对齐。1920 及以下主列本就窄于该上限，此处无效果。
    return Align(
      alignment: AlignmentDirectional.centerStart,
      // ListView 给的高度约束无界，heightFactor: 1 让 Align 收敛到内容高度。
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: statHeatmapMaxGridWidth() + 2 * _sectionCardInset(tokens),
        ),
        child: card,
      ),
    );
  }

  /// 「今日目标」行：今日阅读字数 vs 每日字数目标（与阅读统计页目标卡同一持久化
  /// [AppModel.readingGoalDailyChars]、同一分子函数 [studyGoalCharsForDay]）。
  /// 目标为 0 → 只留设定入口按钮；否则进度条 + 「X / Y 字」，点击行弹编辑对话框。
  Widget _buildDailyGoalRow(FushiDesignTokens tokens) {
    final int goal = ref.read(appProvider).readingGoalDailyChars;
    if (goal <= 0) {
      // BUG-1073 病灶 2：此前是热力图下方孤零零一个左对齐按钮。改成与已设目标态
      // 同构的一整行（图标 + 标签 + 右侧入口），视觉上属于这张卡。口径说明按用户要求
      // 删除，标签退回「每日目标」本名。
      return Padding(
        padding: EdgeInsets.symmetric(vertical: tokens.spacing.gap / 2),
        child: Row(
          children: <Widget>[
            Icon(
              Icons.flag_outlined,
              size: 18,
              color: tokens.type.metadata.color,
            ),
            SizedBox(width: tokens.spacing.gap),
            Expanded(
              child: Text(
                t.stat_goal_daily,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: tokens.type.metadata,
              ),
            ),
            SizedBox(width: tokens.spacing.gap),
            TextButton(
              onPressed: () => unawaited(_editDailyGoal()),
              child: Text(t.stat_goal_set),
            ),
          ],
        ),
      );
    }
    // BUG-2219：与本轮加载的聚合同一个窗口（跨午夜由 [_midnightReload] 重拉）。
    final String todayKey = _statWindow.todayKey;
    final int todayChars = studyGoalCharsForDay(_readingRows, todayKey);
    final double fraction = (todayChars / goal).clamp(0.0, 1.0);
    return InkWell(
      onTap: () => unawaited(_editDailyGoal()),
      borderRadius: FushiBorderRadius.card,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: tokens.spacing.gap / 2),
        child: Row(
          children: <Widget>[
            Text(t.stat_goal, style: tokens.type.metadata),
            SizedBox(width: tokens.spacing.gap),
            Expanded(
              // eink：card 轨道色 == 页面底色，未完成段和 0% 态都看不见，进度条
              // 像一截长度不明的短棍；描一圈边把轨道全长画出来。
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: tokens.radii.chipRadius,
                  border: isEinkTheme(context)
                      ? Border.all(color: tokens.surfaces.outline)
                      : null,
                ),
                child: ClipRRect(
                  borderRadius: tokens.radii.chipRadius,
                  child: LinearProgressIndicator(
                    value: fraction,
                    minHeight: 6,
                    backgroundColor: tokens.surfaces.card,
                    color: tokens.surfaces.primary,
                  ),
                ),
              ),
            ),
            SizedBox(width: tokens.spacing.gap),
            Text(
              t.stat_goal_progress(read: todayChars, goal: goal),
              style: tokens.type.metadata,
            ),
          ],
        ),
      ),
    );
  }

  /// 弹每日字数目标编辑对话框（阅读统计页 _editGoals 的数字输入范式，只编辑每日
  /// 字数；0/清空 = 关闭目标）。写回 [AppModel.setReadingGoalDailyChars] 后
  /// setState 刷新目标行（与统计页读同一偏好，两处天然同步）。取消返回 null 不写。
  Future<void> _editDailyGoal() async {
    final AppModel appModel = ref.read(appProvider);
    final int? saved = await showDialog<int>(
      context: context,
      builder: (BuildContext _) => _DailyGoalDialog(
        initialChars: appModel.readingGoalDailyChars,
        recentDailyAverage: _recentDailyAverageChars(),
      ),
    );
    if (saved == null) return;
    await appModel.setReadingGoalDailyChars(saved < 0 ? 0 : saved);
    if (mounted) setState(() {});
  }

  /// 近 [days] 天（含今天）的日均字数，**与目标同口径**（学习域
  /// [studyGoalCharsForDay]）：给「我该填多少」一个真实参考值（BUG-1075）。
  /// 无数据日按 0 计入分母（真实反映日均，不是活跃日均）。
  int _recentDailyAverageChars({int days = 7}) {
    if (days <= 0) return 0;
    final StatWindow w = _statWindow;
    int total = 0;
    for (final String key in w.lastDayKeys(days)) {
      total += studyGoalCharsForDay(_readingRows, key);
    }
    return total ~/ days;
  }

  /// 统计中心入口（唯一入口：各媒体页头的「xx统计」已撤，统一从首页进总览）。
  void _openStatisticsCenter() {
    Navigator.push(
      context,
      adaptivePageRoute<void>(
        context: context,
        builder: (_) => const StatisticsCenterPage(),
      ),
    );
  }

  /// 点热力图某日 → 时段明细 sheet（阶段 1 统一组件 [showStatPeriodDetailSheet]：
  /// 单日=退化时段，与统计页时段卡同一实现——来源分节 + 合集分组 + 时长倒序 +
  /// 条目跳转）。
  Future<void> _showDayDetailSheet(String dateKey) async {
    final FushiDatabase db = ref.read(appProvider).database;
    final bool deleted = await showStatPeriodDetailSheet(
      context,
      periodLabel: formatStatHeatmapDay(dateKey),
      contains: (String key) => key == dateKey,
      facts: _readingRows,
      resolvers: StatPeriodDetailResolvers(
        titleOf: _statEntryTitle,
        collectionOf: _statEntryCollection,
        onEntryTap: _openStatEntry,
        onEntryDelete: (StatPeriodEntryTarget t) =>
            deleteStatPeriodEntry(db, t),
        ambiguousTitlesOf: (String kind) => kind == kActivityMediaBook
            ? _ambiguousBookTitles
            : const <String>{},
      ),
    );
    // 删过就重拉首页数据：热力图 / 今日目标 / 时间轴都吃同一份事实面。
    if (deleted && mounted) await _loadDashboardData();
  }

  /// 事实行 → 展示标题（合集名由 sheet 组头承担，这里**不**拼合集前缀）。
  /// 书行过 display-title 门面（改名 override 上屏生效）；legacy 行原样 title。
  String _statEntryTitle(StatFact f) {
    if (f.isBook) {
      final String? bookKey =
          f.mediaKey.isNotEmpty ? f.mediaKey : _bookKeyByTitle[f.title];
      if (bookKey == null) return f.title;
      return displayTitleForStatRow(
        rawTitle: f.title,
        bookKeyByTitle: <String, String>{f.title: bookKey},
      );
    }
    return f.title;
  }

  /// 事实行 → 所属合集名（v83 键契约：epub 经 bookKey→uid 换算）；解析不到返回 null
  /// 落「未分组」。
  String? _statEntryCollection(StatFact f) {
    if (f.isBook) {
      final String? bookKey =
          f.mediaKey.isNotEmpty ? f.mediaKey : _bookKeyByTitle[f.title];
      if (bookKey == null) return null;
      return statCollectionName(
        MediaKind.epub.compositeKey(_epubUidByBookKey[bookKey] ?? bookKey),
        _primaryCollectionByEntry,
        _collectionNamesById,
      );
    }
    return null;
  }

  /// 明细条目 → 打开对应的书；查不到的切书架 tab。
  Future<void> _openStatEntry(String mediaKind, String mediaKey) async {
    if (mediaKind != kActivityMediaBook) return;
    final AppModel appModel = ref.read(appProvider);
    if (mediaKey.isNotEmpty) {
      final List<MediaItem> books =
          ref.read(fushiBooksProvider(kShelfBooksKey)).valueOrNull ??
              const <MediaItem>[];
      for (final MediaItem item in books) {
        if (ReaderFushiSource.parseBookKey(item.mediaIdentifier) == mediaKey) {
          final MediaSource source = item.getMediaSource(appModel: appModel);
          await appModel.openMedia(ref: ref, mediaSource: source, item: item);
          return;
        }
      }
    }
    _goToTab(HomeTab.books);
  }

  // ── 区块 4：Activity 时间轴 ──────────────────────────────────────────────

  /// Activity 时间轴：顶部分类筛选 → 内存过滤 events → 纯函数聚合 → 按日期分组渲染。
  /// [booksByKey] 是「mediaKey → 本地书」反查映射（封面缩略 + 点击直达用；查不到
  /// 回退图标/切 tab）。
  Widget _buildActivitySection(
    FushiDesignTokens tokens,
    DateTime now,
    AppModel appModel,
    Map<String, MediaItem> booksByKey,
  ) {
    final List<(String?, String)> filterOptions =
        _visibleMediaFilterOptions<String?>(
          all: (null, t.home_filter_all),
          read: (kActivityRead, t.home_filter_read),
          // 「添加」跨全部媒体，不属任何单一模块，恒在。
          trailing: <(String?, String)>[(kActivityAdded, t.home_filter_added)],
        );
    final String? activeFilter = _effectiveFilter<String?>(
      _activityFilter,
      filterOptions,
      fallback: null,
    );
    final List<ActivityEventRow> filtered = activeFilter == null
        ? _activityEvents
        : _activityEvents
              .where((ActivityEventRow e) => e.eventType == activeFilter)
              .toList();
    final List<ActivityDateGroup> groups = aggregateActivityEvents(filtered);
    final String todayKey = FushiTimeFormat.dayKey(now);
    final String yesterdayKey =
        FushiTimeFormat.dayKey(now.subtract(const Duration(days: 1)));

    return _sectionCard(
      tokens,
      title: t.home_activity,
      header: filterOptions.length > 2
          ? _filterChips<String?>(
              tokens: tokens,
              selected: activeFilter,
              onSelected: (String? v) => setState(() {
                _activityFilter = v;
                _visibleActivityEntryCount = _kActivityPageSize;
              }),
              options: filterOptions,
            )
          : null,
      child: groups.isEmpty
          ? Text(t.home_activity_empty, style: tokens.type.metadata)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (final ActivityDateGroup g in takeActivityEntries(
                  groups,
                  _visibleActivityEntryCount,
                ))
                  _buildActivityGroup(tokens, g, todayKey, yesterdayKey, now,
                      appModel, booksByKey),
                if (groups.fold<int>(
                      0,
                      (int total, ActivityDateGroup group) =>
                          total + group.entries.length,
                    ) >
                    _visibleActivityEntryCount)
                  Align(
                    alignment: AlignmentDirectional.center,
                    child: TextButton.icon(
                      onPressed: () => setState(() {
                        _visibleActivityEntryCount += _kActivityPageSize;
                      }),
                      icon: const Icon(Icons.expand_more),
                      label: Text(t.discovery_load_more),
                    ),
                  ),
              ],
            ),
    );
  }

  /// 单个日期分组：日期头 + 该日的条目。
  Widget _buildActivityGroup(
    FushiDesignTokens tokens,
    ActivityDateGroup group,
    String todayKey,
    String yesterdayKey,
    DateTime now,
    AppModel appModel,
    Map<String, MediaItem> booksByKey,
  ) {
    final String label;
    if (group.dateKey == todayKey) {
      label = t.home_today;
    } else if (group.dateKey == yesterdayKey) {
      label = t.home_yesterday;
    } else {
      label = formatStatHeatmapDay(group.dateKey);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: EdgeInsets.only(
            top: tokens.spacing.gap,
            bottom: tokens.spacing.gap / 2,
          ),
          child: Text(label, style: tokens.type.sectionLabel),
        ),
        for (final ActivityEntry e in group.entries)
          _buildActivityEntry(tokens, e, now, appModel, booksByKey),
      ],
    );
  }

  /// 单条活动：前置封面缩略（命中本地条目；否则类型图标）+ 标题（粗）+ 副行
  /// （动作词 · 相对时间 · [时长] · [session 数]）。整行可点：命中本地条目直接
  /// 打开（书 openMedia），查不到回退切 tab。
  Widget _buildActivityEntry(
    FushiDesignTokens tokens,
    ActivityEntry entry,
    DateTime now,
    AppModel appModel,
    Map<String, MediaItem> booksByKey,
  ) {
    final List<String> parts = <String>[
      _actionWord(entry.eventType),
      _relativeTimeLabel(entry.latestTimestampMs, now),
      if (entry.totalDurationMs > 0) formatStatTime(entry.totalDurationMs),
      if (entry.sessionCount > 1) t.home_session_count(n: entry.sessionCount),
    ];
    return InkWell(
      onTap: () => unawaited(_openActivityEntry(appModel, entry, booksByKey)),
      borderRadius: FushiBorderRadius.card,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: tokens.spacing.gap / 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _activityLeading(tokens, appModel, entry, booksByKey),
            SizedBox(width: tokens.spacing.gap + 4),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    _activityDisplayTitle(entry),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: tokens.type.listTitle,
                  ),
                  SizedBox(height: tokens.spacing.gap / 2),
                  Text(
                    parts.join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tokens.type.metadata,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// BUG-1018 (A1)：活动条**渲染时**应用书的 override 书名（编辑对话框改名后时间轴
  /// 同步显示新名）。events 落库仍存 DB 原名（历史数据身份，聚合键不变），只在这里
  /// 按 [ActivityEntry.mediaKey]（书=bookKey）查 override 替换显示。
  /// 命中合集时再拼「合集名 - 名字」（显示名规则：非合集上下文拼合集名；override
  /// 后的名字再拼前缀）。
  String _activityDisplayTitle(ActivityEntry entry) {
    if (entry.mediaType == kActivityMediaBook) {
      final String? bookKey = entry.mediaKey;
      if (bookKey != null && bookKey.isNotEmpty) {
        final String title =
            ReaderFushiSource.instance.overrideTitleForBookKey(bookKey) ??
                entry.title;
        // v83：合集成员表 epub 键 = uid（mediaKey 的 bookKey 经换算表转一跳）。
        final String? collectionName = statCollectionName(
          MediaKind.epub.compositeKey(_epubUidByBookKey[bookKey] ?? bookKey),
          _primaryCollectionByEntry,
          _collectionNamesById,
        );
        return collectionName == null ? title : '$collectionName - $title';
      }
      return entry.title;
    }
    return entry.title;
  }

  /// 活动条前置视觉：命中本地书用封面缩略（40×56 竖版，圆角裁切，与继续卡同源
  /// 取图），查不到（已删/导入无封面）回退原类型图标（用户反馈时间轴只有小图标
  /// 认不出条目）。
  Widget _activityLeading(
    FushiDesignTokens tokens,
    AppModel appModel,
    ActivityEntry entry,
    Map<String, MediaItem> booksByKey,
  ) {
    final String? key = entry.mediaKey;
    if (key != null && key.isNotEmpty) {
      if (entry.mediaType == kActivityMediaBook) {
        final MediaItem? book = booksByKey[key];
        if (book != null) {
          return ClipRRect(
            borderRadius: FushiBorderRadius.card,
            child: SizedBox(
              width: 40,
              height: 56,
              child: _bookCoverImage(
                tokens,
                resolveMediaCoverImage(
                  kind: MediaKind.epub,
                  book: book,
                  appModel: appModel,
                  decodeWidth: kActivityCoverDecodePixelWidth,
                )!,
              ),
            ),
          );
        }
      }
    }
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Icon(
        _activityIcon(entry.eventType),
        size: 20,
        color: tokens.surfaces.primary,
      ),
    );
  }

  /// 点击活动条：命中本地书**直接打开**（openMedia）；打不开的切书架 tab。
  Future<void> _openActivityEntry(
    AppModel appModel,
    ActivityEntry entry,
    Map<String, MediaItem> booksByKey,
  ) async {
    final String? key = entry.mediaKey;
    if (key != null &&
        key.isNotEmpty &&
        entry.mediaType == kActivityMediaBook) {
      final MediaItem? book = booksByKey[key];
      if (book != null) {
        final MediaSource source = book.getMediaSource(appModel: appModel);
        await appModel.openMedia(ref: ref, mediaSource: source, item: book);
        return;
      }
    }
    if (entry.eventType == kActivityRead ||
        entry.mediaType == kActivityMediaBook) {
      _goToTab(HomeTab.books);
    }
  }

  /// 事件类型 → 动作词（i18n）。
  String _actionWord(String eventType) {
    switch (eventType) {
      case kActivityRead:
        return t.home_filter_read;
      case kActivityAdded:
        return t.home_filter_added;
      default:
        return t.home_filter_all;
    }
  }

  /// 事件类型 → 前置图标。
  IconData _activityIcon(String eventType) {
    switch (eventType) {
      case kActivityRead:
        return Icons.menu_book;
      case kActivityAdded:
        return Icons.add_circle_outline;
      default:
        return Icons.menu_book;
    }
  }

  /// 相对时间结构化结果 → i18n 文案（口径与 Bangumi 同步卡共用，见
  /// [formatActivityRelativeTime]）。
  String _relativeTimeLabel(int timestampMs, DateTime now) =>
      formatActivityRelativeTime(timestampMs, now);

  // ── 共享外壳 ────────────────────────────────────────────────────────────

  /// 统一的分区卡：标题（+ 可选右侧 header 控件）+ 内容，套 group 底色圆角。
  /// [_sectionCard] 的内边距。单独抽出来是因为 [_buildHeatmapCard] 要按「网格自然
  /// 最大宽度 + 两侧内边距」给卡片限宽，两处必须用同一个值。
  double _sectionCardInset(FushiDesignTokens tokens) => tokens.spacing.gap + 4;

  Widget _sectionCard(
    FushiDesignTokens tokens, {
    required String title,
    required Widget child,
    Widget? header,
  }) {
    // eink：group 面层塌缩成页面底色，分区卡（学习活动 / 继续 / 最近添加 /
    // 动态）的边界全没了，整页读成一根连续的列；补 1px 描边（FushiCard 同款）。
    final bool eink = isEinkTheme(context);
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: tokens.surfaces.group,
        shape: RoundedRectangleBorder(
          borderRadius: FushiBorderRadius.card,
          side: eink
              ? BorderSide(color: tokens.surfaces.outline)
              : BorderSide.none,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(_sectionCardInset(tokens)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(title, style: tokens.type.sectionLabel),
            if (header != null) ...<Widget>[
              SizedBox(height: tokens.spacing.gap),
              Align(alignment: Alignment.centerLeft, child: header),
            ],
            SizedBox(height: tokens.spacing.gap),
            child,
          ],
        ),
      ),
    );
  }

  /// 活动时间轴筛选条：「全部」恒是第 0 项，其后「阅读」与 [trailing]（「添加」档）。
  List<(T, String)> _visibleMediaFilterOptions<T>({
    required (T, String) all,
    required (T, String) read,
    List<(T, String)>? trailing,
  }) => <(T, String)>[
    all,
    read,
    ...?trailing,
  ];

  /// 选中档被模块开关滤掉时回落到 [fallback]（恒是「全部」档）。
  ///
  /// 只在渲染期换算、**不写回** `_activityFilter` 状态字段：build 里 setState 会重入，而且用户把模块开回来时
  /// 原来的选择应该自然复活。回落本身是硬要求——选中值不在选项里，Cupertino 分段
  /// 控件会直接 assert。
  static T _effectiveFilter<T>(
    T selected,
    List<(T, String)> options, {
    required T fallback,
  }) => options.any(((T, String) option) => option.$1 == selected)
      ? selected
      : fallback;

  /// 泛型筛选 chip 行：[ChoiceChip] 的 [Wrap]（窄屏自动换行，不溢出）。
  Widget _filterChips<T>({
    required FushiDesignTokens tokens,
    required T selected,
    required ValueChanged<T> onSelected,
    required List<(T value, String label)> options,
  }) {
    return Wrap(
      spacing: tokens.spacing.gap,
      runSpacing: tokens.spacing.gap / 2,
      children: <Widget>[
        for (final (T value, String label) in options)
          ChoiceChip(
            label: Text(label),
            selected: selected == value,
            onSelected: (bool isSelected) {
              if (isSelected) onSelected(value);
            },
          ),
      ],
    );
  }
}
