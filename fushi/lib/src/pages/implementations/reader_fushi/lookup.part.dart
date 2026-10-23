// GENERATED-NOTE: extracted from reader_fushi_page.dart (TODO-589 batch3).
part of '../reader_fushi_page.dart';

/// lookup (查词 / text-selection → dictionary) domain helpers extracted via
/// part-of (TODO-589 batch3); shared private scope. Behaviour-preserving:
/// bodies are byte-for-byte verbatim except the two `setState(` calls in
/// `_checkFavoriteStatus` forwarded through the main shell `_rebuild(` helper
/// (extensions cannot call the @protected State.setState directly); no class
/// static is referenced, so no static qualification was needed.
///
/// Two members stay in the main shell, lifted out of this method group:
/// the `@override onAllPopupsDismissed` (Dart extensions cannot satisfy a
/// superclass virtual contract) and `_runLookupAndHighlight` (it calls the
/// `@protected` `BaseSourcePageState.prunePopupStack`, which the analyzer
/// rejects from an extension body — `invalid_use_of_protected_member`). Both
/// remain reachable from here via the shared private class scope.
extension _ReaderLookup on _ReaderFushiPageState {
  // ── Text Selection → Dictionary ───────────────────────────────────

  /// BUG-712 ①：把点词门控（chrome 可见性 / highlightOnTap）只读镜像同步进阅读器
  /// JS 的 `window.__fushiTapGate`。Dart 是唯一写者：初始值随 setup 脚本注入，
  /// 之后 chrome 翻转（[_toggleChrome]）与设置热更新
  /// （onSettingsChangedLive）各刷一次。JS 侧据此在 tap 命中时直接 selectText
  /// （砍掉 onTap→Dart→eval 来回）；镜像缺失时 JS 回落旧 onTap 链，行为安全。
  /// fire-and-forget：半销毁 WebView 的 eval 异常就地吞掉（同 [_selectTextAt] 成例）。
  void _syncTapGateJs() {
    final InAppWebViewController? controller = _controller;
    if (controller == null) return;
    final bool lookup = ReaderFushiSource.instance.highlightOnTap;
    try {
      controller
          .evaluateJavascript(
        source: 'window.__fushiTapGate = '
            '{ chrome: $_tapGateChrome, lookup: $lookup, maxLen: 400 };',
      )
          .catchError((Object e, StackTrace s) {
        ErrorLogService.instance.log('ReaderFushi.syncTapGate', e, s);
        return null;
      });
    } catch (e, stack) {
      ErrorLogService.instance.log('ReaderFushi.syncTapGate', e, stack);
    }
  }

  Future<void> _handleTextSelected(ReaderSelectionData data) async {
    // Kitapsen: no lookup; a tap never selects a word for one.
    return;
  }

}
