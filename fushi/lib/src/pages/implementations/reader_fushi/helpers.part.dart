// GENERATED-NOTE: extracted from reader_fushi_page.dart (TODO-589 batch5).
part of '../reader_fushi_page.dart';

/// Reader helpers (profile resolution / volume-key paging / reveal settle
/// refresh) extracted via part-of (TODO-589 batch5); shared private scope.
extension _ReaderHelpers on _ReaderFushiPageState {
  Future<void> _resolveAndApplyProfile(
    FushiDatabase db, {
    ProfileMediaKind? mediaTypeOverride,
  }) async {
    try {
      final ProfileViewModel profileVm = ref.read(
        profileViewModelProvider.notifier,
      );

      final String bookKey = widget.bookKey;
      final epubRow = await db.getEpubBook(bookKey);

      await profileVm.autoApplyBinding(
        bookUid: bookKey,
        languageTag: epubRow?.language,
        mediaType: mediaTypeOverride ?? ProfileMediaKind.epub,
      );
    } catch (e, st) {
      debugPrint(
        '[ReaderFushi] profile resolution failed (non-fatal): $e\n$st',
      );
    }
  }

  /// TODO-131: profile 解析+应用 → 阅读器设置刷新。两步有依赖（profile 切换可能
  /// 改哪份 profile-scoped 设置生效），故内部串行；整条与书本定位/解析链并行。
  Future<void> _resolveProfileAndSettings(FushiDatabase db) async {
    await _resolveAndApplyProfile(db);
    if (!mounted) return;
    if (ReaderFushiSource.readerSettings == null) {
      final ReaderSettings rs = ReaderSettings(db);
      await rs.refreshFromDb();
      ReaderFushiSource.readerSettings = rs;
    }
  }

  void _setupVolumeKeyHandlers() {
    final ReaderFushiSource src = ReaderFushiSource.instance;
    VolumeKeyChannel.instance.setHandlers(
      onVolumeUp: () => _onVolumeKey(isUp: true),
      onVolumeDown: () => _onVolumeKey(isUp: false),
    );
    VolumeKeyChannel.instance.setInterceptEnabled(true);
    debugPrint(
      '[ReaderFushi] volume key handlers installed '
      '(inverted=${src.volumePageTurningInverted})',
    );
  }

  void _onVolumeKey({required bool isUp}) {
    final ReaderFushiSource src = ReaderFushiSource.instance;
    // 音量键翻页/句子导航共用固定节流（原可调「翻页速度」已移除，TODO-737）。
    final int speedMs = ReaderFushiSource.defaultScrollingSpeed;
    final bool inverted = src.volumePageTurningInverted;
    final bool goForward = inverted ? isUp : !isUp;

    // TODO-737: 翻页分支的节流归一到 _paginate 入口时间戳闸门（固定 throttleMs =
    // defaultScrollingSpeed），与滚轮共用 _lastPaginateTime，删音量键自有翻页节流。
    _paginate(
      goForward
          ? ReaderNavigationDirection.forward
          : ReaderNavigationDirection.backward,
      throttleMs: speedMs,
    );
  }

  /// 重锚 reveal 落定后补刷一次进度。
  ///
  /// reveal 前打点 `_reanchorClearedAt` 武装了 B-3 settle 窗（TODO-825 治闪屏）：分页 /
  /// VN 的 reveal 是瞬时翻页（JS 调用内落定），连续模式是 smooth 动画（多帧）——两者
  /// 落定那几帧的 scroll 回传都落在窗内被 `_handleReaderScroll` 直接 return，新页不会
  /// 经 scroll 通道 arrive，只能等 10s 轮询；`ReadUnitLedger` 是翻走即计，晚 arrive 就
  /// 晚结算上一页（且期间若关书 / 跳句，新页整页漏计）。这里按同一个窗常量
  /// [kReaderReanchorSettleMs] 排在窗关之后补刷一次：瞬时 reveal 此刻早已落定；smooth
  /// 动画若还没停，窗关后的尾沿 scroll 回传本就会照常再刷（同单元重复采样是 no-op）。
  /// 单 Timer 复位：连续 cue 推进只保留最后一次。BUG-2227 起 `_handleReaderScroll`
  /// 在 B-3 窗内丢弃 scroll 回传时也排这一个 Timer（同一个窗、同一个补刷语义）。
  void _scheduleReanchorSettleProgressRefresh() {
    _revealProgressRefreshTimer?.cancel();
    _revealProgressRefreshTimer = Timer(
      const Duration(milliseconds: kReaderReanchorSettleMs),
      () {
        _revealProgressRefreshTimer = null;
        if (!mounted) return;
        unawaited(_refreshProgress());
      },
    );
  }

}
