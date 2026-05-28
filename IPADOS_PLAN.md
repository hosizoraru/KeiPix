# KeiPix iPadOS Adaptation Plan

> Created 2026-05-28. Target: iPadOS 26.0
> Prerequisite: iPadOS target already added (`256d3b9`)

---

## Phase 1 — Core UI Adaptation

- [x] **1.1 ContentView platform split** — `5435bd4`

- [ ] **1.2 Adaptive column widths**
  - File: `Views/ContentView.swift`
  - macOS: Fixed sidebar width (220pt), flexible detail
  - iPadOS: Full-width gallery, slide-over detail panel
  - Impact: Layout on different iPad sizes

- [x] **1.3 Remove macOS-only frame constraints** — `e966c33`

- [x] **1.4 Reader as full-screen sheet** — `80a935f`

---

## Phase 2 — Touch Gestures

- [x] **2.1 Replace TrackpadEventBridge** — `1c805eb`

- [x] **2.2 Swipe-to-navigate** — `1c805eb` (included in gesture bridge)

- [x] **2.3 Pinch-to-zoom** — `1c805eb` (included in gesture bridge)

- [ ] **2.4 Long-press context menus**
  - Files: Gallery cards, artwork detail
  - iPadOS: `.contextMenu` already works, verify touch targets
  - Impact: Touch-friendly interactions

---

## Phase 3 — Platform-Specific Features

- [ ] **3.1 Share Sheet**
  - iPadOS: `ShareLink` already used in some places
  - Verify: All share actions use `ShareLink` (not `NSSharingService`)
  - Impact: Native share experience

- [ ] **3.2 Multitasking support**
  - iPadOS: `NavigationSplitView` adapts to split-view automatically
  - Verify: App works in Slide Over, Split View, Stage Manager
  - Impact: Multi-window productivity

- [ ] **3.3 Drag and Drop**
  - iPadOS: `.draggable` and `.dropDestination` modifiers
  - Verify: Artwork card drag works on iPad
  - Impact: Content sharing between apps

- [ ] **3.4 Keyboard shortcuts**
  - iPadOS: `.keyboardShortcut` works on iPad with external keyboard
  - Verify: All shortcuts from `KeyboardShortcutCatalog` work
  - Impact: Power-user workflow

---

## Phase 4 — File & Document Handling

- [ ] **4.1 Replace NSOpenPanel/NSSavePanel**
  - Files: `Stores/KeiPixStore+ImageSourceSearch.swift`, `Support/PlatformFilePicker.swift`
  - iPadOS: Use `UIDocumentPickerViewController` via `PlatformFilePicker`
  - Impact: File import/export

- [ ] **4.2 Photos library access**
  - iPadOS: `PHPhotoPicker` for saving to Photos
  - Verify: Download-to-Photos flow works
  - Impact: Save artwork to device

- [ ] **4.3 Files app integration**
  - iPadOS: Downloads go to app's Documents directory
  - Verify: Files app can browse downloads
  - Impact: File management

---

## Phase 5 — Notifications & Background

- [ ] **5.1 Background fetch**
  - iPadOS: `BGTaskScheduler` for feed refresh
  - macOS: Already handled by app lifecycle
  - Impact: Fresh content on app launch

- [ ] **5.2 Push notifications**
  - iPadOS: Same `UNUserNotificationCenter` API
  - Verify: Download completion notifications work
  - Impact: User feedback

---

## Phase 6 — Testing & Polish

- [ ] **6.1 iPad simulator testing**
  - Test all major flows on iPad simulator
  - Verify: Login, browse, download, read, bookmark
  - Impact: Quality assurance

- [ ] **6.2 Touch target sizing**
  - Verify all interactive elements meet 44pt minimum
  - Impact: Touch usability

- [ ] **6.3 Dynamic Type support**
  - Verify text scales properly on iPad
  - Impact: Accessibility

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
