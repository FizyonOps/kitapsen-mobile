/// 全应用**出站 HTTP 代理**解析层：把「用户机器上正在跑的代理」翻译成
/// [HttpClient.findProxy]。
///
/// 本层原先住在 `update_checker_net.dart`（更新检查库的 part）里，命名与归属都写死成
/// 「更新专用」。但代理是**进程级网络出口策略**，不是更新检查的私有属性：BUG-1348 里
/// 谷歌云盘登录的 token 交换用裸 `http.Client()` 直连 `oauth2.googleapis.com`，在同一台
/// 开着代理的机器上必然 `errno = 121`（信号灯超时）失败——浏览器那半程走系统代理拿到了
/// 授权码，app 这半程走直连换不到 token。part 文件契约禁止 part 内 import，同步层没法
/// 复用它，于是同一台机器上「更新检查能走代理、云同步不能」。
///
/// 故本层提取为**独立库**：代理**怎么解析**（自动 / 直连 / 手动、PAC 降级）
/// 全应用只有这一份实现，接代理的调用方一律 import 这里，不再各自重写一遍优先级。
///
/// **覆盖面（BUG-1498 收敛后）**：出站装配不再是「每个调用点各自记得做」的事。
///   * 公网出站一律经 `utils/net/app_http.dart` 的 [createAppHttpClient] /
///     `createAppHttpIoClient` / `createAppDio`（内部调 [applyAppProxySync]）；
///   * 需要异步现场解析的老调用点（云同步 / 更新检查 / 下载发现）继续用 [applyAppProxy]；
///   * 词典链路经 `utils/net/dictionary_dio.dart` 的工厂钩子（BUG-1493）；
///   * **本机 / 局域网 / 自建服务**（AnkiConnect、Yomitan 端口、Mihon sidecar、互联 peer、
///     qBittorrent WebUI、FTP/SFTP、texthooker WS）**故意不经本层**，并且**即便经了
///     也不会被代理**——见 [isDirectProxyTarget]。
///   * 图片经 `AppHttpImage` / `AppCachedHttpImage`；普通公网 WebDAV 同样经工厂。
///   * 原生播放器与 Aidoku 经鉴权回环转发，Mihon 经逐 URL 策略回调。
///   * 内置 torrent 引擎保留单独的 P2P 开关，代理下发到 libtorrent session。
///
/// 守卫 `test/tools/outbound_http_discipline_guard_test.dart` 钉死这条纪律：新增裸
/// `HttpClient()` / `http.Client()` / `IOClient()` / `Dio()` 必须登记在案并写明理由。
library;

import 'dart:io';

import 'package:fushi_engine/utils/net/url_input_normalizer.dart';
import 'package:fushi_core/fushi_core.dart';

/// 进程级「用户手填代理」读取器——[applyAppProxy] 不显式传 `userProxy` 时的取值来源。
///
/// 代理是全局网络配置，却存在 `PreferencesRepository` 里，而同步层（`GoogleDriveAuth`
/// 等单例）拿不到 `AppModel`。与其给每条网络调用链穿一路 `userProxy` 参数（穿漏一处就
/// 是一个「这条路不走代理」的暗坑，BUG-1348 正是如此），不如让配置本身有一个进程级
/// 真相源：`AppModel.initialise()` 把它接到偏好上，此后任何调用方 `applyAppProxy(client)`
/// 都自动拿到同一个值。
///
/// 默认返回空串 = 未接（测试 / popup 等精简入口），[applyAppProxy] 据此回退
/// `env > GUI 系统代理 > DIRECT`，与接入前逐字等价。
String Function() appUserProxyReader = () => '';

/// 进程级代理模式的三个合法值。这是**用户意图**的全部值域，[kProxyModeUnresolved]
/// 不在其中——它表示「还没人把偏好接上来」，不是第四种意图。
const String kProxyModeAuto = 'auto';
const String kProxyModeDirect = 'direct';
const String kProxyModeManual = 'manual';

/// 「偏好还没接上」的哨兵。**它表达不了 `direct`**：没接上就意味着这个进程手里根本
/// 没有用户的选择，只能从手填地址反推 auto/manual（见 [_effectiveProxyMode]）。
///
/// 所以真正的修法不是给哨兵编一个更聪明的猜法，而是让「偏好一读出来就接上」——绑定
/// 住在 `PreferencesRepository.loadFromDb()`（偏好值变得可读的那一刻），而不是某一个
/// 调用点。以前只有 `AppModel.initialise()` 绑，弹窗词典进程
/// （`initialiseForDictionaryPopup`，同样读了偏好却没绑）整段生命周期都落在本哨兵上：
/// 选了「直连」的用户在弹窗进程里照样走系统代理，那不是一个空窗口，是一整个会话。
const String kProxyModeUnresolved = 'unresolved';

