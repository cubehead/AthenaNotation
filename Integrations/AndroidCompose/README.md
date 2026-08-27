# Android Compose integration

`AthenaNotationRenderAndroid` keeps engraving decisions in Swift and emits a
small JSON display list. `AthenaNotationCanvas.kt` executes that list with a
native Jetpack Compose `Canvas`; it does not use a WebView or JavaScript.

## Data flow

```text
MusicXML / MIDI -> NotationScore -> AndroidScoreRenderer -> JSON display list
                                                        -> Compose Canvas
```

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

