import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:fushi_core/fushi_core.dart';
import 'audiobook_repository.dart';
import 'audiobook_local_files.dart';
import 'srt_book_model.dart';
import 'audiobook_storage.dart';

/// [SrtBookRepository.delete] 的结果：删掉几行 + 用户原件的逐条删除结果。
///
/// 行数与原件结果分开：前者是「这条记录还在不在」（BUG-439 的计数判据），后者是
/// 「磁盘上少了什么、哪些没删掉」。把后者揉进 int 就等于把删除失败丢掉。
class SrtBookDeleteResult {
  const SrtBookDeleteResult({
    required this.deleted,
    this.localFiles = const LocalFileDeleteReport(),
  });

  /// 真的从 `srt_books` 删掉的行数（0 = uid 没匹配到）。
  final int deleted;

  /// 「同时删除本地文件」的逐条结果；没勾选时恒为空。
  final LocalFileDeleteReport localFiles;
}

class SrtBookRepository {
  const SrtBookRepository(this._db);

  final FushiDatabase _db;

  Future<void> save(SrtBook book) async {
    await _db.upsertSrtBook(SrtBooksCompanion(
      // Carry the primary key when known so insertOnConflictUpdate (which
      // resolves on the `id` PK, not the `uid` unique index) performs a real
      // in-place update instead of hitting the UNIQUE(uid) constraint. Callers
      // that don't load `id` (fresh inserts) leave it absent — unchanged.
      id: book.id != null ? Value(book.id!) : const Value.absent(),
      uid: Value(book.uid),
      title: Value(book.title),
      author: Value(book.author),
      audioRoot: Value(book.audioRoot),
      audioPathsJson:
          Value(book.audioPaths != null ? jsonEncode(book.audioPaths) : null),
      srtPath: Value(book.srtPath),
      coverPath: Value(book.coverPath),
      importedAt: Value(book.importedAt),
      bookKey: Value(book.bookKey),
    ));
    // 删除传播：重新导入同 uid 的纯字幕书 → 清其 sync 删除墓碑，防「删了又加、墓碑
    // 还在」误判（范式仿 [AudiobookRepository.saveAudiobook] / 书 / 视频的插入清墓碑）。
    await _db.clearSyncDeletionTombstone(
        SyncTombstoneKind.srtbook.dbValue, book.uid);
  }

  /// 局部更新一条 SRT 书：**只写显式传入的字段**，其余列原样不动，行不存在时
  /// 返回 false（调用方据此走整行创建）。
  ///
  /// BUG-1678：[save] 是整行覆盖（companion 除 id 外每列都是 `Value(...)`）。
  /// 「只改其中几列」的调用方凭空造一个 [SrtBook] 再 save，本次没设的列会被静默
  /// 清空。手抄一遍「把旧值搬过来」只是纪律——新增列照样漏抄；这里让「没传 =
  /// 不改」由类型表达，漏抄这件事从结构上不成立。
  ///
  /// 参数一律「null = 不改」。真要把某列清空是另一种意图，需要专门的入口，
  /// 不能与「没提供」混成一个值。
  Future<bool> patchByUid(
    String uid, {
    String? title,
    String? srtPath,
    String? bookKey,
    int? importedAt,
    String? author,
    String? coverPath,
    List<String>? audioPaths,
    String? audioRoot,
  }) async {
    final int affected = await _db.patchSrtBook(
      uid,
      SrtBooksCompanion(
        title: title == null ? const Value.absent() : Value(title),
        srtPath: srtPath == null ? const Value.absent() : Value(srtPath),
        bookKey: bookKey == null ? const Value.absent() : Value(bookKey),
        importedAt:
            importedAt == null ? const Value.absent() : Value(importedAt),
        author: author == null ? const Value.absent() : Value(author),
        coverPath: coverPath == null ? const Value.absent() : Value(coverPath),
        audioPathsJson: audioPaths == null
            ? const Value.absent()
            : Value(jsonEncode(audioPaths)),
        // 换新音频一律文件列表模式：legacy 目录模式的 audioRoot 必须同时清掉，
        // 否则读取端在 audioPaths 断链时会回退去扫早已作废的旧目录。
        audioRoot: audioPaths != null
            ? const Value<String?>(null)
            : (audioRoot == null
                ? const Value.absent()
                : Value<String?>(audioRoot)),
      ),
    );
    if (affected == 0) return false;
    await _db.clearSyncDeletionTombstone(
        SyncTombstoneKind.srtbook.dbValue, uid);
    return true;
  }

