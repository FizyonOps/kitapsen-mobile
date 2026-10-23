import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:fushi_core/fushi_core.dart';
import 'package:fushi/src/media/media_source.dart';
import 'package:fushi/src/models/preferences_repository.dart';
import 'package:fushi/src/profile/language_binding.dart';
import 'package:fushi/src/profile/profile_keys.dart';
import 'package:fushi/src/media/sources/reader_fushi_source.dart';

// 分享 JSON 的模型与异常已下沉引擎（服务端共用），这里转出，调用方 import 不变。
export 'package:fushi_engine/profile/profile_document.dart'
    show ProfileExport, ProfileImportException, ProfileSettingEntry;

class ProfileRepository {
  ProfileRepository(
    this._db, {
    bool Function(String name)? isDictionaryInstalled,
  }) : _isDictionaryInstalled = isDictionaryInstalled;
  final FushiDatabase _db;

  /// 「这本词典**真的装着**吗」的唯一真值源：磁盘上有没有
  /// `dictionaryResourceDirectory/<name>/`。元数据行的存在性**不是**这个判据——
  /// BUG-1994 的旧 prune 恰恰会把已安装词典的行删掉。
  ///
  /// 可空：不注入时 [applyProfile] 一律不回插（等于「无法证明装着」）。测试与
  /// 不关心词典的调用方保持零依赖。
  final bool Function(String name)? _isDictionaryInstalled;

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

