
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, immutable;
import 'package:flutter/material.dart';
import 'package:fushi/utils.dart';
import 'package:path/path.dart' as p;

/// 平台交回了条目、却没有一条带可用路径（部分平台只回 bytes 不回 path）。
///
/// 与「用户取消」必须区分（BUG-446）：取消是静默返回，这个是**失败**，调用方要记
/// 诊断并给用户可见反馈。压成同一个 null 就等于把一类失败伪装成一次取消。
class PickedFileWithoutPathException implements Exception {
  const PickedFileWithoutPathException({required this.count});

  /// 平台交回的条目数（用于诊断日志）。
  final int count;

  @override
  String toString() => 'PickedFileWithoutPathException(count: $count)';
}

/// 一次文件选择的结果：路径 **+ 这条路径是不是用户原始位置的真实路径**。
///
/// 为什么需要它（BUG-1667）：「选到的文件能不能长期引用」此前是调用点**按平台猜**的
/// ——本地音频库导入的「引用原文件不复制」开关直接写死 `isDesktopPlatform`，理由是
/// 「移动端 file_picker 给的是会被系统清掉的缓存临时副本」。可 [pickRealFilePath]
/// 落地后，安卓拿到全文件访问就走 SAF 解析真实路径、根本不产生副本，那条平台前提
/// 就不成立了。**平台不是判据，路径的出处才是**：把出处随路径一起返回，调用方按
/// 事实决策，「安卓一律不能引用」这个特例随之消失。
@immutable
class PickedFilePath {
  const PickedFilePath({required this.path, required this.isRealPath});

  /// 选中文件的绝对路径。
  final String path;

  /// true = 用户原始位置的真实路径，可被长期引用（桌面的 `pickFiles()`、
  /// 安卓 SAF 成功解析到原始位置）。全文件访问权限不保证 provider 能解析真实路径。
  ///
  /// false = 平台复制出来的**临时副本**：安卓 SAF / file_picker 的 app cache
  /// （SAF 用 `getCacheDir()/saf_pick/`，file_picker 用 `getCacheDir()/file_picker/`），
  /// 以及 iOS file_picker 的 import 模式（文件被挪进 `NSTemporaryDirectory()`，
  /// 只有被选中的那一个文件，同级兄弟不跟过来——BUG-2786）。
  /// 清缓存即失效，**只能立刻复制消费，不能作为长期引用落库**。
  final bool isRealPath;
}

/// 平台安全的「按扩展名选文件」，语义等同
/// `FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: …)`，
/// 差别只在**移动端不把扩展名过滤交给平台**（见 [_platformDropsUnknownExtensions]）。
///
/// 什么时候用它、什么时候用 [pickSystemFilePath]：只要路径就用后者（更薄）；需要
/// 平台交回的其它字段（`withData: true` 的 bytes、多选的 `files` 列表）才用这个。
///
/// 返回的 [FilePickerResult] 原样保留平台交回的内容，只是 `files` 已按扩展名过滤；
/// 选中的文件全部不合格时返回 null（并已就地提示），与「用户取消」一样是空结果，
/// 调用方无需区分——需要区分的调用方走 [pickRealFilePathDetailed]。
Future<FilePickerResult?> pickFilesByExtensions({
  required BuildContext? context,
  Iterable<String>? allowedExtensions,
  bool allowMultiple = false,
  bool withData = false,
  String? dialogTitle,
  String? initialDirectory,
}) async {
  final Set<String> extensions = _normalizeExtensions(allowedExtensions);
  final bool filterAfterPick =
      _platformDropsUnknownExtensions && extensions.isNotEmpty;
  final bool nativeFilter = extensions.isNotEmpty && !filterAfterPick;

  final FilePickerResult? result = await FilePicker.platform.pickFiles(
    dialogTitle: dialogTitle,
    initialDirectory: initialDirectory,
    type: nativeFilter ? FileType.custom : FileType.any,
    allowedExtensions: nativeFilter ? extensions.toList() : null,
    allowMultiple: allowMultiple,
    withData: withData,
  );
  if (result == null || !filterAfterPick) return result;

  // 按 `name` 判定而非 `path`：部分平台只回 bytes 不回 path（BUG-446），拿 path
  // 当判据会把那些条目全判成「扩展名不合格」，把一类失败伪装成一次格式不符。
  final List<PlatformFile> accepted = <PlatformFile>[];
  final List<PlatformFile> rejected = <PlatformFile>[];
  for (final PlatformFile file in result.files) {
    if (extensions.contains(_extensionOf(file.name))) {
      accepted.add(file);
    } else {
      rejected.add(file);
    }
  }
  if (rejected.isNotEmpty) {
    _warnUnsupportedPick(
      context: context != null && context.mounted ? context : null,
      name: rejected.first.name,
    );
  }
  return accepted.isEmpty ? null : FilePickerResult(accepted);
}

/// 平台的原生「按扩展名过滤」是否会**静默丢弃**它不认识的扩展名。
///
/// 安卓与 iOS 都会（BUG-2099，详见 [_fallbackPickRaw] 里的完整说明）；桌面三端的
/// 原生对话框直接吃扩展名字符串，过滤可靠，维持原生过滤（选择器里只列相关文件，
/// 体验更好）。
bool get _platformDropsUnknownExtensions =>
    defaultTargetPlatform == TargetPlatform.iOS ||
    defaultTargetPlatform == TargetPlatform.android;

/// 文件名 / 路径的扩展名，小写、不带点（`a.MDX` → `mdx`；无扩展名 → 空串）。
String _extensionOf(String nameOrPath) =>
    p.extension(nameOrPath).toLowerCase().replaceFirst('.', '');

Set<String> _normalizeExtensions(Iterable<String>? extensions) {
  // 同上：本文件不向外交出不可变集合（零特例，省得下一个消费方 add 时再炸一次）。
  if (extensions == null || extensions.isEmpty) return <String>{};
  return extensions
      .map((String ext) => ext.toLowerCase().replaceFirst('.', ''))
      .where((String ext) => ext.isNotEmpty)
      .toSet();
}

/// 「选中的文件扩展名不在允许集」的统一提示。两条 Dart 端过滤路径（路径版
/// [_filterPickedFilesByExtension] 与结果版 [pickFilesByExtensions]）共用它，
/// 免得同一句提示在两处各写一遍、各自漂移。
///
/// [context] 为 null（页面已在原生选择器打开期间销毁）时只是不提示，过滤本身照常。
void _warnUnsupportedPick({
  required BuildContext? context,
  required String name,
}) {
  if (context == null) return;
  final String ext = p.extension(name).toLowerCase();
  FushiToast.show(
    msg: t.import_unsupported_file_format(
      ext: ext.isEmpty ? p.basename(name) : ext,
    ),
    severity: ToastSeverity.error,
  );
}
