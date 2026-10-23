import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:fushi/src/pages/implementations/kitapsen_account_settings_section.dart';
import 'package:fushi/pages.dart';
import 'package:fushi/src/models/module_id.dart';
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
/// 步骤序列由纯函数 [onboardingStepSequence] 生成：欢迎（界面语言/主题）→ 功能
/// 选择（库页模块显隐 + 要配置的能力）→ 资源准备（推荐包 / 自备资源可独立多选）→
/// 按勾选出现的配置步骤（含字体）→ 功能操作教程（点击查词 + 平台支持时的全局
/// 查词 + Anki 真正就绪后的第一张卡片）→ 完成。
/// 配置步骤只做说明 + 跳转到**既有**配置入口（推荐包走备份导入共享编排
/// [runBackupImportFlowForFile]；Anki/备份/互联推各自设置详情页），不复制配置
/// UI——配置能力的单一真相源仍在各自页面。向导的持久化副作用只有两个：离开功能
/// 选择步骤时写 `module_*_enabled` 显隐偏好；完成/跳过时把 `onboarding_completed`
/// 置回 true。
///
/// 页面骨架：页头下方一条分段进度条（[OnboardingProgressBar]）；每步以左对齐的
/// [OnboardingStepHero]（图标 + 标题 + 一句话）开头；动作走 [OnboardingActionList]
/// ——必做/推荐的动作直接摊开，可选动作收进「其他方式」折叠组，避免一屏五个入口。
class OnboardingWizardPage extends BasePage {
  const OnboardingWizardPage({this.tutorialOnly = false, super.key});

  final bool tutorialOnly;

  @override
  BasePageState<OnboardingWizardPage> createState() =>
      _OnboardingWizardPageState();
}

class _OnboardingWizardPageState extends BasePageState<OnboardingWizardPage>
    with SettingsContextHost<OnboardingWizardPage> {
  /// 已勾选的功能。模块项在 initState 从当前偏好播种（重开向导时反映现状）；
  /// 能力项默认勾推荐包 + Anki 制卡 + 字体（查词→制卡是本应用的最大公约数，
  /// 字体是几乎所有人都会碰的一步；备份/互联按需自选）。
  final Set<OnboardingFeature> _selected =
      Set<OnboardingFeature>.of(kOnboardingDefaultCapabilities);

  int _stepIndex = 0;
  final OnboardingTutorialProgress _tutorialProgress =
      OnboardingTutorialProgress();
  bool _completing = false;

  // ── 推荐包下载 ────────────────────────────────────────────────────

  List<OnboardingStepId> get _steps => kKitapsenOnboardingSteps;

  /// 本平台上这个模块**是否存在**（与用户意愿无关）。平台判据只认
  /// [ModuleId.availableOn] 这一处，向导不再自己写 `Platform.isWindows`。
  bool _moduleAvailable(ModuleId module) => module.availableOn(
    isWindows: false,
    isDesktop: false,
    isIOS: Platform.isIOS,
    isAndroid: Platform.isAndroid,
  );

  @override
  void initState() {
    super.initState();
    if (widget.tutorialOnly) return;
    // 模块方格的初值 = 用户此刻的意愿（pref 真值，缺省全开）。遍历
    // [ModuleId.values] 而不是逐个 if：此前这里只覆盖 5 个模块，下载/查词等根本
    // 没被读也没被写，用户在引导里「只留阅读」压根做不到。
    for (final ModuleId module in ModuleId.values) {
      if (!_moduleAvailable(module)) continue;
      if (appModelNoUpdate.moduleEnabled(module)) {
        _selected.add(onboardingFeatureOfModule(module));
      }
    }
  }

  // dispose 里**没有**取消下载：BUG-2097 的根因就是这里曾经有一句
  // `_packCancelToken?.cancel()`，于是走完向导 = 9.5 GB 的下载被静默掐断。
  // 进度/取消/导入现在都由 [RecommendedPackDownloadController] 持有。

  /// 上一次 [_applyModuleSelection] 的在途写入。向导是 fullscreenDialog、完全盖住
  /// HomePage，所以模块开关在向导期间怎么改都不会被看见；**唯独关掉向导的那一刻**
  /// 必须等写入落地——否则 pop 先发生、写入后到，用户会先看到旧的整排底栏 tab
  /// 闪一下再被收掉（「关光只留阅读」这条路径最短：功能页取消勾选 → 下一步就是
  /// 完成）。
  Future<void>? _moduleSelectionWrite;

  Future<void> _complete({bool finished = false}) async {
    if (_completing) return;
    _completing = true;
    try {
      // 先等模块勾选落盘再 pop，理由见 [_moduleSelectionWrite]。
      await _moduleSelectionWrite;
      if (!widget.tutorialOnly) {
        await appModelNoUpdate.setOnboardingCompleted(value: true);
      }
    } finally {
      _completing = false;
    }
    if (!mounted) return;
    await Navigator.of(context).maybePop();
  }

  /// 离开功能选择步骤时，把模块勾选写进 `module_*_enabled` 偏好（只写有变化的）。
  ///
  /// 平台上不提供勾选的模块**不写**，保留用户意愿：它的方格根本没渲染，
  /// `_selected` 里恒为未勾选，照写会被误当成「用户把它关了」。
  Future<void> _applyModuleSelection() async {
    for (final ModuleId module in ModuleId.values) {
      if (!_moduleAvailable(module)) continue;
      final bool wanted = _selected.contains(onboardingFeatureOfModule(module));
      if (appModel.moduleEnabled(module) == wanted) continue;
      await appModel.setModuleEnabled(module, wanted);
    }
  }

  void _goNext() => unawaited(_goNextAsync());

  /// BUG-2380：离开 Anki 那一步之前先判一次「这套配置真能制出卡吗」，判不过就地
  /// 劝建并选用 Lapis。放在推进**之前**而不是之后——用户按下一步的那一刻还看得见
  /// Anki 这一页的上下文，翻页之后再弹就成了没头没尾的打断。
  ///
  /// 弹窗不拦路：用户选「保持当前设置」照样进下一步（引导本来就可跳过，这里不该
  /// 变成硬门）。但建成了的话 `_steps` 会因为 Anki 变 ready 而多出一步，所以 await
  /// 之后必须重新取一次序列，不能沿用进函数时那份。
  Future<void> _goNextAsync() async {
    final List<OnboardingStepId> steps = _steps;
    if (steps[_stepIndex] == OnboardingStepId.features) {
      // 不阻塞翻页（写 11 个 pref 要走 DB），但把 future 留给 [_complete] 等。
      _moduleSelectionWrite = _applyModuleSelection();
      unawaited(_moduleSelectionWrite);
    }
    if (_stepIndex >= steps.length - 1) {
      unawaited(_complete(finished: true));
      return;
    }
    _tutorialProgress.completeStep(steps[_stepIndex]);
    setState(() => _stepIndex += 1);
  }

  void _goBack() {
    if (_stepIndex == 0) return;
    setState(() => _stepIndex -= 1);
  }

  // ── 推荐包 ────────────────────────────────────────────────────────

  // ── Anki ──────────────────────────────────────────────────────────

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
