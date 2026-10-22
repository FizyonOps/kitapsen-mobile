# VLC native library
-keep class org.videolan.libvlc.** { *; }

# Flutter engine & embedding
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Fushi native channels & providers.
# This package filter MUST track applicationId / namespace in android/app/build.gradle.
# The W8 directory rename moved applicationId from app.hibiki.reader to app.fushi.reader
# but left this keep rule pointing at the old package, so it matched zero classes and
# every app-side Kotlin/Java class entered R8's optimization surface for the first time.
# R8 then horizontally merged the anonymous FullTypeReference subclasses that Injekt's
# reified `addSingleton` / `addSingletonFactory` inline into MihonChannelHandler, which
# made getGenericSuperclass() stop being a ParameterizedType and crashed
# MainActivity.onCreate with "TypeReference constructed without actual type information".
-keep class app.fushi.reader.** { *; }

# audio_service background isolate
-keep class com.ryanheise.audioservice.** { *; }

# InAppWebView
-keep class com.pichillilorenzo.flutter_inappwebview_android.** { *; }

# Drift / SQLite (moor_ffi)
-keep class com.tekartik.sqflite.** { *; }

# Kotlin metadata for reflection-based plugins
-keepattributes *Annotation*
-keep class kotlin.Metadata { *; }

# Keep native method signatures for JNI / FFI
-keepclasseswithmembernames class * {
    native <methods>;
}

# Play Core split install (referenced by Flutter engine but not bundled)
-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**
# Kitapsen ships neither the Mihon / Aniyomi extension host (whose third-party
# extension dex needed okhttp, jsoup, rx, injekt, kotlin, kotlinx and friends
# kept under their original names) nor ONNX Runtime (local manga OCR), so their
# keep rules are gone and R8 shrinks those libraries like any other.
