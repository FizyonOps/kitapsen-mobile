import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:fushi_core/fushi_core.dart';

import 'package:drift/drift.dart' show QueryRow, Variable;

import 'package:fushi/src/profile/profile_keys.dart' show ProfileKeys;
import 'package:fushi/src/storage/path_rebase_coverage.dart';
import 'package:fushi/src/storage/path_rebase.dart' show rebaseFontCatalogJson, rebaseFontListJson, rebasePath;

abstract class DataRootMigrator {
  /// 同一段改写，作用在**已经打开**的 [db] 上。
  ///
  /// 抽出来是因为它有第二个调用者：启动期的沙箱重定位自愈
  /// （`sandbox_relocation.dart`）。那条路径里 app 正握着这个库，不能像
  /// [_rebaseDatabasePaths] 那样按目录另开一个 [FushiDatabase] 连接。
  ///
  /// **两条路径必须共用这一份调用清单**——覆盖面的真相源是
  /// `path_rebase_coverage.dart`，各自抄一份表就等于给「新增路径列」留了两个
  /// 会漂开的登记处。
  static Future<void> rebaseOpenDatabasePaths({
    required FushiDatabase db,
    required DocumentsPathRebaser docs,
    required String newSupportRoot,
  }) async {
    await db.transaction(() async {
      await _rebaseEpubBooks(db, docs);
      await _rebaseMediaCollections(db, docs);
      await _rebaseMediaOpenHistory(db, docs);
      await _rebasePreferences(db, docs, newSupportRoot);
      await _rebaseProfileSettings(db, docs, newSupportRoot);
    });
    // checkpoint 必须在事务**外**：SQLite 不允许在活动事务里 wal_checkpoint。
    await db.customStatement('PRAGMA wal_checkpoint(TRUNCATE)');
  }

  /// epub_books：epubPath / extractDir / coverPath。前者与 coverPath 按声明其实不是
  /// 数据根内路径（裸文件名 / 相对 href），改写是防御性 no-op，保留调用与历史行为一致。
  static Future<void> _rebaseEpubBooks(
    FushiDatabase db,
    DocumentsPathRebaser docs,
  ) async {
    for (final EpubBookRow b in await db.getAllEpubBooks()) {
      await db.updateEpubBookContentPaths(
        b.bookKey,
        epubPath: docs.rebase(b.epubPath),
        extractDir: docs.rebase(b.extractDir),
        coverPath: docs.rebaseNullable(b.coverPath),
      );
    }
  }

  /// media_collections：cover_path（`<documents>/video_covers/collections/<id>.jpg`）。
  /// BUG-1211 合集自有封面 ——
  /// 不改写 = 换过封面的合集在换数据根后全部退回「借成员封面」，用户看到封面自己变了。
  /// cover_source 是成员引用不是路径，绝不改写。
  static Future<void> _rebaseMediaCollections(
    FushiDatabase db,
    DocumentsPathRebaser docs,
  ) async {
    for (final MediaCollectionRow c in await db.getAllMediaCollections()) {
      final String? newCover = docs.rebaseNullable(c.coverPath);
      if (newCover == c.coverPath) continue;
      await db.customStatement(
        'UPDATE media_collections SET cover_path = ? WHERE id = ?',
        <Object?>[newCover, c.id],
      );
    }
  }

  /// media_items：image_url（本地书封面存 `file://<绝对路径>` URI）。BUG-1174 漏项 ——
  /// 不改写 = 书架/首页「最近」卡片封面全空白，直到该书被重新打开刷新。远端源的
  /// http(s) URL scheme 非 file，[DocumentsPathRebaser.rebaseFileUri] 原样返回。
  static Future<void> _rebaseMediaOpenHistory(
    FushiDatabase db,
    DocumentsPathRebaser docs,
  ) async {
    for (final MediaOpenHistoryRow m in await db.getAllMediaOpenHistory()) {
      // v80：imageUrl 在 snapshot JSON 里，逐行解码改写（行数被 trim 钉死）。
      Map<String, dynamic> snapshot;
      try {
        snapshot = jsonDecode(m.snapshotJson) as Map<String, dynamic>;
      } catch (_) {
        continue;
      }
      final Object? url = snapshot['imageUrl'];
      if (url is! String) continue;
      final String rebased = docs.rebaseFileUri(url);
      if (rebased == url) continue;
      snapshot['imageUrl'] = rebased;
      await db.customStatement(
        'UPDATE media_open_history SET snapshot_json = ? '
        'WHERE media_source = ? AND media_id = ?',
        <Object?>[jsonEncode(snapshot), m.mediaSource, m.mediaId],
      );
    }
  }

