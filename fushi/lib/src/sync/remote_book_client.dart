import 'dart:io';

import 'package:fushi_engine/sync/fushi_library_host_service.dart';
import 'package:fushi/src/sync/remote_library_source.dart';

abstract class RemoteBookClient implements RemoteLibrarySource {

  Future<List<RemoteBookInfo>> listRemoteBooks();

  Future<void> getRemoteBook(
    String title,
    File destination, {
    void Function(double progress)? onProgress,
  });

  /// 读 host 端记录的书 [bookKey] 阅读进度（TODO-767 跨设备同步）。
  /// 无记录或不支持时返回 [RemoteBookProgress.empty]。
  Future<RemoteBookProgress> remoteBookProgress(String bookKey);

}