/// 代理模式读取器。默认 [kProxyModeUnresolved]；[PreferencesRepository.loadFromDb]
/// 一读出偏好就把它接到真值上。
String Function() appUserProxyModeReader = () => kProxyModeUnresolved;

/// 手动 HTTP 代理 **Basic** 认证凭据（Digest 未实现，challenge 时直接放弃而不是
/// 塞一份永远匹配不上的 Basic 凭据进无限重试环）。密码只在代理发起 407 challenge 时交给
/// [HttpClient.addProxyCredentials]，不拼进 URL / 日志 / findProxy 指令。
String Function() appUserProxyUsernameReader = () => '';
String Function() appUserProxyPasswordReader = () => '';

/// 进程级模式是否已经是用户的真实选择（而不是 [kProxyModeUnresolved] 哨兵）。
bool hasResolvedProxyMode() {
  final String mode = appUserProxyModeReader();
  return mode == kProxyModeAuto ||
      mode == kProxyModeDirect ||
      mode == kProxyModeManual;
}

String _effectiveProxyMode(String proxy) {
  if (hasResolvedProxyMode()) return appUserProxyModeReader();
  // 未接线兜底判据必须是「归一得出来」而不是「非空」：设置页历来对非法地址只弹
  // SnackBar 却仍存原串，所以存量里有 `[::1]:7890`（IPv6 不支持）、带路径、带空格
  // 等「存下来了但归一失败」的值。按非空推成 manual，manual 归一失败又硬走 DIRECT
  // = 存量用户升级即全应用断网。旧行为在这种值上是 fail-open（落回 env > 系统代理），
  // 判据换成归一成功与否，与旧短路条件逐字等价。
  return normalizeUserProxyHostPort(proxy) == null
      ? kProxyModeAuto
      : kProxyModeManual;
}

/// 本次请求该按哪个地址、哪个模式出站。[legacyUserProxy] 只在**没有**已解析模式时顶替
/// 进程级地址（旧入口的 `applyAppProxy(client, userProxy: ...)` 语义）；一旦模式接上来，
/// 用户的选择优先，参数被忽略（见 [applyAppProxy] 文档）。
({String mode, String proxy}) _resolveProxyDecision(String? legacyUserProxy) {
  final String proxy = !hasResolvedProxyMode() && legacyUserProxy != null
      ? legacyUserProxy
      : appUserProxyReader();
  return (mode: _effectiveProxyMode(proxy), proxy: proxy);
}

void _installManualProxyCredentials(
  HttpClient client, {
  String? legacyUserProxy,
}) {
  // 与 findProxy 一样在请求时读取，已有 client 也能响应后来填写的认证配置。
  // 同一 (host, port, scheme, realm) 只交付一次凭据。dart:io 的 retry() 没有深度
  // 计数器：密码错时它会「407 → 移除已用凭据 → 再问回调 → 又加同一份 → retry」
  // 无限打转，请求永不返回、用户只看到转圈。被问第二次就说明上一份被代理拒了。
  final Set<String> attempted = <String>{};
  client.authenticateProxy =
      (String host, int port, String scheme, String? realm) async {
        if (_resolveProxyDecision(legacyUserProxy).mode != kProxyModeManual) {
          return false;
        }
        // 只支持 Basic。塞 Basic 凭据去应付 Digest challenge，findCredentials 永远
        // 匹配不到，同样进无限环。
        if (scheme.toLowerCase() != 'basic') return false;
        final String username = appUserProxyUsernameReader();
        if (username.isEmpty) return false;
        final String? endpoint = normalizeUserProxyHostPort(
          _resolveProxyDecision(legacyUserProxy).proxy,
        );
        if (endpoint == null ||
            endpoint.toLowerCase() != '$host:$port'.toLowerCase()) {
          return false;
        }
        if (!attempted.add('$host:$port|$scheme|${realm ?? ''}')) return false;
        client.addProxyCredentials(
          host,
          port,
          realm ?? '',
          HttpClientBasicCredentials(username, appUserProxyPasswordReader()),
        );
        return true;
      };
}

