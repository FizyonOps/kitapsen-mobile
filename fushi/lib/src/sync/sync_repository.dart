import 'dart:convert';

import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:fushi/src/models/preferences_repository.dart'
    show kDownloadExecutionHostPrefKey, kGameStreamRemoteLaunchPrefKey;
import 'package:fushi/src/sync/sync_backend.dart';
import 'package:fushi_core/fushi_core.dart';
import 'package:fushi_engine/sync/sync_channel_scope.dart';
export 'package:fushi_engine/sync/sync_channel_scope.dart' show SyncChannelScope;

/// 触达一台 Hibiki 同步服务器的一个候选地址。
///
/// 同一台服务器通常可经多条路由触达（局域网、外网），按列表顺序尝试、第一个
/// 可达者胜出。
///
/// BUG-1550：凭据的基数必须与地址的基数一致。host 侧 per-peer token（TODO-961
/// M1b）按 `clientDeviceId` 逐台派发，而列表里的地址可能属于**不同的 host**
/// （LAN 发现里点谁配谁，每次都往同一个列表 append）。凭据若只有一个全局槽，
/// 配对第二台就会把第一台的 token 覆盖掉——之后第一台地址排在前面、依然可达、
/// 却用着第二台的 token → 401。故 token 落在**地址行上**，[token] 为空的行
/// （老配置 / 手动加的同 host 备用地址）回落到全局键，行为与升级前逐字一致。
class FushiClientUrl {
  const FushiClientUrl({
    required this.url,
    this.enabled = true,
    this.fingerprintSha256,
    this.deviceName,
    this.token,
    this.hostId,
    this.learned = false,
    this.addressKind,
  });

  final String url;
  final bool enabled;

  /// https 端点的证书 SHA-256 指纹钉扎值（aa:bb:.. 形式）。null = 明文 http
  /// 老路径不钉扎（向后兼容）；非 null = https 路径，client 用它做指纹钉扎。
  /// M0 仅落地字段，钉扎接线在 M1。
  final String? fingerprintSha256;

  /// 对端展示名（M0 仅落地，UI/配对在 M1 使用）。
  final String? deviceName;

  /// 本地址专属的访问凭据（BUG-1550）。配对成功时写在这里；null/空 = 老配置或
  /// 同 host 的备用地址，回落全局 `sync_hibiki_client_token`。
  ///
  /// 该字段随 `sync_hibiki_client_urls` 落库，而该键已在
  /// [SyncRepository.deviceLocalPrefKeys] 的设备本地清单里，故不会随备份/同步
  /// 携带出设备（与全局 token 键同待遇）。
  final String? token;

  /// 这条地址属于哪台 host（host 的稳定设备 id，来自 `/api/capabilities` 的
  /// `hostId`）。同 hostId 的多条地址是**同一台机器**的不同路径（LAN / IPv6 /
  /// 组网 / 公网 / P2P），选路时组内并发、列设备时合并为一台。null = 老条目或
  /// 老 host，单独成组，行为与升级前逐字一致
  /// （docs/specs/2026-09-28-interconnect-remote-reach.md §1）。
  final String? hostId;

  /// 由 host 公布的地址集自动学到（而非用户手输）。只有 learned 条目会被后续
  /// 刷新自动增删；手输条目永不被自动改动。
  final bool learned;

