import 'dart:async';
import 'dart:io';
import 'dart:math' show Random;

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/common.dart' show CommonDatabase;
import 'package:sqlite3/sqlite3.dart' as sqlite3;

import '../utils/fushi_debug_print.dart';
import 'activity_event_types.dart';
import 'book_format.dart';
import 'collection_order.dart';
import 'epub_book_meta.dart';
import 'media_kind.dart';
import 'pref_codec.dart';
import 'tables.dart';
import 'tag_host_kind.dart';

part 'database.g.dart';
part 'database_infra.part.dart';
part 'database_prefs_media.part.dart';
part 'database_library.part.dart';
part 'database_statistics.part.dart';
part 'database_content_misc.part.dart';
part 'database_tags_sync.part.dart';

/// Thrown when the on-disk database was created by a NEWER build of Fushi than
/// the one currently running (`db user_version > code schemaVersion`).
///
/// 降级保护：当用户用旧版应用打开由新版创建的库时，绝不 DROP/迁移/重建，而是抛出此
/// 异常让打开失败、事务回滚、库文件原样保留，并由 UI 提示用户更新应用。这是修复
/// 「旧 app 启动把用户数据库降级破坏」整类事故的根因拦截。
class FushiDatabaseDowngradeException implements Exception {
  /// The schema version stored in the on-disk DB file (created by a newer app).
  final int dbVersion;

  /// The schema version this (older) build of the code knows about.
  final int appSchemaVersion;

  const FushiDatabaseDowngradeException({
    required this.dbVersion,
    required this.appSchemaVersion,
  });

  @override
  String toString() =>
      'FushiDatabaseDowngradeException: database was created by a newer '
      'version of Fushi (schema v$dbVersion); this app only understands '
      'schema v$appSchemaVersion. Opening was refused to protect your data.';
}

/// Thrown when the database could NOT be opened even after the full WAL/IOERR
/// recovery ladder (checkpoint → DELETE journal → physical sidecar rebuild)
/// ran — i.e. the main `fushi.db` file itself is corrupt, not just a stale
/// `-wal` / `-shm` sidecar. Mirrors [FushiDatabaseDowngradeException]: it is a
/// dedicated, app-recognisable terminal type so the app layer can show an
/// actionable "import a backup / clear data" notice INSTEAD of looping the
/// generic init-error Retry button forever (TODO-905 root cause: a stale
/// sidecar made `PRAGMA journal_mode=WAL` raise SqliteException(1546), and Retry
/// re-ran open against the same untouched bad sidecar = infinite "can't open").
/// BUG-1899：终态失败的两种**根本不同**的成因。此前它们共用一句「likely corrupt,
/// must be restored from a backup or cleared」，把「路径压根打不开」说成了「数据坏了」，
/// 并把用户引向清空数据——而那种情况下磁盘上一个字节都没损坏。
enum FushiDatabaseFailureKind {
  /// 文件在，但内容不是合法的 SQLite（或恢复阶梯已穷尽）。真的坏了：只能恢复备份或清空。
  corrupt,

  /// 根本打不开：父目录不存在、无权限、只读介质、盘断链。
  /// **磁盘上什么都没坏**，让用户去清空数据是有害的误导。
  cannotOpen,
}

class FushiDatabaseUnrecoverableException implements Exception {
  /// Absolute path of the database file that could not be recovered.
  final String dbPath;

  /// The underlying error from the final open attempt (kept for diagnostics).
  final Object cause;

  /// 区分「文件坏了」与「路径打不开」，见 [FushiDatabaseFailureKind]。
  final FushiDatabaseFailureKind kind;

  const FushiDatabaseUnrecoverableException({
    required this.dbPath,
    required this.cause,
    this.kind = FushiDatabaseFailureKind.corrupt,
  });

  @override
  String toString() => switch (kind) {
        FushiDatabaseFailureKind.corrupt =>
          'FushiDatabaseUnrecoverableException: the database file at "$dbPath" '
              'could not be opened even after WAL/sidecar recovery. It is '
              'likely corrupt and must be restored from a backup or cleared. '
              'Cause: $cause',
        FushiDatabaseFailureKind.cannotOpen =>
          'FushiDatabaseUnrecoverableException: the database file at "$dbPath" '
              'could not be opened and does not exist on disk — the folder is '
              'missing, unwritable, or on a disconnected/read-only volume. '
              'Nothing is corrupt; check the data location. Cause: $cause',
      };
}

