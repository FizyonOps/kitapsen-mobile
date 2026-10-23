import 'package:flutter/widgets.dart';
import 'package:fushi/i18n/strings.g.dart';
import 'package:fushi/src/settings/settings_destination.dart';

/// 一级导航分组固定展开，分区内部的展开策略与此无关。
enum SettingsNavigationGroupId {
  interface,
  content,
  connections,
  data,
  app;

  String title(BuildContext context) => switch (this) {
    interface => context.t.settings_group_interface,
    content => context.t.settings_group_content,
    connections => context.t.settings_group_connections,
    data => context.t.settings_group_data,
    app => context.t.settings_group_app,
  };
}

class SettingsNavigationGroup {
  SettingsNavigationGroup(this.id, Iterable<SettingsDestination> destinations)
    : destinations = List<SettingsDestination>.unmodifiable(destinations);

  final SettingsNavigationGroupId id;
  final List<SettingsDestination> destinations;
}

SettingsNavigationGroupId settingsNavigationGroupFor(
  SettingsDestinationId id,
) => switch (id) {
  SettingsDestinationId.appearance => SettingsNavigationGroupId.interface,
  SettingsDestinationId.reading => SettingsNavigationGroupId.content,
  SettingsDestinationId.services => SettingsNavigationGroupId.connections,
  SettingsDestinationId.storage => SettingsNavigationGroupId.data,
  SettingsDestinationId.system ||
  SettingsDestinationId.readerQuickSettings => SettingsNavigationGroupId.app,
};

/// 接收经过平台和模块门控后的列表，保留 schema 组内顺序，不生成空标题。
List<SettingsNavigationGroup> groupSettingsDestinations(
  List<SettingsDestination> destinations,
) {
  return <SettingsNavigationGroup>[
    for (final SettingsNavigationGroupId id in SettingsNavigationGroupId.values)
      if (destinations.any(
        (SettingsDestination destination) =>
            settingsNavigationGroupFor(destination.id) == id,
      ))
        SettingsNavigationGroup(
          id,
          destinations.where(
            (SettingsDestination destination) =>
                settingsNavigationGroupFor(destination.id) == id,
          ),
        ),
  ];
}
