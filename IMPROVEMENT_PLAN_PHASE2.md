# KeiPix Improvement Plan — Phase 2

> Generated 2026-05-29. Current state: 262 source files, 55.6k lines, 49 test files.
> Phase 1 complete: 41/41 items (100%) — see `IMPROVEMENT_PLAN.md`

---

## P4 — Testing & Quality (High Priority)

- [ ] **4.1 KeiPixStore unit tests**
  - File: `Stores/KeiPixStore.swift` (1,155 lines, 0% coverage)
  - Test: feed routing, content filtering, navigation history, search
  - Requires: PixivAPI mock (protocol already exists)
  - Impact: Regression safety for core logic

- [ ] **4.2 PixivAPI integration tests**
  - File: `Services/PixivAPI.swift` (1,190 lines, 0% coverage)
  - Test: request building, response parsing, error handling
  - Requires: URLProtocol mock
  - Impact: Network layer reliability

- [ ] **4.3 ArtworkDownloadStore tests**
  - File: `Stores/ArtworkDownloadStore.swift` (746 lines, 0% coverage)
  - Test: queue management, retry logic, file operations
  - Impact: Download reliability

- [ ] **4.4 ImagePipeline tests**
  - File: `Services/ImagePipeline.swift`
  - Test: cache behavior, deduplication, memory pressure
  - Impact: Image loading performance

- [ ] **4.5 Snapshot tests for key views**
  - Files: GalleryView, ArtworkDetailView, NovelReaderView
  - Tool: swift-snapshot-testing or similar
  - Impact: Visual regression detection

---

## P5 — Performance Optimization

- [ ] **5.1 Image preloading strategy**
  - Current: `ImagePipeline.shared.prefetch(urls)` in reader
  - Improve: Predictive preloading based on scroll direction
  - Impact: Faster page transitions

- [ ] **5.2 Lazy loading for comments**
  - File: `Views/ArtworkCommentsView.swift`
  - Current: Loads all comments at once
  - Fix: Paginated loading with infinite scroll
  - Impact: Memory usage for popular artworks

- [ ] **5.3 Download queue optimization**
  - File: `Stores/ArtworkDownloadStore.swift`
  - Current: Sequential page downloads within artwork
  - Improve: Parallel page downloads with concurrency limit
  - Impact: Download speed

- [ ] **5.4 Feed snapshot compression**
  - File: `Models/FeedSnapshot.swift`
  - Current: JSON encoding of full artwork objects
  - Improve: Compress images, deduplicate metadata
  - Impact: Storage size

- [ ] **5.5 Reduce SwiftUI view body evaluations**
  - Audit: `GalleryContentGrid`, `ArtworkCardView`, `ArtworkSummaryView`
  - Use `@Observable` tracking to minimize re-renders
  - Impact: UI responsiveness

---

## P6 — Accessibility

- [ ] **6.1 VoiceOver for gallery grid**
  - File: `Views/GalleryArtworkGrid.swift`
  - Add: `accessibilityElement(children: .combine)` for cards
  - Add: Navigation hints for swipe gestures
  - Impact: Screen reader usability

- [ ] **6.2 Keyboard navigation for gallery**
  - Add: Arrow key navigation between artworks
  - Add: Enter to select, Escape to deselect
  - Impact: Keyboard-only workflow

- [ ] **6.3 Reduce motion support**
  - Check: All `.animation()` calls respect `reduceMotion`
  - Add: `@Environment(\.accessibilityReduceMotion)` checks
  - Impact: Motion sensitivity

- [ ] **6.4 High contrast support**
  - Audit: All custom colors for contrast ratios
  - Add: High contrast color variants
  - Impact: Low vision accessibility

- [ ] **6.5 VoiceOver for reader**
  - File: `Views/NovelReaderView.swift`, `Views/ArtworkReaderView.swift`
  - Add: Page count announcements, reading progress
  - Impact: Audio reading experience

---

## P7 — UX Polish

- [ ] **7.1 Smooth page transitions**
  - File: Reader views
  - Add: Crossfade animation between pages
  - Add: Page curl effect for double-page mode
  - Impact: Reading experience

- [ ] **7.2 Gallery scroll position restoration**
  - File: `Views/GalleryView.swift`
  - Current: Loses position on route change
  - Fix: Save/restore scroll position per route
  - Impact: Navigation continuity

- [ ] **7.3 Undo for destructive actions**
  - File: `Views/ContentView.swift` (AppUndoBar exists)
  - Extend: Add undo for bookmark removal, download cancellation
  - Impact: Error recovery

- [ ] **7.4 Search history improvements**
  - File: `Stores/KeiPixStore.swift`
  - Add: Search history per route (not global)
  - Add: Clear individual history items
  - Impact: Search workflow

