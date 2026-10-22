# Native-free plugin copies (Kitapsen edition)

The Kitapsen store build compiles out game streaming, LAN discovery and QR
pairing, voice recording, audiobooks and lookup audio, update notifications,
Google Drive sync, gamepads, AnkiDroid, dictionary archives and camera capture.
Their Dart code still has to type-check, so these
packages keep their upstream `lib/` unchanged, but the `flutter: plugin:` block
and the per-platform implementation packages are removed from `pubspec.yaml`.
Flutter therefore registers no plugin and bundles no Android/iOS code for them.

| Package | Upstream version | Removed |
|---|---|---|
| flutter_webrtc | 1.6.2+hotfix.3 | WebRTC native plugin (all platforms) |
| mobile_scanner | 7.4.2 | camera barcode scanner plugin |
| bonsoir | 7.1.1 | bonsoir_android / _darwin / _windows / _linux |
| record | 6.0.0 | record_android / _ios / _macos / _web / _windows / _linux |
| just_audio | 0.9.42 | native player plugin, just_audio_web |
| audio_session | 0.1.25 | native audio-session plugin |
| audio_service | 0.18.18 | background audio service plugin, audio_service_web |
| flutter_local_notifications | 20.1.0 | Android / iOS / macOS notification plugin |
| google_sign_in | 6.3.0 | google_sign_in_android / _ios / _web |
| gamepads | 0.1.10+2 | gamepads_android / _darwin / _ios / _linux / _web / _windows |
| external_app_launcher | 4.0.3 | app-launch plugin (AnkiDroid hand-off) |
| async_zip | 0.1.0 | FFI zip library (Yomichan dictionary import) |
| flutter_archive | 5.0.0 | native zip plugin (MDict / Migaku dictionary import) |
| image_picker | 0.8.7+5 | image_picker_android / _ios / _for_web (gallery covers use file_picker) |

`third_party/ffmpeg_kit_flutter`, `third_party/flutter_onnxruntime` and
`third_party/media_kit_video` had their plugin block removed in place for the same reason, and `media_kit_libs_video`
(libmpv / ffmpeg) is no longer a dependency of the app.

To refresh a copy after an upstream bump: copy the new `lib/` and `pubspec.yaml`,
then delete the `plugin:` block, the platform dependencies and any
`resolution: workspace` line again.
