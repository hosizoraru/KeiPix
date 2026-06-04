# Contributing

欢迎对 KeiPix 提出改动。本页只涵盖与本仓库实际工作流相关的约束，写得短一点便于复盘。

## 工作流

1. 从 `master` 切独立分支
2. 改动控制在一个主题；多主题拆 PR
3. 写代码前先把目标 surface 的视觉 QA 起一遍，避免改完才发现样本数据不全
4. 写完跑 `swift build && swift test`
5. 修到 UI 的一律重抓视觉 QA：`./script/build_and_run.sh --visual-qa-<surface>` → `./script/capture_visual_qa.sh <surface>`
6. 同步刷新 `readme/PROGRESS.md`（带日期表格新增一行）
7. 提 PR 时把 manifest 文件路径列出来

## 提交信息

仓库使用 conventional 风格：

- `feat:` 新功能 / 新 surface
- `fix:` 修复
- `refactor:` 不改外部行为的内部重构
- `test:` 新增 / 调整测试
- `docs:` 文档
- `build:` 构建系统、XcodeGen、脚本
- `chore:` 杂项

主语用动词原形，标题保持 ≤ 70 字符；正文按需要解释"为什么"。

## 分支与 PR

- 分支命名：`feat/<short-name>`、`fix/<short-name>` 等
- PR 标题保持 ≤ 70 字符；正文用 `## Summary` + `## Test plan`
- 不允许直接推 `master`；不允许 `--force` 推 `master`；不允许跳 hooks（`--no-verify`）

## 与参考项目的边界

- `tmp/pixez-flutter`、`tmp/pixes` 仅作为产品 / API 行为的对照，绝不允许把它们的源码结构 / Dart / Kotlin 文件复制到 `Sources/KeiPix`
- 任何"借鉴"都通过重新阅读后用原生 Swift、AppKit/UIKit 热路径和 SwiftUI 组合层重写
- `Tests/KeiPixTests/NativeBoundaryTests.swift` 在 CI 与本地都会拦截：
  - `Sources/KeiPix` 下不能出现 `.dart` / `.kt` / `.kts` / Flutter 引用
  - SwiftUI 视图文件只能作为组合外壳，不把高频滚动、缩放、长文本和平台输入重新堆回声明式层
  - `Package.swift` 必须存在并声明 macOS 26
- 任何参考迁移之前先补对应的源边界测试或扩展现有用例

## 代码风格

- Swift 6 严格并发：写新代码前先想清楚 actor / `@MainActor` / `Sendable`
- 视图文件保持 ≤ 1000 行；超过时按子视图拆开（参考 `GalleryFeedHeaderView`、`UserPreviewListComponents`）
- Store 按领域用 extension 文件分；主 `KeiPixStore.swift` 控制在 1000 行以内
- 不要把多个无关 helper 放进同一个 `Support/*.swift`；按用途单独命名
- 按钮优先使用 `.labelStyle(.iconOnly)` + `.help()` + `.accessibilityLabel()`
- 状态消息使用 `.statusMessageAutoDismiss()` 修饰符
- 跨平台代码使用 `#if os(macOS)` / `#if os(iOS)` 条件编译
- AppKit/UIKit 包装器放在 `Support/` 目录，使用 `NSViewRepresentable` / `UIViewRepresentable`，接口保持小而明确
- 画廊、阅读器、长文本、下载队列、历史列表、创作者列表、搜索、菜单、拖放等热路径优先复用现有 native bridge，不新增平行 SwiftUI 实现

## 可变更动作

- 任何会写到 Pixiv 的代码路径默认 disabled
- Settings → Mutable Action QA 是唯一允许跑批量 / 远端写入演练的入口
- PR 中如新增写入路径，要在描述里说明：可见入口、可逆动作、是否需要授权 sheet

## 文档

- README.md 保持精炼（项目定位 + 快速开始 + 文档索引）
- 详细行为分到 `docs/`：
  - 架构 → `docs/architecture.md`
  - 构建 → `docs/build-and-run.md`
  - 功能矩阵 → `docs/features.md`
  - QA → `docs/quality-assurance.md`
  - 安全 / 隐私 → `docs/safety-and-privacy.md`
  - 本地化 → `docs/localization.md`
  - 版本 / 发版 → `docs/release-versioning.md`
  - 贡献 → `docs/contributing.md`（本文件）
- 进度快照 / 缺口审计放 `readme/`，文件名带日期
- 任何新增 surface 都要把 launch mode 列入 [`docs/quality-assurance.md`](quality-assurance.md)

## 检查清单

合 PR 前自检一遍：

- [ ] `swift build` 通过
- [ ] `swift test` 通过（关键模块再 `swift test --filter` 跑一次）
- [ ] 改动到 UI → 视觉 QA 重抓并把 manifest 路径写在 PR
- [ ] 改动到字符串 → 中英文 strings 同步
- [ ] 改动到写入路径 → 可见入口与可逆性已交代
- [ ] `readme/PROGRESS.md` 与 `readme/NON_NOVEL_GAP_AUDIT_*.md` 同步更新（如适用）