/// **纯函数（TODO-871/862）**：把用户手填的「自定义更新代理」原始串归一成
/// `host:port`，非法返 null。自动模式不调用本函数；手动模式非法时安全直连，
/// 不会暗中改走机器上的另一个代理。
///
/// 规则：trim → 剥可选 `http://` / `https://` 前缀 → 校验 `host:port`：
/// * host = IPv4（四段 0-255）或主机名（字母数字 + `.` + `-`，至少一个非空标签）。
/// * port = 纯数字、范围 1-65535。
///
/// **【必改④】IPv6 字面量**（`[::1]:7890`，含方括号 / 多个冒号）本期**不支持**→ 直接返
/// null。空串 / 缺端口 / 非数字端口 / `0` / `70000` / 带路径 → null。
///
/// 公开（非 @visibleForTesting）：除测试外，设置页输入框也实时调用它做格式校验
/// （`settings_schema_system.dart`），故是真实生产 API。
String? normalizeUserProxyHostPort(String raw) {
  // 先折全角：下面按 `://` `/` `:` 逐段拆，全角标点会让 scheme 剥不掉、
  // host 与 port 也分不开，最终整串被判非法（BUG-1807）。
  String value = normalizeUrlInput(raw);
  if (value.isEmpty) return null;
  // 剥可选 scheme 前缀（大小写不敏感）。
  for (final String scheme in const <String>['https://', 'http://']) {
    if (value.toLowerCase().startsWith(scheme)) {
      value = value.substring(scheme.length).trim();
      break;
    }
  }
  if (value.isEmpty) return null;
  // 带路径 / query / fragment 一律不接受（host:port 之外的内容）。
  if (value.contains('/') || value.contains('?') || value.contains('#')) {
    return null;
  }
  // IPv6 字面量（方括号或多于一个冒号）本期不支持 → null（【必改④】）。
  if (value.contains('[') || value.contains(']')) return null;
  final int firstColon = value.indexOf(':');
  if (firstColon < 0) return null; // 缺端口。
  if (value.indexOf(':', firstColon + 1) >= 0) return null; // 多冒号（疑似 IPv6）。
  final String host = value.substring(0, firstColon);
  final String portText = value.substring(firstColon + 1);
  if (host.isEmpty || portText.isEmpty) return null;
  if (!_isValidProxyHost(host)) return null;
  final int? port = int.tryParse(portText);
  if (port == null || port < 1 || port > 65535) return null;
  return '$host:$port';
}

/// 校验 [host] 是否为合法 IPv4 或主机名（normalizeUserProxyHostPort 内部用）。
bool _isValidProxyHost(String host) {
  // IPv4：四段、每段 0-255。
  final RegExpMatch? ipv4 = RegExp(
    r'^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$',
  ).firstMatch(host);
  if (ipv4 != null) {
    for (int i = 1; i <= 4; i++) {
      final int seg = int.parse(ipv4.group(i)!);
      if (seg > 255) return false;
    }
    return true;
  }
  // 主机名：点分标签，每段字母数字或内部连字符，不以 `-` 起止。
  final RegExp label = RegExp(r'^[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?$');
  final List<String> parts = host.split('.');
  for (final String part in parts) {
    if (part.isEmpty) return false;
    if (!label.hasMatch(part)) return false;
  }
  return true;
}

/// **唯一装配路**（两个入口共用）：装一个**请求时求值**的 `findProxy` 闭包 + 凭据钩子。
///
/// 「请求时求值」是这次收敛的关键。异步入口以前把模式裁决**烘焙**进闭包、并且只在
/// manual 分支里装凭据钩子：用户在 auto 模式下建好的 client，之后改成 manual，那些
/// client 既不会改走手填代理、也永远拿不到 407 应答。两个装配点从此不可能给出不同答案。
void _installAppProxy(HttpClient client, {String? legacyUserProxy}) {
  client.findProxy = (Uri uri) =>
      resolveAppProxyDirective(uri, legacyUserProxy: legacyUserProxy);
  _installManualProxyCredentials(client, legacyUserProxy: legacyUserProxy);
}

/// env 里有没有给代理（`https_proxy` / `http_proxy`，大小写不敏感）。
bool _hasEnvProxy(Map<String, String> environment) =>
    environment.keys.any((String k) {
      final String lower = k.toLowerCase();
      return lower == 'https_proxy' || lower == 'http_proxy';
    });

