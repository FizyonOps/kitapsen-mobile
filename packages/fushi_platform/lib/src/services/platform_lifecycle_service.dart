abstract class PlatformLifecycleService {
  Future<void> restartApp();
  bool get supportsRestart;
}
