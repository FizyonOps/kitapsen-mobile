import 'dart:io';
import 'dart:isolate';

import 'package:fushi_core/fushi_core.dart'
    show fushiDatabaseFileName, isDatabaseSnapshotFileName;
import 'package:path/path.dart' as p;

import 'package:fushi/src/storage/app_paths.dart';

/// 存储占用扫描服务（设置 → 存储）。
///
/// 只读扫描：本文件**不做任何删除**。删除一律走各域既有的删除路径（书籍
/// `ReaderFushiSource.deleteBook`、主库快照残留 fushi_core
/// `deleteDatabaseSnapshotFiles`），由 UI 层接线。每条明细带 [StorageEntryKind]
/// 说明它接哪条原语（或只读）。
///
/// 每个类目都出明细：书籍的条目来自 DB（有标题、接既有删除原语），其余类目的
/// 条目就是类目根下的直接子项（`_childEntriesSync`，只读展示）。目录求和递归 stat
/// 整棵树，全部经 [Isolate.run] 隔离跑，绝不在 UI isolate 同步扫。
enum StorageCategoryId {
  /// 书籍：`fushi_books`（EPUB / PDF 正文）。
  books,

  /// 封面与缩略图：`thumbnails`。
  covers,

  /// 自定义字体：`custom_fonts`。
  customFonts,

  /// 数据库与内部数据：support 根的直接子项（主库 `fushi.db` 等）。
  database,

  /// BUG-1905：缓存与临时文件。iOS 上 `getTemporaryDirectory()` 是
  /// `Library/Caches`，`Directory.systemTemp` 是 `<沙盒>/tmp`，两个都扫；具体扫哪些根
  /// 见 [StorageUsageService._defaultCacheRoots]。
  cache,

  /// BUG-1905：其他未归类 —— documents 根下**不在**白名单里的顶层项，让漏算在结构上
  /// 无法隐藏。只在 documents 根是本 app 专属容器时才有意义。
  other,
}

/// 明细条目的种类 = 它接哪条删除原语。可删性属于**条目**而不是类目：同一个
/// 「数据库与内部数据」类目里，活库是只读的，快照残留却可删（BUG-1870）。
enum StorageEntryKind {
  /// 一本书（`id` = bookKey；删除走 `ReaderFushiSource.deleteBook`）。
  book,

  /// support 根下全部主库快照残留聚成的**一条**（`paths` = 文件清单；删除走
  /// fushi_core `deleteDatabaseSnapshotFiles`，识别口径同源）。
  databaseSnapshots,

  /// 类目根下的磁盘子项，只读展示（删它就是裸 `Directory.delete`，绕过墓碑/引用护栏）。
  readOnly,

  /// 类目根下的磁盘子项，且**可以**直接删（`paths` = 待删路径）。只用于
  /// [kDeletableEntryCategories] 里那些纯派生 / 缓存 / 可重新获取的类目 —— 那里的
  /// 东西没有任何 DB 行引用，裸删不绕过任何护栏。
  derivedFile,
}

/// 明细可**直接删**的类目：派生数据（封面缩略图）与缓存 / 临时文件，没有任何 DB 行
/// 引用，裸删不留悬空引用。books（走 deleteBook）、customFonts（字体配置指着）、
/// database（活库）、other（白名单之外，语义不明）刻意不在内。
const Set<StorageCategoryId> kDeletableEntryCategories = <StorageCategoryId>{
  StorageCategoryId.covers,
  StorageCategoryId.cache,
};

/// 一个类目内的单条可展开条目（一本书 / 一部词典 / 类目根下的一个子项）。
class StorageEntryUsage {
  const StorageEntryUsage({
    required this.id,
    required this.label,
    required this.bytes,
    required this.paths,
    required this.kind,
  });

  /// 域内主键（书 = bookKey，通用子项 = 绝对路径）。
  final String id;

