# 发布 AthenaNotation

## 发布前一次性配置

1. 创建一个独立的公开 Git 仓库，例如 `AthenaNotation`。
2. 确认 `README.md`、`README.zh-CN.md` 和
   `AthenaNotation.podspec` 中的仓库地址与实际 GitHub 仓库一致。
3. 当前 CocoaPods 采用 GitHub 源码地址安装，不提交 CocoaPods Trunk，
   因此不需要注册 Trunk 账号。

## 每个版本

版本号遵循 Semantic Versioning：

- Patch：兼容的错误修复，例如 `0.1.1`
- Minor：兼容的新功能，例如 `0.2.0`
- Major：破坏兼容性的 API 变化，例如 `1.0.0`

发布前：

1. 更新 `CHANGELOG.md`。
2. 把 `AthenaNotation.podspec` 的 `spec.version` 改为目标版本。
3. 确认 Podspec 的 Git 地址与仓库地址一致。
4. 运行：

```sh
swift test
swift build --product AthenaNotationExample
pod lib lint AthenaNotation.podspec --allow-warnings
```

## 发布 Swift Package

SwiftPM 不需要上传单独的二进制包。根目录保留有效的 `Package.swift`，
将仓库推送到 GitHub，并发布完整三段式版本标签：

```sh
git tag 0.1.0
git push origin main
git push origin 0.1.0
```

标签必须是 `MAJOR.MINOR.PATCH`；只有 `0.1` 不会被 SwiftPM 识别为完整版本。
建议同时在 GitHub 创建同名 Release，并粘贴本版本的 Changelog。

客户端随后可以使用：

```swift
.package(
  url: "https://github.com/cubehead/AthenaNotation.git",
  from: "0.1.0"
)
```

如未来需要发布到支持 SE-0391 的 Swift Package Registry，可在配置登录和
签名后使用 `swift package-registry publish`；Git 标签发布仍是首发阶段最简单、
兼容面最广的方式。

## 通过 GitHub 发布 CocoaPods

必须推送与 Podspec 版本完全一致的 Git 标签，因为 Podspec 的
`spec.source` 和客户端 Podfile 都会读取该标签。

发布前验证本地 Podspec：

```sh
pod lib lint AthenaNotation.podspec --allow-warnings
```

推送标签后，使用者可直接写入：

```ruby
pod 'AthenaNotation',
    :git => 'https://github.com/cubehead/AthenaNotation.git',
    :tag => '0.1.0'
```

暂不执行 `pod trunk push`，也不需要在 CocoaPods 公共 Specs 索引中创建条目。
已推送的版本标签应视为不可变；修复时增加版本号并创建新标签。

## 推荐发布顺序

1. 本地 Swift 和 CocoaPods 验证
2. 提交版本号与 Changelog
3. 创建并推送 Git 标签
4. 创建 GitHub Release
5. 用 GitHub 标签地址在空白 App 中验证 CocoaPods 安装
6. 分别验证 SPM 和 CocoaPods 集成

参考：

- [SwiftPM 官方发布说明](https://docs.swift.org/swiftpm/documentation/packagemanagerdocs/releasingpublishingapackage/)
- [SwiftPM Package Registry 发布命令](https://docs.swift.org/swiftpm/documentation/packagemanagerdocs/packageregistrypublish/)
- [CocoaPods Podfile 语法](https://guides.cocoapods.org/syntax/podfile.html)
- [CocoaPods Development Pods](https://guides.cocoapods.org/using/the-podfile.html#using-the-files-from-a-folder-local-to-the-machine)
