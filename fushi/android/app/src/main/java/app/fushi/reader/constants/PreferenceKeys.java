package app.fushi.reader.constants;

/**
 * SharedPreferences file names and key constants for Hibiki services.
 *
 * <p><strong>Do not rename these values.</strong> They are persisted to disk;
 * renaming without a migration will silently lose stored data on existing
 * installs.</p>
 */
public final class PreferenceKeys {

    private PreferenceKeys() {}

    // ── SharedPreferences file names ─────────────────────────────────────────

    /** Prefs file used by {@code MainActivity} for splash/theme persistence. */
    public static final String FILE_SPLASH = "hibiki_splash";

    // ── Splash / theme keys (MainActivity) ───────────────────────────────────

    /** Stored background colour as a packed ARGB int. */
    public static final String SPLASH_BG_COLOR = "bg_color";

    /** Stored dark-mode flag. */
    public static final String SPLASH_IS_DARK = "is_dark";
}