  /// 显示名（书名 / `<顶层目录>/<子项名>`）。[StorageEntryKind.databaseSnapshots]
  /// 的显示名由 UI 按 `paths.length` 翻译，此处只是无 i18n 的兜底。
  final String label;

  final StorageEntryKind kind;

  /// 该条目占用字节数（多个目录求和）。
  final int bytes;

  /// 参与求和的绝对路径（诊断用）。
  final List<String> paths;
}

/// 一个类目的扫描结果。
class StorageCategoryUsage {
  const StorageCategoryUsage({
    required this.id,
    required this.bytes,
    this.entries = const <StorageEntryUsage>[],
  });

  final StorageCategoryId id;

  /// 类目总字节数。书籍类目按**目录整树**求和——可能大于 [entries] 之和：
  /// 孤儿目录、未入库残留也如实计入，不做「只算已知条目」的假账；其余类目的
  /// 明细就是根目录的全部直接子项，两者恒相等。
  final int bytes;

  /// 可展开明细，按字节数降序。书籍是 DB 已知条目（带删除原语），其余
  /// 类目是类目根下的直接子项（只读展示）。
  final List<StorageEntryUsage> entries;
}

/// 书籍条目的扫描输入（由 UI 层从 `epub_books` 取出后传入）。
class StorageBookRef {
  const StorageBookRef({
    required this.id,
    required this.title,
    required this.extractDir,
  });

  /// `EpubBooks.bookKey`，直接成为 [StorageEntryUsage.id]。
  final String id;

  final String title;

  /// `EpubBooks.extractDir`（解压正文绝对路径；这是唯一真相，**不要**用
  /// bookKey 重新派生——pre-v16 的书目录名是旧 int id）。
  final String extractDir;
}

/// 每类目 → documents 根下归属的顶层目录名。与
/// [AppPaths.fushiOwnedDocumentsEntries] 保持全覆盖（守卫测试咬住）。
const Map<StorageCategoryId, List<String>> kStorageCategoryDocumentsChildren =
    <StorageCategoryId, List<String>>{
  StorageCategoryId.books: <String>['fushi_books'],
  StorageCategoryId.covers: <String>['thumbnails'],
  StorageCategoryId.customFonts: <String>['custom_fonts'],
};

/// 同步递归求目录字节数（isolate 入口；每个 entry 单独容错——扫描中途被删/
/// 无权限的文件跳过不炸整树）。
int directorySizeSync(final String path) {
  final Directory dir = Directory(path);
  if (!dir.existsSync()) {
    // 不是目录时按文件算（随包组件里有单文件项）。
    final File f = File(path);
    try {
      return f.existsSync() ? f.lengthSync() : 0;
    } on FileSystemException {
      return 0;
    }
  }
  int total = 0;
  try {
    for (final FileSystemEntity e
        in dir.listSync(recursive: true, followLinks: false)) {
      if (e is! File) continue;
      try {
        total += e.lengthSync();
      } on FileSystemException {
        // 竞态删除/无权限：跳过该文件。
      }
    }
  } on FileSystemException {
    // 整树列举失败（目录被并发删除等）：返回已累计部分。
  }
  return total;
}

/// isolate 入口：多路径求和（每条路径独立容错）。
int _pathsSizeSync(final List<String> paths) {
  int total = 0;
  for (final String path in paths) {
    total += directorySizeSync(path);
  }
  return total;
}

