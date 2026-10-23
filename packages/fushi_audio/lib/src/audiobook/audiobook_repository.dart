import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:fushi_core/fushi_core.dart';
import 'audiobook_health.dart';
import 'audiobook_model.dart';
import 'audiobook_storage.dart';

class AudiobookRepository {
  const AudiobookRepository(this._db);

  final FushiDatabase _db;

  // ── audiobook CRUD ──────────────────────────────────────────────

  Future<Audiobook?> findByBookKey(String bookKey) async {
    final row = await _db.getAudiobookByBookKey(bookKey);
    if (row == null) return null;
    return _rowToAudiobook(row);
  }

  Future<void> saveCues({
    required String bookKey,
    required List<AudioCue> cues,
  }) async {
    await _db.replaceCuesForBook(
        bookKey, cues.map(AudioCue.toCompanion).toList());
  }

  // ── 窄写入：一次只改一件事 ───────────────────────────────────────
  //
  // BUG-1678：这里**故意没有**「写一整行 Audiobook」的入口。`upsertAudiobook`
  // 是整行覆盖（companion 每列都是 `Value(...)`，没有 absent），凭空造一个模型
  // 再写就会把本次没碰的列静默清空——「只换字幕」因此清掉了 audioPaths/audioRoot，
  // 用户的音频消失。修法不是「记得先克隆一份基线」（那只是把地雷挪个位置），
  // 而是**不给整行入口**：调用方只能说「换音频」「换字幕」「回写 health」，
  // 每个动作只写自己那几列，想清空别的列都无从下手。

  /// 保证 [bookKey] 有一行；已存在则原样不动。附加音频/字幕前先调它。
  Future<void> ensureAudiobook(String bookKey) async {
    await _db.ensureAudiobookRow(bookKey);
    // 删除传播：重新导入同 bookKey 的有声书 → 清其 sync 删除墓碑，防「删了又加、
    // 墓碑还在」误判（范式仿书/视频的插入清墓碑）。
    await _db.clearSyncDeletionTombstone(
        SyncTombstoneKind.audiobook.dbValue, bookKey);
  }

  /// 换音频（唯一写音频两列的入口）。[audioPaths] 为落地后的绝对路径列表，
  /// 顺序即 `AudioCue.audioFileIndex` 的含义。写入后 `audioRoot` 恒为 null：
  /// 新音频一律文件列表模式，legacy 目录模式不得残留（否则读取端在 audioPaths
  /// 断链时会回退去扫早已作废的旧目录）。
  ///
  /// BUG-1679：音频集合真的变了就把播放进度归零。`audiobook_pos_<bookKey>` 记的
  /// 是**毫秒偏移**，只在它绑定的那一套音频上有意义；换一套后同一个数字指向的是
  /// 另一段声音：
  ///   * 超出新音频总时长 → [AudiobookPlayerController.load] 的恢复 seek 把播放器
  ///     钉在 EOF，按播放立刻结束 —— 用户看到的是「音频不响」；
  ///   * 落在时长内 → 起播点随机，followAudio 立刻把阅读器拽到那条 cue 所在的页
  ///     —— 用户看到的是「乱跳页」。
  /// 判据是数据本身（新旧集合不等），所以重复导入同一组音频不会误伤「听到哪儿了」。
  /// 旧行不存在时也归零：bookKey 是 sanitize 后的书名，删书重导会拿到同一个 key，
  /// 而 preferences 不随书删除，上一世的进度会原样复活。
  Future<void> replaceAudio({
    required String bookKey,
    required List<String> audioPaths,
  }) async {
    await ensureAudiobook(bookKey);
    final AudiobookRow? before = await _db.getAudiobookByBookKey(bookKey);
    final bool audioChanged = before == null ||
        before.audioRoot != null ||
        !AudiobookStorage.sameAudioPathList(
          _audioPathsOf(before),
          audioPaths,
        );

    await _db.patchAudiobook(
      bookKey,
      AudiobooksCompanion(
        audioPathsJson: Value(jsonEncode(audioPaths)),
        audioRoot: const Value<String?>(null),
      ),
    );
    if (audioChanged) {
      await updatePositionMs(bookKey: bookKey, positionMs: 0);
    }
    fushiDebugPrint('[hibiki-audiobook] replaceAudio bookKey=$bookKey '
        'files=${audioPaths.length} audioChanged=$audioChanged');
  }

  /// 换对齐字幕（唯一写 alignment 两列的入口）。
  Future<void> replaceAlignment({
    required String bookKey,
    required String format,
    required String path,
  }) async {
    await ensureAudiobook(bookKey);
    await _db.patchAudiobook(
      bookKey,
      AudiobooksCompanion(
        alignmentFormat: Value(format),
        alignmentPath: Value(path),
      ),
    );
  }

