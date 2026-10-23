import 'dart:convert';

/// Rewrites an absolute [oldPath] that lives under [oldRoot] so it lives under
/// [newRoot] instead, preserving the sub-path. Returns [oldPath] verbatim when
/// it is not under [oldRoot] (already local, or an unrelated location).
///
/// A full-data backup stores file paths captured on the SOURCE device. On the
/// importing device the app directories differ (iOS reassigns the container
/// UUID on every reinstall), so the stored absolute paths would not resolve.
/// Import rebases every stored path from the backup's recorded root to this
/// device's matching root. Separators are normalized so `/` vs `\` differences
/// between the compared strings don't defeat the prefix match.
String rebasePath(String oldPath, String oldRoot, String newRoot) {
  String stripTrailing(String s) =>
      (s.endsWith('/') || s.endsWith('\\')) ? s.substring(0, s.length - 1) : s;
  // Normalize separators ONLY for the prefix comparison; the returned path
  // keeps the source path's original separators (a POSIX backup restored on a
  // POSIX host must not gain Windows separators just because p.join would, and
  // vice-versa). So we slice the original oldPath rather than rebuild via join.
  final String nrOld = stripTrailing(oldRoot.replaceAll('\\', '/'));
  final String npOld = oldPath.replaceAll('\\', '/');
  if (npOld == nrOld) return stripTrailing(newRoot);
  // Require a separator boundary so "/a/books_extra" is not treated as under
  // "/a/books". replaceAll preserves length, so nrOld.length indexes the
  // original oldPath correctly.
  if (!npOld.startsWith('$nrOld/')) return oldPath;
  final String suffix = oldPath.substring(nrOld.length); // keeps leading sep
  return stripTrailing(newRoot) + suffix;
}

/// Rebases every file-font `path` inside a persisted font-list JSON string
/// (`[{name, path, enabled}, ...]`) from [oldRoot] onto [newRoot] via
/// [rebasePath]. System fonts (`path == null`) and paths not under [oldRoot]
/// are left untouched. A malformed value (not a JSON list of maps) is returned
/// verbatim so a corrupt pref never aborts the import.
///
/// Custom fonts live under the SOURCE device's `<appDoc>/custom_fonts`; the
/// importing device's root differs, so the stored absolute paths would not
/// resolve and the fonts (shown as imported & enabled) would silently never
/// apply (BUG-183). Import rebases them so the reader/AppFontLoader find them.
String rebaseFontListJson(String json, String oldRoot, String newRoot,
    {String Function(String path)? rewritePath}) {
  String rewrite(String path) => rewritePath == null
      ? rebasePath(path, oldRoot, newRoot)
      : rewritePath(path);
  try {
    final dynamic decoded = jsonDecode(json);
    if (decoded is! List) return json;
    final List<dynamic> out = decoded.map<dynamic>((dynamic e) {
      if (e is! Map) return e;
      final Object? path = e['path'];
      if (path is! String) return e; // system font (null) or odd shape
      return <String, dynamic>{
        ...Map<String, dynamic>.from(e),
        'path': rewrite(path),
      };
    }).toList();
    return jsonEncode(out);
  } catch (_) {
    return json; // never throw on a corrupt pref value
  }
}

/// Rebases every file-font `path` inside the canonical font catalog JSON
/// (`{version, fonts:[{id, name, path}]}`) from [oldRoot] onto [newRoot].
/// Target rows (`font_targets`) refer to catalog entries by id and do not carry
/// paths, so preserving ids while rebasing catalog paths keeps targets valid.
/// Malformed values are returned verbatim so a corrupt pref never aborts import.
String rebaseFontCatalogJson(String json, String oldRoot, String newRoot,
    {String Function(String path)? rewritePath}) {
  String rewrite(String path) => rewritePath == null
      ? rebasePath(path, oldRoot, newRoot)
      : rewritePath(path);
  try {
    final dynamic decoded = jsonDecode(json);
    if (decoded is! Map) return json;
    final Map<String, dynamic> root = Map<String, dynamic>.from(decoded);
    final dynamic fonts = root['fonts'];
    if (fonts is! List) return json;
    root['fonts'] = fonts.map<dynamic>((dynamic e) {
      if (e is! Map) return e;
      final Map<String, dynamic> row = Map<String, dynamic>.from(e);
      final Object? path = row['path'];
      if (path is! String) return row;
      return <String, dynamic>{
        ...row,
        'path': rewrite(path),
      };
    }).toList();
    return jsonEncode(root);
  } catch (_) {
    return json; // never throw on a corrupt pref value
  }
}