  /// learned 条目由 host 标注的地址种类（`InterconnectAddressKind.name`）。组网
  /// 网卡上的私网段（ZeroTier 10.x、Tailscale fd7a::）单看 URL 会被当成局域网，
  /// 排序要用 host 的原始判断。手输条目为 null（按 URL 推断）。
  final String? addressKind;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'url': url,
        'enabled': enabled,
        if (fingerprintSha256 != null) 'fingerprintSha256': fingerprintSha256,
        if (deviceName != null) 'deviceName': deviceName,
        if (token != null && token!.isNotEmpty) 'token': token,
        if (hostId != null) 'hostId': hostId,
        if (learned) 'learned': true,
        if (addressKind != null) 'kind': addressKind,
      };

  factory FushiClientUrl.fromJson(Map<String, dynamic> json) => FushiClientUrl(
        url: json['url'] as String,
        enabled: json['enabled'] as bool? ?? true,
        fingerprintSha256: json['fingerprintSha256'] as String?,
        deviceName: json['deviceName'] as String?,
        token: json['token'] as String?,
        hostId: json['hostId'] as String?,
        learned: json['learned'] as bool? ?? false,
        addressKind: json['kind'] as String?,
      );

  /// 复制并覆盖部分字段（不可变更新）。`null` 入参保留原值；要显式清空请直接构造。
  FushiClientUrl copyWith({
    String? url,
    bool? enabled,
    String? fingerprintSha256,
    String? deviceName,
    String? token,
    String? hostId,
    bool? learned,
    String? addressKind,
  }) =>
      FushiClientUrl(
        url: url ?? this.url,
        enabled: enabled ?? this.enabled,
        fingerprintSha256: fingerprintSha256 ?? this.fingerprintSha256,
        deviceName: deviceName ?? this.deviceName,
        token: token ?? this.token,
        hostId: hostId ?? this.hostId,
        learned: learned ?? this.learned,
        addressKind: addressKind ?? this.addressKind,
      );
}

/// 同步配置和缓存的持久化层（基于 Preferences 表）。
///
/// 桌面 OAuth 凭据（refresh token, client secret）存储在用户级 SQLite 数据库中，
/// 采用 base64 编码。安全模型与 gcloud/aws-cli 等桌面 CLI 工具一致：
/// 依赖操作系统文件权限保护用户数据目录。
class SyncRepository {
  SyncRepository(this._db);
  final FushiDatabase _db;

  static const _keyRootFolderId = 'sync_root_folder_id';
  static const _keyFolderCache = 'sync_folder_cache';
  static const _keyCollectionsBaselineMs = 'sync_collections_baseline_ms';
  // 删除墓碑消费的因果基线：描述「本设备见过远端删除标记到什么时刻」。远端墓碑
  // deletedAt 晚于它才是「新闻」（弹逐条确认），早于它视为本设备已处理过、不再反复弹。
  // 设备本地（[deviceLocalPrefKeys]）：随备份跨设备会让新设备把老墓碑误判为新闻反复弹。
  static const _keyDeletionTombstonesBaselineMs =
      'sync_deletion_tombstones_baseline_ms';
  // 7c 视频刮削元数据增量拉取基线：本设备从该通道见过的最大 host updatedAt。
  // 设备本地：随备份到新设备会让它以为已见过、永远不全量拉。
  static const _keyVideoMetadataSyncSinceMs =
      'sync_video_metadata_since_ms';
  // 删除墓碑**推送**的因果基线（互联通道专用，与上面的消费基线镜像对称）：描述
  // 「本设备已把删除推给对端 host 到什么时刻」。deletedAt 晚于它的墓碑才需要推。
  //
  // 为什么不复用墓碑行上的 `remotePublishedAt`：那个字段的语义是「已写进云端
  // `__tombstones__` 资产」。互联推送去标它，会让同时配了云备份的设备在云通道
  // `syncDeletionTombstones` 的 `remotePublishedAt == 0` 过滤里永远跳过这条——只连
  // 云的第三台设备就再也收不到这次删除了。两个通道各记各的账。
  //
  // 设备本地（[deviceLocalPrefKeys]）：随备份跨设备会让新设备以为自己已经推过一批
  // 它从没连过的 host。
  static const _keyDeletionTombstonesPushBaselineMs =
      'sync_deletion_tombstones_push_baseline_ms';
  static const _keyDesktopCredentials = 'sync_desktop_credentials';
  static const _keyBackendType = 'sync_backend_type';
  // apikey 同步设定重设计（2026-08-17）：互联 service-config（host 的外部服务
  // API key / 服务配置，interconnect_service_config.dart 白名单）此前是**无 UI、
  // 无开关**的隐形通道——用户既看不见「配对后 host 的 Jimaku/TMDB key 会同步过来」
  // 这件事，也关不掉它。默认 true 保持既有行为（TLS 开着的互联用户无感知），
  // 开关落设备本地（要不要接收 host 凭据是每台设备自己的信任决策，不跨设备跟随）。
  static const _keyInterconnectServiceConfigSync =
      'interconnect_sync_service_config';
  static const _keyWebDavUrl = 'sync_webdav_url';
  static const _keyWebDavUsername = 'sync_webdav_username';
  static const _keyWebDavPassword = 'sync_webdav_password';
  // Kitapsen 书店账号（`KitapsenClient`）：地址 + 用户名 + 密码（base64，同 WebDAV）。
  // 设备本地：登录凭据绝不随备份跨设备。
  static const _keyKitapsenUrl = 'sync_kitapsen_url';
  static const _keyKitapsenUsername = 'sync_kitapsen_username';
  static const _keyKitapsenPassword = 'sync_kitapsen_password';
  // Google / Apple sign-in stores the app token kitapsen.com handed out
  // (`POST /auth/mobile/session`) instead of a password.
  static const _keyKitapsenToken = 'sync_kitapsen_token';

