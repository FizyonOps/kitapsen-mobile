import 'package:flutter/material.dart';
import 'package:fushi/src/utils/adaptive/adaptive_platform.dart';
import 'package:fushi/src/utils/app_ui_scale.dart';
import 'package:fushi/src/utils/components/fushi_motion_tokens.dart';

Widget adaptiveDialogAction({
  required BuildContext context,
  required VoidCallback? onPressed,
  required Widget child,
  bool isDestructiveAction = false,
  bool isDefaultAction = false,
}) {
  if (isDestructiveAction) {
    final cs = Theme.of(context).colorScheme;
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: cs.errorContainer,
        foregroundColor: cs.onErrorContainer,
      ),
      child: child,
    );
  }
  if (isDefaultAction) {
    return FilledButton(
      onPressed: onPressed,
      child: child,
    );
  }
  return TextButton(
    onPressed: onPressed,
    child: child,
  );
}

Widget adaptiveSwitch({
  required BuildContext context,
  required bool value,
  required ValueChanged<bool>? onChanged,
  Color? activeColor,
}) {
  return Switch(
    value: value,
    onChanged: onChanged,
    activeColor: activeColor,
  );
}

Widget adaptiveSlider({
  required BuildContext context,
  required double value,
  required ValueChanged<double>? onChanged,
  double min = 0.0,
  double max = 1.0,
  int? divisions,
  String? label,
  Color? thumbColor,
  ValueChanged<double>? onChangeStart,
  ValueChanged<double>? onChangeEnd,
}) {
  final Widget slider = Slider(
    value: value,
    onChanged: onChanged,
    min: min,
    max: max,
    divisions: divisions,
    label: label,
    thumbColor: thumbColor,
    onChangeStart: onChangeStart,
    onChangeEnd: onChangeEnd,
  );
  // 值指示器水平钳制根因修复（见 slider_value_indicator_scale_test.dart）：
  // Material Slider 的 getHorizontalShift 用 parentBox.localToGlobal(center)（GLOBAL/
  // view 坐标，含 Transform.scale 的 ×s）与 sizeWithOverflow(= MediaQuery.sizeOf) 比较，
  // SDK 假定两者同空间。FushiAppUiScale 把树放大 s 倍、却把 MediaQuery.size 缩成 view/s，
  // 两空间差 s²，钳制甩飞气泡。这里把 Slider 看到的 screenSize 还原回 GLOBAL/view 空间
  // (= size * scale)，与 localToGlobal 同空间，钳制即正确归零。scale==1.0 为 no-op。
  // 只改 size（保留 textScaler 等），且 Slider 布局宽度来自父约束、不依赖 MediaQuery.size，
  // 故仅影响值指示器钳制这一条买路。
  final double uiScale = FushiAppUiScale.of(context);
  if (uiScale == FushiAppUiScale.defaultScale) return slider;
  final MediaQueryData mq = MediaQuery.of(context);
  return MediaQuery(
    data: mq.copyWith(size: mq.size * uiScale),
    child: slider,
  );
}

/// [value] 非空时画**确定**进度（0..1）；为空时是原本的不确定动画。两个平台分支都
/// 认这个值，避免「Material 显进度、Cupertino 一直转」的静默分歧。
///
/// eink 下不确定态改成一枚静止的沙漏：转圈是永不停歇的动画，墨水屏上等于那一小块
/// 持续局部刷新（闪烁 + 残影）；确定进度照常画环（一次一格、不连续重绘）。
Widget adaptiveIndicator({
  required BuildContext context,
  Color? color,
  double? strokeWidth,
  double? value,
}) {
  if (value == null && isEinkTheme(context)) {
    // 这是全局 helper：不少调用点把它包在 14~20 px 的 tight SizedBox 里（Anki
    // 配置行、字幕重匹配、阅读器快捷设置……），父约束会把 36 压到 16 而 24 px 的
    // 字形不缩，裁成残缺一角。FittedBox.scaleDown 让沙漏随容器缩、无约束时不放大。
    return SizedBox(
      width: 36,
      height: 36,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Icon(
          Icons.hourglass_top,
          color: color ?? Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
  return CircularProgressIndicator(
    color: color,
    strokeWidth: strokeWidth ?? 4.0,
    value: value,
  );
}

Future<T?> adaptiveModalSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = true,
  bool showDragHandle = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    showDragHandle: showDragHandle,
    sheetAnimationStyle: fushiMd3SheetAnimationStyle,
    builder: builder,
  );
}

Widget adaptiveSegmentedButton<T extends Object>({
  required BuildContext context,
  required List<ButtonSegment<T>> segments,
  required Set<T> selected,
  required ValueChanged<Set<T>> onSelectionChanged,
  ButtonStyle? style,
}) {
  return SegmentedButton<T>(
    showSelectedIcon: false,
    segments: segments,
    selected: selected,
    onSelectionChanged: onSelectionChanged,
    style: style,
  );
}

Route<T> adaptivePageRoute<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  RouteSettings? settings,
  bool fullscreenDialog = false,
}) {
  return MaterialPageRoute<T>(
    builder: builder,
    settings: settings,
    fullscreenDialog: fullscreenDialog,
  );
}
