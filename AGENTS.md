# AGENTS.md

This file is the working contract for agents editing KeiPix. It applies to the
whole repository unless a deeper `AGENTS.md` overrides it.

## Project Direction

KeiPix is a native Swift Pixiv client for Apple OS 26+. The current product
direction is **AppKit/UIKit first, SwiftUI as glue**.

- Use AppKit/UIKit for hot interaction paths: waterfall feeds, native
  collection/list reuse, image scroll/zoom, long text, search fields, menus,
  drag and drop, pointer/trackpad/touch gestures, and platform window behavior.
- Use SwiftUI for state wiring, app chrome, navigation shells, settings
  composition, overlays, and lightweight surfaces.
- Keep macOS, iPadOS, and iOS behavior platform-specific. Do not force one
  presentation model across all devices when the available space and interaction
  model differ.
- Treat Apple OS 26 visual polish as part of the product requirement, not as
  optional decoration.

## Repository Map

- `Sources/KeiPix/App`: app entry points, app delegate, menu/dock wiring.
- `Sources/KeiPix/Models`: routing, Pixiv models, reader state, QA models.
- `Sources/KeiPix/Services`: Pixiv API, session, image pipeline, update checks,
  reverse image search, decoding/export services.
- `Sources/KeiPix/Stores`: `KeiPixStore` and domain-specific store extensions.
- `Sources/KeiPix/Support`: platform bridges and reusable helpers. Native
  AppKit/UIKit representables belong here.
- `Sources/KeiPix/Views`: SwiftUI shells and composed screens around the native
  hot paths.
- `Sources/KeiPix/Resources`: string catalogs and bundled resources.
- `Tests/KeiPixTests`: model, parser, UI-boundary, QA, route, and regression
  tests.
- `project.yml`: XcodeGen source of truth.
- `KeiPix.xcodeproj`: generated from `project.yml`; do not hand-edit it.

## Naming And Organization

- Native bridge types should make their platform role obvious. Prefer names
  like `Native<Surface>CollectionView`, `Native<Surface>ListView`,
  `<Surface>NSView`, `<Surface>UIView`, or `<Surface>Representable`.
- SwiftUI screens should use stable product names such as `ArtworkDetailView`,
  `PixivisionReaderView`, or `GeneralSettingsPage`. Avoid vague names like
  `NewView`, `ModernCard`, or `BetterSheet`.
- Settings pages live under `Sources/KeiPix/Views/Settings` and use
  `<Category>SettingsPage`. If a category is user-selectable, update
  `SettingsCategory`, search terms, compact shortcuts when relevant, and
  `NativeBoundaryTests/settingsWorkspaceUsesAdaptiveOS26Layout`.
- Parser/model tests should follow the domain name, for example
  `PixivisionArticleParserTests`, `PixivWebProfileParserTests`, or
  `BookmarkFeedOptionsTests`.
- Visual QA surfaces use lowercase kebab-case (`settings-window`,
  `creator-profile`, `artwork-detail-social`). Keep the launch flag,
  `VisualQASurface` raw value, manifest surface, and capture command aligned.
- String catalogs use PascalCase file stems that match the domain table:
  `Navigation.xcstrings`, `Settings.xcstrings`, `Reader.xcstrings`,
  `Pixivision.xcstrings`. Add the matching `L10nTable` constant.
- Store extensions should stay domain-focused:
  `KeiPixStore+Search.swift`, `KeiPixStore+Downloads.swift`,
  `KeiPixStore+PixivLinks.swift`, etc. Do not make a miscellaneous extension
  that becomes a second giant store.
- Tests that assert architecture boundaries belong in `NativeBoundaryTests`;
  tests that assert visible QA evidence belongs in `VisualQAEvidenceTests`;
  tests for pure models/parsers should stay close to the model name.

## Before Editing

1. Check `git status --short` first. The worktree may contain user changes; do
   not revert or sweep unrelated changes into your work.
