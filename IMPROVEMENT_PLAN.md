# KeiPix Improvement Plan

> Generated 2026-05-28 from comprehensive codebase analysis.
> 242 Swift files, ~54k lines, 49 test files.

---

## P0 — High Impact, Small Effort

- [x] **1. Memoize `clientFilteredArtworks`** — `3fd6781`
- [x] **2. Add VoiceOver labels to `ArtworkCardView`** — `044f1a0`
- [x] **3. Add `.refreshable` to `GalleryView`** — `fddd828`
- [x] **4. Extract status message debounce pattern** — `1980090`

- [x] **5. Convert error alerts to non-blocking toasts** — `639d950`

---

## P1 — High Impact, Medium Effort

- [x] **6. Extract QA/VisualQA code from production** — `79dfa38`
  - Files: `Stores/KeiPixStore+NonNovelQA.swift` (747 lines), `Support/VisualQASampleData.swift` (883 lines)
  - Fix: Move to test target or wrap in `#if DEBUG`
  - Impact: Binary size, code cleanliness

- [x] **7. Replace repetitive `setX()`/UserDefaults pattern** — `0e7275a`
- [x] **8. L10n system already uses String Catalog** — `text()` reads from compiled `.xcstrings` `.lproj` bundles. Manual `L10n` enum needed for custom `appLanguage` override (not supported by `LocalizedStringResource`).
- [x] **9. Refactor `loadFeed` route mapping** — `0fe99e9`
- [x] **10. Wrap AppKit imports in `#if os(macOS)`** — `40c1e72`

---

## P2 — Architecture Refactors (Long-term)

- [x] **11. Split KeiPixStore** — `a0e1708` (extracted PixivLinks, 26 extension files total)

- [x] **12. Add PixivAPI protocol abstraction** — `298f224`

- [x] **13. Structured error handling** — `3adba2e`

- [ ] **14. SwiftData persistence layer**
  - Problem: All persistence via UserDefaults JSON blobs
  - Fix: SwiftData models for history, downloads, bookmarks, watchlist
  - Impact: Query performance, relationship modeling

---

## P3 — Platform Integration (Nice-to-have)

- [ ] WidgetKit — "Artwork of the Day", download queue status
- [ ] Quick Look — Space bar artwork preview
- [ ] Share Extension — receive Pixiv links from other apps
- [x] Haptic feedback — `ba4e8a9`
- [x] Skeleton loading states — `ba4e8a9`
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
