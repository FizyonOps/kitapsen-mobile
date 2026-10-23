import 'dart:async';

import 'package:flutter/material.dart';
import 'package:fushi/pages.dart';
import 'package:fushi/src/models/kitapsen_edition.dart';
import 'package:fushi/src/settings/settings_actions.dart';
import 'package:fushi/src/settings/settings_context.dart';
import 'package:fushi/src/settings/settings_destination.dart';
import 'package:fushi/src/utils/misc/build_version.dart';
import 'package:fushi/utils.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

SettingsDestination buildSystemDestination() {
  return SettingsDestination(
    id: SettingsDestinationId.system,
    title: t.settings_destination_system_about,
    // Kitapsen has no in-app updater (the stores update the app).
    summary: t.kitapsen_settings_destination_system_summary,
    icon: Icons.settings_suggest_outlined,
    sections: <SettingsSection>[
      SettingsSection(
        id: 'system.section.general',
        presentation: SettingsSectionPresentation.alwaysExpanded,
        // 文案统一（阶段 F/G）：本 section 原标题与 destination 标题同为「系统」，
        // 搜索面包屑显示「系统 › 系统」语义重复。改为「通用」——本区聚的是版本 /
        // 内存 / 手柄导航 / 快捷键 / GitHub 这类通用应用项。框架层另有面包屑去重
        // （settingsSearchBreadcrumb），双保险消灭整类重复。
        title: t.settings_section_general,
        items: <SettingsItem>[
          // 新手引导重开入口（首启由 HomePage 自动弹一次）；引导本身只跳转
          // 既有配置页面，不写任何功能开关。
          SettingsNavigationItem(
            id: 'system.onboarding_wizard',
            title: t.onboarding_reopen,
            icon: Icons.flag_outlined,
            onTap: (SettingsContext settingsContext) async {
              await pushSettingsPage(
                settingsContext,
                (_) => const OnboardingWizardPage(),
              );
            },
          ),
          SettingsSwitchItem(
            id: 'system.low_memory_mode',
            title: t.low_memory_mode,
            subtitle: t.low_memory_mode_hint,
            icon: Icons.memory_outlined,
            value: (SettingsContext settingsContext) =>
                settingsContext.appModel.lowMemoryMode,
            onChanged: (SettingsContext settingsContext, bool value) async {
              await settingsContext.appModel.setLowMemoryMode(value);
              settingsContext.refresh();
            },
          ),
          SettingsCustomItem(
            id: 'system.app_version',
            icon: Icons.info_outline,
            builder: _buildRuntimeAppVersionRow,
          ),
        ],
      ),
      // Kitapsen › About: privacy policy, support, GPL source + upstream credit
      // and the open-source licenses. Deliberately no storefront link.
      SettingsSection(
        id: 'system.section.kitapsen_about',
        presentation: SettingsSectionPresentation.alwaysExpanded,
        title: t.kitapsen_about_section,
        visible: (_) => true,
        items: <SettingsItem>[
          SettingsActionItem(
            id: 'system.kitapsen_privacy_policy',
            title: t.kitapsen_about_privacy_policy,
            icon: Icons.privacy_tip_outlined,
            onTap: (_) => _openExternal(Uri.parse(kKitapsenPrivacyPolicyUrl)),
          ),
          SettingsActionItem(
            id: 'system.kitapsen_support',
            title: t.kitapsen_about_support,
            subtitle: kKitapsenSupportEmail,
            icon: Icons.mail_outline,
            onTap: (_) => _openExternal(
              Uri(scheme: 'mailto', path: kKitapsenSupportEmail),
            ),
          ),
          SettingsActionItem(
            id: 'system.kitapsen_source_code',
            title: t.kitapsen_about_source_code,
            subtitle: t.kitapsen_about_based_on_fushi,
            icon: Icons.code_outlined,
            onTap: (_) => _openExternal(Uri.parse(kKitapsenSourceUrl)),
          ),
          SettingsActionItem(
            id: 'system.kitapsen_licenses',
            title: t.kitapsen_about_licenses,
            icon: Icons.description_outlined,
            onTap: (SettingsContext c) {
              showLicensePage(
                context: c.context,
                applicationName: 'Kitapsen',
                applicationVersion: c.appModel.packageInfo.version,
                applicationLegalese:
                    '${t.kitapsen_about_based_on_fushi}\n$kFushiUpstreamUrl',
              );
            },
          ),
        ],
      ),
      SettingsSection(
        id: 'system.section.network',
        presentation: SettingsSectionPresentation.collapsed,
        title: t.section_network,
        items: <SettingsItem>[
          // 全应用唯一的代理项：自动 = env > 系统代理 > 直连；直连 = 明确禁用；
          // 手动 = 下方地址与可选认证。持久化地址键 `update_custom_proxy` 是历史遗留，
          // 冻结不改；旧安装若已有地址且还没有模式键，会自动投影成手动模式。
          SettingsSegmentedItem<String>(
            id: 'system.network_proxy_mode',
            title: t.network_proxy_mode_label,
            icon: Icons.dns_outlined,
            options: <SettingsSegmentOption<String>>[
              SettingsSegmentOption<String>(
                value: kProxyModeAuto,
                label: t.network_proxy_mode_auto,
                icon: Icons.sync_outlined,
                tooltip: t.network_proxy_mode_auto_hint,
              ),
              SettingsSegmentOption<String>(
                value: kProxyModeDirect,
                label: t.network_proxy_mode_direct,
                icon: Icons.link_off_outlined,
                tooltip: t.network_proxy_mode_direct_hint,
              ),
              SettingsSegmentOption<String>(
                value: kProxyModeManual,
                label: t.network_proxy_mode_manual,
                icon: Icons.tune_outlined,
                tooltip: t.network_proxy_mode_manual_hint,
              ),
            ],
            selected: (SettingsContext c) => c.appModel.networkProxyMode,
            onChanged: (SettingsContext c, String value) async {
              await c.appModel.setNetworkProxyMode(value);
              c.refresh();
            },
          ),
          SettingsTextItem(
            id: 'system.network_proxy',
            title: t.network_proxy_label,
            subtitle: t.network_proxy_address_hint,
            icon: Icons.dns_outlined,
            placeholder: t.network_proxy_hint,
            keyboardType: TextInputType.url,
            visible: (SettingsContext c) =>
                c.appModel.networkProxyMode == kProxyModeManual,
            value: (SettingsContext settingsContext) =>
                settingsContext.appModel.updateCustomProxy,
            onChanged: (SettingsContext settingsContext, String value) async {
              final String trimmed = value.trim();
              await settingsContext.appModel.setUpdateCustomProxy(trimmed);
              // 非空且无法归一成合法 host:port → 提示（仍保存原串，运行时忽略）。
              if (trimmed.isNotEmpty &&
                  normalizeUserProxyHostPort(trimmed) == null) {
                final BuildContext ctx = settingsContext.context;
                if (!ctx.mounted) return;
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(content: Text(t.network_proxy_invalid)),
                );
              }
            },
          ),
          SettingsTextItem(
            id: 'system.network_proxy_username',
            title: t.network_proxy_username,
            // 认证的作用面必须说清：凭据是 dart:io `HttpClient.authenticateProxy`
            // 的 407 应答，只覆盖 app 自己发的 HTTP 出站。内置 torrent 引擎的 C ABI
            // （`ht_apply_proxy`）只接 type/host/port，libtorrent 的
            // `settings_pack::proxy_username/password` 根本没被导出，凭据到不了
            // P2P 那一侧；不写出来用户会以为「开了 P2P 走代理」就连上了。
            // Kitapsen: the hint is about the torrent engine, which this
            // edition does not have.
            subtitle:
                null,
            icon: Icons.person_outline,
            visible: (SettingsContext c) =>
                c.appModel.networkProxyMode == kProxyModeManual,
            value: (SettingsContext c) => c.appModel.networkProxyUsername,
            onChanged: (SettingsContext c, String value) async {
              await c.appModel.setNetworkProxyUsername(value.trim());
            },
          ),
          SettingsTextItem(
            id: 'system.network_proxy_password',
            title: t.network_proxy_password,
            icon: Icons.password_outlined,
            secret: true,
            visible: (SettingsContext c) =>
                c.appModel.networkProxyMode == kProxyModeManual,
            value: (SettingsContext c) => c.appModel.networkProxyPassword,
            onChanged: (SettingsContext c, String value) async {
              await c.appModel.setNetworkProxyPassword(value);
            },
          ),
        ],
      ),
      SettingsSection(
        id: 'system.section.diagnostics',
        presentation: SettingsSectionPresentation.collapsed,
        title: t.settings_destination_diagnostics,
        items: <SettingsItem>[
          // 标题里的实时条数走 titleBuilder（渲染时求值）。写成构造期插值会把整棵
          // schema 变成「每次 setState 都得重建才能刷新计数」的状态载体——那正是
          // 全量重建的成因之一（见 settings_destination.dart 的 titleBuilder 注释）。
          SettingsNavigationItem(
            id: 'diagnostics.error_log',
            title: t.error_log_label(n: 0),
            titleBuilder: (_) =>
                t.error_log_label(n: ErrorLogService.instance.entries.length),
            icon: Icons.report_problem_outlined,
            builder: (_) => const ErrorLogPage(),
          ),
          SettingsSwitchItem(
            id: 'diagnostics.debug_log_enabled',
            title: t.debug_log_toggle,
            icon: Icons.rule_outlined,
            value: (_) => DebugLogService.instance.enabled,
            onChanged: (SettingsContext settingsContext, bool value) async {
              await DebugLogService.instance.setEnabled(value);
              settingsContext.refresh();
            },
          ),
          SettingsNavigationItem(
            id: 'diagnostics.debug_log',
            title: t.debug_log_title(count: 0),
            titleBuilder: (_) => t.debug_log_title(
              count: DebugLogService.instance.entries.length,
            ),
            icon: Icons.terminal_outlined,
            visible: (_) =>
                DebugLogService.instance.enabled ||
                DebugLogService.instance.entries.isNotEmpty,
            builder: (_) => const DebugLogPage(),
          ),
        ],
      ),
    ],
  );
}