2. Read the nearest existing implementation before adding a new abstraction.
   KeiPix already has many shared native bridges and OS 26 surface components.
3. For broad UI/platform work, classify the surface and plan before editing.
   High-value hot paths should move toward AppKit/UIKit ownership; low-risk
   forms and settings pages can remain SwiftUI unless profiling or UX evidence
   says otherwise.
4. Keep changes scoped to one theme. The maintainer prefers segmented commits
   that are easy to revert and audit.

## Implementation Workflow

Use this order for non-trivial feature work or bug fixes:

1. Identify the surface family and current owner files before editing.
2. Decide whether the work is product behavior, backend/API behavior, native
   platform behavior, or visual polish. Pick reference sources and validation
   checks from the tables below.
3. Add or update focused tests first when the behavior is model/API/parser
   driven. For UI-only work, identify the visual QA surface before editing.
4. Implement in the smallest layer that owns the behavior. Avoid adding UI
   state to views when it belongs in `KeiPixStore`, and avoid adding service
   logic to SwiftUI bodies.
5. Validate with focused tests, then broader tests/builds. Use real simulator
   screenshots for user-visible iPadOS/iOS/macOS layout changes.
6. Stage only the files for this phase and commit with one focused message.

## Reference Research

For new Pixiv-facing features or fixes in backend/API behavior, research more
than one source before designing the Swift implementation.

- For Apple-platform UI, layout, gestures, windowing, accessibility, OS 26
  Liquid Glass, AppKit, UIKit, and SwiftUI behavior, consult current Apple
  Developer documentation before making non-trivial design or API choices.
  Treat Apple docs and Human Interface Guidelines as the primary design
  baseline, then adapt Pixiv Web, Pixez, or Pixes behavior into native Apple
  controls instead of copying their layout directly.
- Preferred behavior references:
  - Pixez: `https://github.com/Notsfsssf/pixez-flutter` (GPL-3.0; behavior reference only)
  - Pixes: `https://github.com/pixes-app/pixes` (MIT; behavior reference only)
  - Pixiv Web, especially when app APIs do not expose a feature directly.
- Use those references to understand product behavior, request shape, edge
  cases, and user expectations. Do **not** copy implementation structure, UI
  layout, Dart, Kotlin, generated code, or licensing-sensitive source into
  KeiPix.
- License nuance matters: Pixez is GPL-3.0 and Pixes is MIT-licensed, but
  KeiPix's policy is the same for both reference clients: understand behavior,
  then re-design and reimplement it in native Swift for Apple platforms.
- Combine references instead of treating any single client as canonical. If
  Pixez, Pixes, and Pixiv Web disagree, document the tradeoff in code comments,
  tests, or the final handoff.
- Re-design for Apple platforms after research: map the feature to AppKit/UIKit
  controls, Apple OS 26 layout, native gestures, keyboard shortcuts, menus,
  accessibility, and platform-specific presentation.
- Prefer official Pixiv/API behavior that can be validated locally. When Pixiv
  Web is the only source, isolate parsing/scraping logic, add parser tests with
  fixtures, and make failure states visible and non-destructive.
- If Chrome/Safari logged-in Pixiv Web is needed for research, keep that step
  separate from implementation and report what was observed rather than baking
  brittle assumptions into UI code.

### Reference Priority By Task