  /// Deletes the SRT book + its on-disk persist dir. [SrtBookDeleteResult
  /// .deleted] is the number of srt_books rows actually removed (0 when [uid]
  /// matched nothing) so callers can count only real deletions (BUG-439).
  ///
  /// [propagateDeletion]（默认 false）：true 时记一条 `srtbook` sync 删除墓碑，供同步
  /// 发布到远端标记、其他设备逐条确认后也删（对应删除弹窗「从所有设备删除」）。false
  /// （含消费远端删除标记的路径）只删本机，绝不回写墓碑造成传播循环。app 层按
  /// `DeleteScope` 传入——用 bool 而非 DeleteScope 是为了不让本包反向依赖 app 层，
  /// 与同包 [AudiobookRepository.deleteAudiobook] 同一范式。
  ///
  /// 墓碑**只对 standalone 行写**（该行 `bookKey` 为空）：这类纯字幕书无 EpubBooks 行，
  /// 跨设备身份就是 uid。srt-backed 行（`bookKey` 非空）的身份是 bookKey，它的墓碑由
  /// `ReaderFushiSource.deleteBook` 写成 `book` 种类——两者互斥，同一资产绝不会产生
  /// 两条墓碑、也就不会在对端弹出两条重复的删除确认。
  /// [deleteLocalFiles]（默认 false）：true 时连显式登记的原始音频文件一起删
  /// （[deleteAudiobookLocalFiles]，对应删除弹窗「同时删除本地文件」）。删除结果在
  /// [SrtBookDeleteResult.localFiles] 里逐条回传，调用方负责记日志并告诉用户。
  Future<SrtBookDeleteResult> delete(
    String uid, {
    bool propagateDeletion = false,
    bool deleteLocalFiles = false,
  }) async {
    // 身份判据与原件位置都要在删行前读（删完就查不到了）。
    final SrtBookRow? before = await _db.getSrtBookByUid(uid);
    final bool standalone =
        propagateDeletion && (before?.bookKey.isEmpty ?? false);
    final int deleted = await _db.deleteSrtBookByUid(uid);
    // 墓碑写在**任何**磁盘操作之前：DB 行是唯一真相源，此刻这本书对用户已经消失；
    // 持久化目录删除与原件删除都是删完再打扫的尾活，Windows 上可能因句柄占用抛
    // errno 32/145，且原件删除的解析阶段本身也会抛（权限拒绝 / 网络盘掉线）。若把
    // 墓碑排在它们后面，一次尾活失败就会静默吞掉用户「从所有设备删除」的意图
    // （同 TODO-1359 那类「尾活失败翻转结果」的坑）。
    if (deleted > 0 && standalone) {
      try {
        await _db.writeSyncDeletionTombstone(SyncTombstoneKind.srtbook.dbValue,
            uid, DateTime.now().millisecondsSinceEpoch);
      } catch (_) {
        // best-effort：记账失败不影响字幕书已删。
      }
    }
    await AudiobookStorage.deletePersistDir(uid);
    if (!deleteLocalFiles || before == null) {
      return SrtBookDeleteResult(deleted: deleted);
    }
    return SrtBookDeleteResult(
      deleted: deleted,
      localFiles:
          await deleteAudiobookLocalFiles(_decodeAudioPaths(before.audioPathsJson)),
    );
  }

  /// 删行前快照原件列表用；坏 JSON 当作**没登记**。
  ///
  /// 这个返回值绝不能触发任何「换个办法猜文件在哪」的回落：一次 JSON 解码失败若
  /// 能把删除范围从「这几个登记过的文件」升级成别的什么，爆炸半径就由一个解析
  /// 意外决定。没登记 = 没有可删清单，见 `audiobook_local_files.dart`。
  static List<String>? _decodeAudioPaths(String? raw) {
    if (raw == null) return null;
    try {
      return (jsonDecode(raw) as List<dynamic>).cast<String>();
    } catch (_) {
      return null;
    }
  }

}
