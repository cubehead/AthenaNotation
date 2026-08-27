# Accessibility and score navigation

`AthenaScoreAnalysis` provides UI-independent navigation and spoken score
descriptions. The same semantic order is used by Apple VoiceOver and Android
TalkBack integrations.

## Navigation

```swift
let navigator = ScoreNavigator(score: score)

let current = navigator.entry(id: selectedEventID)
let next = navigator.next(after: selectedEventID)
let previous = navigator.previous(before: selectedEventID)
let secondMeasure = navigator.entries(inMeasure: 2)
let nearestBassEvent = navigator.nearest(to: position, staffID: "bass")
```

Each `ScoreNavigationEntry` contains the stable event ID, voice, staff through
its event, exact onset and end, one-based measure number, and an exact one-based
beat. Simultaneous events are ordered by staff, voice, then stable event ID.

## Spoken labels

```swift
let formatter = ScoreAccessibilityFormatter(localeIdentifier: "en_US")
let label = formatter.label(for: navigator.entries[0])
```

English and Simplified Chinese labels describe position, note/chord/rest,
pitch spelling, written duration, dots, fingering, dynamics, text, techniques,
and preserved notation symbols. Other locales currently fall back to English.

`NativeScorePreview` creates virtual accessibility children for every entry.
`AndroidRenderScene.accessibility` carries matching labels over the JSON/JNI
boundary; `AthenaNotationCanvas.kt` creates TalkBack semantics nodes from them.

---

# 无障碍与乐谱导航

`AthenaScoreAnalysis` 提供不依赖 UI 框架的乐谱导航和朗读描述。Apple
VoiceOver 与 Android TalkBack 使用同一套语义顺序。

`ScoreNavigator` 可以按稳定事件 ID 查询前后事件、按小节读取、按精确时间和谱表
寻找最近事件。每个 `ScoreNavigationEntry` 都包含精确起止时间、从 1 开始的小节号
和拍位；同时发生的事件按谱表、声部和稳定 ID 排序。

`ScoreAccessibilityFormatter` 目前提供英文和简体中文标签，内容包括位置、音符/
和弦/休止、音高拼写、时值、附点、指法、力度、文字、奏法和已保留的符号。
Apple 渲染视图会自动创建 VoiceOver 虚拟子元素；Android JSON 的
`accessibility` 数组由 Compose 适配器转换为 TalkBack 语义节点。
