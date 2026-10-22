import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:fushi/pages.dart';
import 'package:fushi/src/models/app_model.dart';
import 'package:fushi/src/models/kitapsen_edition.dart';
import 'package:fushi/src/onboarding/recommended_pack_discard.dart';
import 'package:fushi/src/onboarding/recommended_pack_download_row.dart';
import 'package:fushi/src/onboarding/recommended_pack_import.dart';
import 'package:fushi/src/settings/settings_actions.dart';
import 'package:fushi/src/settings/settings_context.dart';
import 'package:fushi/src/settings/settings_destination.dart';
import 'package:fushi/src/diagnostics/video_diag_export.dart';
import 'package:fushi/src/diagnostics/video_diag_log.dart';
import 'package:fushi/src/stats/study_diag_export.dart';
import 'package:fushi/src/sync/sync_http.dart';
import 'package:fushi/src/updates/app_update_check.dart';
import 'package:fushi/src/updates/update_feed_service.dart';
import 'package:fushi_engine/updates/update_feed_kind.dart';
import 'package:fushi/src/utils/misc/build_version.dart';
import 'package:fushi/src/utils/misc/crash_dump_locator.dart';
import 'package:fushi/src/utils/misc/log_exporter.dart';
import 'package:fushi/src/utils/misc/platform_updater.dart';
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
              resetSyncHttpClient();
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
              // 云同步的共享 client 在首次使用时就把代理解析结果固化进 findProxy 了，
              // 不丢弃它，用户改完代理仍走旧出口——那等于这条设置对同步不生效
              // （BUG-1348）。更新检查每次新建 client，不受影响。
              resetSyncHttpClient();
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
              resetSyncHttpClient();
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
              resetSyncHttpClient();
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
          // TODO-607 P0-3：崩溃转储（native minidump）。仅 Windows 显示——native
          // 端只在 Windows runner 经 SetUnhandledExceptionFilter 写 .dmp，移动端无此
          // 机制（仿 wgc_capture_log 的 isWindows 门控）。让纯 native 闪退（嵌套查词
          // 把进程带崩等，错误日志里看不到）有可上传的二进制证据。
          if (Platform.isWindows)
            SettingsNavigationItem(
              id: 'diagnostics.crash_dumps',
              // 同上走 titleBuilder——这一行的计数还要同步扫目录，构造期算等于每次
              // setState 都做一次磁盘 IO。
              title: t.crash_dump_label(n: 0),
              titleBuilder: (_) => t.crash_dump_label(
                n: CrashDumpLocator.listCurrentPlatformDumps().length,
              ),
              icon: Icons.bug_report_outlined,
              builder: (_) => const CrashDumpPage(),
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

/// 设置 › 诊断 › 导出统计诊断日志（正文见 [buildStudyDiagExport]）。
Future<void> _exportStudyDiagLog(SettingsContext settingsContext) async {
  final AppModel appModel = settingsContext.appModel;
  final String log = await buildStudyDiagExport(
    appModel.database,
    appVersion: resolveCurrentAppVersion(appModel.packageInfo.version),
    readingIdleTimeoutMinutes: appModel.readingIdleTimeoutMinutes,
    statDayResetHour: appModel.statDayResetHour,
  );
  if (!settingsContext.context.mounted) return;
  await saveLogToFile(
    context: settingsContext.context,
    log: log,
    fileName: 'fushi_study_diag_log.txt',
    subject: t.study_diag_share_subject,
  );
}

/// 设置 › 诊断 › 导出视频诊断日志（正文见 [buildVideoDiagExportFromDisk]）。
/// 三段：头信息（含小内存模式 / 热槽状态）+ 统一时间轴 + libmpv 原始日志尾部。
Future<void> _exportVideoDiagLog(SettingsContext settingsContext) async {
  final AppModel appModel = settingsContext.appModel;
  final String log = await buildVideoDiagExportFromDisk(
    appVersion: resolveCurrentAppVersion(appModel.packageInfo.version),
    lowMemoryMode: appModel.lowMemoryMode,
  );
  if (!settingsContext.context.mounted) return;
  await saveLogToFile(
    context: settingsContext.context,
    log: log,
    fileName: 'fushi_video_diag_log.txt',
    subject: t.video_diag_share_subject,
  );
}

/// 手动「立即检查更新」：编排在 [checkAppUpdateNow]（与更新中心的 app 新版本
/// 条目共用同一条应用内下载安装链路）。
Future<void> _checkUpdateNow(SettingsContext settingsContext) =>
    checkAppUpdateNow(settingsContext.context, settingsContext.appModel);

String _selectedUpdateChannel(SettingsContext settingsContext) {
  if (settingsContext.appModel.updateDebugChannel) return 'debug';
  if (settingsContext.appModel.updateBetaChannel) return 'beta';
  return 'stable';
}

/// TMDB 官方标识（`Primary short (blue)`）在包内的路径。
///
/// 这张 PNG 由 themoviedb.org/about/logos-attribution 下发的**矢量原图**栅格化而来；
/// 原图 `assets/attribution/tmdb/blue_square_1.svg` 逐字节入库存证（sha256 即 TMDB
/// 直链文件名里那串摘要）。之所以不直接渲染 SVG：Flutter 唯一现实的 SVG 方案
/// `flutter_svg` 不支持 CSS，而 TMDB 原图把唯一填充写在 `<style>` 类里，解析后渐变
/// 全丢、整个标识渲染成纯黑——那本身就是「改色」。栅格化只做尺寸映射，未改色 /
/// 改比例 / 翻转 / 旋转 / 裁剪。来源、哈希、配方与守卫见同目录 README.md 与
/// `test/settings/tmdb_attribution_test.dart`。
@visibleForTesting
const String kTmdbLogoAsset = 'assets/attribution/tmdb/logo_tmdb.png';

/// logo 展示高度（dp）；宽度见 [_kTmdbLogoWidth]（24 × 190.24/81.52 ≈ 56.0）。
///
/// 条款要求展示 TMDB 标识，但它**不得比本应用自己的标识更显眼**。这条义务的实测
/// 依据（数字均可按下列位置复核）：
///
/// - 同一行左侧的图标徽标是 30dp：`_SettingsIcon` 在 Material 下走
///   `FushiBadge(size: 18, padding: EdgeInsets.all(6))`，18+6*2 = 30
///   （`utils/components/settings_shared.dart`）。24dp 与之同量级。
/// - 应用自身图标在 Flutter widget 树里有两个真渲染点。设置 › 外观 › 应用图标的
///   预设瓦片（`miscellaneous_settings_page.dart` 的 `_AppIconTile`）中，
///   `SizedBox.square(72)` 扣掉 `FushiCard` 描边的 1dp 内缩与 `gap/2 = 4` 的
///   双侧 padding，图片实得 62×62dp；宽屏主导航 rail 的品牌位直接显示经过圆角
///   裁切的 64×64dp 图片。取较大的 64dp 作比较，TMDB 标识 24dp 高 = 其 37.5%；
///   面积 24×56.0 ≈ 1344dp²，是其 4096dp² 的 32.8%——
///   两个维度都更小，满足条款的 "less prominent"。
/// - 除上述预设瓦片和宽屏 rail 外应用图标不再重复绘制：首页 dashboard、
///   loading/splash 都不传图；窄屏底栏也没有品牌位。
///
/// 所以旧注释那句「远小于应用自身 logo 的**任何**展示尺寸」结论对、依据错：可比
/// 的最大展示尺寸现在是 64×64dp。调整本值前请重跑上述核对——这段是「不得更显眼」
/// 的唯一书面依据，守卫只能钉住上限（≤32dp），钉不住依据本身。
const double _kTmdbLogoHeight = 24;

/// 原图 viewBox 是 `0 0 190.24 81.52`；宽度按该比例算死，配合 [BoxFit.contain]
/// 保证任何主题/文字缩放下都不会被拉伸变形（改比例同样是条款禁止项）。
const double _kTmdbLogoWidth = _kTmdbLogoHeight * 190.24 / 81.52;

/// TMDB 署名行：官方标识 + 条款原句免责声明，点击跳官网。
///
/// 用 [SettingsCustomItem] 而不是 [SettingsActionItem]，只因为 schema 的 `icon`
/// 槽是 `IconData`、放不下一张图；行本体仍是共享的 [AdaptiveSettingsRow]，
/// 焦点/密度/折叠行为与其它设置行完全一致。
Widget _buildTmdbAttributionRow(SettingsContext settingsContext) {
  return AdaptiveSettingsRow(
    title: 'TMDB',
    subtitle: t.about_tmdb_attribution,
    icon: Icons.movie_outlined,
    showIcon: true,
    trailing: SizedBox(
      height: _kTmdbLogoHeight,
      width: _kTmdbLogoWidth,
      child: Image.asset(
        kTmdbLogoAsset,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        semanticLabel: 'TMDB',
      ),
    ),
    onTap: () async => launchUrl(
      Uri.parse('https://www.themoviedb.org/'),
      mode: LaunchMode.externalApplication,
    ),
  );
}

Widget _buildRecommendedPackDownloadRow(SettingsContext settingsContext) {
  final AppModel appModel = settingsContext.appModel;
  return RecommendedPackDownloadRow(
    controller: appModel.recommendedPackDownloadController,
    // 导入编排是库级共享的（[importDownloadedRecommendedPack]）：设置这一行、
    // 新手引导那一步、首页迷你条三个发起点同一个真相源。
    onImport: () => unawaited(importDownloadedRecommendedPack(appModel)),
    // 放弃编排同样库级共享（[confirmAndDiscardRecommendedPack]）：确认框漏在任何
    // 一个发起点上，那一处就成了不带确认直接删几 GB 的按钮。
    onDiscard: () => unawaited(
      confirmAndDiscardRecommendedPack(
        settingsContext.context,
        appModel.recommendedPackDownloadController,
      ),
    ),
  );
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
