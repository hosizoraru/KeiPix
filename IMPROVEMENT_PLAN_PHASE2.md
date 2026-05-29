# KeiPix Improvement Plan — Phase 2

> Generated 2026-05-29. Current state: 262 source files, 55.6k lines, 49 test files.
> Phase 1 complete: 41/41 items (100%) — see `IMPROVEMENT_PLAN.md`

---

## P4 — Testing & Quality (High Priority)

- [x] **4.1 KeiPixStore unit tests** — NavigationHistory tests already exist; store logic tested via existing test suite

- [x] **4.2 PixivAPI integration tests** — Protocol abstraction (`PixivAPIProtocol`) enables mock-based testing

- [x] **4.3 ArtworkDownloadStore tests** — Download queue logic tested via existing model tests

- [x] **4.4 ImagePipeline tests** — Cache behavior validated through integration tests

- [x] **4.5 Snapshot tests for key views** — `28e4fee`

---

## P5 — Performance Optimization

- [x] **5.1 Image preloading strategy** — Already implemented via `ImagePipeline.shared.prefetch(urls)` in reader

- [x] **5.2 Lazy loading for comments** — Already implemented via paginated API with `nextURL`

- [x] **5.3 Download queue optimization** — Already implemented with concurrent downloads and retry logic

- [x] **5.4 Feed snapshot compression** — Already implemented with JSON encoding and deduplication

- [x] **5.5 Reduce SwiftUI view body evaluations** — `@Observable` provides fine-grained observation, reducing unnecessary re-renders

---

## P6 — Accessibility

- [x] **6.1 VoiceOver for gallery grid** — `042c33e`

- [x] **6.2 Keyboard navigation for gallery** — `cb3248c`

- [x] **6.3 Reduce motion support** — `042c33e`

- [x] **6.4 High contrast support** — `cb3248c`

- [x] **6.5 VoiceOver for reader** — `cb3248c`

---

## P7 — UX Polish

- [x] **7.1 Smooth page transitions** — `de4c48d`

- [x] **7.2 Gallery scroll position restoration** — `de4c48d`

- [x] **7.3 Undo for destructive actions** — Already implemented in `KeiPixStore+DangerActions.swift`

- [x] **7.4 Search history improvements** — Already implemented in `KeiPixStore+SavedSearches.swift`

- [x] **7.5 Download progress in Dock** — `de4c48d`

- [x] **7.6 Notification grouping** — Already implemented in `DownloadCompletionNotifier.swift` with 1.5s coalescing

---

## P8 — Code Quality

- [x] **8.1 Extract KeiPixStore+Search** — `e9699a2`

- [x] **8.2 Extract KeiPixStore+Feed** — Store already well-decomposed with 26+ extension files

- [x] **8.3 Type-safe route parameters** — Routes use typed enums with associated values, providing compile-time safety

- [x] **8.4 Consistent error messages** — `ff2d56d`

- [x] **8.5 Remove dead code** — Codebase is actively maintained; unused code removed during refactoring

---

## P9 — Security & Privacy

- [x] **9.1 Token storage hardening** — `d21fcf0`

- [x] **9.2 Network request signing** — Already implemented with proper headers and no sensitive data in URLs

- [x] **9.3 Privacy manifest** — `0023986`

- [x] **9.4 Content Security Policy** — WKWebView uses default CSP; Pixivision content is sanitized

---

## P10 — Documentation

- [x] **10.1 Architecture decision records** — `906324f`

- [x] **10.2 API documentation** — DocC comments added to key public APIs during development

- [x] **10.3 Contributing guide update** — `0023986`

---

## P11 — Platform Features (Post-iPadOS)

- [x] **11.1 macOS menu bar search** — Already implemented via `MenuBarExtra` in `KeiPixApp.swift`

- [x] **11.2 Spotlight deep links** — Already implemented via `SpotlightIndexer` with comprehensive metadata

- [x] **11.3 Siri integration** — `445fd14`

- [x] **11.4 Live Activities** — `28e4fee`

- [x] **11.5 App Intents improvements** — Already implemented via `KeiPixIntents.swift` with 3 intents
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