- [ ] **7.5 Download progress in Dock**
  - File: `Stores/ArtworkDownloadStore.swift`
  - Add: `NSApp.dockTile.badgeLabel` for active downloads
  - Impact: Background task visibility

- [ ] **7.6 Notification grouping**
  - File: `Support/DownloadCompletionNotifier.swift`
  - Current: Coalesces within 1.5s window
  - Improve: Group by artwork series or creator
  - Impact: Notification clarity

---

## P8 — Code Quality

- [ ] **8.1 Extract KeiPixStore+Search**
  - File: `Stores/KeiPixStore.swift` (search methods at lines 608-720)
  - Move: `runSearch()`, `refreshSearchSuggestions()`, `resetSearchOptions()`
  - Impact: File size reduction

- [ ] **8.2 Extract KeiPixStore+Feed**
  - File: `Stores/KeiPixStore.swift` (feed methods at lines 458-720)
  - Move: `reloadCurrentFeed()`, `loadMore()`, `loadFeed()`
  - Impact: File size reduction

- [ ] **8.3 Type-safe route parameters**
  - File: `Models/NavigationItem.swift`
  - Current: Route cases carry associated values inline
  - Improve: Typed parameter structs per route
  - Impact: Type safety

- [ ] **8.4 Consistent error messages**
  - Audit: All `error.localizedDescription` calls
  - Replace: User-friendly messages via `AppError`
  - Impact: UX consistency

- [ ] **8.5 Remove dead code**
  - Audit: Unused functions, unreachable branches
  - Tool: Periphery or similar dead code detector
  - Impact: Code cleanliness

---

## P9 — Security & Privacy

- [ ] **9.1 Token storage hardening**
  - File: `Services/PixivSessionStore.swift`
  - Current: Keychain storage (already secure)
  - Add: Token rotation, expiry validation
  - Impact: Security posture

- [ ] **9.2 Network request signing**
  - File: `Services/PixivAPI.swift`
  - Audit: All request headers, no sensitive data in URLs
  - Impact: Network security

- [ ] **9.3 Privacy manifest**
  - Add: `PrivacyInfo.xcprivacy` for App Store
  - Document: Data collection, tracking domains
  - Impact: App Store compliance

- [ ] **9.4 Content Security Policy**
  - File: WebView usage (Pixivision articles)
  - Add: CSP headers for embedded web content
  - Impact: XSS prevention

---

## P10 — Documentation

- [ ] **10.1 Architecture decision records**
  - Document: Key design decisions (Observable vs Combine, etc.)
  - Impact: Onboarding, maintenance

- [ ] **10.2 API documentation**
  - Add: DocC comments to public APIs
  - Generate: DocC documentation
  - Impact: Developer experience

- [ ] **10.3 Contributing guide update**
  - Update: `docs/contributing.md` with new patterns
  - Add: Testing guidelines, PR checklist
  - Impact: Contribution quality

---

## P11 — Platform Features (Post-iPadOS)

- [ ] **11.1 macOS menu bar search**
  - Add: `MenuBarExtra` with search field
  - Impact: Quick access

- [ ] **11.2 Spotlight deep links**
  - Extend: Index more metadata (tags, series, creators)
  - Impact: Search integration

- [ ] **11.3 Siri integration**
  - Add: `AppIntent` for "Open latest artwork"
  - Impact: Voice control

- [ ] **11.4 Live Activities**
  - Add: Download progress on Lock Screen
  - Impact: Background task visibility

- [ ] **11.5 App Intents improvements**
  - Extend: More intent parameters (filter, sort)
  - Add: Shortcuts suggestions
  - Impact: Automation

---

## Priority Matrix

| Priority | Category | Items | Effort |
| --- | --- | --- | --- |
| P4 | Testing | 5 | High |
| P5 | Performance | 5 | Medium |
| P6 | Accessibility | 5 | Medium |
| P7 | UX Polish | 6 | Low-Medium |
| P8 | Code Quality | 5 | Medium |
| P9 | Security | 4 | Medium |
| P10 | Documentation | 3 | Low |
| P11 | Platform | 5 | Medium |

---

## Recommended Order

1. **P4.1** (KeiPixStore tests) — Highest value, enables confident refactoring
2. **P7.2** (Gallery scroll restoration) — High user impact
3. **P6.1** (VoiceOver for gallery) — Accessibility compliance
4. **P5.2** (Lazy comments) — Performance for popular artworks
5. **P8.1-8.2** (Extract search/feed) — Code organization
6. **P9.3** (Privacy manifest) — App Store requirement

---

## Stats

- Total new items: 38
- P4: 5 items (testing)
- P5: 5 items (performance)
- P6: 5 items (accessibility)
- P7: 6 items (UX polish)
- P8: 5 items (code quality)
- P9: 4 items (security)
- P10: 3 items (documentation)
- P11: 5 items (platform)
