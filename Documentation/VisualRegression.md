# Engraving visual regression

The renderer test target commits deterministic SVG golden files in:

```text
Tests/AthenaNotationRenderAndroidTests/__Snapshots__/
```

The fixtures exercise grand staff geometry, chords at a second, stems, beams,
playback highlighting, fingerings, dynamics, SMuFL attachments, tuplets,
slurs, hairpins, pedal, repeats, voltas, final barlines, and multi-system
layout. They are normal SVG documents and can be reviewed in a browser or a
pull-request diff.

Every `swift test` run regenerates the scene in memory and compares its complete
SVG output byte-for-byte with the committed file. To accept an intentional
engraving change after visual review:

```sh
ATHENA_RECORD_SNAPSHOTS=1 swift test --filter EngravingSnapshotTests
swift test --filter EngravingSnapshotTests
```

Never record snapshots merely to make CI green. Review both SVGs at their
native viewBox size, confirm the change is intended, and commit the renderer,
tests, and updated fixtures together.

---

# 雕版视觉回归

测试目标在 `Tests/AthenaNotationRenderAndroidTests/__Snapshots__/` 保存确定性
SVG 金图。它覆盖双谱表、二度和弦错位、符杆/连桁、播放高亮、指法、力度、SMuFL
附加符号、Tuplet、连音线、渐强渐弱、踏板、重复、Volta、终止线和多行排版。

普通 `swift test` 会逐字节比较重新生成的 SVG。只有在人工查看并确认雕版变化正确后，
才能使用 `ATHENA_RECORD_SNAPSHOTS=1` 更新金图。
