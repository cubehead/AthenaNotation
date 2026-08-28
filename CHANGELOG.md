# Changelog

## Unreleased

- Add an independent playback-cursor visibility policy for Apple, Android, and
  Windows rendering, including matching example controls and Android JNI APIs.
- Add width-aware automatic system breaks that use engraving collision extents,
  prefer measure boundaries, split dense measures when necessary, and lay out
  the complete score without a fixed measures-per-line limit.
- Measure each Apple-rendered system independently for ledger notes, stems,
  attachments, tuplets, voltas, and spanners; use the resulting geometry for
  vertical scrolling, playback following, and touch hit testing.
- Update the Apple example to demonstrate complete-score adaptive layout.

## 1.1.0 - 2026-08-28

- Add semantic playback callbacks, note transitions, validated A–B repeat
  ranges, count-in timing events, and reusable playback-step planning.
- Add configurable score touch callbacks and automatic playback-following
  scroll behavior on Apple and Android renderers.
- Extend the Android JNI bridge and Compose example with touch-to-seek,
  playback highlighting, A–B resolution, count-in calculations, and verified
  Release AAR consumption.
- Add the experimental `AthenaNotationRenderWindows` SwiftPM product, portable
  display-list facade, command-line example, tests, and native Windows CI.
- Make visual fixtures and public API checks deterministic across macOS and
  Windows Swift toolchains.

## 1.0.0 - 2026-08-27

- Add the `AthenaNotationRenderAndroid` Swift product with a Codable display
  list, string-only `AndroidRenderBridge`, bundled Bravura font, Compose Canvas
  adapter, and rendering tests.
- Document the Swift 6.3.3 Android toolchain requirement and verified
  ARM64-device and x86_64-emulator build commands.
- Expand MusicXML import with structured diagnostics, dynamics, text and
  rehearsal directions, articulations, ornaments, fermatas, techniques,
  lyrics, glissandi, hairpins, pedal ranges, and octave shifts.
- Add deterministic, reviewable SVG engraving regression fixtures.
- Add exact score navigation and localized accessibility descriptions, expose
  virtual VoiceOver score children, and carry TalkBack metadata in Android JSON.
- Establish and enforce the 1.0 public Symbol Graph baseline and Semantic
  Versioning compatibility policy.
- Add automatic light/dark notation themes and scrollable score viewports on
  Apple and Android.

All notable changes follow Semantic Versioning.

## 0.1.0

- Initial standalone open-source package.
- Semantic notation model with exact rational timing.
- Native layout and SwiftUI five-line staff renderer.
- MusicXML and Standard MIDI File import.
- Tempo, expression, pedal and playback timeline analysis.
- Swift Package Manager and CocoaPods distribution metadata.
