package app.fushi.reader.constants;

public final class ChannelNames {
    private ChannelNames() {}

    public static final String PREFIX = "app.fushi.reader";
    public static final String SPLASH = PREFIX + "/splash";
    public static final String VOLUME_KEYS = PREFIX + "/volume_keys";
    public static final String FONTS = PREFIX + "/fonts";
    // 长按 app 图标的动态快捷方式，实现见 AppShortcutsHelper。
    public static final String APP_SHORTCUTS = PREFIX + "/app_shortcuts";
}
