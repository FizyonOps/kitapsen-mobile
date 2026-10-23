import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fushi/i18n/strings.g.dart';
import 'package:fushi/src/platform/mobile/android_download_keep_alive.dart';
import 'package:fushi/src/platform/mobile/download_keep_alive_hub.dart';
import 'package:fushi/src/sync/sync_error_messages.dart';

/// 一个远端书（Kitapsen 书店）下载任务的生命周期状态。
enum RemoteBookDownloadStatus { running, completed, failed }

/// 一个远端书下载任务的不可变快照。UI 只读这个渲染进度/状态。
@immutable
class RemoteBookDownloadTask {
  const RemoteBookDownloadTask({
    required this.id,
    required this.title,
    required this.status,
    required this.progress,
    this.error,
  });

  /// 稳定任务键（= [RemoteBookDownloadManager.bookTaskId]）。
  final String id;

  /// 展示标题。
  final String title;

  /// 当前生命周期状态。
  final RemoteBookDownloadStatus status;

  /// 0..1 进度；首个 onProgress 前为 null（不确定进度）。
  final double? progress;

  /// 失败时的错误文本（status==failed 时非空）。
  final String? error;

  bool get isRunning => status == RemoteBookDownloadStatus.running;

  RemoteBookDownloadTask copyWith({
    RemoteBookDownloadStatus? status,
    double? progress,
    String? error,
    bool clearError = false,
  }) {
    return RemoteBookDownloadTask(
      id: id,
      title: title,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// 执行一次实际下载到 [dest] 的原语（注入，解耦具体 client）。[onProgress] 上报
/// 0..1 进度。传输不支持中途中止，所以没有暂停。
typedef RemoteBookDownloadRunner = Future<void> Function(
  File dest, {
  void Function(double progress)? onProgress,
});

/// 下载成功后落库/建行等收尾（注入；任一失败计入任务失败，不静默丢半成品）。
typedef RemoteBookDownloadComplete = Future<void> Function(File dest);

/// **app 级远端书下载管理器**。持有所有进行中/已完成/失败的下载任务，不挂任何页面
/// State —— 故切 tab / 退页 / 页面 dispose 时下载循环仍在本管理器里活着，页面只
/// `ref.watch` 订阅渲染进度（BUG-1693：书侧此前挂在书架页 State 里，失败在离页后
/// 完全不可见）。
///
/// 有任务在跑时经 [DownloadKeepAlive] 挂 Android 前台服务保活（BUG-2714）。
class RemoteBookDownloadManager extends ChangeNotifier {
  RemoteBookDownloadManager({DownloadKeepAlive? keepAlive})
      : _keepAlive = keepAlive;

  final DownloadKeepAlive? _keepAlive;
  bool _keepAliveActive = false;

  /// 书任务键。UI 查书任务状态必须经同一派生函数，不得手拼前缀。
  static String bookTaskId(String downloadId) => 'book:$downloadId';

  final Map<String, RemoteBookDownloadTask> _tasks =
      <String, RemoteBookDownloadTask>{};

  /// 已结束（completed/failed）任务的**完成顺序**，用于有界保留（BUG-1561）。
  /// Dart 的 Map 迭代序是首次插入序，覆写同 key 不会把它挪到末尾，所以顺序得自己记。
  final List<String> _finishedOrder = <String>[];
  bool _disposed = false;

  /// 已结束任务的保留上限（BUG-1561）。结束态只对「刚发生的事」有意义（失败角标、
  /// 重试判据），超出这个窗口的最旧结束态直接淘汰；running 任务永不淘汰。
  static const int maxFinishedTasks = 32;

  /// 取某任务快照（无则 null）。
  RemoteBookDownloadTask? taskFor(String id) => _tasks[id];

  /// 某任务是否正在下载（UI 决定显示进度徽标）。
  bool isRunning(String id) => _tasks[id]?.isRunning ?? false;

  /// 启动一个远端书下载任务（键 = [bookTaskId]）。已在跑（同 [downloadId]）则忽略
  /// 重复调用，返回当前任务。
  ///
  /// 流程：置 running（不确定进度）→ [run] 驱动下载（更新进度）→ 成功调
  /// [onComplete] 收尾 → 标 completed；任一步失败标 failed 并存错误。**整个生命周期
  /// 与页面无关**：页面 dispose 后任务仍在本管理器里推进到底。
  Future<RemoteBookDownloadTask> startBookDownload({
    required String downloadId,
    required String title,
    required File dest,
    required RemoteBookDownloadRunner run,
    RemoteBookDownloadComplete? onComplete,
  }) async {
    final String id = bookTaskId(downloadId);
    final RemoteBookDownloadTask? existing = _tasks[id];
    if (existing != null && existing.isRunning) return existing;

    _tasks[id] = RemoteBookDownloadTask(
      id: id,
      title: title,
      status: RemoteBookDownloadStatus.running,
      progress: null,
    );
    // 重跑同一个 id（用户重试）= 上一轮的结束态被消费掉了，从保留窗口里摘掉。
    _finishedOrder.remove(id);
    _notify();

    try {
      await run(
        dest,
        onProgress: (double progress) => _updateProgress(id, progress),
      );
      if (onComplete != null) await onComplete(dest);
      _setStatus(id, RemoteBookDownloadStatus.completed, progress: 1);
      return _tasks[id]!;
    } catch (e) {
      _setStatus(
        id,
        RemoteBookDownloadStatus.failed,
        // BUG-1693：存**用户可读**的失败原因，不是原始异常文本——它会被失败角标
        // tooltip 原样上屏。未知错误 friendlySyncErrorDetail 回落原文，不吞信息。
        error: friendlySyncErrorDetail(e),
      );
      rethrow;
    }
  }

  /// 把 [id] 记进结束窗口并淘汰最旧的溢出项（BUG-1561）。
  void _retainFinished(String id) {
    _finishedOrder
      ..remove(id)
      ..add(id);
    while (_finishedOrder.length > maxFinishedTasks) {
      final String evicted = _finishedOrder.removeAt(0);
      final RemoteBookDownloadTask? task = _tasks[evicted];
      // 理论上不会命中 running（只有结束时才进这个表），但真撞上就留着它的状态槽。
      if (task != null && task.isRunning) continue;
      _tasks.remove(evicted);
    }
  }

  void _updateProgress(String id, double progress) {
    final RemoteBookDownloadTask? task = _tasks[id];
    if (task == null || !task.isRunning) return;
    _tasks[id] = task.copyWith(progress: progress.clamp(0.0, 1.0));
    _notify();
  }

  void _setStatus(
    String id,
    RemoteBookDownloadStatus status, {
    double? progress,
    String? error,
  }) {
    final RemoteBookDownloadTask? task = _tasks[id];
    if (task == null) return;
    _tasks[id] = task.copyWith(
      status: status,
      progress: progress,
      error: error,
      clearError: error == null,
    );
    if (status == RemoteBookDownloadStatus.completed ||
        status == RemoteBookDownloadStatus.failed) {
      _retainFinished(id);
    }
    _notify();
  }

  void _notify() {
    if (_disposed) return;
    _syncKeepAlive();
    notifyListeners();
  }

  /// 有任务在跑就挂前台服务，全停了就撤。节流 / 去重在 [DownloadKeepAlive] 里做，
  /// 这里每次状态变化都如实报。
  void _syncKeepAlive() {
    final DownloadKeepAlive? keepAlive = _keepAlive;
    if (keepAlive == null) return;
    final List<RemoteBookDownloadTask> running = <RemoteBookDownloadTask>[
      for (final RemoteBookDownloadTask task in _tasks.values)
        if (task.isRunning) task,
    ];
    if (running.isEmpty) {
      if (_keepAliveActive) {
        _keepAliveActive = false;
        unawaited(keepAlive.stop());
      }
      return;
    }
    _keepAliveActive = true;
    final String title = running.length == 1
        ? running.single.title
        : t.remote_book_download_notification_title(count: running.length);
    unawaited(keepAlive.update(
      title: title,
      text: t.download_task_status_downloading,
      percent: null,
    ));
  }

  @override
  void dispose() {
    _disposed = true;
    if (_keepAliveActive) unawaited(_keepAlive?.stop());
    super.dispose();
  }
}

/// app 级单例 provider：在整个 app 生命周期内持有远端书下载任务，跨页面存活。
final remoteBookDownloadManagerProvider =
    ChangeNotifierProvider<RemoteBookDownloadManager>(
  (ref) => RemoteBookDownloadManager(
      keepAlive: downloadKeepAliveHub.lease('remote_books')),
);
