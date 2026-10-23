import 'dart:io';

import 'package:path/path.dart' as p;

const String _dartDefineTestRoot = String.fromEnvironment('FUSHI_TEST_ROOT');

String? fushiTestRootPath({
  Map<String, String>? environment,
  String dartDefineRoot = _dartDefineTestRoot,
}) {
  final String raw = ((environment ?? Platform.environment)['FUSHI_TEST_ROOT'] ?? '');
  if (raw.trim().isEmpty) {
    return null;
  }
  return Directory(raw).absolute.path;
}

Directory? fushiTestDirectory(
  String child, {
  Map<String, String>? environment,
  String dartDefineRoot = _dartDefineTestRoot,
}) {
  final String? root = fushiTestRootPath(
    environment: environment,
    dartDefineRoot: dartDefineRoot,
  );
  if (root == null) {
    return null;
  }
  final Directory directory = Directory(p.join(root, child));
  if (!directory.existsSync()) {
    directory.createSync(recursive: true);
  }
  return directory;
}
