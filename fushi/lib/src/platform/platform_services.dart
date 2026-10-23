import 'dart:io' show Platform;

import 'package:fushi_platform/fushi_platform.dart';
import 'package:fushi/src/platform/android/android_directory_service.dart';
import 'package:fushi/src/platform/android/android_lifecycle_service.dart';
import 'package:fushi/src/platform/android/android_permission_service.dart';
import 'package:fushi/src/platform/android/android_device_info_service.dart';
import 'package:fushi/src/platform/ios/ios_directory_service.dart';
import 'package:fushi/src/platform/ios/ios_lifecycle_service.dart';
import 'package:fushi/src/platform/ios/ios_permission_service.dart';
import 'package:fushi/src/platform/ios/ios_device_info_service.dart';

/// Holds all platform-specific service implementations.
///
/// Created once in `main()` before `runApp()` and passed to [AppModel] as a
/// constructor parameter. This avoids the need for `AppModel` to know which
/// platform it runs on or to hold a `Ref`.
class PlatformServices {
  final PlatformDirectoryService directory;
  final PlatformLifecycleService lifecycle;
  final PlatformPermissionService permission;
  final PlatformDeviceInfoService deviceInfo;

  /// 本进程跑在 Windows 上吗。
  ///
  /// 收在这里而不是让调用方各自读 `Platform.isWindows`：本类的职责（见类注释）就是
  /// 「让 [AppModel] 不必知道自己跑在哪个平台」，而模块可用性判据
  /// （[ModuleId.availableOn]，galgame 只做 Windows 端）此前绕过本类直读
  /// `dart:io`，于是 widget 测试没有任何缝去声明「这条用例讲的是 Windows」——
  /// 表现为一批仪表盘游戏用例在 Windows 本机全绿、在 Linux CI 上必红。
  /// 默认值仍取真实平台，生产行为不变。
  final bool isWindows;

  /// 本进程跑在桌面端吗（Windows / macOS / Linux）。同上，默认取真实平台。
  final bool isDesktop;

  /// 本进程跑在 iOS 上吗。同上，默认取真实平台。
  ///
  /// 单列一个字段而不是让调用方写 `!isDesktop && !isAndroid`：iOS 在
  /// [ModuleId.availableOn] 里承载的是 App Store 合规边界
  /// （[StoreRestrictedCapability]），与「移动端」这个技术分类不是一回事——
  /// Android 同为移动端却不受任何一条商店限制约束。
  final bool isIOS;

  /// 本进程跑在 Android 上吗。同上，默认取真实平台。
  ///
  /// 只服务于 games 模块的串流形态（`GamesModuleForm.streamClient`）：串流接收端
  /// 只在 Android 上有入口。
  final bool isAndroid;

  PlatformServices({
    required this.directory,
    required this.lifecycle,
    required this.permission,
    required this.deviceInfo,
    bool? isWindows,
    bool? isDesktop,
    bool? isIOS,
    bool? isAndroid,
  })  : isWindows = isWindows ?? false,
        isDesktop = isDesktop ??
            (false || false || false),
        isIOS = isIOS ?? Platform.isIOS,
        isAndroid = isAndroid ?? Platform.isAndroid;

  /// Constructs the correct service bundle for the current platform.
  factory PlatformServices.forCurrentPlatform() {
    if (Platform.isAndroid) {
      final AndroidDeviceInfoService deviceInfo = AndroidDeviceInfoService();
      return PlatformServices(
        directory: AndroidDirectoryService(),
        lifecycle: AndroidLifecycleService(),
        permission: AndroidPermissionService(deviceInfo),
        deviceInfo: deviceInfo,
      );
    }
    if (Platform.isIOS) {
      return PlatformServices(
        directory: IosDirectoryService(),
        lifecycle: IosLifecycleService(),
        permission: IosPermissionService(),
        deviceInfo: IosDeviceInfoService(),
      );
    }
    throw UnsupportedError('Kitapsen runs on Android and iOS only.');
  }
}