| Task type | Preferred order | Notes |
| --- | --- | --- |
| App API already exists in KeiPix | Existing KeiPix service/store, Pixez/Pixes behavior, Pixiv Web sanity check | Preserve local architecture first; use references to catch missing edge cases. |
| Pixiv Web-only behavior | Pixiv Web, Pixez/Pixes fallbacks, local Swift parser model | Keep parsing isolated and tested; surface graceful failure when markup changes. |
| New feature UX | Apple platform patterns, existing KeiPix surfaces, Pixiv Web/Pixez/Pixes behavior | Do not clone mobile/web layouts. Translate the workflow into native Apple controls. |
| Auth/session/token behavior | Existing KeiPix session model, Pixiv API behavior, Pixez/Pixes diagnostics | Treat tokens as secrets and avoid speculative login-state hacks. |
| Safety or remote write behavior | KeiPix safety policy, Pixiv API behavior, Pixiv Web confirmation patterns | Remote writes require visible user intent, confirmation, and a rollback or explicit no-rollback explanation. |
| Reader/feed performance | Existing native bridges, Apple collection/scroll/text APIs, reference clients only for behavior | Performance hot paths should end in AppKit/UIKit ownership. |

## Native Boundary Rules

- Reuse existing bridge types where possible:
  `NativeGalleryCollectionView`, `NativeArtworkShelfCollectionView`,
  `NativeAdaptiveGridCollectionView`, `NativeDownloadQueueListView`,
  `NativeBrowsingHistoryCollectionView`, `NativeBookmarkTagCollectionView`,
  `NativeCreatorPreviewCollectionView`, `NativeNovelTextPageView`,
  `ImageScrollView`, `iPadImageScrollView`, `NativeInlineFilterField`,
  `SearchFieldNSView`, `NativeToolbarMenuButton`, `ReaderGestureBridge`,
  `TrackpadEventBridge`, `DragDropNSView`, and `EnhancedMenuNSView`.
- Do not reintroduce high-frequency scrolling, zooming, text rendering, search,
  or pointer/menu behavior as large pure-SwiftUI implementations when a native
  bridge exists or is the appropriate next boundary.
- Put new AppKit/UIKit wrappers in `Sources/KeiPix/Support`. Keep their public
  SwiftUI-facing API small and state-driven.
- Use `#if os(macOS)` / `#if os(iOS)` around platform-specific code. Avoid
  unconditional `import AppKit` or macOS-only APIs in shared iOS/iPadOS paths.
- Reference projects may be used only for behavior research. Do not copy
  Flutter/Dart/Kotlin source or reference-client implementation paths into
  `Sources/KeiPix`; `NativeBoundaryTests` protects this boundary.

## Platform Layout Guidance

- macOS: treat sidebar, waterfall/feed, and detail/reader as separate workspace
  regions. Sidebar visibility should usually be user-controlled, not hidden as a
  side effect of opening content.
- iPadOS: optimize for adaptive two-region browsing. Detail/reader panels can
  be shown or hidden to give the feed room, especially in portrait and Split
  View.
- iOS: prefer compact, direct actions and reader entry points. Avoid hiding
  essential navigation behind desktop assumptions.
- Pointer, trackpad, touch, and gesture behavior all matter on iPadOS and iOS
  because of Magic Keyboard, pointing devices, and iPhone Mirroring.

## Localization

- User-visible strings go through `Sources/KeiPix/Support/L10n.swift`.
- Add matching entries to the appropriate `.xcstrings` catalog for `en`,
  `zh-Hans`, `zh-Hant`, and `ja`.
- Current catalogs include `Localizable.xcstrings` and `Navigation.xcstrings`.
  Prefer the right existing catalog; when a domain grows too large, split by
  business area instead of continuing to bloat `Localizable.xcstrings`.
- Avoid broad JSON rewrites of `.xcstrings`. Use targeted edits and always run:

```bash
jq empty Sources/KeiPix/Resources/Localizable.xcstrings
```

- Xcode paths compile string catalogs directly. SwiftPM relies on the
  `XCStringsBuilder` plugin declared in `Package.swift`.

### Catalog Split Rules

- Keep `Localizable.xcstrings` for generic app-wide copy and legacy keys.
- Keep `Navigation.xcstrings` for sidebar, tabs, routing labels, navigation
  menus, shortcut labels, and page-status chrome.
- If a domain gains many keys, create a new catalog such as
  `Settings.xcstrings`, `Reader.xcstrings`, `Artwork.xcstrings`,
  `Pixivision.xcstrings`, or `Profile.xcstrings`.
