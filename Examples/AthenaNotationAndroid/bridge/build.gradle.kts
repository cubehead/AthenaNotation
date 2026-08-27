import org.gradle.api.tasks.AbstractCopyTask
import org.gradle.api.tasks.Exec
import org.gradle.api.tasks.Sync
import org.jetbrains.kotlin.gradle.dsl.JvmTarget
import java.io.ByteArrayInputStream
import java.util.zip.ZipFile
import java.util.zip.ZipInputStream

plugins {
  alias(libs.plugins.android.library)
  alias(libs.plugins.kotlin.android)
  alias(libs.plugins.kotlin.compose)
}

base { archivesName.set("athena-notation-android") }

android {
  namespace = "io.github.cubehead.athenanotation.bridge"
  compileSdk = 35

  defaultConfig {
    minSdk = 28
    ndk { abiFilters += "arm64-v8a" }
  }

  buildTypes {
    debug { isJniDebuggable = true }
    release {
      isMinifyEnabled = false
      isJniDebuggable = false
    }
  }

  compileOptions {
    sourceCompatibility = JavaVersion.VERSION_17
    targetCompatibility = JavaVersion.VERSION_17
  }
  buildFeatures { compose = true }

  sourceSets.getByName("main").java.srcDir("../../../Integrations/AndroidCompose")
}

kotlin { compilerOptions { jvmTarget.set(JvmTarget.JVM_17) } }

dependencies {
  implementation(platform(libs.androidx.compose.bom))
  implementation(libs.androidx.compose.ui)
  implementation(libs.androidx.compose.foundation)
}

val userHome = System.getProperty("user.home")
val swiftly = file("$userHome/.swiftly/bin/swiftly")
val swiftSDK = file(
  "$userHome/Library/org.swift.swiftpm/swift-sdks/" +
    "swift-6.3.3-RELEASE_android.artifactbundle/swift-android"
)
val swiftPackage = file("src/main/swift")
val swiftTriple = "aarch64-unknown-linux-android28"
val ndkTarget = "aarch64-linux-android28"
val swiftDebugOutput = file("src/main/swift/.build/$swiftTriple/debug")
val swiftReleaseOutput = file("src/main/swift/.build/$swiftTriple/release")
val swiftNDK = swiftSDK.resolve("android-ndk-r27d")
val ndkToolchain = swiftNDK.resolve("toolchains/llvm/prebuilt/darwin-x86_64")
val ndkSysroot = ndkToolchain.resolve("sysroot")
val zlibArchive = ndkSysroot.resolve("usr/lib/aarch64-linux-android/libz.a")
val zlibBootstrap = layout.buildDirectory.file("swiftBootstrap/arm64-v8a/libAthenaZlib.so")
val generatedDebugJniLibs = layout.buildDirectory.dir("generated/jniLibs/debug/arm64-v8a")
val generatedReleaseJniLibs = layout.buildDirectory.dir("generated/jniLibs/release/arm64-v8a")
val swiftRuntimeLibraries = listOf(
  "libBlocksRuntime.so",
  "libFoundation.so",
  "libFoundationEssentials.so",
  "libFoundationInternationalization.so",
  "libFoundationXML.so",
  "lib_FoundationICU.so",
  "libdispatch.so",
  "libswiftAndroid.so",
  "libswiftCore.so",
  "libswiftDispatch.so",
  "libswiftSynchronization.so",
  "libswiftSwiftOnoneSupport.so",
  "libswift_Builtin_float.so",
  "libswift_Concurrency.so",
  "libswift_RegexParser.so",
  "libswift_StringProcessing.so",
  "libswift_math.so",
)

val buildSwiftDebugArm64 by tasks.registering(Exec::class) {
  group = "build"
  description = "Cross-compiles the AthenaNotation JNI bridge for Android ARM64."
  workingDir(swiftPackage)
  executable(swiftly)
  args(
    "run", "+6.3.3", "swift", "build",
    "--swift-sdk", swiftTriple,
    "--build-system", "native",
  )
  inputs.file(swiftPackage.resolve("Package.swift"))
  inputs.dir(swiftPackage.resolve("Sources"))
  inputs.dir(file("../../../Sources"))
  outputs.dir(swiftDebugOutput)
}

