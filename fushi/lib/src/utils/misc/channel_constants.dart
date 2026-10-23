// Java counterpart: app.fushi.reader.constants.ChannelNames
// Both files MUST stay in sync. If you add a channel here, add it there too.

import 'package:flutter/services.dart';

abstract class FushiChannels {
  static const String _prefix = 'app.fushi.reader';

  static const MethodChannel splash = MethodChannel('$_prefix/splash');
  static const MethodChannel volumeKeys = MethodChannel('$_prefix/volume_keys');

  static const MethodChannel fonts = MethodChannel('$_prefix/fonts');

  /// 长按 app 图标的系统快捷方式（Android launcher shortcuts / iOS quick
  /// actions）。Dart 门面 `lib/src/platform/app_shortcuts.dart`。
  static const MethodChannel appShortcuts =
      MethodChannel('$_prefix/app_shortcuts');
}
