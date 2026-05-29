# KeiPix Hybrid SwiftUI + AppKit/UIKit Plan

> Generated 2026-05-29. Analysis of SwiftUI limitations and AppKit/UIKit integration opportunities.
> Reference: Apple Developer Documentation, community best practices (SwiftUI+AppKit/UIKit hybrid).

---

## 为什么要混合开发？

SwiftUI 是声明式 UI 框架，但存在以下已知限制：

| 限制 | SwiftUI 现状 | AppKit/UIKit 解决方案 |
|------|-------------|---------------------|
| 文本渲染 | `Text` 不支持富文本、行内图片、自定义布局 | `NSTextView` / `UITextView` + `NSAttributedString` |
| 手势系统 | 基础手势，无触控板/鼠标精细控制 | `NSGestureRecognizer` / `UIGestureRecognizer` 完整手势栈 |
| 图片查看 | 无原生缩放/平移/旋转 | `NSScrollView` / `UIScrollView` + `NSMagnificationGestureRecognizer` |
| 滚动性能 | `LazyVStack` 有 cell 复用限制 | `NSCollectionView` / `UICollectionView` 完整虚拟化 |
| 菜单/工具栏 | 声明式 API 有限 | `NSMenu` / `NSToolbar` 完整控制 |
| 文本输入 | `TextField` / `TextEditor` 功能有限 | `NSTextField` / `UITextField` 完整输入法支持 |
| 窗口管理 | `WindowGroup` 有限控制 | `NSWindow` 完整窗口管理 |
| 剪贴板 | 基础支持 | `NSPasteboard` / `UIPasteboard` 完整格式支持 |
| 拖放 | 声明式 API | `NSDragging` / `UIDragInteraction` 完整控制 |
| 打印 | 无原生支持 | `NSPrintOperation` / `UIPrintInteractionController` |

---

## Phase A — 高优先级 AppKit/UIKit 集成

### A1. 小说阅读器 — NSTextView 替代 Text

**问题：**
- SwiftUI `Text` 不支持富文本（行内图片、链接高亮、注音）
- 长文本渲染性能差（全部渲染，无虚拟化）
- 无法精确控制光标、选择、复制行为
- 翻译叠加需要自定义布局

**解决方案：**
```swift
// NSTextView + NSAttributedString
struct NovelTextRenderer: NSViewRepresentable {
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let textView = NSTextView()
        // 配置富文本、行间距、字体
        scrollView.documentView = textView
        return scrollView
    }
}
```

**收益：**
- 原生富文本渲染（注音、链接、图片）
- 虚拟化长文本（性能提升 10x）
- 精确的文本选择和复制
- 原生输入法支持（日文/中文）
- 更好的翻译叠加布局

**文件：** `Views/NovelReaderView.swift` (800+ lines)

---

### A2. 图片查看器 — NSScrollView + NSMagnificationGestureRecognizer

**问题：**
- SwiftUI `scaleEffect` + `offset` 手动计算缩放/平移
- 无惯性滚动、无边界回弹
- 双指缩放不流畅
- 无法精确控制缩放中心点

**解决方案：**
```swift
// NSScrollView with custom magnification
struct ImageScrollView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let imageView = NSImageView()
        scrollView.documentView = imageView
        scrollView.allowsMagnification = true
        scrollView.minMagnification = 1.0
        scrollView.maxMagnification = 4.0
        return scrollView
    }
}
```

**收益：**
- 原生惯性滚动和边界回弹
- 流畅的双指缩放（系统级优化）
- 精确的缩放中心点控制
- 更好的触控板手势支持

**文件：** `Views/ArtworkReaderView.swift` (600+ lines)

---

### A3. 画廊滚动 — NSCollectionView 替代 LazyVStack

**问题：**
- `LazyVStack` cell 复用有限制（内存增长）
- 无预取 API（滚动到边缘才加载）
- 无自定义布局（masonry 需要手动计算）
- 滚动性能在大数据集下降

**解决方案：**
```swift
// NSCollectionView with custom layout
struct GalleryCollectionView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSCollectionView {
        let collectionView = NSCollectionView()
        collectionView.collectionViewLayout = MasonryLayout()
        // 注册 cell、配置数据源
        return collectionView
    }
}
```

**收益：**
- 原生 cell 复用（内存固定）
- 预取 API（提前加载可见区域外的内容）
- 自定义布局（masonry、waterfall）
- 更好的滚动性能（1000+ items）

**文件：** `Views/GalleryView.swift`, `Views/GalleryArtworkGrid.swift`

---

### A4. 文本输入 — NSTextField 替代 TextField

**问题：**
- SwiftUI `TextField` 输入法支持有限（日文/中文）
- 无原生自动补全 UI
- 无历史记录下拉
- 搜索建议需要自定义实现

