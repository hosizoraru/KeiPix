# Quality Assurance

KeiPix 通过三层证据支撑发布信心：单元测试（SwiftPM）、Runtime Readiness 矩阵（应用内）、视觉 QA（独立 launch mode + 真实窗口截图 + manifest）。本页梳理日常工作流。

## 单元测试

```bash
swift test
swift test --filter <TestSuiteName>
```

当前测试目录 `Tests/KeiPixTests` 共 51 个 Swift 文件；最近一次完整本地基线为 **289 个测试 / 51 个测试套件**。主要覆盖：

- `NativeBoundaryTests` — 强制 AppKit/UIKit 优先、SwiftUI 辅助的 native bridge 边界，禁止 Flutter / Dart / Kotlin / Gradle 参考项目源码进入主源码
- `RuntimeReadinessTests` — 矩阵模型、持久化、读模式诊断
- `VisualQAEvidenceTests` — 视觉 QA manifest 模型
- `BatchBookmarkTests`、`GallerySelectionTests` — 选区与批量动作
- `CommentEmojiTests` — Pixiv 评论 emoji token 解析
- `CopyTemplateTests` — 用户自定义复制模板渲染
- `CreatorCollectionTests` — 本地置顶作者集合
- `DiscoveryDashboardTests` — 默认发现路由覆盖
- `DownloadModelsTests`、`UgoiraModelsTests`、`SearchOptionsTests` — 各 API 模型
- `FeedSnapshotTests` — 离线缓存 / 还原
- `FeedbackReportTests` — 举报 / 反馈摘要
- `MangaWatchlistProgressTests`、`ArtworkSeriesPresentationTests`、`ArtworkReadingModeTests` — 漫画与阅读相关
- `PixivIDOpenTests`、`PixivisionArticleLinkAuditTests` — URL 路由覆盖与活检
- `ArtworkDetailStateTests`、`ReaderPagePresentationTests`、`ReaderWindowRegistryTests` — 详情、阅读模式和阅读窗口状态
- `PlatformAbstractionTests`、`KeiPixBackupArchiveTests`、`ReleaseUpdateCheckerTests`、`KeyboardShortcutCatalogTests` — 平台抽象、备份、更新和快捷键模型

## Runtime Readiness 矩阵

应用内 Settings → Runtime Readiness 是非小说 QA 的指挥中心：

- 按 P0 / P1 / P2 三档分组：核心路线、签入路线、覆盖广度
- 一键运行 Read-only QA 与 Mutable QA（Mutable QA 需要显式键入 `TEST ACCOUNT` 授权）
- 结果可复制为纯文本、自动持久化到 `UserDefaults`，重开 Settings / 重启 App 都不会丢
- 直接读取 `artifacts/visual-qa/` 下最新 manifest，无 manifest 的 surface 会显示 missing 状态

最近一次签入运行：选定 2P 作品 `#142077008`，`2026年5月25日 21:52:44` 复制诊断为 P0 4/4、P1 8/8、P2 8/8，详见 [`readme/PROGRESS.md`](../readme/PROGRESS.md)。

## 视觉 QA

每个 surface 都通过专门的 launch mode 切换到隔离的 Visual QA Sample 会话（不会读真实账户存储），再用 `screencapture` 抓窗口出图。

启动 surface：

```bash
./script/build_and_run.sh --visual-qa-runtime-readiness
./script/build_and_run.sh --visual-qa-gallery-three-column
# ... 任一 launch mode
```

捕获截图与 manifest：

```bash
./script/capture_visual_qa.sh runtime-readiness
./script/capture_visual_qa.sh gallery-three-column
```

输出落到 `artifacts/visual-qa/<UTC 时间戳>/<surface>.png` 与 `<surface>.md`。manifest 里记录抓取时间、surface 名、应用版本、备注。

### 已落地的 launch mode

当前 `VisualQALaunchArgument` 定义一组隔离 launch flags：