  /// 一次性清理解耦前的**全局** folder 缓存键（BUG-1576 迁移）。
  ///
  /// 迁移语义是**丢弃而不是搬运**：这两个键的值此刻已经无法归因到任何一条通道
  /// （双通道 sweep 里谁最后写的就是谁的，正是本 bug 的成因），把它搬进任何一个
  /// 槽位都等于把污染固化下来。而它本身是**纯缓存**：根目录由
  /// `findOrCreateRootFolder` 按名查找/创建、书文件夹由 `ensureBookFolder` 按名
  /// 解析，丢了只是下一轮同步多几次目录解析，不丢任何用户数据（切后端时本来就
  /// 会 [clearFolderCache]，见 `applyBackupBackendChange`）。
  ///
  /// 幂等：键已不存在时是 no-op。
  Future<void> migrateFolderCacheToPerChannel() async {
    await (_db.delete(_db.preferences)
          ..where(
              (t) => t.key.isIn(<String>[_keyRootFolderId, _keyFolderCache])))
        .go();
  }

  // ── Sync settings ─────────────────────────────────────────────────

  /// 一次性迁移：把已废弃的 "SMB"(实为 WebDAV 网关) 配置并入 WebDAV，并删除全部
  /// `sync_smb_*` 死键。仅当对应 WebDAV 字段为空时才搬运，绝不覆盖用户已有的
  /// WebDAV 配置。幂等：无 SMB 数据时是 no-op。
  ///
  /// 用原始 key 字符串而非常量，因为 SMB 的 key 常量已随后端一并删除；迁移代码
  /// 必须独立于已删除的符号。
  Future<void> migrateSmbToWebDav() async {
    const String kSmbUrl = 'sync_smb_webdav_url';
    const String kSmbUser = 'sync_smb_username';
    const String kSmbPass = 'sync_smb_password';

    final String? backend = await _getStringOrNull(_keyBackendType);
    if (backend == 'smb') {
      // All-or-nothing: only seed WebDAV from SMB when there's no existing
      // WebDAV config at all. Avoids a hybrid (URL from one source, password
      // from the other) when the user had configured both.
      final bool hasWebDav = (await _getStringOrNull(_keyWebDavUrl)) != null;
      if (!hasWebDav) {
        final String? smbUrl = await _getStringOrNull(kSmbUrl);
        final String? smbUser = await _getStringOrNull(kSmbUser);
        // 密码以 base64 存储，原样搬运（不解码再编码，避免双重编码）。
        final String? smbPass = await _getStringOrNull(kSmbPass);
        if (smbUrl != null) await _setString(_keyWebDavUrl, smbUrl);
        if (smbUser != null) await _setString(_keyWebDavUsername, smbUser);
        if (smbPass != null) await _setString(_keyWebDavPassword, smbPass);
      }
      await _setString(_keyBackendType, SyncBackendType.webDav.name);
    }

    for (final String k in const <String>[
      kSmbUrl,
      kSmbUser,
      kSmbPass,
      'sync_smb_host',
      'sync_smb_share',
      'sync_smb_domain',
    ]) {
      await _deleteKey(k);
    }
  }

