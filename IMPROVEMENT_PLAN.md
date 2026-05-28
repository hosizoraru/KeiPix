# KeiPix Improvement Plan

> Generated 2026-05-28 from comprehensive codebase analysis.
> 242 Swift files, ~54k lines, 49 test files.

---

## P0 — High Impact, Small Effort

- [x] **1. Memoize `clientFilteredArtworks`** — `3fd6781`
- [x] **2. Add VoiceOver labels to `ArtworkCardView`** — `044f1a0`
- [x] **3. Add `.refreshable` to `GalleryView`** — `fddd828`
- [x] **4. Extract status message debounce pattern** — `1980090`

- [ ] **5. Convert error alerts to non-blocking toasts**
  - File: `Views/ContentView.swift:260`
  - Problem: `.alert` blocks all interaction for transient network errors
  - Fix: Use existing `FloatingStatusBanner` for errors, keep `.alert` only for critical actions
  - Impact: UX — non-blocking error feedback

---

## P1 — High Impact, Medium Effort

- [ ] **6. Extract QA/VisualQA code from production**
  - Files: `Stores/KeiPixStore+NonNovelQA.swift` (747 lines), `Support/VisualQASampleData.swift` (883 lines)
  - Fix: Move to test target or wrap in `#if DEBUG`
  - Impact: Binary size, code cleanliness

- [ ] **7. Replace repetitive `setX()`/UserDefaults pattern**
  - File: `Stores/KeiPixStore+Preferences.swift` (541 lines, 81 setters)
  - Fix: Generic `persist<T>(_ key: String, value: T)` or `@AppStorage` migration
  - Impact: ~400 lines eliminated

- [ ] **8. Auto-generate L10n from String Catalog**
  - File: `Support/L10n.swift` (1,613 lines)
  - Problem: Manual wrapping of every string key
  - Fix: Use Swift's `LocalizedStringResource` or compiler-generated enum from `.xcstrings`
  - Impact: Maintenance burden

- [ ] **9. Refactor `loadFeed` route mapping**
  - File: `Stores/KeiPixStore.swift:862-962` (100-line switch)
  - Fix: Route-to-API mapping table
  - Impact: Extensibility

- [ ] **10. Wrap AppKit imports in `#if os(macOS)`**
  - Files: 7 stores/views with unconditional `import AppKit`
  - Fix: Conditional compilation + use `PlatformFilePicker` consistently
  - Impact: iPadOS readiness

---

## P2 — Architecture Refactors (Long-term)

- [ ] **11. Split KeiPixStore god object**
  - File: `Stores/KeiPixStore.swift` (1,289 lines + extensions)
  - Extract: `PreferencesStore`, `SessionManager`, `FeedCoordinator`
  - Impact: Testability, maintainability

- [ ] **12. Add PixivAPI / ArtworkDownloadStore tests**
  - Files: `Services/PixivAPI.swift` (1,190 lines), `Stores/ArtworkDownloadStore.swift` (746 lines)
  - Fix: Protocol abstractions + mock-based unit tests
  - Impact: Test coverage for critical paths

- [ ] **13. Structured error handling**
  - File: All `errorMessage = error.localizedDescription` calls
  - Fix: `AppError` enum with retry actions, error categorization
  - Impact: UX — better error recovery

- [ ] **14. SwiftData persistence layer**
  - Problem: All persistence via UserDefaults JSON blobs
  - Fix: SwiftData models for history, downloads, bookmarks, watchlist
  - Impact: Query performance, relationship modeling

---

## P3 — Platform Integration (Nice-to-have)

- [ ] WidgetKit — "Artwork of the Day", download queue status
- [ ] Quick Look — Space bar artwork preview
- [ ] Share Extension — receive Pixiv links from other apps
- [ ] Haptic feedback — `NSHapticFeedbackManager` for bookmarks/downloads
- [ ] Skeleton loading states — replace `ProgressView` spinners
- [ ] Touch Bar support
- [ ] Handoff between devices
- [ ] Finder extension for downloaded files

---

## iPadOS Blockers

| Blocker | Files | Fix |
| --- | --- | --- |
| Unconditional `import AppKit` | 7 stores/views | `#if os(macOS)` guards |
| `NSOpenPanel`/`NSSavePanel` direct usage | 3 store files | Use `PlatformFilePicker` |
| `TrackpadEventBridge` (NSViewRepresentable) | `Support/TrackpadEventBridge.swift` | Abstract to protocol |
| `@NSApplicationDelegateAdaptor` | `App/KeiPixApp.swift` | Conditional compilation |
| `MenuBarExtra` scene | `App/KeiPixApp.swift` | `#if os(macOS)` guard |
| `WindowCaptureProtectionBridge` | `Views/` | NSWindow API abstraction |

---

## Stats

- Total items: 24
- P0: 5 items (immediate)
- P1: 5 items (short-term)
- P2: 4 items (medium-term)
- P3: 8 items (long-term)
- iPadOS blockers: 6 items
