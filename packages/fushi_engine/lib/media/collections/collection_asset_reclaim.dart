import 'package:fushi_core/fushi_core.dart';

/// 删除合集的唯一入口。
///
/// 合集自有封面 / 附加图（`video_covers/collections/`、v68 `media_images`）只由视频
/// 模块生成，Kitapsen 不带那个模块，没有可回收的磁盘资产，所以这里只删 DB 行
/// （[FushiDatabase.deleteMediaCollection]，返回被删的合集行数）。
Future<int> deleteMediaCollectionWithAssets(
  FushiDatabase db,
  int collectionId,
) =>
    db.deleteMediaCollection(collectionId);
