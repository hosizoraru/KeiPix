# Architecture

KeiPix 是 SwiftPM 单 executable target 的原生 Apple 平台客户端。当前主平台是 macOS 26+；`Package.swift` 同时声明 iOS 26，用于保留同源码 iPadOS 适配路线。整体 UI 架构已经调整为 **AppKit/UIKit 优先、SwiftUI 辅助**：平台热路径下沉到原生 view，SwiftUI 负责应用外壳、状态绑定、轻量组合与设置类 surface。

## Source Layout

```text
Sources/KeiPix/
├── App/             # App entry, AppDelegate, dock/menu/service wiring
├── Intents/         # AppIntents and Shortcuts
├── Models/          # Pixiv API models, route models, reader/QA models
├── Services/        # PixivAPI, PixivSessionStore, ImagePipeline, release, SauceNAO
├── Stores/          # KeiPixStore plus domain extensions
├── Support/         # Native bridges, platform abstractions, shared utilities
├── Views/           # SwiftUI shell/composition around native hot paths
└── Resources/       # Localizable.xcstrings and bundled resources
```

`KeiPix.xcodeproj` 由 XcodeGen 根据 `project.yml` 生成。仓库里的 Xcode target 当前是 macOS；iPadOS 仍处在同源码 UIKit bridge 与 SwiftPM 平台声明阶段，不把它描述成已发布 target。

## UI Ownership

| Layer | Owner | Examples |
| --- | --- | --- |
| Window, route, settings, forms, lightweight composition | SwiftUI | `KeiPixApp`, sidebars, settings sections, action sheets |
| Dense collection/list virtualization | AppKit/UIKit | `NativeGalleryCollectionView`, `NativeBrowsingHistoryCollectionView`, `NativeCreatorPreviewCollectionView`, `NativeDownloadQueueListView` |
| Image reader viewport | AppKit/UIKit | `ImageScrollView`, `iPadImageScrollView`, `ReaderPageViewportLayout` |
| Long text rendering | AppKit/UIKit TextKit | `NativeNovelTextPageView`, `NovelTextNSView`, `iPadTextRenderer` |
| Platform input and integration | AppKit/UIKit | `SearchFieldNSView`, `EnhancedMenuNSView`, `DragDropNSView`, `TrackpadEventBridge` |
| Low-heat or rapidly changing surfaces | SwiftUI unless profiling says otherwise | Pixivision wrappers, Runtime Readiness, most settings UI |

The bridge rule is intentionally narrow: native views own rendering, layout reuse, platform gestures and responder behavior; SwiftUI still owns observable state, commands, overlays and screen composition.

## Key Modules

### `KeiPixStore`

- `@MainActor` observable store injected into SwiftUI environment.
- Holds session mode, account metadata, navigation route, feed state, detail state, downloads, local libraries, reading preferences and QA state.
- Split by domain in `Stores/KeiPixStore+*.swift` so feature work can stay localized.
- Async work enters through explicit actions and returns UI mutations to the main actor.

### `PixivAPI`

- Implements Pixiv App API headers, bearer auth, refresh-and-retry, form POST, JSON decoding and diagnostics.
- Covers recommendation, ranking, following, bookmarks, comments, tags, series, users, search, mute and popular-preview routes.
- Exposed through `PixivAPIProtocol` where tests or sample flows need substitution.

### `PixivSessionStore`

- Stores access / refresh tokens in the app sandbox JSON file:
  `~/Library/Containers/com.keipix.client/Data/Library/Application Support/KeiPix/pixiv-sessions.json`.
- Avoids development-time Keychain ACL prompts caused by changing ad-hoc signatures.
- Supports multi-account selection, deletion and migration from the older single-session file.

### `ImagePipeline`

- Adds Pixiv `Referer`, URLCache disk caching and memory caching.
- Shared by remote cards, detail views, local previews and visual QA sample flows.
- Sensitive preview masking is applied at the view layer based on user preferences.

### Native Gallery And Lists

- `NativeGalleryCollectionView` bridges `NSCollectionView` / `UICollectionView`.
- Masonry, compact and list modes share placement/presentation models while native layouts handle reuse and diffable updates.
- Selection highlight updates are kept separate from content reloads, preventing visible masonry reshuffle when opening detail.
- Download queues, browsing history and creator previews use native list/collection containers for keyboard focus, reuse and platform interaction.

### Reader Viewports

- `ImageScrollView` routes macOS image reading through `NSScrollView`; iPadOS uses `UIScrollView`.
- `ReaderPageViewportLayout` gives SwiftUI a stable size contract around native scroll views so single-page and double-page modes do not fight parent layout.
- Multi-page works can use single, double-page, continuous and index modes; single-page works are coerced away from stale double-page preference.

### TextKit Novel Pages

- `NativeNovelTextPageView` handles pure text pages with `NSTextView` / `UITextView`.
- SwiftUI remains responsible for reader chrome, page state, translation state and embedded-image fallback pages.

### URL Routing

- `PixivWebLinkResolver` and `PixivURLRoutingCoverage` normalize Pixiv / Pixivision / `keipix://` / `pixiv://` / `.webloc` / `.url` / pasted text into app routes.
- Runtime Readiness can run resolver samples and live Pixivision article link checks.

### Visual QA

- `VisualQALaunchArgument` currently defines 19 isolated launch modes.
- `VisualQASampleData` injects local sample data and avoids real account state.
- `script/capture_visual_qa.sh` captures the front KeiPix window and writes a screenshot plus manifest.

## Boundary Tests

`Tests/KeiPixTests/NativeBoundaryTests.swift` is the main guardrail for the hybrid direction:

- `Package.swift` must stay on the SwiftPM native route and declare macOS/iOS 26.
- `Sources/KeiPix` must not vendor Flutter, Dart, Kotlin, Gradle or reference-client implementation paths.
- SwiftUI view files stay as composition shells.
- Gallery, reader, TextKit, download queue, browsing history, creator list/search/menu/drop bridges must remain explicit.
- Native gallery must avoid full visible-item reloads for highlight-only changes.

## Data And Privacy

- User preferences, reading progress, local history, saved searches, pinned creators and QA snapshots use `UserDefaults` or small JSON libraries.
- Downloaded files live in user-accessible sandbox/download locations.
- Visual QA uses generated local samples.
- The app has no telemetry; `--telemetry` only tails local unified logging.

## Concurrency

- `SWIFT_STRICT_CONCURRENCY` is enabled.
- UI state is main-actor isolated.
- Network, disk and decoding work are pushed behind async actions or helper types, with UI mutations returning to `@MainActor`.

## Reference Client Boundary

Pixez, Pixes and other clients are product/API references only. Their Flutter/Dart/Kotlin source structure is not copied into `Sources/KeiPix`; behavior is reimplemented with native Swift, AppKit/UIKit and SwiftUI glue, with boundary tests updated before high-risk migrations.
