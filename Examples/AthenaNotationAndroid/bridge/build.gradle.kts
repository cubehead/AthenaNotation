import org.gradle.api.tasks.Copy
import org.gradle.api.tasks.Exec
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
  alias(libs.plugins.android.library)
  alias(libs.plugins.kotlin.android)
}

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
}

kotlin { compilerOptions { jvmTarget.set(JvmTarget.JVM_17) } }

val userHome = System.getProperty("user.home")
val swiftly = file("$userHome/.swiftly/bin/swiftly")
val swiftSDK = file(
  "$userHome/Library/org.swift.swiftpm/swift-sdks/" +
    "swift-6.3.3-RELEASE_android.artifactbundle/swift-android"
)
val swiftPackage = file("src/main/swift")
val swiftTriple = "aarch64-unknown-linux-android28"
val ndkTarget = "aarch64-linux-android28"
val swiftOutput = file("src/main/swift/.build/$swiftTriple/debug")
val swiftNDK = swiftSDK.resolve("android-ndk-r27d")
val ndkToolchain = swiftNDK.resolve("toolchains/llvm/prebuilt/darwin-x86_64")
val ndkSysroot = ndkToolchain.resolve("sysroot")
val zlibArchive = ndkSysroot.resolve("usr/lib/aarch64-linux-android/libz.a")
val zlibBootstrap = layout.buildDirectory.file("swiftBootstrap/arm64-v8a/libAthenaZlib.so")
val generatedJniLibs = layout.buildDirectory.dir("generated/jniLibs/debug/arm64-v8a")

val buildSwiftArm64 by tasks.registering(Exec::class) {
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
  outputs.dir(swiftOutput)
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

val copySwiftLibraries by tasks.registering(Copy::class) {
  dependsOn(buildSwiftArm64, buildZlibBootstrapArm64)

  from(swiftOutput) { include("*.so", "*.so.*") }
  from(zlibBootstrap.map { it.asFile.parentFile }) { include("libAthenaZlib.so") }
  from(swiftSDK.resolve("swift-resources/usr/lib/swift-aarch64/android")) {
    include("*.so")
  }
  from(swiftSDK.resolve("ndk-sysroot/usr/lib/aarch64-linux-android")) {
    include("libc++_shared.so")
  }
  into(generatedJniLibs)
}

android.sourceSets.getByName("main").jniLibs.srcDir(
  layout.buildDirectory.dir("generated/jniLibs/debug")
)

tasks.configureEach {
  if (name == "preDebugBuild") {
    dependsOn(copySwiftLibraries)
  }
}