  /// 一次性幂等迁移：把「互联=互斥的 backendType==fushiServer 单选」旧模型迁到
  /// 独立的 [isInterconnectEnabled] 开关（互联与云备份不再冲突，可并存）。
  ///
  /// 旧模型里选互联意味着 `sync_backend_type == 'fushiServer'`（配对设备时也会被
  /// 强写成这个值，见 interconnect UI）。迁移：这类用户置互联开关为 true，并把
  /// backendType 迁到云默认 googleDrive（未认证时云通道自动 no-op），使升级后互联
  /// 照常跑、且不再占着「云后端选择」这个位置。互联自身的持久化字段（serverEnabled
  /// / clientUrls / token 等）本就独立存储，无需搬运。
  ///
  /// 一次性：迁移过一次后（[_keyInterconnectBackendMigrated] 落盘）永远 no-op。
  /// 这点是硬要求而非优化——解耦后用户仍可主动把云备份后端选成互联（互联页的
  /// 「用互联做备份后端」按钮，把备份写到已配对对端而不是云盘）。若迁移继续只看
  /// 「backendType 是不是 fushiServer」，这个用户选择会在下次启动被当成旧数据
  /// 抹回 googleDrive，按钮变成重启即失效的假开关。
  ///
  /// 必须在任何 [getBackendType]（未知值静默回落 googleDrive）之前、init 期跑一次。
  /// 用原始 key 字符串读取 backendType，独立于枚举符号的存亡。
  Future<void> migrateInterconnectBackendToToggle() async {
    if (await _db.getPrefTyped<bool>(_keyInterconnectBackendMigrated, false)) {
      return;
    }
    final String? backend = await _getStringOrNull(_keyBackendType);
    if (backend == SyncBackendType.fushiServer.name) {
      await setInterconnectEnabled(true);
      await _setString(_keyBackendType, SyncBackendType.googleDrive.name);
    }
    // 无论本机是否真有旧数据要搬，都记「迁移已跑过」：新装用户同样只有这一次窗口，
    // 之后的 backendType 一律是用户的真实选择。
    await _db.setPrefTyped<bool>(_keyInterconnectBackendMigrated, true);
  }

  // ── Kitapsen account ──────────────────────────────────────────────

  /// 已登录的 Kitapsen 账号；地址、用户名与凭据（密码或 app token）缺一即视为未登录。
  /// A Google / Apple account has a [token] and an empty password.
  Future<({String url, String username, String password, String? token})?>
      getKitapsenAccount() async {
    final String? url = await _getStringOrNull(_keyKitapsenUrl);
    final String? username = await _getStringOrNull(_keyKitapsenUsername);
    final String? encoded = await _getStringOrNull(_keyKitapsenPassword);
    final String? encodedToken = await _getStringOrNull(_keyKitapsenToken);
    if (url == null || username == null) return null;
    if (encoded == null && encodedToken == null) return null;
    return (
      url: url,
      username: username,
      password: encoded == null ? '' : _decodeSecret(encoded),
      token: encodedToken == null ? null : _decodeSecret(encodedToken),
    );
  }