/// SQLite primary result codes that a stale/locked/corrupt `-wal`/`-shm`
/// sidecar surfaces as when opening + switching to WAL after a hard kill:
///   - 10 = `SQLITE_IOERR` family (1546 = `SQLITE_IOERR_SHMOPEN`, SHMMAP, …) —
///     the exact code reported in TODO-905 (Windows mmap-lock residue);
///   - 14 = `SQLITE_CANTOPEN` family (526 = `SQLITE_CANTOPEN_*`) — the same
///     hard-kill residue surfaces here on other OS/state combinations
///     (e.g. a sidecar SQLite can't open/recreate).
/// Both mean "the MAIN db may be fine but a sidecar is the problem". Recovery
/// triggers on either, then PROVES the main db is healthy (read-only open) before
/// touching anything — so a genuinely missing/corrupt/permission-denied main db
/// is NOT mistaken for a sidecar problem (it falls through to unrecoverable).
const int _kSqliteIoErr = 10; // SQLITE_IOERR
const int _kSqliteCantOpen = 14; // SQLITE_CANTOPEN
const int _kSqliteNotADb = 26; // SQLITE_NOTADB

bool _isSidecarOpenError(Object e) {
  if (e is! sqlite3.SqliteException) return false;
  final int primary = e.extendedResultCode & 0xFF;
  // IOERR(10) / CANTOPEN(14): the classic hard-kill sidecar residue. NOTADB(26):
  // a non-SQLite-header file — could be a corrupt MAIN db, so it also enters the
  // ladder, where _mainDbIsHealthy() proves whether the main db is fine (recover)
  // or itself bad (terminal). All three are gated by the health probe below, so
  // a corrupt main db is never mistaken for a stale sidecar.
  return primary == _kSqliteIoErr ||
      primary == _kSqliteCantOpen ||
      primary == _kSqliteNotADb;
}

/// The 16-byte magic header every SQLite database file starts with
/// ("SQLite format 3\u0000"). See https://www.sqlite.org/fileformat.html .
final List<int> _kSqliteMagic = 'SQLite format 3\u0000'.codeUnits; // 16 bytes

/// Whether the MAIN `fushi.db` file is itself a structurally valid SQLite
/// database, judged ONLY by its file header — deliberately WITHOUT opening a
/// connection (a read-only open of a WAL db still engages the `-wal`/`-shm`
/// sidecar, which is the very thing that is broken here, so it would falsely
/// report a healthy main db as bad). Gates sidecar recovery: we only ever delete
/// `-wal`/`-shm` when the main db's header is intact, so a corrupt/missing main
/// db can never be mistaken for a stale sidecar (it stays unrecoverable instead
/// of triggering a destructive delete).
bool _mainDbHeaderIsValid(String path) {
  final File file = File(path);
  if (!file.existsSync()) return false;
  try {
    final RandomAccessFile raf = file.openSync();
    try {
      if (raf.lengthSync() < _kSqliteMagic.length) return false;
      final List<int> head = raf.readSync(_kSqliteMagic.length);
      for (int i = 0; i < _kSqliteMagic.length; i++) {
        if (head[i] != _kSqliteMagic[i]) return false;
      }
      return true;
    } finally {
      raf.closeSync();
    }
  } catch (_) {
    return false;
  }
}

