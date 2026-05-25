# KeiPix

KeiPix 是一款面向 macOS 26+ 的原生 Swift + SwiftUI Pixiv 客户端。所有 UI 使用 SwiftUI 编写，仅在桌面集成层（窗口、触控板、安全沙盒、Pixivision 文章 WebView）使用窄口的 AppKit / WebKit 桥接。

> Native Swift + SwiftUI Pixiv client for macOS 26 and newer Apple platforms. Reference Flutter projects under `tmp/` are behavior references only — no GPL / Flutter / Dart source is reused inside `Sources/KeiPix`.

## 项目状态

非小说功能面（插画、漫画、发现、账户、下载、阅读器、安全过滤、本地缓存）整体完成度约 **96–99%**，每条线都有可重复的视觉 QA 证据与读模式诊断。小说相关流程（推荐 / 搜索 / 排行榜 / 阅读器 / 评论）按当前策略**继续延后**，待非小说面稳定再启动。最新带日期的快照见 [`readme/PROGRESS.md`](readme/PROGRESS.md) 与 [`readme/NON_NOVEL_GAP_AUDIT_2026-05-25.md`](readme/NON_NOVEL_GAP_AUDIT_2026-05-25.md)。

## 主要特性

- **原生体验**：`NavigationSplitView` 侧边栏 + 自适应 masonry 画廊 + 详情 inspector，AppKit 仅做触控板、窗口、剪贴板、URL 拖放等窄桥接
- **登录与账户**：Pixiv OAuth PKCE（嵌入式 `WKWebView`）、Keychain 持久化、token 自动刷新、refresh-token 一键导入（Pixez 迁移）、多账号切换、访客 / 测试模式
- **完整的非小说浏览**：推荐 / 排行榜 / 关注 / 收藏 / 标签搜索 / Pixivision，原生发现仪表盘聚合所有侧边栏入口
- **画廊与阅读器**：自定义 `MasonryLayout`、四档密度、连续 / 单页 / 索引模式、触控板手势、跳页面板、独立阅读器窗口、专注全屏、按作品续读
- **下载与本地库**：队列 / 模板命名 / 多 P 范围下载 / 失败退避重试 / 自动收藏联动 / 本地阅读器 / Finder 联动
- **Ugoira**：解码、变速播放、ZIP / GIF / 单帧 PNG 导出、本地预览
- **搜索**：高级筛选（match/sort/age/date/bookmark/AI/work-type/ugoira）、自动补全、保存预设 / 历史 JSON 导入导出、非 Premium 限量热门预览、Pixiv Web URL 互通
- **安全过滤**：AI / R-18 / R-18G 标记与可选预览遮罩、本地静音 + Pixiv mute 同步只读诊断、反馈 / 举报原生 sheet
- **离线与缓存**：URLCache 图片缓存、按路由 / 筛选键缓存的最近成功作品流，断网失败时只读还原并提示
- **可重复的视觉 QA**：23 个 launch mode 直达独立窗口截图，证据落在 `artifacts/visual-qa/<UTC 时间戳>/`
- **本地化**：英文与简体中文 strings 全覆盖，Settings 搜索按本地化语言索引
- **Runtime Readiness 矩阵**：P0/P1/P2 行 + 可复制诊断文本，最新一次签入运行选定 2P 作品 `#142077008`，记录 P0 4/4、P1 8/8、P2 8/8

## 快速开始

```bash
./script/build_and_run.sh
```

常用模式：

```bash
./script/build_and_run.sh --verify     # 启动 cached-feed 视觉 QA 模式（默认 --verify 入口）
./script/build_and_run.sh --logs       # 跟随 stdout/stderr
./script/build_and_run.sh --debug      # lldb 启动
./script/build_and_run.sh --package    # 仅打包不启动
```

更细的视觉 QA launch mode 列表请看 [`docs/quality-assurance.md`](docs/quality-assurance.md)。

Codex 应用的 Run 动作通过 `.codex/environments/environment.toml` 走同一个脚本。

## 文档索引

精简后的细分文档全部放在 [`docs/`](docs/) 下：

| 文档 | 内容 |
| --- | --- |
| [`docs/architecture.md`](docs/architecture.md) | 模块划分、源码目录、与 Pixez/Pixes 的边界 |
| [`docs/build-and-run.md`](docs/build-and-run.md) | SwiftPM / XcodeGen 双轨构建、签名、沙盒、`.codex` 集成 |
| [`docs/features.md`](docs/features.md) | 按流程展开的非小说功能矩阵 |
| [`docs/quality-assurance.md`](docs/quality-assurance.md) | Runtime Readiness 矩阵、视觉 QA 流程、可变更动作授权 |
| [`docs/safety-and-privacy.md`](docs/safety-and-privacy.md) | AI / R-18 / mute / 反馈 / 远端写入授权策略 |
| [`docs/localization.md`](docs/localization.md) | 多语言策略与扩展指引 |
| [`docs/contributing.md`](docs/contributing.md) | 提交规范、参考项目使用边界、源边界测试 |

历史快照：[`readme/PROGRESS.md`](readme/PROGRESS.md) ｜ [`readme/NON_NOVEL_GAP_AUDIT_2026-05-25.md`](readme/NON_NOVEL_GAP_AUDIT_2026-05-25.md)

## 参考项目

下列两个 Flutter 客户端被 clone 到 `tmp/` 仅作为产品和后端架构的参考（OAuth PKCE、Pixiv App API headers、token refresh、image `Referer`、侧边栏分区、画廊浏览、详情动作）：

- `tmp/pixez-flutter`
- `tmp/pixes`

`Sources/KeiPix` 是全新的原生 SwiftUI 实现。`Tests/KeiPixTests/NativeBoundaryTests.swift` 强制源码边界：检测 `Package.swift`、SwiftUI-first 视图，并阻止 Flutter / Dart / Kotlin 实现路径混入主源码。

## 运行环境

- macOS 26.0 或更新（`Package.swift` 与 `project.yml` 同步声明）
- Swift 6.0（`SWIFT_STRICT_CONCURRENCY: complete`）
- Xcode 26.x，启用 App Sandbox + Hardened Runtime
- 网络：Pixiv App API（`X-Client-Time` / `X-Client-Hash` / Bearer / 表单 POST），图片走带 `Referer` 的原生 loader

## License

仓库当前未附带正式 License 文件。在加入正式 License 之前，本项目源码版权归作者所有，仅供阅读与评估，不授予分发或衍生授权。任何对参考项目（Pixez / Pixes，GPL）的代码引用都被 `NativeBoundaryTests` 拦截。
