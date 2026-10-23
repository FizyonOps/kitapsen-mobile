import 'package:flutter/material.dart';
import 'package:fushi/src/utils/components/fushi_motion_tokens.dart';

Future<T?> showAppDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  Color? barrierColor,
}) {
  return showDialog<T>(
    context: context,
    builder: builder,
    barrierDismissible: barrierDismissible,
    barrierColor: barrierColor,
    animationStyle: fushiMd3DialogAnimationStyle,
  );
}
