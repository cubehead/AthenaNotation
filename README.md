<p align="center">
  <img src="Assets/Brand/athena-notation-mark.png" width="168" alt="AthenaNotation logo">
</p>

<h1 align="center">AthenaNotation</h1>

<p align="center">
  A native Swift music-notation engine for iPadOS, macOS, and Android.
</p>

<p align="center">
  <a href="README.md">English</a> · <a href="README.zh-CN.md">简体中文</a>
</p>

[![CI](https://github.com/cubehead/AthenaNotation/actions/workflows/ci.yml/badge.svg)](https://github.com/cubehead/AthenaNotation/actions/workflows/ci.yml)
[![Swift 6.0](https://img.shields.io/badge/Swift-6.0-F05138?logo=swift&logoColor=white)](https://www.swift.org/)
[![Platforms](https://img.shields.io/badge/platforms-iPadOS%20%7C%20macOS%20%7C%20Android-lightgrey)](Package.swift)
[![CocoaPods](https://img.shields.io/badge/CocoaPods-GitHub%20source-EE3322?logo=cocoapods&logoColor=white)](AthenaNotation.podspec)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

AthenaNotation provides a semantic score model, engraving layout, SwiftUI
renderer, MusicXML and MIDI importers, and score-timeline analysis—without a
WebView, JavaScript renderer, or third-party MIDI runtime.

> **Project status:** AthenaNotation 1.0 has a versioned public API baseline and
> follows Semantic Versioning. See [Public API stability](Documentation/APIStability.md).

## Features

- Exact rational timing, multiple voices, and grand-staff scores
- Notes, rests, dots, beams, tuplets, ties, slurs, and ledger lines
- Accidentals, fingerings, articulations, ornaments, dynamics, hairpins, pedal
  markings, lyrics, text directions, repeats, voltas, and final barlines
- Native SwiftUI/Canvas rendering on Apple platforms
- Swift-owned engraving display lists and a Jetpack Compose Canvas adapter on Android
- MusicXML `score-partwise` import
- Standard MIDI File Type 0 and Type 1 import
- Tempo changes, count-in, expression, pedal, and playback-timeline analysis
- Exact event/measure/beat navigation with localized accessibility labels
- VoiceOver virtual score elements and TalkBack metadata
- Focused products, so clients can depend on only the modules they need

## Scope

AthenaNotation provides reusable building blocks for score semantics,
engraving, native rendering, supported file import, and score-timeline
analysis. Its public modules are application-neutral: clients can select only
the products they need and compose them into their own workflows.

Dependencies point inward toward the semantic core, keeping the model and
layout engine portable across supported platforms. See
[Architecture](Documentation/Architecture.md).

## Requirements

- Swift 6.0 or later
- iOS / iPadOS 17 or later
- macOS 15 or later
- Swift 6.3, the Swift SDK for Android, and Android NDK r27d or later for Android builds

## Installation

### Swift Package Manager

In Xcode, choose **File → Add Package Dependencies** and enter:

```text
https://github.com/cubehead/AthenaNotation.git
```

Or add the dependency to `Package.swift`:

```swift
dependencies: [
  .package(
    url: "https://github.com/cubehead/AthenaNotation.git",
    from: "1.0.0"
  )
]
```

Add the complete product:

```swift
.product(name: "AthenaNotation", package: "AthenaNotation")
```

You can also select an individual product:

- `AthenaNotationCore`
- `AthenaNotationRenderApple`
- `AthenaNotationRenderAndroid`
- `AthenaMusicXML`
- `AthenaMIDI`
- `AthenaScoreAnalysis`

### CocoaPods

```ruby
platform :ios, '17.0'
use_frameworks!

target 'YourApp' do
  pod 'AthenaNotation',
      :git => 'https://github.com/cubehead/AthenaNotation.git',
      :tag => '1.0.0'
end
```

Run `pod install` after saving the Podfile. This installs the checked release
directly from GitHub and does not require AthenaNotation to exist in the public
CocoaPods Specs index.

To follow the latest `main` branch instead:

```ruby
pod 'AthenaNotation',
    :git => 'https://github.com/cubehead/AthenaNotation.git',
    :branch => 'main'
```

Use a version tag for reproducible application builds. The branch form is
intended for development and early evaluation.

For a local checkout:

```ruby
pod 'AthenaNotation', :path => '../AthenaNotation'
```

Swift Package Manager exposes the focused modules listed above. CocoaPods
compiles the open-source core as one `AthenaNotation` module.

### Android / Jetpack Compose

Build the focused `AthenaNotationRenderAndroid` Swift product with the official
Swift SDK for Android, expose `AndroidRenderBridge` through `swift-java`, and
render its JSON display list with the included Compose adapter:

```swift
let sceneJSON = try AndroidRenderBridge().renderScoreJSON(
  scoreJSON,
  width: 1024,
  height: 720,
  preferredSystemCount: 2,
  playbackEventIDs: ["current-event-id"]
)
```

The renderer owns notation geometry in Swift. Kotlin only executes drawing
commands with native Compose Canvas, so there is no WebView or JavaScript
runtime. See [Android Compose integration](Integrations/AndroidCompose/README.md)
for embedding the canvas, or run the
[complete Android example](Examples/AthenaNotationAndroid/README.md) to build
the distributable AAR and test MusicXML, MIDI, Bravura rendering, and playback
highlighting on Android 9–15 ARM64 emulators. The AAR—not a JAR—is required
because the Android package includes native Swift libraries and font resources.
The Compose adapter follows the Android system color scheme by default and can
be pinned or customized with `AthenaNotationColors`.
Its JSON scene also contains localized event labels consumed by the included
TalkBack semantics layer.

## Quick Start

### Import and render MusicXML

```swift
import AthenaMusicXML
import AthenaNotationRenderApple
import SwiftUI

let imported = try MusicXMLImporter().parse(data: musicXMLData)

struct ScoreView: View {
  var body: some View {
    ScrollableNativeScorePreview(
      score: imported.score,
      preferredSystemCount: 2
    )
  }
}
```

`ScrollableNativeScorePreview` preserves a readable minimum height for every
system and scrolls vertically when its viewport is shorter than the score.
Use `NativeScorePreview` directly only when the containing view already owns
the notation canvas size.

Both Apple render views follow the SwiftUI color scheme automatically. To pin
the notation to a specific palette, pass `theme: .light` or `theme: .dark`;
`NativeScoreTheme` also accepts custom background, foreground, and playback
highlight colors.

See [MusicXML coverage](Documentation/MusicXMLCoverage.md) for the notation
preserved by the 1.0 importer and its documented limitations.

### Navigate and describe a score

```swift
import AthenaScoreAnalysis

let navigator = ScoreNavigator(score: imported.score)
let first = navigator.entries.first
let next = first.flatMap { navigator.next(after: $0.id) }
let label = first.map {
  ScoreAccessibilityFormatter(localeIdentifier: "zh_CN").label(for: $0)
}
```

Navigation uses exact rational onset, measure, and beat values. The Apple
renderer exposes the same entries to VoiceOver; Android render JSON contains
matching TalkBack metadata. See [Accessibility and navigation](Documentation/Accessibility.md).

### Import a MIDI file

```swift
import AthenaMIDI

let imported = try MIDIFileImporter().parse(data: midiData)
let score = imported.score
let initialTempo = imported.tempoBPM
```

With CocoaPods, replace the focused imports with:

```swift
import AthenaNotation
```

## Example App

Run the bundled macOS SwiftUI example:

```sh
swift run AthenaNotationExample
```

You can also open `Package.swift` in Xcode and run the
`AthenaNotationExample` scheme. The example renders a two-staff piano score
and imports MusicXML, `.mid`, and `.midi` files.

## Modules

| Module | Responsibility |
| --- | --- |
| `AthenaNotationCore` | Score semantics and exact musical time |
| `AthenaNotationLayout` | Engraving, spacing, collision, and system planning |
| `AthenaNotationRenderApple` | Native SwiftUI renderer and Bravura resources |
| `AthenaNotationRenderAndroid` | Android display-list renderer, JSON bridge, and Bravura resources |
| `AthenaScoreAnalysis` | Tempo, expression, pedal, and playback timelines |
| `AthenaMusicXML` | MusicXML importer |
| `AthenaMIDI` | Standard MIDI File importer |

## Development

```sh
git clone https://github.com/cubehead/AthenaNotation.git
cd AthenaNotation
swift test
Tools/check-api-baseline.sh
swift build --target AthenaNotationRenderAndroid
swift build --product AthenaNotationExample
pod lib lint AthenaNotation.podspec --allow-warnings
```

The current test suite covers score semantics, notation layout, committed SVG
engraving fixtures, SMuFL glyphs, MusicXML, MIDI, accessibility, navigation,
and analysis timelines.

See [engraving visual regression](Documentation/VisualRegression.md) for the
golden-file review workflow and [public API stability](Documentation/APIStability.md)
for the 1.x compatibility gate.

## Roadmap

- [x] Native semantic score model
- [x] Native SwiftUI grand-staff renderer
- [x] Android render display list and Jetpack Compose Canvas adapter
- [x] MusicXML and MIDI file import
- [x] Swift Package Manager and CocoaPods distribution
- [x] Expand MusicXML notation coverage
- [x] Add visual regression fixtures for engraving
- [x] Improve accessibility and score-navigation APIs
- [x] Stabilize the public API for 1.0

The 1.0 roadmap is complete. Future work is tracked through GitHub issues and
must preserve the [1.x compatibility contract](Documentation/APIStability.md).

## Contributing

Issues and pull requests are welcome. For substantial public API or engraving
changes, please open an issue first.

Read [CONTRIBUTING.md](CONTRIBUTING.md) and the
[Code of Conduct](CODE_OF_CONDUCT.md) before contributing.

## Releasing

Maintainer instructions for Git tags, GitHub Releases, Swift Package Manager,
and Git-based CocoaPods distribution are in [RELEASING.md](RELEASING.md).

## Brand assets

The transparent AthenaNotation mark is available in
[`Assets/Brand`](Assets/Brand/README.md). It combines an abstract Athena helmet,
a musical note, and a five-line staff. Brand assets are distributed under the
same MIT license as the project.

## License

AthenaNotation source code is available under the [MIT License](LICENSE).

The bundled Bravura font is licensed separately under the SIL Open Font
License 1.1. See
`Sources/AthenaNotationRenderApple/Resources/Bravura.LICENSE.txt` and
[NOTICE](NOTICE).

## Acknowledgements

- [Bravura](https://github.com/steinbergmedia/bravura), the SMuFL-compliant
  music font by Steinberg
- [SMuFL](https://www.smufl.org/), the Standard Music Font Layout specification
