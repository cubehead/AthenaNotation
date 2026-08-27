# AthenaNotation

[English](README.md) | [简体中文](README.zh-CN.md)

[![CI](https://github.com/cubehead/AthenaNotation/actions/workflows/ci.yml/badge.svg)](https://github.com/cubehead/AthenaNotation/actions/workflows/ci.yml)
[![Swift 6.0](https://img.shields.io/badge/Swift-6.0-F05138?logo=swift&logoColor=white)](https://www.swift.org/)
[![Platforms](https://img.shields.io/badge/platforms-iPadOS%2017%2B%20%7C%20macOS%2015%2B-lightgrey)](Package.swift)
[![CocoaPods](https://img.shields.io/badge/CocoaPods-GitHub%20source-EE3322?logo=cocoapods&logoColor=white)](AthenaNotation.podspec)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

A native Swift music-notation engine for iPadOS and macOS.

AthenaNotation provides a semantic score model, engraving layout, SwiftUI
renderer, MusicXML and MIDI importers, and score-timeline analysis—without a
WebView, JavaScript renderer, or third-party MIDI runtime.

> **Project status:** AthenaNotation is under active development. Public APIs
> may change before version 1.0.

## Features

- Exact rational timing, multiple voices, and grand-staff scores
- Notes, rests, dots, beams, tuplets, ties, slurs, and ledger lines
- Accidentals, fingerings, dynamics, hairpins, pedal markings, repeats, voltas,
  and final barlines
- Native SwiftUI and Canvas rendering with the Bravura SMuFL font
- MusicXML `score-partwise` import
- Standard MIDI File Type 0 and Type 1 import
- Tempo changes, count-in, expression, pedal, and playback-timeline analysis
- Focused products, so clients can depend on only the modules they need

## Scope

AthenaNotation is the open-source notation core. It intentionally excludes:

- audio engines and SoundFont banks
- live MIDI device management and practice scoring
- OVE and other optional or proprietary importers
- LED waterfall UI and ESP32 communication
- product-specific application UI and services

Those features belong in packages that depend on AthenaNotation, never the
other way around. See [Architecture](Documentation/Architecture.md).

## Requirements

- Swift 6.0 or later
- iOS / iPadOS 17 or later
- macOS 15 or later

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
    from: "0.1.0"
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
      :tag => '0.1.0'
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

## Quick Start

### Import and render MusicXML

```swift
import AthenaMusicXML
import AthenaNotationRenderApple
import SwiftUI

let imported = try MusicXMLImporter().parse(data: musicXMLData)

struct ScoreView: View {
  var body: some View {
    NativeScorePreview(
      score: imported.score,
      preferredSystemCount: 2
    )
  }
}
```

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
| `AthenaScoreAnalysis` | Tempo, expression, pedal, and playback timelines |
| `AthenaMusicXML` | MusicXML importer |
| `AthenaMIDI` | Standard MIDI File importer |

## Development

```sh
git clone https://github.com/cubehead/AthenaNotation.git
cd AthenaNotation
swift test
swift build --product AthenaNotationExample
pod lib lint AthenaNotation.podspec --allow-warnings
```

The current test suite covers score semantics, notation layout, SMuFL glyphs,
MusicXML, MIDI, and analysis timelines.

## Roadmap

- [x] Native semantic score model
- [x] Native SwiftUI grand-staff renderer
- [x] MusicXML and MIDI file import
- [x] Swift Package Manager and CocoaPods distribution
- [ ] Expand MusicXML notation coverage
- [ ] Add visual regression fixtures for engraving
- [ ] Improve accessibility and score-navigation APIs
- [ ] Stabilize the public API for 1.0

## Contributing

Issues and pull requests are welcome. For substantial public API or engraving
changes, please open an issue first.

Read [CONTRIBUTING.md](CONTRIBUTING.md) and the
[Code of Conduct](CODE_OF_CONDUCT.md) before contributing.

## Releasing

Maintainer instructions for Git tags, GitHub Releases, Swift Package Manager,
and Git-based CocoaPods distribution are in [RELEASING.md](RELEASING.md).

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