  /// Stores a password account, or with [token] a Google / Apple account.
  Future<void> setKitapsenAccount({
    required String url,
    required String username,
    String password = '',
    String? token,
  }) async {
    await _setString(_keyKitapsenUrl, url);
    await _setString(_keyKitapsenUsername, username);
    if (token != null) {
      await _setString(_keyKitapsenToken, _encodeSecret(token));
      await _deleteKey(_keyKitapsenPassword);
    } else {
      await _setString(_keyKitapsenPassword, _encodeSecret(password));
      await _deleteKey(_keyKitapsenToken);
    }
  }

  Future<void> clearKitapsenAccount() async {
    await (_db.delete(_db.preferences)
          ..where((t) => t.key.isIn(<String>[
                _keyKitapsenUrl,
                _keyKitapsenUsername,
                _keyKitapsenPassword,
                _keyKitapsenToken,
              ])))
        .go();
  }

  // ── Encoding ─────────────────────────────────────────────────────

  static String _encodeSecret(String value) => base64Encode(utf8.encode(value));

  static String _decodeSecret(String encoded) {
    try {
      return utf8.decode(base64Decode(encoded));
    } catch (_) {
      return encoded;
    }
  }

  // ── OneDrive credentials ────────────────────────────────────────

  static const _keyOneDriveToken = 'sync_onedrive_token';

  // ── Dropbox credentials ─────────────────────────────────────────

  static const _keyDropboxToken = 'sync_dropbox_token';

  // ── FTP credentials ─────────────────────────────────────────────

  static const _keyFtpHost = 'sync_ftp_host';
  static const _keyFtpPort = 'sync_ftp_port';
  static const _keyFtpUsername = 'sync_ftp_username';
  static const _keyFtpPassword = 'sync_ftp_password';
  static const _keyFtpUseTls = 'sync_ftp_use_tls';

  // ── SFTP credentials ────────────────────────────────────────────

  static const _keySftpHost = 'sync_sftp_host';
  static const _keySftpPort = 'sync_sftp_port';
  static const _keySftpUsername = 'sync_sftp_username';
  static const _keySftpPassword = 'sync_sftp_password';
  static const _keySftpPrivateKey = 'sync_sftp_private_key';

  // ── Hibiki Server config ────────────────────────────────────────

  static const _keyInterconnectEnabled = 'sync_interconnect_enabled';

  /// 「旧互联后端 → 独立开关」迁移的一次性完成标记。见
  /// [migrateInterconnectBackendToToggle]：迁移过去靠「backendType 不再是
  /// fushiServer」当哨兵，于是用户之后主动把备份后端设回互联（互联页的
  /// 「用互联做备份后端」按钮）会在下次启动被迁移当成旧数据再改回 googleDrive。
  /// 用独立标记记「本机已迁移过」，让迁移真正只跑一次。
  static const _keyInterconnectBackendMigrated =
      'sync_interconnect_backend_migrated';
  static const _keyServerEnabled = 'sync_server_enabled';
  static const _keyServerPort = 'sync_server_port';
  static const _keyServerPassword = 'sync_server_password';
  static const _keyDeviceId = 'sync_device_id';

  /// 「本机作为制卡落地设备」开关打开的时刻（毫秒）；0 = 关。跨设备中转按它与远端
  /// 认领比大小决定谁是落地设备（后打开者胜），见 `PendingMineRelay`。设备本地。
  static const _keyPendingMineLandingClaimedAt =
      'sync_pending_mine_landing_claimed_at';

  static const _keyLanRequiresPin = 'sync_lan_requires_pin';
  static const _keyServerTlsEnabled = 'sync_server_tls_enabled';