/// isolate 入口：列出多个根目录的**直接子项**并逐个求大小。
///
/// 这是除书籍（有 DB 标题与既有删除原语，见 `_scanBooks`）之外所有类目的明细来源：
/// 类目根下每个文件/子目录一条，label 带顶层目录名前缀，跨根重名不会混淆。
///
/// 子项之和恒等于整树之和（根目录自身不占字节），所以类目总量直接由明细求和得出，
/// 不再额外扫一遍整树。
List<Map<String, Object>> _childEntriesSync(final List<String> roots) {
  final List<Map<String, Object>> out = <Map<String, Object>>[];
  for (final String root in roots) {
    final Directory dir = Directory(root);
    if (!dir.existsSync()) continue;
    List<FileSystemEntity> children;
    try {
      children = dir.listSync(followLinks: false);
    } on FileSystemException {
      // 整树列举失败（并发删除/无权限）：该根跳过。
      continue;
    }
    for (final FileSystemEntity child in children) {
      out.add(<String, Object>{
        'label': '${p.basename(root)}/${p.basename(child.path)}',
        'path': child.path,
        'bytes': directorySizeSync(child.path),
        'isFile': child is File,
      });
    }
  }
  return out;
}

/// 目录求和的执行环境（默认 [Isolate.run]；widget 测试的 FakeAsync 区里真
/// isolate 永不完成，测试注同步执行版 `<R>(f) async => f()`）。
typedef StorageIsolateRunner = Future<R> Function<R>(R Function() computation);

class StorageUsageService {
  StorageUsageService({
    Future<Directory> Function()? documentsRoot,
    Future<Directory> Function()? supportRoot,
    Future<List<Directory>> Function()? cacheRoots,
    Future<bool> Function()? documentsRootIsFushiOwned,
    StorageIsolateRunner? isolateRunner,
  })  : _documentsRoot = documentsRoot ?? AppPaths.documentsRootDirectory,
        _supportRoot = supportRoot ?? AppPaths.supportRootDirectory,
        _cacheRoots = cacheRoots ?? _defaultCacheRoots,
        _documentsRootIsFushiOwned =
            documentsRootIsFushiOwned ?? AppPaths.documentsRootIsFushiOwned,
        _run = isolateRunner ?? Isolate.run;

  final Future<Directory> Function() _documentsRoot;
  final Future<Directory> Function() _supportRoot;

  /// BUG-1905：此前完全没被扫过的第三类根（缓存/临时）。见 [_defaultCacheRoots]。
  final Future<List<Directory>> Function() _cacheRoots;

  /// BUG-1905：见 [AppPaths.documentsRootIsFushiOwned]——决定「其他未归类」敢不敢算。
  final Future<bool> Function() _documentsRootIsFushiOwned;

  final StorageIsolateRunner _run;

  /// 逐类目扫描，每算完一类就产出一个结果（UI 渐进刷新，慢的类目不挡快的类目）。
  /// [books] 由调用方从 DB 取出。
  Stream<StorageCategoryUsage> scanCategories({
    required final List<StorageBookRef> books,
  }) async* {
    final Directory docs = await _documentsRoot();
    final Directory support = await _supportRoot();

    for (final StorageCategoryId id in StorageCategoryId.values) {
      switch (id) {
        case StorageCategoryId.books:
          yield await _scanBooks(docs, books);
        case StorageCategoryId.database:
          yield await _scanDatabase(support);
        case StorageCategoryId.cache:
          yield await _scanCache();
        case StorageCategoryId.other:
          yield await _scanOther(docs);
        default:
          final List<String> children =
              kStorageCategoryDocumentsChildren[id] ?? const <String>[];
          yield await _scanGeneric(id, <String>[
            for (final String child in children) p.join(docs.path, child),
          ]);
      }
    }
  }

