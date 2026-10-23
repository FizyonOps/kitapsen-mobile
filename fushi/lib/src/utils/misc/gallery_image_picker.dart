import 'dart:io';

import 'package:file_picker/file_picker.dart';

/// 「选一张图片」的统一入口：file_picker 的 `FileType.image` 系统选择器
/// （Android / iOS 都由它弹出系统照片 / 文件界面）。
Future<File?> pickGalleryImageFile() async {
  final FilePickerResult? result = await FilePicker.platform.pickFiles(
    type: FileType.image,
  );
  if (result == null || result.files.isEmpty) return null;
  final String? pickedPath = result.files.first.path;
  if (pickedPath == null || pickedPath.isEmpty) return null;
  return File(pickedPath);
}
