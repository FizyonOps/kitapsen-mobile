import 'dart:async';

import 'package:flutter/material.dart';
import 'package:fushi/src/pages/implementations/kitapsen_account_settings_section.dart';
import 'package:fushi/pages.dart';
import 'package:fushi/src/onboarding/onboarding_steps.dart';
import 'package:fushi/src/settings/settings_actions.dart'
    show buildLanguageSelector, buildBrightnessSelector;
import 'package:fushi/src/settings/settings_context.dart';
import 'package:fushi/utils.dart';

/// 步骤内容区最大宽度：桌面宽窗口下正文行长过长会难读，卡片也会被拉成长条。
const double _kOnboardingContentMaxWidth = 720;

/// 新手引导向导：首次启动（`onboarding_completed == false`）由 [HomePage] 首帧
/// 弹出，之后可从「设置 → 系统」重新打开。
///
/// 步骤序列 [kKitapsenOnboardingSteps]：欢迎（界面语言/主题）→ Kitapsen 账号登录。
/// 向导唯一的持久化副作用：完成/跳过时把 `onboarding_completed` 置回 true。
///
/// 页面骨架：页头下方一条分段进度条（[OnboardingProgressBar]）；每步以左对齐的
/// [OnboardingStepHero]（图标 + 标题 + 一句话）开头；动作走 [OnboardingActionList]
/// ——必做/推荐的动作直接摊开，可选动作收进「其他方式」折叠组，避免一屏五个入口。
class OnboardingWizardPage extends BasePage {
  const OnboardingWizardPage({super.key});

  @override
  BasePageState<OnboardingWizardPage> createState() =>
      _OnboardingWizardPageState();
}