**解决方案：**
```swift
// NSTextField with autocomplete
struct SearchField: NSViewRepresentable {
    func makeNSView(context: Context) -> NSSearchField {
        let searchField = NSSearchField()
        searchField.delegate = context.coordinator
        searchField.sendsSearchStringImmediately = true
        return searchField
    }
}
```

**收益：**
- 原生输入法支持（IME）
- 原生搜索字段样式
- 历史记录下拉
- 更好的自动补全

**文件：** `Views/ContentView.swift` (搜索栏)

---

### A5. 菜单栏 — NSMenu 增强

**问题：**
- SwiftUI `Menu` 有限的自定义选项
- 无法添加自定义视图到菜单项
- 无法动态更新菜单内容
- 快捷键显示有限制

**解决方案：**
```swift
// NSMenu with custom items
struct MenuBarEnhancer: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        // 配置 NSMenu 自定义项
        return view
    }
}
```

**收益：**
- 自定义菜单项视图（图片、进度条）
- 动态菜单更新
- 完整的快捷键显示
- 更好的菜单栏集成

**文件：** `Views/MenuBarExtraView.swift`

---

### A6. 拖放增强 — NSDraggingSession

**问题：**
- SwiftUI `.draggable` 有限的预览自定义
- 无法自定义拖放动画
- 多项拖放支持有限
- 无法精确控制拖放区域

**解决方案：**
```swift
// NSDraggingSource + NSDraggingDestination
struct DragDropView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = DraggableNSView()
        // 配置拖放源和目标
        return view
    }
}
```

**收益：**
- 自定义拖放预览
- 流畅的拖放动画
- 多项拖放支持
- 精确的拖放区域控制

**文件：** `Views/GalleryArtworkGrid.swift` (拖放画作)

---

## Phase B — 中优先级 AppKit/UIKit 集成

### B1. 打印支持 — NSPrintOperation

**问题：** 无原生打印支持
**解决方案：** `NSPrintOperation` 打印画作/小说
**收益：** 用户可以直接打印内容

### B2. 触控栏增强 — NSTouchBar 自定义

**问题：** 当前 Touch Bar 基础实现
**解决方案：** `NSTouchBar` 自定义滑块、进度条
**收益：** 更丰富的触控栏交互

### B3. 窗口管理 — NSWindow 增强

**问题：** SwiftUI `WindowGroup` 有限控制
**解决方案：** `NSWindow` 自定义标题栏、工具栏
**收益：** 更好的窗口自定义

### B4. 通知中心 — NSUserNotificationCenter 增强

**问题：** 基础通知支持
**解决方案：** 自定义通知内容、操作按钮
**收益：** 更丰富的通知交互

### B5. Finder 集成 — NSWorkspace 增强

**问题：** 基础文件操作
**解决方案：** `NSWorkspace` 自定义文件图标、预览
**收益：** 更好的 Finder 集成

---

## Phase C — iPadOS UIKit 集成

### C1. 手势识别 — UIGestureRecognizer

**问题：** SwiftUI 手势有限
**解决方案：** `UIGestureRecognizer` 自定义手势
**收益：** 更精细的手势控制

### C2. 图片查看 — UIScrollView

**问题：** SwiftUI 缩放/平移不流畅
**解决方案：** `UIScrollView` 原生缩放
**收益：** 流畅的图片查看

### C3. 文本渲染 — UITextView

**问题：** SwiftUI Text 限制
**解决方案：** `UITextView` 富文本
**收益：** 更好的文本渲染

### C4. 文件选择 — UIDocumentPickerViewController

**问题：** SwiftUI 文件选择有限
**解决方案：** `UIDocumentPickerViewController`
**收益：** 原生文件选择体验

### C5. 分享 — UIActivityViewController

**问题：** SwiftUI ShareLink 有限
**解决方案：** `UIActivityViewController`
**收益：** 更多分享选项

---

## 实施计划

### 阶段 1：核心阅读器重写（高优先级）

| 项目 | 平台 | 工作量 | 影响 |
|------|------|--------|------|
| A1. NSTextView 小说阅读器 | macOS | 大 | 高 |
| A2. NSScrollView 图片查看器 | macOS | 中 | 高 |
| A4. NSTextField 搜索栏 | macOS | 小 | 中 |

### 阶段 2：画廊和交互（中优先级）

| 项目 | 平台 | 工作量 | 影响 |
|------|------|--------|------|
| A3. NSCollectionView 画廊 | macOS | 大 | 高 |
| A5. NSMenu 增强 | macOS | 小 | 低 |
| A6. NSDraggingSession 拖放 | macOS | 中 | 中 |

### 阶段 3：iPadOS 适配（中优先级）

| 项目 | 平台 | 工作量 | 影响 |
|------|------|--------|------|
| C1. UIGestureRecognizer | iPadOS | 中 | 高 |
| C2. UIScrollView 图片查看 | iPadOS | 中 | 高 |
| C3. UITextView 文本渲染 | iPadOS | 中 | 中 |

