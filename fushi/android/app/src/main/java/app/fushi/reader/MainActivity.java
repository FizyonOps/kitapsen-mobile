// Derived from the AnkiDroid API Sample

package app.fushi.reader;

import android.app.Activity;
import android.content.Intent;
import android.os.Build;
import android.os.Bundle;
import android.os.Environment;
import android.os.Handler;
import android.os.Looper;
import android.os.SystemClock;
import android.media.AudioManager;
import android.database.Cursor;
import android.provider.DocumentsContract;
import android.provider.MediaStore;
import android.provider.OpenableColumns;
import android.view.KeyEvent;
import android.view.MotionEvent;
import androidx.annotation.NonNull;
import android.net.Uri;

import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.embedding.engine.FlutterShellArgs;
import io.flutter.plugin.common.MethodChannel;

import android.content.SharedPreferences;
import android.graphics.drawable.ColorDrawable;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.OutputStream;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.TreeSet;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import app.fushi.reader.constants.ChannelNames;
import app.fushi.reader.constants.PreferenceKeys;

import androidx.documentfile.provider.DocumentFile;

import io.flutter.embedding.android.FlutterActivity;
import android.content.Context;
import android.content.res.Configuration;

// Kitapsen: only the channels of features the app shows are registered here.
// Anki, TTS, picture-in-picture, NFC pairing, Mihon extensions, the floating
// lyric / dictionary / ball overlays, screen and system OCR, the lookup IME
// hint, data migration, download keep-alive, the APK self-updater and the
// video brightness drag are not part of this edition, and neither are their
// Java / Kotlin classes. There is no audio_service player, so this is a plain
// FlutterActivity.
public class MainActivity extends FlutterActivity {
    private static final String VOLUME_KEY_CHANNEL = ChannelNames.VOLUME_KEYS;
    private static final String SAF_CHANNEL = ChannelNames.SAF;
    private static final String FONTS_CHANNEL = ChannelNames.FONTS;
    private static final String SPLASH_CHANNEL = ChannelNames.SPLASH;
    private static final String LIFECYCLE_CHANNEL = ChannelNames.LIFECYCLE;
    private static final String ICON_CHANNEL = ChannelNames.ICON_SWITCH;
    private static final String SPLASH_PREFS = PreferenceKeys.FILE_SPLASH;
    private static final int SAF_PICK_DIR_REQUEST = 1001;
    // Native SAF pickers that RESOLVE the picked content URI to a real
    // filesystem path (no copy). Distinct from the copy-based 1001 so
    // onActivityResult routes them to path resolution instead of a tree copy.
    private static final int SAF_PICK_REAL_DIR_REQUEST = 1003;
    private static final int SAF_PICK_REAL_FILE_REQUEST = 1004;

    private Activity context;
    private MethodChannel.Result pendingSafResult;
    private String pendingSafDestPath;
    private final ExecutorService ioExecutor = Executors.newFixedThreadPool(2);

    // Reader opens this gate when volume-key page turning is enabled so
    // dispatchKeyEvent swallows VOLUME_UP/DOWN and forwards them to Dart.
    private volatile boolean volumeKeyIntercept = false;
    private MethodChannel volumeKeyChannel;

    // Controller triggers (LT / RT) reach Android only as joystick motion axes,
    // which the Flutter engine drops on the floor; this bridge turns their
    // press / release edges into the KEYCODE_BUTTON_L2 / R2 key events the Dart
    // shortcut layer already binds and captures. Fed from
    // dispatchGenericMotionEvent, emits through dispatchKeyEvent so the
    // synthesized keys take the exact route a physical L2 / R2 button would.
    private final GamepadTriggerKeySynthesizer gamepadTriggers =
            new GamepadTriggerKeySynthesizer(this::dispatchKeyEvent);

    @Override
    protected void attachBaseContext(Context newBase) {
        SharedPreferences prefs = newBase.getSharedPreferences(SPLASH_PREFS, MODE_PRIVATE);
        if (prefs.contains(PreferenceKeys.SPLASH_IS_DARK)) {
            boolean isDark = prefs.getBoolean(PreferenceKeys.SPLASH_IS_DARK, false);
            int currentNight = newBase.getResources().getConfiguration().uiMode
                    & Configuration.UI_MODE_NIGHT_MASK;
            boolean systemDark = currentNight == Configuration.UI_MODE_NIGHT_YES;
            if (isDark != systemDark) {
                Configuration config = new Configuration(
                        newBase.getResources().getConfiguration());
                config.uiMode = (config.uiMode & ~Configuration.UI_MODE_NIGHT_MASK)
                        | (isDark ? Configuration.UI_MODE_NIGHT_YES
                                  : Configuration.UI_MODE_NIGHT_NO);
                super.attachBaseContext(newBase.createConfigurationContext(config));
                return;
            }
        }
        super.attachBaseContext(newBase);
    }

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        SharedPreferences splashPrefs = getSharedPreferences(SPLASH_PREFS, MODE_PRIVATE);
        int bgColor = splashPrefs.getInt(PreferenceKeys.SPLASH_BG_COLOR, 0);
        if (bgColor != 0) {
            getWindow().setBackgroundDrawable(new ColorDrawable(bgColor));
        }
        context = MainActivity.this;

