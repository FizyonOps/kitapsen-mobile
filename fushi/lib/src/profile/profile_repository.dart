import 'package:fushi_core/fushi_core.dart';
import 'package:fushi/src/media/media_source.dart';
import 'package:fushi/src/models/preferences_repository.dart';
import 'package:fushi/src/profile/language_binding.dart';
import 'package:fushi/src/profile/profile_keys.dart';
import 'package:fushi/src/media/sources/reader_fushi_source.dart';

class ProfileRepository {
  ProfileRepository(this._db);
  final FushiDatabase _db;

  Future<List<ProfileRow>> getAllProfiles() => _db.getAllProfiles();

  Future<int> getActiveProfileId() async {
    final raw = await _db.getPref('active_profile_id');
    return raw != null ? (int.tryParse(raw) ?? -1) : -1;
  }

  Future<void> setActiveProfileId(int id) =>
      _db.setPref('active_profile_id', id.toString());

  Future<int> createProfile(String name) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = await _db.insertProfile(
      ProfilesCompanion.insert(
        name: name,
        createdAt: now,
        updatedAt: now,
      ),
    );
    return id;
  }

  Future<void> snapshotCurrentSettings(int profileId) async {
    // Profile ids are autoincrement (always >= 1); a non-positive id is the
    // "no active profile" sentinel (e.g. ProfileViewModel.dispose fires before
    // _load assigns a real id, so state.activeProfileId is still -1).
    // Snapshotting it would write orphan profile_settings rows / trip the FK.
    if (profileId <= 0) return;

    final entries = <ProfileSettingsCompanion>[];

    // Anki settings (SharedPreferences)

    // ALL Drift prefs (excluding app-state keys)
    final allPrefs = await _db.getAllPrefs();
    for (final entry in allPrefs.entries) {
      if (ProfileKeys.isExcludedPref(entry.key)) continue;
      entries.add(ProfileSettingsCompanion.insert(
        profileId: profileId,
        category: ProfileKeys.categoryPref,
        key: entry.key,
        value: entry.value,
      ));
    }

    await _db.replaceProfileSettings(profileId, entries);
  }

  Future<void> applyProfile(int profileId) async {
    // A non-positive (sentinel) id has no snapshot rows, so the prune step
    // below would delete EVERY non-excluded live pref — silent settings wipe.
    // Ids are always >= 1, so guard the sentinel instead of nuking prefs.
    if (profileId <= 0) return;

    final rows = await _db.getProfileSettings(profileId);

    final prefMap = <String, String>{};
    for (final row in rows) {
      switch (row.category) {
        case ProfileKeys.categoryPref:
          prefMap[row.key] = row.value;
        case ProfileKeys.categoryReader:
          // 旧快照里 reader 偏好按 MediaSource 命名空间还原；用单一真相编码器
          // 而非硬编码 `src:reader_fushi:` 猜下层私有 key 格式（[dbSourcePrefKey]）。
          prefMap[dbSourcePrefKey(kReaderSourcePersistedKey, row.key)] =
              row.value;
        default:
          break;
      }
    }

    // BUG-1019: old snapshots (taken before a key entered the exclusion list,
    // e.g. audiobook_pos_* / audiobook_speed_* / override_title://*) may still
    // carry excluded keys. Apply must neither restore those stale values (a
    // months-old speed/position overwriting the live one) nor delete the live
    // rows (the prune loop below already skips excluded keys) — so drop them
    // from the restore map here. Same single source of truth as snapshot/prune:
    // [ProfileKeys.isExcludedPref].
    prefMap
        .removeWhere((String key, String _) => ProfileKeys.isExcludedPref(key));

    // Wrap DB writes in transaction for consistency
    await _db.transaction(() async {
      final currentPrefs = await _db.getAllPrefs();
      for (final key in currentPrefs.keys) {
        if (ProfileKeys.isExcludedPref(key)) continue;
        if (!prefMap.containsKey(key)) {
          await _db.deletePref(key);
        }
      }
      for (final entry in prefMap.entries) {
        // [FushiDatabase.setPref] auto-bumps the persisted prefs-version
        // (TODO-855) for every non-version key written here, so the common
        // profile switch (which always writes at least one pref) is already
        // signalled to the :popup process.
        await _db.setPref(entry.key, entry.value);
      }
      // TODO-855: guarantee a bump even for the edge cases the per-key
      // auto-bump above does NOT cover — a switch into a profile with an empty
      // snapshot, or one whose only effect is deleting prefs (deletePref does
      // not bump). Read the CURRENT (post-loop, already-bumped) version and add
      // one more so the counter is always present and strictly monotonic; an
      // extra increment on top of the per-key bumps is harmless (the popup just
      // reloads once on its next lookup). Written through _db.setPref against
      // the version key itself, whose recursion guard skips re-bumping, so this
      // does NOT double-count. prefs_version is excluded from profile snapshots,
      // so it is neither pruned above nor present in prefMap.
      final String? rawVersion =
          await _db.getPref(PreferencesRepository.prefsVersionKey);
      final int nextVersion =
          (rawVersion == null ? 0 : PrefCodec.decode<int>(rawVersion, 0)) + 1;
      await _db.setPref(
        PreferencesRepository.prefsVersionKey,
        PrefCodec.encode(nextVersion),
      );
    });

    // Anki settings (SharedPreferences)
  }

  /// 全部媒体类型绑定的**裸串视图**（key = [ProfileMediaKind.dbValue]；DB 列
  /// 接受任意串，历史行可能含旧值域，原样透传不丢行）。
  Future<Map<String, int>> getAllMediaTypeBindings() async {
    final rows = await _db.getAllMediaTypeProfiles();
    return {for (final r in rows) r.mediaType: r.profileId};
  }

  /// 全部语言绑定（key = **归一化后**的语言标签，如 `ja` / `zh-Hant`）。
  ///
  /// 读侧也过一次 [normalizeLanguageBinding]：存量行理论上都是写侧归一过的，
  /// 但 DB 是自由文本列，手工改库 / 旧备份导入都可能塞进未归一的键。读侧再归一
  /// 一次让它们至少能被 UI 看见并改掉，而不是变成一行永远命不中的幽灵绑定。
  /// 归一后为空的行（`und` / 垃圾串）直接丢弃——它们不对应任何可路由的语言。
  Future<Map<String, int>> getAllLanguageBindings() async {
    final rows = await _db.getAllLanguageProfiles();
    final Map<String, int> out = <String, int>{};
    for (final r in rows) {
      final String key = normalizeLanguageBinding(r.languageTag);
      if (key.isEmpty) continue;
      out[key] = r.profileId;
    }
    return out;
  }

  Future<int?> getBookProfileId(String bookUid) async {
    final row = await _db.getBookProfile(bookUid);
    return row?.profileId;
  }

  Future<void> setBookProfile(String bookUid, int profileId) =>
      _db.setBookProfile(bookUid, profileId);

  Future<void> removeBookProfile(String bookUid) =>
      _db.deleteBookProfile(bookUid);

  /// 解析该打开哪个 Profile：**book > language > mediaType > active**。
  ///
  /// 语言排在 book 之下、mediaType 之上：book 级是用户对单个条目的明确指令，压过
  /// 一切；而「用哪套词典 / 哪个 Anki 牌组」由内容语言决定的程度，远高于由「这是
  /// EPUB 还是视频」决定的程度——300 本书不可能一本本绑 book 级，媒体类型又粗到
  /// 把日文书和英文书归成同一个 `epub`。
  ///
  /// [languageTag] 传原始内容语言串即可（内部归一）。**为空 / 不可识别时整级跳过**，
  /// 落到 mediaType，行为与语言绑定引入前逐字节一致。调用方绝不应为了「填一个值」
  /// 而把全局默认内容语言喂进来：那会让所有未标注条目一起路由到同一个 Profile，
  /// 且用户改一次全局默认就整批跳档——那不是按语言绑定，是多了一个全局开关。
  Future<int> resolveProfileId({
    required String? bookUid,
    String? languageTag,
    required ProfileMediaKind? mediaType,
  }) async {
    if (bookUid != null) {
      final bookProfileId = await getBookProfileId(bookUid);
      if (bookProfileId != null) return bookProfileId;
    }

    final String languageKey = normalizeLanguageBinding(languageTag);
    if (languageKey.isNotEmpty) {
      final langRow = await _db.getLanguageProfile(languageKey);
      if (langRow != null) return langRow.profileId;
    }

    if (mediaType != null) {
      final mtRow = await _db.getMediaTypeProfile(mediaType.dbValue);
      if (mtRow != null) return mtRow.profileId;
    }

    return getActiveProfileId();
  }

  // ── 导出 / 导入（单 Profile JSON 序列化）────────────────────────────

  Future<void> ensureDefaultProfile() async {
    final existing = await _db.getAllProfiles();
    if (existing.isEmpty) {
      final id = await createProfile('Default');
      await setActiveProfileId(id);
      await snapshotCurrentSettings(id);
      return;
    }

    final activeId = await getActiveProfileId();
    final valid = existing.any((p) => p.id == activeId);
    if (!valid) {
      await setActiveProfileId(existing.first.id);
      await applyProfile(existing.first.id);
    }
  }
}
