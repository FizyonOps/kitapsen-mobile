/// 新手引导的纯数据模型：功能多选 → 步骤序列的映射。
///
/// 与 UI 解耦成顶层纯函数，便于单测「选了哪些功能就出现哪些步骤、顺序稳定」，
/// 不必实例化整个向导页面（模式同 `home_page.dart` 的 [homeActiveTabs]）。
library;

/// 向导步骤身份（枚举身份而非整数索引，插入/裁剪步骤不会打乱路由判断）。
enum OnboardingStepId {
  /// 欢迎：界面语言 / 明暗。
  welcome,

  /// Kitapsen 账号登录（可跳过）。
  kitapsenAccount,
}

/// Kitapsen's first-run flow: welcome (language / theme) then the store
/// sign-in. No feature picker, dictionaries, Anki or tutorials.
const List<OnboardingStepId> kKitapsenOnboardingSteps = <OnboardingStepId>[
  OnboardingStepId.welcome,
  OnboardingStepId.kitapsenAccount,
];
