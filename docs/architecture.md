# Architecture

KeiPix 整体是一款 SwiftPM 单 target 的 macOS 应用，UI 全部基于 SwiftUI，状态聚合在一个 `@MainActor` 的 `KeiPixStore` 上，并通过若干扩展文件按领域切分。AppKit / WebKit 仅以最窄边界出现：触控板事件桥接、窗口截图保护、Pixivision 文章 WebView、URL 拖放接收。

## 源码目录

```
Sources/KeiPix/
├── App/             # SwiftUI App 入口、AppDelegate、URL scheme 路由
├── Models/          # Pixiv API 模型、本地 UI 模型、QA / 可视化 QA 模型
├── Services/        # PixivAPI、PixivSessionStore、ImagePipeline、Ugoira 解码与导出、SauceNAO
├── Stores/          # KeiPixStore 主体 + 按领域切分的 extension
│   ├── KeiPixStore.swift                       # 主状态、feed/route 调度
│   ├── KeiPixStore+Accounts.swift              # 登录 / 切号 / token 健康检查
│   ├── KeiPixStore+ArtworkActions.swift        # 收藏 / 关注 / 分享
│   ├── KeiPixStore+ArtworkDetailState.swift    # 详情面板折叠状态持久化
│   ├── KeiPixStore+CopyTemplates.swift         # 用户自定义复制模板
│   ├── KeiPixStore+CreatorCollections.swift    # 本地置顶作者集合
│   ├── KeiPixStore+DangerActions.swift         # 危险动作授权（mute 上传等）
│   ├── KeiPixStore+FeedSnapshots.swift         # 离线缓存快照
│   ├── KeiPixStore+History.swift               # 浏览 / 搜索 / 反向图历史
│   ├── KeiPixStore+ImageSourceSearch.swift     # SauceNAO 反查
│   ├── KeiPixStore+MutedContent.swift          # 屏蔽逻辑 + Pixiv 同步
│   ├── KeiPixStore+MutedContentFiles.swift     # 导入导出
│   ├── KeiPixStore+NonNovelQA.swift            # 非小说 QA 矩阵执行
│   ├── KeiPixStore+Preferences.swift           # 用户偏好
│   ├── KeiPixStore+SavedSearches.swift         # 搜索保存与导入导出
│   ├── KeiPixStore+Social.swift                # 评论 / 系列 / 列表 API 封装
│   ├── KeiPixStore+SpotlightLibrary.swift      # Pixivision 收藏与历史
│   ├── ArtworkDownloadStore.swift              # 下载队列状态机
│   └── ArtworkDownloadStore+Queue.swift        # 队列动作
├── Support/         # 跨视图复用工具：Masonry / Glass / Trackpad / 链接解析 / L10n / 视觉 QA 启动参数等
├── Views/           # 所有 SwiftUI 视图（按 surface 拆分单文件）
└── Resources/       # en.lproj、zh-Hans.lproj 的 Localizable.strings
```

## 关键模块

### `KeiPixStore`

- `@MainActor` `final class`，作为 SwiftUI 环境对象注入
- 持有当前 session（Pixiv App API token / 账户元数据 / 模式）、当前路由、各 feed 状态、UI 偏好
- 通过领域 extension 文件切分以维持单文件可读性，主文件目前约 939 行
- 异步动作统一通过 `Task` 调度，`@Published` 属性驱动 SwiftUI 重渲染

### `PixivAPI`

- 实现 Pixiv App API 的 `X-Client-Time` / `X-Client-Hash` 头与 Bearer 鉴权
- 401 自动 refresh 一次后重试；表单 POST、JSON 反序列化、可重入诊断接口
- 路由族覆盖：推荐 / 排行榜 / 关注 / 收藏 / 评论 / 标签 / 系列 / 用户 / 搜索 / mute / popular-preview

### `PixivSessionStore`

- 文件型 token store：把 access / refresh token 写到沙盒容器内 `~/Library/Containers/com.keipix.client/Data/Library/Application Support/KeiPix/pixiv-sessions.json`
- 不依赖 macOS Login Keychain：避开 ad-hoc 开发签名每次构建都变化导致的 ACL 重新授权弹窗
- 仍然支持多账户：按 user id 分键，`select` / `delete` / `deleteCurrent` 都不污染其他账户
- 兼容旧版单账户 `pixiv-session.json` 文件，首次启动时自动迁移到多账户库

### `ImagePipeline`

- 图片加载器：URLCache 磁盘缓存 + 内存缓存
- 默认带 Pixiv `Referer` 头；R-18/R-18G 预览遮罩在 `RemoteImageView` 中根据偏好叠加
- 同时供下载库的本地预览复用

### `MasonryLayout` & `ArtworkMasonryPresentation`

- 自定义 SwiftUI `Layout` 实现真正的瀑布流
- 按 `aspectRatio` 决定列跨度：常规 / 宽 / 全景 / 超宽各档阈值经过真实账号样本调整
- `gallery-three-column` 等四档独立的视觉 QA 样本覆盖宽幅、高幅、敏感、AI、ugoira、多 P

### `PixivWebLinkResolver` & `PixivURLRoutingCoverage`

- 把 Pixiv / Pixivision / `keipix://` / `pixiv://` / 文档 URL / 拖入文本 / 剪贴板片段统一转成 App 内路由
- `Runtime Readiness` 用 `PixivURLRoutingCoverage` 跑预设样本，外加从 Pixivision 文章 HTML 抽取真实链接做活检

### Visual QA 启动参数

- `VisualQALaunchArgument` 解析 23 个独立 surface 的命令行旗标
- `VisualQASampleData` 注入本地化样本数据，避免触碰真实账户存储
- 当任一 visual-qa 旗标存在时，`KeiPixStore` 会切换到隔离的 "Visual QA" 模式

## 与 Pixez / Pixes 的边界

- 仅作为产品 / 后端架构参考：OAuth PKCE 流程、Pixiv App API headers、token refresh 时机、图片 `Referer`、侧边栏分区、画廊浏览、详情动作
- `Sources/KeiPix` 内不允许出现 Flutter / Dart / Kotlin 实现文件
- `Tests/KeiPixTests/NativeBoundaryTests.swift` 强制：
  - `Package.swift` 存在并声明 macOS 26
  - 视图文件以 SwiftUI 为主
  - `Sources/KeiPix` 下不存在 `.dart` / `.kt` / `.kts` / Flutter 引用

## 并发与状态

- `SWIFT_STRICT_CONCURRENCY: complete`（Swift 6 严格并发）
- 主线程隔离用 `@MainActor`；Task 边界都标注隔离状态
- I/O（网络、磁盘、token 文件）走 actor 或后台 task，UI 更新统一切回 `@MainActor`

## 本地数据层

- `UserDefaults` 持久化：UI 偏好、QA 矩阵快照、已置顶作者、搜索预设、复制模板、详情折叠状态、阅读进度、下载完成记录索引
- 文件系统：图片 URLCache、下载库（沙盒 Downloads 区域）、Ugoira ZIP 缓存、可视化 QA 输出
- 沙盒应用容器：Pixiv access / refresh token（`pixiv-sessions.json`）、账户元数据，写入时使用 `.completeFileProtectionUnlessOpen`