/// Opens [uri] outside the app; a missing handler (no mail app / browser) is
/// logged, never thrown into the settings tap handler.
Future<void> _openExternal(Uri uri) async {
  try {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } on Object catch (e, stack) {
    ErrorLogService.instance.log('SettingsSystem.openExternal', e, stack);
  }
}

Widget _buildRuntimeAppVersionRow(SettingsContext settingsContext) {
  final packageInfo = settingsContext.appModel.packageInfo;
  return AdaptiveSettingsRow(
    title: t.app_version,
    subtitle: formatAppVersionDisplay(
      packageInfo,
      runningCodeVersion: fushiRunningCodeVersion,
    ),
    icon: Icons.info_outline,
    showIcon: true,
  );
}

/// 版本展示文案。versionName 是 semver（含 `-debug.5613` 等预发布段），
/// buildNumber 是 Android versionCode（如 `1000561300`），两者语义不同：
/// 绝不能用 semver 的 `+` build-metadata 把 versionCode 拼进 versionName，
/// 否则会渲染出畸形的 `0.11.1-debug.5613+1000561300`。用括号并列展示。
///
/// [runningCodeVersion] 是编译进 `app.so` 的构建版本（见 `build_version.dart`），
/// [PackageInfo.version] 则来自 exe / Info.plist / manifest 的版本资源。两者是
/// **两个文件**：Inno 的回滚保留被覆盖的文件、只删本次新建的文件，所以「新 exe +
/// 旧 app.so」这种半更新态完全可能落地（BUG-1786 现场），而版本资源照样报新版本。
///
/// 不一致时并排显示 exe 那个值——关于页是用户唯一能自查这件事的地方。
@visibleForTesting
String formatAppVersionDisplay(
  PackageInfo packageInfo, {
  String? runningCodeVersion,
}) {
  final String executableVersion = packageInfo.version;
  final String shown = runningCodeVersion ?? executableVersion;
  final String display = '$shown (${packageInfo.buildNumber})';
  if (runningCodeVersion == null) return display;
  if (_isSameBuildVersion(runningCodeVersion, executableVersion)) {
    return display;
  }
  return '$display ≠ exe $executableVersion';
}