  Future<StorageCategoryUsage> _scanBooks(
    final Directory docs,
    final List<StorageBookRef> books,
  ) async {
    // 总量按目录整树（含孤儿），明细按 DB 已知的书。全部路径打包进**一次**
    // isolate 调用，避免几百本书起几百个 isolate。
    final List<String> categoryRoots = <String>[
      for (final String child
          in kStorageCategoryDocumentsChildren[StorageCategoryId.books]!)
        p.join(docs.path, child),
    ];
    final List<List<String>> perBookPaths = <List<String>>[
      for (final StorageBookRef b in books)
        <String>[if (b.extractDir.isNotEmpty) b.extractDir],
    ];
    // 一次 isolate 调用同时拿「类目根的直接子项」与「每本书的大小」：子项之和
    // 恒等于整树之和（根目录自身不占字节），所以类目总量改由子项求得，扫描量与
    // 旧的整树求和一致，却顺带拿到了求差集所需的子项清单。
    final Map<String, Object> raw = await _run(() {
      return <String, Object>{
        'children': _childEntriesSync(categoryRoots),
        'sizes': <int>[
          for (final List<String> paths in perBookPaths) _pathsSizeSync(paths),
        ],
      };
    });
    final List<Map<String, Object>> children =
        (raw['children']! as List<dynamic>).cast<Map<String, Object>>();
    final List<int> sizes = (raw['sizes']! as List<dynamic>).cast<int>();
    final List<StorageEntryUsage> entries = <StorageEntryUsage>[
      for (int i = 0; i < books.length; i++)
        StorageEntryUsage(
          id: books[i].id,
          label: books[i].title,
          bytes: sizes[i],
          paths: perBookPaths[i],
          kind: StorageEntryKind.book,
        ),
      // BUG-2096：DB 不认识、却确实占着盘的直接子项（删书留下的孤儿目录、导入
      // 残留）。不铺出来的话它们只活在「类目总量 − 明细之和」的差里，而页面从不
      // 显示那个差——用户只看见类目行的大数字，展开却对不上账。只读展示：裸删
      // 会绕过墓碑/引用护栏。
      ..._childEntries(
        children,
        excludePaths: _topLevelOwners(
          paths: <String>[
            for (final List<String> paths in perBookPaths) ...paths,
          ],
          roots: categoryRoots,
        ),
      ),
    ]..sort((StorageEntryUsage a, StorageEntryUsage b) =>
        b.bytes.compareTo(a.bytes));
    return StorageCategoryUsage(
      id: StorageCategoryId.books,
      bytes: _sumChildBytes(children),
      entries: entries,
    );
  }

  /// 快照聚合条目的域内主键（UI 用它做忙碌态/去重）。
  static const String kDatabaseSnapshotsEntryId = 'database-snapshots';

  Future<StorageCategoryUsage> _scanDatabase(final Directory support) async {
    // support 根的直接子项：明细里因此能看到主库 `fushi.db` 等具体大件。
    //
    // BUG-1870：主库崩溃恢复快照（`fushi.db.corrupt-bak-<stamp>.db*`）不逐个按
    // 原始文件名铺开，而是聚成**一条**可删条目——识别口径直接用 fushi_core 的
    // [isDatabaseSnapshotFileName]，与删除原语同源。
    final List<Map<String, Object>> raw =
        await _run(() => _childEntriesSync(<String>[support.path]));
    final List<Map<String, Object>> snapshots = <Map<String, Object>>[
      for (final Map<String, Object> e in raw)
        if (e['isFile'] as bool &&
            isDatabaseSnapshotFileName(p.basename(e['path'] as String)))
          e,
    ];
    final List<String> snapshotPaths = <String>[
      for (final Map<String, Object> e in snapshots) e['path'] as String,
    ];
    final List<StorageEntryUsage> entries = <StorageEntryUsage>[
      ..._childEntries(raw, excludePaths: snapshotPaths.toSet()),
      if (snapshots.isNotEmpty)
        StorageEntryUsage(
          id: kDatabaseSnapshotsEntryId,
          label: '${p.basename(support.path)}/$fushiDatabaseFileName.*',
          bytes: snapshots.fold<int>(
              0, (int sum, Map<String, Object> e) => sum + (e['bytes'] as int)),
          paths: snapshotPaths,
          kind: StorageEntryKind.databaseSnapshots,
        ),
    ]..sort((StorageEntryUsage a, StorageEntryUsage b) =>
        b.bytes.compareTo(a.bytes));
    return StorageCategoryUsage(
      id: StorageCategoryId.database,
      bytes: _sumBytes(entries),
      entries: entries,
    );
  }

