import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:fushi_engine/epub/epub_book.dart';
import 'package:fushi/src/focus/fushi_focus_scroll.dart';
import 'package:fushi/src/media/book/book_search.dart';
import 'package:fushi_reading/fushi_reading.dart';
import 'package:fushi/src/media/sources/reader_fushi_source.dart';
import 'package:fushi/src/models/app_model.dart';
import 'package:fushi/src/pages/implementations/book_css_editor_page.dart';
import 'package:fushi/src/reader/reader_settings_side_dialog.dart';
import 'package:fushi/src/reader/reader_desktop_chrome.dart'
    show ReaderSideSheet;
import 'package:fushi/src/reader/ttu_toc_flatten.dart'
    show resolveCurrentTocEntry;
import 'package:fushi/src/settings/material_settings_renderer.dart';
import 'package:fushi/src/settings/settings_actions.dart';
import 'package:fushi/src/settings/settings_context.dart';
import 'package:fushi/src/settings/settings_destination.dart';
import 'package:fushi/src/settings/settings_renderer.dart';
import 'package:fushi/src/settings/settings_schema.dart';
import 'package:fushi/utils.dart';

/// 面板的呈现形态。
enum ReaderQuickSettingsPresentation {
  /// 左侧抽屉「导航」：阅读进度 + 书内搜索 + 按字数跳转 + 章节列表 + 收藏。
  sideSheetNavigation,

  /// 右侧抽屉「设置」。
  sideSheetAppearance,
}

/// 章节列表的同合集卷切换接线（BUG-2521）。[labels] 是各卷标题（与
/// [currentIndex] 同序）；[tocOf] 取某卷目录（兄弟卷在 isolate 解析、按卷缓存，
/// 不可查看的卷返回空表）；[onJump] 切到某卷（[chapterIndex] null = 按该卷保存
/// 位置打开）——切书本身由阅读器页面走完整退出链后 pushReplacement。
class ReaderTocVolumeSwitch {
  const ReaderTocVolumeSwitch({
    required this.labels,
    required this.currentIndex,
    required this.tocOf,
    required this.onJump,
  });

  final List<String> labels;
  final int currentIndex;
  final Future<List<TtuTocEntry>> Function(int volume) tocOf;
  final Future<void> Function(int volume, int? chapterIndex) onJump;
}

class ReaderQuickSettingsSheet extends StatefulWidget {
  const ReaderQuickSettingsSheet({
    required this.toc,
    required this.readerProgress,
    required this.onJumpSection,
    this.readerCharOffset,
    required this.appModel,
    required this.ref,
    this.onThemeChanged,
    this.favoriteSentences = const [],
    this.favoritePositionLabel,
    this.onDeleteFavorite,
    this.onJumpToFavorite,
    this.onPlayFavorite,
    this.extraLocationSection,
    this.onSearchJump,
    this.onJumpToCharOffset,
    this.charProgress,
    this.onPageMarginChanged,
    this.isFushiReader = false,
    this.epubBook,
    this.chapterLabel,
    this.onStyleChanged,
    this.extractDir,
    this.onReloadChapter,
    this.autofocusSearch = false,
    this.initialSideSheetTab = 'layout',
    this.onSideSheetTabChanged,
    this.expandedTocParents,
    this.volumeSwitch,
    this.initialSubPage,
    required this.presentation,
    this.onClose,
    this.coverPath,
    super.key,
  });

  final List<TtuTocEntry> toc;

  /// 0-indexed section index and total chapter count.
  final (int section, int total)? readerProgress;

  /// 当前章内的字符偏移（`countStudyChars` 口径，与 [TtuTocEntry.anchorCharOffset]
  /// 同尺），未知为 null。同一 spine 章下靠锚点分节的多条目录项只有它能分清
  /// 读到哪一条。
  final int? readerCharOffset;

  /// 跳到目录条目。[fragment] 是该条目的章内锚（[TtuTocEntry.fragment]），
  /// 同一 spine 章下的多个目录项只有它能区分，为 null 时就是跳到章首。
  final Future<void> Function(int sectionIndex, String? fragment) onJumpSection;
  final AppModel appModel;

  /// Riverpod ref from the reader page, forwarded to the schema-projected
  /// settings so [SettingsContext] always has a real [WidgetRef].
  final WidgetRef ref;
  final Future<void> Function()? onThemeChanged;
  final List<FavoriteSentence> favoriteSentences;

  /// 收藏行「阅读位置」标签（如 `78.6%`）解析器，由阅读器页面用每章字符账本折算全书
  /// 进度。返回 null 时该行不显示位置（账本未就绪 / 无 sectionIndex）。
  final String? Function(FavoriteSentence fav)? favoritePositionLabel;
  final Future<void> Function(FavoriteSentence fav)? onDeleteFavorite;
  final Future<void> Function(FavoriteSentence fav)? onJumpToFavorite;
  final Future<void> Function(FavoriteSentence fav)? onPlayFavorite;

  /// Shown last in the navigation sheet's location section (the Kitapsen
  /// edition's bookmarks and notes).
  final Widget? extraLocationSection;
  final Future<void> Function(BookSearchResult result, String query)?
      onSearchJump;
  final Future<void> Function(int globalCharOffset)? onJumpToCharOffset;
  final (int current, int total)? charProgress;
  final VoidCallback? onPageMarginChanged;

  /// Called after any display/style setting changes so the reader can
  /// live-update CSS without a full page reload.
  final Future<void> Function()? onStyleChanged;

  /// When true, skip BookSearch JS calls and disable ttu-only features.
  final bool isFushiReader;

  final EpubBook? epubBook;

  /// 当前章节名（由阅读器页面经 TOC 反查得到），用于阅读进度区块展示。
  final String? chapterLabel;

  final String? extractDir;
  final Future<void> Function()? onReloadChapter;

  /// 导航抽屉打开即把焦点放进书内搜索框（Ctrl+F 的语义就是要搜）。
  final bool autofocusSearch;


  /// 桌面端右侧设置抽屉初始分组（页面记忆上次打开的 tab）。
  final String initialSideSheetTab;
  final ValueChanged<String>? onSideSheetTabChanged;

