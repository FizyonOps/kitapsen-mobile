import 'package:flutter/material.dart';
import 'package:fushi_engine/media/torrent/torznab_client.dart';
import 'package:fushi/src/models/kitapsen_edition.dart';
import 'package:fushi/src/media/video/dandanplay_client.dart';
import 'package:fushi_engine/media/video/metadata/video_metadata_languages.dart';
import 'package:fushi_engine/media/video/metadata/video_source_scrape_config.dart';
import 'package:fushi/src/media/video/scraper/tmdb_default_key.dart';
import 'package:fushi/src/media/video/video_settings_actions.dart';
import 'package:fushi/src/pages/implementations/discovery_source_settings_section.dart';
import 'package:fushi/src/pages/implementations/alist_site_settings_section.dart';
import 'package:fushi/src/pages/implementations/kitapsen_account_settings_section.dart';
import 'package:fushi/src/pages/implementations/opds_server_settings_section.dart';
import 'package:fushi/src/pages/implementations/video_external_provider_settings_section.dart';
import 'package:fushi/src/models/module_registry.dart';
import 'package:fushi/src/models/store_compliance.dart';
import 'package:fushi/src/settings/settings_actions.dart';
import 'package:fushi/src/settings/settings_context.dart';
import 'package:fushi/src/settings/settings_destination.dart';
import 'package:fushi/src/settings/settings_detail_page.dart';
import 'package:fushi/src/sync/jellyfin_settings_widget.dart';
import 'package:fushi/src/sync/plex_settings_widget.dart';
import 'package:fushi/src/sync/plex_video_client.dart' show PlexServerConfig;
import 'package:fushi/src/media/video/media_server/media_server_config.dart';
import 'package:fushi/src/sync/sync_repository.dart';
import 'package:fushi/src/sync/jellyfin_video_client.dart'
    show JellyfinServerConfig;
import 'package:fushi/utils.dart';
import 'package:fushi_engine/media/video/subtitle/open_subtitles_client.dart';

/// 「在线服务」一级设置分类：第三方 API / 索引器 / 媒体服务器的凭据与端点。
///
/// 此前这些东西按「服务于哪个媒介」散在两页：字幕两家（Jimaku / OpenSubtitles）
/// 在视频页与下载页各挂一份同一组件，刮削三家（MAL / TMDB / AniDB 文件识别 / Jellyfin）在视频，
/// 索引器（内置来源 / Torznab / 发现来源）在下载，Dandanplay 服务器在视频·弹幕。
/// 用户在视频页配完 Jimaku 不知道下载页还有 Torznab；BUG-1712 的双挂载修法是把
/// 症状固化成结构。互联分区那条「同步主机服务配置」开关早已把这组服务当成一个
/// 整体下发（interconnect_service_config.dart），设置页却没有对应的编辑面。
///
/// 成员判据：**第三方**在线服务的凭据/端点/开关。不归此的：qBittorrent（本机下载
/// 后端）、云盘备份后端（与同步模式选择器绑死）、AnkiConnect / Yomitan（各自域的
/// 核心集成）。持久化键一个不动——只是编辑面搬家，零数据迁移。
///
/// 原分区各留一条 [buildOpenServicesItem] 跳转行，用户在字幕/下载语境里仍一步可达。
SettingsDestination buildServicesDestination() {
  // Kitapsen: the only online service is the store account, so the category is
  // the account page itself (one tap from Settings, no third-party services).
  return SettingsDestination(
    id: SettingsDestinationId.services,
    title: t.kitapsen_account_title,
    summary: t.kitapsen_account_summary,
    icon: Icons.account_circle_outlined,
    sections: const <SettingsSection>[],
    body: (SettingsContext c) => const KitapsenAccountSettingsSection(),
  );
}

SettingsNavigationItem _externalServicePage({
  required String id,
  required String title,
  required VideoExternalProviderScope scope,
  required SettingsSubtitleBuilder status,
  List<SettingsBodySearchEntry> entries = const <SettingsBodySearchEntry>[],
}) => _servicePage(
  id: id,
  title: title,
  status: status,
  entries: entries,
  body: (SettingsContext c) =>
      VideoExternalProviderSettingsSection(scope: scope),
);

SettingsNavigationItem _servicePage({
  required String id,
  required String title,
  required SettingsSubtitleBuilder status,
  required SettingsItemBuilder body,
  List<SettingsBodySearchEntry> entries = const <SettingsBodySearchEntry>[],
}) => SettingsNavigationItem(
  id: id,
  title: title,
  subtitleBuilder: status,
  child: () => SettingsDestination(
    id: SettingsDestinationId.services,
    title: title,
    icon: Icons.cloud_outlined,
    sections: const <SettingsSection>[],
    body: body,
    bodySearchEntries: entries,
  ),
);

