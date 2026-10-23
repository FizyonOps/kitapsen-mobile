import 'package:fushi_platform/fushi_platform.dart';
import 'package:restart_app/restart_app.dart';

class IosLifecycleService implements PlatformLifecycleService {
  @override
  bool get supportsRestart => true;

  @override
  Future<void> restartApp() async => Restart.restartApp();

}