/// 按平台读 GUI 系统代理（Windows 注册表 / macOS scutil / Linux gsettings）。
/// 其余平台返回空 map。
Future<Map<String, String>> resolveSystemProxyEnvironment() async {
  return const <String, String>{};
}

// ---------------------------------------------------------------------------
// 同步装配路径（BUG-1498）
// ---------------------------------------------------------------------------
//
// 为什么必须有一条同步路：全仓 40+ 个出站点的形态都是构造函数初始化列表里的
// `client ?? http.Client()`（刮削 / 弹幕 / 字幕 / 封面 / 发音源……）。初始化列表里
// **不能 await**，而 [applyAppProxy] 是异步的（要跑 `reg query` / `scutil` /
// `gsettings`）。这正是「代理层存在、却有 40 条链路绕过它」的结构性成因——不是谁忘了，
// 是那个形状根本接不上。
//
// 解法是把「异步的那一半」搬到进程启动时做一次：`AppModel.initialise()` 调
// [primeAppProxy] 缓存平台 GUI 系统代理解析结果，此后 [applyAppProxySync] 纯同步装配。
// 用户在设置页改了手填代理不受影响，因为 `findProxy` 是**请求时**才调的闭包，每次都
// 重读 [appUserProxyReader]。
//
// **系统代理不是「一次解析足够」的（#1514）**：FlClash / Clash 这类软件在用户点「系统
// 代理」的那一刻才写注册表，Fushi 比代理软件先启动、或用户中途才开系统代理，是常态而
// 不是边角。缓存只在启动时读一次，自动模式就整个进程生命周期直连——浏览器扩展 YouTube
// 制卡 `/api/mine` 取 manifest 在墙内全部超时，用户手填同一个地址就好了。所以缓存带有效
// 期，过期后按平台能力刷新（见 [_currentSystemProxyEnv]）。

/// macOS / Linux 系统代理缓存的有效期。那边要起 `scutil` / `gsettings` 子进程，而
/// `findProxy` 是同步回调不能等：过期时后台刷新一次、本次仍用旧值，下一个请求起生效。
/// 间隔取长一些，避免持续出站时每几秒起一个子进程。
const Duration kAsyncSystemProxyRefreshInterval = Duration(seconds: 30);

/// 平台 GUI 系统代理解析结果的进程级缓存。null = 还没 prime 过。
Map<String, String>? _cachedSystemProxyEnv;

/// [_cachedSystemProxyEnv] 的读取时刻（取自 [_systemProxyClock]）。
DateTime? _cachedSystemProxyEnvAt;

/// 正在进行的后台刷新（macOS / Linux），防止同一过期窗口里重复起子进程。
Future<void>? _systemProxyRefreshInFlight;

/// 缓存代次：测试重置 / 注入后，还没回来的旧后台刷新不得覆盖新状态。
int _systemProxyGeneration = 0;

/// 异步读取器：[primeAppProxy] 与 macOS / Linux 后台刷新用。
Future<Map<String, String>> Function() _systemProxyAsyncReader =
    resolveSystemProxyEnvironment;

DateTime Function() _systemProxyClock = DateTime.now;

void _storeSystemProxyEnv(Map<String, String> env) {
  _cachedSystemProxyEnv = Map<String, String>.of(env);
  _cachedSystemProxyEnvAt = _systemProxyClock();
}

/// 预解析并缓存平台 GUI 系统代理，供 [applyAppProxySync] 同步取用。
///
/// 在 `AppModel.initialise()` 里调一次即可；此后缓存按有效期自动刷新（见
/// [_currentSystemProxyEnv]），重复调用则立即按当前系统设置刷新。解析失败按各
/// `resolve*` 的约定返回空 map（= 不补代理），绝不抛。
Future<void> primeAppProxy() async {
  final int generation = _systemProxyGeneration;
  final Map<String, String> env = await _systemProxyAsyncReader();
  if (generation != _systemProxyGeneration) return;
  _storeSystemProxyEnv(env);
}