- When adding a new catalog, update `L10n.swift` with an explicit table entry
  instead of relying on accidental `Localizable` lookup, then validate both
  SwiftPM and Xcode builds.
- Tests should guard important visible copy so a key added to `L10n.swift` does
  not silently miss the catalog and fall back to English in localized UI.

### Catalog Migration Order

1. Keep tiny or shared copy in `Localizable.xcstrings`.
2. Move navigation and route chrome to `Navigation.xcstrings`.
3. When a surface grows, create the domain catalog before adding another large
   batch of keys. Suggested first splits: `Settings.xcstrings`,
   `Reader.xcstrings`, `Pixivision.xcstrings`, `Artwork.xcstrings`, then
   `Profile.xcstrings`.
4. Add a matching `L10nTable` constant and call `text("Key", table: ...)`.
5. Add or extend a focused test that checks representative keys and translated
   values.
6. Validate with `jq empty`, focused tests, `swift test`, and one Xcode build
   when a new catalog file is introduced.

## Build And Test

Use the smallest focused check first, then broaden before handoff.

Common checks:

```bash
swift test --filter NativeBoundaryTests
swift test
git diff --check
```

String catalog changes:

```bash
jq empty Sources/KeiPix/Resources/Localizable.xcstrings
swift test --filter AboutViewTests
swift test
```

macOS app:

```bash
./script/build_and_run.sh --verify
xcodebuild -quiet -project KeiPix.xcodeproj -scheme KeiPix \
  -configuration Debug -destination 'platform=macOS' \
  -derivedDataPath /tmp/KeiPix-macOS-DerivedData \
  CODE_SIGNING_ALLOWED=NO build
```

iOS and iPadOS:

```bash
./script/build_and_run_ios.sh --verify
./script/build_and_run_ipados.sh --verify
xcodebuild -quiet -project KeiPix.xcodeproj -scheme 'KeiPix iOS' \
  -configuration Debug -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/KeiPix-iOS-DerivedData \
  CODE_SIGNING_ALLOWED=NO build
xcodebuild -quiet -project KeiPix.xcodeproj -scheme 'KeiPix iPadOS' \
  -configuration Debug -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/KeiPix-iPadOS-DerivedData \
  CODE_SIGNING_ALLOWED=NO build
```

When using Simulator while another worktree is also validating, use a dedicated
device and pass `KEIPIX_IOS_SIMULATOR_ID` / `KEIPIX_IPADOS_SIMULATOR_ID` or set
XcodeBuildMCP session defaults explicitly. Do not trust screenshots from a
shared or ambiguous simulator.

### Recommended Validation Matrix

| Change type | Minimum checks |
| --- | --- |
| Model/parser/API behavior | Focused unit tests for the model/parser plus `swift test` |
| Pixiv Web parsing | Fixture parser tests, failure-state test, and one live/web observation when safe |
| Native bridge or hot UI path | Focused `NativeBoundaryTests`, `swift test`, platform Xcode build, and visual QA |
| iPadOS/iOS layout | Generic iOS/iPadOS build plus real Simulator screenshot/snapshot on the target device class |
| macOS workspace/window behavior | macOS Xcode build plus `./script/build_and_run.sh --verify` or a matching visual QA surface |
| Localization | `jq empty`, focused L10n/surface tests, `swift test`, and a localized Simulator/app screenshot when visible |
| XcodeGen/project metadata | `xcodegen generate`, relevant Xcode build, and careful diff review of generated project changes |
| Remote write/safety behavior | Unit tests, explicit authorization UI, undo/reversal path, and documentation in the handoff |

### Account-State Validation

Prefer deterministic sample data first, then use signed-out and real-account
simulators only when the task truly needs them.