  /// 通用类目扫描：类目根下每个直接子项一条明细，类目总量 = 明细求和。
  Future<StorageCategoryUsage> _scanGeneric(
    final StorageCategoryId id,
    final List<String> roots,
  ) async {
    final List<Map<String, Object>> raw =
        await _run(() => _childEntriesSync(roots));
    final List<StorageEntryUsage> entries = _childEntries(
      raw,
      kind: kDeletableEntryCategories.contains(id)
          ? StorageEntryKind.derivedFile
          : StorageEntryKind.readOnly,
    )..sort((StorageEntryUsage a, StorageEntryUsage b) =>
        b.bytes.compareTo(a.bytes));
    return StorageCategoryUsage(
        id: id, bytes: _sumBytes(entries), entries: entries);
  }

  /// BUG-1905：要统计的缓存/临时根。
  ///
  /// **只在这些目录确实属于本 app 时才统计** —— 这是本类目唯一的正确性红线：
  /// * **iOS / Android**：两个目录都在 app 沙盒内，且**互不相同**——
  ///   `path_provider` 的 `getTemporaryDirectory()` 在 Apple 平台返回
  ///   `Library/Caches`（见 `PathProviderPlugin.swift` 的
  ///   `case .temp: return .cachesDirectory`），而 Dart 的 `Directory.systemTemp`
  ///   读 `TMPDIR` 指向 `<沙盒>/tmp`。两个都要算，去重后扫。
  /// * **macOS**：`getTemporaryDirectory()` 给的是 app 私有的 `Library/Caches`，
  ///   算；但 `systemTemp`（`/var/folders/…/T`）是跨 app 共享的，不算。
  /// * **Windows / Linux**：临时目录是**全系统共享**的（`%TEMP%` / `/tmp`），
  ///   里面装着别的程序的文件。把它算进 app 占用会严重高报——宁可这一类为 0，
  ///   也绝不报一个假的大数。要在桌面统计 Fushi 自己的临时文件，只能再引入一份
  ///   「哪些子目录是我们的」白名单，而白名单漂移正是本 bug 的成因，不再重蹈。
  static Future<List<Directory>> _defaultCacheRoots() async {
    final bool sandboxed = Platform.isIOS || Platform.isAndroid;
    if (!sandboxed) return const <Directory>[];
    final Directory temp = await AppPaths.tempRootDirectory();
    if (!sandboxed) return <Directory>[temp];
    final Directory system = Directory.systemTemp;
    return <Directory>[
      temp,
      if (p.canonicalize(system.path) != p.canonicalize(temp.path)) system,
    ];
  }

  /// BUG-1905：缓存与临时文件。根的选取与理由见 [_defaultCacheRoots]。
  Future<StorageCategoryUsage> _scanCache() async {
    final List<Directory> roots = await _cacheRoots();
    final List<Map<String, Object>> raw = roots.isEmpty
        ? const <Map<String, Object>>[]
        : await _run(() => _childEntriesSync(
            <String>[for (final Directory d in roots) d.path]));
    final List<StorageEntryUsage> entries = _childEntries(
      raw,
      kind: StorageEntryKind.derivedFile,
    )..sort((StorageEntryUsage a, StorageEntryUsage b) =>
        b.bytes.compareTo(a.bytes));
    return StorageCategoryUsage(
      id: StorageCategoryId.cache,
      bytes: _sumBytes(entries),
      entries: entries,
    );
  }

