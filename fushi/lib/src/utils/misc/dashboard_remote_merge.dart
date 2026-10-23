import 'package:fushi_core/fushi_core.dart';

/// 新首页仪表盘互联数据混排的纯函数层（「继续/活动也走 hibiki 互联」）。
///
/// - 「继续」：远端候选只补**本地没有**的条目——本地已有同 bookKey/bookUid 时以
///   本地为准（进度 live 同步本就把 host 更新的进度拉进本地 DB，双端都展示只会
///   出重复行）。
/// - 「活动」：远端事件转成 [ActivityEventRow]（id=0 哨兵，不落库）与本地事件
///   一起流入既有聚合 `aggregateActivityEvents`——聚合键含设备维（provenance），
///   双端 session 各自成条不合并；同设备同日同条目（mediaKey，缺失回落标题）
///   才合并计数（BUG-1350 后语义）。
///
/// 纯 Dart 无 IO，便于单测。
abstract class RemoteContinueCandidate {

}