class _OnboardingWizardPageState extends BasePageState<OnboardingWizardPage>
    with SettingsContextHost<OnboardingWizardPage> {
  int _stepIndex = 0;
  bool _completing = false;

  List<OnboardingStepId> get _steps => kKitapsenOnboardingSteps;

  Future<void> _complete() async {
    if (_completing) return;
    _completing = true;
    try {
      await appModelNoUpdate.setOnboardingCompleted(value: true);
    } finally {
      _completing = false;
    }
    if (!mounted) return;
    await Navigator.of(context).maybePop();
  }

  void _goNext() {
    if (_stepIndex >= _steps.length - 1) {
      unawaited(_complete());
      return;
    }
    setState(() => _stepIndex += 1);
  }

  void _goBack() {
    if (_stepIndex == 0) return;
    setState(() => _stepIndex -= 1);
  }

  // ── build ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final FushiDesignTokens tokens = FushiDesignTokens.of(context);
    final List<OnboardingStepId> steps = _steps;
    final OnboardingStepId step = steps[_stepIndex];
    final bool isLast = _stepIndex == steps.length - 1;

    // 单行页头：返回按钮和标题同一行，页头下方挂分段进度条。
    //
    // 手动返回按钮与标题共用 [FushiPageHeader]；关闭自动推导，避免将来本页在可返回
    // route 中嵌套时重复插入第二个返回按钮。脚手架的 PrimaryScrollController /
    // PageScrollRegistry（手柄 LB/RB 翻页）照旧保留。
    return FushiPageScaffold(
      automaticallyImplyLeading: false,
      headerCompact: true,
      leading: BackButton(
        key: const ValueKey<String>('onboarding_back'),
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      title: t.onboarding_title,
      headerBottom: OnboardingProgressBar(
        current: _stepIndex,
        total: steps.length,
      ),
      body: Column(
        children: <Widget>[
          // BUG-2440：脚手架的 body 不再扣底部安全区，那一段归下面这条按钮行的
          // SafeArea 认领。步骤正文在按钮行**上方**、够不着屏幕底边，所以先把
          // 底部 inset 从它的 MediaQuery 里摘掉——不摘的话，自己补安全区的步骤
          // （如 [OnlineServicesOnboardingView]）会和按钮行各补一次，在按钮上方
          // 顶出一条 34pt 空白。
          Expanded(
            child: MediaQuery.removePadding(
              context: context,
              removeBottom: true,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: _kOnboardingContentMaxWidth,
                  ),
                  child: _buildStep(step),
                ),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.all(tokens.spacing.card),
              child: Row(
                children: <Widget>[
                  if (!isLast)
                    TextButton(
                      onPressed: () => unawaited(_complete()),
                      child: Text(t.onboarding_action_skip),
                    ),
                  const Spacer(),
                  Text(
                    '${_stepIndex + 1} / ${steps.length}',
                    style: textTheme.labelMedium!.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  SizedBox(width: tokens.spacing.gap),
                  if (_stepIndex > 0)
                    OutlinedButton(onPressed: _goBack, child: Text(t.back)),
                  if (_stepIndex > 0) SizedBox(width: tokens.spacing.gap),
                  FilledButton(
                    onPressed: _goNext,
                    child: Text(
                      isLast
                          ? t.onboarding_action_start
                          : t.onboarding_action_next,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep(OnboardingStepId step) {
    // Kitapsen: only the welcome and account steps exist ([kKitapsenOnboardingSteps]);
    // returning before the switch compiles every other step page out.
    return step == OnboardingStepId.kitapsenAccount
        ? _buildKitapsenAccountStep()
        : _buildWelcomeStep();
  }

  /// Kitapsen sign-in step: the same account section as Settings › Kitapsen
  /// account. Skippable (Skip / Start both close the wizard).
  Widget _buildKitapsenAccountStep() {
    final FushiDesignTokens tokens = FushiDesignTokens.of(context);
    return ListView(
      padding: EdgeInsets.all(tokens.spacing.card),
      children: <Widget>[
        OnboardingStepHero(
          icon: Icons.menu_book_outlined,
          title: t.kitapsen_onboarding_title,
          body: t.kitapsen_onboarding_body,
        ),
        SizedBox(height: tokens.spacing.card),
        const KitapsenAccountSettingsSection(),
      ],
    );
  }

  Widget _buildWelcomeStep() {
    final FushiDesignTokens tokens = FushiDesignTokens.of(context);
    final SettingsContext settingsContext = createSettingsContext(
      appModel: appModel,
      ref: ref,
    );
    return ListView(
      padding: EdgeInsets.all(tokens.spacing.card),
      children: <Widget>[
        OnboardingStepHero(
          icon: Icons.waving_hand_outlined,
          title: t.onboarding_welcome_headline,
          body: t.onboarding_welcome_body,
        ),
        SizedBox(height: tokens.spacing.card),
        // 复用外观设置的行选择器（同一真相源），语言/明暗改动立即生效。
        FushiCard(
          padding: EdgeInsets.symmetric(vertical: tokens.spacing.gap / 2),
          child: Column(
            children: <Widget>[
              buildLanguageSelector(settingsContext),
              buildBrightnessSelector(settingsContext),
            ],
          ),
        ),
      ],
    );
  }

}

// ── 共享 widget（公开，便于脱离 AppModel 做 widget 测试）────────────────

/// 页头下方的分段进度条：已走过 / 当前 段用主色，未到的段用轮廓色。
/// 每段等宽，段数 = 步骤数——勾选变化让步骤增减时条也跟着重排。
class OnboardingProgressBar extends StatelessWidget {
  const OnboardingProgressBar({
    required this.current,
    required this.total,
    super.key,
  });

  /// 当前步骤下标（0-based）。
  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    final FushiDesignTokens tokens = FushiDesignTokens.of(context);
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Semantics(
      label: '${current + 1} / $total',
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          tokens.spacing.page,
          0,
          tokens.spacing.page,
          tokens.spacing.gap,
        ),
        child: Row(
          children: <Widget>[
            for (int i = 0; i < total; i++)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: tokens.spacing.gap / 4,
                  ),
                  child: AnimatedContainer(
                    duration: fushiMd3StateDuration,
                    curve: fushiMd3StateCurve,
                    height: 4,
                    decoration: BoxDecoration(
                      color:
                          i <= current ? colors.primary : colors.outlineVariant,
                      borderRadius: tokens.radii.chipRadius,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 每一步开头的 hero：圆底图标 + 标题 + 一句说明，左对齐。
class OnboardingStepHero extends StatelessWidget {
  const OnboardingStepHero({
    required this.icon,
    required this.title,
    required this.body,
    super.key,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final FushiDesignTokens tokens = FushiDesignTokens.of(context);
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: colors.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 28, color: colors.onPrimaryContainer),
        ),
        SizedBox(width: tokens.spacing.card),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(title, style: theme.textTheme.headlineSmall),
              SizedBox(height: tokens.spacing.gap / 2),
              Text(
                body,
                style: theme.textTheme.bodyMedium!.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