  /// BUG-1905：documents 根下**白名单之外**的顶层项。
  ///
  /// 让漏算无法隐藏：白名单是手写的，漏了什么就静默少算多少，而总计恰恰是各类目
  /// 之和，页面自己永远发现不了（例：错误日志 `.txt`）。
  ///
  /// 桌面老扁平安装下 documents 根就是用户自己的文档文件夹，那里的东西不是 app 的
  /// 占用，本类目直接返回 0（见 [AppPaths.documentsRootIsFushiOwned]）。
  Future<StorageCategoryUsage> _scanOther(final Directory docs) async {
    if (!await _documentsRootIsFushiOwned()) {
      return const StorageCategoryUsage(id: StorageCategoryId.other, bytes: 0);
    }
    final List<Map<String, Object>> raw =
        await _run(() => _childEntriesSync(<String>[docs.path]));
    const Set<String> known = AppPaths.fushiOwnedDocumentsEntries;
    final List<StorageEntryUsage> entries = <StorageEntryUsage>[
      for (final StorageEntryUsage e in _childEntries(raw))
        if (!known.contains(p.basename(e.paths.single))) e,
    ]..sort((StorageEntryUsage a, StorageEntryUsage b) =>
        b.bytes.compareTo(a.bytes));
    return StorageCategoryUsage(
      id: StorageCategoryId.other,
      bytes: _sumBytes(entries),
      entries: entries,
    );
  }

  /// isolate 回传的原始子项 → 明细。[excludePaths] 里的子项既不计入明细也不计入
  /// 总量（被别的类目单列、或已聚合进别的条目时用）。[kind] 决定这批明细有没有
  /// 删除入口，默认只读。
  static List<StorageEntryUsage> _childEntries(
    final List<Map<String, Object>> raw, {
    final Set<String> excludePaths = const <String>{},
    final StorageEntryKind kind = StorageEntryKind.readOnly,
  }) {
    return <StorageEntryUsage>[
      for (final Map<String, Object> e in raw)
        if (!excludePaths.contains(e['path'] as String))
          StorageEntryUsage(
            // 通用明细没有域内主键，用绝对路径当身份（UI 只拿它做展开/去重）。
            id: e['path'] as String,
            label: e['label'] as String,
            bytes: e['bytes'] as int,
            paths: <String>[e['path'] as String],
            kind: kind,
          ),
    ];
  }

  static int _sumBytes(final List<StorageEntryUsage> entries) =>
      entries.fold<int>(0, (int sum, StorageEntryUsage e) => sum + e.bytes);

  /// [_childEntriesSync] 产出的子项字节和 == 类目根整树字节和（根目录自身不占
  /// 字节）；书籍类目的总量由它得出。
  static int _sumChildBytes(final List<Map<String, Object>> children) =>
      children.fold<int>(
          0, (int sum, Map<String, Object> e) => sum + (e['bytes'] as int));

  /// 把已知条目的路径收敛到「类目根的直接子项」层级，供 [_childEntries] 求差集。
  ///
  /// 书籍的明细口径是 DB 已知条目，其路径可能深于直接子项，而孤儿只能按直接子项
  /// 铺开——两套口径必须先落到同一层级才能相减，否则整个 `fushi_books/<bookKey>`
  /// 会被当成没人认领，与那本书的条目重复计一遍。
  static Set<String> _topLevelOwners({
    required final Iterable<String> paths,
    required final List<String> roots,
  }) {
    final Set<String> owners = <String>{};
    for (final String path in paths) {
      for (final String root in roots) {
        if (!p.isWithin(root, path)) continue;
        final List<String> segments = p.split(p.relative(path, from: root));
        if (segments.isEmpty) continue;
        owners.add(p.join(root, segments.first));
        break;
      }
    }
    return owners;
  }
}

/// 人类可读字节数（存储页统一口径：1024 进制，两位小数以内）。
String formatStorageBytes(final int bytes) {
  if (bytes < 1024) return '$bytes B';
  const List<String> units = <String>['KB', 'MB', 'GB', 'TB'];
  double v = bytes / 1024;
  int u = 0;
  while (v >= 1024 && u < units.length - 1) {
    v /= 1024;
    u++;
  }
  return '${v >= 100 ? v.toStringAsFixed(0) : v.toStringAsFixed(1)} ${units[u]}';
}