  /// 目录折叠状态的会话记忆（页面持有的可变集合；null 则本面板自持）。
  final Set<String>? expandedTocParents;

  /// 同合集卷切换（BUG-2521）：目录区顶部出卷 chip，看别的卷的目录不离开面板、
  /// 点别的卷的章才真正切书。null = 不在多卷合集里，目录区与从前一样。
  final ReaderTocVolumeSwitch? volumeSwitch;

  /// TODO-1309①：打开面板时直达的子页 id（如 'location' 导航子页）。null =
  /// 默认落主菜单（窄窗）/ 默认分类（宽窗）。仅用于初始化 [_subPage]，
  /// 之后由用户导航自行覆盖。
  final String? initialSubPage;

  /// 呈现形态（桌面端右侧抽屉 vs 既有 sheet），见 [ReaderQuickSettingsPresentation]。
  final ReaderQuickSettingsPresentation presentation;

  /// 抽屉形态的关闭回调（标题行 ×）。sheet 形态不用（由外壳路由自行关闭）。
  final VoidCallback? onClose;

  /// 书籍封面文件路径（有声书面板左侧显示；null 不显示）。
  final String? coverPath;

  @override
  State<ReaderQuickSettingsSheet> createState() =>
      _ReaderQuickSettingsSheetState();
}

