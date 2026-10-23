import 'dart:async';

import 'package:flutter/material.dart';
import 'package:fushi/src/sync/book_exit_sync_scope.dart';
import 'package:fushi/src/sync/kitapsen_client.dart';
import 'package:fushi/src/sync/sync_activity.dart';
import 'package:fushi/src/sync/sync_backend.dart';
import 'package:fushi/src/sync/sync_orchestrator.dart';
import 'package:fushi/src/sync/sync_progress.dart';
import 'package:fushi_core/fushi_core.dart';

final ValueNotifier<bool> syncInProgress = ValueNotifier<bool>(false);

/// App-wide latest sync progress tick, fed by EVERY full-sweep run (manual
/// "立即同步" AND the app-open/background auto-sweep). The settings "立即同步" row
/// reflects this so its inline progress bar shows whenever a sync is in flight —
/// not only for the run that row triggered (BUG-101). null between runs (and for
/// the single-book auto-sync path, which has no phase structure → indeterminate).
final ValueNotifier<SyncProgress?> syncProgress =
    ValueNotifier<SyncProgress?>(null);

/// 在飞的这轮同步的**身份**。null = 没有同步在跑。
///
/// [syncProgress] 只在编排器真进入某个阶段后才有值，而每轮同步在那之前还有一整段
/// 准备期（等互斥锁 → 读开关 → 冷却判断 → 走网络鉴权），合集/单本两条轻量路径更是
/// 从头到尾都没有阶段结构。缺了这一层，界面上「在准备」「在跑轻量同步」「所有通道
/// 都没认证过、正在空转」三种现实完全同形。UI 拿不到阶段 tick 时退化到这一层。
final ValueNotifier<SyncActivity?> syncActivity =
    ValueNotifier<SyncActivity?>(null);

// HBK-AUDIT-049: cloud backends (GoogleDrive/Dropbox/OneDrive/WebDAV/SMB) are
// process-wide singletons holding mutable shared state (_accessToken,
// _cachedApi, _rootFolderId, _titleToFolderId) with no per-operation lock.
// _syncingIds only dedups identical keys, so two DIFFERENT books — or a
// per-book sync overlapping the '__all__' sweep — used to run concurrently and
// interleave on that shared state. Serialize every auto-sync operation through
// one app-wide mutex so a backend's token/api/cache is only ever touched by a
// single in-flight sync. Dedup (_syncingIds) still short-circuits redundant
// triggers before they queue on the mutex.

/// Fired after an auto-sync run produced a [SyncRunReport], carrying the
/// already-resolved+authenticated [SyncBackend] so the caller can drive a
/// conflict-resolution dialog without re-resolving/re-authing. Only invoked when
/// the run actually reached a report (auth ok, sync ran); skipped/aborted runs
/// never call it.
typedef SyncReportCallback = void Function(
  SyncRunReport report,
  SyncBackend backend,
);

void triggerAutoSyncAfterClose({
  required FushiDatabase db,
  required String mediaIdentifier,
  required ScaffoldMessengerState messenger,
  SyncReportCallback? onReport,
}) {
  // TODO-132 诉求B：退出书同步是 fire-and-forget（不 await，不阻塞 onWillPop /
  // 退出 UI）。但把这个游离 Future 登记进 app-scope [BookExitSyncScope]，使页面
  // 销毁后它照样跑完，且进程退出路径能有界等它落定——避免「退出书后立刻杀应用」
  // 时关书 export 被打成半截（与 132A/BUG-201 的 baseline 原子化互补）。
  // messenger 仍传入（保留签名 + 留给冲突对话框的祖先上下文经 onReport 走
  // navigatorKey，不依赖它），但**不再**用它弹打断式「同步成功」SnackBar。
  //
  // Kitapsen 书店进度独立于云备份 / 互联通道（不受自动同步开关约束）：书来自书店
  // 就把本机位置报回去，网页阅读器下次打开即从这里接着读。
  BookExitSyncScope.instance.register(
    syncKitapsenBookProgress(db, mediaIdentifier),
  );
}

void triggerAutoSyncOnBackground({
  required FushiDatabase db,
  required String mediaIdentifier,
}) {
  // Background (app→paused) intentionally has NO onReport: the user can't see a
  // dialog, so conflicts stay silent until a later visible sync surfaces them.
  unawaited(syncKitapsenBookProgress(db, mediaIdentifier));
}