        super.onCreate(savedInstanceState);

        disableSystemFocusHighlight();
        // 阅读器主窗口请求系统最高刷新率（收敛到共享 HighRefreshRate，与查词弹窗
        // PopupDictFlutterActivity / 悬浮窗共用同一实现，见 HighRefreshRate.java）。
        HighRefreshRate.applyToActivity(this);
    }

    // BUG-195: On API 26+ every View defaults to defaultFocusHighlightEnabled=true,
    // so when touch mode is exited the framework draws a system focus rectangle on
    // the currently focused View -- including the FlutterView host that hosts the
    // whole UI. On some skins (Samsung OneUI 6.5) that system frame overlaps Hibiki's
    // own keyboard/gamepad focus ring drawn in Flutter (see hibiki_focus_ring.dart),
    // giving a double highlight. We disable only the Android system default highlight
    // here; the Flutter self-drawn focus ring and focus navigation are untouched.
    // Done in code on the decorView (rather than only a theme attribute) because the
    // FlutterSurfaceView host is created programmatically inside super.onCreate, so a
    // direct setDefaultFocusHighlightEnabled(false) on the window's view hierarchy is
    // the deterministic place to kill it.
    private void disableSystemFocusHighlight() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            android.view.View decorView = getWindow().getDecorView();
            if (decorView != null) {
                decorView.setDefaultFocusHighlightEnabled(false);
            }
        }
    }

    // BUG-438/TODO-889: a gamepad connect/disconnect is a keyboard/navigation
    // configuration change. This Activity declares both keyboard AND navigation in
    // android:configChanges (the navigation flag is essential: a gamepad is a
    // navigation input device, so without it CONFIG_NAVIGATION changes recreate the
    // Activity instead of calling onConfigurationChanged, re-exposing the system
    // focus frame and a load spinner). With them declared Flutter keeps the Activity
    // alive and onConfigurationChanged fires instead of a recreate; re-apply the
    // system focus-highlight suppression here too, because the framework can reset
    // defaultFocusHighlightEnabled when input config changes.
    @Override
    public void onConfigurationChanged(@NonNull Configuration newConfig) {
        super.onConfigurationChanged(newConfig);
        disableSystemFocusHighlight();
    }

    @Override
    protected void onDestroy() {
        ioExecutor.shutdownNow();
        super.onDestroy();
    }

    // TODO-112 / BUG-196: volume keys must NEVER reach the FlutterView key
    // pipeline. super.dispatchKeyEvent() forwards the event to the view hierarchy
    // (including FlutterView) BEFORE Activity.onKeyDown adjusts the volume, so the
    // raw VOLUME_UP/DOWN leaked into Flutter and flipped FocusManager's highlight
    // mode to "traditional" -> a stray focus ring appeared on the reading content
    // even when volume-key page turning was OFF and the user only ever touched the
    // screen. We intercept volume keys here for BOTH states and never call super
    // for them:
    //   * intercept ON  (page turning): forward the key-down to Dart, swallow it
    //     (no volume change), exactly as before.
    //   * intercept OFF (default): adjust the system volume ourselves with
    //     adjustSuggestedStreamVolume(USE_DEFAULT_STREAM_TYPE, FLAG_SHOW_UI) — the
    //     standard "behave like the hardware volume key" API (picks the active
    //     stream, shows the volume slider) — so the buttons still work normally,
    //     but the event no longer pollutes Flutter's focus highlight mode.
    @Override
    public boolean dispatchKeyEvent(KeyEvent event) {
        int code = event.getKeyCode();
        if (code == KeyEvent.KEYCODE_VOLUME_UP || code == KeyEvent.KEYCODE_VOLUME_DOWN) {
            if (event.getAction() != KeyEvent.ACTION_DOWN) {
                // Consume the UP edge too so it never reaches FlutterView either;
                // the DOWN edge already did the work below.
                return true;
            }
            if (volumeKeyIntercept) {
                if (volumeKeyChannel != null) {
                    final String method = code == KeyEvent.KEYCODE_VOLUME_UP
                            ? "onVolumeUp"
                            : "onVolumeDown";
                    new Handler(Looper.getMainLooper()).post(() -> {
                        volumeKeyChannel.invokeMethod(method, null);
                    });
                }
                return true;
            }
            adjustSystemVolume(code == KeyEvent.KEYCODE_VOLUME_UP);
            return true;
        }
        return super.dispatchKeyEvent(event);
    }

    // Controller trigger axes → L2 / R2 key events (see GamepadTriggerKeySynthesizer).
    // Observe only, then let the event continue: the return value must stay the
    // framework's own — a joystick MotionEvent nobody consumes is what makes
    // ViewRootImpl synthesize the D-pad keys from the hat axes, so consuming it
    // here would silently kill the controller's D-pad.
    @Override
    public boolean dispatchGenericMotionEvent(MotionEvent event) {
        gamepadTriggers.onGenericMotionEvent(event);
        return super.dispatchGenericMotionEvent(event);
    }

    @Override
    protected void onPause() {
        // A trigger still pulled when the app goes to the background (or the
        // controller disconnects) would otherwise leave L2 / R2 stuck down.
        gamepadTriggers.releaseAll(SystemClock.uptimeMillis());
        super.onPause();
    }

    // Mirror the OS hardware-volume-key behaviour without routing the key through
    // FlutterView. USE_DEFAULT_STREAM_TYPE lets the framework pick the active
    // audio stream (music while playing, ring otherwise) and FLAG_SHOW_UI shows
    // the standard volume slider, so the user sees no difference from the default.
    private void adjustSystemVolume(boolean raise) {
        AudioManager audioManager =
                (AudioManager) getSystemService(Context.AUDIO_SERVICE);
        if (audioManager == null) return;
        int direction = raise
                ? AudioManager.ADJUST_RAISE
                : AudioManager.ADJUST_LOWER;
        audioManager.adjustSuggestedStreamVolume(
                direction,
                AudioManager.USE_DEFAULT_STREAM_TYPE,
                AudioManager.FLAG_SHOW_UI);
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        if (requestCode == SAF_PICK_DIR_REQUEST) {
            if (pendingSafResult == null) return;
            final MethodChannel.Result safResult = pendingSafResult;
            final String destPath = pendingSafDestPath;
            pendingSafResult = null;
            pendingSafDestPath = null;
            if (resultCode != Activity.RESULT_OK || data == null || data.getData() == null) {
                safResult.success(null);
                return;
            }
            Uri treeUri = data.getData();
            ioExecutor.execute(() -> {
                try {
                    DocumentFile dir = DocumentFile.fromTreeUri(context, treeUri);
                    if (dir == null || !dir.exists()) {
                        new Handler(Looper.getMainLooper()).post(() ->
                            safResult.error("NOT_FOUND", "Directory not found", null));
                        return;
                    }
                    File destDir = new File(destPath);
                    if (destDir.exists()) deleteRecursive(destDir);
                    destDir.mkdirs();
                    copyDocumentTree(dir, destDir);
                    new Handler(Looper.getMainLooper()).post(() ->
                        safResult.success(destPath));
                } catch (Exception e) {
                    new Handler(Looper.getMainLooper()).post(() ->
                        safResult.error("SAF_ERROR", e.getMessage(), null));
                }
            });
            return;
        }
        if (requestCode == SAF_PICK_REAL_DIR_REQUEST
                || requestCode == SAF_PICK_REAL_FILE_REQUEST) {
            if (pendingSafResult == null) return;
            final MethodChannel.Result safResult = pendingSafResult;
            pendingSafResult = null;
            if (resultCode != Activity.RESULT_OK || data == null
                    || data.getData() == null) {
                safResult.success(null); // user cancelled
                return;
            }
            final Uri pickedUri = data.getData();
            final boolean isTree = requestCode == SAF_PICK_REAL_DIR_REQUEST;
            ioExecutor.execute(() -> {
                String resolved = resolveSafRealPath(pickedUri, isTree);
                // BUG-2265: provenance comes from resolution, never from the
                // provider name or the returned path's spelling. A cache copy
                // must be consumed/copied by the importer, never referenced.
                final boolean isRealPath = resolved != null;
                // Files: unresolved providers remain usable via a cache copy.
                // Folders: no fallback (dart:io cannot read a cloud tree anyway).
                if (resolved == null && !isTree) {
                    resolved = copyUriToCache(pickedUri);
                }
                final Object pickedResult;
                if (isTree || resolved == null) {
                    // Keep the directory channel's existing String contract.
                    pickedResult = resolved;
                } else {
                    Map<String, Object> fileResult = new java.util.HashMap<>();
                    fileResult.put("path", resolved);
                    fileResult.put("isRealPath", isRealPath);
                    pickedResult = fileResult;
                }
                // null = user picked a folder we cannot map, or a copy failure.
                new Handler(Looper.getMainLooper()).post(() ->
                    safResult.success(pickedResult));
            });
        }
    }

    @Override
    protected void onResume() {
        super.onResume();
        // BUG-438/TODO-889: re-apply the system focus-highlight suppression on
        // resume. disableSystemFocusHighlight() runs once in onCreate. With
        // navigation now in android:configChanges a gamepad plug/unplug is kept
        // alive (onConfigurationChanged), but onResume is still a belt-and-braces
        // path for skins that re-attach the decorView and reset
        // defaultFocusHighlightEnabled back to true, re-exposing the system focus
        // rectangle over Hibiki own focus ring. Re-applying here (and in
        // onConfigurationChanged) keeps it killed.
        disableSystemFocusHighlight();
    }

    private void deleteRecursive(File f) {
        if (f.isDirectory()) {
            File[] children = f.listFiles();
            if (children != null) {
                for (File child : children) deleteRecursive(child);
            }
        }
        f.delete();
    }

    // TODO-1232: choose the rendering backend before the Flutter engine is
    // created. A command-line "--enable-impeller=false" takes precedence over the
    // AndroidManifest EnableImpeller default at engine init (see FlutterEngineFlags
    // docs), so appending it here flips the backend for THIS launch only -- no
    // rebuild, no adb. This runs at engine start, before any Dart code, so the
    // resolution below is the AUTHORITATIVE decision; RenderBackendService in Dart
    // only mirrors it for the settings toggle + diagnostics.
    @Override
    public FlutterShellArgs getFlutterShellArgs() {
        FlutterShellArgs args = super.getFlutterShellArgs();
        if (isImpellerDisabledPref()) {
            args.add(FlutterShellArgs.ARG_DISABLE_IMPELLER);
        }
        return args;
    }

    // TODO-1232: the effective "disable Impeller (use Skia)" decision for THIS
    // launch. Android DEFAULTS TO IMPELLER (never-set -> false) so the majority
    // keeps Impeller's smoother rendering / no Skia first-frame shader jank.
    // Impeller silently fails to composite media_kit's external SurfaceProducer
    // video texture on a FEW Android GPUs (e.g. Mali-G76 / Android 11, BUG-597),
    // leaving video black while decode + texture handshake are fully green -- those
    // devices degrade via the discoverable one-tap "switch to Skia + restart" entry
    // in the player settings sheet (writes this pref = true, then restarts), rather
    // than flipping every Android user to Skia. An EXPLICIT user choice overrides
    // this default in either direction (explicit > platform default); only the
    // never-set case falls back to Impeller. Mirrors
    // RenderBackendService.resolveImpellerDisabled(storedPref, isAndroid: true).
    private boolean isImpellerDisabledPref() {
        Boolean raw = getImpellerDisabledRawPref();
        return raw != null ? raw : false;
    }

    // TODO-1232: raw persisted intent as a tri-state -- null when the user has
    // never touched the render-backend switch, else the stored boolean. Kept
    // separate from isImpellerDisabledPref() so the "render" channel can hand Dart
    // the same tri-state (RenderBackendService resolves the platform default),
    // keeping the toggle/diagnostics mirror in lock-step with the engine-start
    // decision above.
    private Boolean getImpellerDisabledRawPref() {
        SharedPreferences prefs =
                getSharedPreferences(PreferenceKeys.FILE_RENDER, MODE_PRIVATE);
        if (!prefs.contains(PreferenceKeys.RENDER_IMPELLER_DISABLED)) {
            return null;
        }
        return prefs.getBoolean(PreferenceKeys.RENDER_IMPELLER_DISABLED, false);
    }

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        SelectionActionChannel.registerWith(flutterEngine, this);
        ClipboardImageChannel.registerWith(flutterEngine, getApplicationContext());

        volumeKeyChannel = new MethodChannel(
                flutterEngine.getDartExecutor().getBinaryMessenger(), VOLUME_KEY_CHANNEL);
        volumeKeyChannel.setMethodCallHandler((call, result) -> {
            if ("setInterceptEnabled".equals(call.method)) {
                Object arg = call.arguments;
                volumeKeyIntercept = arg instanceof Boolean && (Boolean) arg;
                result.success(null);
            } else {
                result.notImplemented();
            }
        });

        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), SAF_CHANNEL)
            .setMethodCallHandler((call, result) -> {
                switch (call.method) {
                    case "pickAndCopyDirectory": {
                        String destPath = call.argument("destPath");
                        if (destPath == null) {
                            result.error("INVALID_ARG", "destPath required", null);
                            return;
                        }
                        // Only one SAF picker can be pending at a time because
                        // startActivityForResult uses a single request code.
                        // Reject concurrent requests to avoid silently dropping
                        // the previous caller's result.
                        if (pendingSafResult != null) {
                            result.error("BUSY",
                                "A SAF directory pick is already in progress", null);
                            return;
                        }
                        pendingSafResult = result;
                        pendingSafDestPath = destPath;
                        Intent intent = new Intent(Intent.ACTION_OPEN_DOCUMENT_TREE);
                        applyTreeInitialLocation(intent, null);
                        startActivityForResult(intent, SAF_PICK_DIR_REQUEST);
                        break;
                    }
                    case "pickRealDirectory": {
                        // Native SAF folder picker; onActivityResult resolves the
                        // tree URI to a real absolute path (no copy).
                        if (pendingSafResult != null) {
                            result.error("BUSY",
                                "A SAF pick is already in progress", null);
                            return;
                        }
                        pendingSafResult = result;
                        Intent dirIntent = new Intent(Intent.ACTION_OPEN_DOCUMENT_TREE);
                        applyTreeInitialLocation(dirIntent, call.argument("initialDirectory"));
                        try {
                            startActivityForResult(dirIntent, SAF_PICK_REAL_DIR_REQUEST);
                        } catch (Exception e) {
                            // No DocumentsUI: reset so the channel is not stuck BUSY.
                            pendingSafResult = null;
                            result.error("NO_PICKER", e.getMessage(), null);
                        }
                        break;
                    }
                    case "pickRealFile": {
                        // Native SAF file picker; onActivityResult resolves the
                        // document URI to a real absolute path (no copy).
                        if (pendingSafResult != null) {
                            result.error("BUSY",
                                "A SAF pick is already in progress", null);
                            return;
                        }
                        pendingSafResult = result;
                        Intent fileIntent = new Intent(Intent.ACTION_OPEN_DOCUMENT);
                        fileIntent.addCategory(Intent.CATEGORY_OPENABLE);
                        fileIntent.setType("*/*");
                        try {
                            startActivityForResult(fileIntent, SAF_PICK_REAL_FILE_REQUEST);
                        } catch (Exception e) {
                            // No DocumentsUI: reset so the channel is not stuck BUSY.
                            pendingSafResult = null;
                            result.error("NO_PICKER", e.getMessage(), null);
                        }
                        break;
                    }
                    default:
                        result.notImplemented();
                }
            });


        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), SPLASH_CHANNEL)
            .setMethodCallHandler((call, result) -> {
                SharedPreferences prefs = getSharedPreferences(SPLASH_PREFS, MODE_PRIVATE);
                switch (call.method) {
                    case "setSplashColor": {
                        Object rawArgs = call.arguments;
                        if (!(rawArgs instanceof Map)) {
                            result.error("INVALID_ARG",
                                "setSplashColor requires a Map argument", null);
                            break;
                        }
                        Map<?, ?> args = (Map<?, ?>) rawArgs;
                        Object colorObj = args.get("color");
                        Object isDarkObj = args.get("isDark");
                        if (!(colorObj instanceof Number) || !(isDarkObj instanceof Boolean)) {
                            result.error("INVALID_ARG",
                                "color (Number) and isDark (Boolean) are required", null);
                            break;
                        }
                        int color = ((Number) colorObj).intValue();
                        boolean isDark = (Boolean) isDarkObj;
                        prefs.edit()
                             .putInt(PreferenceKeys.SPLASH_BG_COLOR, color)
                             .putBoolean(PreferenceKeys.SPLASH_IS_DARK, isDark)
                             .apply();
                        getWindow().setBackgroundDrawable(new ColorDrawable(color));
                        result.success(null);
                        break;
                    }
                    case "getSplashColor": {
                        int color = prefs.getInt(PreferenceKeys.SPLASH_BG_COLOR, 0);
                        result.success(color);
                        break;
                    }
                    default:
                        result.notImplemented();
                }
            });

        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), FONTS_CHANNEL)
            .setMethodCallHandler((call, result) -> {
                if ("listSystemFonts".equals(call.method)) {
                    ioExecutor.execute(() -> {
                        // 只从系统字体配置取「族名」：fonts.xml 的 <family name> 与 <alias name>
                        // 正是 Skia（Flutter 引擎）与 WebView CSS 按 font-family 能解析到的名字。
                        // Android 12+ 另有 font_fallback.xml，两份都读。不再扫 /system/fonts 目录：
                        // 由文件名猜出的「NotoSansCJK-Regular」之类按族名谁都解析不到，是死条目。
                        // supportsJapanese 省略：Paint.hasGlyph 走系统回退链，判不出字体本身覆盖。
                        TreeSet<String> families = new TreeSet<>(String.CASE_INSENSITIVE_ORDER);
                        Pattern comment = Pattern.compile("<!--.*?-->", Pattern.DOTALL);
                        Pattern named = Pattern.compile(
                                "<(?:family|alias)\\b[^>]*?\\bname\\s*=\\s*\"([^\"]+)\"");
                        String[] configs = {
                                "/system/etc/fonts.xml",
                                "/system/etc/font_fallback.xml",
                        };
                        for (String path : configs) {
                            File xml = new File(path);
                            if (!xml.isFile()) continue;
                            try (BufferedReader reader = new BufferedReader(
                                    new InputStreamReader(new FileInputStream(xml),
                                            java.nio.charset.StandardCharsets.UTF_8))) {
                                StringBuilder sb = new StringBuilder();
                                String line;
                                while ((line = reader.readLine()) != null) {
                                    sb.append(line).append('\n');
                                }
                                String body = comment.matcher(sb).replaceAll("");
                                Matcher m = named.matcher(body);
                                while (m.find()) {
                                    String name = m.group(1).trim();
                                    if (!name.isEmpty()) families.add(name);
                                }
                            } catch (Exception e) {
                                android.util.Log.w("hibiki-fonts", "Failed to parse " + path, e);
                            }
                        }
                        List<Map<String, Object>> entries = new ArrayList<>(families.size());
                        for (String family : families) {
                            Map<String, Object> entry = new HashMap<>();
                            entry.put("family", family);
                            entries.add(entry);
                        }
                        android.util.Log.d("hibiki-fonts", "Found " + entries.size() + " font families");
                        new Handler(Looper.getMainLooper()).post(() -> result.success(entries));
                    });
                } else {
                    result.notImplemented();
                }
            });

        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), LIFECYCLE_CHANNEL)
            .setMethodCallHandler((call, result) -> {
                if ("moveTaskToBack".equals(call.method)) {
                    moveTaskToBack(true);
                    result.success(null);
                } else {
                    result.notImplemented();
                }
            });

        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), ICON_CHANNEL)
            .setMethodCallHandler((call, result) -> {
                switch (call.method) {
                    case "getCurrentIcon":
                        result.success(IconSwitchHelper.getCurrentIcon(this));
                        break;
                    case "switchPresetIcon": {
                        String alias = call.argument("alias");
                        boolean ok = IconSwitchHelper.switchPresetIcon(this, alias);
                        result.success(ok);
                        break;
                    }
                    case "createCustomShortcut": {
                        byte[] imageBytes = call.argument("imageBytes");
                        boolean ok = IconSwitchHelper.createCustomShortcut(this, imageBytes);
                        result.success(ok);
                        break;
                    }
                    case "isCustomShortcutSupported":
                        result.success(IconSwitchHelper.isCustomShortcutSupported(this));
                        break;
                    default:
                        result.notImplemented();
                        break;
                }
            });

        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), ChannelNames.APP_SHORTCUTS)
            .setMethodCallHandler((call, result) -> {
                if ("setShortcuts".equals(call.method)) {
                    List<Map<String, String>> items = call.argument("items");
                    String disabledMessage = call.argument("disabledMessage");
                    List<String> moduleDisabledIds = call.argument("moduleDisabledIds");
                    AppShortcutsHelper.setShortcuts(
                        this,
                        items == null ? new ArrayList<>() : items,
                        disabledMessage,
                        moduleDisabledIds == null ? new ArrayList<>() : moduleDisabledIds);
                    result.success(null);
                } else {
                    result.notImplemented();
                }
            });

        // TODO-1232 A3: render-backend experiment toggle. Dart writes the flag
        // here; MainActivity.getFlutterShellArgs reads it at the NEXT launch to
        // decide whether to disable Impeller (Skia fallback). Persisted to a
        // native prefs file this app owns so it is readable pre-engine.
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(),
                ChannelNames.RENDER)
            .setMethodCallHandler((call, result) -> {
                switch (call.method) {
                    case "isImpellerDisabled":
                        // TODO-1232: return the RAW tri-state (null = never set);
                        // Dart applies the platform default so the toggle and the
                        // engine-start decision (getFlutterShellArgs ->
                        // isImpellerDisabledPref) agree on "unset -> Skia on Android".
                        result.success(getImpellerDisabledRawPref());
                        break;
                    case "setImpellerDisabled": {
                        final Object arg = call.arguments;
                        if (!(arg instanceof Boolean)) {
                            result.error("INVALID_ARG",
                                "setImpellerDisabled requires a boolean", null);
                            break;
                        }
                        getSharedPreferences(PreferenceKeys.FILE_RENDER, MODE_PRIVATE)
                                .edit()
                                .putBoolean(PreferenceKeys.RENDER_IMPELLER_DISABLED,
                                        (Boolean) arg)
                                .apply();
                        result.success(null);
                        break;
                    }
                    default:
                        result.notImplemented();
                }
            });
    }

    private void copyDocumentTree(DocumentFile srcDir, File destDir) throws Exception {
        final String destCanon = destDir.getCanonicalPath();
        for (DocumentFile child : srcDir.listFiles()) {
            String name = child.getName();
            if (name == null) continue;
            // HBK-AUDIT-015: a hostile/odd document name ('../x', 'a/b') could
            // escape destDir (zip-slip). Reject path separators and dot names,
            // and verify the resolved target stays under destDir.
            if (name.contains("/") || name.contains("\\")
                    || name.equals("..") || name.equals(".")) {
                continue;
            }
            File target = new File(destDir, name);
            if (!target.getCanonicalPath().startsWith(destCanon + File.separator)) {
                continue;
            }
            if (child.isDirectory()) {
                target.mkdirs();
                copyDocumentTree(child, target);
            } else {
                // HBK-AUDIT-015: removed the >50MB "/proc/self/fd symlink"
                // special case — it copied the same bytes as the stream path
                // (no hard-link, no SAF bypass) and silently swallowed errors.
                // Always stream via ContentResolver.
                copyFile(child, target);
            }
        }
    }

    private void copyFile(DocumentFile src, File dest) throws Exception {
        try (InputStream in = getContentResolver().openInputStream(src.getUri());
             OutputStream out = new FileOutputStream(dest)) {
            if (in == null) return;
            byte[] buf = new byte[8192];
            int len;
            while ((len = in.read(buf)) > 0) {
                out.write(buf, 0, len);
            }
        }
    }

    // Resolve a SAF tree/document content URI to a real filesystem absolute path
    // (no copy). The app holds MANAGE_EXTERNAL_STORAGE, so once we recover the
    // real path dart:io can read it and the whole downstream stays real-path
    // based. Covers the common DocumentsUI entry points so "pick from Recent /
    // Videos / Downloads" does not silently fail:
    //   - externalstorage (逐级浏览设备目录/SD 卡): volumeId:relative
    //   - downloads with a raw: docId: the real path is embedded
    //   - media provider (Recent / 视频集): resolve via MediaStore _data
    //   - generic: best-effort _data column on the picked URI
    // Returns null only for providers with no real path (true cloud); the caller
    // then cancels (folder) or copies to cache (file).
    private String resolveSafRealPath(Uri uri, boolean isTree) {
        try {
            final String authority = uri.getAuthority();
            if ("com.android.externalstorage.documents".equals(authority)) {
                final String docId = isTree
                    ? DocumentsContract.getTreeDocumentId(uri)
                    : DocumentsContract.getDocumentId(uri);
                final String path = externalStorageDocIdToPath(docId);
                if (path != null) return path;
            }
            // A folder pick only ever yields a tree URI; non-externalstorage
            // trees are cloud DocumentsProviders with no readable real path.
            if (isTree) return null;

            if ("com.android.providers.downloads.documents".equals(authority)) {
                final String docId = DocumentsContract.getDocumentId(uri);
                if (docId != null && docId.startsWith("raw:")) {
                    final File raw = new File(docId.substring(4));
                    if (raw.exists()) return raw.getAbsolutePath();
                }
            }
            if ("com.android.providers.media.documents".equals(authority)) {
                final String path = mediaDocIdToPath(DocumentsContract.getDocumentId(uri));
                if (path != null) return path;
            }
            // Best-effort: some providers expose the legacy _data column directly.
            final String data = queryDataColumn(uri, null, null);
            if (data != null && new File(data).exists()) return data;
            return null;
        } catch (Exception e) {
            return null;
        }
    }

    // BUG-2646: a bare ACTION_OPEN_DOCUMENT_TREE lets DocumentsUI open wherever
    // it likes; several ROMs (reported on a ColorOS-style DocumentsUI) land on
    // "Recent", which in folder mode lists nothing and has no "use this folder"
    // button, so the user cannot pick any folder at all. Always point the picker
    // at a real browsable location: the caller's current folder when it lives on
    // shared storage, otherwise the internal-storage root. EXTRA_INITIAL_URI is
    // API 26+; older DocumentsUI already opens on a storage root.
    private void applyTreeInitialLocation(Intent intent, String initialDirectory) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return;
        final String docId = realPathToExternalStorageDocId(initialDirectory);
        intent.putExtra(DocumentsContract.EXTRA_INITIAL_URI,
            DocumentsContract.buildDocumentUri(
                "com.android.externalstorage.documents",
                docId != null ? docId : "primary:"));
    }

    // Inverse of externalStorageDocIdToPath: real absolute path -> externalstorage
    // docId "volumeId:relative". Walks up to the nearest existing directory (the
    // current folder may not be created yet). Returns null for paths outside
    // shared storage (e.g. app-private /data/user/0/...), which SAF cannot show.
    private String realPathToExternalStorageDocId(String path) {
        if (path == null || path.trim().isEmpty()) return null;
        File dir = new File(path.trim());
        while (dir != null && !dir.isDirectory()) dir = dir.getParentFile();
        if (dir == null) return null;
        final String abs = dir.getAbsolutePath();
        final String primary = Environment.getExternalStorageDirectory().getAbsolutePath();
        if (abs.equals(primary)) return "primary:";
        if (abs.startsWith(primary + "/")) {
            return "primary:" + abs.substring(primary.length() + 1);
        }
        final Matcher m = Pattern.compile("^/storage/([^/]+)(?:/(.*))?$").matcher(abs);
        if (m.matches()) {
            final String volumeId = m.group(1);
            if ("emulated".equals(volumeId) || "self".equals(volumeId)) return null;
            return volumeId + ":" + (m.group(2) != null ? m.group(2) : "");
        }
        return null;
    }

    // externalstorage docId "volumeId:relative" -> real absolute path.
    private String externalStorageDocIdToPath(String docId) {
        if (docId == null) return null;
        final int sep = docId.indexOf(':');
        if (sep < 0) return null;
        final String volumeId = docId.substring(0, sep);
        final String relative = docId.substring(sep + 1);
        final String root = resolveVolumeRoot(volumeId);
        if (root == null) return null;
        final File target = relative.isEmpty() ? new File(root) : new File(root, relative);
        return target.exists() ? target.getAbsolutePath() : null;
    }

    // externalstorage volume id -> real mount root. "primary" is internal
    // storage; other ids are physical SD cards under /storage/<id> (used only
    // when present). Both are readable via dart:io under MANAGE_EXTERNAL_STORAGE.
    private String resolveVolumeRoot(String volumeId) {
        if ("primary".equalsIgnoreCase(volumeId) || "home".equalsIgnoreCase(volumeId)) {
            return Environment.getExternalStorageDirectory().getAbsolutePath();
        }
        final File volumeRoot = new File("/storage/" + volumeId);
        return volumeRoot.exists() ? volumeRoot.getAbsolutePath() : null;
    }

    // media provider docId ("video:123" / "image:123" / "audio:123") -> real
    // path via the matching MediaStore collection's _data column.
    private String mediaDocIdToPath(String docId) {
        if (docId == null) return null;
        final int sep = docId.indexOf(':');
        if (sep < 0) return null;
        final String type = docId.substring(0, sep);
        final String id = docId.substring(sep + 1);
        final Uri contentUri;
        if ("video".equals(type)) {
            contentUri = MediaStore.Video.Media.EXTERNAL_CONTENT_URI;
        } else if ("image".equals(type)) {
            contentUri = MediaStore.Images.Media.EXTERNAL_CONTENT_URI;
        } else if ("audio".equals(type)) {
            contentUri = MediaStore.Audio.Media.EXTERNAL_CONTENT_URI;
        } else {
            return null;
        }
        final String path = queryDataColumn(contentUri, "_id=?", new String[]{id});
        return (path != null && new File(path).exists()) ? path : null;
    }

    // Read the legacy _data column for a content URI (readable under all-files
    // access). Returns null if the column is absent/empty or the query fails.
    private String queryDataColumn(Uri uri, String selection, String[] args) {
        try (Cursor cursor = getContentResolver()
                .query(uri, new String[]{"_data"}, selection, args, null)) {
            if (cursor != null && cursor.moveToFirst()) {
                final int idx = cursor.getColumnIndex("_data");
                if (idx >= 0) {
                    final String data = cursor.getString(idx);
                    if (data != null && !data.isEmpty()) return data;
                }
            }
        } catch (Exception e) {
            // fall through
        }
        return null;
    }

    // Last-resort copy of a picked file content URI into app cache, returning the
    // cache path. Used only when the URI has no real filesystem path (true cloud
    // DocumentsProvider) — same escape hatch as the no-permission file_picker
    // path. The caller labels this as isRealPath=false so importers copy it into
    // owned storage instead of persisting a reference to this temporary file.
    private String copyUriToCache(Uri uri) {
        try {
            String name = queryDisplayName(uri);
            if (name == null || name.isEmpty()) {
                name = "saf_pick_" + SystemClock.uptimeMillis();
            }
            final File cacheDir = new File(getCacheDir(), "saf_pick");
            cacheDir.mkdirs();
            final File dest = new File(cacheDir, name);
            try (InputStream in = getContentResolver().openInputStream(uri);
                 OutputStream out = new FileOutputStream(dest)) {
                if (in == null) return null;
                byte[] buf = new byte[8192];
                int len;
                while ((len = in.read(buf)) > 0) {
                    out.write(buf, 0, len);
                }
            }
            return dest.getAbsolutePath();
        } catch (Exception e) {
            return null;
        }
    }

    // Display name for a content URI (falls back to null when unavailable).
    private String queryDisplayName(Uri uri) {
        try (Cursor cursor = getContentResolver().query(
                uri, new String[]{OpenableColumns.DISPLAY_NAME}, null, null, null)) {
            if (cursor != null && cursor.moveToFirst()) {
                final int idx = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME);
                if (idx >= 0) return cursor.getString(idx);
            }
        } catch (Exception e) {
            // fall through
        }
        return null;
    }
}