  /// 互联总开关，独立于 [getBackendType]（云备份后端选择）。为 true 时互联作为
  /// 一条独立的同步/端到端通道运行——连接对端、远端查词/音频/占位卡 live 数据源、
  /// 以及与云备份并行的元数据同步通道——与用户选的云后端并存、互不排斥。
  ///
  /// 历史上互联是 `SyncBackendType.fushiServer` 这个互斥单选项；已由
  /// [migrateInterconnectBackendToToggle] 迁移到本独立布尔开关。默认 false。
  Future<bool> isInterconnectEnabled() =>
      _db.getPrefTyped<bool>(_keyInterconnectEnabled, false);

  /// 互联总开关的进程内「已变更」广播（BUG-1560）。
  ///
  /// 这个开关有两个写入口——同步设置页的「启用互联」开关和库页来源视图里的互联
  /// 虚拟来源行——而两边各自还缓存着一份内存态（设置页的 `_SyncSettingsState` 按
  /// AppModel 缓存、`load()` 一辈子只跑一次；来源视图在 initState 读一次）。谁写
  /// 完都不通知对方，另一边就一直显示旧值、互联各 section 的显隐也跟着错，直到
  /// 重启 app。
  ///
  /// 真值只有一个——preferences 里那一位；本 notifier 只是它的变更广播。bump 放在
  /// **唯一的写方法** [setInterconnectEnabled] 里，所以再多写入口也不可能漏发通知
  /// （消费方 re-read 真值，不信广播里的载荷，故没有第二份真相）。
  static final ValueNotifier<int> interconnectEnabledRevision =
      ValueNotifier<int>(0);

  Future<void> setInterconnectEnabled(bool v) async {
    await _db.setPrefTyped<bool>(_keyInterconnectEnabled, v);
    interconnectEnabledRevision.value++;
  }

  // ── 媒体服务器（Jellyfin / Emby / Plex） ─────────────────────────────

  /// v1 单服务器键（一条 [JellyfinServerConfig] JSON）。只在 [getJellyfinServers]
  /// 的一次性迁移里读，此后不再写；常量保留是为了黑名单与迁移代码引用同一字面量。
  static const _keyJellyfinServer = 'sync_jellyfin_server';

  /// v2 多服务器键：JSON 数组，每项 [MediaServerConfig.toJson]。列表顺序 =
  /// 用户添加顺序（视频页「媒体服务器」栏目一台一张卡片按此排）。键名带
  /// `jellyfin` 是历史名（冻结）：Plex 等其它类型也落在这个数组里，按 `kind`
  /// 字段区分，缺字段 = Jellyfin。
  static const _keyJellyfinServers = 'sync_jellyfin_servers';

  // ── Hibiki Client (connect to another Hibiki instance) ─────────

  static const _keyFushiClientUrl = 'sync_hibiki_client_url';
  static const _keyFushiClientUrls = 'sync_hibiki_client_urls';
  static const _keyFushiClientToken = 'sync_hibiki_client_token';

  /// 有序候选地址列表（下标即优先级）。新键缺失时，从旧的单地址键迁移种子，
  /// 保证老用户无感。
  Future<List<FushiClientUrl>> getFushiClientUrls() async {
    final raw = await _getStringOrNull(_keyFushiClientUrls);
    if (raw != null) {
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      return list.map(FushiClientUrl.fromJson).toList();
    }
    final legacy = await _getStringOrNull(_keyFushiClientUrl);
    if (legacy != null && legacy.isNotEmpty) {
      return <FushiClientUrl>[FushiClientUrl(url: legacy)];
    }
    return const <FushiClientUrl>[];
  }

  Future<String?> getFushiClientToken() async {
    final encoded = await _getStringOrNull(_keyFushiClientToken);
    return encoded != null ? _decodeSecret(encoded) : null;
  }

  // ── Device-local key catalog ──────────────────────────────────────

