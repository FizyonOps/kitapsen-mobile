/// 媒体种类值域间的**显式跨域映射表**（命名统一 Phase 3.4）。
///
/// 本仓有多套互不通用的媒体种类字符串值域（合集/书架 [MediaKind]、活动事件
/// [ActivityMediaKind]、统计来源 [StatSourceKind]、Profile 绑定
/// `ProfileMediaKind`、sync 墓碑 `SyncTombstoneKind`……）。值域**不合并**
/// （`book` ≠ `epub` 是真实语义差），跨域换算此前散在 UI 层隐式手写
/// （如 home_dashboard 对 book 活动行「epub 优先、srt 回退」的复合键推导）。
/// 本文件把这些换算收口成穷尽 switch 的纯函数——加媒体种类时编译器强制
/// 补齐每张映射，守卫测试钉死既有映射对。
///
/// 刻意**不提供** `MediaKind → ProfileMediaKind` 映射：Profile 绑定域的
/// `audiobook` / `lyrics` / `srtbook` 取决于运行时挂载状态（同一本
/// [MediaKind.epub] 书可解析到三种绑定），不是静态种类换算，见
/// profile_media_kind.dart 文件头。
library;

import 'activity_event_types.dart';
import 'media_kind.dart';
import 'stat_source_kind.dart';

/// 合集/书架种类 → 活动事件种类（epub 折叠进活动域的 `book`）。
ActivityMediaKind activityMediaKindOf(MediaKind kind) => switch (kind) {
      MediaKind.epub => ActivityMediaKind.book,
    };