  /// preferences：按 [kPathRebasePrefs] 声明逐 key 改写（字体目录 / 音频来源配置）。
  static Future<void> _rebasePreferences(
    FushiDatabase db,
    DocumentsPathRebaser docs,
    String newSupportRoot,
  ) async {
    final Map<String, String> prefs = await db.getAllPrefs();
    for (final PathRebasePref spec in kPathRebasePrefs) {
      if (!spec.mustRebase) continue;
      final String? raw = prefs[spec.key];
      if (raw == null) continue;
      final String rebased = rebaseMigratedPrefValue(
        spec.key,
        raw,
        documents: docs,
        newSupportRoot: newSupportRoot,
      );
      if (rebased != raw) await db.setPref(spec.key, rebased);
    }
  }

  /// profile_settings：每个 Profile 的 pref 快照副本。**必须覆盖所有 Profile**，用与
  /// [_rebasePreferences] 完全相同的改写函数。
  ///
  /// 为什么选「迁移时一起改」而不是「让路径 pref 不进快照」：后者会改掉 Profile 的既有
  /// 语义（字体目录、发音库配置现在确实是**每 Profile** 的），等于为了修迁移去动一个与
  /// 迁移无关的功能契约——爆炸半径大得多，且会破坏已按 Profile 分别配字体的用户。
  /// 迁移时一起改是纯增量、零语义变更。
  static Future<void> _rebaseProfileSettings(
    FushiDatabase db,
    DocumentsPathRebaser docs,
    String newSupportRoot,
  ) async {
    final List<QueryRow> rows = await db.customSelect(
      'SELECT id, key, value FROM profile_settings WHERE category = ?',
      variables: <Variable<Object>>[
        Variable<String>(ProfileKeys.categoryPref),
      ],
    ).get();
    for (final QueryRow row in rows) {
      final String key = row.read<String>('key');
      final String value = row.read<String>('value');
      final String rebased = rebaseMigratedPrefValue(
        key,
        value,
        documents: docs,
        newSupportRoot: newSupportRoot,
      );
      if (rebased == value) continue;
      await db.customStatement(
        'UPDATE profile_settings SET value = ? WHERE id = ?',
        <Object?>[rebased, row.read<int>('id')],
      );
    }
  }
}

/// BUG-1174 ③：数据根迁移期的 documents 根路径改写器。**本质幂等**。
///
/// 旧写法的判据是 `startsWith(oldRoot)`。当新根落在旧根**内部**时（正是
/// `<Documents>` → `<Documents>/Hibiki/data` 这种形态），一条已经改写过的路径**仍然**
/// 以旧根开头，再跑一次就变成 `Documents/Hibiki/data/Hibiki/data/...` —— 全库路径当场
/// 作废、且不抛任何异常，**静默毁库**。同型的坑在 iOS 容器重定位上已经踩过一次
/// （BUG-1115）。
///
/// 这里不靠「保证只跑一次」的流程来回避（那是把正确性押在流程上），而是**把判据改对**：
/// 作用域谓词收窄为「相对旧根的**首段**命中 [scopeTopLevelNames]」，也就是**本次搬移
/// 真正会动的那些顶层项**。`Hibiki` 不在白名单里（`isSafeNestedTargetInSharedDocuments`
/// 靠的就是这一点），所以已改写过的路径首段是 `Hibiki` → 天然跳过。「跑没跑过」这个
/// 问题因此**消失**，而不是被判断掩盖。
///
/// [scopeTopLevelNames] 必须与 `DataRootMigrationRequest.documentsTopLevelIncludeNames`
/// **同源**：改写作用域与搬移作用域一旦漂开，就会出现「文件搬走了但路径没改」或反过来
/// 「路径改了但文件还在旧位置」。`null`（Hibiki 专属根的整树搬移语义）= 无首段限制；
/// 那条路径上 `_validateTarget` 已禁止新根落在旧根内部，故同样幂等。
@immutable
class DocumentsPathRebaser {
  const DocumentsPathRebaser({
    required this.oldRoot,
    required this.newRoot,
    required this.scopeTopLevelNames,
  });

