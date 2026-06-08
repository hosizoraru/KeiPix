# Build & Run

KeiPix 同时支持 SwiftPM 与 XcodeGen 开发路径。SwiftPM 主要服务 macOS 本地可执行程序与测试，XcodeGen 生成 macOS app/test target 以及正式 iOS / iPadOS app target；两条路径共享 `Sources/KeiPix` 与 `Tests/KeiPixTests`。`KeiPix.xcodeproj` 由 [`XcodeGen`](https://github.com/yonaskolb/XcodeGen) 从 `project.yml` 生成。

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

## Build And Run Simulator Apps

iOS 和 iPadOS 使用 XcodeGen + `xcodebuild` + `simctl` 路线。脚本会在需要时运行 `xcodegen generate`，查找或创建项目专用 Simulator，boot 后 build、install、launch：

```bash
./script/build_and_run_ios.sh
./script/build_and_run_ipados.sh
```

常用验收模式：

```bash
./script/build_and_run_ios.sh --verify
./script/build_and_run_ipados.sh --verify
./script/build_and_run_ios.sh --build-only
./script/build_and_run_ipados.sh --logs
```

默认 Simulator 名称为 `KeiPix-iOS` 和 `KeiPix-iPadOS`。如果你正在和其他工作树并行验收，建议显式指定设备，避免混用登录态或截图证据：

```bash
KEIPIX_IOS_SIMULATOR_ID=<iphone-udid> ./script/build_and_run_ios.sh --verify
KEIPIX_IPADOS_SIMULATOR_ID=<ipad-udid> ./script/build_and_run_ipados.sh --verify
```

可用环境变量：

| 变量 | 用途 |
| --- | --- |
| `KEIPIX_CONFIGURATION` | `Debug` 或 `Release`，默认 `Debug` |
| `KEIPIX_SIMULATOR_ID` | iOS/iPadOS 共用的 Simulator UDID override |
| `KEIPIX_IOS_SIMULATOR_ID` / `KEIPIX_IPADOS_SIMULATOR_ID` | 单平台 Simulator UDID override |
| `KEIPIX_IOS_SIMULATOR_NAME` / `KEIPIX_IPADOS_SIMULATOR_NAME` | 自动查找或创建的 Simulator 名称 |
| `KEIPIX_IOS_DEVICE_TYPE` / `KEIPIX_IPADOS_DEVICE_TYPE` | 自动创建时使用的 `simctl` device type id |
| `KEIPIX_DERIVED_DATA_PATH` | 共用 DerivedData override |
| `KEIPIX_XCODEBUILD_VERBOSE=1` | 显示完整 `xcodebuild` 日志；默认使用 `-quiet` 保持脚本输出简洁 |

## Launch Modes

macOS 本地 `.app` 脚本：

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

Simulator 脚本：

| Mode | 用途 |
| --- | --- |
| `run`（默认） | 生成项目、构建、安装并启动 |
| `--build-only` | 只构建，不启动 Simulator |
| `--install-only` | 安装并启动最近一次构建产物 |
| `--verify` | 构建、安装、启动，并输出一张 Simulator screenshot |
| `--logs` | 启动后跟随 app bundle id 的 unified log |

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

当前测试目录有 52 个 Swift 测试文件。最近一次完整本地基线为 **313 个测试 / 52 个测试套件**，覆盖模型、解析器、下载、阅读、URL 路由、视觉 QA、Runtime Readiness、iOS / iPadOS target metadata 和 native bridge 边界。

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

正式 iOS / iPadOS target 使用独立 scheme：

```bash
xcodebuild -project KeiPix.xcodeproj -scheme 'KeiPix iOS' \
  -configuration Debug \
  -destination 'platform=iOS Simulator,id=<iphone-simulator-udid>' \
  -derivedDataPath /tmp/KeiPix-iOSDerived \
  build

xcodebuild -project KeiPix.xcodeproj -scheme 'KeiPix iPadOS' \
  -configuration Debug \
  -destination 'platform=iOS Simulator,id=<ipad-simulator-udid>' \
  -derivedDataPath /tmp/KeiPix-iPadFormalDerived \
  build
```

`KeiPix.xcodeproj` 不需要手改；刷新项目时重新运行 `xcodegen generate`。

## CI

GitHub Actions workflow 位于 `.github/workflows/macos-build.yml`：

- 选择 Xcode 26 toolchain
- `swift package resolve`
- `./script/check_version_consistency.sh`
- `swift build --jobs <logical-cpu-count>`
- `swift test --parallel --jobs <logical-cpu-count>`
- `./script/build_release_app.sh zip` 生成 macOS zipped `.app` artifact
- `./script/build_unsigned_ipa.sh ios` 生成 iOS unsigned IPA artifact
- `./script/build_unsigned_ipa.sh ipados` 生成 iPadOS unsigned IPA artifact
- macOS 测试、macOS `.app` 打包、iOS IPA 打包和 iPadOS IPA 打包并行执行；各 job 失败都会让 workflow 失败，但 artifact 不再等待测试 job 结束才开始构建
- SwiftPM job 缓存 `.build` / SwiftPM cache，iOS 与 iPadOS 打包 job 缓存各自的 `.tmp/DerivedData-unsigned-ipa-*`；cache key 覆盖 Swift source、资源、XcodeGen spec、plist、entitlements 和版本配置
- mobile packaging 在 CI 中会重新生成 `KeiPix.xcodeproj`；本地脚本也会在项目缺失、`project.yml`/source/plist/privacy 输入更新时重新生成，避免 stale Xcode project 漏掉新增 Swift 文件
- checkout 使用完整 git history 和 tags。非 tag 构建设置 `KEIPIX_BUILD_NUMBER_STRATEGY=git`，优先按最近 `v*` 版本 tag 的提交距离派生 build number，没有版本 tag 时用 commit count 兜底；tag `v*` 构建保持 `CURRENT_PROJECT_VERSION`
- `master` push 且测试和两个 IPA job 都成功后，`publish-livecontainer-nightly` 会生成 `apps_nightly.json`，把 `nightly` tag / release 移到当前提交，并上传订阅源、iOS unsigned IPA、iPadOS unsigned IPA 三个 release assets
- tag `v*` 时把 macOS `.zip` / `.dmg` 产物附加到 GitHub Release

本地可复现同样的打包产物：

```bash
./script/build_release_app.sh zip
./script/build_unsigned_ipa.sh ios
./script/build_unsigned_ipa.sh ipados
```

脚本会自动按本机 logical CPU 数设置 SwiftPM / Xcode 并行 job 数；需要限制或放大时可设置 `KEIPIX_BUILD_JOBS=<n>`，IPA 构建也支持更具体的 `KEIPIX_XCODE_JOBS=<n>` 覆盖。

unsigned IPA 使用 `iphoneos` SDK 的 Release 构建，关闭 Xcode signing，并输出标准 `Payload/KeiPix.app` 结构，适合导入 LiveContainer 这类 live container / sideload 测试环境；它不是 App Store、TestFlight 或普通已签名真机安装包。

本地脚本默认使用 config 构建号；需要模拟 Actions/nightly 的动态构建号时，给同一套脚本加上环境变量即可：

```bash
KEIPIX_BUILD_NUMBER_STRATEGY=git ./script/version_settings.sh --print-json
KEIPIX_BUILD_NUMBER_STRATEGY=git ./script/build_release_app.sh zip
KEIPIX_BUILD_NUMBER_STRATEGY=git ./script/build_unsigned_ipa.sh ios
```

LiveContainer nightly 订阅源使用稳定 release asset URL，而不是 14 天保留的 Actions artifact URL：

```text
https://github.com/hosizoraru/KeiPix/releases/download/nightly/apps_nightly.json
```

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
| `Config/AppVersion.xcconfig` | 版本号和构建号的人类维护入口，详见 [Release Versioning](release-versioning.md) |
| `App/Info.plist` | Xcode 构建使用的 plist 模板 |
| `App/Info-iOS.plist` | iOS target 使用的 plist 模板，包含 `keipix://` / `pixiv://` 路由、后台刷新、照片保存说明和 iPhone 方向声明 |
| `App/Info-iPadOS.plist` | iPadOS target 使用的 plist 模板，包含 `keipix://` / `pixiv://` 路由、后台刷新、照片保存说明和 iPad 方向声明 |
| `App/KeiPix.entitlements` | App Sandbox、网络、用户选择文件、下载、打印 entitlement |
| `script/version_settings.sh` | 本地脚本和 CI 共享的版本读取与校验 helper |
| `script/check_version_consistency.sh` | 发布前版本一致性检查 |
| `script/set_app_version.sh` | 同步设置 `Config/AppVersion.xcconfig` 与 `project.yml` 里的版本字段 |
| `script/build_and_run.sh` | SwiftPM 本地 `.app` 构建与运行脚本 |
| `script/build_and_run_ios.sh` | iOS Simulator 快速构建、安装和启动脚本 |
| `script/build_and_run_ipados.sh` | iPadOS Simulator 快速构建、安装和启动脚本 |
| `script/build_and_run_simulator.sh` | iOS/iPadOS 两个入口共用的 XcodeGen / `xcodebuild` / `simctl` runner |
| `script/build_release_app.sh` | CI/release 打包脚本 |
| `script/build_unsigned_ipa.sh` | CI/本地 iOS 与 iPadOS unsigned IPA 打包脚本 |
| `project.yml` | XcodeGen 项目描述 |

修改 entitlement、bundle metadata 或 URL/document type 时，要同步 Xcode 路径和脚本路径。修改版本号时优先使用 `./script/set_app_version.sh <version> <build>`，然后运行 `./script/check_version_consistency.sh`。

## iOS And iPadOS Targets

`project.yml` 声明了正式 `KeiPixiOS` / `KeiPixiPad` app target 和 `KeiPix iOS` / `KeiPix iPadOS` scheme。两个 target 平台都为 iOS，设备族分别为 iPhone 与 iPad，bundle id 分别为 `com.keipix.client.ios` 和 `com.keipix.client.ipad`。`Package.swift` 同时声明 `.iOS(.v26)`，多个热路径已经具备 UIKit bridge，例如 `UICollectionView`、`UIScrollView`、`UITextView`、`UISearchTextField`。

推荐验证顺序：

1. `xcodegen generate`
2. 使用 `./script/build_and_run_ios.sh --verify` 跑 iPhone smoke check
3. 使用 `./script/build_and_run_ipados.sh --verify` 跑 iPad smoke check
4. 检查 feed、downloads、settings 这类基础 surface 的安全区、sidebar/detail、空状态和触控导航
5. 再补多尺寸设备矩阵、视觉 QA、签名和分发检查

文档中可以把 iOS / iPadOS 写成正式 target，但不要写成已公开发布完成目标，除非上述设备与分发验证已经补齐。命令行和 XcodeBuildMCP 同时跑构建时，建议给命令行 `xcodebuild` 指定独立 `-derivedDataPath`，避免 DerivedData 数据库锁。

## Troubleshooting

- `swift build` 失败但 Xcode 通过：检查 `Package.swift` 资源声明和 SwiftPM build-tool plugin 输出。
- 启动后闪退：用 `./script/build_and_run.sh --logs` 看 sandbox、resource 或 entitlement 错误。
- 视觉 QA 截图为空：确认目标窗口面积不小于 240x240，并且先用对应 `--visual-qa-*` 启动。
- Token 失效：Settings -> Runtime Readiness -> Account Health Check，或使用 `--verify` 走隔离 sample 模式验证 UI。
- iOS / iPadOS 相关编译失败：先确认使用 Xcode 26+ SDK、正确 destination，并确认相关 AppKit-only bridge 有 `#if os(macOS)` 隔离。
- 并行验收混到其他工作树：给脚本传 `KEIPIX_IOS_SIMULATOR_ID` 或 `KEIPIX_IPADOS_SIMULATOR_ID`，并使用独立 `KEIPIX_DERIVED_DATA_PATH`。
