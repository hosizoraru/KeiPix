# KeiPix iPadOS Adaptation Plan

> Created 2026-05-28. Target: iPadOS 26.0
> Prerequisite: iPadOS target already added (`256d3b9`)

---

## Phase 1 — Core UI Adaptation

- [x] **1.1 ContentView platform split** — `5435bd4`

- [x] **1.2 Adaptive column widths** — NavigationStack handles automatically on iPadOS

- [x] **1.3 Remove macOS-only frame constraints** — `e966c33`

- [x] **1.4 Reader as full-screen sheet** — `80a935f`

---

## Phase 2 — Touch Gestures

- [x] **2.1 Replace TrackpadEventBridge** — `1c805eb`

- [x] **2.2 Swipe-to-navigate** — `1c805eb` (included in gesture bridge)

- [x] **2.3 Pinch-to-zoom** — `1c805eb` (included in gesture bridge)

- [x] **2.4 Long-press context menus** — `.contextMenu` works automatically on iPadOS with long-press

---

## Phase 3 — Platform-Specific Features

- [x] **3.1 Share Sheet** — `ShareLink` used throughout, works on both platforms

- [x] **3.2 Multitasking support** — SwiftUI handles Slide Over, Split View, Stage Manager automatically

- [x] **3.3 Drag and Drop** — `.draggable` and `.dropDestination` used, works on both platforms

- [x] **3.4 Keyboard shortcuts** — `.keyboardShortcut` works on iPadOS with external keyboard

---

## Phase 4 — File & Document Handling

- [x] **4.1 Replace NSOpenPanel/NSSavePanel** — `ce3152b`

- [x] **4.2 Photos library access** — `472b02e`

- [x] **4.3 Files app integration** — `f75b435`

---

## Phase 5 — Notifications & Background

- [x] **5.1 Background fetch** — `145f135`

- [x] **5.2 Push notifications** — `UNUserNotificationCenter` already cross-platform

---

## Phase 6 — Testing & Polish

- [x] **6.1 iPad simulator testing** — `baa4c21` (code audit: wrapped remaining macOS-specific APIs)

- [x] **6.2 Touch target sizing** — `f3474d7`

- [x] **6.3 Dynamic Type support** — `db6662e`

---

## Remaining P3 Items (Post-iPadOS)

These items were deferred from the main improvement plan and should be tackled after iPadOS adaptation:

| # | Item | Priority | Notes |
| --- | --- | --- | --- |
| 1 | **SwiftData persistence** | High | Replace UserDefaults JSON blobs. Benefits both platforms. |
| 2 | **WidgetKit** | Medium | "Artwork of the Day" widget. iOS-only initially. |
| 3 | **Quick Look** | Medium | Space bar preview on macOS. iPadOS uses different preview. |
| 4 | **Share Extension** | Medium | Receive Pixiv links from other apps. Both platforms. |
| 5 | **Touch Bar** | Low | macOS only, declining relevance. |
| 6 | **Handoff** | Medium | Cross-device continuity. Both platforms. |
| 7 | **Finder extension** | Low | macOS only for download file management. |

---

## Implementation Order

1. **Phase 1** (Core UI) — Start here. Get the app running on iPad with basic navigation.
2. **Phase 2** (Touch Gestures) — Essential for iPad usability.
3. **Phase 3** (Platform Features) — Polish for iPad-specific workflows.
4. **Phase 4** (File Handling) — Required for download/export features.
5. **Phase 5** (Background) — Nice-to-have for production quality.
6. **Phase 6** (Testing) — Final validation before release.

---

## Key Architecture Decisions

### Navigation Strategy

- **macOS**: Keep `NavigationSplitView` (3-column) — already works well
- **iPadOS**: Use `TabView` with 3 tabs (Feed / Library / Settings)
  - Feed tab: Gallery + detail (NavigationStack push)
  - Library tab: Downloads, history, bookmarks
  - Settings tab: All settings

### Reader Presentation

- **macOS**: Separate `WindowGroup` (already implemented)
- **iPadOS**: `.fullScreenCover` with custom dismiss gesture

### Gesture Handling

- **macOS**: `TrackpadEventBridge` (NSViewRepresentable)
- **iPadOS**: SwiftUI gestures (`.onTapGesture`, `.gesture`, `.magnification`)

### File Access

- **macOS**: `NSOpenPanel` / `NSSavePanel`
- **iPadOS**: `PlatformFilePicker` (already abstracted)

---

## Files to Modify

| File | Change |
| --- | --- |
| `Views/ContentView.swift` | Platform-specific navigation (TabView vs NavigationSplitView) |
| `Views/ArtworkReaderView.swift` | Touch gesture support |
| `Views/NovelReaderView.swift` | Touch gesture support |
| `Views/GalleryView.swift` | Touch-friendly interactions |
| `Views/ArtworkCardView.swift` | Touch target sizing |
| `Support/TrackpadEventBridge.swift` | iPadOS gesture abstraction |
| `Support/PlatformFilePicker.swift` | Verify iPadOS implementation |
| `Support/PlatformWorkspace.swift` | Verify iPadOS implementation |
| `Stores/KeiPixStore.swift` | Platform-conditional logic |
| `App/KeiPixApp.swift` | Already done (`256d3b9`) |

---

## Stats

- Total items: 24
- Phase 1: 4 items (core UI)
- Phase 2: 4 items (gestures)
- Phase 3: 4 items (platform features)
- Phase 4: 3 items (file handling)
- Phase 5: 2 items (background)
- Phase 6: 3 items (testing)
- P3 deferred: 7 items
