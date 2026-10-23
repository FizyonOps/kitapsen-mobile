import 'dart:async';

import 'package:flutter/material.dart';
import 'package:fushi/media.dart';
import 'package:fushi/pages.dart';
import 'package:fushi/src/media/reader_exit_flush.dart';
import 'package:fushi/src/sync/kitapsen_client.dart'
    show syncKitapsenBookProgress;

/// A page template which assumes use of [BaseSourcePageState] by which all
/// pages in the app that are used for when using a certain source will
/// conveniently share base functionality.f
abstract class BaseSourcePage extends BasePage {
  /// Create an instance of this tab page.
  const BaseSourcePage({
    required this.item,
    super.key,
  });

  /// The media item pertaining to this usage instance of the source.
  final MediaItem? item;

}

/// A base class for providing all pages used for media in the app with a
/// collection of shared functions and variables. In large part, this was
/// implemented to define shortcuts for common lengthy methods across UI code.
abstract class BaseSourcePageState<T extends BaseSourcePage>
    extends BasePageState<T> {

  @override
  void initState() {
    super.initState();

    // Kitapsen: no dictionary popup and no Anki card-source navigation.
    return;
  }

  @override
  void dispose() {
    _isSearchingNotifier.dispose();
    super.dispose();
  }

  final ValueNotifier<bool> _isSearchingNotifier = ValueNotifier<bool>(false);

  /// Handles leaving a source page. All sources should
  /// use this and wrap their [build] function with a [PopScope].
  Future<bool> onWillPop() async {
    final mediaSource = appModel.currentMediaSource;
    final item = widget.item;
    await onSourcePagePop();

    if (mediaSource != null) {
      await appModel.closeMedia(
        ref: ref,
        mediaSource: mediaSource,
        item: item,
      );
    }

    // 关书后把这本书的位置报回 Kitapsen（fire-and-forget，不阻塞退出 UI）。
    if (item != null) {
      unawaited(syncKitapsenBookProgress(appModel.database, item.mediaIdentifier));
    }
    return true;
  }

  bool _sourceExitClaimed = false;

  /// 退出单飞门：页内退出（PopScope 回调 / 退出按钮）与外部导航收页
  /// （[_closeForSourceReturn]，经 [ExternalMediaNavigation.closeActive]）共用。
  /// 返回 false = 已经有一条退出在跑，调用方不得再跑第二遍——否则
  /// [onSourcePagePop]（落盘、停表）、closeMedia、自动同步都会并发执行两次。
  /// 只上不下：退出一旦发起就无条件出栈（[exitAfterPersist]），本页随之销毁。
  /// 自带单飞门的子类（阅读器的 `_popInProgress`）覆写成同一把锁。
  @protected
  bool claimSourceExit() {
    if (_sourceExitClaimed) return false;
    _sourceExitClaimed = true;
    return true;
  }

  /// Action to perform within the source page upon closing the media.
  Future<void> onSourcePagePop() async {}

}