  /// 回写 health 四列（唯一写 health 列的入口）。与 [updateHealthOverlay]
  /// 的 pref overlay 是两回事：这里落的是 audiobooks 行上的持久值。
  Future<void> writeHealth({
    required String bookKey,
    required AudiobookHealth health,
  }) async {
    await ensureAudiobook(bookKey);
    final Audiobook carrier = Audiobook()..bookKey = bookKey;
    health.packInto(carrier);
    await _db.patchAudiobook(
      bookKey,
      AudiobooksCompanion(
        healthKindRaw: Value(carrier.healthKindRaw),
        matchRatePct: Value(carrier.matchRatePct),
        healthMeasuredAt: Value(carrier.healthMeasuredAt),
        healthReason: Value(carrier.healthReason),
      ),
    );
  }

  static List<String> _audioPathsOf(AudiobookRow row) {
    final String? raw = row.audioPathsJson;
    if (raw == null) return const <String>[];
    return (jsonDecode(raw) as List<dynamic>).cast<String>();
  }

  // ── playback position (preferences) ────────────────────────────

  static const String _kPositionMsKeyPrefix = 'audiobook_pos_';

  /// 位置最后写入时刻（epoch 毫秒）pref 前缀。与 `audiobook_pos_<bookKey>` 配套，
  /// 供互联（LAN）live 进度同步做「取较新时间戳」LWW（BUG-471）。云后端 SyncManager
  /// 路径不读此键（其时间戳借用阅读进度 `lastBookmarkModified`），互不影响。
  static const String _kPositionAtMsKeyPrefix = 'audiobook_pos_at_';

  /// 写位置（毫秒）并同时写入当前时刻为更新时间戳（BUG-471）。位置与时间戳是同一
  /// 进度的两个 pref，必须一起写，否则 LWW 无依据。
  ///
  /// 位置**没变就什么都不写**（BUG-2328）：时间戳的语义是「位置最后一次变动的时刻」，
  /// 不是「最后一次有人调本方法的时刻」。控制器在暂停 / 退后台 / 关书 / stop 都会强制
  /// flush 一次（durability 契约，见 [AudiobookPlayerController.flushPosition]），而 reader
  /// 关书时先落阅读位置再 flush 音频——若每次 flush 都重盖时间戳，音频进度就永远比
  /// 阅读进度「更新」，开书 LWW 仲裁会被写入顺序而不是用户行为决定（暂停在第 3 章、
  /// 静读到第 10 章关书，重开跳回第 3 章）。
  Future<void> updatePositionMs({
    required String bookKey,
    required int positionMs,
  }) async {
    final String posKey = '$_kPositionMsKeyPrefix$bookKey';
    final int current = await _db.getPrefTyped<int>(posKey, 0);
    if (current == positionMs) return;
    await _db.setPrefTyped(posKey, positionMs);
    await _db.setPrefTyped('$_kPositionAtMsKeyPrefix$bookKey',
        DateTime.now().millisecondsSinceEpoch);
  }

  static const String _kHealthOverlayKeyPrefix = 'audiobook_health_overlay_';

  Future<void> updateHealthOverlay({
    required String bookKey,
    required AudiobookHealth health,
  }) async {
    final m = <String, dynamic>{
      'kind': health.kind.name,
      'pct': health.ratePct,
      'reason': health.reason,
      'at': health.measuredAt.millisecondsSinceEpoch,
    };
    await _db.setPref('$_kHealthOverlayKeyPrefix$bookKey', jsonEncode(m));
  }

  // ── conversions ─────────────────────────────────────────────────

  static Audiobook _rowToAudiobook(AudiobookRow r) {
    final ab = Audiobook();
    ab.id = r.id;
    ab.bookKey = r.bookKey;
    ab.audioRoot = r.audioRoot;
    ab.audioPaths = r.audioPathsJson != null
        ? (jsonDecode(r.audioPathsJson!) as List).cast<String>()
        : null;
    ab.alignmentFormat = r.alignmentFormat;
    ab.alignmentPath = r.alignmentPath;
    ab.healthKindRaw = r.healthKindRaw;
    ab.matchRatePct = r.matchRatePct;
    ab.healthMeasuredAt = r.healthMeasuredAt;
    ab.healthReason = r.healthReason;
    ab.followAudio = r.followAudio;
    return ab;
  }

  // 这里曾有一个 `_audiobookToCompanion(Audiobook)`：把整个模型摊成每列都是
  // `Value(...)` 的 companion 去做整行覆盖。它随 `saveAudiobook` 一起删除——
  // 只要这个函数还在，就总有人凭空造模型再写全行，把没碰的列清空（BUG-1678）。
}
