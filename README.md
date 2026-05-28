# KeiPix

Native Swift + SwiftUI Pixiv client for macOS 26+ and iPadOS 26+.

> 所有 UI 使用 SwiftUI 编写，仅在桌面集成层使用窄口的 AppKit 桥接。iPadOS 使用跨平台手势和文件抽象层。

## 功能概览

### 浏览与发现

- **原生画廊**：MasonryLayout、四档密度、连续/单页/双页/索引阅读模式
- **浏览器式导航历史**：Cmd+[ / Cmd+] 后退/前进，100 条历史缓存
- **自适应操作栏**：根据面板宽度自动显示更多按钮（收藏/下载/分享/搜索图源/稍后再看）
- **内联翻译**：Apple Translation 框架，支持双语对照和沉浸式两种模式，翻译目标语言可配置
- **搜索**：高级筛选、自动补全、保存预设、Pixiv Web URL 互通

### 阅读器

- **双页书本模式**：宽屏自动展开左右页，类似实体书阅读体验
- **触控板手势**：滑动翻页、捏合缩放、双击缩放、拖拽平移
- **iPadOS 触控手势**：跨平台手势桥接器，支持滑动/捏合/双击
- **翻译缓存**：按页缓存翻译结果，翻页不丢失
- **翻译模式**：双语对照（原文+译文）和沉浸式（译文替换原文）

### 下载与本地库

- 队列管理 / 模板命名 / 多P范围下载 / 失败退避重试
- 自动收藏联动 / 本地阅读器 / Finder 元数据写入
- iPadOS: Photos 库保存 / Files app 集成

### 平台集成

- **Spotlight**：下载内容可搜索
- **Shortcuts**：AppIntents 支持
- **Handoff**：跨设备接力浏览
- **Touch Bar**：导航/收藏/下载快捷按钮
- **Quick Look**：空格键预览画作
- **WidgetKit**：数据提供器（Artwork of the Day）
- **Share Extension**：接收其他 App 的 Pixiv 链接

### 安全与隐私

- AI / R-18 / R-18G 标记与可选预览遮罩
- 本地静音 + Pixiv mute 同步
- 隐私模式 / 屏幕截图保护

## 平台支持

| 平台 | 最低版本 | 状态 |
| --- | --- | --- |
| macOS | 26.0 | 主平台，完整功能 |
| iPadOS | 26.0 | 基础适配完成（TabView 导航、触控手势、全屏阅读器） |

## 快速开始

```bash
# 构建并运行
./script/build_and_run.sh

# 仅构建
swift build

# 运行测试
swift test

# 视觉 QA 模式
./script/build_and_run.sh --verify
```

## 项目结构

```text
Sources/KeiPix/
├── App/              # 应用入口、AppDelegate、Services
├── Intents/          # AppIntents (Shortcuts)
├── Models/           # 数据模型、路由、阅读模式
├── Resources/        # xcstrings、资源文件
├── Services/         # PixivAPI、ImagePipeline、SpotlightIndexer
├── Stores/           # KeiPixStore (26 个扩展文件)
├── Support/          # 工具类、L10n、平台抽象
└── Views/            # SwiftUI 视图 (90+ 文件)
```

## 架构亮点

- **@Observable**：KeiPixStore 使用 Swift Observation 框架
- **平台抽象**：PlatformTypes、PlatformWorkspace、PlatformFilePicker、PasteboardWriter
- **跨平台手势**：ReaderGestureBridge 统一 macOS 触控板和 iPadOS 触控手势
- **条件编译**：`#if os(macOS)` / `#if os(iOS)` 分离平台特定代码
- **结构化错误**：AppError 枚举（network/auth/parsing/rateLimited）

## 改进计划

详见 [`IMPROVEMENT_PLAN.md`](IMPROVEMENT_PLAN.md) 和 [`IPADOS_PLAN.md`](IPADOS_PLAN.md)。

| 阶段 | 状态 |
| --- | --- |
| P0 (高影响小改动) | 5/5 ✅ |
| P1 (高影响中改动) | 5/5 ✅ |
| P2 (架构重构) | 5/5 ✅ |
| P3 (新功能) | 8/8 ✅ |
| iPadOS 适配 | 20/20 ✅ |

## 运行环境

- macOS 26.0+ / iPadOS 26.0+
- Swift 6.2+（`SWIFT_STRICT_CONCURRENCY: complete`）
- Xcode 26.x
- App Sandbox + Hardened Runtime

## 测试

```bash
# 运行所有测试
swift test

# 测试覆盖
# - 49 个测试文件
# - 模型、解析器、服务、工具类
# - NavigationHistory、SearchOptions、DownloadNamingTemplate 等
```

## 本地化

- 英文 / 简体中文 / 繁体中文 / 日文
- String Catalog (`.xcstrings`) 格式
- 运行时语言切换支持

## License

仓库当前未附带正式 License 文件。在加入正式 License 之前，本项目源码版权归作者所有，仅供阅读与评估，不授予分发或衍生授权。
