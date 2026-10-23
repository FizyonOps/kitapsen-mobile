import 'package:fushi_platform/fushi_platform.dart';

class IosPermissionService implements PlatformPermissionService {
  @override
  Future<bool> hasExternalStoragePermission() async => true;

}