/// 自动模式那一格此刻该用的 GUI 系统代理。
///
/// * 没 prime 过（精简入口 / 测试没选择解析系统代理）→ 空，与引入缓存前逐字等价；
/// * 有同步读取器（Windows）且缓存过期 → 现读并回写，本次请求就用新值；
/// * 否则（macOS / Linux）缓存过期 → 后台刷新，本次用旧值。
Map<String, String> _currentSystemProxyEnv() {
  final Map<String, String>? cached = _cachedSystemProxyEnv;
  if (cached == null) return const <String, String>{};
  final DateTime now = _systemProxyClock();
  final Duration age = now.difference(_cachedSystemProxyEnvAt ?? now);
  if (age >= kAsyncSystemProxyRefreshInterval) {
    _refreshSystemProxyInBackground();
  }
  return cached;
}

void _refreshSystemProxyInBackground() {
  if (_systemProxyRefreshInFlight != null) return;
  final int generation = _systemProxyGeneration;
  _systemProxyRefreshInFlight = _systemProxyAsyncReader()
      .then(
        (Map<String, String> env) {
          if (generation == _systemProxyGeneration) _storeSystemProxyEnv(env);
        },
        onError: (Object e) {
          // 各 resolve* 约定不抛；真抛了就保留旧缓存、不更新时刻，下个请求再试。
          fushiDebugPrint('[AppProxy] refresh system proxy failed: $e');
        },
      )
      .whenComplete(() {
        if (generation == _systemProxyGeneration) {
          _systemProxyRefreshInFlight = null;
        }
      });
}

/// **同步版** [applyAppProxy]：装一个请求时才求值的 `findProxy` 闭包。
///
/// 优先级与异步版逐字一致（本机/局域网直连 > 模式裁决 > 自动模式的 env/系统代理），
/// GUI 系统代理那一格取自 [primeAppProxy] 缓存（按有效期刷新）。
/// **没 prime 过时该格为空**，于是退化成 `env > DIRECT`——与本函数存在之前那些裸
/// `HttpClient()` 相比只多不少，绝不会更坏。
void applyAppProxySync(HttpClient client) => _installAppProxy(client);

/// **纯查表**：一个 URI 该走什么出口。[applyAppProxySync] 装进 `findProxy` 的就是它。
///
/// 公开（非 `@visibleForTesting`）是因为它是这条纪律的可断言表面：守卫与单测要能直接
/// 问「AnkiConnect / 局域网 peer 会不会被代理」，而不是去 mock 一个 HttpClient。
String resolveAppProxyDirective(
  Uri uri, {
  String? legacyUserProxy,
  Map<String, String>? systemEnvOverride,
}) {
  if (isDirectProxyTarget(uri.host)) return 'DIRECT';
  final ({String mode, String proxy}) decision = _resolveProxyDecision(
    legacyUserProxy,
  );
  if (decision.mode == kProxyModeDirect) return 'DIRECT';
  // 手动模式不参与 env>GUI>DIRECT 排序，消除「手填 vs 系统代理」覆盖顺序不确定
  // （TODO-871/862）；normalize 失败时明确直连，不偷用 env/系统代理。
  if (decision.mode == kProxyModeManual) {
    final String? normalizedUserProxy = normalizeUserProxyHostPort(
      decision.proxy,
    );
    return normalizedUserProxy == null
        ? 'DIRECT'
        : 'PROXY $normalizedUserProxy';
  }
  final Map<String, String> environment = <String, String>{
    ...Platform.environment,
  };
  // env 变量优先：用户显式 set 的不该被 GUI 系统代理覆盖。仅当 env 没给代理时才补 GUI
  // 系统代理——调用方显式给的那一份优先，否则取 [primeAppProxy] 缓存（TODO-704），
  // 缓存过期按平台刷新（#1514）。
  if (!_hasEnvProxy(environment)) {
    environment.addAll(systemEnvOverride ?? _currentSystemProxyEnv());
  }
  return HttpClient.findProxyFromEnvironment(uri, environment: environment);
}