class _ReaderQuickSettingsSheetState extends State<ReaderQuickSettingsSheet>
    with
        SettingsContextHost<ReaderQuickSettingsSheet>,
        SingleTickerProviderStateMixin {

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _charJumpController = TextEditingController();
  List<BookSearchResult> _searchResults = const [];
  String _searchResultsQuery = '';
  int _searchGeneration = 0;
  bool _isSearching = false;
  bool _layoutReloading = false;


  /// 桌面端右侧「设置」抽屉当前展开的分组 id（初值来自页面记忆）。
  late String _sideSheetTab = widget.initialSideSheetTab;

  /// 「设置」抽屉标签栏的控制器，仅 [ReaderQuickSettingsPresentation.sideSheetAppearance]
  /// 形态首次 build 时创建（其余形态没有标签栏）。
  TabController? _sideSheetTabController;

  /// 导航抽屉里当前章那一行的 key：打开时滚到它。
  final GlobalKey _currentTocRowKey = GlobalKey();

  /// 目录里手动展开的父节（按父节 label）；深度 >= 2 的子节默认折叠，当前章所在的
  /// 父节自动展开。
  late final Set<String> _expandedTocParents =
      widget.expandedTocParents ?? <String>{};

  /// 目录区当前查看的卷（初值 = 当前卷）。只影响列表内容，不影响阅读器。
  late int _viewedVolume = widget.volumeSwitch?.currentIndex ?? 0;


  late List<FavoriteSentence> _favorites =
      List<FavoriteSentence>.of(widget.favoriteSentences);

  @override
  void dispose() {
    _sideSheetTabController?.dispose();
    _searchController.dispose();
    _charJumpController.dispose();
    super.dispose();
  }

  Future<void> _updateSetting(String key, Object value) async {
    final ReaderFushiSource src = ReaderFushiSource.instance;
    switch (key) {
      case 'fontSize':
        await src.setReaderFontSize((value as num).toDouble());
      case 'lineHeight':
        await src.setReaderLineHeight((value as num).toDouble());
      case 'writingMode':
        await src.setReaderWritingMode(value as String);
        widget.onPageMarginChanged?.call();
      case 'viewMode':
        await src.setReaderViewMode(value as String);
      case 'theme':
        await src.setReaderTheme(value as String);
      case 'hideFurigana':
      case 'textIndentation':
        await src.setReaderTextIndentation((value as num).toDouble());
      case 'marginTop':
        await src.setReaderMarginTop((value as num).toDouble());
        widget.onPageMarginChanged?.call();
      case 'marginBottom':
        await src.setReaderMarginBottom((value as num).toDouble());
        widget.onPageMarginChanged?.call();
      case 'marginLeft':
        await src.setReaderMarginLeft((value as num).toDouble());
        widget.onPageMarginChanged?.call();
      case 'marginRight':
        await src.setReaderMarginRight((value as num).toDouble());
        widget.onPageMarginChanged?.call();
      case 'pageColumns':
        await src.setReaderPageColumns((value as num).toInt());
      case 'spreadMode':
        await src.setReaderSpreadMode(value as String);
      case 'spreadDirection':
        await src.setReaderSpreadDirection(value as String);
      case 'enableVerticalFontKerning':
        await src.setReaderEnableVerticalFontKerning(value as bool);
      case 'enableFontVPAL':
        await src.setReaderEnableFontVPAL(value as bool);
      case 'verticalTextOrientation':
        await src.setReaderVerticalTextOrientation(value as String);
      case 'enableTextJustification':
        await src.setReaderEnableTextJustification(value as bool);
      case 'prioritizeReaderStyles':
        await src.setReaderPrioritizeReaderStyles(value as bool);
    }
    if (widget.isFushiReader) {
      const layoutKeys = {
        'writingMode',
        'viewMode',
        'pageColumns',
        'spreadMode',
        'spreadDirection',
        'prioritizeReaderStyles'
      };
      if (layoutKeys.contains(key)) {
        await _reloadLayoutLive();
      } else {
        await widget.onStyleChanged?.call();
      }
    }
  }

  Future<void> _reloadLayoutLive() async {
    final Future<void> Function()? reload = widget.onReloadChapter;
    if (reload == null || _layoutReloading) return;
    _layoutReloading = true;
    try {
      await reload();
    } finally {
      _layoutReloading = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return switch (widget.presentation) {
      ReaderQuickSettingsPresentation.sideSheetNavigation =>
        _buildNavigationSideSheet(context, theme),
      ReaderQuickSettingsPresentation.sideSheetAppearance =>
        _buildAppearanceSideSheet(context, theme),
    };
  }

  VoidCallback _sideSheetClose(BuildContext context) =>
      widget.onClose ?? () => Navigator.of(context).maybePop();

  /// 桌面端右侧抽屉「导航」：进度 + 既有的导航子页内容（搜索 / 字数跳转 / 章节 / 收藏）。
  Widget _buildNavigationSideSheet(BuildContext context, ThemeData theme) {
    final FushiDesignTokens tokens = FushiDesignTokens.of(context);
    final double sectionGap = tokens.spacing.gap + tokens.spacing.gap / 2;
    final Widget progress = _buildProgressSection(theme);
    // 打开即滚到当前章那一行（首帧后；行不存在时 no-op）。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final BuildContext? rowContext = _currentTocRowKey.currentContext;
      if (rowContext == null || !mounted) return;
      FushiFocusScroll.ensureVisible(
        rowContext,
        alignment: 0.3,
        duration: const Duration(milliseconds: 160),
      );
    });
    return ReaderSideSheet(
      title: t.section_navigation,
      onClose: _sideSheetClose(context),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (progress is! SizedBox) ...[
            progress,
            SizedBox(height: sectionGap),
          ],
          _buildLocationSection(theme),
        ],
      ),
    );
  }

  /// 「设置」抽屉的标签页：导航有自己的面板，不在这里。
  List<({String id, IconData icon, String label})> _sideSheetCategories() {
    return _wideCategories().where((cat) => cat.id != 'location').toList();
  }

  TabController _ensureSideSheetTabController(
    List<({String id, IconData icon, String label})> cats,
  ) {
    final TabController? existing = _sideSheetTabController;
    if (existing != null) return existing;
    final int initial = cats.indexWhere((cat) => cat.id == _sideSheetTab);
    final TabController controller = TabController(
      length: cats.length,
      initialIndex: initial < 0 ? 0 : initial,
      vsync: this,
    );
    controller.addListener(() {
      // 点标签时动画开始、结束各通知一次，只认落定后那次；滑动切页只通知落定。
      if (controller.indexIsChanging) return;
      final String id = cats[controller.index].id;
      if (id == _sideSheetTab) return;
      // 换页由 TabBarView 自己完成，这里只记账、交给页面记忆，不必重建整个面板。
      _sideSheetTab = id;
      widget.onSideSheetTabChanged?.call(id);
    });
    return _sideSheetTabController = controller;
  }

  /// 右侧抽屉「设置」：标题下固定一条标签栏，每个标签页各自滚动、切走再切回保留
  /// 滚动位置，避免几十行全部纵向平铺。
  Widget _buildAppearanceSideSheet(BuildContext context, ThemeData theme) {
    final FushiDesignTokens tokens = FushiDesignTokens.of(context);
    final List<({String id, IconData icon, String label})> cats =
        _sideSheetCategories();
    final TabController controller = _ensureSideSheetTabController(cats);
    return ReaderSideSheet(
      title: t.reader_settings_section,
      headerActions: const <Widget>[ReaderSettingsSideButton()],
      onClose: _sideSheetClose(context),
      scrollable: false,
      // 与库页 / 下载页同一个分区导航组件：整排是单个焦点停靠点（方向键 / 手柄
      // 左右切页），按文案取宽、放不下横向滚动（桌面可鼠标拖），并与下方
      // TabBarView 共用同一个 controller，横滑时指示器跟手。
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            // 首个页签文字与标题左缘对齐（标题左留白 20 = 4 + tab 自带的 16）。
            padding: const EdgeInsetsDirectional.only(start: 4, end: 4),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: LibrarySectionTabs<String>.controlled(
                key: const ValueKey<String>('fushi_side_sheet_tabs'),
                tabs: <LibrarySectionTab<String>>[
                  for (final cat in cats)
                    LibrarySectionTab<String>(value: cat.id, label: cat.label),
                ],
                controller: controller,
                focusIdPrefix: 'reader-settings-tab',
              ),
            ),
          ),
          const Divider(height: 1),
        ],
      ),
      child: TabBarView(
        controller: controller,
        children: <Widget>[
          // 每页一个独立滚动视图（PageStorageKey 记住各自的滚动位置）；页面离屏即
          // 卸载，切换时整棵内容子树重建，不会复用上一页同位置 Element 的
          // Switch / Segmented 动画副作用。
          for (final cat in cats)
            SingleChildScrollView(
              key: PageStorageKey<String>('fushi_side_sheet_tab_${cat.id}'),
              padding: ReaderSideSheet.defaultPadding.copyWith(
                top: tokens.spacing.gap + tokens.spacing.gap / 2,
              ),
              child: _buildSideSheetTabContent(context, cat.id),
            ),
        ],
      ),
    );
  }

  Widget _buildSideSheetTabContent(BuildContext context, String tab) {
    final Widget content = _subPageContent(tab);
    return content;
  }

  /// 面板分类项（id 与 [_subPageContent] 的 case 对齐）：设置抽屉标签栏、有声书
  /// 面板与窄窗主页共用同一份顺序。
  /// audiobook 仅在有 controller 时出现。
  List<({String id, IconData icon, String label})> _wideCategories() {
    // TODO-725 / TODO-802：导航置首（location → layout → behavior → lookup →
    // [audiobook]）。「外观」组已删，主题选择器并入 layout（见 _buildLayoutDetail）。
    // 与窄窗主页 navigationRows 顺序保持一致。
    return <({String id, IconData icon, String label})>[
      (
        id: 'location',
        icon: Icons.menu_book_outlined,
        label: t.section_navigation,
      ),
      (
        id: 'layout',
        icon: Icons.auto_stories_outlined,
        label: t.section_layout
      ),
      (
        id: 'behavior',
        icon: Icons.touch_app_outlined,
        label: t.settings_destination_reading_controls,
      ),
    ];
  }



  /// 某分类的详情内容（不含返回页头）。窄窗 push 子页与宽窗右 pane 共用。
  Widget _subPageContent(String page) {
    switch (page) {
      case 'layout':
        // Lyrics mode keeps its bespoke font/margin controls — those are not
        // schema items (they write lyrics-only `setLyrics*` setters) — but still
        // exposes the theme selector + book-CSS row via _buildLyricsDisplaySection
        // so the theme/CSS stay reachable after the appearance group was dropped
        // (TODO-802 reachability).
        return _buildLayoutDetail();
      case 'behavior':
        return _buildReaderGroupContent(
          ReaderGroup.behavior,
          t.settings_destination_reading_controls,
        );
      case 'location':
        return _buildLocationSection(Theme.of(context));
      default:
        return const SizedBox.shrink();
    }
  }


  /// 把某个 [ReaderGroup] 投影成 schema 渲染内容。写路径走 schema item 的
  /// `setReaderPref*` + notify helper，与本面板的 `_updateSetting` 落同一存储。
  ///
  /// 实时更新由 notify helper 经 `ReaderFushiSource` 的回调驱动，且是按 key
  /// 精确的：CSS-only key 走 `notifyReaderSettingsChanged`（=
  /// `onSettingsChangedLive`，CSS 注入），结构性布局 key（view mode / writing
  /// mode / columns / spread / prioritize reader styles）走
  /// `notifyReaderLayoutChanged`（= `onLayoutReloadLive`，整章重排）。schema
  /// 投影项实时从 `ReaderFushiSource.instance` 读写，本 refresh 回调只需
  /// setState 重读 live 值即可。
  SettingsContext _settingsContext() {
    return createSettingsContext(appModel: widget.appModel, ref: widget.ref);
  }

  Widget _buildReaderGroupContent(ReaderGroup group, String title) {
    final SettingsContext settingsContext = _settingsContext();
    return _buildSettingsDestinationContent(
      settingsContext,
      buildReaderGroupDestination(settingsContext, group, title),
    );
  }

  Widget _buildSettingsDestinationContent(
    SettingsContext settingsContext,
    SettingsDestination destination,
  ) {
    const SettingsRenderer renderer = MaterialSettingsRenderer();
    return renderer.buildDetailContent(
      settingsContext: settingsContext,
      destination: destination,
      shrinkWrap: true,
      // 本面板已在外层 SingleChildScrollView 提供横向 padding（widePanePadding /
      // narrowPadding）；让渲染器别再自带横向缩进，否则 schema 投影子页（布局 / 阅读
      // 控制 / 查词）会双重缩进、比 bespoke 的「导航 / 有声书」子页更窄（TODO-1321）。
      insetHorizontally: false,
    );
  }

  /// 主题行专用 [SettingsContext]：换肤后除 setState 外还要 `_syncThemeSelection`
  /// （把 appThemeKey 落 reader 设置 + 触发 `onThemeChanged` 的词典/歌词联动）。
  /// 与 appearance 其它行的普通 `_settingsContext()` 区分，故单列一个工厂。
  SettingsContext _themeSettingsContext() {
    return createSettingsContext(
      appModel: widget.appModel,
      ref: widget.ref,
      beforeRefresh: () => unawaited(_syncThemeSelection()),
    );
  }

  Future<void> _syncThemeSelection() async {
    await _updateSetting('theme', widget.appModel.appThemeKey);
    await widget.onThemeChanged?.call();
  }

  /// 主题选择器卡。TODO-802：「外观」组删除后，主题（阅读纸张配色，改的也是阅读
  /// 显示）并入「布局与显示」子页顶部；普通布局子页与歌词模式子页共用此卡，保证
  /// 删外观组后主题仍可达。主题行用专门的 [_themeSettingsContext]（换肤后还要
  /// `_syncThemeSelection` 落 reader 设置 + 触发词典/歌词联动）。
  Widget _buildThemeSelectorSection() {
    // 主题卡与下方 layout schema section 并列同一 Column（见 _buildLayoutDetail）。
    // schema section 现走 buildDetailContent(insetHorizontally:false)，横向留白全部
    // 由本面板外层 padding 统一提供，schema 正文不再自带横向缩进；主题卡也裸放（无额
    // 外 Padding）即可与配置行、以及同面板 bespoke 的「导航 / 有声书」子页左右等宽、
    // 同为宽版（BUG-545/546 的等宽仍成立，只是统一到更宽的外层 padding 宽度，TODO-1321）。
    return AdaptiveSettingsSection(
      children: <Widget>[
        buildThemeSelector(_themeSettingsContext()),
        buildBrightnessSelector(_themeSettingsContext()),
      ],
    );
  }

  /// 「编辑书籍 CSS」入口行。归类语义对齐：CSS 改的是排版（字号/行高/边距等同
  /// 一维度），属「布局与显示」组而非「外观」，故随 layout 子页渲染（窄窗 push
  /// 子页 + 宽窗右 pane 共用）。仅当书籍解压目录可用（`extractDir != null`）时
  /// 出现；点击打开 [BookCssEditorPage]，返回后整章重排以应用新 CSS。
  Widget _buildBookCssEditorRow() {
    return AdaptiveSettingsNavigationRow(
      title: t.book_css_editor_edit_css,
      icon: Icons.code_outlined,
      onTap: () async {
        await Navigator.push(
          context,
          adaptivePageRoute(
            context: context,
            builder: (_) => BookCssEditorPage(extractDir: widget.extractDir!),
          ),
        );
        await _reloadLayoutLive();
      },
    );
  }

  /// 「编辑书籍 CSS」入口行的外层 section。与主题卡（`_buildThemeSelectorSection`）
  /// 同构：普通布局子页与歌词模式子页里，它与走 `buildDetailContent` 的 schema
  /// section（layout 配置项组）并列同一 Column。schema 正文现走
  /// `insetHorizontally:false`、不再自带横向缩进，横向留白由本面板外层 padding 统一
  /// 提供，故 CSS 入口条裸放 section 即与配置行等宽（BUG-573），且与 bespoke 的
  /// 「导航 / 有声书」子页同为宽版（TODO-1321）。
  Widget _buildBookCssEditorSection() {
    // 与 _buildThemeSelectorSection 同理：CSS 入口条裸放即可与上方 layout 配置行、
    // 以及 bespoke 的「导航 / 有声书」子页左右等宽、同为宽版。横向留白由本面板外层
    // padding 统一提供，schema 正文经 insetHorizontally:false 不再自带横向缩进
    // （BUG-573 的等宽仍成立，统一到更宽的外层 padding 宽度，TODO-1321）。
    return AdaptiveSettingsSection(
      children: <Widget>[_buildBookCssEditorRow()],
    );
  }

  /// 「布局与显示」子页详情：主题选择器（TODO-802 并入）→ layout schema 行 →
  /// 可选「编辑书籍 CSS」行。窄窗 push 子页与宽窗右 pane 共用（经
  /// [_subPageContent] 的 'layout' 分支）。
  Widget _buildLayoutDetail() {
    final Widget layoutContent =
        _buildReaderGroupContent(ReaderGroup.layout, t.section_layout);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _buildThemeSelectorSection(),
        layoutContent,
        if (widget.extractDir != null) _buildBookCssEditorSection(),
      ],
    );
  }

  Widget _buildLocationSection(ThemeData theme) {
    final FushiDesignTokens tokens = FushiDesignTokens.of(context);
    final double sectionGap = tokens.spacing.gap + tokens.spacing.gap / 2;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.epubBook != null && widget.onSearchJump != null)
          _buildSearchSection(theme),
        if (widget.onJumpToCharOffset != null) ...[
          SizedBox(height: sectionGap),
          _buildCharJumpSection(theme),
        ],
        if (widget.toc.isNotEmpty) ...[
          SizedBox(height: sectionGap),
          _buildTocSection(context, theme),
        ],
        if (_favorites.isNotEmpty) ...[
          SizedBox(height: sectionGap),
          _buildFavoritesSection(context, theme),
        ],
        if (widget.extraLocationSection != null) ...[
          SizedBox(height: sectionGap),
          widget.extraLocationSection!,
        ],
      ],
    );
  }


  Widget _buildProgressSection(ThemeData theme) {
    final List<String> lines = [];

    final (int, int)? rp = widget.readerProgress;
    if (rp != null && rp.$2 > 0) {
      final int displayIdx = rp.$1 + 1;
      final double pct = (displayIdx / rp.$2) * 100;
      lines.add(t.chapter_progress(
        idx: displayIdx,
        total: rp.$2,
        suffix: '',
        pct: pct.toStringAsFixed(1),
      ));
    }

    final String? rawTitle = widget.epubBook?.title.trim();
    final String? rawChapter = widget.chapterLabel?.trim();
    final bool hasTitle = rawTitle != null && rawTitle.isNotEmpty;
    final bool hasChapter = rawChapter != null && rawChapter.isNotEmpty;
    if (((lines.isEmpty) && !hasTitle) && !hasChapter) {
      return const SizedBox.shrink();
    }
    final FushiDesignTokens tokens = FushiDesignTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingsSectionHeader(
          t.reading_progress,
          padding: EdgeInsets.only(bottom: tokens.spacing.gap),
        ),
        if (hasTitle)
          Text(
            rawTitle,
            style: theme.textTheme.titleSmall,
          ),
        if (hasChapter)
          Text(
            rawChapter,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        for (final String line in lines)
          Text(line, style: theme.textTheme.bodyMedium),
      ],
    );
  }

  Future<void> _doSearch() async {
    final String query = _searchController.text.trim();
    if (query.isEmpty) return;
    final int gen = ++_searchGeneration;
    setState(() => _isSearching = true);
    try {
      final List<BookSearchResult> results = widget.epubBook != null
          ? await BookSearch.searchBook(widget.epubBook!, query)
          : const <BookSearchResult>[];
      if (!mounted || gen != _searchGeneration) return;
      setState(() {
        _searchResults = results;
        _searchResultsQuery = query;
        _isSearching = false;
      });
    } catch (e, stack) {
      ErrorLogService.instance.log('ReaderQuickSettings.search', e, stack);
      debugPrint('[fushi-search] error: $e');
      if (!mounted || gen != _searchGeneration) return;
      setState(() {
        _searchResults = const [];
        _searchResultsQuery = '';
        _isSearching = false;
      });
    }
  }

  Widget _buildSearchSection(ThemeData theme) {
    final FushiDesignTokens tokens = FushiDesignTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingsSectionHeader(
          t.book_search,
          padding: EdgeInsets.only(bottom: tokens.spacing.gap),
        ),
        Row(
          children: [
            Expanded(
              child: FushiTextField(
                controller: _searchController,
                autofocus: widget.autofocusSearch,
                hintText: t.book_search_hint,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: tokens.spacing.rowHorizontal,
                  vertical: tokens.spacing.rowVertical,
                ),
                style: theme.textTheme.bodyMedium,
                onSubmitted: (_) => _doSearch(),
              ),
            ),
            SizedBox(width: tokens.spacing.gap),
            SizedBox.square(
              dimension: 40,
              child: Center(
                child: _isSearching
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child:
                            adaptiveIndicator(context: context, strokeWidth: 2),
                      )
                    : FushiIconButton(
                        icon: Icons.search,
                        size: 20,
                        backgroundColor: theme.colorScheme.secondaryContainer,
                        enabledColor: theme.colorScheme.onSecondaryContainer,
                        padding: EdgeInsets.all(tokens.spacing.gap),
                        tooltip: t.search,
                        onTap: _doSearch,
                      ),
              ),
            ),
          ],
        ),
        if (_searchResults.isNotEmpty) ...[
          SizedBox(height: tokens.spacing.gap),
          Text(
            t.book_search_results(n: _searchResults.length),
            style: theme.textTheme.bodySmall,
          ),
          SizedBox(height: tokens.spacing.gap / 2),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 280),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _searchResults.length,
              itemBuilder: (_, i) {
                final BookSearchResult r = _searchResults[i];
                final String query = _searchResultsQuery;
                final int rawIdx = r.sectionIndex;
                final List<TtuTocEntry> toc = widget.toc;
                final TtuTocEntry? tocEntry =
                    toc.cast<TtuTocEntry?>().firstWhere(
                          (e) => e!.index == rawIdx,
                          orElse: () => null,
                        );
                final String chapterLabel =
                    tocEntry?.label ?? t.go_to_chapter(n: rawIdx + 1);

                final String before = r.context.substring(0, r.matchStart);
                final int matchEnd =
                    (r.matchStart + query.length).clamp(0, r.context.length);
                final String match =
                    r.context.substring(r.matchStart, matchEnd);
                final String after = r.context.substring(matchEnd);

                return _InBookSearchResultRow(
                  chapterLabel: chapterLabel,
                  before: before,
                  match: match,
                  after: after,
                  onTap: () async {
                    final String q = _searchResultsQuery;
                    Navigator.pop(context);
                    await widget.onSearchJump?.call(r, q);
                  },
                );
              },
            ),
          ),
        ] else if (!_isSearching &&
            _searchController.text.trim().isNotEmpty) ...[
          SizedBox(height: tokens.spacing.gap),
          Text(
            t.book_search_no_results,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ],
    );
  }

  Widget _buildCharJumpSection(ThemeData theme) {
    final int? current = widget.charProgress?.$1;
    final int? total = widget.charProgress?.$2;
    final bool hasProgress = current != null && total != null && total > 0;
    final FushiDesignTokens tokens = FushiDesignTokens.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingsSectionHeader(
          t.jump_to_char,
          padding: EdgeInsets.only(bottom: tokens.spacing.gap),
        ),
        if (hasProgress)
          Padding(
            padding: EdgeInsets.only(bottom: tokens.spacing.gap),
            child: Text(
              t.jump_to_char_current(current: current, total: total),
              style: theme.textTheme.bodySmall,
            ),
          ),
        Row(
          children: [
            Expanded(
              child: FushiTextField(
                controller: _charJumpController,
                keyboardType: TextInputType.number,
                hintText: t.jump_to_char_hint,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: tokens.spacing.rowHorizontal,
                  vertical: tokens.spacing.rowVertical,
                ),
                style: theme.textTheme.bodyMedium,
                onSubmitted: (_) => _doCharJump(context),
              ),
            ),
            SizedBox(width: tokens.spacing.gap),
            SizedBox.square(
              dimension: 40,
              child: Center(
                child: FushiIconButton(
                  icon: Icons.arrow_forward,
                  size: 20,
                  backgroundColor: theme.colorScheme.secondaryContainer,
                  enabledColor: theme.colorScheme.onSecondaryContainer,
                  padding: EdgeInsets.all(tokens.spacing.gap),
                  tooltip: t.jump_to_char,
                  onTap: () => _doCharJump(context),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _doCharJump(BuildContext context) {
    final String text = _charJumpController.text.trim();
    if (text.isEmpty) return;
    final int? target = int.tryParse(text);
    if (target == null || target < 0) return;
    Navigator.pop(context);
    widget.onJumpToCharOffset?.call(target);
  }

  Widget _buildTocSection(BuildContext context, ThemeData theme) {
    final ReaderTocVolumeSwitch? volumes = widget.volumeSwitch;
    if (volumes == null) return _buildCurrentTocSection(context, theme);
    final FushiDesignTokens tokens = FushiDesignTokens.of(context);
    final bool peekingSibling = _viewedVolume != volumes.currentIndex;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _buildVolumeChips(theme, volumes),
        SizedBox(height: tokens.spacing.gap),
        if (!peekingSibling)
          _buildCurrentTocSection(context, theme)
        else
          _buildSiblingTocSection(context, theme, volumes, _viewedVolume),
      ],
    );
  }

  /// 卷 chip 行：当前卷带勾；点别的卷只换下方列表（无感查看），不切书。
  Widget _buildVolumeChips(ThemeData theme, ReaderTocVolumeSwitch volumes) {
    final FushiDesignTokens tokens = FushiDesignTokens.of(context);
    return SizedBox(
      height: 40,
      child: HorizontalDragScrollable(
        child: ListView.separated(
          key: const ValueKey<String>('reader-toc-volume-chips'),
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: tokens.spacing.gap / 2),
          itemCount: volumes.labels.length,
          separatorBuilder: (_, __) => SizedBox(width: tokens.spacing.gap),
          itemBuilder: (BuildContext context, int i) => ChoiceChip(
            key: ValueKey<String>('reader-toc-volume-chip-$i'),
            label: Text(
              volumes.labels[i],
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            avatar: i == volumes.currentIndex
                ? const Icon(Icons.menu_book_outlined, size: 16)
                : null,
            selected: i == _viewedVolume,
            onSelected: (bool _) {
              if (i == _viewedVolume) return;
              setState(() => _viewedVolume = i);
            },
          ),
        ),
      ),
    );
  }

  /// 兄弟卷的目录：isolate 解析（按卷缓存）→ 列表；首行「打开本卷」按保存位置整卷
  /// 切过去；点某章 = 切书并落到该章。不可查看的卷（PDF / 漫画）只有首行。
  Widget _buildSiblingTocSection(
    BuildContext context,
    ThemeData theme,
    ReaderTocVolumeSwitch volumes,
    int volume,
  ) {
    final FushiDesignTokens tokens = FushiDesignTokens.of(context);
    Future<void> jump(int? chapterIndex) async {
      Navigator.of(context).pop();
      await volumes.onJump(volume, chapterIndex);
    }

    final Widget openRow = _InBookTocRow(
      key: ValueKey<String>('reader-toc-volume-open-$volume'),
      // index 只用来区分 header（<0 = 标题行不可点）；本行是可点动作行，回调
      // 自带卷号，不读 index。
      entry: TtuTocEntry(index: 0, label: t.reader_volume_open),
      selected: false,
      onTap: () => unawaited(jump(null)),
    );
    return FutureBuilder<List<TtuTocEntry>>(
      key: ValueKey<String>('reader-toc-volume-toc-$volume'),
      future: volumes.tocOf(volume),
      builder: (BuildContext context, AsyncSnapshot<List<TtuTocEntry>> snap) {
        final List<Widget> rows = <Widget>[openRow];
        if (snap.hasError) {
          rows.add(
            Padding(
              padding: EdgeInsets.all(tokens.spacing.rowHorizontal),
              child: Text(
                t.reader_volume_peek_failed,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.error),
              ),
            ),
          );
        } else if (!snap.hasData) {
          rows.add(
            Padding(
              padding: EdgeInsets.all(tokens.spacing.rowHorizontal),
              child: const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          );
        } else {
          final List<TtuTocEntry> toc = snap.data!;
          for (int i = 0; i < toc.length; i++) {
            if (toc[i].depth >= 2) continue; // 兄弟卷只列顶层章，够定位即可。
            rows.add(
              _InBookTocRow(
                entry: toc[i],
                selected: false,
                onTap:
                    toc[i].isHeader ? null : () => unawaited(jump(toc[i].index)),
              ),
            );
          }
        }
        return AdaptiveSettingsSection(
          title: volumes.labels[volume],
          children: rows,
        );
      },
    );
  }

  Widget _buildCurrentTocSection(BuildContext context, ThemeData theme) {
    final List<TtuTocEntry> toc = widget.toc;
    // BUG-2545：目录是 spine 的**稀疏**映射（同一章横跨多个 xhtml 只有头一个进
    // 目录，章间插图页根本不在目录里），所以「当前章」不能拿当前 spine 章号去和
    // 目录项 index 精确相等——那样一来读在任何没被目录直接指向的 spine 位置上
    // （实测一本 35 项 spine 的书里占 23 个位置）整个列表一行都不标、
    // `_currentTocRowKey` 也挂不上，「打开即滚到当前章」跟着静默失效。判据统一成
    // floor（最后一个不晚于当前位置的目录项），与页脚章名
    // `_currentChapterLabelFor` 和有声书面板「章节」tab 同一口径。
    //
    // 同一 spine 章下靠 `#anchor` 分节的多条目录项（一个 xhtml 装整卷）章号全
    // 相同，再按章内字符偏移比一次（[resolveCurrentTocEntry]），当前只落在
    // **一条**上——旧判据只比章号，那一章下的每一条都被标成当前（四个勾）。
    final int? currentRow = resolveCurrentTocEntry(
      toc,
      widget.readerProgress?.$1,
      widget.readerCharOffset,
    );
    // 折叠规则：深度 >= 2 的条目挂在其 parent 下，parent 未展开则不画；当前章所在链
    // 上的父节自动视为展开。父节是否有可折叠子节：看下一条的深度是否更深且 >= 2。
    final Set<String> autoExpanded = <String>{};
    if (currentRow != null && toc[currentRow].depth >= 2) {
      final String? parent = toc[currentRow].parent;
      if (parent != null) autoExpanded.add(parent);
    }
    bool hasFoldableChildren(int i) =>
        i + 1 < toc.length &&
        toc[i + 1].depth > toc[i].depth &&
        toc[i + 1].depth >= 2;
    bool isExpanded(TtuTocEntry parent) =>
        _expandedTocParents.contains(parent.label) ||
        autoExpanded.contains(parent.label);
    // 「当前章那一行」只能有**一行**：`_currentTocRowKey` 是 GlobalKey，同一个
    // key 挂到两个在场 widget 上，debug 直接抛 `Multiple widgets used the same
    // GlobalKey`，release 则由 `Element._retakeInactiveElement` 把 element 从前
    // 一行手里抢走——那一行被摘出渲染树，**目录里真的少一行**。
    // [resolveCurrentTocEntry] 返回的就是唯一一条的下标。
    return AdaptiveSettingsSection(
      title: t.toc_section(n: toc.length),
      children: [
        for (int i = 0; i < toc.length; i++)
          if (toc[i].depth < 2 ||
              (toc[i].parent != null &&
                  (_expandedTocParents.contains(toc[i].parent!) ||
                      autoExpanded.contains(toc[i].parent!))))
            _InBookTocRow(
              key: i == currentRow ? _currentTocRowKey : null,
              entry: toc[i],
              selected: i == currentRow,
              foldable: hasFoldableChildren(i),
              expanded: hasFoldableChildren(i) && isExpanded(toc[i]),
              onToggleExpanded: hasFoldableChildren(i)
                  ? () => setState(() {
                        final String label = toc[i].label;
                        if (!_expandedTocParents.remove(label)) {
                          _expandedTocParents.add(label);
                        }
                      })
                  : null,
              onTap: toc[i].isHeader
                  ? null
                  : () async {
                      Navigator.of(context).pop();
                      await widget.onJumpSection(
                        toc[i].index,
                        toc[i].fragment,
                      );
                    },
            ),
      ],
    );
  }

  /// 收藏行副标题：`书名 - 章节 - 时间`，末尾追加阅读位置百分比（解析成功时）。
  String _favoriteMetaLabel(FavoriteSentence favorite, DateFormat fmt) {
    final String base =
        '${favorite.bookTitle}${favorite.chapterLabel != null ? ' - ${favorite.chapterLabel}' : ''} - ${fmt.format(favorite.createdAt)}';
    final String? position = widget.favoritePositionLabel?.call(favorite);
    return position == null ? base : '$base · $position';
  }

  Widget _buildFavoritesSection(BuildContext context, ThemeData theme) {
    final DateFormat fmt = DateFormat('MM/dd HH:mm');
    return AdaptiveSettingsSection(
      title: t.favorites(n: _favorites.length),
      children: [
        for (final FavoriteSentence favorite in _favorites)
          _InBookFavoriteRow(
            favorite: favorite,
            // BUG-875 附带（用户反馈）：收藏行右侧加「阅读位置」百分比（如 78.6%），
            // 让用户不放音频 / 不复制文本也能一眼看出这条收藏在书里的位置。位置解析
            // 失败（章字符账本未就绪）时不追加、只显示原元信息。
            metaLabel: _favoriteMetaLabel(favorite, fmt),
            color: _highlightColor(favorite.color),
            onPlay: widget.onPlayFavorite == null
                ? null
                : () async => widget.onPlayFavorite?.call(favorite),
            onJump:
                favorite.sectionIndex == null || widget.onJumpToFavorite == null
                    ? null
                    : () async {
                        Navigator.of(context).pop();
                        await widget.onJumpToFavorite?.call(favorite);
                      },
            onCopy: () {
              Clipboard.setData(ClipboardData(text: favorite.text));
              FushiToast.show(msg: t.copy, severity: ToastSeverity.success);
            },
            onDelete: () async {
              await widget.onDeleteFavorite?.call(favorite);
              if (mounted) {
                setState(() {
                  _favorites = List<FavoriteSentence>.of(_favorites)
                    ..remove(favorite);
                });
              }
            },
          ),
      ],
    );
  }

  static Color _highlightColor(String? color) {
    switch (color) {
      case 'green':
        return const Color(0xFF00C853);
      case 'blue':
        return const Color(0xFF448AFF);
      case 'pink':
        return const Color(0xFFFF4081);
      case 'purple':
        return const Color(0xFFAA00FF);
      default:
        return FushiColor.defaultHighlightYellow;
    }
  }

}

class _InBookTocRow extends StatelessWidget {
  const _InBookTocRow({
    super.key,
    required this.entry,
    required this.selected,
    this.onTap,
    this.foldable = false,
    this.expanded = false,
    this.onToggleExpanded,
  });

  final TtuTocEntry entry;
  final bool selected;
  final VoidCallback? onTap;

  /// 有深度 >= 2 的子节可折叠时，行尾给一个展开 / 收起箭头。
  final bool foldable;
  final bool expanded;
  final VoidCallback? onToggleExpanded;

  @override
  Widget build(BuildContext context) {
    final FushiDesignTokens tokens = FushiDesignTokens.of(context);
    final String title = entry.label.isEmpty ? t.untitled_chapter : entry.label;
    final double indent = entry.depth * tokens.spacing.card;

    if (entry.isHeader) {
      final ThemeData theme = Theme.of(context);
      return Padding(
        padding: EdgeInsetsDirectional.only(
          start: (tokens.spacing.gap + tokens.spacing.gap / 2) +
              indent,
          top: tokens.spacing.gap + tokens.spacing.gap / 2,
          bottom: tokens.spacing.gap / 2,
        ),
        child: Text(
          title,
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.primary,
          ),
        ),
      );
    }

    final Color selectedColor = Theme.of(context).colorScheme.primary;

    return Padding(
      padding: EdgeInsetsDirectional.only(start: indent),
      child: AdaptiveSettingsRow(
        title: title,
        // TOC chapter names can be long; on a narrow phone the default 2-line
        // clamp clips them. Allow a few wrapped lines (still finite so pathological
        // titles can't blow up the row) before ellipsizing (TODO-1055).
        titleMaxLines: 4,
        // 章节行不再带书本 / 小节图标：层级靠缩进（indent）表达即可。
        showIcon: false,
        onTap: onTap,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (selected)
              Icon(
                Icons.check,
                size: 18,
                color: selectedColor,
              ),
            if (foldable)
              IconButton(
                key: ValueKey<String>('fushi_toc_fold_${entry.label}'),
                visualDensity: VisualDensity.compact,
                iconSize: 20,
                tooltip: expanded
                    ? MaterialLocalizations.of(context).collapsedIconTapHint
                    : MaterialLocalizations.of(context).expandedIconTapHint,
                icon: Icon(expanded ? Icons.expand_less : Icons.expand_more),
                onPressed: onToggleExpanded,
              ),
          ],
        ),
      ),
    );
  }
}

