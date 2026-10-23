import 'package:drift/drift.dart' show Value;
// 引擎只准 import 纯 Dart 子 barrel：全 barrel 会导出 just_audio /
// shared_preferences / file_picker，把 Flutter 拖进无头服务端的 AOT 编译
// （守卫 fushi/test/build/fushi_engine_purity_guard_test.dart）。
// StudyClock 就在子 barrel 里（fushi_reading.dart 导出 src/reading/study_clock.dart）。
import 'package:fushi_reading/fushi_reading.dart';
import 'package:fushi_core/fushi_core.dart';

/// 同一媒体相邻两段间隔不超过这个值就归成同一次会话（与首页活动流的
/// `kActivitySessionGap` 同值：一条纪律，两处消费）。
const Duration kStudySessionGap = Duration(minutes: 30);

/// 删一次会话的**唯一**入口：先让段 uid 在所有在跑的 `StudyClock` 上退役，再删库。
///
/// 顺序不能反。时钟按 uid upsert **绝对值**，删库与退役之间落下的任何一个 tick 都会
/// 把刚写零的行原样写回去——用户删掉「刚刚那次」（书还开着、段还开着）时必然撞上，
/// 表现为「删了又回来」。
/// 页面**不要**直接调 `FushiDatabase.deleteStudySession`。
Future<void> deleteStudySession(FushiDatabase db, StudySession s) async {
  retireStudySegmentUids(s.segmentUids);
  await db.deleteStudySession(segmentUids: s.segmentUids.toSet());
}

/// 清空全部学习会话（统计页会话区块的「清除全部会话」）的**唯一**入口。
///
/// 逐会话走 [deleteStudySession] 的同一条纪律（先在 `StudyClock` 上退役 uid 再写库），
/// 只是把退役与写库各批成一次：会话流常年几十上百条，逐条一个事务在移动端能卡住
/// 整个 UI 帧。语义与逐条删逐字节一致——段写零、不立墓碑。
///
/// 只清 [sessions] 里这一批（调用页传自己域的切片，总览传跨域全量），不是「清空
/// 本域全部统计」——legacy 日行、收藏一个都不动。
Future<void> deleteStudySessions(
  FushiDatabase db,
  List<StudySession> sessions,
) async {
  if (sessions.isEmpty) return;
  final Set<String> uids = <String>{
    for (final StudySession s in sessions) ...s.segmentUids,
  };
  retireStudySegmentUids(uids.toList());
  await db.deleteStudySessions(segmentUids: uids);
}

/// 用户对一次会话的编辑意图（统计页会话行的铅笔）：`null` = 该项不改。
///
/// 只开放**日期**与**字数**两项（用户 2026-09-10）：日期只挪日历日、保留时分秒，
/// 段「不跨本地小时边界」的不变式因此原样成立（[StudySegments.hour] 恒等于新
/// [StudySegments.startAt] 的小时）；时长不开放——它是段的活跃时长求和，改它要么
/// 得凭空发明分摊、要么破坏 `endAt - startAt >= durationMs`。
class StudySessionEdit {
  const StudySessionEdit({this.date, this.chars});

  /// 目标日历日（只取 y/m/d，时分秒忽略）；null = 不挪日期。
  final DateTime? date;

  /// 会话新的**总**字数；null = 不改字数。
  final int? chars;

  bool get isEmpty => date == null && chars == null;
}

/// 纯函数：把会话新的总字数 [total] 分摊回各段。
///
/// [current] 是各段**现有**字数（顺序即段顺序）。按现有字数比例分，除不尽的余数
/// 全给第一段（保证 `sum(out) == total` 逐字节成立）；各段现有字数全为 0（纯时长
/// 段）时整数落在第一段——没有任何信息能支持更细的分法，把它摊平反而
/// 让每段都带上一个凭空捏造的数字。
List<int> distributeSessionChars(List<int> current, int total) {
  if (current.isEmpty) return const <int>[];
  final int clamped = total < 0 ? 0 : total;
  final int sum = current.fold<int>(0, (int a, int b) => a + b);
  if (sum <= 0) {
    return <int>[clamped, for (int i = 1; i < current.length; i++) 0];
  }
  final List<int> out = <int>[
    for (final int c in current) (clamped * c) ~/ sum,
  ];
  out[0] += clamped - out.fold<int>(0, (int a, int b) => a + b);
  return out;
}

