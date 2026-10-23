
import 'package:flutter/material.dart';

enum FushiDesignSystem { auto, material }

@immutable
class FushiDesignSystemTheme extends ThemeExtension<FushiDesignSystemTheme> {
  const FushiDesignSystemTheme(this.designSystem);

  final FushiDesignSystem designSystem;

  @override
  FushiDesignSystemTheme copyWith({FushiDesignSystem? designSystem}) {
    return FushiDesignSystemTheme(designSystem ?? this.designSystem);
  }

  @override
  FushiDesignSystemTheme lerp(
    covariant ThemeExtension<FushiDesignSystemTheme>? other,
    double t,
  ) {
    return this;
  }
}

/// 墨水屏模式标志的 ThemeExtension 载体。挂在 ThemeNotifier._buildThemeData 的
/// extensions 里，使任意 widget 可经 `Theme.of(context)` 感知 eink（用于把入场
/// 淡入/滑出等 Flutter 侧动画时长归零），零新增数据流、随主题重建自动更新。
@immutable
class FushiEinkTheme extends ThemeExtension<FushiEinkTheme> {
  const FushiEinkTheme(this.einkMode);

  final bool einkMode;

  @override
  FushiEinkTheme copyWith({bool? einkMode}) {
    return FushiEinkTheme(einkMode ?? this.einkMode);
  }

  @override
  FushiEinkTheme lerp(
    covariant ThemeExtension<FushiEinkTheme>? other,
    double t,
  ) {
    return this;
  }
}

/// True 当墨水屏模式开启（读不到扩展时为 false，测试裸 ThemeData 零破坏）。
bool isEinkTheme(BuildContext context) {
  return Theme.of(context).extension<FushiEinkTheme>()?.einkMode ?? false;
}

/// eink 下把动画时长归零（墨水屏连续重绘=残影），否则原样返回。
/// 共享组件与页面级 Animated* 统一走这里，别再手写三元。
Duration einkSafeDuration(BuildContext context, Duration duration) {
  return isEinkTheme(context) ? Duration.zero : duration;
}

/// eink 下把不定态进度（`value == null`）钉成 0：不定态是一条永不停歇的往复
/// 动画，墨水屏上等于整条进度带持续局部刷新（残影 + 闪烁）；旁边的文案已经在
/// 说「正在下载 / 同步中」，静止的空轨道足够表达。非 eink 原样返回。
double? einkSafeProgressValue(BuildContext context, double? value) {
  return isEinkTheme(context) ? (value ?? 0) : value;
}
