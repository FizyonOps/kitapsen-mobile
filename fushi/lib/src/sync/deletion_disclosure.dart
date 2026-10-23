import 'package:flutter/material.dart';
import 'package:fushi/utils.dart';

/// 删除确认框的回传：用户确认删除时是否连同统计数据一起删。
@immutable
class DeleteDecision {
  const DeleteDecision({this.deleteStatistics = false});

  final bool deleteStatistics;
}

class DeletionDisclosure {
  const DeletionDisclosure({
    required this.willDelete,
    required this.willKeep,
    this.statisticsEntry,
  });

  /// 确认后真的会从本机消失的东西。
  final List<String> willDelete;

  /// 确认后仍然留着的东西——尤其是用户自己导入的原始文件。
  final List<String> willKeep;

  /// 勾选「同时删除统计数据」时从「会被保留」挪进「会被删除」的那一条；null = 这个
  /// 目标的披露不涉及统计。必须是 `willKeep` 的成员。
  final String? statisticsEntry;

  /// 勾选「同时删除统计数据」后的披露：[statisticsEntry] 从「会被保留」挪进「会被
  /// 删除」。幂等，且与 [withLocalFilesDeleted] 可任意顺序叠加。
  DeletionDisclosure withStatisticsDeleted() {
    final String? entry = statisticsEntry;
    if (entry == null || willDelete.contains(entry)) return this;
    return DeletionDisclosure(
      willDelete: <String>[...willDelete, entry],
      willKeep: <String>[
        for (final String item in willKeep)
          if (item != entry) item,
      ],
      statisticsEntry: entry,
    );
  }
}

/// 删除书架上一本书时的逐项披露（会被删除 / 会被保留）。
DeletionDisclosure buildDeletionDisclosure() {
  return DeletionDisclosure(
    willDelete: <String>[
      t.delete_disclosure_book_records,
      t.delete_disclosure_book_extracted,
    ],
    willKeep: <String>[
      t.delete_disclosure_source_kept,
      t.delete_disclosure_stats_kept,
    ],
    statisticsEntry: t.delete_disclosure_stats_kept,
  );
}

/// 两个删除确认框（`showDeleteScopeConfirm` / `ReaderHistoryDeleteDialog`）里
/// **唯一**的勾选行形状：「从所有设备删除」与「同时删除本地文件」共用它，两个新老
/// 选项不会各写一套长相。
///
/// 不覆盖下载任务面板那个确认框：它是 `AlertDialog`，会对 content 做 intrinsic
/// 测量，而本行内部的 `AdaptiveSettingsRow` 含 `LayoutBuilder`（
/// 「LayoutBuilder does not support returning intrinsic dimensions」直接崩）。
/// 要连它一起统一得先把那个弹窗换成 `FushiModalSheetFrame`，是另一件事。
///
/// [destructive]：勾选态用 error 色。删用户自己的原件比「同步到别的设备」重，
/// 视觉上必须区分得开。
class DeleteConfirmCheckboxRow extends StatelessWidget {
  const DeleteConfirmCheckboxRow({
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.destructive = false,
    super.key,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return AdaptiveSettingsRow(
      title: title,
      subtitle: subtitle,
      onTap: () => onChanged(!value),
      trailing: Icon(
        value ? Icons.check_box : Icons.check_box_outline_blank,
        color: value
            ? (destructive ? colors.error : colors.primary)
            : colors.onSurfaceVariant,
      ),
    );
  }
}

/// 「同时删除统计数据」勾选行。
///
/// [subtitle] 与 [DeleteLocalFilesRow] 同样**必填**：删掉的统计在各域口径不同
/// （视频是观看时长/字幕字数/查词计数），没有一句通用说明能同时成立。
///
/// 它**不进**「记住这些选择」：那一行记的是「这台设备上删东西时的惯常选择」，而
/// 统计删除按媒体身份立碑、其他设备同步后也跟着删，没有撤销——这种事不该因为上次
/// 勾过就默认勾上。
class DeleteStatisticsRow extends StatelessWidget {
  const DeleteStatisticsRow({
    required this.value,
    required this.onChanged,
    required this.subtitle,
    super.key,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final String subtitle;

  @override
  Widget build(BuildContext context) => DeleteConfirmCheckboxRow(
        title: t.delete_statistics,
        subtitle: subtitle,
        value: value,
        onChanged: onChanged,
        destructive: true,
      );
}

/// 把 [DeletionDisclosure] 渲染成确认框里的「会被删除 / 会被保留」两段列表。
///
/// 书架删除确认框（`ReaderHistoryDeleteDialog`）与通用删除确认框
/// （`showDeleteScopeConfirm`）共用本视图，保证两处披露长得一样、也不会各自漂移。
class DeletionDisclosureView extends StatelessWidget {
  const DeletionDisclosureView({required this.disclosure, super.key});

  final DeletionDisclosure disclosure;

  @override
  Widget build(BuildContext context) {
    final FushiDesignTokens tokens = FushiDesignTokens.of(context);
    final ColorScheme colors = Theme.of(context).colorScheme;

    Widget section({
      required String label,
      required IconData icon,
      required Color color,
      required List<String> items,
    }) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, size: 16, color: color),
              SizedBox(width: tokens.spacing.gap / 2),
              Flexible(
                child: Text(
                  label,
                  style: tokens.type.listSubtitle.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          for (final String item in items)
            Padding(
              padding: EdgeInsets.only(
                left: tokens.spacing.gap + tokens.spacing.gap / 2,
                top: tokens.spacing.gap / 4,
              ),
              child: Text(
                '• $item',
                style: tokens.type.listSubtitle.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        section(
          label: t.delete_disclosure_will_delete_label,
          icon: Icons.delete_outline,
          color: colors.error,
          items: disclosure.willDelete,
        ),
        SizedBox(height: tokens.spacing.gap),
        section(
          label: t.delete_disclosure_will_keep_label,
          icon: Icons.shield_outlined,
          color: colors.primary,
          items: disclosure.willKeep,
        ),
      ],
    );
  }
}