/// **本机 / 局域网直连闸门**：这些目标经 HTTP 代理只会更坏，甚至直接把功能打断。
///
/// 这不是「优化」，是一条硬正确性约束。实测（`HttpClient.findProxyFromEnvironment`，
/// environment 里给了 `http_proxy`）：
/// ```text
/// http://127.0.0.1:8765/      -> PROXY 1.2.3.4:8080
/// http://localhost:8765/      -> PROXY 1.2.3.4:8080
/// http://192.168.1.34:5000/   -> PROXY 1.2.3.4:8080
/// http://hibiki-pc.local:8080 -> PROXY 1.2.3.4:8080
/// ```
/// Dart **不做任何隐式 loopback bypass**（浏览器和 Windows 的 `ProxyOverride`
/// 默认值 `<local>` 都做），`no_proxy` 也只在用户自己设了才有；而 Windows 系统代理是从
/// 注册表 `ProxyServer` 读的，`ProxyOverride` 压根没被读进来。用户手填代理那条分支更极端
/// ——它无条件返回 `PROXY host:port`，连 `no_proxy` 都不过。
///
/// 于是「把某条链路接进代理层」在本仓一直是个危险动作：AnkiConnect（`127.0.0.1:8765`）、
/// Yomitan 本地端口、Mihon sidecar、桌面 OAuth 回环回调（BUG-1348 的原始症状之一）、
/// 互联局域网 peer、qBittorrent WebUI、自建 WebDAV，任何一条被卷进去都是功能当场坏掉。
/// 把闸门放在**解析层**而不是每个调用点，这个风险就一次性消失了：接不接代理不再需要
/// 逐点判断「它会不会打到本机」。
///
/// 覆盖（与 Windows `<local>` / 常见 `no_proxy` 默认值对齐）：
/// * `localhost` / `*.localhost`（RFC 6761）、`*.local`（mDNS——互联 peer 发现用 Bonsoir
///   广播的正是这种名字）；
/// * IPv4：`127.0.0.0/8`、`0.0.0.0`、`10.0.0.0/8`、`172.16.0.0/12`、`192.168.0.0/16`、
///   `169.254.0.0/16`（link-local）；
/// * IPv6：`::1`、`::`、`fc00::/7`（ULA）、`fe80::/10`（link-local）。
///
/// **不覆盖**用户自填的公网自建服务（自建 dandanplay 镜像、公网 WebDAV）：那些确实该跟着
/// 全局代理走，与浏览器行为一致。
bool isDirectProxyTarget(String host) {
  String h = host.trim().toLowerCase();
  if (h.isEmpty) return false;
  // `Uri.host` 对 IPv6 字面量已剥方括号，但调用方也可能直接喂原始 authority。
  if (h.startsWith('[') && h.endsWith(']')) {
    h = h.substring(1, h.length - 1);
  }
  // IPv6 的 zone id（`fe80::1%eth0`）不参与判定。
  final int zone = h.indexOf('%');
  if (zone >= 0) h = h.substring(0, zone);
  if (h.isEmpty) return false;

  if (h == 'localhost' || h.endsWith('.localhost')) return true;
  if (h == 'local' || h.endsWith('.local')) return true;

  final List<int>? v4 = _parseIpv4(h);
  if (v4 != null) {
    if (v4[0] == 127 || v4[0] == 0) return true; // loopback / 未指定
    if (v4[0] == 10) return true; // 10.0.0.0/8
    if (v4[0] == 172 && v4[1] >= 16 && v4[1] <= 31) return true; // 172.16/12
    if (v4[0] == 192 && v4[1] == 168) return true; // 192.168/16
    if (v4[0] == 169 && v4[1] == 254) return true; // link-local
    return false;
  }

  if (!h.contains(':')) return false; // 普通主机名 → 公网，走代理
  // 到这里当 IPv6 字面量处理。`::ffff:127.0.0.1` 这类映射地址交给尾部的 IPv4 段判定。
  final int lastColon = h.lastIndexOf(':');
  final String tail = h.substring(lastColon + 1);
  final List<int>? mapped = _parseIpv4(tail);
  if (mapped != null) return isDirectProxyTarget(tail);
  if (h == '::1' || h == '::') return true;
  // fc00::/7（ULA：fc / fd 开头）与 fe80::/10（link-local：fe8 / fe9 / fea / feb）。
  if (h.startsWith('fc') || h.startsWith('fd')) return true;
  if (RegExp(r'^fe[89ab]').hasMatch(h)) return true;
  return false;
}

/// 把点分四段解析成 0-255 的四元组；非 IPv4 字面量返回 null。
List<int>? _parseIpv4(String host) {
  final List<String> parts = host.split('.');
  if (parts.length != 4) return null;
  final List<int> out = <int>[];
  for (final String part in parts) {
    if (part.isEmpty || part.length > 3) return null;
    if (!RegExp(r'^\d+$').hasMatch(part)) return null;
    final int value = int.parse(part);
    if (value > 255) return null;
    out.add(value);
  }
  return out;
}
