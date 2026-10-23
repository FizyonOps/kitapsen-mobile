/// [ModuleId] 与各域值域之间的**显式映射表**。
///
/// 本仓有多套互不通用的值域：底栏 tab [HomeTab]、设置一级分类
/// [SettingsDestinationId]、快捷键作用域 [ShortcutScope]、书架/合集媒体种类
/// [MediaKind]。「功能模块」要门控它们全部，但值域**不合并**（`HomeTab.home` /
/// `SettingsDestinationId.appearance` 这类恒在项根本没有对应模块）。
///
/// 这里把换算收成**穷尽 switch 的纯函数**：加模块时编译器强制补齐每张映射，
/// 漏一张就编译不过。体例照抄
/// `packages/fushi_core/lib/src/database/media_kind_mappings.dart`。
///
/// 反向映射一律返回**可空**值，`null` = 「不属于任何模块」= 恒可见。省掉的那个
/// 默认分支正是安全方向：新加的 destination 默认恒在，忘写映射不会把它藏掉。
library;

import 'package:fushi/src/models/module_id.dart';
import 'package:fushi/src/pages/implementations/home_page.dart' show HomeTab;
import 'package:fushi/src/settings/settings_destination.dart'
    show SettingsDestinationId;
import 'package:fushi/src/shortcuts/shortcut_action.dart' show ShortcutScope;
import 'package:fushi_core/fushi_core.dart' show MediaKind;

// ── HomeTab ────────────────────────────────────────────────────────────────

/// 顶层 tab → 所属模块。`home` / `settings` 恒在（全部模块关光后的安全回退面），
/// 故返回 `null`。
ModuleId? moduleOfHomeTab(HomeTab tab) => switch (tab) {
  HomeTab.home => null,
  HomeTab.settings => null,
  HomeTab.books => ModuleId.books,
  HomeTab.store => null,
  HomeTab.manga => ModuleId.manga,
  HomeTab.video => ModuleId.video,
  HomeTab.browse => ModuleId.browse,
  HomeTab.dictionaries => ModuleId.lookup,
  HomeTab.games => ModuleId.games,
  HomeTab.browserExtension => ModuleId.browserExtension,
};

/// 某个顶层 tab 此刻是否可达。`_selectTab` / 任何「点了要跳过去」的入口渲染判据
/// 都用它，别自己拼 `isEnabled(moduleOfHomeTab(t)!)`——恒在 tab 会在那个 `!` 上崩。
bool isHomeTabVisible(HomeTab tab, ModuleVisibility visibility) =>
    visibility.isEnabledOrUngated(moduleOfHomeTab(tab));

// ── SettingsDestinationId ──────────────────────────────────────────────────

// ── ShortcutScope ──────────────────────────────────────────────────────────

// ── MediaKind ──────────────────────────────────────────────────────────────

/// 书架/合集媒体种类 → 所属模块。
///
/// ⚠️ **漫画盖不住**：[MediaKind] 没有 `manga` 值——漫画是 `EpubBooks.format ==
/// 'manga'` 派生出来的，落在 `epub` 桶里。按本映射过滤只能把漫画跟着 books 一起
/// 处理；需要区分漫画的地方（首页「继续」/「最近添加」）必须另带派生判据，不能
/// 给 [MediaKind] 加值（`dbValue` 是持久化契约，加值会波及合集/统计/同步全链）。
ModuleId moduleOfMediaKind(MediaKind kind) => switch (kind) {
  MediaKind.epub || MediaKind.srt => ModuleId.books,
  MediaKind.video => ModuleId.video,
  MediaKind.game => ModuleId.games,
};
