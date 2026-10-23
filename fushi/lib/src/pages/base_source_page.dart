import 'dart:async';

import 'package:flutter/material.dart';
import 'package:fushi/media.dart';
import 'package:fushi/pages.dart';
import 'package:fushi/src/media/reader_exit_flush.dart';
import 'package:fushi/src/sync/sync_auto_trigger.dart';

/// 一次查词是怎么发起的。决定这次查词要不要跑「每查一次就付费一次」的旁路工作
/// （查词按句意自动挑词条），以及这一层弹窗有没有可信的原句。
enum LookupOrigin {
  /// 明确的一次点击 / 按键 / 菜单「查词」：查的就是读者此刻那句话里的词。
  explicit,

  /// 指针扫过（Shift 悬停 / 悬停查词）：扫一行就连查十几个词，不自动挑词条。
  hover,

  /// 在弹窗释义里点词叠出的子层：查的词来自释义，不在读者的原句里，
  /// 这一层没有可信的句子（不显示 ✨、不自动挑词条）。
  nested,
}

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
    final messenger = ScaffoldMessenger.maybeOf(context);
    await onSourcePagePop();

    if (mediaSource != null) {
      await appModel.closeMedia(
        ref: ref,
        mediaSource: mediaSource,
        item: item,
      );
    }

    if ((item != null) && (messenger != null)) {
      triggerAutoSyncAfterClose(
        db: appModel.database,
        mediaIdentifier: item.mediaIdentifier,
        messenger: messenger,
        onReport: appModel.presentSyncPrompts,
      );
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

  Future<int> searchDictionaryResult({
    required String searchTerm,
    required Rect selectionRect,
    int? overrideMaximumTerms,
    bool deferDisplay = false,
    LookupOrigin origin = LookupOrigin.explicit,
  }) async {
    return 0;
  }

  /// Dismiss only the top-most visible popup (one layer), leaving any parent
  /// popup in place — used by the cursor's B/Esc "back one layer".
  @protected
  void dismissTopPopup() {
    return;
  }

  @protected
  void prunePopupStack(int keepCount) {
    return;
  }

}