| State | Use for | Rules |
| --- | --- | --- |
| Visual QA sample data | Layout, animation, empty/loading/error state, non-network UI | Must not read or mutate real account data. |
| Signed-out simulator | Login gates, guest previews, shared signed-out state, unauthenticated route safety | Reuse `PixivSignedOutStateView`; do not hand-roll page-specific signed-out empty states. |
| Real logged-in simulator | Authenticated feed/API regressions, user-specific Pixiv Web parity, token import/export, session refresh | Use a dedicated KeiPix simulator/device. Report the device name/UDID and avoid remote writes. |
| Mutable Action QA | Intentional remote-write testing only | Requires explicit authorization UI and a reversible path where Pixiv allows one. |

When another worktree is using Simulator, do not share devices. Create or select
an isolated KeiPix simulator and keep screenshots tied to that UDID. If the app
state looks wrong after a successful build, suspect stale simulator state,
LaunchServices drift, or a different bundle before assuming the source change
failed.

## Visual QA

UI, layout, reader, feed, sheet, menu, localization, or platform-adaptive work
needs visual evidence, not just source inspection.

Useful launch surfaces:

```bash
./script/build_and_run.sh --visual-qa-gallery-three-column
./script/build_and_run.sh --visual-qa-settings-window
./script/build_and_run.sh --visual-qa-creator-profile
./script/capture_visual_qa.sh gallery-three-column
```

For iPadOS/iOS work, use Simulator screenshots or `snapshot_ui` after
navigation, rotation, or layout changes. Verify both the route and the actual
device name/UDID when multiple simulators are running.

### New Visual QA Surface Protocol

Add a new `--visual-qa-*` surface when a new major view, sheet, reader mode,
menu family, or adaptive layout becomes important enough that screenshots should
catch regressions.

1. Add a case to `VisualQALaunchArgument` with a kebab-case flag.
2. Add or reuse a `VisualQASurface` case with the same surface name.
3. Route the launch argument in the relevant app shell or view.
4. Add deterministic sample data in `VisualQASampleData` or the nearest fixture
   helper. Prefer wide, narrow, empty, loading, and sensitive-content cases when
   the surface can display them.
5. Update `script/build_and_run.sh` usage/case entries if the macOS launcher
   should expose the surface.
6. Extend `VisualQAEvidenceTests` and, when relevant, `NativeBoundaryTests`.
7. Capture evidence with `script/capture_visual_qa.sh <surface>` or simulator
   screenshots for iOS/iPadOS.

Surface names should be stable, lowercase, and kebab-case, for example
`creator-profile`, `settings-window`, or `artwork-detail-social`.

### Surface-Specific Starting Points

| Surface family | Start with |
| --- | --- |
| Feed/waterfall/gallery | `GalleryView`, `GalleryFeedHeaderView`, `NativeGalleryCollectionView`, `ArtworkMasonryPresentation`, `GallerySelectionTests` |
| Artwork detail/reader | `ArtworkDetailView`, `ArtworkReaderView`, `ArtworkReaderWindowView`, `ImageScrollView`, `ReaderPagePresentationTests` |
| Novel reader | `NovelDetailView`, `NovelReaderView`, `NativeNovelTextPageView`, `NovelTextTokenizerTests` |
| Search/saved search/tags | `Stores/KeiPixStore+Search.swift`, `SearchFiltersView`, `SavedSearchesView`, `NativeInlineFilterField` |
| Creator/profile sheets | `UserProfileSheet`, `UserProfileSheetHeader`, `UserProfileCreatorTagsSection`, `NativeCreatorPreviewCollectionView` |
| Library surfaces | `LibrarySurfaceComponents.swift`, `BookmarkTagsView`, `WatchLaterView`, `MangaWatchlistView`, `DownloadQueueView` |
| Settings/About | `SettingsView`, `Sources/KeiPix/Views/Settings/*`, `AboutView`, `AboutViewTests`, `NativeBoundaryTests/settingsWorkspaceUsesAdaptiveOS26Layout` |
| Pixivision/Spotlight | `PixivisionReaderView`, `SpotlightView`, `PixivisionArticleParserTests`, `PixivisionArticleListParserTests` |

