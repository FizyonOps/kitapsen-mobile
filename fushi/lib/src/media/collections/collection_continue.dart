/// 统一合集「继续看/继续读」推导（Jellyfin Next-Up 语义的极简版）。
///
/// 不给合集加 currentEpisode 类指针列（消灭状态同步问题）——继续位置纯从成员进度
/// 数据推导。锚点规则（BUG-1542）：取**最近一次播放**的成员（`lastPlayedAt` 最大）；
/// 它已完成 → 下一个（没有下一个就它自己）；否则停在它。
///
/// 为什么锚点是时刻而不是位置：`lastPlayedAt` 落库前（schema v85）这里只有「有没有
/// 进度」的静态事实，只能退而取**排序位置最靠后**的有痕迹成员。那等价于假设「用户
/// 永远按集号单调前进」——用户回头看 PV 或补看早期某集后，锚点仍被 234 集里位置最
/// 靠后的那个残留痕迹钉死（用户实报：刚退出 PV 第 1 集，头部却显示「继续看 第233
/// 集」）。时刻是「用户刚才在看哪一集」的直接事实，位置只是它的一个巧合代理。
///
/// 旧库无时刻数据时（迁移回填不到 `lastPlayedAt` 的成员）自动退回位置口径，行为与
/// v85 前逐字节一致。
library;

/// 成员播放痕迹（合集内已排序，index 0 在前）。
class CollectionMemberProgress {
  const CollectionMemberProgress({
    required this.completed,
  });

  /// 该成员是否已标记完成。
  final bool completed;
}
