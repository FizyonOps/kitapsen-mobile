
import 'package:path/path.dart' as path;

/// 选中的文件不是一个可用的本地音频源库（不是 Yomitan「本地音频服务器」SQLite，
/// 或库里没有任何音频）。[LocalAudioManager.importFile] 在把文件收进库前抛出，
/// 让上层给用户一句「这不是有效音频数据库」，而不是把没用的 zip / 备份 zip 当成
/// 音频源静默导入成空音频（BUG-779）。
abstract class InvalidLocalAudioDbException implements Exception {

}

abstract class LocalAudioManager {

  /// 内部副本命名（[importFile] 生成、[pruneOrphans] 回收的形状）：
  /// `local_audio_<数字标识>.db`（兼容旧时间戳；新文件附加进程 ID）。
  /// 是判定「可跨机按文件名归一」的唯一真值。
  static final RegExp _internalCopyNamePattern =
      RegExp(r'^local_audio_\d+\.db$');

  /// 同时容忍 `/` 与 `\` 的 basename（不依赖运行平台的 [path.basename] 语义，
  /// 兼容跨 OS 备份：Windows 备份在 POSIX 机导入时反斜杠也要被切掉）。
  static String _basenameAnySep(String p) {
    int cut = -1;
    for (int i = p.length - 1; i >= 0; i--) {
      final String c = p[i];
      if (c == '/' || c == '\\') {
        cut = i;
        break;
      }
    }
    return cut < 0 ? p : p.substring(cut + 1);
  }

  /// [dbPath] 的 basename 是否是内部副本命名。跨机导入后目录前缀是**源机**的，
  /// 只有文件名可信，故只按 basename 判断（[resolveInternalPath] 据此归一）。
  static bool isInternalCopyName(String dbPath) =>
      dbPath.isNotEmpty &&
      _internalCopyNamePattern.hasMatch(_basenameAnySep(dbPath));

  /// 把一条存储的 localAudio 库路径归一到本机库目录 [dir]：内部副本按**文件名**
  /// 重挂到 `<dir>/<basename>`（跨机可移植——丢弃源机绝对前缀，只认文件名，修
  /// TODO-1171：换机后源机绝对 path 不存在导致本地发音静默消失）；外部引用
  /// （BUG-483 引用模式，命名不匹配）原样返回（本就无法跨机，保留原值等重指）。
  static String resolveInternalPath(String storedPath, String dir) =>
      isInternalCopyName(storedPath)
          ? path.join(dir, _basenameAnySep(storedPath))
          : storedPath;

}
