import 'package:flutter/material.dart';
import 'package:fushi/src/settings/settings_home_page.dart';

// ─── Full-page version (home "调整" tab) ──────────────────────────────────────

class FushiSettingsContent extends StatelessWidget {
  const FushiSettingsContent({super.key, this.onBack});

  /// 非空时在设置页头左侧显示返回箭头（宽屏隐藏图标侧栏的全屏设置场景）。
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return SettingsHomePage(embedded: true, onBack: onBack);
  }
}
