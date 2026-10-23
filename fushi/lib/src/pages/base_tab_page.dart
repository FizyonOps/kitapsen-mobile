import 'package:fushi/media.dart';
import 'package:fushi/pages.dart';

/// A template for a single media type's tab body content in the main menu.
///
/// [BaseModuleTabPage] 的 MediaSource 特化子类：在共通 tab 生命周期之上
/// 绑定 [MediaType]（tabRefreshNotifier 刷新信号 + [MediaSource] 代理渲染）。
abstract class BaseTabPage extends BaseModuleTabPage {
  const BaseTabPage({
    super.key,
  });

}

abstract class BaseTabPageState<T extends BaseTabPage>
    extends BaseModuleTabPageState<T> {
  @override
  void initState() {
    super.initState();
    mediaType.tabRefreshNotifier.addListener(refresh);
  }

  @override
  void dispose() {
    mediaType.tabRefreshNotifier.removeListener(refresh);
    super.dispose();
  }

  MediaType get mediaType;

  MediaSource get mediaSource =>
      appModel.getCurrentSourceForMediaType(mediaType: mediaType);

}
