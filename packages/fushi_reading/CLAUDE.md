[Root](../../CLAUDE.md) > [packages](../) > **fushi_reading**

# fushi_reading

> **Kitapsen edition (2026-10-23).** This package was `fushi_audio` upstream.
> The audiobook player, subtitle parsers, audio/text matching and Sasayaki code
> were deleted with the audiobook feature; what remained is the pure-Dart reading
> support below, so the package and its `src/audiobook/` folder were renamed.

## Responsibility

Pure Dart (no Flutter SDK, no method-channel plugins) reading support shared by
the app and `fushi_engine`:

- `src/parsers/text_file_io.dart`: text file reading with charset detection. The
  platform detector lives in the app (`fushi/lib/src/media/book/platform_charset_detector.dart`)
  and is injected through `platformCharsetDecoder` in `fushi/lib/src/engine_bindings.dart`.
- `src/reading/`: `ReaderPositionModel` / `ReaderPositionRepository` (reading
  position), `BookmarkRepository`, `FavoriteSentenceRepository`, `StudyClock`
  (the single study timer behind reading statistics) and `compareFilePathNatural`
  (natural path sort for legacy unpacked books).
- `src/matching/epub_builder.dart`: builds an EPUB from plain text (TXT import,
  via `fushi_engine/lib/epub/text_to_epub.dart`).

## Entry point

`lib/fushi_reading.dart` is the only barrel; import `package:fushi_reading/fushi_reading.dart`.

## Dependencies

`fushi_core` (database). The pubspec must not declare `sdk: flutter`.

## Tests

The Kitapsen edition has no test suites. Verify by building and running the app.