/// Opens [dbFile] robustly. Layer 0 is the normal fast path; only a
/// sidecar-class open error (stale/locked/corrupt `-wal`/`-shm` after a hard
/// kill) drops into the recovery ladder. [allowSidecarDelete] gates the physical
/// sidecar rebuild (Layer 2): only the MAIN process may delete `-wal`/`-shm`; the
/// separate `:popup` process passes false and backs off (throws) so two
/// processes never race to delete the same sidecar (TODO-905 D3).
///
/// Throws [FushiDatabaseUnrecoverableException] when the main DB file itself is
/// corrupt (recovery exhausted) so the app layer can stop the Retry loop.
Future<QueryExecutor> _openWithRecovery(
  File dbFile, {
  required bool allowSidecarDelete,
}) async {
  final String path = dbFile.path;
  void applyPragmas(CommonDatabase db) {
    // BUG-772：busy_timeout 前置，让下面的 journal_mode=WAL 切换本身也受 5s busy 超时
    // 约束——视频硬崩留脏 -wal/-shm 时，probe-open 的 WAL 切换可能因锁争用长阻塞 UI
    // isolate（与主 raster 根因并存的独立同步冻结隐患）。
    db.execute('PRAGMA busy_timeout = 5000');
    db.execute('PRAGMA journal_mode=WAL');
    db.execute('PRAGMA foreign_keys = ON');
  }

  // ── Layer 0 — normal path. Probe-open with a raw sqlite3 connection applying
  //    the exact same PRAGMAs drift would. This surfaces the open error eagerly
  //    (createInBackground would otherwise defer it to the first query). On
  //    success we close the probe and hand drift a fresh background connection.
  try {
    final sqlite3.Database probe = sqlite3.sqlite3.open(path);
    try {
      applyPragmas(probe);
    } finally {
      probe.close();
    }
    return NativeDatabase.createInBackground(dbFile, setup: applyPragmas);
  } catch (e, stack) {
    // Not a sidecar-class error → nothing recovery can safely do, surface it.
    if (!_isSidecarOpenError(e)) rethrow;
    // The error class is ambiguous (a corrupt MAIN db can also raise
    // CANTOPEN/NOTADB): only recover if the main db's header is a valid SQLite
    // file. Otherwise it is a corrupt/missing main db → terminal, do NOT delete
    // any sidecar.
    if (!_mainDbHeaderIsValid(path)) {
      // BUG-1899：这里必须分清两件事。sqlite 的 open 在父目录存在时会**自己创建**
      // 缺失的 db 文件，所以走到这一步还「文件不存在」，只可能是连创建都失败了 ——
      // 目录不存在 / 无权限 / 只读介质 / 盘断链。那不是「损坏」，把它说成损坏会把
      // 用户引去清空数据（用户报告：自定义数据安装位置后启动即「Database damaged」，
      // 实际只是 `<dataRoot>/support` 这个空目录没被创建）。
      // 文件确实在但头不是 SQLite magic → 才是真的坏了。
      throw FushiDatabaseUnrecoverableException(
        dbPath: path,
        cause: e,
        kind: File(path).existsSync()
            ? FushiDatabaseFailureKind.corrupt
            : FushiDatabaseFailureKind.cannotOpen,
      );
    }
    fushiDebugPrint('[fushi-db] sidecar open error on "$path" '
        '(main db healthy → recovering): $e\n$stack');
  }

  // ── Layer 1 — checkpoint the WAL back into the main DB, then leave WAL mode.
  //    A raw connection that does NOT pre-set WAL can usually still open even
  //    when a stale -shm is poisoned; wal_checkpoint(TRUNCATE) flushes every
  //    already-committed WAL frame into fushi.db (NO DATA LOSS), then
  //    journal_mode=DELETE drops the -wal/-shm cleanly. MUST run before any
  //    physical sidecar delete (Layer 2) so committed-but-uncheckpointed
  //    transactions are preserved.
  try {
    final sqlite3.Database recover = sqlite3.sqlite3.open(path);
    try {
      recover.execute('PRAGMA wal_checkpoint(TRUNCATE)');
      recover.execute('PRAGMA journal_mode=DELETE');
    } finally {
      recover.close();
    }
    fushiDebugPrint(
        '[fushi-db] Layer 1 recovery OK (checkpoint+DELETE) for "$path"');
    return NativeDatabase.createInBackground(dbFile, setup: applyPragmas);
  } catch (e, stack) {
    if (!_isSidecarOpenError(e)) rethrow;
    fushiDebugPrint('[fushi-db] Layer 1 still failing on "$path": $e\n$stack');
  }

  // ── Layer 2 — physical sidecar rebuild. Layer 1 could not even open a raw
  //    connection (sidecar too poisoned).
  await _rebuildSidecar(dbFile);
  try {
    return NativeDatabase.createInBackground(dbFile, setup: applyPragmas);
  } catch (e, stack) {
    if (!_isSidecarOpenError(e)) rethrow;
    // ── Layer 3 — sidecar gone yet still failing ⇒ the main fushi.db is
    //    corrupt after all. Terminal: hand the app a recognisable type so it can
    //    stop the Retry loop and offer restore/clear instead of looping.
    fushiDebugPrint(
        '[fushi-db] Layer 2 rebuild failed, DB unrecoverable: $e\n$stack');
    throw FushiDatabaseUnrecoverableException(dbPath: path, cause: e);
  }
}

