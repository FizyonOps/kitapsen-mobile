/// 开书链路的分阶段计时（从页面 initState 起只算一次「点开书 → 首屏恢复完成」）。
///
/// 阶段由页面按顺序 [mark]：settings → located → parsed → charCounts → spreadMap →
/// position → webViewCreated → firstRestore；有声书槽异步落定时补 `audioSlot`。
/// [report] 用 `debugPrint` 打一行 `[open-perf] …`——`DebugLogService` 开着时会被
/// 拦进应用内调试日志（设置 → 调试日志），用户机上就能看到每一段耗时。
library;

import 'package:flutter/foundation.dart';

class ReaderOpenTrace {
  ReaderOpenTrace(this.label) : _watch = Stopwatch()..start();

  final String label;
  final Stopwatch _watch;
  final List<({String stage, int atMs})> _marks =
      <({String stage, int atMs})>[];
  bool _reported = false;

  /// 记录一个阶段的到达时刻（同名只记第一次，多次调用幂等）。
  void mark(String stage) {
    if (_marks.any((m) => m.stage == stage)) return;
    _marks.add((stage: stage, atMs: _watch.elapsedMilliseconds));
  }

  /// 各阶段相对上一阶段的增量：`stage=+Δms`，最后附总时长。
  String summary() {
    final StringBuffer sb = StringBuffer('[open-perf] $label');
    int prev = 0;
    for (final m in _marks) {
      sb.write(' ${m.stage}=+${m.atMs - prev}ms');
      prev = m.atMs;
    }
    sb.write(' total=${_watch.elapsedMilliseconds}ms');
    return sb.toString();
  }

  /// 首屏恢复完成时打一次汇总（只打一次）；之后有声书槽落定等迟到阶段单独补一行。
  void report() {
    if (_reported) return;
    _reported = true;
    debugPrint(summary());
  }
}
