// Derived from the AnkiDroid API Sample

package app.fushi.reader;

import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.os.SystemClock;
import android.media.AudioManager;
import android.view.KeyEvent;
import android.view.MotionEvent;
import androidx.annotation.NonNull;

import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

import android.content.SharedPreferences;
import android.graphics.drawable.ColorDrawable;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileInputStream;
import java.io.InputStreamReader;
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

import io.flutter.embedding.android.FlutterActivity;
import android.content.Context;
import android.content.res.Configuration;

// Kitapsen: only the channels of features the app shows are registered here.
// Anki, TTS, picture-in-picture, NFC pairing, Mihon extensions, the floating
// lyric / dictionary / ball overlays, screen and system OCR, the lookup IME
// hint, data migration, download keep-alive, the APK self-updater, the video
// brightness drag, the SAF folder / file pickers (file_picker serves every
// pick), the move-to-back lifecycle call, the launcher icon switcher, the
// Impeller / Skia render toggle, image clipboard copy and the Android text
// selection actions are not part of this edition, and neither are their Java /
// Kotlin classes. There is no audio_service player, so this is a plain
// FlutterActivity.
public class MainActivity extends FlutterActivity {
    private static final String VOLUME_KEY_CHANNEL = ChannelNames.VOLUME_KEYS;
    private static final String FONTS_CHANNEL = ChannelNames.FONTS;
    private static final String SPLASH_CHANNEL = ChannelNames.SPLASH;
    private static final String SPLASH_PREFS = PreferenceKeys.FILE_SPLASH;
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

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);

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
    }
}