class _InBookSearchResultRow extends StatelessWidget {
  const _InBookSearchResultRow({
    required this.chapterLabel,
    required this.before,
    required this.match,
    required this.after,
    required this.onTap,
  });

  final String chapterLabel;
  final String before;
  final String match;
  final String after;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final FushiDesignTokens tokens = FushiDesignTokens.of(context);
    final Color primary = theme.colorScheme.primary;
    final Color highlight = theme.colorScheme.primaryContainer;
    final Widget child = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.gap + tokens.spacing.gap / 2,
        vertical: tokens.spacing.gap + tokens.spacing.gap / 8,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.search,
            size: 18,
            color: primary,
          ),
          SizedBox(width: tokens.spacing.gap + tokens.spacing.gap / 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  chapterLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(color: primary),
                ),
                SizedBox(height: tokens.spacing.gap / 4),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: before),
                      TextSpan(
                        text: match,
                        style: TextStyle(
                          backgroundColor: highlight,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      TextSpan(text: after),
                    ],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return InkWell(
      borderRadius: tokens.radii.controlRadius,
      onTap: onTap,
      child: child,
    );
  }
}

class _InBookFavoriteRow extends StatelessWidget {
  const _InBookFavoriteRow({
    required this.favorite,
    required this.metaLabel,
    required this.color,
    required this.onCopy,
    required this.onDelete,
    this.onPlay,
    this.onJump,
  });