### Common Feature Checklists

New settings category:

1. Add `SettingsCategory` case, title, icon, and search terms.
2. Add `<Category>SettingsPage` using `OS26SettingsPage` and
   `OS26SettingsSection`.
3. Wire `SettingsView.detail` and compact shortcut behavior if the category is
   high frequency.
4. Add localized strings and focused tests.
5. Validate compact iPad/iPhone layout and macOS split-view behavior.

New Pixiv Web-backed feature:

1. Capture or document the Pixiv Web behavior and any Pixez/Pixes comparison.
2. Add a Swift model/parser with fixtures before wiring UI.
3. Keep network/parsing code out of SwiftUI views.
4. Provide visible loading, empty, failure, and signed-out states.
5. Add real-account validation only if sample fixtures cannot prove the chain.

New native bridge:

1. Define a small SwiftUI-facing wrapper in `Support`.
2. Hide AppKit/UIKit implementation details behind platform branches.
3. Keep updates diffable and identity-stable.
4. Add `NativeBoundaryTests` coverage so future changes do not regress to a
   pure SwiftUI hot path.
5. Exercise the bridge in at least one visual QA or simulator flow.

## Generated Files And Project Updates

- Edit `project.yml`, plist templates, scripts, or sources; regenerate the Xcode
  project with `xcodegen generate` when needed.
- Do not manually edit `KeiPix.xcodeproj/project.pbxproj`.
- Avoid committing generated project churn unless the task explicitly changes
  targets, schemes, build settings, resources, or plist wiring.
- If XcodeGen output changes unexpectedly, inspect the diff carefully before
  staging.

## Versioning

- `Config/AppVersion.xcconfig` is the human-edited source for
  `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION`.
- Use `./script/set_app_version.sh <marketing-version> <build-number>` when
  changing app versions so `Config/AppVersion.xcconfig` and `project.yml` stay
  aligned.
- Run `./script/check_version_consistency.sh` after version, plist, packaging,
  CI, release-update, backup, About, or User-Agent changes.
- Runtime code should read bundle metadata through `AppVersion.current`. Do not
  reintroduce ad hoc `Bundle.main` version reads or hard-coded `KeiPix/1.0`
  User-Agent strings.

## UI And Interaction Style

- Prefer OS 26 glass and native control patterns already present in
  `LibrarySurfaceComponents.swift`, `Glass.swift`, sheet chrome helpers, and
  native toolbar menu wrappers.
- Avoid legacy grouped-form or bordered-card styling when the surrounding
  surface has moved to OS 26 chrome.
- Menu actions should be legible: icon-only controls need tooltips/help and
  accessibility labels; dropdown/menu rows should expose current selections
  when that reduces extra taps.
- Keep loading, empty, signed-out, and error states visually consistent across
  related surfaces instead of patching each page separately.
- For search, saved search, search author, tag search, and popular-tag pages,
  treat them as one UX family and keep clearing/filter state discoverable.

## Safety And Privacy

- Remote Pixiv write paths must be explicit, visible, and gated. Prefer local
  reversible actions by default.
- Token export/import and account actions should be confirmation-gated and must
  treat refresh tokens like passwords.
- Privacy mode, muted content, AI/R-18/R-18G controls, and signed-out states are
  user-facing safety features. Do not bypass them in UI shortcuts or QA samples.

## Git Hygiene

- Keep commits phase-sized and topic-focused. Do not mix unrelated UI,
  localization, generated project, and docs changes unless the task requires it.
- Prefer conventional commit prefixes from `docs/contributing.md` for public
  commits (`feat:`, `fix:`, `refactor:`, `test:`, `docs:`, `build:`, `chore:`).
- Before final handoff, report the checks that actually ran. If a simulator,
  build, or test could not run, say so directly.
