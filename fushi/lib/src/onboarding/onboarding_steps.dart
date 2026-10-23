/// 新手引导的纯数据模型：功能多选 → 步骤序列的映射。
///
/// 与 UI 解耦成顶层纯函数，便于单测「选了哪些功能就出现哪些步骤、顺序稳定」，
/// 不必实例化整个向导页面（模式同 `home_page.dart` 的 [homeActiveTabs]）。
library;

import 'package:fushi/src/models/module_id.dart';

/// 功能选择步骤里可勾选的项，分两类：
///
/// - **功能模块**（[ModuleId] 全部 11 个）：勾选状态在离开功能选择步骤时写进
///   `module_*_enabled` 偏好，未勾选的模块整套入口都不再露出（底栏/侧栏 tab、
///   设置一级分类、快捷键分区、首页聚合；设置 → 外观 → 功能模块 可随时改回）。
///   模块本身**不产生**引导步骤，但它是本模块名下配置步骤的总闸：模块都不要了，
///   向导就不该再拉着用户配它（扩展安装 / Anki / 备份 / 互联 / 应用外查词）。
/// - **配置能力**（资源准备/Anki/字体/备份/互联）：勾选只决定向导后续走哪些配置
///   步骤，不写任何持久化开关。
///
/// 两类的对应关系是**一张表**（[onboardingFeatureOfModule]），不是散在各处的
/// `if`：加模块时编译器强制在那张表里补齐，`kOnboardingModuleFeatures` 与反查
/// 都从它推导。
enum OnboardingFeature {
  /// 小说库页（模块）。
  books,

  /// 漫画库页（模块）。
  manga,

  /// 视频库页（模块）。
  video,

  /// galgame 游戏库页（模块，仅 Windows 提供勾选）。
  games,

  /// 浏览（模块）：在线来源 / 扩展 / 发现 / 下载。
  browse,

  /// 查词页（模块）。注意关掉它只关**页面入口**，划词查词能力全留。
  lookup,

  /// 浏览器扩展 tab（模块，仅桌面提供勾选；同时门控扩展安装引导步骤）。
  browserExtension,

  /// 听书：有声书播放/导入、语音转录、悬浮歌词（模块）。
  listening,

  /// 制卡：Anki 集成（模块）。门控下面的 [anki] 配置步骤。
  cardCreation,

  /// 在线服务与媒体追踪（模块）。
  services,

  /// 同步备份 + 设备互联（模块）。门控下面的 [backup] / [interconnect] 步骤。
  sync,

  /// 官方推荐包：日语推荐词典 + 日/英发音音频库（Fushi 备份 zip，向导内直接
  /// 下载导入）。
  recommendedPack,

  /// 手动补充资源：导入词典，并按需导入有声书/配置发音来源；可与推荐包同时选。
  manualResources,

  /// Anki 制卡（AnkiConnect / AnkiDroid）。
  anki,

  /// 在线服务账号与 API 配置总览；默认不选，仅展示配置教程。
  onlineServices,

  /// 自定义字体（界面/正文/词典）。默认勾选；不勾则向导不出现字体步骤。
  fonts,

  /// 备份与同步（云端/自建后端 + 本地备份文件）。
  backup,

  /// 设备互联（局域网配对、共享书库/进度/查词）。
  interconnect,
}

/// 配置能力的默认教程选择；不控制服务启用，也不读取或修改已有账号。
const Set<OnboardingFeature> kOnboardingDefaultCapabilities =
    <OnboardingFeature>{
  OnboardingFeature.recommendedPack,
  OnboardingFeature.anki,
  OnboardingFeature.fonts,
};

/// [ModuleId] → 功能选择步骤里代表它的勾选项。**穷尽 switch**：加模块时编译器
/// 强制在这里补齐，向导的模块方格、写回 `module_*_enabled` 的循环与下面的步骤
/// 总闸全部从这一张表推导，不会再出现「加了模块但向导只认 5 个」的漂移。
OnboardingFeature onboardingFeatureOfModule(ModuleId module) =>
    switch (module) {
      ModuleId.books => OnboardingFeature.books,
      ModuleId.manga => OnboardingFeature.manga,
      ModuleId.video => OnboardingFeature.video,
      ModuleId.games => OnboardingFeature.games,
      ModuleId.browse => OnboardingFeature.browse,
      ModuleId.lookup => OnboardingFeature.lookup,
      ModuleId.browserExtension => OnboardingFeature.browserExtension,
      ModuleId.listening => OnboardingFeature.listening,
      ModuleId.cardCreation => OnboardingFeature.cardCreation,
      ModuleId.services => OnboardingFeature.services,
      ModuleId.sync => OnboardingFeature.sync,
    };

/// 向导步骤身份（枚举身份而非整数索引，插入/裁剪步骤不会打乱路由判断）。
enum OnboardingStepId {
  /// 欢迎 + 界面语言/明暗主题（复用外观设置的行选择器）。
  welcome,

  /// 功能多选（库页模块 + 配置能力）。
  features,

  /// 推荐包下载与导入。
  recommendedPack,

  /// 手动导入词典、有声书与发音来源。
  manualResources,
  anki,
  onlineServices,
  backup,
  interconnect,

  /// 浏览器扩展安装引导（仅桌面）。
  browserExtension,

  /// 自定义字体配置（仅 [OnboardingFeature.fonts] 被勾选时）。
  fonts,

  /// 应用内点击文字查词的操作教程（全平台）。
  clickLookup,

  /// 应用外全局查词的操作教程（当前仅 Windows / Android 有完整入口）。
  globalLookup,

  /// 完成第一张 Anki 卡片（仅本次向导已验证连接并选好牌组/笔记类型时）。
  firstAnkiCard,
  finish,

  /// Kitapsen: sign in to the store account (skippable).
  kitapsenAccount,
}

/// Kitapsen's first-run flow: welcome (language / theme) then the store
/// sign-in. No feature picker, dictionaries, Anki or tutorials.
const List<OnboardingStepId> kKitapsenOnboardingSteps = <OnboardingStepId>[
  OnboardingStepId.welcome,
  OnboardingStepId.kitapsenAccount,
];

/// Records explicit Next actions, not merely visiting a page or leaving via Skip.
class OnboardingTutorialProgress {
  final Set<OnboardingStepId> _completed = <OnboardingStepId>{};

  void completeStep(OnboardingStepId step) {
    if (_isTutorial(step)) _completed.add(step);
  }

  static bool _isTutorial(OnboardingStepId step) =>
      step == OnboardingStepId.clickLookup ||
      step == OnboardingStepId.globalLookup ||
      step == OnboardingStepId.firstAnkiCard;
}
