import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fushi/i18n/strings.g.dart';
import 'package:fushi/src/platform/mobile/android_download_keep_alive.dart';
import 'package:fushi/src/platform/mobile/download_keep_alive_hub.dart';
import 'package:fushi/src/sync/sync_error_messages.dart';

/// 一个互联（hibiki 互联 / LAN 对端）下载任务的生命周期状态。
///
/// [paused]：用户主动暂停，或进程被杀后从续传清单接回来的任务。`.part` 留着，
/// [InterconnectDownloadManager.resume] 从已下载的字节处接着下。
enum InterconnectDownloadStatus { running, paused, completed, failed }

/// 任务的内容域（下载中心按它选图标 / 分类）。
enum InterconnectDownloadKind { video, book, audiobook }

/// 一个互联下载任务的不可变快照。UI 只读这个渲染进度/状态。
@immutable
class InterconnectDownloadTask {
  const InterconnectDownloadTask({
    required this.id,
    required this.title,
    required this.status,
    required this.progress,
    this.kind = InterconnectDownloadKind.video,
    this.receivedBytes,
    this.totalBytes,
    this.startedAt,
    this.error,
  });

  /// 稳定任务键（视频用 RemoteVideoInfo.id；与列表去重键一致）。
  final String id;

  /// 展示标题。
  final String title;

  /// 当前生命周期状态。
  final InterconnectDownloadStatus status;

  /// 0..1 进度；首个 onProgress 前为 null（不确定进度）。
  final double? progress;

  final InterconnectDownloadKind kind;

  /// 已落盘字节（**含续传前已有的 `.part`**）；传输原语不报字节时为 null。
  final int? receivedBytes;

  /// 总字节；服务端没给长度时为 null。
  final int? totalBytes;

  /// 任务（最近一次）开始的时刻（毫秒）；下载中心按它排序。
  final int? startedAt;

  /// 失败时的错误文本（status==failed 时非空）。
  final String? error;

  bool get isRunning => status == InterconnectDownloadStatus.running;
  bool get isPaused => status == InterconnectDownloadStatus.paused;