/// [codeVersion]（`app.so` 里的构建版本）与 [executableVersion]（exe / Info.plist /
/// manifest 的版本资源）是否来自同一次构建。
///
/// **不对称**：原生版本资源是代码版本的一种**有损渲染**——在版本字段只收数字段的
/// 平台上（Apple：`CFBundleShortVersionString` 至多三段非负整数），`release-desktop.yml`
/// 给 `--build-name` 传的是剥掉预发布段的 `apple_build_version_name`，而
/// `--dart-define=FUSHI_BUILD_VERSION` 注入的仍是完整版本名（守卫
/// `test/build/build_version_define_guard_test.dart` 同时钉死这两条）。所以两侧
/// **故意解耦**：iOS 上同一次构建就是 `2.2.1-beta.30` 的代码配 `2.2.1` 的 Info.plist。
///
/// 判据因此是「逐字相等 **或** 版本资源等于代码版本剥掉预发布段后的值」：
///
/// - Windows 半更新态 exe `2.2.1-debug.12216` / 代码 `2.2.1-debug.12215`：剥段得
///   `2.2.1` ≠ exe ⇒ 照常告警（BUG-1786 现场，基版本相同、只差序号一位，只比基
///   版本的实现会对唯一需要它的输入闭眼）。
/// - Apple 预发布包 exe `2.2.1` / 代码 `2.2.1-beta.30`：剥段后相等 ⇒ 静默。
///
/// **已知残留假阴性**：Windows「正式版 exe `2.2.1` + 同 base 预发布 app.so」的跨通道
/// 半更新态会被这条判据静默。这是有意的取舍——它与 Apple 的正常态在字符串层面完全
/// 同形，分开只能靠平台特例分支；换来的是 Apple 端不再常驻一个恒为真的「你的安装
/// 坏了」告警。真出这种跨通道半更新态时，更新检查侧（[resolveCurrentAppVersion] 吃
/// 代码版本）仍会照常提示新版本，用户不会被困住。
bool _isSameBuildVersion(String codeVersion, String executableVersion) {
  final String code = _normalizedVersion(codeVersion);
  final String executable = _normalizedVersion(executableVersion);
  if (code == executable) return true;
  return executable == _withoutPrerelease(code);
}

String _normalizedVersion(String version) =>
    version.trim().replaceFirst(RegExp('^[vV]'), '').split('+').first;

/// 剥掉 semver 预发布段（`2.2.1-beta.30` → `2.2.1`）——原生版本字段只收数字段的
/// 平台上，版本资源里落地的就是这个值。
String _withoutPrerelease(String normalizedVersion) =>
    normalizedVersion.split('-').first;
