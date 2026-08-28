# Architecture

AthenaNotation uses one-way dependencies so the semantic score remains usable
without UI or importers.

```text
AthenaNotationCore
├── AthenaNotationLayout
│   ├── AthenaNotationRenderApple
│   └── AthenaNotationRenderAndroid
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
font. Highlighted event IDs are accepted as rendering state through the public
view API. The canvas publishes virtual, localized score events to VoiceOver
through `ScoreNavigator` and `ScoreAccessibilityFormatter`. Score views expose
configurable semantic touch callbacks and can keep the active playback system
visible. They do not own transport or count-in UI.

## AthenaNotationRenderAndroid

Converts the same semantic score and layout planner output into a Codable,
platform-neutral display list. `AndroidRenderBridge` exposes a string-only JSON
boundary suitable for `swift-java`/JNI. The Jetpack Compose adapter executes
lines, paths, polygons, text and Bravura glyph commands with Android's native
Canvas. It does not import SwiftUI, CoreText, UIKit, or Android APIs, which keeps
the Swift product independently cross-compilable. The scene also carries
event-level accessibility metadata that the included Compose adapter exposes
to TalkBack.

## AthenaScoreAnalysis

Builds tempo, count-in, playback, expression, pedal and active-note timelines,
plus deterministic event navigation and localized accessibility descriptions.
Clients can query by exact musical time, event identifier, measure, beat, or
staff without importing a UI framework. This module also validates A–B ranges,
resolves repeat boundaries into host actions, and creates semantic playback
callback payloads. Timers and concrete output services remain client-owned.

## Importers

`AthenaMusicXML` and `AthenaMIDI` translate external files into the same
`NotationScore` model. Unknown or unsupported data should produce diagnostics
without leaking format-specific types into the core.

MusicXML preserves common note and direction notation, including fingerings,
articulations, ornaments, lyrics, text, dynamics, hairpins, pedal, octave
shifts, glissandi, tuplets, slurs, ties, repeats and voltas. Diagnostics expose
stable codes, severities and optional measure numbers.

## Dependency boundary

The modules in this repository form a reusable library layer. Applications and
integrations consume its public products through their documented APIs, while
the semantic core and layout engine remain independent of application targets
and platform services.

Additional integrations can live in separate packages that depend on
AthenaNotation. Dependencies must not point from AthenaNotation back into a
client or integration package.

Presentation components and concrete runtime services remain client-owned.
Open modules expose semantic state and callbacks without naming a particular
application or integration.
