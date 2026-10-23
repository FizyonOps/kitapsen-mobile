import 'package:flutter/material.dart';

/// The launcher icon, shown as the navigation rail's brand mark.
const String kAppIconAsset = 'assets/meta/launcher_icon_squircle.png';

/// Renders the application icon.
class CurrentAppIcon extends StatelessWidget {
  const CurrentAppIcon({
    super.key,
    this.fit = BoxFit.contain,
    this.filterQuality = FilterQuality.medium,
  });

  final BoxFit fit;
  final FilterQuality filterQuality;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      kAppIconAsset,
      fit: fit,
      filterQuality: filterQuality,
      excludeFromSemantics: true,
    );
  }
}
