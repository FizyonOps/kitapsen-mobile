/// 显式确认式删除传播的纯决策核心 + 远端墓碑标记编解码（多端库联合视图 / 删除传播）。
///
/// 数据流：本地删资产 → sync_deletion_tombstones 记墓碑（见 FushiDatabase）→ 同步时发布
/// 成远端标记（云 `__tombstones__/<marker>.json` / 互联 host 暴露）→ compare 对话框读双方
/// 墓碑与在库态，经 [computeDeletionPropagation] 算出**待用户逐条确认**的候选，绝不静默自动删
/// （与 union-only 的安全取舍一致）。纯 Dart：零 IO、零 Flutter 依赖，便于单测。
library;

/// 用户在删除某资产时选择的传播范围（源设备弹窗采集）。
///
/// - [keepLocalOnly]：只删本机，不写传播墓碑——其他设备保留（仍走本机原有防复活语义）。
/// - [syncEverywhere]：写 `sync_deletion_tombstones` 墓碑并在同步时发布到远端标记，
///   其他设备同步时读到标记 → 逐条确认 → 也删（见 [computeDeletionPropagation]）。
enum DeleteScope {
  keepLocalOnly,
  syncEverywhere,
}

/// 用户在删除确认框里做出的完整决定：传播范围 + 本地原件 + 统计事实。
///
/// 三个维度正交：[scope] 只管「其他设备删不删」（墓碑），[deleteLocalFiles] 只管
/// 「本机磁盘上用户自己的原件删不删」（视频文件 / 有声书原始音频），
/// [deleteStatistics] 只管「这条媒体攒下的学习/观看统计删不删」。后两者默认 false
/// ——现有所有入口的语义（只删库记录 + app 自己的副本）一个字都不变。
///
/// [deleteStatistics] 单独一维而不跟着 [scope] 走：统计是**另一类事实**，删掉一部
/// 看完的番并不等于要把看它花掉的那些小时从图表里抹掉。反过来它也不受
/// [DeleteScope.keepLocalOnly] 约束——统计删除按媒体身份立碑（见
/// `deleteVideoStatisticsForIdentity`），否则下一轮聚合同步会把对端还留着的段整批
/// 灌回来（BUG-2215 的原文）。
class DeleteDecision {
  const DeleteDecision({
    required this.scope,
    this.deleteLocalFiles = false,
    this.deleteStatistics = false,
  });

  final DeleteScope scope;
  final bool deleteLocalFiles;
  final bool deleteStatistics;

  @override
  bool operator ==(Object other) =>
      other is DeleteDecision &&
      other.scope == scope &&
      other.deleteLocalFiles == deleteLocalFiles &&
      other.deleteStatistics == deleteStatistics;

  @override
  int get hashCode => Object.hash(scope, deleteLocalFiles, deleteStatistics);

  @override
  String toString() => 'DeleteDecision(${scope.name}, '
      'deleteLocalFiles: $deleteLocalFiles, '
      'deleteStatistics: $deleteStatistics)';
}
