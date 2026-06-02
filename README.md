# KeiPix

[![Build & Test](https://github.com/hosizoraru/KeiPix/actions/workflows/macos-build.yml/badge.svg)](https://github.com/hosizoraru/KeiPix/actions/workflows/macos-build.yml)
![Swift 6.2+](https://img.shields.io/badge/Swift-6.2%2B-orange)
![macOS 26+](https://img.shields.io/badge/macOS-26%2B-blue)
![AppKit/UIKit first](https://img.shields.io/badge/UI-AppKit%20%2F%20UIKit%20first-6f42c1)

KeiPix 是一个原生 Swift Pixiv 客户端，当前以 macOS 26+ 为主平台，并保留同源码 iPadOS 26+ 适配路线。它不是 Pixiv 官方项目；目标是在 Apple 平台上用更贴近系统控件的方式做好浏览、阅读、下载、本地库和 QA。

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

## Platform Status

| 平台 | 状态 | 说明 |
| --- | --- | --- |
| macOS 26+ | 主平台 | SwiftPM 与 XcodeGen 路线，CI 执行 `swift build`、`swift test --parallel` 和 `.app` 打包。 |
| iPadOS 26+ | 同源码适配路线 | `Package.swift` 声明 iOS 26，热路径包含 UIKit bridge。当前 XcodeGen 项目仍只生成 macOS target，iPadOS 发布前需要独立 target、设备和视觉 QA 验收。 |

## Quick Start

```bash
# 构建并启动本地 .app
./script/build_and_run.sh

# SwiftPM 构建与测试
swift build
swift test

# 最小可重复活性检查
./script/build_and_run.sh --verify

# 示例视觉 QA surface
./script/build_and_run.sh --visual-qa-gallery-three-column
./script/capture_visual_qa.sh gallery-three-column
```

## Repository Map

```text
Sources/KeiPix/
├── App/              # App entry, AppDelegate, service wiring, dock/menu glue
├── Intents/          # AppIntents and Shortcuts
├── Models/           # Pixiv models, routing, reader state, QA models
├── Resources/        # Localizable.xcstrings and bundled resources
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

最新本地基线为 **289 个测试 / 51 个测试套件**，覆盖模型、解析、URL 路由、下载、阅读模式、视觉 QA manifest、Runtime Readiness、平台边界和 native bridge 守卫。

日常验证入口：

```bash
swift test
swift test --filter NativeBoundaryTests
swift test --filter RuntimeReadinessTests
./script/build_and_run.sh --verify
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
| [Contributing](docs/contributing.md) | 分支、提交、PR、视觉 QA 要求 |
| [Hybrid UI Plan](HYBRID_UI_PLAN.md) | AppKit/UIKit 优先迁移计划与阶段进度 |

## Contributing

欢迎提 issue 和 PR。请优先说明目标 surface、平台、期望行为、实际行为和验证方式。UI/阅读器/画廊相关改动请附 `swift test` 与视觉 QA 证据；远端写入路径需要说明可见入口、授权方式和回滚/撤销方式。

完整贡献指南见 [CONTRIBUTING.md](CONTRIBUTING.md) 与 [docs/contributing.md](docs/contributing.md)。GitHub issue / PR 模板会复用同一套信息：环境、目标 surface、验证证据和回滚风险。

## License

仓库当前未附带正式 License 文件。在加入正式 License 之前，本项目源码版权归作者所有，仅供阅读与评估，不授予分发、再授权或衍生授权。
