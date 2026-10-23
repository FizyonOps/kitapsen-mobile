
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:fushi/src/utils/misc/channel_constants.dart';
import 'package:fushi/src/utils/misc/error_log_service.dart';

/// 本机一款系统字体族。
///
/// [family] 是引擎（Flutter `TextStyle.fontFamily` / WebView CSS `font-family`）
/// **按名能解析到**的族名——字体库里系统字体条目只存这个名字，名字不对等于没加。
@immutable
class SystemFontFamily {
  const SystemFontFamily({required this.family, this.supportsJapanese});

  final String family;

  /// 字体自身是否带日文字形（假名 + 常用汉字）。null = 该平台判不出来
  /// （Android 的字形检测会把系统回退也算进去，判了也是恒 true）。
  final bool? supportsJapanese;

  @override
  bool operator ==(Object other) =>
      other is SystemFontFamily &&
      other.family == family &&
      other.supportsJapanese == supportsJapanese;

  @override
  int get hashCode => Object.hash(family, supportsJapanese);

  @override
  String toString() =>
      'SystemFontFamily($family, supportsJapanese: $supportsJapanese)';
}

/// 系统字体清单与它的来源可信度。
@immutable
class SystemFontList {
  const SystemFontList({required this.families, required this.namesReliable});

  static const SystemFontList empty = SystemFontList(
    families: <SystemFontFamily>[],
    namesReliable: true,
  );

  final List<SystemFontFamily> families;

  /// false = 名字是从字体**文件名**推出来的兜底结果（平台枚举不可用时），
  /// 与引擎认的族名可能对不上（`msgothic.ttc` 推不出 `MS Gothic`），UI 要提示。
  final bool namesReliable;
}

/// 解析 `listSystemFonts` 通道的返回值。
///
/// 契约：`List<Map>`，每项 `{family: String, supportsJapanese?: bool}`。旧 Android
/// 宿主返回裸 `List<String>`，同样接受（`supportsJapanese` 记 null）。按族名大小写
/// 不敏感去重，排序后返回；空名、`@` 开头的竖排别名族一律丢弃。
@visibleForTesting
List<SystemFontFamily> parseSystemFontChannelResult(Object? raw) {
  if (raw is! List) return const <SystemFontFamily>[];
  final Map<String, SystemFontFamily> byKey = <String, SystemFontFamily>{};
  for (final Object? item in raw) {
    String? family;
    bool? supportsJapanese;
    if (item is String) {
      family = item;
    } else if (item is Map) {
      final Object? rawFamily = item['family'];
      if (rawFamily is String) family = rawFamily;
      final Object? rawJa = item['supportsJapanese'];
      if (rawJa is bool) supportsJapanese = rawJa;
    }
    final String trimmed = family?.trim() ?? '';
    if (trimmed.isEmpty || trimmed.startsWith('@')) continue;
    byKey.putIfAbsent(
      trimmed.toLowerCase(),
      () =>
          SystemFontFamily(family: trimmed, supportsJapanese: supportsJapanese),
    );
  }
  return _sorted(byKey.values);
}

List<SystemFontFamily> _sorted(Iterable<SystemFontFamily> families) =>
    families.toList()..sort(
      (SystemFontFamily a, SystemFontFamily b) =>
          a.family.toLowerCase().compareTo(b.family.toLowerCase()),
    );

/// 系统字体清单的唯一入口（字体库「添加系统字体」浏览页用）。
///
/// 顺序：平台通道（各端原生 API 给真实族名）→ Linux `fc-list` → 扫字体目录按
/// 文件名推名（标记 [SystemFontList.namesReliable] = false）。成功结果进程内缓存。
abstract class SystemFontCatalog {

  static SystemFontList? _cache;

  /// 测试注入：替换真实平台枚举。
  @visibleForTesting
  static Future<SystemFontList> Function()? debugLoaderOverride;

  static Future<SystemFontList> load() async {
    final SystemFontList? cached = _cache;
    if (cached != null) return cached;
    final SystemFontList result = (await _loadFromPlatform());
    if (result.families.isNotEmpty) _cache = result;
    return result;
  }

  static Future<SystemFontList> _loadFromPlatform() async {
    final List<SystemFontFamily> fromChannel = await _loadFromChannel();
    if (fromChannel.isNotEmpty) {
      return SystemFontList(families: fromChannel, namesReliable: true);
    }
    return SystemFontList.empty;
  }

  static Future<List<SystemFontFamily>> _loadFromChannel() async {
    try {
      final Object? raw = await FushiChannels.fonts.invokeMethod<Object?>(
        'listSystemFonts',
      );
      return parseSystemFontChannelResult(raw);
    } on MissingPluginException {
      // 该平台宿主没实现（例如 Linux runner），走下一级兜底。
      return const <SystemFontFamily>[];
    } catch (e, stack) {
      ErrorLogService.instance.log('SystemFontCatalog.channel', e, stack);
      return const <SystemFontFamily>[];
    }
  }

}
