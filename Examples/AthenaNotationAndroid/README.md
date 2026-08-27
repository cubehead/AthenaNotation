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

Then validate the host build and run the device-side tests:

```sh
./gradlew testDebugUnitTest
./gradlew connectedDebugAndroidTest
```

The four device tests verify:

- Swift/JNI library loading in the Android application process
- MusicXML import and Swift display-list generation
- MIDI import and Swift display-list generation
- Compose rendering with black engraving pixels and blue playback highlighting

The screenshot test also writes `athena-notation.png` into the app's external
files directory while the test package is installed. The example packages a
small ARM64 zlib bootstrap because Swift 6.3's Android `FoundationXML` binary
uses zlib symbols without declaring `libz.so` as a direct ELF dependency.
