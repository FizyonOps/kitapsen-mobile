/// Kitapsen edition switch for the engine package.
///
/// The engine must not import `package:fushi` (purity guard), so it carries
/// its own constant. Always `true` in this repository; it mirrors the app's
/// `kKitapsenEdition`. Code behind `!kEngineKitapsenEdition` is compiled out of
/// the store builds (App Review guideline 2.3.1: no hidden features).
library;

const bool kEngineKitapsenEdition = true;