/// 从别的分区跳到「在线服务」的导航行（视频·字幕、下载各放一条）。
///
/// 迁走的条目不在原地留副本——那正是 BUG-1712 双挂载的老路；留一条跳转让原语境
/// 里的用户一步到达。推整页详情路由而非切主从选中态：主从壳没有对外的选分区
/// API，而 pushed 详情页在宽/窄两种布局下都成立（搜索结果在窄屏也是这样跳的）。
SettingsNavigationItem buildOpenServicesItem(String id) {
  return SettingsNavigationItem(
    id: id,
    title: t.settings_destination_services,
    subtitle: t.settings_services_link_subtitle,
    icon: Icons.cloud_outlined,
    showIcon: true,
    // 与它指向的分类同门控：services 模块关掉时整行不渲染。留着就是一条通往已关
    // 模块的暗门（宿主分类——视频 / 下载——可能仍开着，所以宿主的 destination 级
    // 门控盖不住这一行）。
    visible: (SettingsContext c) => isSettingsDestinationVisible(
      SettingsDestinationId.services,
      c.appModel.moduleVisibility,
    ),
    onTap: (SettingsContext settingsContext) async {
      await pushSettingsPage(
        settingsContext,
        (_) => SettingsDetailPage(destination: buildServicesDestination()),
      );
    },
  );
}

/// Reads saved authentication locally; a saved token is configuration, not proof
/// of a currently reachable server. Network validation remains in its real page.
class _JellyfinSettingsLink extends StatefulWidget {
  const _JellyfinSettingsLink({required this.settingsContext});
  final SettingsContext settingsContext;

  @override
  State<_JellyfinSettingsLink> createState() => _JellyfinSettingsLinkState();
}

class _JellyfinSettingsLinkState extends State<_JellyfinSettingsLink> {
  late Future<JellyfinServerConfig?> _config;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _config = SyncRepository(
      widget.settingsContext.appModel.database,
    ).getJellyfinServer();
  }

  Future<void> _open() async {
    // 必须走 `.subPage`：默认构造器按 id 回顶层 schema 找「最新声明」，而这页
    // 复用父分类 `services` 的 id，按 id 找回来的是整页「在线服务」（BUG-2485）。
    await pushSettingsPage(
      widget.settingsContext,
      (_) => SettingsDetailPage.subPage(
        () => SettingsDestination(
          id: SettingsDestinationId.services,
          title: 'Jellyfin · Emby',
          icon: Icons.cloud_outlined,
          sections: const <SettingsSection>[],
          body: (SettingsContext c) => JellyfinConfigWidget(settingsContext: c),
        ),
      ),
    );
    if (mounted) {
      setState(_load);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<JellyfinServerConfig?>(
    future: _config,
    builder:
        (BuildContext context, AsyncSnapshot<JellyfinServerConfig?> snapshot) =>
            AdaptiveSettingsNavigationRow(
              title: 'Jellyfin · Emby',
              subtitle: snapshot.connectionState != ConnectionState.done
                  ? t.jellyfin_settings_title
                  : snapshot.data == null
                  ? t.settings_service_not_configured
                  : t.settings_service_configured,
              onTap: _open,
            ),
  );
}

/// Plex 入口行：与 [_JellyfinSettingsLink] 同形，只读本地配置判「已配置」。
class _PlexSettingsLink extends StatefulWidget {
  const _PlexSettingsLink({required this.settingsContext});
  final SettingsContext settingsContext;

  @override
  State<_PlexSettingsLink> createState() => _PlexSettingsLinkState();
}

class _PlexSettingsLinkState extends State<_PlexSettingsLink> {
  late Future<bool> _configured;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _configured = SyncRepository(widget.settingsContext.appModel.database)
        .getMediaServers()
        .then(
          (List<MediaServerConfig> servers) =>
              servers.any((MediaServerConfig s) => s is PlexServerConfig),
        );
  }

  Future<void> _open() async {
    // 与 Jellyfin 入口同理必须走 `.subPage`（BUG-2485）。
    await pushSettingsPage(
      widget.settingsContext,
      (_) => SettingsDetailPage.subPage(
        () => SettingsDestination(
          id: SettingsDestinationId.services,
          title: 'Plex',
          icon: Icons.cloud_outlined,
          sections: const <SettingsSection>[],
          body: (SettingsContext c) => PlexConfigWidget(settingsContext: c),
        ),
      ),
    );
    if (mounted) {
      setState(_load);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<bool>(
    future: _configured,
    builder: (BuildContext context, AsyncSnapshot<bool> snapshot) =>
        AdaptiveSettingsNavigationRow(
          title: 'Plex',
          subtitle: snapshot.connectionState != ConnectionState.done
              ? t.video_library_media_servers
              : snapshot.data == true
              ? t.settings_service_configured
              : t.settings_service_not_configured,
          onTap: _open,
        ),
  );
}

/// AniDB HTTP 资料接口的静态状态：只看配置快照里的 **HTTP** 身份（与 UDP 分开，
/// BUG-2623）。运行期被 AniDB 拒绝（302 闩）/ 封禁不在这里体现。
String anidbHttpApiStatusLabel(VideoSourceScrapeGlobalConfig config) =>
    config.anidbHttpClientConfigured
    ? t.video_anidb_http_api_available(
        client: config.anidbHttpClientName,
        version: '${config.anidbHttpClientVersion}',
      )
    : t.video_anidb_http_api_unregistered;
