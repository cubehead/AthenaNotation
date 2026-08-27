# Architecture

AthenaNotation uses one-way dependencies so the semantic score remains usable
without UI or importers.

```text
AthenaNotationCore
├── AthenaNotationLayout
│   └── AthenaNotationRenderApple
├── AthenaScoreAnalysis
├── AthenaMusicXML
└── AthenaMIDI
```

## AthenaNotationCore

Owns exact score semantics: rational durations, pitches and spellings, staves,
voices, events, attachments, tuplets, spanners, voltas, tempo changes,
dynamics, pedal ranges and barlines. It does not import SwiftUI.

## AthenaNotationLayout

Transforms semantics into engraving decisions. Planners handle horizontal
spacing, systems, beams, chord notehead displacement, accidentals, tuplets,
spanners and voltas. Layout depends only on the semantic model.

## AthenaNotationRenderApple

Renders the layout with SwiftUI Canvas, CoreText and the bundled Bravura SMuFL
font. Highlighted event IDs are input state; playback engines remain outside
this package.

## AthenaScoreAnalysis

Builds tempo, count-in, playback, expression, pedal and active-note timelines.
It analyzes score state but does not play audio or communicate with MIDI
hardware.

## Importers

`AthenaMusicXML` and `AthenaMIDI` translate external files into the same
`NotationScore` model. Unknown or unsupported data should produce diagnostics
without leaking format-specific types into the core.

## Extension boundary

The following deliberately stay outside this repository:

- audio engines and SoundFont banks
- live MIDI endpoint management and practice scoring
- OVE or other optional/proprietary importers
- LED waterfall UI and ESP32 communication
- complete product UI, accounts, libraries and commerce

Extensions may depend on AthenaNotation. AthenaNotation must never depend on an
extension.
