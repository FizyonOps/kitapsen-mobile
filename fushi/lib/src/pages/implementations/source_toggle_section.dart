import 'package:flutter/material.dart';

/// 来源开关区的小节标题（图标 + 标题 + 说明）。
///
/// 「外部资源与字幕来源」里那份原本是私有的 `_sectionHeading`；发现来源区要和它
/// 长得一样，抄一份就会漂，所以提到共用层，原处改为委托。
class SourceSectionHeading extends StatelessWidget {
  const SourceSectionHeading({
    super.key,
    required this.title,
    required this.hint,
    this.icon,
  });

  final String title;
  final String hint;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 20, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: theme.textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  hint,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