  /// 导入备份时必须保留在本设备、不能被备份覆盖的 preference key：后端选择 +
  /// 全部凭据/令牌 + 本机服务器配置 + Hibiki 客户端地址/令牌（含旧单地址键）。
  ///
  /// 故意排除：
  /// - 行为开关 `sync_auto_enabled`/`sync_stats_enabled`/`sync_audiobook_enabled`/
  ///   `sync_content_enabled` —— 当作用户设置，随备份恢复。
  /// - 内容 `audiobook_pos_*` —— 随备份恢复。
  /// - folder cache `sync_root_folder_id`/`sync_folder_cache` —— 不还原，下次同步重建。
  ///
  /// 这是"哪些 key 属于设备本地"的唯一真相源；备份导入只引用本清单，杜绝两处漂移。
  ///
  /// BUG-1579：因果基线拆成 per-channel 键后，本清单同步展开成「基名 × 全部槽位」
  /// （[_perChannelDeviceLocalBases] × [SyncChannelScope.all]）。漏展开的后果不是
  /// 编译错误而是静默泄漏——基线会随备份跨设备携带，正是拆键前就有的老毛病。
  static final List<String> deviceLocalPrefKeys = <String>[
    ..._deviceLocalFixedKeys,
    for (final String base in _perChannelDeviceLocalBases)
      for (final SyncChannelScope scope in SyncChannelScope.all)
        scope.key(base),
  ];

  /// 按通道分槽、且属设备本地的键基名（展开进 [deviceLocalPrefKeys]）。
  ///
  /// 不含 `sync_last_sync_ms`：它解耦前就不在设备本地清单里（冷却戳随备份恢复是
  /// 既有行为），拆键不改变这一点。不含 folder 缓存：那本来就是「不还原、下次同步
  /// 重建」的一类（见上面的排除说明）。
  static const List<String> _perChannelDeviceLocalBases = <String>[
    _keyCollectionsBaselineMs,
    _keyDeletionTombstonesBaselineMs,
    _keyVideoMetadataSyncSinceMs,
  ];

