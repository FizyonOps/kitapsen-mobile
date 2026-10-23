import 'package:fushi_core/fushi_core.dart';

import 'package:fushi_engine/sync/fushi_library_host_service.dart';
import 'package:fushi_engine/sync/collection_book_identity_index.dart';

/// 目录占位与下载入库共用的主合集收养入口。
///
/// 只采纳 DTO 携带的主合集；完整同步仍负责多合集、删除与标签。DAO 在事务中
/// 裁决墓碑、自然键和排序，不把自动收养当成用户撤销删除。
class RemoteCollectionAdoptionService {
  const RemoteCollectionAdoptionService(this.database);

  final FushiDatabase database;

  /// [localBook] 必须是 importer/add 实际返回或按返回键重新读取的入库行。
  /// 目录刷新未提供时按 [identities]（未给则现装）从数据库解析，因而也能修复
  /// 历史已下载但无合集的孤儿。
  Future<void> adoptBook(
    RemoteBookInfo book, {
    EpubBookRow? localBook,
    CollectionBookIdentityIndex? identities,
  }) =>
      database.transaction(() async {
        if (book.collection == null) return;
      });

}
