# Android Native Code

Java only. Kitapsen registers just the channels its visible features use.

## Constant Classes (`constants/`)

- `ChannelNames.java` — MethodChannel name constants. Has a Dart counterpart
  that MUST stay in sync: `lib/src/utils/misc/channel_constants.dart`
  (`FushiChannels`).
- `PreferenceKeys.java` — native SharedPreferences file and key names (the
  splash colour MainActivity applies before the Flutter engine starts).

## Architecture

- `MainActivity.java` — Main Flutter activity; registers the splash, volume
  keys, system fonts and app shortcuts channels.
- `AppShortcutsHelper.java` — Launcher long-press shortcuts.
- `GamepadTriggerKeySynthesizer.java` — Turns controller trigger axes into
  L2 / R2 key events.
- `HighRefreshRate.java` — Requests the display's highest refresh rate.
- `FushiFileProvider.java` — FileProvider for sharing exported files.

## Cross-Language Sync Points

When changing any of the following, update both sides in the same change:

| Native (this dir)        | Dart counterpart                                 |
|--------------------------|--------------------------------------------------|
| `ChannelNames.java`      | `channel_constants.dart` (`FushiChannels`)      |