  final FavoriteSentence favorite;
  final String metaLabel;
  final Color color;
  final VoidCallback? onPlay;
  final VoidCallback? onJump;
  final VoidCallback onCopy;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final FushiDesignTokens tokens = FushiDesignTokens.of(context);
    return AdaptiveSettingsRow(
      title: favorite.text,
      subtitle: metaLabel,
      icon: Icons.format_quote_outlined,
      onTap: onJump,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildColorRail(context, color),
          SizedBox(width: tokens.spacing.gap * 0.75),
          // 跳转按钮已移除：整行点击 (onTap) 已经跳转到该收藏句子，
          // 单独的跳转图标与之重复，反而把按钮挤在一起。
          if (onPlay != null) ...[
            _InBookIconButton(
              materialIcon: Icons.volume_up_outlined,
              tooltip: t.play,
              onPressed: onPlay!,
            ),
            SizedBox(width: tokens.spacing.gap / 2),
          ],
          _InBookIconButton(
            materialIcon: Icons.copy_outlined,
            tooltip: t.copy,
            onPressed: onCopy,
          ),
          SizedBox(width: tokens.spacing.gap / 2),
          _InBookIconButton(
            materialIcon: Icons.delete_outline,
            tooltip: t.options_delete,
            destructive: true,
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }

  Widget _buildColorRail(BuildContext context, Color railColor) {
    final FushiDesignTokens tokens = FushiDesignTokens.of(context);
    return Container(
      width: 4,
      height: 32,
      decoration: BoxDecoration(
        color: railColor,
        borderRadius: tokens.radii.chipRadius,
      ),
    );
  }
}

class _InBookIconButton extends StatelessWidget {
  const _InBookIconButton({
    required this.materialIcon,
    required this.tooltip,
    required this.onPressed,
    this.destructive = false,
  });

  final IconData materialIcon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final FushiDesignTokens tokens = FushiDesignTokens.of(context);
    final Color color = destructive
        ? (Theme.of(context).colorScheme.error)
        : (Theme.of(context).colorScheme.onSurfaceVariant);

    return FushiIconButton(
      icon: materialIcon,
      size: 18,
      enabledColor: color,
      tooltip: tooltip,
      constraints: BoxConstraints(
        minWidth: tokens.spacing.gap * 4,
        minHeight: tokens.spacing.gap * 4,
      ),
      padding: EdgeInsets.zero,
      onTap: onPressed,
    );
  }
}
