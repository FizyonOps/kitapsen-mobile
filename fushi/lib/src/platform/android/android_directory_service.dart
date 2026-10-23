import 'dart:io';

import 'package:fushi_platform/fushi_platform.dart';
import 'package:path/path.dart' as p;

class AndroidDirectoryService implements PlatformDirectoryService {

  @override
  Future<void> excludeFromMediaScanner(String directoryPath) async {
    final noMedia = File(p.join(directoryPath, '.nomedia'));
    if (!noMedia.existsSync()) {
      noMedia.createSync();
    }
  }
}