/// 纯函数：日期平移量（毫秒）。[from] 是会话原起始时刻，[to] 是目标日历日。
///
/// 按**日历日之差**平移整个会话（不是「把 startAt 的年月日换掉」）：会话可以跨午夜，
/// 逐段各自换年月日会把跨午夜的后半段拉回同一天、打乱段间相对关系。
int studySessionDateShiftMs(DateTime from, DateTime to) =>
    DateTime(to.year, to.month, to.day)
        .difference(DateTime(from.year, from.month, from.day))
        .inMilliseconds;

/// 编辑一次学习会话的**唯一**入口。顺序与 [deleteStudySession] 同一条纪律：
/// 先让段 uid 在所有在跑的 `StudyClock` 上退役，再写库——时钟按 uid upsert 绝对值，
/// 改库与退役之间落下的任何一个 tick 都会把刚改完的段按旧值原样写回去（「改了又弹
/// 回来」）。页面**不要**直接调 `FushiDatabase.updateStudySession`。
Future<void> applyStudySessionEdit(
  FushiDatabase db,
  StudySession s,
  StudySessionEdit edit,
) async {
  if (edit.isEmpty) return;
  final int shiftMs = edit.date == null
      ? 0
      : studySessionDateShiftMs(
          DateTime.fromMillisecondsSinceEpoch(s.startAt),
          edit.date!,
        );
  final List<StudySegmentRow> rows =
      await db.getStudySegmentsByUids(s.segmentUids.toSet());
  // 段顺序按 startAt 定死，分摊结果才与「哪一段是第一段」无关于查询返回顺序。
  rows.sort(
      (StudySegmentRow a, StudySegmentRow b) => a.startAt.compareTo(b.startAt));
  final List<int> newChars = edit.chars == null
      ? <int>[for (final StudySegmentRow r in rows) r.chars]
      : distributeSessionChars(
          <int>[for (final StudySegmentRow r in rows) r.chars],
          edit.chars!,
        );
  final int now = DateTime.now().millisecondsSinceEpoch;
  final List<StudySegmentsCompanion> updates = <StudySegmentsCompanion>[];
  for (int i = 0; i < rows.length; i++) {
    final StudySegmentRow r = rows[i];
    final int startAt = r.startAt + shiftMs;
    final DateTime startDay = DateTime.fromMillisecondsSinceEpoch(startAt);
    updates.add(StudySegmentsCompanion(
      uid: Value(r.uid),
      startAt: Value(startAt),
      endAt: Value(r.endAt + shiftMs),
      dateKey: Value(FushiDatabase.statDateKeyOf(startDay)),
      hour: Value(startDay.hour),
      chars: Value(newChars[i]),
      updatedAt: Value(now),
    ));
  }
  retireStudySegmentUids(s.segmentUids);
  await db.updateStudySession(segments: updates);
}

/// 一次学习会话（统计页「最近会话」一行）：**派生视图，不落库**。
///
/// 事实只有 `study_segments`（一段一行、整点切段、uid 键控）。会话 = 同
/// (deviceId, mediaKind, mediaKey) 的相邻段按 [kStudySessionGap] 归并。
///
/// 删除一次会话 = 它的段按 uid **写零**（`FushiDatabase.deleteStudySession`，与按天删同一
/// 原语：零值是一次新的绝对值写，经 uid LWW 同步自然传到对端；**不**立按身份的墓碑——
/// 那会压死这本书的全部历史）。
class StudySession {
  StudySession({
    required this.mediaKind,
    required this.mediaKey,
    required this.title,
    required this.format,
    required this.deviceId,
    required this.startAt,
    required this.endAt,
    required this.durationMs,
    required this.chars,
    required this.pages,
    required List<String> segmentUids,
  }) : segmentUids = List<String>.unmodifiable(segmentUids);

  final String mediaKind;
  final String mediaKey;

  /// 展示快照（段的 title）；空串时展示层回退 [mediaKey]。
  final String title;
  final String format;
  final String deviceId;
  final int startAt;
  final int endAt;
  final int durationMs;
  final int chars;
  final int pages;

  /// 组成本会话的段 uid（删除时写零的行集）。
  final List<String> segmentUids;

  bool get isBook => mediaKind == kActivityMediaBook;

