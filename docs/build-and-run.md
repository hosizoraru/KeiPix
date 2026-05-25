# Build & Run

KeiPix 同时支持 SwiftPM 与 Xcode 两条路。两条路共享 `Sources/KeiPix` 与 `Tests/KeiPixTests`，`KeiPix.xcodeproj` 由 [`XcodeGen`](https://github.com/yonaskolb/XcodeGen) 从 `project.yml` 生成，并在 `.gitignore` 中。

## 系统要求

- macOS 26.0 或更新
- Xcode 26.x（`project.yml` 锁定 `xcodeVersion: "26.3"`）
- Swift 6.0
- Homebrew 用于安装 XcodeGen（仅 Xcode 路径需要）

## 一键构建并运行

```bash
./script/build_and_run.sh
```

脚本会执行以下流程：

1. `swift build` 编译 SwiftPM 产物
2. 复制可执行文件到 `dist/KeiPix.app/Contents/MacOS/`
3. 内联生成 `Info.plist`（含 bundle id、`keipix://` URL scheme、`.webloc/.url` 文档绑定、最低系统版本）
4. `open -n` 启动一份独立实例

`pkill -x KeiPix` 会先关掉已有实例，所以可以反复运行。

## 启动模式

| Mode | 用途 |
| --- | --- |
| `run`（默认） | 普通启动 |
| `--debug` | 在 lldb 中启动 |
| `--logs` | 启动并 `log stream` 跟随 stdout/stderr |
| `--telemetry` | 启动并跟随 `subsystem == com.keipix.client` 的日志 |
| `--verify` | 以 `--visual-qa-cached-feed` 启动，作为最小可重复活性检查 |
| `--package` | 仅 `plutil -lint` 校验并打印 bundle 路径，不启动 |
| `--visual-qa-*` | 23 个独立 visual QA surface（详见 [`quality-assurance.md`](quality-assurance.md)） |

`.codex/environments/environment.toml` 把 Codex 应用的 Run 按钮直接绑到这个脚本。

## 直接走 SwiftPM

```bash
swift build
swift test
swift run KeiPix
```

测试目录 `Tests/KeiPixTests` 覆盖：模型、保存搜索、复制模板、可视化 QA 证据模型、批量收藏、ugoira、`PixivisionArticleLinkAuditor`、`RuntimeReadinessTests`、`NativeBoundaryTests` 等共 20 个测试文件。

```bash
swift test --filter RuntimeReadinessTests
swift test --filter NativeBoundaryTests
```

> 实测 `swift test` 基线在 50–72 个用例之间浮动，取决于近期是否新增 visual QA / 模型覆盖。

## Xcode 路径（XcodeGen）

```bash
brew install xcodegen          # 一次性安装
xcodegen generate              # 由 project.yml 生成 KeiPix.xcodeproj
open KeiPix.xcodeproj
```

命令行构建与测试：

```bash
xcodebuild -project KeiPix.xcodeproj -scheme KeiPix -configuration Debug \
  -destination 'platform=macOS' build

xcodebuild -project KeiPix.xcodeproj -scheme KeiPix -configuration Debug \
  -destination 'platform=macOS' test
```

`KeiPix.xcodeproj` 不入库；想刷新只需重新 `xcodegen generate`。

## 应用元数据

| 文件 | 用途 |
| --- | --- |
| `App/Info.plist` | Xcode 构建使用的 plist 模板 |
| `App/KeiPix.entitlements` | App Sandbox + 网络 / 用户选择文件 / 下载文件 / 打印 entitlement |
| `script/build_and_run.sh` | SwiftPM 构建路径下生成的 `Info.plist`（与 Xcode 版本同步） |
| `project.yml` | XcodeGen 项目描述（macOS 26、Swift 6、严格并发、Sandbox、Hardened Runtime） |

修改 entitlement 或 Info.plist 时记得两处都同步。

## 常用排错

- `swift build` 失败但 Xcode 通过 → 检查 `Package.swift` 的资源声明（`Resources` 目录走 `.process`）
- 启动后立刻闪退 → 用 `--logs` 跑一次，看是否触发 entitlement 限制（沙盒读写权限）
- 视觉 QA 截图为空 → 见 [`quality-assurance.md`](quality-assurance.md) 的 Window ID 说明（窗口需要 ≥ 240×240 才会被采集）
- Token 失效 → Settings → Runtime Readiness → Account Health Check，会显式跑一次刷新；或在 `--verify` 模式下用本地 sample 模式重新验证 UI

## 添加 iPadOS 目标

`project.yml` 已经为未来扩展预留位置：声明第二个 `target`，`platform: iOS`，源码继续指向 `Sources/KeiPix`，再 `xcodegen generate` 即可。本仓库目前不打开 iPadOS 流程，因为 macOS 触控板 / 窗口路径与 iOS 触控差距明显，开启前需要单独评估视图层。
