# 公开 API 稳定性

AthenaNotation 1.x 遵循语义化版本。以下库产品的公开声明属于兼容性承诺范围：

- `AthenaNotationCore`
- `AthenaNotationLayout`
- `AthenaNotationRenderApple`
- `AthenaNotationRenderAndroid`
- `AthenaScoreAnalysis`
- `AthenaMusicXML`
- `AthenaMIDI`

## 兼容性承诺

补丁版本用于修复问题，不会有意破坏源码兼容性。次版本可以增加 API、乐谱符号、
绘制命令和可选 Codable 字段。删除或重命名公开声明、改变其类型，或者改变已有语义，
必须提升主版本号。

Codable 与 Android JSON 使用方必须忽略未知字段。次版本可能增加枚举成员或新的
raw-value 乐谱类型，客户端应为暂未识别的符号保留降级行为。

## 自动化基线

[`API/PublicAPI.txt`](../API/PublicAPI.txt) 由 Swift Symbol Graph 生成。CI 执行：

```sh
Tools/check-api-baseline.sh
```

经过评审、确认兼容的 API 增量可以这样更新基线：

```sh
Tools/check-api-baseline.sh --record
```

文本基线是代码评审门禁，不能替代行为测试和语义化版本判断。

## 1.0 过渡

1.0 从这份基线开始提供稳定性承诺；更早的 0.1 预览 API 允许在 1.0 中完成最后整理。
