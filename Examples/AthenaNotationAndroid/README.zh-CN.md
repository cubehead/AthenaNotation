# AthenaNotation Android 运行时示例

[English](README.md) | 简体中文

这个项目会把 `AthenaNotation` 交叉编译为 Android ARM64 动态库，通过 JNI
加载，并使用 Jetpack Compose Canvas 执行 Swift 生成的绘制列表。设备测试会在
真实 Android 进程内导入 MusicXML 和 MIDI，并对最终乐谱图像做像素断言。

它不只是交叉编译样例，而是一套运行时验证应用，覆盖 Swift Foundation、JNI
边界、核心导入器、绘制列表序列化、Bravura 字形和 Compose Canvas。

## 环境要求

- swift.org Swift 6.3.3 及其对应的 Swift SDK for Android
- Swift SDK 包内配置的 Android NDK r27d
- Android SDK 35，以及 API 28 或更高版本的 ARM64 模拟器
- JDK 17 或更高版本

如果 Android Studio 尚未生成，请创建 `local.properties`：

```properties
sdk.dir=/Android/sdk/的绝对路径
```

通过 Android Studio Device Manager 启动 ARM64 AVD，或使用命令行：

```sh
$ANDROID_SDK_ROOT/emulator/emulator @Pixel_3a_API_34
```

## 构建 AAR

构建并校验可分发的 Release AAR：

```sh
./gradlew :bridge:verifyReleaseAar
```

产物位于
`bridge/build/outputs/aar/athena-notation-android-release.aar`，其中已经包含
Kotlin/JNI API、Compose 渲染器、Bravura 字体、ARM64 Swift 动态库、必要的
Swift runtime、libc++ 和 zlib bootstrap。这里不能只使用 JAR，因为 JAR 无法
完整携带 Android 资源和按 ABI 区分的原生动态库。

使用本地文件接入时，把 AAR 复制到应用的 `libs` 目录：

```kotlin
dependencies {
    implementation(files("libs/athena-notation-android-release.aar"))
    implementation(platform("androidx.compose:compose-bom:2024.09.00"))
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.foundation:foundation")
}
```

通过打包后的 API 渲染实际数据：

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

该可滚动组件会按可用宽度显示乐谱并保留纵向间距；窗口高度不足时滚动乐谱，
不会再把五线谱整体缩小。播放高亮变化时，也会自动滚动到当前事件。

触摸能力可以开关，回调返回语义事件 ID。Example 把开关、状态文字和 A–B 按钮
保留在应用 UI 中，但触摸后的高亮渲染、A–B 步进结果以及倒计时时长/拍数都调用
共享 Swift 层。`resolveABStep` 会返回 `advanced`、`looped` 或 `finished`，并给出
下一步宿主动作；倒计时具体怎么显示仍完全由应用决定。

## 运行时测试

示例 App 会刻意依赖生成出来的 **Release AAR 文件**，而不是依赖 `bridge`
源码 module。启动 ARM64 模拟器后运行：

```sh
./gradlew :app:connectedDebugAndroidTest
```

设备测试会验证：

- Android 应用进程内加载 Swift/JNI 动态库
- MusicXML 导入及 Swift 绘制列表生成
- MIDI 导入及 Swift 绘制列表生成
- Compose 乐谱渲染，包括黑色雕版像素和蓝色播放高亮
- 由 Swift 导航元数据生成的逐事件 TalkBack 无障碍语义
- 通过 JNI 复用的 Swift A–B 循环和倒计时语义

截图测试还会在测试包安装期间，将 `athena-notation.png` 写入应用外部文件目录。
示例会打包一个很小的 ARM64 zlib bootstrap，因为 Swift 6.3 Android 版本的
`FoundationXML` 使用了 zlib 符号，却没有把 `libz.so` 声明为直接 ELF 依赖。

已经验证的 ARM64 模拟器矩阵：

| Android | API | 结果 |
| --- | ---: | --- |
| Android 9 | 28 | 4/4 通过 |
| Android 14 | 34 | 4/4 通过 |
| Android 15 | 35 | 6/6 通过 |
