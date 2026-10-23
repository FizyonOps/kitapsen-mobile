
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:fushi/src/utils/misc/toast_severity.dart';

export 'package:fluttertoast/fluttertoast.dart' show Toast, ToastGravity;
// 语义与调色板住在 toast_severity.dart（视频页 OSD 也用，见该文件头注释），
// 这里再导出一次，让既有 `import fushi_toast.dart` 的调用点无需改 import。
export 'package:fushi/src/utils/misc/toast_severity.dart';

/// Cross-platform toast that uses native Fluttertoast on mobile
/// and an overlay-based widget on desktop.
abstract class FushiToast {

  /// [severity] 决定配色与图标（见 [ToastSeverity]）。显式传 [backgroundColor] /
  /// [textColor] 仍然优先——少数调用点（如 tag chip 透传自身颜色）不是语义着色。
  static void show({
    required String msg,
    Toast toastLength = Toast.LENGTH_SHORT,
    ToastGravity gravity = ToastGravity.BOTTOM,
    Color? backgroundColor,
    Color? textColor,
    ToastSeverity severity = ToastSeverity.neutral,
  }) {
    final ({Color background, Color foreground, IconData icon})? palette =
        toastSeverityPalette(severity);
    final Color? bg = backgroundColor ?? palette?.background;
    final Color? fg = textColor ?? palette?.foreground;
    // 原生 toast 画不了图标，只能着色；桌面自绘 overlay 图标齐全。
    Fluttertoast.showToast(
      msg: msg,
      toastLength: toastLength,
      gravity: gravity,
      backgroundColor: bg,
      textColor: fg,
    );
    return;
  }

}
