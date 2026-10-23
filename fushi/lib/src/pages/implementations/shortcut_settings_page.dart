// 快捷键设置页（library 壳）。
//
// 结构（快捷键设置重构）：本文件只保留页面本体（scope 卡片投影 + 可视化/列表
// 切换 + 手柄品牌选择 + GameInput 提示）；单个动作行与鼠标 chip 在
// `shortcut_settings/action_tile.part.dart`，绑定编辑对话框（键盘/鼠标实时捕获
// + 手柄下拉 + 冲突重分配）在 `shortcut_settings/binding_edit_dialog.part.dart`，
// 动作/作用域/鼠标绑定的本地化标签在公开的
// `shortcuts/shortcut_labels.dart` 扩展（加动作时标签与数据层就近同步）。
// 写穿路径不变：updateBindingWithReassignments → saveShortcutRegistry。
