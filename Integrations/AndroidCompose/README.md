# Android Compose integration

`AthenaNotationRenderAndroid` keeps engraving decisions in Swift and emits a
small JSON display list. `AthenaNotationCanvas.kt` executes that list with a
native Jetpack Compose `Canvas`; it does not use a WebView or JavaScript.

## Data flow

```text
MusicXML / MIDI -> NotationScore -> AndroidScoreRenderer -> JSON display list
                                                        -> Compose Canvas
```

## Toolchain

Install the matching swift.org Swift `6.3.3` toolchain,
`swift-6.3.3-RELEASE_android` SDK, and Android NDK r27d or later by following the official
[Swift SDK for Android guide](https://www.swift.org/documentation/articles/swift-sdk-for-android-getting-started.html).

Do not add a `.swift-version` file to this repository: CocoaPods interprets it
as the Swift *language mode* and requires it to match the podspec's `6.0`, while
the Android SDK requires a matching `6.3.3` *toolchain release*. Select 6.3.3
globally with Swiftly or in the shell used for Android builds instead.

Verify the renderer for a physical ARM64 device and an x86_64 emulator:

```sh
swift sdk list
swift build \
  --swift-sdk aarch64-unknown-linux-android28 \
  --target AthenaNotationRenderAndroid
swift build \
  --swift-sdk x86_64-unknown-linux-android28 \
  --target AthenaNotationRenderAndroid
```

The MusicXML, MIDI, and score-analysis products can be checked the same way by
replacing the target name with `AthenaMusicXML`, `AthenaMIDI`, or
`AthenaScoreAnalysis`.

1. Cross-compile the `AthenaNotationRenderAndroid` Swift product with the
   official Swift SDK for Android.
2. Generate a Kotlin/Java binding for `AndroidRenderBridge` with `swift-java`,
   and package the resulting shared libraries in the Android app.
3. Copy `Sources/AthenaNotationRenderAndroid/Resources/Bravura.otf` to
   `app/src/main/res/font/bravura.otf`.
4. Add `AthenaNotationCanvas.kt` to the Android application.
5. Pass the JSON returned by `renderScoreJSON` to the composable.

Example UI call:

```kotlin
val bravura = ResourcesCompat.getFont(context, R.font.bravura)!!

AthenaNotationCanvas(
    sceneJSON = renderedSceneJSON,
    bravuraTypeface = bravura,
    modifier = Modifier.fillMaxSize(),
)
```

The JSON boundary is intentional: Kotlin never depends on Swift object memory
layout, and the display list can be snapshotted for visual regression tests.
`role` and `eventID` fields also preserve hit-testing, playback highlighting,
and future accessibility metadata.