val buildSwiftReleaseArm64 by tasks.registering(Exec::class) {
  group = "build"
  description = "Cross-compiles the release AthenaNotation JNI bridge for Android ARM64."
  workingDir(swiftPackage)
  executable(swiftly)
  args(
    "run", "+6.3.3", "swift", "build",
    "--swift-sdk", swiftTriple,
    "--build-system", "native",
    "-c", "release",
  )
  inputs.file(swiftPackage.resolve("Package.swift"))
  inputs.dir(swiftPackage.resolve("Sources"))
  inputs.dir(file("../../../Sources"))
  outputs.dir(swiftReleaseOutput)
}

val buildZlibBootstrapArm64 by tasks.registering(Exec::class) {
  group = "build"
  description = "Builds the global zlib bootstrap required by Swift FoundationXML."
  executable(ndkToolchain.resolve("bin/clang"))
  args(
    "--target=$ndkTarget",
    "--sysroot=$ndkSysroot",
    "-shared",
    "-Wl,-z,global",
    "-Wl,-z,max-page-size=16384",
    "-Wl,--whole-archive", zlibArchive,
    "-Wl,--no-whole-archive",
    "-o", zlibBootstrap.get().asFile,
  )
  inputs.file(zlibArchive)
  outputs.file(zlibBootstrap)
  doFirst { zlibBootstrap.get().asFile.parentFile.mkdirs() }
}

fun AbstractCopyTask.includeSwiftRuntime(output: File) {
  from(output) { include("*.so", "*.so.*") }
  from(zlibBootstrap.map { it.asFile.parentFile }) { include("libAthenaZlib.so") }
  from(swiftSDK.resolve("swift-resources/usr/lib/swift-aarch64/android")) {
    include(*swiftRuntimeLibraries.toTypedArray())
  }
  from(swiftSDK.resolve("ndk-sysroot/usr/lib/aarch64-linux-android")) {
    include("libc++_shared.so")
  }
}

val copyDebugSwiftLibraries by tasks.registering(Sync::class) {
  dependsOn(buildSwiftDebugArm64, buildZlibBootstrapArm64)
  includeSwiftRuntime(swiftDebugOutput)
  into(generatedDebugJniLibs)
}

val copyReleaseSwiftLibraries by tasks.registering(Sync::class) {
  dependsOn(buildSwiftReleaseArm64, buildZlibBootstrapArm64)
  includeSwiftRuntime(swiftReleaseOutput)
  into(generatedReleaseJniLibs)
}

android.sourceSets.getByName("debug").jniLibs.srcDir(
  layout.buildDirectory.dir("generated/jniLibs/debug")
)
android.sourceSets.getByName("release").jniLibs.srcDir(
  layout.buildDirectory.dir("generated/jniLibs/release")
)

tasks.configureEach {
  if (name == "preDebugBuild") dependsOn(copyDebugSwiftLibraries)
  if (name == "preReleaseBuild") dependsOn(copyReleaseSwiftLibraries)
}

val verifyReleaseAar by tasks.registering {
  group = "verification"
  description = "Verifies that the release AAR contains the Android API, resources, and Swift runtime."
  dependsOn("assembleRelease")

  doLast {
    val aar = layout.buildDirectory.file(
      "outputs/aar/athena-notation-android-release.aar"
    ).get().asFile
    check(aar.isFile) { "Release AAR was not produced: $aar" }
    ZipFile(aar).use { zip ->
      val requiredEntries = setOf(
        "AndroidManifest.xml",
        "classes.jar",
        "res/font/bravura.otf",
        "jni/arm64-v8a/libAthenaNotationAndroidBridge.so",
        "jni/arm64-v8a/libAthenaZlib.so",
        "jni/arm64-v8a/libFoundationXML.so",
        "jni/arm64-v8a/libswiftCore.so",
        "jni/arm64-v8a/libc++_shared.so",
      )
      val names = zip.entries().asSequence().map { it.name }.toSet()
      check(names.containsAll(requiredEntries)) {
        "AAR is missing: ${requiredEntries - names}"
      }

      val classes = zip.getInputStream(zip.getEntry("classes.jar")).readBytes()
      ZipInputStream(ByteArrayInputStream(classes)).use { classJar ->
        val classNames = generateSequence { classJar.nextEntry }.map { it.name }.toSet()
        val requiredClasses = setOf(
          "io/github/cubehead/athenanotation/SwiftNotation.class",
          "io/github/cubehead/athenanotation/compose/AthenaNotationCanvasKt.class",
        )
        check(classNames.containsAll(requiredClasses)) {
          "classes.jar is missing: ${requiredClasses - classNames}"
        }
      }
    }
  }
}
