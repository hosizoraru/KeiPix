# KeiPix

[![Build, Test & Package](https://github.com/hosizoraru/KeiPix/actions/workflows/macos-build.yml/badge.svg)](https://github.com/hosizoraru/KeiPix/actions/workflows/macos-build.yml)
![Swift 6.2+](https://img.shields.io/badge/Swift-6.2%2B-orange)
![macOS 26+](https://img.shields.io/badge/macOS-26%2B-blue)
![iOS 26+](https://img.shields.io/badge/iOS-26%2B-blue)
![iPadOS 26+](https://img.shields.io/badge/iPadOS-26%2B-blueviolet)
![AppKit/UIKit first](https://img.shields.io/badge/UI-AppKit%20%2F%20UIKit%20first-6f42c1)

KeiPix 是一个原生 Swift Pixiv 客户端，当前以 macOS 26+ 为主平台，并已具备正式 iOS / iPadOS 26+ XcodeGen target 与 Simulator 验证路线。它不是 Pixiv 官方项目；目标是在 Apple 平台上用更贴近系统控件的方式做好浏览、阅读、下载、本地库和 QA。

项目路线已经从“SwiftUI 优先”调整为 **AppKit/UIKit 优先，SwiftUI 辅助**：

- AppKit/UIKit 承担高频热路径：瀑布流/列表复用、图片滚动缩放、长文本、菜单、拖放、输入、平台手势。
- SwiftUI 继续负责状态绑定、窗口与导航外壳、轻量组合、设置表单、预览和快速迭代。
- `NSViewRepresentable` / `UIViewRepresentable` 是明确桥接边界，业务状态仍由 Swift store 驱动，平台视图专注渲染与交互。

## Highlights

- **原生画廊与 feed**：masonry / compact / list 已接入 `NSCollectionView` / `UICollectionView` 容器，使用 diffable snapshot、原生布局和稳定 selection 更新，降低瀑布流刷新闪烁风险。
- **作品阅读器**：`NSScrollView` / `UIScrollView` 承接单页、双页、连续阅读的缩放、平移、惯性滚动和双击缩放，SwiftUI 只保留 chrome、overlay 和阅读状态。
- **小说与长文本**：纯文本页使用 TextKit 路线，`NSTextView` / `UITextView` 负责选择、复制、链接和长文本排版，嵌图页保留 SwiftUI fallback。
- **下载与本地库**：队列管理、范围下载、失败退避、模板命名、本地阅读、Finder metadata、Spotlight 索引和 Quick Look 预览。
- **搜索与发现**：推荐、排行、关注、收藏、标签、保存搜索、Pixiv Web URL 互通、Pixivision/Spotlight 库。
- **平台集成**：AppIntents / Shortcuts、Handoff、Touch Bar、Share Extension、Pixiv 链接拖放和 `keipix://` 路由。
- **安全与隐私**：AI / R-18 / R-18G 标记、本地静音、Pixiv mute 只读同步、可逆写入门槛、无遥测。
- **Xcode 27 beta 兼容**：移动端脚本继续用 `simctl` 做自动化，并在图形窗口层优先打开 Device Hub；本地 Developer Documentation 可作为 OS 27 / SDK 27 研究数据源。

## Platform Status

| 平台 | 状态 | 说明 |
| --- | --- | --- |
| macOS 26+ | 主平台 | SwiftPM 与 XcodeGen 路线，CI 执行 `swift build --arch arm64`、`swift test --arch arm64 --parallel` 和 `.app` 打包。 |
| iOS 26+ | 正式 target / 验证中 | XcodeGen 声明 `KeiPixiOS` target 与 `KeiPix iOS` scheme，bundle id 为 `com.keipix.client.ios`。提供 iPhone Simulator 快速 build-run 脚本；公开发布前仍需小屏交互、登录链路、视觉 QA、签名和分发检查。 |
| iPadOS 26+ | 正式 target / 验证中 | XcodeGen 声明 `KeiPixiPad` target 与 `KeiPix iPadOS` scheme，bundle id 为 `com.keipix.client.ipad`。基础 Simulator build-run 已通过；公开发布前仍需多尺寸设备、视觉 QA、签名和分发检查。 |

## Quick Start

```bash
# 构建并启动本地 .app
./script/build_and_run.sh

# 构建并启动 Simulator 版本
./script/build_and_run_ios.sh
./script/build_and_run_ipados.sh

# SwiftPM 构建与测试
swift build --arch arm64
swift test --arch arm64

# 最小可重复活性检查
./script/build_and_run.sh --verify
./script/build_and_run_ios.sh --verify
./script/build_and_run_ipados.sh --verify

# 示例视觉 QA surface
./script/build_and_run.sh --visual-qa-gallery-three-column
./script/capture_visual_qa.sh gallery-three-column
```

在 Xcode 27 beta 上，iOS / iPadOS 脚本会打开 Xcode 内置的 Device Hub，而不是依赖旧的独立 Simulator 应用；CI 或无头环境可以设置 `KEIPIX_OPEN_DEVICE_WINDOW=0`。

## Local Packaging

GitHub Actions 会在 PR、`master` push 和 tag 构建中分别上传：

- macOS zipped `.app`：`KeiPix-macOS-<version>-build.<build>-app`
- iOS unsigned IPA：`KeiPix-iOS-<version>-build.<build>-unsigned-ipa`
- iPadOS unsigned IPA：`KeiPix-iPadOS-<version>-build.<build>-unsigned-ipa`

本地也可以用同一套脚本生成可测试产物：

```bash
# macOS Release .app，输出 artifacts/KeiPix-<version>-build.<build>.zip
./script/build_release_app.sh zip

# iPhone 设备包，输出 artifacts/KeiPix-iOS-<version>-build.<build>-unsigned.ipa
./script/build_unsigned_ipa.sh ios

# iPad 设备包，输出 artifacts/KeiPix-iPadOS-<version>-build.<build>-unsigned.ipa
./script/build_unsigned_ipa.sh ipados
```

`build_unsigned_ipa.sh` 使用 `iphoneos` SDK 的 Release 构建，并显式关闭 Xcode signing。生成的 IPA 采用标准 `Payload/KeiPix.app` 结构，适合导入 LiveContainer 这类 live container / sideload 测试环境；它不是 App Store、TestFlight 或普通已签名真机安装包。如果你的测试环境需要开发者证书或重签名，请在容器/签名工具侧完成那一步。

Nightly LiveContainer 订阅源：

```text
https://github.com/hosizoraru/KeiPix/releases/download/nightly/apps_nightly.json
```

`apps_nightly.json` 使用同一套版本元数据：`versionName` 对应当前可达 `v*` tag 的版本号，`buildNumber` / `buildVersion` / `versionCode` 使用 tag code，例如 `v0.27.0 -> 2700`、`v0.27.2 -> 2702`、`v1.2.3 -> 10203`。commit 数和短 hash 只写进 About/诊断与 nightly 描述，不参与版本号或安装升级判断；因此 `v0.27.6+12` 仍然是外部版本 `0.27.6`、构建号 `2706`。需要本地模拟 nightly 时可以运行：

```bash
KEIPIX_BUILD_NUMBER_STRATEGY=git ./script/version_settings.sh --print-json
KEIPIX_BUILD_NUMBER_STRATEGY=git ./script/build_unsigned_ipa.sh ios
```

`Config/AppVersion.xcconfig` 与 `project.yml` 必须和最新版本 tag 保持一致；更新版本请先运行 `./script/set_app_version.sh 0.27.x`，再给同一个提交打 annotated `v0.27.x` tag。`master` 的 Actions 在 iOS 与 iPadOS IPA 都构建成功后，会移动 `nightly` tag，并把 `nightly` release 更新为最新的两个 unsigned IPA 和订阅源；本地需要刷新 seed 文件时可运行：

```bash
./script/generate_livecontainer_apps_nightly.sh apps_nightly.json
```

## Repository Map

```text
Sources/KeiPix/
├── App/              # App entry, AppDelegate, service wiring, dock/menu glue
├── Intents/          # AppIntents and Shortcuts
├── Models/           # Pixiv models, routing, reader state, QA models
├── Resources/        # String catalogs and bundled resources
├── Services/         # PixivAPI, ImagePipeline, session, release, SauceNAO
├── Stores/           # KeiPixStore plus domain extensions
├── Support/          # Native bridges, platform abstractions, helpers
└── Views/            # SwiftUI shell/composition around native hot paths
```

## Architecture

- `KeiPixStore` 使用 Swift Observation，集中持有 session、route、feed、下载、阅读和用户偏好。
- 领域逻辑通过 `Stores/KeiPixStore+*.swift` 拆分，避免把所有行为塞回一个巨型 store。
- 平台热路径放在 `Support/`，例如 `NativeGalleryCollectionView`、`ImageScrollView`、`NativeNovelTextPageView`、`NativeDownloadQueueListView`、`NativeBrowsingHistoryCollectionView`。
- `NativeBoundaryTests` 保护迁移边界：不能引入 Flutter/Dart/Kotlin 参考项目源码，native bridge 需要显式存在，画廊/阅读器/文本/列表等关键 surface 必须继续走原生容器。

## Quality

最新本地基线为 **313 个测试 / 52 个测试套件**，覆盖模型、解析、URL 路由、下载、阅读模式、视觉 QA manifest、Runtime Readiness、平台边界和 native bridge 守卫。

日常验证入口：

```bash
swift test --arch arm64
swift test --arch arm64 --filter NativeBoundaryTests
swift test --arch arm64 --filter RuntimeReadinessTests
./script/build_and_run.sh --verify
./script/build_and_run_ios.sh --verify
./script/build_and_run_ipados.sh --verify
```

UI 改动需要补对应视觉 QA surface。截图和 manifest 输出在 `artifacts/visual-qa/<timestamp>/`，详见 [Quality Assurance](docs/quality-assurance.md)。

## Documentation

| 文档 | 内容 |
| --- | --- |
| [Build & Run](docs/build-and-run.md) | SwiftPM、XcodeGen、脚本、CI 和排错 |
| [Architecture](docs/architecture.md) | 当前 native-first 混合架构与关键模块 |
| [Architecture Decisions](docs/architecture-decisions.md) | 项目重要 ADR |
| [Features](docs/features.md) | 非小说面功能矩阵 |
| [Quality Assurance](docs/quality-assurance.md) | 单元测试、Runtime Readiness、视觉 QA |
| [Safety & Privacy](docs/safety-and-privacy.md) | 凭据、内容安全、远端写入边界 |
| [Localization](docs/localization.md) | String Catalog 与多语言策略 |
| [Release Versioning](docs/release-versioning.md) | 版本号、构建号、CI artifact 与更新检查 |
| [Contributing](docs/contributing.md) | 分支、提交、PR、视觉 QA 要求 |
| [Hybrid UI Plan](HYBRID_UI_PLAN.md) | AppKit/UIKit 优先迁移计划与阶段进度 |

## Contributing

欢迎提 issue 和 PR。请优先说明目标 surface、平台、期望行为、实际行为和验证方式。UI/阅读器/画廊相关改动请附 `swift test` 与视觉 QA 证据；远端写入路径需要说明可见入口、授权方式和回滚/撤销方式。

完整贡献指南见 [CONTRIBUTING.md](CONTRIBUTING.md) 与 [docs/contributing.md](docs/contributing.md)。GitHub issue / PR 模板会复用同一套信息：环境、目标 surface、验证证据和回滚风险。

## License

KeiPix is licensed under the Apache License, Version 2.0. See [LICENSE](LICENSE) for the full license text.
