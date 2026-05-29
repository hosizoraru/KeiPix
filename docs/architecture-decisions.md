# Architecture Decision Records

> Key design decisions made during KeiPix development.

---

## ADR-001: @Observable over Combine

**Date**: 2026-05-01

**Context**: Need reactive state management for SwiftUI views.

**Decision**: Use Swift's `@Observable` macro instead of Combine's `@Published`.

**Rationale**:
- `@Observable` is the modern Swift approach (Swift 5.9+)
- Better SwiftUI integration with fine-grained observation
- Less boilerplate than Combine
- No `AnyCancellable` management

**Consequences**: All store properties use `@Observable`, views observe directly.

---

## ADR-002: Extension-based store decomposition

**Date**: 2026-05-01

**Context**: KeiPixStore grows large with all features.

**Decision**: Split store into 26+ extension files by domain.

**Rationale**:
- Each extension handles one domain (accounts, social, downloads, etc.)
- Main file stays under 1,200 lines
- Easier to find and modify specific functionality
- Reduces merge conflicts

**Consequences**: Store properties in main file, methods in extensions.

---

## ADR-003: Platform abstraction layer

**Date**: 2026-05-15

**Context**: Need to support both macOS and iPadOS.

**Decision**: Create platform abstraction files with `#if os(macOS)` / `#if os(iOS)`.

**Rationale**:
- Single codebase for both platforms
- Platform-specific code isolated in abstraction files
- Gradual migration from AppKit to SwiftUI
- iPadOS support without separate codebase

**Consequences**: `PlatformTypes`, `PlatformWorkspace`, `PlatformFilePicker`, `PasteboardWriter`.

---

## ADR-004: Hybrid SwiftUI + AppKit/UIKit

**Date**: 2026-05-28

**Context**: SwiftUI has limitations for complex UI (text rendering, gestures, image viewing).

**Decision**: Use AppKit/UIKit wrappers for performance-critical components.

**Rationale**:
- SwiftUI `Text` can't handle rich text efficiently
- SwiftUI gestures lack fine control for trackpad
- `NSScrollView` has better zoom/pan than `scaleEffect`
- `NSCollectionView` has better virtualization than `LazyVStack`

**Consequences**: `NovelTextNSView`, `ImageScrollView`, `SearchFieldNSView`, `TrackpadEventBridge`.

---

## ADR-005: Error handling with AppError

**Date**: 2026-05-28

**Context**: Generic `error.localizedDescription` doesn't provide good UX.

**Decision**: Use `AppError` enum with typed error categories.

**Rationale**:
- Categorize errors (network, auth, parsing, rate limit)
- Provide user-friendly messages
- Enable retry logic
- Consistent error handling across app

**Consequences**: `AppError` enum, `ErrorToast` component, structured error messages.

---

## ADR-006: Translation with Apple Translation framework

**Date**: 2026-05-28

**Context**: Need inline translation for Japanese/Chinese content.

**Decision**: Use Apple's `TranslationSession` for inline translation.

**Rationale**:
- Native Apple framework, no third-party dependency
- Supports inline translation (no sheet popup)
- Language detection and target language configuration
- Works on macOS 14.4+ and iOS 17+

**Consequences**: `InlineTranslateSection`, `TranslationLanguageResolver`, bilingual/immersive modes.

---

## ADR-007: Navigation history with browser-style back/forward

**Date**: 2026-05-28

**Context**: Users lose browsing context when viewing artworks.

**Decision**: Implement browser-style navigation history with cursor.

**Rationale**:
- Familiar UX pattern (Cmd+[ / Cmd+])
- 100-entry cap with oldest-first eviction
- Deduplication of consecutive same-ID entries
- History clears on context change (route switch)

**Consequences**: `NavigationHistory` struct, `navigateToArtwork()`, `navigateBack()`/`navigateForward()`.

---

## ADR-008: Adaptive action row for detail views

**Date**: 2026-05-28

**Context**: Action buttons in detail views take too much space.

**Decision**: Use `GeometryReader` to measure width and promote buttons adaptively.

**Rationale**:
- More buttons visible on wider screens
- Icon-only buttons with `.help()` tooltips
- Stateful buttons keep text for context
- Consistent pattern across artwork, novel, and manga views

**Consequences**: `AdaptiveActionRow`, width-based button promotion, `.labelStyle(.iconOnly)`.

---

## ADR-009: Double-page book layout for readers

**Date**: 2026-05-28

**Context**: Wide screens waste space with single-page layout.

**Decision**: Implement two-page book spread for readers.

**Rationale**:
- More natural reading experience on wide screens
- Spine divider between pages
- Automatic activation on wide screens (> 1200pt)
- Manual toggle for user preference

**Consequences**: `ArtworkDoublePageReader`, `NovelReadingMode.doublePage`, spine divider.

---

## ADR-010: Touch target sizing for iPadOS

**Date**: 2026-05-28

**Context**: iPadOS requires 44pt minimum touch targets.

**Decision**: Use `TouchTargetModifier` for all interactive elements.

**Rationale**:
- Apple HIG requires 44pt minimum
- No-op on macOS (pointer precision is higher)
- Applied to icon-only buttons and action strips
- Ensures touch usability on iPad

**Consequences**: `TouchTargetModifier`, `.touchTarget()` extension.
