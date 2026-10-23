

/// 与业务无关的资产存取层：在“命名空间”（文件夹/前缀）下存/取/列二进制资产，
/// 外加通用 JSON 读写。每个 `SyncBackend` 都实现它，供同步编排器统一调用。
abstract class SyncAssetStore {

}