/// Layer 2 helper: snapshot then physically remove the stale `-wal` / `-shm`
/// sidecars so SQLite rebuilds them from a clean `fushi.db`.
///
/// 🔴 Data-safety invariant (TODO-905 red line): this NEVER touches the main
/// `.db` file — it only deletes the `$path-wal` / `$path-shm` suffixes. A
/// `.corrupt-bak` snapshot of the main DB + each sidecar is taken first so a
/// user can hand-recover the last un-checkpointed writes if needed.
///
/// Exact names produced (the whitelist in [isDatabaseSnapshotFileName] must
/// match these verbatim): `fushi.db.corrupt-bak-<stamp>.db`,
/// `fushi.db.corrupt-bak-<stamp>.db-wal`, `fushi.db.corrupt-bak-<stamp>.db-shm`
/// — the copied file's own extension is appended AFTER the stamp, so a snapshot
/// never ends in a bare `-wal` / `-shm`.
Future<void> _rebuildSidecar(File dbFile) async {
  final String path = dbFile.path;
  final File wal = File('$path-wal');
  final File shm = File('$path-shm');

  // Snapshot the main DB + sidecars before deleting anything (D1: 数据安全兜底).
  final String stamp = DateTime.now().millisecondsSinceEpoch.toString();
  Future<void> snapshot(File src, String suffix) async {
    if (await src.exists()) {
      try {
        await src.copy('$path.corrupt-bak-$stamp$suffix');
      } catch (e) {
        fushiDebugPrint(
            '[fushi-db] snapshot of "${src.path}" failed (non-fatal): $e');
      }
    }
  }

  await snapshot(dbFile, '.db');
  await snapshot(wal, '.db-wal');
  await snapshot(shm, '.db-shm');

  // Delete ONLY the sidecar PATHS; the main .db is left byte-for-byte intact.
  // Handles either a normal sidecar file OR a stray directory occupying the
  // path (a hard kill can leave the path unusable as a file — the cause of the
  // CANTOPEN); both are removed so SQLite can recreate a clean sidecar.
  Future<void> deleteSidecar(String sidecarPath) async {
    final FileSystemEntityType type = await FileSystemEntity.type(sidecarPath);
    if (type == FileSystemEntityType.file) {
      await File(sidecarPath).delete();
    } else if (type == FileSystemEntityType.directory) {
      await Directory(sidecarPath).delete(recursive: true);
    }
  }

  await deleteSidecar('$path-wal');
  await deleteSidecar('$path-shm');
  fushiDebugPrint('[fushi-db] Layer 2: deleted stale -wal/-shm for "$path" '
      '(main .db untouched, .corrupt-bak-$stamp snapshot kept)');
}

/// 主库在 support 根下的文件名。唯一真相源：除了 [_openDb] 自身，app 层判定「这台机器
/// 上是否已经有一个跑过的安装」时也要认这个文件（见 `AppPaths` 的默认 documents
/// 布局判据），故抽成导出常量而不是各处重复字面量。
const String fushiDatabaseFileName = 'fushi.db';