  static const List<String> _deviceLocalFixedKeys = <String>[
    // v105 统计按 Profile 隔离：legacy 统计归属 Profile 的值是本库自增 id，
    // 换一台设备就指向别的 Profile，绝不随备份 / Profile 分享出境。
    kStatLegacyProfileIdPrefKey,
    _keyBackendType,
    // 「新下载任务交给哪台互联 host 执行」指向的是本设备配的 host 地址，随备份
    // 到别的设备只会指错（PC 恢复手机的备份后把任务投给它自己）。
    kDownloadExecutionHostPrefKey,
    // 「允许配对设备远程启动游戏」是本机安全开关：从另一台电脑恢复备份不得替
    // 这台电脑打开远程起进程的门。
    kGameStreamRemoteLaunchPrefKey,
    // 「本机作为制卡落地设备」：换设备恢复备份若把它带过去，就会同时有两台落地设备，
    // 同一张卡被两边各落一次。
    _keyPendingMineLandingClaimedAt,
    // （旧键 google_drive_hoshi_compat 已由 fushi_core v72 迁移清行：Hoshi 共享
    // 空间功能删除后它无任何读写方；导入的旧备份库开库时同样被清，故无需再列。）
    _keyDesktopCredentials,
    _keyOneDriveToken,
    _keyDropboxToken,
    _keyWebDavUrl,
    _keyWebDavUsername,
    _keyWebDavPassword,
    _keyKitapsenUrl,
    _keyKitapsenUsername,
    _keyKitapsenPassword,
    _keyKitapsenToken,
    _keyFtpHost,
    _keyFtpPort,
    _keyFtpUsername,
    _keyFtpPassword,
    _keyFtpUseTls,
    _keySftpHost,
    _keySftpPort,
    _keySftpUsername,
    _keySftpPassword,
    _keySftpPrivateKey,
    _keyServerEnabled,
    _keyServerPort,
    _keyServerPassword,
    _keyDeviceId,
    _keyLanRequiresPin,
    _keyServerTlsEnabled,
    _keyFushiClientUrls,
    _keyFushiClientToken,
    _keyFushiClientUrl,
    // Jellyfin 服务器绑定含访问令牌，属设备本地凭据，绝不随备份跨设备。旧单值键
    // 与新列表键都列：旧键在迁移前的备份里仍可能存在。
    _keyJellyfinServer,
    _keyJellyfinServers,
    // 「要不要接收 host 的 service-config（外部服务 API key）」是每台设备自己的
    // 信任决策，跨设备携带会把 A 机的选择强加给 B 机。
    _keyInterconnectServiceConfigSync,
    // 合集同步因果基线：描述「本设备见过共享清单到什么时刻」，跨设备携带会让
    // 新设备把没见过的墓碑误判成旧闻而复活成员（见 getCollectionsSyncBaselineMs）。
    // 这两条是**解耦前的全局键**：现值仍被 per-channel 读作迁移初值，故照旧不能
    // 跨设备携带；per-channel 槽位由 _perChannelDeviceLocalBases 展开补上。
    _keyCollectionsBaselineMs,
    // 删除墓碑消费基线：同理设备本地，跨设备携带会让新设备反复弹老墓碑确认框。
    _keyDeletionTombstonesBaselineMs,
    // 删除墓碑推送基线：同理设备本地，跨设备携带会让新设备以为自己已经把一批删除
    // 推给过一个它从没连过的 host（漏推 = 对端该删的没删）。
    _keyDeletionTombstonesPushBaselineMs,
    // TODO-1961：下载保存根与历史根都是**本机绝对路径**（如 D:\downloads），跨设备
    // 恢复必然指向新机不存在的位置。启动校验会回退默认根并警告（不丢数据），但让它
    // 漂过去只会给用户「我明明设过怎么变了」的困惑，故按设备本地处理不随备份携带。
    'download_save_root',
    'download_save_root_history',
    // 发现/下载闭环：第三方 indexer / 字幕服务配置、下载后端路径映射和受管来源
    // 都描述本机能力。跨设备恢复会携带明文凭据、无效绝对路径或错误 source id。
    'video_resource_torznab_config',
    'video_subtitle_opensubtitles_config',
    // 用户自配的 AI 提供商：条目里带 base64 的 API key，且本地推理服务（Ollama /
    // LM Studio）的地址是 `http://localhost:11434` 这种只对本机成立的端点。跨设备
    // 恢复既泄付费凭据又指向一台并不在跑的服务。功能映射按 provider id 指向它们，
    // 单独漂过去只会变成一堆悬空 id，故一并设备本地。
    'ai_providers',
    'ai_feature_providers',
    // 漫画 OCR 大模型档位：开了就是「上传漫画页 + 按量计费」，这种同意只对点它的
    // 那台设备成立，漂过去会让另一台配了 AI 的设备静默开始上传。
    'manga_ocr_ai_mode',
    // 查词自动按句意挑词条：同理，每次查词一个计费请求。
    'lookup_ai_context_auto',
    // 用户自配的 OPDS 书目服务器：条目里带 base64 密码，且服务器地址多是
    // 局域网 IP（`http://192.168.x.x:8080`），跨设备恢复既泄凭据又指向一台
    // 新机根本连不到的主机。
    'discovery_opds_servers',
    // 同形：AList / OpenList 站点清单，条目里带 base64 密码。
    'discovery_alist_sites',
    'video_download_backend_path_mappings',
    'video_download_target_source_id',
    'video_download_embedded_installation_id',
  ];

  Future<void> _deleteKey(String key) async {
    await (_db.delete(_db.preferences)..where((t) => t.key.equals(key))).go();
  }

  Future<String?> _getStringOrNull(String key) async {
    final row = await (_db.select(_db.preferences)
          ..where((t) => t.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  Future<void> _setString(String key, String value) async {
    await _db.into(_db.preferences).insertOnConflictUpdate(
          PreferencesCompanion.insert(key: key, value: value),
        );
  }
}
