# Build & Run

KeiPix 同时支持 SwiftPM 与 XcodeGen 开发路径。SwiftPM 主要服务 macOS 本地可执行程序与测试，XcodeGen 生成 macOS app/test target 以及正式 iPadOS app target；两条路径共享 `Sources/KeiPix` 与 `Tests/KeiPixTests`。`KeiPix.xcodeproj` 由 [`XcodeGen`](https://github.com/yonaskolb/XcodeGen) 从 `project.yml` 生成。

## Requirements

- macOS 26.0 或更新
- Xcode 26.x（`project.yml` 记录 `xcodeVersion: "26.3"`）
- Swift 6.2+ toolchain（`Package.swift` 使用 `// swift-tools-version: 6.2`）
- Homebrew + XcodeGen（仅 Xcode 路径需要）

`project.yml` 的 `SWIFT_VERSION: "6.0"` 是 Swift language mode；实际命令行工具链仍以 Xcode/Swift 6.2+ 为准。

## Build And Run The Local App

```bash
./script/build_and_run.sh
```

脚本会执行：

1. `swift build`
2. 复制可执行文件到 `dist/KeiPix.app/Contents/MacOS/`
3. 内联生成 `Info.plist`，包含 bundle id、`keipix://` URL scheme、`.webloc/.url` 文档绑定和最低系统版本
4. `open -n` 启动独立实例

普通启动前会先 `pkill -x KeiPix`，方便反复本地验证。

## Launch Modes

| Mode | 用途 |
| --- | --- |
| `run`（默认） | 构建并普通启动 |
| `--debug` | 在 `lldb` 中启动 |
| `--logs` | 启动并跟随进程 stdout/stderr 相关 unified log |
| `--telemetry` | 启动并跟随 `subsystem == com.keipix.client` 的本地日志 |
| `--verify` | 以 `--visual-qa-cached-feed` 启动，作为最小可重复活性检查 |
| `--package` | 仅构建 `.app` 并校验 plist，不启动 |
| `--visual-qa-*` | 进入隔离的视觉 QA sample surface |

`.codex/environments/environment.toml` 把 Codex 应用的 Run 按钮绑定到这个脚本。

## SwiftPM

```bash
swift build
swift test
swift run KeiPix
```

常用定向测试：

```bash
swift test --filter NativeBoundaryTests
swift test --filter RuntimeReadinessTests
swift test --filter GallerySelectionTests
```

当前测试目录有 52 个 Swift 测试文件。最近一次完整本地基线为 **302 个测试 / 52 个测试套件**，覆盖模型、解析器、下载、阅读、URL 路由、视觉 QA、Runtime Readiness、iPadOS target metadata 和 native bridge 边界。

## XcodeGen

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

正式 iPadOS target 使用独立 scheme：

```bash
xcodebuild -project KeiPix.xcodeproj -scheme 'KeiPix iPadOS' \
  -configuration Debug \
  -destination 'platform=iOS Simulator,id=<simulator-udid>' \
  -derivedDataPath /tmp/KeiPix-iPadFormalDerived \
  build
```

`KeiPix.xcodeproj` 不需要手改；刷新项目时重新运行 `xcodegen generate`。

## CI

GitHub Actions workflow 位于 `.github/workflows/macos-build.yml`：

- 选择 Xcode 26 toolchain
- `swift package resolve`
- `swift build`
- `swift test --parallel`
- `./script/build_release_app.sh` 生成 `.zip` 或 `.dmg`
- tag `v*` 时把产物附加到 GitHub Release

## Visual QA

启动一个 surface：

```bash
./script/build_and_run.sh --visual-qa-gallery-three-column
```

捕获截图与 manifest：

```bash
./script/capture_visual_qa.sh gallery-three-column
```

输出在 `artifacts/visual-qa/<UTC timestamp>/`。UI、布局、文案、阅读器或画廊热路径改动后，需要刷新对应 surface 的证据。

## App Metadata

| 文件 | 用途 |
| --- | --- |
| `App/Info.plist` | Xcode 构建使用的 plist 模板 |
| `App/Info-iPadOS.plist` | iPadOS target 使用的 plist 模板，包含 `keipix://` / `pixiv://` 路由、后台刷新、照片保存说明和 iPad 方向声明 |
| `App/KeiPix.entitlements` | App Sandbox、网络、用户选择文件、下载、打印 entitlement |
| `script/build_and_run.sh` | SwiftPM 本地 `.app` 构建与运行脚本 |
| `script/build_release_app.sh` | CI/release 打包脚本 |
| `project.yml` | XcodeGen 项目描述 |

修改 entitlement、bundle metadata 或 URL/document type 时，要同步 Xcode 路径和脚本路径。

## iPadOS Target

`project.yml` 声明了正式 `KeiPixiPad` app target 和 `KeiPix iPadOS` scheme，target 平台为 iOS、设备族为 iPad，bundle id 为 `com.keipix.client.ipad`。`Package.swift` 同时声明 `.iOS(.v26)`，多个热路径已经具备 UIKit bridge，例如 `UICollectionView`、`UIScrollView`、`UITextView`、`UISearchTextField`。

推荐验证顺序：

1. `xcodegen generate`
2. 使用 `KeiPix iPadOS` scheme 在 iPad Simulator 上 build/run
3. 检查 feed、downloads、settings 这类基础 surface 的安全区、sidebar/detail、空状态和触控导航
4. 再补多尺寸设备矩阵、视觉 QA、签名和分发检查

文档中可以把 iPadOS 写成正式 target，但不要写成已公开发布完成目标，除非上述设备与分发验证已经补齐。命令行和 XcodeBuildMCP 同时跑构建时，建议给命令行 `xcodebuild` 指定独立 `-derivedDataPath`，避免 DerivedData 数据库锁。

## Troubleshooting

- `swift build` 失败但 Xcode 通过：检查 `Package.swift` 资源声明和 SwiftPM build-tool plugin 输出。
- 启动后闪退：用 `./script/build_and_run.sh --logs` 看 sandbox、resource 或 entitlement 错误。
- 视觉 QA 截图为空：确认目标窗口面积不小于 240x240，并且先用对应 `--visual-qa-*` 启动。
- Token 失效：Settings -> Runtime Readiness -> Account Health Check，或使用 `--verify` 走隔离 sample 模式验证 UI。
- iPadOS 相关编译失败：先确认使用 Xcode 26+ SDK、正确 destination，并确认相关 AppKit-only bridge 有 `#if os(macOS)` 隔离。
