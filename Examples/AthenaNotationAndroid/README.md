# AthenaNotation Android runtime example

English | [简体中文](README.zh-CN.md)

This project builds `AthenaNotation` as an Android ARM64 shared library, loads
it through JNI, and renders the Swift-generated display list with Jetpack
Compose Canvas. Its instrumentation tests run MusicXML and MIDI import inside
an Android process and perform pixel assertions against the rendered score.

It is a runtime validation app, not just a cross-compilation sample. The test
APK exercises Swift Foundation, the JNI boundary, core importers, display-list
serialization, Bravura glyph rendering, and Compose Canvas on a real Android
runtime.

Requirements:

- swift.org Swift 6.3.3 and the matching Swift SDK for Android
- Android NDK r27d configured in the Swift SDK bundle
- Android SDK 35 and an ARM64 emulator running API 28 or later
- JDK 17 or later

Create `local.properties` if Android Studio has not already created it:

```properties
sdk.dir=/absolute/path/to/Android/sdk
```

Start an ARM64 AVD, or select one in Android Studio's Device Manager:

```sh
$ANDROID_SDK_ROOT/emulator/emulator @Pixel_3a_API_34
```

## Build the AAR

Build and verify the distributable release artifact:

```sh
./gradlew :bridge:verifyReleaseAar
```

The output is
`bridge/build/outputs/aar/athena-notation-android-release.aar`. It contains the
Kotlin/JNI API, Compose renderer, Bravura font, ARM64 Swift library, required
Swift runtime libraries, libc++, and the zlib bootstrap. A JAR is not sufficient
because it cannot package Android resources and ABI-specific native libraries.
Published versions provide the AAR and a SHA-256 checksum as GitHub Release
assets, named with both the library version and the included ARM64 ABI.

For a local file dependency, copy the AAR to your app's `libs` directory:

```kotlin
dependencies {
    implementation(files("libs/athena-notation-android-release.aar"))
    implementation(platform("androidx.compose:compose-bom:2024.09.00"))
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.foundation:foundation")
}
```

Render actual input data through the packaged API:

```kotlin
val notation = SwiftNotation()
val sceneJSON = notation.renderMusicXML(musicXMLText)
val midiSceneJSON = notation.renderMIDI(midiBytes)
val bravura = ResourcesCompat.getFont(
    context,
    io.github.cubehead.athenanotation.bridge.R.font.bravura,
)!!

ScrollableAthenaNotationCanvas(
    sceneJSON,
    bravura,
    systemCount = 1,
    touchEnabled = allowTouch,
    onEventTap = { eventID ->
        sceneJSON = notation.renderMusicXMLAtEvent(musicXMLText, eventID)
    },
    modifier = Modifier.fillMaxSize(),
)
```

The scrollable composable fits notation to the available width and preserves
its vertical spacing. A short window scrolls the score instead of scaling the
staff down. It also scrolls the active playback highlight into view.
The example includes a separate cursor-visibility switch; hiding the cursor
keeps the selected playback event and touch-to-seek state intact.

Touch handling is configurable and returns a semantic event ID. The example
keeps the switch, status text, and A–B button in application UI while calling
the shared Swift layer for hit-result rendering, A–B step resolution, and
count-in duration/beat calculations. `resolveABStep` returns `advanced`,
`looped`, or `finished` plus the next host action; the host remains free to
design any count-in presentation.

## Runtime tests

The example app intentionally depends on the generated **release AAR file**,
not on the `bridge` source project. With an ARM64 emulator running:

```sh
./gradlew :app:connectedDebugAndroidTest
```

The device tests verify:

- Swift/JNI library loading in the Android application process
- MusicXML import and Swift display-list generation
- MIDI import and Swift display-list generation
- Compose rendering with black engraving pixels and blue playback highlighting
- Event-level TalkBack semantics generated from Swift navigation metadata
- Shared Swift A–B loop and count-in semantics through JNI

The screenshot test also writes `athena-notation.png` into the app's external
files directory while the test package is installed. The example packages a
small ARM64 zlib bootstrap because Swift 6.3's Android `FoundationXML` binary
uses zlib symbols without declaring `libz.so` as a direct ELF dependency.

Validated ARM64 emulator matrix:

| Android | API | Result |
| --- | ---: | --- |
| Android 9 | 28 | 4/4 passed |
| Android 14 | 34 | 4/4 passed |
| Android 15 | 35 | 6/6 passed |
