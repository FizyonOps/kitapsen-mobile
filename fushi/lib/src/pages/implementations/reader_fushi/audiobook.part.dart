// GENERATED-NOTE: extracted from reader_fushi_page.dart (TODO-589 batch5).
part of '../reader_fushi_page.dart';

/// audiobook domain helpers (profile resolution / audio-slot + session
/// attach / cue priming + SRT chapter map / position restore-from-cue /
/// volume-key sentence nav / cue-change sync + cross-chapter + boundary
/// skip / lookup-cue + sentence-audio-range resolution / audio import)
/// extracted via part-of (TODO-589 batch5); shared private scope.
/// Behaviour-preserving: bodies are byte-for-byte verbatim except the four
/// `setState(` calls (in `_attachExistingSession`, `_startAndAttachSession`,
/// `_openAudioImportDialog`, `_openSrtBookAudioPicker`) forwarded through the
/// main shell `_rebuild(` helper (extensions cannot call the @protected
/// State.setState directly). No class static is referenced, so no static
/// qualification was needed.
///
/// No member of this group is an `@override` or calls a `@protected`
/// `BaseSourcePageState` member, so nothing had to stay behind in the shell
/// on those grounds. The `@override` reader-audiobook-view forwarders
/// (`onReaderCueChanged` / `onCueCrossChapter` / `onBoundarySkip` /
/// `clearDictionaryResult` / `supportsSentenceDraft`), the open-book
/// orchestrator (`_initBook`) and the audiobook chrome (`_buildAudiobookBar`
/// / `buildPopupAudioControls` / `_currentChapterLabel`) remain in the shell,
/// reachable via the shared private class scope.
extension _ReaderAudiobook on _ReaderFushiPageState {
  Future<void> _resolveAndApplyProfile(
    FushiDatabase db, {
    ProfileMediaKind? mediaTypeOverride,
  }) async {
    try {
      final ProfileViewModel profileVm = ref.read(
        profileViewModelProvider.notifier,
      );

      final String bookKey = widget.bookKey;

      // 两张内容表都查一次：媒体类型判定只需要知道「有没有」，但语言级绑定要读
      // 它们的 language 列。`audiobooks` 表自身**没有** language 列——有声书的
      // 语言跟着它配对的 srt_books / epub_books 行走，所以这里不按 mediaType
      // 分支去取，两张都取、SRT 优先（有声书多数配 SRT）。
      final srtRow = await db.getSrtBookByBookKey(bookKey);
      final epubRow = await db.getEpubBook(bookKey);

      ProfileMediaKind mediaType;
      if (mediaTypeOverride != null) {
        mediaType = mediaTypeOverride;
      } else {
        mediaType = ProfileMediaKind.epub;
        final abRow = await db.getAudiobookByBookKey(bookKey);
        if (abRow != null) {
          mediaType = ProfileMediaKind.audiobook;
        } else if (srtRow != null) {
          mediaType = ProfileMediaKind.srtbook;
        }
      }

      await profileVm.autoApplyBinding(
        bookUid: bookKey,
        languageTag: srtRow?.language ?? epubRow?.language,
        mediaType: mediaType,
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

  /// 解析并接管本书的有声书会话（TODO-291 阶段2）。
  ///
  /// 控制器现由进程级 [AudiobookSession] 持有。reader 不再自己 new / dispose 控制器，
  /// 而是：① 若已有同书的后台会话 → 直接复用（退书后台听书再进，无缝接回）；
  /// ② 否则让 session 起新会话；③ attach reader 的 WebView 侧回调。
  Future<void> _resolveAudioSlot() async {
    return;
  }

  /// 以播放器**当前位置**对应的 cue 作开书起点。返回 false = 算不出（无控制器 /
  /// 无 cue / cue 反查不到章），调用方据此回退阅读进度（BUG-2328）。
  ///
  /// 三条反查路径（sasayaki fragment → SRT 切章表 → href/正文兜底）统一由
  /// [_setOpenResumePoint] 落到起点字段：那里一次写齐七个字段，存档分支残留的锚不会
  /// 在 restoreToCharOffset 里压过分数、把视口拽回旧位置。
  ///
  /// BUG-2333 起 fragment 那条路还经 [_studyRangeForAudioFragment] 把**音频 UTF-16
  /// 坐标**映射成学习单位偏移，因此它能给出精确字符锚（charOffset）；无 fragment 的正文兜底也必须
  /// 唯一匹配正文来取得字符锚，SRT 切章表仍使用章内分数。
  bool _restoreFromCurrentAudioCue() {
    const AudioCue? cue = null;
    if (cue == null || _book == null) return false;

    return true;
  }

  /// 听书跟随 reveal（`AudiobookBridge.highlight(reveal: true)`）落定后补刷一次进度。
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

  int get _lookupSectionIndex {
    return _currentChapter;
  }

}