  final String oldRoot;
  final String newRoot;

  /// 本次搬移真正会动的顶层项基名集合；null = 整树搬移（无首段限制）。
  final Set<String>? scopeTopLevelNames;

  static String _stripTrailingSeparator(String value) =>
      (value.endsWith('/') || value.endsWith('\\'))
          ? value.substring(0, value.length - 1)
          : value;

  /// [path] 是否落在本次改写的作用域内。分隔符归一与边界判据与
  /// `path_rebase.dart` 的 `rebasePath` 逐字节一致（`/a/books_extra` 不算在
  /// `/a/books` 下）。首段比较**大小写不敏感**——`p.canonicalize` 在 Windows 上转小写，
  /// 原样比对会让 `hibikiExport` 漏网（它会被搬走、路径却不改 = 数据分家）。在 Linux 上
  /// 大小写不敏感只会更宽松几个名字，而那些名字下本来就没有别人写的 DB 路径。
  bool isInScope(String path) {
    final String root = _stripTrailingSeparator(oldRoot.replaceAll('\\', '/'));
    final String normalized = path.replaceAll('\\', '/');
    if (normalized == root) return true;
    if (!normalized.startsWith('$root/')) return false;
    final Set<String>? scope = scopeTopLevelNames;
    if (scope == null) return true;
    final String first =
        normalized.substring(root.length + 1).split('/').first.toLowerCase();
    return scope.any((String owned) => owned.toLowerCase() == first);
  }

  /// 作用域内 → rebase 到新根；作用域外（用户外部路径 / 已改写过的路径）→ 原样返回。
  String rebase(String path) =>
      isInScope(path) ? rebasePath(path, oldRoot, newRoot) : path;

  String? rebaseNullable(String? path) => path == null ? null : rebase(path);

  /// 改写 `file://<绝对路径>` URI（`media_items.image_url`）。必须先解码成文件路径再
  /// 改写、再重新编码：对 URI 字符串直接做前缀替换，分隔符与百分号编码都不对。
  /// 非 `file:` scheme（远端源的 http(s) 封面）原样返回。
  String rebaseFileUri(String value) {
    final Uri? uri = Uri.tryParse(value);
    if (uri == null || uri.scheme != 'file') return value;
    final String filePath;
    try {
      filePath = uri.toFilePath();
    } catch (_) {
      return value; // 畸形 file URI：不猜、不动。
    }
    final String rebased = rebase(filePath);
    if (rebased == filePath) return value;
    return Uri.file(rebased).toString();
  }
}

/// BUG-1174 ②：给定 (pref key, 原始值) 返回改写后的值。**纯函数**。
///
/// `preferences` 与 `profile_settings` 两条路都必须调它。历史教训：把改写逻辑抄两份
/// （备份恢复侧与迁移侧）迟早漂开。这里只留一份。
///
/// 未登记（[pathRebasePrefFor] 返回 null）或登记为不改写的 key 一律原样返回——
/// `profile_settings` 里躺着**全部**非排除 pref，绝不能对不认识的 key 乱动。
String rebaseMigratedPrefValue(
  String key,
  String value, {
  required DocumentsPathRebaser documents,
  required String newSupportRoot,
}) {
  final PathRebasePref? spec = pathRebasePrefFor(key);
  if (spec == null || !spec.mustRebase) return value;
  switch (spec.shape) {
    // 字体 JSON 复用 path_rebase 的遍历器，但**必须注入作用域改写器**：那两个函数
    // 默认走裸 rebasePath（startsWith 判据），新根落在旧根内部时会把已改写过的 path 再
    // 改一遍 → `.../Hibiki/data/Hibiki/data/custom_fonts/a.ttf`。这是本次被幂等测试
    // **真实抓到**的旁路（BUG-1174 ③）。备份恢复侧不传 rewritePath，行为逐字节不变。
    case PathValueShape.fontCatalogJson:
      return rebaseFontCatalogJson(
        value,
        documents.oldRoot,
        documents.newRoot,
        rewritePath: documents.rebase,
      );
    case PathValueShape.fontListJson:
      return rebaseFontListJson(
        value,
        documents.oldRoot,
        documents.newRoot,
        rewritePath: documents.rebase,
      );
    case PathValueShape.none:
      return value;
  }
}