### 阶段 4：平台增强（低优先级）

| 项目 | 平台 | 工作量 | 影响 |
|------|------|--------|------|
| B1. NSPrintOperation | macOS | 小 | 低 |
| B2. NSTouchBar 增强 | macOS | 小 | 低 |
| B3. NSWindow 增强 | macOS | 中 | 中 |
| B4. NSUserNotificationCenter | macOS | 小 | 低 |
| B5. NSWorkspace 增强 | macOS | 小 | 低 |

---

## 关键架构原则

### 1. 渐进式迁移
- 不要一次性重写所有视图
- 从性能瓶颈开始（小说阅读器、图片查看器）
- 保持 SwiftUI 声明式 API 的优势

### 2. 协议抽象
```swift
// 跨平台协议
protocol TextRenderer {
    func render(_ text: String, style: TextStyle) -> some View
}

// macOS 实现
struct MacTextRenderer: TextRenderer {
    func render(_ text: String, style: TextStyle) -> some View {
        NovelTextNSView(text: text, style: style)
    }
}

// iPadOS 实现
struct IPadTextRenderer: TextRenderer {
    func render(_ text: String, style: TextStyle) -> some View {
        NovelTextUIView(text: text, style: style)
    }
}
```

### 3. 状态管理
- SwiftUI 状态（`@Observable`）保持不变
- AppKit/UIKit 视图通过 `NSViewRepresentable` / `UIViewRepresentable` 桥接
- 使用 `Coordinator` 模式处理委托回调

### 4. 测试策略
- 单元测试：纯 Swift 逻辑（不变）
- UI 测试：SwiftUI 视图（不变）
- 集成测试：AppKit/UIKit 桥接（新增）

---

## 风险和缓解

| 风险 | 影响 | 缓解措施 |
|------|------|----------|
| 代码复杂度增加 | 维护成本 | 协议抽象，清晰的职责分离 |
| 平台差异 | 跨平台兼容 | 条件编译，平台抽象层 |
| 测试困难 | 质量保证 | 协议 mock，集成测试 |
| 性能回归 | 用户体验 | 基准测试，性能监控 |

---

## Phase 2 改进计划（续）

> 详见 `IMPROVEMENT_PLAN_PHASE2.md`，以下为摘要。

### P4 — Testing & Quality

- [ ] **4.1** KeiPixStore unit tests
- [ ] **4.2** PixivAPI integration tests
- [ ] **4.3** ArtworkDownloadStore tests
- [ ] **4.4** ImagePipeline tests
- [ ] **4.5** Snapshot tests for key views

### P5 — Performance Optimization

- [ ] **5.1** Image preloading strategy
- [ ] **5.2** Lazy loading for comments
- [ ] **5.3** Download queue optimization
- [ ] **5.4** Feed snapshot compression
- [ ] **5.5** Reduce SwiftUI view body evaluations

### P6 — Accessibility

- [ ] **6.1** VoiceOver for gallery grid
- [ ] **6.2** Keyboard navigation for gallery
- [ ] **6.3** Reduce motion support
- [ ] **6.4** High contrast support
- [ ] **6.5** VoiceOver for reader

### P7 — UX Polish

- [ ] **7.1** Smooth page transitions
- [ ] **7.2** Gallery scroll position restoration
- [ ] **7.3** Undo for destructive actions
- [ ] **7.4** Search history improvements
- [ ] **7.5** Download progress in Dock
- [ ] **7.6** Notification grouping

### P8 — Code Quality

- [ ] **8.1** Extract KeiPixStore+Search
- [ ] **8.2** Extract KeiPixStore+Feed
- [ ] **8.3** Type-safe route parameters
- [ ] **8.4** Consistent error messages
- [ ] **8.5** Remove dead code

### P9 — Security & Privacy

- [ ] **9.1** Token storage hardening
- [ ] **9.2** Network request signing
- [ ] **9.3** Privacy manifest
- [ ] **9.4** Content Security Policy

### P10 — Documentation

- [ ] **10.1** Architecture decision records
- [ ] **10.2** API documentation
- [ ] **10.3** Contributing guide update

### P11 — Platform Features

- [ ] **11.1** macOS menu bar search
- [ ] **11.2** Spotlight deep links
- [ ] **11.3** Siri integration
- [ ] **11.4** Live Activities
- [ ] **11.5** App Intents improvements

---

## 统计

| 分类 | 项目数 | 状态 |
|------|--------|------|
| Phase A (高优先级) | 6 | 待开始 |
| Phase B (中优先级) | 5 | 待开始 |
| Phase C (iPadOS) | 5 | 待开始 |
| Phase 2 改进 | 38 | 待开始 |
| **总计** | **54** | |
