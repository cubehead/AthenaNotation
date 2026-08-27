<p align="center">
  <img src="Assets/Brand/athena-notation-mark.png" width="168" alt="AthenaNotation 标志">
</p>

<h1 align="center">AthenaNotation</h1>

<p align="center">
  面向 iPadOS、macOS 和 Android 的原生 Swift 乐谱引擎。
</p>

<p align="center">
  <a href="README.md">English</a> · <a href="README.zh-CN.md">简体中文</a>
</p>

[![CI](https://github.com/cubehead/AthenaNotation/actions/workflows/ci.yml/badge.svg)](https://github.com/cubehead/AthenaNotation/actions/workflows/ci.yml)
[![Swift 6.0](https://img.shields.io/badge/Swift-6.0-F05138?logo=swift&logoColor=white)](https://www.swift.org/)
[![支持平台](https://img.shields.io/badge/platforms-iPadOS%20%7C%20macOS%20%7C%20Android-lightgrey)](Package.swift)
[![CocoaPods](https://img.shields.io/badge/CocoaPods-GitHub%20source-EE3322?logo=cocoapods&logoColor=white)](AthenaNotation.podspec)
[![MIT License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

AthenaNotation 提供乐谱语义模型、排版、SwiftUI 渲染、MusicXML/MIDI
导入和乐谱时间线分析，不依赖 WebView、JavaScript 渲染器或第三方 MIDI
运行库。

> **项目状态：** AthenaNotation 正在积极开发中；在 1.0 版本之前，公开 API
> 仍可能调整。

## 功能

- 精确有理数时间、多声部和钢琴高低音双谱表
- 音符、休止、附点、连桁、Tuplet、延音线、连音线和加线
- 升降号、指法、力度、渐强渐弱、踏板、重复、Volta 和终止线
- Apple 端基于 SwiftUI、Canvas 和 Bravura SMuFL 字体的原生渲染
- Android 端由 Swift 生成雕版绘制列表，Jetpack Compose Canvas 原生执行
- MusicXML `score-partwise` 导入
- Standard MIDI File Type 0 和 Type 1 导入
- 速度变化、倒计时、表情、踏板和播放时间线分析
- 可按需选择的细粒度 Swift Package 产品

## 项目边界

AthenaNotation 是开源的乐谱核心，明确不包含：

- 音频引擎和 SoundFont 音色库
- 实时 MIDI 设备管理和练琴打分
- OVE 及其他可选或专有格式导入
- LED 瀑布流 UI 和 ESP32 通讯
- 完整产品的业务 UI 与服务

上述功能可以依赖 AthenaNotation，但 AthenaNotation 不能反向依赖它们。
详细说明见[架构文档](Documentation/Architecture.md)。

## 环境要求

- Swift 6.0+
- iOS / iPadOS 17+
- macOS 15+
- Android 构建需要 Swift 6.3、Swift SDK for Android 和 Android NDK r27d+

## 安装

### Swift Package Manager

在 Xcode 中选择 **File → Add Package Dependencies**，输入：

```text
https://github.com/cubehead/AthenaNotation.git
```

也可以在 `Package.swift` 中添加：

```swift
dependencies: [
  .package(
    url: "https://github.com/cubehead/AthenaNotation.git",
    from: "0.1.0"
  )
]
```

添加完整产品：

```swift
.product(name: "AthenaNotation", package: "AthenaNotation")
```

也可以只选择需要的产品：

- `AthenaNotationCore`
- `AthenaNotationRenderApple`
- `AthenaNotationRenderAndroid`
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

保存 Podfile 后运行 `pod install`。这种方式直接从 GitHub 安装固定版本，
不要求 AthenaNotation 出现在 CocoaPods 公共 Specs 索引中。

如果需要跟踪最新的 `main` 分支：

```ruby
pod 'AthenaNotation',
    :git => 'https://github.com/cubehead/AthenaNotation.git',
    :branch => 'main'
```

正式 App 建议使用版本标签，保证构建可重复；分支形式更适合开发和早期体验。

使用本地检出版本：

```ruby
pod 'AthenaNotation', :path => '../AthenaNotation'
```

Swift Package Manager 会保留上面的细粒度模块；CocoaPods 则会把全部开源核心
编译为一个 `AthenaNotation` 模块。

### Android / Jetpack Compose

使用官方 Swift SDK for Android 交叉编译 `AthenaNotationRenderAndroid`，通过
`swift-java` 暴露 `AndroidRenderBridge`，再用仓库提供的 Compose 适配器执行
JSON 绘制列表：

```swift
let sceneJSON = try AndroidRenderBridge().renderScoreJSON(
  scoreJSON,
  width: 1024,
  height: 720,
  preferredSystemCount: 2,
  playbackEventIDs: ["current-event-id"]
)
```

乐谱几何计算仍由 Swift 统一负责，Kotlin 只通过原生 Compose Canvas 执行绘制，
不使用 WebView 或 JavaScript。详见
[Android Compose 接入说明](Integrations/AndroidCompose/README.md)；也可以直接运行
[完整 Android 示例](Examples/AthenaNotationAndroid/README.md)，在 ARM64 模拟器中
构建可分发 AAR，并在 Android 9～15 上端到端测试 Swift/JNI 桥接、MusicXML、
MIDI、Bravura 渲染和播放高亮。由于包内含 Swift 原生库和字体资源，Android
发布物应使用 AAR，而不是 JAR。

## 快速开始

### 导入并显示 MusicXML

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

### 导入 MIDI 文件

```swift
import AthenaMIDI

let imported = try MIDIFileImporter().parse(data: midiData)
let score = imported.score
let initialTempo = imported.tempoBPM
```

通过 CocoaPods 接入时，将上述细粒度导入替换为：

```swift
import AthenaNotation
```

## 示例 App

运行仓库自带的 macOS SwiftUI 示例：

```sh
swift run AthenaNotationExample
```

也可以直接在 Xcode 打开 `Package.swift`，运行
`AthenaNotationExample` scheme。示例可以显示双谱表钢琴谱，并导入
MusicXML、`.mid` 和 `.midi` 文件。

## 模块

| 模块 | 职责 |
| --- | --- |
| `AthenaNotationCore` | 乐谱语义和精确音乐时间 |
| `AthenaNotationLayout` | 雕版、间距、碰撞和系统排版 |
| `AthenaNotationRenderApple` | 原生 SwiftUI 渲染和 Bravura 资源 |
| `AthenaNotationRenderAndroid` | Android 绘制列表、JSON 桥接和 Bravura 资源 |
| `AthenaScoreAnalysis` | 速度、表情、踏板和播放时间线 |
| `AthenaMusicXML` | MusicXML 导入 |
| `AthenaMIDI` | Standard MIDI File 导入 |

## 开发

```sh
git clone https://github.com/cubehead/AthenaNotation.git
cd AthenaNotation
swift test
swift build --target AthenaNotationRenderAndroid
swift build --product AthenaNotationExample
pod lib lint AthenaNotation.podspec --allow-warnings
```

当前测试覆盖乐谱语义、排版、SMuFL 字形、MusicXML、MIDI 和分析时间线。

## 路线图

- [x] 原生乐谱语义模型
- [x] 原生 SwiftUI 钢琴双谱表渲染
- [x] Android 绘制列表和 Jetpack Compose Canvas 适配器
- [x] MusicXML 和 MIDI 文件导入
- [x] Swift Package Manager 和 CocoaPods 发布配置
- [ ] 扩展 MusicXML 符号覆盖范围
- [ ] 增加雕版视觉回归测试
- [ ] 完善无障碍与乐谱导航 API
- [ ] 稳定 1.0 公开 API

## 参与贡献

欢迎提交 Issue 和 Pull Request。涉及较大的公开 API 或雕版改动时，建议先创建
Issue 讨论。

贡献前请阅读 [CONTRIBUTING.md](CONTRIBUTING.md) 和
[行为准则](CODE_OF_CONDUCT.md)。

## 发布

Git 标签、GitHub Releases、Swift Package Manager 和基于 Git 的 CocoaPods
发布步骤见 [RELEASING.md](RELEASING.md)。

## 品牌资源

透明背景的 AthenaNotation 标志位于
[`Assets/Brand`](Assets/Brand/README.md)。图形融合了抽象雅典娜头盔、音符与
五线谱；品牌资源与项目代码采用相同的 MIT 许可。

## 开源协议

AthenaNotation 源代码使用 [MIT License](LICENSE)。

项目附带的 Bravura 字体单独使用 SIL Open Font License 1.1，完整文本位于
`Sources/AthenaNotationRenderApple/Resources/Bravura.LICENSE.txt`，另见
[NOTICE](NOTICE)。

## 致谢

- [Bravura](https://github.com/steinbergmedia/bravura)：Steinberg 提供的
  SMuFL 乐谱字体
- [SMuFL](https://www.smufl.org/)：Standard Music Font Layout 标准
