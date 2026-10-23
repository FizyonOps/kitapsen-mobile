import 'package:flutter/widgets.dart';
import 'package:fushi/pages.dart';
import 'package:fushi/src/settings/material_settings_renderer.dart';
import 'package:fushi/src/settings/settings_context.dart';
import 'package:fushi/src/settings/settings_destination.dart';
import 'package:fushi/src/settings/settings_schema.dart';
import 'package:fushi/utils.dart';

class SettingsDetailPage extends BasePage {
  const SettingsDetailPage({
    required SettingsDestination this.destination,
    super.key,
  }) : subPageBuilder = null;

  /// 子 schema 页（[SettingsNavigationItem.child]）：与顶层分类同一套详情壳，但
  /// 新鲜树来自 [subPageBuilder] 而不是按 id 到顶层 schema 里找——子页共用父分类的
  /// id，按 id 找会把父页渲染出来。
  const SettingsDetailPage.subPage(
    SettingsDestination Function() this.subPageBuilder, {
    super.key,
  }) : destination = null;

  final SettingsDestination? destination;
  final SettingsDestination Function()? subPageBuilder;

  @override
  BasePageState<SettingsDetailPage> createState() => _SettingsDetailPageState();
}

class _SettingsDetailPageState extends BasePageState<SettingsDetailPage>
    with SettingsContextHost<SettingsDetailPage> {
  @override
  void initState() {
    super.initState();
    ErrorLogService.instance.addListener(_onLogChanged);
    DebugLogService.instance.addListener(_onLogChanged);
  }

  @override
  void dispose() {
    ErrorLogService.instance.removeListener(_onLogChanged);
    DebugLogService.instance.removeListener(_onLogChanged);
    super.dispose();
  }

  void _onLogChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final SettingsContext settingsContext =
        createSettingsContext(appModel: appModel, ref: ref);
    final SettingsDestination destination = _freshDestination(settingsContext);
    if (!destination.isVisible(settingsContext)) {
      // 本帧还得返回点什么；pop 在帧末执行，用户看不到这一帧的空白。
      return const SizedBox.shrink();
    }
    return const MaterialSettingsRenderer().buildDetailPage(
      settingsContext: settingsContext,
      destination: destination,
    );
  }

  SettingsDestination _freshDestination(SettingsContext settingsContext) {
    final SettingsDestination Function()? subPage = widget.subPageBuilder;
    if (subPage != null) return subPage();
    final SettingsDestination top = widget.destination!;
    for (final SettingsDestination destination
        in buildSettingsSchema(settingsContext)) {
      if (destination.id == top.id) return destination;
    }
    return top;
  }
}
