/// 配置方案（Profile）分享 JSON 的**编解码与「作为新 Profile 落库」**——app 与
/// 无头服务端共用的唯一实现。
///
/// 这份 JSON 就是「配置管理」页导出的 `<名字>.fushiprofile.json`，也是互联
/// `/api/interconnect/profile` 的载荷（见 `interconnect_profile_transfer.dart`）。
/// 以前解析 / 组装 / createNew 落库全写在 app 的 `ProfileRepository` 里，服务端要
/// 收发同一份载荷就只能再抄一份——魔数、版本判据、「哪条废弃 key 入站即拒」于是会有
/// 两个真相源。这里只收纯 DB 的部分：
///
/// * **不**含「当前活偏好 → 快照」（`snapshotCurrentSettings`）与「快照 → 活偏好」
///   （`applyProfile`）：那两步要读写 Anki 设置、词典装没装的磁盘判据与 app 内存
///   缓存，只有 app 凑得齐；
/// * **不**含出境剔凭据：判定的唯一真相源是 app 的 `PrefRedactionPolicy`，由调用方
///   在把快照行交给 [encodeProfileDocument] 之前过滤。
library;

/// 配置方案导入失败：文件损坏 / 类型魔数不符 / 版本不兼容 / 结构非法。
///
/// 故意在写任何 DB 之前抛出（解析 + 校验阶段），使导入对 DB 是全有或全无，
/// 一个坏文件绝不留下半个 Profile（事务零破坏）。
abstract class ProfileImportException implements Exception {
}

/// 单 Profile 导出文件的解析结果（已剔除凭据、已 A1 剥字体绝对路径）。
abstract class ProfileExport {

}

/// 单条配置项（category/key/value），对应 profile_settings 行。
abstract class ProfileSettingEntry {
}

/// profile_settings 里「Drift 偏好」这一类的 category 值（与 app `ProfileKeys`
/// 同值，那边引用本常量）。
const String kProfileSettingCategoryPref = 'pref';

/// v63 已从 live preferences 与 Profile 副本中删除的旧全局超分键。
///
/// 每游戏真值是 `galgames.upscaling_mode`；此键只保留为输入拒绝标识，防止
/// 旧快照或旧分享 JSON 在升级后把废弃数据重新写回。
const String kObsoleteGalgameUpscalingModePrefKey =
    'galgame_magpie_upscaling_mode';
