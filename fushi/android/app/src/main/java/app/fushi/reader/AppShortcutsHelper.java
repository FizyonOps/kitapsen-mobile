package app.fushi.reader;

import android.content.Context;
import android.content.Intent;
import android.net.Uri;
import android.util.Log;

import androidx.core.content.pm.ShortcutInfoCompat;
import androidx.core.content.pm.ShortcutManagerCompat;
import androidx.core.graphics.drawable.IconCompat;

import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

/// 长按 app 图标弹出的动态快捷方式（Dart 门面 `lib/src/platform/app_shortcuts.dart`）。
///
/// 每条快捷方式就是一条指向 MainActivity 的 ACTION_VIEW intent，data 为
/// `fushi://shortcut/<id>`：冷启动时 `ReceiveIntent.getInitialIntent()`、热启动时
/// singleTask 的 onNewIntent 都会把它交给 Dart 的 `handleIncomingUrl`，不需要另起
/// 投递通道。列表由 Dart 按界面语言整表下发，这里只负责换图标并替换。
public final class AppShortcutsHelper {
    private static final String TAG = "AppShortcuts";

    private AppShortcutsHelper() {}

    public static void setShortcuts(Context context, List<Map<String, String>> items) {
        // Dart 本次仍在提供的全部快捷方式（含因启动器上限进不了菜单的）：只有这里的
        // 固定快捷方式才该被（重新）启用。
        List<ShortcutInfoCompat> offered = new ArrayList<>();
        for (Map<String, String> item : items) {
            String id = item.get("id");
            String title = item.get("title");
            String url = item.get("url");
            if (id == null || title == null || url == null) continue;
            Intent intent = new Intent(Intent.ACTION_VIEW, Uri.parse(url))
                .setClass(context, MainActivity.class)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            offered.add(new ShortcutInfoCompat.Builder(context, id)
                .setShortLabel(title)
                .setLongLabel(title)
                .setIcon(IconCompat.createWithResource(context, iconFor(id)))
                .setIntent(intent)
                .setRank(offered.size())
                .build());
        }
        int max = ShortcutManagerCompat.getMaxShortcutCountPerActivity(context);
        List<ShortcutInfoCompat> shortcuts =
            new ArrayList<>(offered.subList(0, Math.min(max, offered.size())));
        try {
            // 之前被置灰的固定快捷方式要先恢复，再随动态列表一起更新。
            ShortcutManagerCompat.enableShortcuts(context, offered);
        } catch (RuntimeException e) {
            Log.w(TAG, "enableShortcuts failed", e);
        }
        try {
            ShortcutManagerCompat.setDynamicShortcuts(context, shortcuts);
        } catch (RuntimeException e) {
            // 系统限流（后台频繁更新）或启动器不支持时只丢图标菜单，不影响 app。
            Log.w(TAG, "setDynamicShortcuts failed", e);
        }
        Set<String> offeredIds = new HashSet<>();
        for (ShortcutInfoCompat shortcut : offered) offeredIds.add(shortcut.getId());
        disableRemovedPinned(context, offeredIds);
    }

    /// 被固定到桌面的快捷方式不受 setDynamicShortcuts 管：id 已下线后它还在桌面上，
    /// 点下去会把用户送进一个不存在的入口。用启动器默认文案置灰它。Dart 侧
    /// `AppShortcut.tryParse` 另有兜底。
    private static void disableRemovedPinned(Context context, Set<String> offered) {
        List<String> retired = new ArrayList<>();
        try {
            for (ShortcutInfoCompat pinned :
                ShortcutManagerCompat.getShortcuts(context, ShortcutManagerCompat.FLAG_MATCH_PINNED)) {
                String id = pinned.getId();
                if (!offered.contains(id)) retired.add(id);
            }
            if (!retired.isEmpty()) {
                ShortcutManagerCompat.disableShortcuts(context, retired, null);
            }
        } catch (RuntimeException e) {
            Log.w(TAG, "disableShortcuts failed", e);
        }
    }

    // Kitapsen publishes only the books shortcut (the books module is the only
    // one it ships), so the lookup / manga / video icons are not bundled.
    private static int iconFor(String id) {
        return R.drawable.ic_shortcut_books;
    }
}