/// 主库**快照残留**的识别口径（BUG-1870；存储页「数据库备份快照」条目与
/// [deleteDatabaseSnapshotFiles] 共用，展示什么就删什么）。
///
/// 只认代码**真的产过**的整文件副本：[_rebuildSidecar] 的崩溃恢复快照
/// `<主库名>.corrupt-bak-<毫秒戳>.db` / `.db-wal` / `.db-shm`（副本名以 `.db*` 结尾，
/// 不是 `-wal`/`-shm`）。白名单而不是黑名单：活库本体与 `-wal` / `-shm` /
/// `-journal` 侧车形态上就不在白名单里，结构上永远不可能命中。
bool isDatabaseSnapshotFileName(final String name) =>
    name.startsWith(fushiDatabaseFileName) &&
    _kCorruptBakSuffix
        .hasMatch(name.substring(fushiDatabaseFileName.length));

/// 崩溃恢复快照后缀（[_rebuildSidecar]：`.corrupt-bak-<stamp>` + 被复制文件的
/// `.db` / `.db-wal` / `.db-shm`）。
final RegExp _kCorruptBakSuffix =
    RegExp(r'^\.corrupt-bak-\d+\.db(-wal|-shm)?$');

/// [supportRoot] **直接**子层里可删的主库快照残留（同步、不递归、不追 symlink；
/// 存储页在扫描 isolate 里调用）。
List<File> listDatabaseSnapshotFiles(final Directory supportRoot) {
  if (!supportRoot.existsSync()) return const <File>[];
  return <File>[
    for (final FileSystemEntity e in supportRoot.listSync(followLinks: false))
      if (e is File && isDatabaseSnapshotFileName(p.basename(e.path))) e,
  ];
}

/// [deleteDatabaseSnapshotFiles] 的结果。删除是**逐文件容错**的：Windows 上
/// Defender / 索引器临时占住某个副本是常态，一个失败就整批中止会让用户点了删除
/// 却几十个文件一个没少。
class DatabaseSnapshotDeletionResult {
  const DatabaseSnapshotDeletionResult({
    required this.deleted,
    required this.failures,
  });

  /// 已删除的绝对路径。
  final List<String> deleted;

  /// 删不掉的：路径 → 失败原因（原样带给 UI 提示，不吞）。
  final Map<String, String> failures;

  bool get hasFailures => failures.isNotEmpty;
}

/// 删除 [supportRoot] 下全部可删的主库快照残留。识别口径与
/// [listDatabaseSnapshotFiles] 同源（含所有权门控），故活库/侧车/待恢复副本结构
/// 上不可能被删到。单个文件删不掉不中止整批：收集失败原因后继续删剩下的。
Future<DatabaseSnapshotDeletionResult> deleteDatabaseSnapshotFiles(
    final Directory supportRoot) async {
  final List<String> deleted = <String>[];
  final Map<String, String> failures = <String, String>{};
  for (final File f in listDatabaseSnapshotFiles(supportRoot)) {
    try {
      await f.delete();
      deleted.add(f.path);
    } on FileSystemException catch (e) {
      failures[f.path] = e.osError?.message ?? e.message;
    }
  }
  return DatabaseSnapshotDeletionResult(deleted: deleted, failures: failures);
}

LazyDatabase _openDb(String dbDirectory, {bool isMainProcess = true}) {
  return LazyDatabase(() async {
    final file = File(p.join(dbDirectory, fushiDatabaseFileName));
    return _openWithRecovery(file, allowSidecarDelete: isMainProcess);
  });
}

/// Opens an arbitrary `.db` FILE (not a directory). Used by the backup MERGE
/// import (TODO-888) to migrate an extracted backup DB up to the current schema
/// before ATTACHing it to the live DB. Same robust open as [_openDb].
LazyDatabase _openDbFile(String dbFilePath, {bool isMainProcess = true}) {
  return LazyDatabase(() async {
    final file = File(dbFilePath);
    return _openWithRecovery(file, allowSidecarDelete: isMainProcess);
  });
}