| Surface | 旗标 |
| --- | --- |
| Cached feed restoration / minimal verify | `--visual-qa-cached-feed`（`--verify` 也会进入该 surface） |
| Gallery — auto / 2 列 / 3 列 / 紧凑 | `--visual-qa-gallery-auto` / `--visual-qa-gallery-two-column` / `--visual-qa-gallery-three-column` / `--visual-qa-gallery-compact` |
| Search workspace | `--visual-qa-search-workspace` |
| Ranking | `--visual-qa-ranking` |
| Manga watchlist | `--visual-qa-manga-watchlist` |
| Series sheet | `--visual-qa-series-sheet` |
| Artwork detail social | `--visual-qa-artwork-detail-social` |
| Artwork bookmark editor | `--visual-qa-bookmark-editor` |
| Novel bookmark editor | `--visual-qa-novel-bookmark-editor` |
| Creator profile | `--visual-qa-creator-profile` |
| Feedback sheet | `--visual-qa-feedback-sheet` |
| Muted content library | `--visual-qa-muted-content` |
| Ugoira player | `--visual-qa-ugoira-player` |
| Downloaded reader | `--visual-qa-downloaded-reader` |
| Settings window | `--visual-qa-settings-window` |
| Runtime Readiness | `--visual-qa-runtime-readiness` |
| Sharing templates | `--visual-qa-sharing-templates` |
| Pixiv link drop | `--visual-qa-pixiv-link-drop` |
| Pixiv ID open | `--visual-qa-pixiv-id-open` |

`batch-bookmark-preview` 目前作为 capture helper surface 记录在历史证据里，但不是 `VisualQALaunchArgument` 的独立命令行旗标。

### 截图脚本说明

`script/capture_visual_qa.sh`：

- 内联 Swift 调用 `CGWindowListCopyWindowInfo`，找到 owner == `KeiPix`、面积 ≥ 240×240、layer 0 的最前窗口
- 找不到窗口直接报错退出（提醒先用 `build_and_run.sh --visual-qa-*` 启动）
- 调 `screencapture` 抓单窗口，文件名 `${surface}.png`
- 同步写入 `${surface}.md` manifest，记录采集时间、应用、surface 名

### 添加新的 surface

1. 在 `VisualQALaunchArgument` 加入新枚举值与 CLI 旗标
2. 在 `VisualQASampleData` 中准备本地化样本（避免触碰真实账号）
3. `script/build_and_run.sh` 的 `case` 与 usage 字符串各加一条
4. 在 Runtime Readiness `KeiPixStore+NonNovelQA.swift` 把 surface 接入对应行
5. 跑 `./script/capture_visual_qa.sh <surface>` 落证据
6. 更新 `readme/PROGRESS.md`、`readme/NON_NOVEL_GAP_AUDIT_*.md`

## 可变更动作授权

任何会写入 Pixiv 的 QA 动作都默认禁用：

- Settings → Mutable Action QA 中要求显式键入 `TEST ACCOUNT` 才能解锁
- 解锁后才会出现：私密收藏添加 / 移除、私密关注 / 取消、Pixiv mute 上传等
- 任何动作完成后立即给出可逆的反向动作
- 评论删除目前**不**通过这条路径：Pixiv 当前无可逆删除端点，相关 QA 仍走人工显式审批

## 签入运行验证

`--verify` 模式启动的是 Visual QA Sample，不会触碰用户的真实 token 文件。CI / 本地最小活性检查：

```bash
./script/build_and_run.sh --verify
```

成功条件：进程存在、窗口面积充足、cached-feed surface 渲染完成（脚本中已 `sleep 1` 后 `pgrep -x KeiPix` 校验）。

## 何时刷新证据

在以下情境**必须**重抓相关 surface 的视觉 QA：

- 任一画廊 / 阅读器 / 设置 / Runtime Readiness 的视图布局有变更
- 视图新增 / 删除 / 重命名，或 native bridge 的尺寸/滚动/selection 行为有变更
- Localizable.xcstrings 中相关文案改动
- API 路径或解析逻辑改动到 surface 上的可见字段
- 新增 surface（按上面流程登记 manifest）
