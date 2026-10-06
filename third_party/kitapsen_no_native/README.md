# Native-free plugin copies (Kitapsen edition)

The Kitapsen store build compiles out game streaming, LAN discovery and QR
pairing, and voice recording. Their Dart code still has to type-check, so these
packages keep their upstream `lib/` unchanged, but the `flutter: plugin:` block
and the per-platform implementation packages are removed from `pubspec.yaml`.
Flutter therefore registers no plugin and bundles no Android/iOS code for them.

| Package | Upstream version | Removed |
|---|---|---|
| flutter_webrtc | 1.6.2+hotfix.3 | WebRTC native plugin (all platforms) |
| mobile_scanner | 7.4.2 | camera barcode scanner plugin |
| bonsoir | 7.1.1 | bonsoir_android / _darwin / _windows / _linux |
| record | 6.0.0 | record_android / _ios / _macos / _web / _windows / _linux |

`third_party/ffmpeg_kit_flutter` and `third_party/flutter_onnxruntime` had their
plugin block removed in place for the same reason, and `media_kit_libs_video`
(libmpv / ffmpeg) is no longer a dependency of the app.

To refresh a copy after an upstream bump: copy the new `lib/` and `pubspec.yaml`,
then delete the `plugin:` block and the platform dependencies again.