  InterconnectDownloadTask copyWith({
    InterconnectDownloadStatus? status,
    double? progress,
    bool clearProgress = false,
    int? receivedBytes,
    int? totalBytes,
    String? error,
    bool clearError = false,
  }) {
    return InterconnectDownloadTask(
      id: id,
      title: title,
      status: status ?? this.status,
      progress: ((progress ?? this.progress)),
      kind: kind,
      receivedBytes: receivedBytes ?? this.receivedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      startedAt: startedAt,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// 执行一次实际下载到 [dest] 的原语（注入，便于测试与解耦具体 client）。
/// [onProgress] 上报 0..1 进度。书 / 有声书走这一形；它们的传输不支持中途
/// 中止，所以没有暂停。
typedef InterconnectDownloadRunner = Future<void> Function(
  File dest, {
  void Function(double progress)? onProgress,
});

/// 视频下载原语：在 [InterconnectDownloadRunner] 之上多报字节（[onBytes]，
/// received 含续传前已有的 `.part`），并接受 [cancelSignal]——它完成时传输中止、
/// 抛 [RemoteDownloadCancelled]、`.part` 留着供续传（即「暂停」）。
typedef InterconnectVideoDownloadRunner = Future<void> Function(
  File dest, {
  void Function(double progress)? onProgress,
  void Function(int received, int? total)? onBytes,
  Future<void>? cancelSignal,
});

/// 下载成功后落库/建行等收尾（注入；任一失败计入任务失败，不静默丢半成品）。
typedef InterconnectDownloadComplete = Future<void> Function(File dest);

/// 任务的「怎么再跑一次」：暂停后继续、失败后重试都靠它，不必回到发起页面。
class _DownloadSpec {
  const _DownloadSpec({
    required this.title,
    required this.kind,
    required this.dest,
    required this.run,
    required this.onComplete,
    required this.pausable,
  });

  final String title;
  final InterconnectDownloadKind kind;
  final File dest;
  final InterconnectVideoDownloadRunner run;
  final InterconnectDownloadComplete? onComplete;

  /// 传输原语认 cancelSignal（视频）。书的原语不认，暂停无从谈起。
  final bool pausable;
}

/// **app 级互联下载管理器（TODO-819）**。持有所有进行中/已完成/失败的互联下载任务，
/// 不挂任何页面 State —— 故切 tab / 退页 / 页面 dispose 时下载循环仍在本管理器里活着，
/// 页面只 `ref.watch` 订阅渲染进度。
///
/// 承载视频下载（[startVideoDownload]，底层走可续传引擎，中断留 .part 可续）与
/// 书 / 有声书下载（[startBookDownload] / [startSrtAudiobookDownload]，BUG-1693
/// 批审计：书侧此前挂在书架页 State 里，失败在离页后完全不可见）。
///
/// 进程活不过切后台是另一回事（BUG-2714）：有任务在跑时经 [DownloadKeepAlive]
/// 挂 Android 前台服务保活；真被杀了，视频任务靠与 `.part` 并排的续传清单
/// （[InterconnectVideoResumeStore]）在下次拿到远端清单时接回来。
class InterconnectDownloadManager extends ChangeNotifier {
  InterconnectDownloadManager({
    DownloadKeepAlive? keepAlive,
    int Function()? now,
  })  : _keepAlive = keepAlive,
        _now = now ?? _wallClock;

  static int _wallClock() => DateTime.now().millisecondsSinceEpoch;

  final DownloadKeepAlive? _keepAlive;
  final int Function() _now;
  bool _keepAliveActive = false;
  final int _keepAliveHolds = 0;

  /// 书域任务键（BUG-1693 批审计）：书任务与视频任务同居一张 [_tasks] 表——视频
  /// 键是 `RemoteVideoInfo.id`、书键是 `RemoteBookInfo.downloadId`（= host 的
  /// `bookKey ?? title`），两个值域互不设防，域前缀隔离避免撞键。UI 查书任务
  /// 状态必须经同一派生函数，不得手拼前缀。
  static String bookTaskId(String downloadId) => 'book:$downloadId';

  final Map<String, InterconnectDownloadTask> _tasks =
      <String, InterconnectDownloadTask>{};

  final Map<String, _DownloadSpec> _specs = <String, _DownloadSpec>{};

  /// 在跑任务的中止开关（完成 = 请求暂停）。
  final Map<String, Completer<void>> _cancelSignals =
      <String, Completer<void>>{};

  /// 已结束（completed/failed）任务的**完成顺序**，用于有界保留（BUG-1561）。
  /// Dart 的 Map 迭代序是首次插入序，覆写同 key 不会把它挪到末尾，所以顺序得自己记。
  final List<String> _finishedOrder = <String>[];
  bool _disposed = false;

  /// 已结束任务的保留上限（BUG-1561）。此前 [_tasks] 只增不减：一次会话里下载/重试
  /// 过的每个条目都永久占一格，进程活多久就攒多久。结束态只对「刚发生的事」有意义
  /// （失败角标、重试判据），超出这个窗口的最旧结束态直接淘汰。running / paused
  /// 任务永不淘汰（paused 背后是一份还没下完的 `.part`）。
  static const int maxFinishedTasks = 32;

  /// 取某任务快照（无则 null）。
  InterconnectDownloadTask? taskFor(String id) => _tasks[id];

  /// 某任务是否正在下载（UI 决定显示进度徽标）。
  bool isRunning(String id) => _tasks[id]?.isRunning ?? false;

  /// 启动一个远端书下载任务（EPUB / 漫画包，含随书有声书；键 = [bookTaskId]）。
  /// 已在跑（同 [downloadId]）则忽略重复调用，返回当前任务。
  Future<InterconnectDownloadTask> startBookDownload({
    required String downloadId,
    required String title,
    required File dest,
    required InterconnectDownloadRunner run,
    InterconnectDownloadComplete? onComplete,
  }) =>
      _startDownload(
        bookTaskId(downloadId),
        _DownloadSpec(
          title: title,
          kind: InterconnectDownloadKind.book,
          dest: dest,
          run: _adaptRunner(run),
          onComplete: onComplete,
          pausable: false,
        ),
      );

  static InterconnectVideoDownloadRunner _adaptRunner(
    InterconnectDownloadRunner run,
  ) {
    return (
      File dest, {
      void Function(double progress)? onProgress,
      void Function(int received, int? total)? onBytes,
      Future<void>? cancelSignal,
    }) =>
        run(dest, onProgress: onProgress);
  }

  /// 三个公开入口共用的任务生命周期本体。
  ///
  /// 流程：置 running（不确定进度）→ [run] 驱动下载（更新进度）→
  /// 成功调 [onComplete] 收尾（建行/下字幕）→ 标 completed；任一步失败标 failed 并存
  /// 错误；被暂停标 paused。**整个生命周期与页面无关**：页面 dispose 后任务仍在本
  /// 管理器里推进到底。
  Future<InterconnectDownloadTask> _startDownload(
    String id,
    _DownloadSpec spec,
  ) async {
    final InterconnectDownloadTask? existing = _tasks[id];
    if (existing != null && existing.isRunning) return existing;

    _specs[id] = spec;
    final Completer<void> cancel = Completer<void>();
    _cancelSignals[id] = cancel;
    final InterconnectDownloadTask started = InterconnectDownloadTask(
      id: id,
      title: spec.title,
      status: InterconnectDownloadStatus.running,
      // 继续暂停任务时先沿用暂停前的进度，首个回报（含已有 part）会立刻校正。
      progress: existing?.isPaused == true ? existing!.progress : null,
      kind: spec.kind,
      receivedBytes:
          existing?.isPaused == true ? existing!.receivedBytes : null,
      totalBytes: existing?.isPaused == true ? existing!.totalBytes : null,
      startedAt: _now(),
    );
    _tasks[id] = started;
    // 重跑同一个 id（用户重试）= 上一轮的结束态被消费掉了，从保留窗口里摘掉。
    _finishedOrder.remove(id);
    _notify();

    try {
      await spec.run(
        spec.dest,
        onProgress: (double progress) => _updateProgress(id, progress),
        onBytes: (int received, int? total) =>
            _updateBytes(id, received, total),
        cancelSignal: cancel.future,
      );
      if (spec.onComplete != null) await spec.onComplete!(spec.dest);
      _specs.remove(id);
      _setStatus(id, InterconnectDownloadStatus.completed, progress: 1);
      return _tasks[id]!;
    }  catch (e) {
      _setStatus(
        id,
        InterconnectDownloadStatus.failed,
        // BUG-1693：存**用户可读**的失败原因（对端离线 → 「无法连接配对设备…」），
        // 不是 `SocketException: OS Error: … errno = 1225` 这类原始异常文本——
        // 它会被失败角标 tooltip 原样上屏。未知错误 friendlySyncErrorDetail
        // 回落原文，不吞信息。
        error: friendlySyncErrorDetail(e),
      );
      rethrow;
    } finally {
      if (identical(_cancelSignals[id], cancel)) _cancelSignals.remove(id);
    }
  }

  /// 把 [id] 记进结束窗口并淘汰最旧的溢出项（BUG-1561）。
  void _retainFinished(String id) {
    _finishedOrder
      ..remove(id)
      ..add(id);
    while (_finishedOrder.length > maxFinishedTasks) {
      final String evicted = _finishedOrder.removeAt(0);
      final InterconnectDownloadTask? task = _tasks[evicted];
      // 理论上不会命中 running（只有结束时才进这个表），但真撞上就留着它的状态槽。
      if (task != null && task.isRunning) continue;
      _tasks.remove(evicted);
      _specs.remove(evicted);
    }
  }

  void _updateProgress(String id, double progress) {
    final InterconnectDownloadTask? task = _tasks[id];
    if (task == null || !task.isRunning) return;
    _tasks[id] = task.copyWith(progress: progress.clamp(0.0, 1.0));
    _notify();
  }

  void _updateBytes(String id, int received, int? total) {
    final InterconnectDownloadTask? task = _tasks[id];
    if (task == null || !task.isRunning) return;
    final int? knownTotal = total != null && total > 0 ? total : null;
    _tasks[id] = task.copyWith(
      receivedBytes: received,
      totalBytes: knownTotal,
      progress: _fraction(received, knownTotal ?? task.totalBytes),
    );
    _notify();
  }

  static double? _fraction(int? received, int? total) {
    if (received == null || total == null || total <= 0) return null;
    return (received / total).clamp(0.0, 1.0);
  }

  void _setStatus(
    String id,
    InterconnectDownloadStatus status, {
    double? progress,
    String? error,
  }) {
    final InterconnectDownloadTask? task = _tasks[id];
    if (task == null) return;
    _tasks[id] = task.copyWith(
      status: status,
      progress: progress,
      error: error,
      clearError: error == null,
    );
    if (status == InterconnectDownloadStatus.completed ||
        status == InterconnectDownloadStatus.failed) {
      _retainFinished(id);
    }
    _notify();
  }

  void _notify() {
    if (_disposed) return;
    _syncKeepAlive();
    notifyListeners();
  }

  /// 有任务在跑就挂前台服务（通知里是进度），全停了就撤。节流 / 去重在
  /// [DownloadKeepAlive] 里做，这里每次状态变化都如实报。
  void _syncKeepAlive() {
    final DownloadKeepAlive? keepAlive = _keepAlive;
    if (keepAlive == null) return;
    final List<InterconnectDownloadTask> running = <InterconnectDownloadTask>[
      for (final InterconnectDownloadTask task in _tasks.values)
        if (task.isRunning) task,
    ];
    if (running.isEmpty) {
      // 串行下载的空档（见 [holdKeepAliveDuring]）：不撤，下一条起跑时再 update。
      if (_keepAliveHolds > 0) return;
      if (_keepAliveActive) {
        _keepAliveActive = false;
        unawaited(keepAlive.stop());
      }
      return;
    }
    _keepAliveActive = true;
    int received = 0;
    int total = 0;
    bool totalsKnown = true;
    for (final InterconnectDownloadTask task in running) {
      final int? taskTotal = task.totalBytes;
      if (taskTotal == null) {
        totalsKnown = false;
        break;
      }
      received += task.receivedBytes ?? 0;
      total += taskTotal;
    }
    final int? percent =
        totalsKnown && total > 0 ? (received * 100 ~/ total) : null;
    final String title = running.length == 1
        ? running.single.title
        : t.interconnect_download_notification_title(count: running.length);
    unawaited(keepAlive.update(
      title: title,
      text: percent == null
          ? t.download_task_status_downloading
          : '${t.download_task_status_downloading} · $percent%',
      percent: percent,
    ));
  }

  @override
  void dispose() {
    _disposed = true;
    if (_keepAliveActive) unawaited(_keepAlive?.stop());
    super.dispose();
  }
}

/// app 级单例 provider：在整个 app 生命周期内持有互联下载任务，跨页面存活。
final interconnectDownloadManagerProvider =
    ChangeNotifierProvider<InterconnectDownloadManager>(
  (ref) => InterconnectDownloadManager(
      keepAlive: downloadKeepAliveHub.lease('interconnect')),
);