    // TODO-1077: dictionary enable-list / order / source / language visibility
    // live in the standalone `dictionary_metadata` table, not in prefs, so they
    // were previously shared across all profiles. Snapshot one row per
    // dictionary (key = dictionary name) into the dedicated
    // [ProfileKeys.categoryDictionaryMeta] category so they follow the profile.
    final List<DictionaryMetaRow> dictRows =
        await _db.getAllDictionaryMetadata();
    for (final DictionaryMetaRow row in dictRows) {
      entries.add(ProfileSettingsCompanion.insert(
        profileId: profileId,
        category: ProfileKeys.categoryDictionaryMeta,
        key: row.name,
        value: _encodeDictionaryMeta(row),
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

    final ankiMap = <String, String>{};
    final prefMap = <String, String>{};
    // TODO-1077: snapshot rows for the dictionary_metadata table. `hasDictMeta`
    // distinguishes "profile has no dictionary_meta snapshot at all" (old
    // snapshot, pre-TODO-1077) from "profile intentionally has zero
    // dictionaries". Only the latter may prune the live table; the former MUST
    // be left untouched so a switch never wipes the shared dictionary config.
    final Map<String, DictionaryMetadataCompanion> dictMetaMap =
        <String, DictionaryMetadataCompanion>{};
    bool hasDictMeta = false;
    for (final row in rows) {
      switch (row.category) {
        case ProfileKeys.categoryAnki:
          ankiMap[row.key] = row.value;
        case ProfileKeys.categoryPref:
          prefMap[row.key] = row.value;
        case ProfileKeys.categoryDictionaryMeta:
          hasDictMeta = true;
          final DictionaryMetadataCompanion? companion =
              _decodeDictionaryMeta(row.key, row.value);
          // Defensive: a single corrupt row degrades gracefully (skipped)
          // instead of aborting the whole profile-apply (mirrors the Anki
          // fieldMappings try/catch, HBK-AUDIT-043).
          if (companion != null) dictMetaMap[row.key] = companion;
        // Legacy categories from old snapshots
        case ProfileKeys.categoryDictionary:
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
      // BUG-1994: profile 只拥有「怎么排、开不开」，**不拥有「装了哪些」**。
      //
      // TODO-1077 原来的做法是「快照即真相」：upsert 快照里的每一行，再删掉快照
      // 没有的 live 行（照抄上面 pref 的 prune）。那等于把「这本词典启用中」编码
      // 成「元数据行存在」，可这一行同时还承载「这本词典已安装」这个**全局**事实
      // ——两个正交语义挤进同一个存在性判据。后果是在 A 里导入的词典，切到更早
      // 建的 B 时被当成「B 没启用它」而整行删掉，B 的词典库里直接消失（明镜/牛津
      // 只差一个「在 B 建立之前还是之后导入」）。开关和顺序本来就是行内的列
      // （hiddenLanguagesJson / order），行的存在性根本不该再兼任开关。
      //
      // 所以：不再 prune，只把 profile 拥有的四列写回**已存在**的行。
      //
      // 更新命中 0 行 = 快照有这个名字、库里没有这一行。这里有两种真实成因，靠
      // 「磁盘上有没有 `dictionaryResourceDirectory/<name>/`」区分——**元数据行在
      // 不在**从来就不是「装没装」的判据（那正是本 bug 的病根）：
      //   * 目录不存在 → 词典真的被删了，快照比库旧。跳过，绝不 insert（插进去
      //     就是一行没有磁盘目录的幽灵元数据）。
      //   * 目录还在   → 这一行是被旧版本的 prune 删掉的**真行**，词典还躺在磁盘
      //     上。按快照整行补回来。旧实现里这条自愈是 `upsertDictionaryMeta` 顺带
      //     给的（用户报告 T5「切回 A 牛津又出现」），一并砍掉会把「切回去就有」
      //     变成「永远没有」——升级时正停在受害 profile 的用户直接永久丢失。
      //     never break userspace：自愈保留，只是判据从「快照即真相」换成磁盘。
      // `hasDictMeta` 保留：前 TODO-1077 的旧快照没有 dictionary_meta 行，跳过整
      // 段即可，不能被误当成「没有词典」。
      if (hasDictMeta) {
        for (final MapEntry<String, DictionaryMetadataCompanion> entry
            in dictMetaMap.entries) {
          final DictionaryMetadataCompanion companion = entry.value;
          final int updated = await _db.applyDictionaryMetaProfileColumns(
            name: entry.key,
            order: companion.order.value,
            hiddenLanguagesJson: companion.hiddenLanguagesJson.value,
            collapsedLanguagesJson: companion.collapsedLanguagesJson.value,
            expandedLanguagesJson: companion.expandedLanguagesJson.value,
            languageOverride: companion.languageOverride.value,
          );
          if (updated == 0 &&
              (_isDictionaryInstalled?.call(entry.key) ?? false)) {
            await _db.upsertDictionaryMeta(companion);
          }
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

  // ── TODO-1077 dictionary_metadata snapshot serialization ────────────

  /// Serialize one `dictionary_metadata` row into the JSON value stored in a
  /// profile_settings row (key = dictionary name). Carries every profile-owned
  /// column: order, formatKey (source), type, and the language-visibility /
  /// metadata JSON blobs (kept as raw strings — they are already JSON).
  String _encodeDictionaryMeta(DictionaryMetaRow row) {
    return jsonEncode(<String, dynamic>{
      'order': row.order,
      'formatKey': row.formatKey,
      'type': row.type,
      'metadataJson': row.metadataJson,
      'hiddenLanguagesJson': row.hiddenLanguagesJson,
      'collapsedLanguagesJson': row.collapsedLanguagesJson,
      'expandedLanguagesJson': row.expandedLanguagesJson,
      'languageOverride': row.languageOverride,
    });
  }

  /// Decode a snapshot dictionary-meta value back into an upsert companion.
  /// Returns null (skip the row) on any malformed data — a single bad row must
  /// not abort the whole profile-apply (mirrors [ProfileKeys] Anki parsing,
  /// HBK-AUDIT-043). [name] is the profile_settings key (dictionary name / PK).
  DictionaryMetadataCompanion? _decodeDictionaryMeta(
      String name, String value) {
    try {
      final dynamic decoded = jsonDecode(value);
      if (decoded is! Map) return null;
      final Object? rawOrder = decoded['order'];
      final int order =
          rawOrder is int ? rawOrder : int.tryParse('$rawOrder') ?? 0;
      String asString(Object? v, String fallback) => v is String ? v : fallback;
      return DictionaryMetadataCompanion(
        name: Value(name),
        formatKey: Value(asString(decoded['formatKey'], '')),
        order: Value(order),
        type: Value(asString(decoded['type'], 'term')),
        metadataJson: Value(asString(decoded['metadataJson'], '{}')),
        hiddenLanguagesJson:
            Value(asString(decoded['hiddenLanguagesJson'], '[]')),
        collapsedLanguagesJson:
            Value(asString(decoded['collapsedLanguagesJson'], '[]')),
        // 旧快照没有这个键 → '[]' = 全部「继承」= 与 BUG-2158 之前的行为一致。
        expandedLanguagesJson:
            Value(asString(decoded['expandedLanguagesJson'], '[]')),
        // null（未指定）是合法值，不能像上面几个那样塞空串默认值——空串会让
        // effectiveSourceLanguage 的「非空即用户指定」判据失真。
        languageOverride: Value(decoded['languageOverride'] is String
            ? decoded['languageOverride'] as String
            : null),
      );
    } catch (_) {
      return null;
    }
  }

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
