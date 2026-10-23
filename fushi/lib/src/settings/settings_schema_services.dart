import 'package:flutter/material.dart';
import 'package:fushi/src/pages/implementations/kitapsen_account_settings_section.dart';
import 'package:fushi/src/settings/settings_context.dart';
import 'package:fushi/src/settings/settings_destination.dart';
import 'package:fushi/utils.dart';

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