  /// 按一次编辑生成**同一条**会话的展示副本（起止平移、总字数替换）。
  ///
  /// 只给「全部会话」sheet 用：sheet 拿的是打开那一刻的快照，页面在它底下重聚合
  /// 不会让 sheet 里的行跟着变，用户改完看到的还是旧值。真相仍以重聚合为准
  /// （改完日期的会话可能与相邻会话合并成一条，这里算不出来），所以关掉 sheet
  /// 之后看到的才是最终形态。
  StudySession withEdit(StudySessionEdit edit) {
    final int shiftMs = edit.date == null
        ? 0
        : studySessionDateShiftMs(
            DateTime.fromMillisecondsSinceEpoch(startAt),
            edit.date!,
          );
    return StudySession(
      mediaKind: mediaKind,
      mediaKey: mediaKey,
      title: title,
      format: format,
      deviceId: deviceId,
      startAt: startAt + shiftMs,
      endAt: endAt + shiftMs,
      durationMs: durationMs,
      chars: edit.chars ?? chars,
      pages: pages,
      segmentUids: segmentUids,
    );
  }

  /// 展示 / 删除的稳定键（同一派生结果内唯一）。
  String get key => 'seg:${segmentUids.first}';
}

bool _isZero(StudySegmentRow s) =>
    s.durationMs <= 0 && s.chars <= 0 && s.pages <= 0;

/// 从事实派生会话列表，按结束时刻倒序。
///
/// [segments] 写零的行（用户已删）不进任何会话；legacy 日行没有 uid、没有起止时刻，
/// 本来就不在这里——会话流只覆盖 v92 之后的数据。
List<StudySession> deriveStudySessions({
  required List<StudySegmentRow> segments,
  Duration gap = kStudySessionGap,
}) {
  final List<StudySession> out = <StudySession>[];

  // 同 (device, kind, key) 按起始时刻排序，gap 内相邻归并。
  final List<StudySegmentRow> rest = <StudySegmentRow>[
    for (final StudySegmentRow s in segments)
      if (!_isZero(s)) s,
  ]..sort((StudySegmentRow a, StudySegmentRow b) {
      final int c = _compareGroup(_groupKey(a), _groupKey(b));
      return c != 0 ? c : a.startAt.compareTo(b.startAt);
    });
  final int gapMs = gap.inMilliseconds;
  _Run? run;
  for (final StudySegmentRow s in rest) {
    if (run != null &&
        run.groupKey == _groupKey(s) &&
        s.startAt - run.endAt <= gapMs) {
      run.add(s);
      continue;
    }
    if (run != null) out.add(run.build());
    run = _Run(s);
  }
  if (run != null) out.add(run.build());

  out.sort((StudySession a, StudySession b) => b.endAt.compareTo(a.endAt));
  return out;
}

/// 归并分组键：record 相等 / 比较按三段身份逐字段，不拼字符串（拼接分隔符要么撞
/// 身份字符集，要么得写 NUL——源码含裸 NUL 会被 git 判 binary）。
typedef _GroupKey = (String deviceId, String mediaKind, String mediaKey);

_GroupKey _groupKey(StudySegmentRow s) => (s.deviceId, s.mediaKind, s.mediaKey);

int _compareGroup(_GroupKey a, _GroupKey b) {
  final int d = a.$1.compareTo(b.$1);
  if (d != 0) return d;
  final int k = a.$2.compareTo(b.$2);
  if (k != 0) return k;
  return a.$3.compareTo(b.$3);
}

class _Run {
  _Run(StudySegmentRow first)
      : groupKey = _groupKey(first),
        first = first,
        endAt = first.endAt {
    add(first);
  }

  final _GroupKey groupKey;
  final StudySegmentRow first;
  int endAt;
  int durationMs = 0;
  int chars = 0;
  int pages = 0;
  final List<String> uids = <String>[];
  String title = '';

  void add(StudySegmentRow s) {
    if (s.endAt > endAt) endAt = s.endAt;
    durationMs += s.durationMs;
    chars += s.chars;
    pages += s.pages;
    uids.add(s.uid);
    // 最新一段的 title 快照最接近当前显示名。
    if (s.title.isNotEmpty) title = s.title;
  }

  StudySession build() => StudySession(
        mediaKind: first.mediaKind,
        mediaKey: first.mediaKey,
        title: title,
        format: first.format,
        deviceId: first.deviceId,
        startAt: first.startAt,
        endAt: endAt,
        durationMs: durationMs,
        chars: chars,
        pages: pages,
        segmentUids: uids,
      );
}
