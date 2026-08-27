# Changelog

## Unreleased

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
