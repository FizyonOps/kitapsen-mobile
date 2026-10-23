import 'package:flutter/foundation.dart';

enum AudioSourceKind {
  fushiRemote('fushiRemote'),
  localAudio('localAudio'),
  remoteAudio('remoteAudio');

  const AudioSourceKind(this.wireName);

  final String wireName;

  /// Hibiki 时代写下的 wireName（W9-6 改名前）。音频源配置以 JSON 落偏好，存量
  /// 用户经迁移带过来的配置里仍是旧值；不认它会让 fromWireName 落到 orElse 的
  /// remoteAudio，把「Fushi 互联发音源」悄悄降级成一个空的自定义远程源。
  static const String _legacyFushiRemoteWireName = 'hibikiRemote';

  static AudioSourceKind fromWireName(Object? value) {
    final String name = value?.toString() ?? '';
    if (name == _legacyFushiRemoteWireName) return AudioSourceKind.fushiRemote;
    return AudioSourceKind.values.firstWhere(
      (AudioSourceKind kind) => kind.wireName == name,
      orElse: () => AudioSourceKind.remoteAudio,
    );
  }
}

@immutable
class AudioSourceConfig {
  const AudioSourceConfig._({
    required this.kind,
    required this.enabled,
    this.label,
    this.url,
    this.path,
  });

  factory AudioSourceConfig.fushiRemote({bool enabled = false}) {
    // label 留空：显示名由 UI 用 i18n（audio_source_fushi_interconnect）解析，
    // 不把英文写死进持久化 JSON。
    return AudioSourceConfig._(
      kind: AudioSourceKind.fushiRemote,
      enabled: enabled,
    );
  }

  factory AudioSourceConfig.localAudio({
    required String label,
    required String path,
    bool enabled = false,
  }) {
    return AudioSourceConfig._(
      kind: AudioSourceKind.localAudio,
      enabled: enabled,
      label: label,
      path: path,
    );
  }

  factory AudioSourceConfig.remoteAudio({
    required String url,
    String? label,
    bool enabled = true,
  }) {
    return AudioSourceConfig._(
      kind: AudioSourceKind.remoteAudio,
      enabled: enabled,
      label: label,
      url: url,
    );
  }

  factory AudioSourceConfig.fromJson(Map<String, dynamic> json) {
    final AudioSourceKind kind = AudioSourceKind.fromWireName(json['kind']);
    final bool enabled =
        json['enabled'] is bool ? json['enabled'] as bool : true;
    final String? label = _nullableString(json['label']);
    switch (kind) {
      case AudioSourceKind.fushiRemote:
        return AudioSourceConfig.fushiRemote(enabled: enabled);
      case AudioSourceKind.localAudio:
        return AudioSourceConfig.localAudio(
          label: label ?? _nullableString(json['path']) ?? '',
          path: _nullableString(json['path']) ?? '',
          enabled: enabled,
        );
      case AudioSourceKind.remoteAudio:
        return AudioSourceConfig.remoteAudio(
          url: _nullableString(json['url']) ?? '',
          label: label,
          enabled: enabled,
        );
    }
  }

  final AudioSourceKind kind;
  final bool enabled;
  final String? label;
  final String? url;
  final String? path;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'kind': kind.wireName,
      'enabled': enabled,
      if (label != null) 'label': label,
      if (url != null) 'url': url,
      if (path != null) 'path': path,
    };
  }

  static List<AudioSourceConfig> fromLegacyUrls(List<String> urls) {
    return urls
        .where((String url) => url.trim().isNotEmpty)
        .map((String url) => AudioSourceConfig.remoteAudio(url: url.trim()))
        .toList();
  }

  static String? _nullableString(Object? value) {
    if (value == null) return null;
    final String text = value.toString();
    return text.isEmpty ? null : text;
  }

  @override
  bool operator ==(Object other) {
    return other is AudioSourceConfig &&
        other.kind == kind &&
        other.enabled == enabled &&
        other.label == label &&
        other.url == url &&
        other.path == path;
  }

  @override
  int get hashCode => Object.hash(kind, enabled, label, url, path);

  @override
  String toString() => 'AudioSourceConfig(${toJson()})';
}
