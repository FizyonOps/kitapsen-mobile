// 偏好 KV / 最近打开流 / 搜索历史 / 有声书（God 类拆分 2026-08：part+mixin，仓库 reader_fushi
// part 先例；mixin 是真类成员——可被测试子类 override、虚分派正常
// （extension 方案在此翻车过）；私有 mixin 不进公共 API 面。
part of 'database.dart';

mixin _FushiDbPrefsMedia
    on _$FushiDatabase, _FushiDbInfra, _FushiDbLibrary, _FushiDbTagsSync {
  // ── preferences helpers ─────────────────────────────────────────
  Future<String?> getPref(String key) async {
    final q = select(preferences)..where((t) => t.key.equals(key));
    final row = await q.getSingleOrNull();
    return row?.value;
  }

  /// 一次取回全部以 [prefix] 开头的偏好（key → value）。
  ///
  /// 「每本一个键」的偏好族（有声书健康度覆盖等）在列表页要为每本各查一次
  /// [getPref]，库越大 N+1 越重；这里一条 `LIKE 'prefix%'` 取完。[prefix] 里的
  /// `%` / `_` 按字面转义，不当通配符。
  Future<Map<String, String>> getPrefsByPrefix(String prefix) async {
    final String escaped = prefix
        .replaceAll(r'\', r'\\')
        .replaceAll('%', r'\%')
        .replaceAll('_', r'\_');
    final SimpleSelectStatement<$PreferencesTable, PreferenceRow> q =
        select(preferences)
          ..where((t) => t.key.like('$escaped%', escapeChar: r'\'));
    final List<PreferenceRow> rows = await q.get();
    return <String, String>{
      for (final PreferenceRow row in rows) row.key: row.value,
    };
  }

  Future<void> setPref(String key, String value) async {
    // BUG-906 (A): the business write and the version bump MUST land in one
    // transaction. Previously these were two independent awaits, so two
    // concurrent setPref calls could interleave between the insert and the
    // read-modify-write bump inside [_bumpPrefsVersion], losing an increment
    // (both read version=N, both write N+1) → :popup keeps serving a stale
    // pref cache. drift serializes transactions on the single write connection,
    // so wrapping insert+bump makes the whole write atomic w.r.t. any other
    // transactional pref write: no lost increments, and a cross-process reader
    // never observes the new value paired with a stale version.
    await transaction(() async {
      await into(preferences).insertOnConflictUpdate(
        PreferencesCompanion.insert(
          key: key,
          value: value,
          // BUG-1502: every local write stamps `now`. Without it the upsert
          // would leave `updated_at` at whatever it was (DO UPDATE SET only
          // touches columns present in the companion), so a locally renamed
          // book would keep an ancient stamp and lose the cross-device LWW.
          updatedAt: Value<int>(DateTime.now().millisecondsSinceEpoch),
        ),
      );
      // Bump the cross-process change signal for every real pref write. Skip
      // the version key itself (a direct write of it — e.g. a sync/backup
      // restore replaying the persisted counter — must NOT recursively bump on
      // top of its own value, which would double-count and break monotonic
      // alignment).
      if (key != FushiDatabase.prefsVersionKey) {
        await _bumpPrefsVersion();
      }
    });
  }

  /// Atomically replaces one preference only while its raw persisted value is
  /// still [expectedValue]. A successful non-version write advances
  /// [FushiDatabase.prefsVersionKey] in the same transaction; a failed comparison changes
  /// neither row.
  ///
  /// This is the DB-level primitive for migrations that start from a cached
  /// preference snapshot. An unconditional [setPref] would let an old process
  /// overwrite a newer cross-process choice after its snapshot went stale.
  Future<bool> compareAndSetPref(
    String key, {
    required String expectedValue,
    required String newValue,
  }) async {
    return transaction(() async {
      final int updated = await (update(preferences)
            ..where(
              (t) => t.key.equals(key) & t.value.equals(expectedValue),
            ))
          .write(
        PreferencesCompanion(
          value: Value<String>(newValue),
          // BUG-1502: same rule as [setPref] — a successful local write is a
          // write, and must advance the LWW stamp.
          updatedAt: Value<int>(DateTime.now().millisecondsSinceEpoch),
        ),
      );
      if (updated != 1) return false;
      if (key != FushiDatabase.prefsVersionKey) {
        await _bumpPrefsVersion();
      }
      return true;
    });
  }

  /// Atomically increment the persisted prefs-version directly in the DB so the
  /// next cross-process read observes a strictly larger value. Encoded as a
  /// PrefCodec int (`i:N`) so it round-trips identically to every other int
  /// preference. Writes via the raw [into]/[insertOnConflictUpdate] path (NOT
  /// [setPref]) to avoid re-entering the recursion guard above.
  ///
  /// BUG-906 (A): this read-modify-write is NOT atomic on its own. It MUST be
  /// called from within an enclosing transaction — which its only two callers
  /// ([setPref] and [compareAndSetPref]) now both provide — so that drift's
  /// single-writer transaction lock serializes the read+write against every
  /// other pref write. Called bare (outside a transaction) it can lose
  /// increments under concurrency; do not add such a caller.
  Future<void> _bumpPrefsVersion() async {
    final String? raw = await getPref(FushiDatabase.prefsVersionKey);
    final int current = raw == null ? 0 : PrefCodec.decode<int>(raw, 0);
    await into(preferences).insertOnConflictUpdate(
      PreferencesCompanion.insert(
        key: FushiDatabase.prefsVersionKey,
        value: PrefCodec.encode(current + 1),
      ),
    );
  }

  /// Adopts a preference value that came from ANOTHER device, last-write-wins
  /// (BUG-1502). Returns whether the row was actually written.
  ///
  /// This is the single cross-device merge primitive for preference rows that
  /// are CONTENT rather than device settings (today: the `override_title://`
  /// rename rows, BUG-1488). Its three properties are the whole point:
  ///
  ///  - **Stamps [updatedAt], not `now`.** Adopting with `now` would make this
  ///    device's copy permanently the newest, so the origin device's NEXT
  ///    rename could never land again — exactly the bug this replaces.
  ///  - **Strictly-newer wins; ties keep the local row.** A tie is either two
  ///    pre-v84 rows (both stamped 0 = "unknown", see [Preferences.updatedAt])
  ///    or an old peer that sends no stamp at all (decoded as 0). Keeping local
  ///    on a tie makes both cases degrade to the previous insert-if-absent
  ///    behaviour — an old peer can never clobber a name this user just typed.
  ///  - **Absent row always adopts** (`NOT EXISTS` beats any comparison), so a
  ///    book this device has never renamed still picks up the peer's name even
  ///    when the peer sends stamp 0.
  ///
  /// Bumps the cross-process prefs version exactly when it writes, so a popup /
  /// second process re-reads instead of serving a stale cached name.
  Future<bool> setPrefIfNewer(
    String key,
    String value, {
    required int updatedAt,
  }) async {
    return transaction(() async {
      final PreferenceRow? existing = await (select(preferences)
            ..where((t) => t.key.equals(key)))
          .getSingleOrNull();
      if (existing != null && existing.updatedAt >= updatedAt) return false;
      await into(preferences).insertOnConflictUpdate(
        PreferencesCompanion.insert(
          key: key,
          value: value,
          updatedAt: Value<int>(updatedAt),
        ),
      );
      if (key != FushiDatabase.prefsVersionKey) {
        await _bumpPrefsVersion();
      }
      return true;
    });
  }

  Future<void> deletePref(String key) async {
    await (delete(preferences)..where((t) => t.key.equals(key))).go();
  }

  Future<Map<String, String>> getAllPrefs() async {
    final rows = await select(preferences).get();
    return Map.fromEntries(rows.map((r) => MapEntry(r.key, r.value)));
  }

  // ── media open history（v78：取代 media_items）─────────────────────
  Future<List<MediaOpenHistoryRow>> getAllMediaOpenHistory() =>
      (select(mediaOpenHistory)
            ..orderBy([(t) => OrderingTerm.desc(t.openedAt)]))
          .get();

  Future<int> deleteMediaOpenHistory(String mediaSource, String mediaId) =>
      (delete(mediaOpenHistory)
            ..where((t) =>
                t.mediaSource.equals(mediaSource) & t.mediaId.equals(mediaId)))
          .go();
}