@DriftDatabase(tables: [
  MediaOpenHistory,
  ReaderPositions,
  Bookmarks,
  ReadingStatistics,
  ReadingHourlyLogs,
  Preferences,
  EpubBooks,
  BookTags,
  TagAssignments,
  Profiles,
  ProfileSettings,
  MediaTypeProfiles,
  BookProfiles,
  LanguageProfiles,
  Series,
  ShelfEntries,
  MediaCollections,
  MediaCollectionItems,
  BookCustomCss,
  RevealedImages,
  ActivityEvents,
  StudySegmentTombstones,
  StudySegments,
])
class FushiDatabase extends _$FushiDatabase
    with
        _FushiDbInfra,
        _FushiDbTagsSync,
        _FushiDbLibrary,
        _FushiDbPrefsMedia,
        _FushiDbContentMisc,
        _FushiDbStatistics {
  /// [isMainProcess] gates the TODO-905 sidecar rebuild: the main app passes
  /// the default `true` (it may physically delete a poisoned `-wal`/`-shm`),
  /// while the separate `:popup` process passes `false` so it backs off on an
  /// IOERR instead of racing the main process to delete the same sidecar.
  FushiDatabase(String dbDirectory, {bool isMainProcess = true})
      : super(_openDb(dbDirectory, isMainProcess: isMainProcess));

  /// Opens a specific `.db` FILE (not a directory). Backup MERGE import
  /// (TODO-888) uses this to migrate an extracted backup DB to the current
  /// schema before merging it into the live DB.
  FushiDatabase.atFile(String dbFilePath, {bool isMainProcess = true})
      : super(_openDbFile(dbFilePath, isMainProcess: isMainProcess));

  FushiDatabase.forTesting(super.e) ;

  @override
  int get schemaVersion => 116;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (m, from, to) async {
          if (from > to) {
            // DOWNGRADE PROTECTION (root-cause fix for the recurring "old app
            // downgrades & destroys the user DB" incidents). drift dispatches
            // onUpgrade whenever the stored user_version != code schemaVersion,
            // INCLUDING when the DB is NEWER than the code (from > to). This is
            // the EARLIEST hook drift gives us, and it runs BEFORE any DROP /
            // migration / customStatement below. We refuse the open here by
            // throwing, which aborts beforeOpen: drift never advances
            // user_version and the DB file is left byte-for-byte intact. NEVER
            // drop / migrate / rebuild in this branch — a previous build did
            // exactly that and wiped users' libraries twice. The app layer
            // catches this exception and shows an "update your app" notice.
            throw FushiDatabaseDowngradeException(
              dbVersion: from,
              appSchemaVersion: to,
            );
          }
          // Kitapsen has shipped schema 116 since its first build, so no
          // Kitapsen install upgrades from an older version and the upstream
          // v1-v116 ladder is gone. An older file only gets the tables and
          // indexes it lacks. Tables of removed features stay on disk untouched.
          for (final TableInfo<Table, Object?> table in allTables) {
            if (!await _tableExists(table.actualTableName)) {
              await m.createTable(table);
            }
          }
          await _ensureIndexes();
        },
        onCreate: (m) async {
          await m.createAll();
          // 与 v81 步成对：uid 唯一索引不进 _ensureIndexes（会被早期迁移步在
          // 列不存在时调用），fresh 库在此内联补上。
          await customStatement(
              'CREATE UNIQUE INDEX IF NOT EXISTS idx_epub_books_uid '
              "ON epub_books (uid) WHERE uid != ''");
          // 与 v82 步成对：书签索引换 book_uid 列，同理不进 _ensureIndexes。
          await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_bookmarks_book_uid_created '
              'ON bookmarks (book_uid, created_at DESC)');
          await _ensureIndexes();
        },
        beforeOpen: (details) async {
          // Second, belt-and-suspenders downgrade guard. drift calls beforeOpen
          // on every open with the on-disk version (`versionBefore`, null for a
          // freshly created DB) and the code version (`versionNow`). On a real
          // downgrade onUpgrade already threw above (hadUpgrade is true when
          // versionBefore != versionNow), but if that branch is ever weakened
          // this independent check still refuses the open before any query runs.
          // No DROP / migration here — just throw to abort the open with the DB
          // untouched.
          final int? before = details.versionBefore;
          if (before != null && before > schemaVersion) {
            throw FushiDatabaseDowngradeException(
              dbVersion: before,
              appSchemaVersion: schemaVersion,
            );
          }
        },
      );

  // ── 类级常量/静态键（被 `FushiDatabase.x` 形式跨库引用，extension 的
  // static 需 extension 名限定，故集中留在类体；方法本体在各 part）──

  /// TODO-855: persisted monotonic counter, bumped on every preference write
  /// at this single lowest-level write choke point ([setPref]). It is the
  /// cross-process change signal the separate :popup process reads (via a cheap
  /// indexed row lookup) to decide whether to reload its warm-reuse pref cache,
  /// instead of unconditionally re-scanning the whole preferences table on each
  /// lookup. Sinking the bump here means EVERY path that writes a preference —
  /// PreferencesRepository, ThemeNotifier (theme / app_ui_scale), MediaSource
  /// (per-source font sizes etc.), profile switch, sync/backup restore —
  /// automatically advances it; no caller can forget to bump.
  static const String prefsVersionKey = 'prefs_version';


  /// 统计日分组键（本地时区 `yyyy-MM-dd`）的**唯一权威派生**（P4 写侧收敛 A 组）。
  /// app 层 `statDateKey` / 视频桶拆分等统计写入面的 dateKey 一律直接或间接走
  /// 这里，别再各自格式化一份。委托 [_FushiDbStatistics.statDateKeyOf]（复合
  /// 入口 recordReadingSession / recordMiningEvent 在 DB 层派生 dateKey 用的
  /// 同一实现）。
  static String statDateKeyOf(DateTime d) =>
      _FushiDbStatistics.statDateKeyOf(d);

  /// 「统计日」重置整点（0..23，默认 0）——「今日」从几点开始；见
  /// [_FushiDbStatistics.statDayResetHour]。偏好键 [kStatDayResetHourPrefKey]。
  static int get statDayResetHour => _FushiDbStatistics.statDayResetHour;
  static set statDayResetHour(int hour) =>
      _FushiDbStatistics.statDayResetHour = hour;

  /// 日历日 → `yyyy-MM-dd`（不看重置整点）。
  static String statCalendarDayKeyOf(DateTime day) =>
      _FushiDbStatistics.statCalendarDayKeyOf(day);

  /// dateKey → 对应日历日（本地午夜 DateTime，只用于日历算术）。
  static DateTime statDateKeyToDay(String dateKey) =>
      _FushiDbStatistics.statDateKeyToDay(dateKey);

  /// 键算术：[dateKey] 往后 [days] 天（负数往前）。窗口 / streak / 热力图一律走
  /// 这里，不要把合成的午夜 DateTime 喂给 [statDateKeyOf]。
  static String statDateKeyPlusDays(String dateKey, int days) =>
      _FushiDbStatistics.statDateKeyPlusDays(dateKey, days);

  /// 到下一个统计日边界（下一次 `statDayResetHour:00`）的时长，恒 > 0。
  static Duration untilNextStatDayBoundary(DateTime now) =>
      _FushiDbStatistics.untilNextStatDayBoundary(now);

  /// v92 学习事实段的幂等键生成（转发 [_FushiDbStatistics.newStudySegmentUid]；
  /// mixin 的 static 不经类继承，这里给调用方一个稳定入口）。
  static String newStudySegmentUid() => _FushiDbStatistics.newStudySegmentUid();

  /// 段 provenance 用的设备身份偏好键（与 fushi 层 SyncRepository 同一把 key）。
  static const String studyDeviceIdPrefKey =
      _FushiDbStatistics.studyDeviceIdPrefKey;
}

int _epubBookUidCounter = 0;

/// 书的本机稳定 uid 生成（v81 / P3 Stage 1）：`book_<微秒时刻>_<进程内计数>`。
/// 与迁移回填的 `book_<rowid>_<秒时刻>` 同命名空间不同后缀形，互不相撞；
/// 进程内计数器兜同微秒批量导入。**机器局域**身份，不进 wire（那边仍是
/// bookKey）；跨设备无需一致。
String generateEpubBookUid() => 'book_${DateTime.now().microsecondsSinceEpoch}_'
    '${_epubBookUidCounter++}';

