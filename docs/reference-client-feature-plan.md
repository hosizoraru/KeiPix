# Reference Client Feature Plan

This plan tracks KeiPix features worth absorbing from the four local reference
clients in `.tmp`: Pixeval, Pixiv-Nginx, pixes, and pixez-flutter. These
projects are behavior references only. KeiPix remains native Swift, with
AppKit/UIKit owning hot paths and SwiftUI used for app chrome, state wiring,
navigation, and lightweight surfaces.

## Product Rules

| Rule | Decision |
| --- | --- |
| Native boundary | Keep waterfall feeds, long lists, readers, text entry, menus, and hot scrolling on AppKit/UIKit bridges when they become performance-sensitive. |
| SwiftUI role | Use SwiftUI for shell composition, route selection, sheets, settings, async state, and platform-adaptive chrome. |
| Reference-client use | Read behavior, endpoints, edge cases, and user expectations; do not copy GPL/Flutter/Avalonia implementation or layout. |
| Platform split | iOS and portrait iPad stay compact and direct; landscape iPad and macOS can expose fuller inspectors, rails, and secondary panes. |
| Apple baseline | Prefer Apple HIG, AppKit, UIKit, collection-view/list, sheet, menu, and privacy patterns before adapting Pixiv Web or third-party UI. |
| Validation | Each implementation phase needs focused tests first, then the smallest relevant build, then visual Simulator/Device Hub evidence for visible iOS/iPadOS changes. |

## Reference Findings

| Area | Status | Reference signal | KeiPix state | Decision |
| --- | --- | --- | --- | --- |
| Novel comments | Done | Pixeval/Mako and pixez-flutter expose novel comments, replies, posting, deletion, and stamp comments. | KeiPix now loads, displays, replies to, posts normal comments, deletes authored comments, and posts stamp comments through the shared comment surface. | Keep as a shared artwork/novel surface; continue improving the native list container without splitting artwork and novel comments. |
| Comment actions | Done | Pixeval exposes delete and stamp variants for illustration and novel comments. | KeiPix now exposes authored-comment deletion and stamp sending for illustration and novel comments. | Keep remote writes explicit; do not live-test destructive actions without authorization. |
| MyPixiv | Done | Pixeval exposes user, illustration, and novel MyPixiv surfaces. pixez-flutter displays total MyPixiv users. | KeiPix now has MyPixiv API/store entry points, profile MyPixiv counts, profile menu entry points, and dedicated artwork/novel feed routes. | Treat the first MyPixiv slice as complete; later polish can focus on richer navigation affordances if real-account QA exposes gaps. |
| Activity feed | Partial | Pixeval has a feed surface for social activity signals, including bookmark, follow, and posted-work activity copy. | KeiPix now has a parser-first Pixiv Web activity foundation with stacc URL construction, signed-in Web session fetch boundary, embedded JSON parsing, HTML fallback parsing, next-page handling, and fixture coverage. | Keep the user-visible route gated until signed-in Web session failure states and native AppKit/UIKit list presentation are complete. |
| Remote search options | Done | Pixeval exposes `/v1/search/options`, and Pixeval's search paths use the same match/sort/AI/date vocabulary plus novel-specific language, genre, and length knobs. | KeiPix now decodes and caches Pixiv remote search metadata, uses server-provided bookmark ranges as search filter presets, routes existing search filters into novel search query/local filtering, maps remote novel language/genre options into compact menus, applies Pixiv's safe novel text-length presets, and sends supported illustration `content_type` filters. | Keep Pixiv tool metadata as research-only until a confirmed app-api query parameter is observed. |
| Download templates | Done for first slices | Pixeval has conditional macro paths. | KeiPix has placeholder templates, previews, unknown-token warnings, a native token insertion menu backed by the renderer's documented token catalog, and documented template presets. | Keep growing this as a native editor: token insertion and presets are done; conditional editing can come later without copying macro syntax. |
| Novel export | Done | Pixeval supports HTML, Markdown, and original text. | KeiPix now supports TXT, Markdown, and static HTML export. | Consider EPUB/PDF later only if the native reader/export workflow needs them. |
| Reader tools | Done | Pixeval has image viewer modes, page preview slider, rotate/mirror tools. | KeiPix now has native readers, paging, continuous/double page, zoom, basic slider, native macOS/iPad landscape filmstrip rail, and a shared rotate/mirror command model used by detail and standalone readers. | Keep future reader work scoped to explicit polish slices instead of reopening the completed filmstrip and transform foundations. |
| Dashboard cards | Planned | Pixeval supports configurable home cards, including single work/novel/user cards. | KeiPix has section visibility customization. | Evolve discovery dashboard later with native card presets. |
| Network/direct connect | Done for diagnostics | Pixeval/Pixiv-Nginx provide domain fronting, IP sets, mirror/proxy patterns. | KeiPix has app-level system/direct/manual proxy and now reports host-by-host Pixiv reachability for App API, OAuth, Web, and image CDN. | Keep diagnostics read-only and platform-networking based; do not bundle MITM/self-signed proxy. |
| Widget-style surfaces | Planned | pixez-flutter has Android widgets. | KeiPix has `WidgetDataProvider` but no WidgetKit target. | Low priority; track for future WidgetKit/live surface work. |
| Search filter memory | Done | pixez-flutter remembers search sort, target, AI, and ugoira options per search result context. | KeiPix now keeps separate search option profiles for all artwork, illustrations, manga, and novels; saved presets restore through the same profile chain. | Keep this as lightweight per-search-kind memory, not a replacement for saved searches or the in-feed client filter. |
| Novel follow and bookmarks | Done | pixez-flutter exposes novel follow, public/private novel bookmarks, novel ranking, novel watchlist, and series pages as one novel workflow. | KeiPix now has novel recommended, latest, ranking, search, followed-creator feed, watchlist, bookmark actions, novel bookmark tag suggestions, series chapter sheets, and related navigation. | Treat the reference-client novel workflow parity slice as complete; track future novel polish as narrower rows instead of keeping this goal open. |
| Reader page preview | Done | Pixeval has a page preview slider/filmstrip for image readers. | KeiPix now has native readers, page restore, paging modes, a tested filmstrip presentation model, and a native collection-backed rail visible on macOS and iPad landscape while staying hidden on phone/portrait iPad. | Keep future reader preview polish scoped to explicit follow-up slices rather than reopening this rail slice. |
| Work subscriptions | Done for first native tracking | Pixeval can subscribe to creator work updates and queue sync. | KeiPix already tracks illustration, manga, and novel subscription buckets, migrates legacy state, exposes per-kind controls, and opens subscription cards into matching creator feeds. | Treat the first native subscription slice as complete; future work should be polish, not a parallel feature. |
| Local filtering DSL | Done for native editor slice | Pixeval has a rich work filter language for title, author, tag, ratio, date, R-18, AI, GIF, bookmark, and index checks. | KeiPix now has `ClientFilterDSL`, compact bottom-bar in-feed filtering, structured advanced-filter models, wide-header quick presets, and a native text-field typed editor for tag/title/creator, bookmark/view/page ranges, content flags, ugoira, bookmark state, ratio, and preserved passthrough terms. | Treat the current native editor goal as closed; if date or page-index predicates become useful, track them as separate narrow DSL/parser polish rows instead of keeping this row open. |

## 2026-06-14 Scan Refresh

This refresh cross-checked the reference clients against the current KeiPix
source tree after the June novel, collection, Pixivision, search, download, and
settings work. Items already absorbed stay in the main findings table above.
The rows below are the remaining gaps or polish opportunities that still look
worth native Swift work.

| Priority | Status | Opportunity | Reference signal | Current KeiPix gap | Native implementation direction |
| --- | --- | --- | --- | --- | --- |
| P0 | Done | Latest novel feed | Pixeval exposes `NovelNewEngine` and the app API path `/v1/novel/new`. | KeiPix now has a dedicated `.novelLatest` route backed by `/v1/novel/new`, reachable from the sidebar, discovery dashboard novel group, and compact iPhone novel menu. | Keep this slice closed; future novel feed work should be tracked as narrower polish or separate API rows. |
| P0 | Done | Novel bookmark tag suggestions | Pixeval exposes `/v1/user/bookmark-tags/novel`. | KeiPix now has the novel bookmark tag endpoint, Store hook, and lightweight novel bookmark editor wired from gallery, detail, and reader surfaces. | Keep novel suggestions on `/v1/user/bookmark-tags/novel`; do not regress to artwork-only bookmark tag state. |
| P0 | Done | Native reader filmstrip rail | Pixeval has a page preview slider/filmstrip for image readers. | The presentation model, native collection bridge, macOS reader-window QA route, and iPadOS reader-sheet QA route are complete and validated. | Keep `NativeReaderFilmstripCollectionView` under `Support` with UIKit/AppKit collection ownership; mount it only for landscape iPad and macOS when `ReaderFilmstripPresentation` is visible. |
| P1 | Done | Cross-page batch download | pixes can fetch successive `nextUrl` pages up to a user-selected maximum before enqueueing downloads. | KeiPix now has an explicit loaded-feed batch download plan that can gather bounded following `nextURL` pages before queueing, while selected-work batch downloads stay local to the current selection. | Keep cross-page fetching opt-in, capped, and visible through progress/loading feedback; do not silently request remote pages from selected-work actions. |
| P1 | Partial | Pixiv activity feed | Pixeval exposes social feed copy for followed users' posted works, bookmarks, and followed-user actions. | KeiPix now has `PixivActivityFeedParser`, `PixivActivityPage`, `PixivActivityItem`, `/stacc` URL construction, and a Web-session-only API fetch boundary, but no native route or visual surface yet. | Next slice should add signed-in empty/error state modeling and an AppKit/UIKit-backed activity list before exposing this from Discover. |
| P1 | Done | Reader rotate/mirror tools | Pixeval image viewer includes rotation and mirror tools. | KeiPix now uses a shared `ReaderImageTransform` command model for rotate and mirror state, applies transforms at the image layer, and exposes the same transform menu in detail and standalone readers. | Keep transform commands in the shared reader model; future work should focus on finer image-layout polish only if real-reader QA shows a gap. |
| P1 | Done | Advanced local filter editor | Pixeval's filter language can target title, author, tag, ratio, date, R-18/R-18G, AI, GIF, bookmark count, and page index. | KeiPix now has a wide-header advanced editor that round-trips existing filter queries into typed fields, native AppKit/UIKit text entry, numeric ranges, include/exclude flag menus, aspect-ratio selection, and passthrough terms while keeping the iPhone toolbar lightweight. | Keep future date/index predicates as separate narrow filter DSL polish rather than reopening the completed typed-editor slice. |
| P2 | Planned | Configurable discovery dashboard cards | Pixeval supports configurable home cards and card sources. | KeiPix has a discovery dashboard and bottom-tab customization, but dashboard cards are not user-composable. | Add native card presets and layout editing later, favoring direct toggles on iPhone and fuller drag/reorder controls on iPad landscape/macOS. |
| P2 | Partial | Download task history polish | pixez-flutter exposes task history, status filtering, compact/image rows, and periodic running-state refresh. | KeiPix has a stronger queue, throughput, retry, filtering/search/sort, and Spotlight integration, but completed task history can still become more inspectable. | Extend the existing native download queue/history model instead of creating a parallel task page. |

## Completion Semantics

| Status | Meaning |
| --- | --- |
| Done | Implemented, tested, and validated with the checks appropriate to the surface. |
| Done for first slices | The core feature landed and is no longer a blocking gap; later rows should describe polish or explicit next slices. |
| Partial | KeiPix already covers a meaningful subset, but a clearly named gap remains. |
| In progress | Code or tests exist in the worktree, but the slice is not complete until final tests/builds and required visual evidence pass. |
| Planned | Confirmed reference-client opportunity with no completed KeiPix implementation yet. |

## Do Not Copy Directly

| Reference pattern | Reason | Native KeiPix translation |
| --- | --- | --- |
| Pixiv-Nginx self-signed certificate and MITM proxy setup | This is too risky for a native client and conflicts with privacy expectations. | Host-by-host diagnostics, proxy status, and clear troubleshooting text. |
| pixez-flutter certificate bypass / SNI bypass implementation | It is a network workaround, not a safe default client behavior. | Advanced diagnostics only; keep normal requests on platform networking. |
| Flutter/Avalonia layout and implementation structure | Reference projects are behavior references only. | Rebuild workflows with Swift models, AppKit/UIKit hot paths, and SwiftUI shells. |
| Desktop-style filter DSL as the iPhone default | It would overload small-screen input and conflict with compact feed filtering. | Use chips/dropdowns on iPhone; reserve advanced editors for wider layouts. |

## Phase Roadmap

| Phase | Status | Scope | Implementation shape | Evidence |
| --- | --- | --- | --- | --- |
| 1 | Done | Novel comment read/post path | Completed API, Store, and detail UI wiring for `/v3/novel/comments`, `/v2/novel/comment/replies`, and `/v1/novel/comment/add`. | Existing endpoint, boundary, Visual QA fixture, and full Swift tests. |
| 2 | Done | Comment delete actions | Completed delete endpoints for illustration and novel comments, plus a destructive row action scoped to comments authored by the signed-in user. | Endpoint/form tests, authored-by-current-user tests, comment UI boundary tests, no live remote delete unless explicitly authorized. |
| 3 | Done | Stamp comments | Completed stamp send support for illustration and novel comments after delete flow is stable. | Model/API tests plus visual proof that stamp comments display and send affordance is clear. |
| 4 | Done | Native comment list | Completed the first top-level comment list container move toward AppKit/UIKit ownership while SwiftUI remains row-hosting glue. | Native boundary tests, macOS Visual QA, and iOS/iPadOS builds. |
| 5 | Done | MyPixiv | Completed models/endpoints/routes for MyPixiv users, illustration feed, and novel feed; surfaced counts and route entry points in user profile. | Route coverage tests, API query tests, profile native-boundary checks, platform builds, and macOS creator-profile Visual QA. |
| 6 | Done | Search options | Fetched and cached `/v1/search/options`; mapped server-provided bookmark ranges, novel query/local filters, remote novel language/genre menus, novel text-length presets, and supported artwork `content_type` query values. | Parser/model tests, search option tests, novel query/filter tests, search UI boundary tests, and search UI screenshots when the visible pane changes further. |
| 7 | Done for filmstrip rail slice | Reader/export polish | Completed novel HTML export, filmstrip presentation model, and native reader filmstrip rail. Reader rotate/mirror unification remains tracked as its own P1 row above. | Export formatter tests, `ReaderPagePresentationTests`, `NativeBoundaryTests/artworkReaderFilmstripUsesNativeCollectionRail`, full `swift test`, macOS/iOS/iPadOS builds, macOS `reader-window` Visual QA, and iPadOS 27 Device Hub screenshot. |
| 8 | Done | Network diagnostics | Completed host-by-host Pixiv reachability diagnostics with selected proxy summaries. | Deterministic diagnostics tests, platform builds, and Runtime Readiness screenshot. |
| 9 | Done | Search filter memory | Completed first slice of per-kind option memory for all artwork, illustrations, manga, and novel search profiles. | SearchOptions profile tests, search regression tests, and platform builds. |
| 10 | Done | Download templates | Completed first editor slices: documented token catalog, compact insertion menu, and native template preset menu in Downloads settings. | Download naming template tests, settings native-boundary test, string catalog validation, platform builds, and settings Visual QA when the settings surface is reviewed. |
| 11 | Done | Work subscriptions | Extended creator work subscriptions from illustration-only checks to illustration, manga, and novel update buckets while preserving existing saved state; exposed per-kind local tracking controls in the existing native grid; opened subscription cards into the matching creator feed instead of a search fallback. | WorkSubscription migration/bucket/route tests, native boundary checks, platform builds, and Work Subscriptions Visual QA evidence. |
| 12 | Done | Reader rotate/mirror tools | Unified rotate and mirror controls through `ReaderImageTransform`, shared the menu between detail and standalone readers, reset transforms on artwork changes, and kept image transforms scoped to image pages rather than reader chrome. | Transform model tests, native-boundary command-model coverage, full Swift tests, macOS/iOS/iPadOS builds, macOS `reader-window` Visual QA, and iOS/iPadOS simulator verify screenshots. |
| 13 | Done | Pixiv activity parser foundation | Added Pixiv Web stacc URL construction, a Web-session-gated API read boundary, `PixivActivityFeedParser`, activity models, embedded JSON fixture parsing, HTML fallback parsing, next-page handling, and duplicate suppression. | `PixivActivityFeedParserTests`, `SearchOptionsTests/pixivWebBookmarkURLs`, `swift test`, `git diff --check`, and macOS/iOS/iPadOS generic builds. |
| 14 | Done | Advanced local filter model foundation | Added a structured `AdvancedLocalFilterDraft` model that can generate `ClientFilterDSL` queries for text, range, boolean, ugoira/GIF, and ratio criteria; extended the DSL parser/evaluator for the same menu-generated tokens. | `AdvancedLocalFilterModelsTests`, `swift test`, `git diff --check`, and macOS/iOS/iPadOS generic builds. |
| 15 | Done | Advanced local filter quick menu | Added wide-header menu presets for bookmarked, AI/R-18, ugoira, and aspect-ratio filters while preserving the iPhone bottom-bar filtering path. | `AdvancedLocalFilterModelsTests`, `NativeBoundaryTests/advancedLocalFiltersStayOnWideFeedHeaders`, string catalog validation, `swift test`, `git diff --check`, macOS/iOS/iPadOS generic builds, and macOS gallery Visual QA. |
| 16 | Done | Advanced local filter typed editor | Added a native wide-header popover editor for typed tag/title/creator text, bookmark/view/page ranges, content flag include/exclude menus, ugoira/bookmarked state, aspect ratio, passthrough terms, and stable query generation from existing filter text. | `AdvancedLocalFilterModelsTests`, `NativeBoundaryTests/advancedLocalFiltersStayOnWideFeedHeaders`, string catalog validation, `swift test`, `git diff --check`, XcodeGen, macOS/iOS/iPadOS generic builds, and macOS gallery Visual QA. |

## Current Slice

| Item | Status | Notes |
| --- | --- | --- |
| Novel comments API tests | Done | Covered `/v3/novel/comments`, `/v2/novel/comment/replies`, and novel comment post form fields. |
| Novel comments Store wiring | Done | Store now exposes novel comment list, replies, and post helpers alongside artwork comments. |
| Novel comments UI | Done | Detail view exposes the shared comment surface for novels and has local Visual QA comments. |
| Comment delete actions | Done | Delete requests use Pixiv's comment delete endpoints, the UI only exposes the destructive action for the signed-in author's own comments, and successful deletes remove the row locally. |
| Stamp comments | Done | Stamp send support now shares the artwork/novel comment post chain and uses a compact native picker. |
| Native comment list | Done | The shared artwork/novel comment surface now uses a native hosted list bridge with AppKit/UIKit intrinsic-height containers. |
| MyPixiv | Done | API/store entry points, profile count, profile menu actions, and dedicated artwork/novel feed routes are wired. |
| Remote search options | Done for safe app-api parameters | Parser, endpoint URL, API fetch, store cache hook, bookmark range preset mapping, novel search filter/query wiring, remote novel language/genre menu mapping, novel text-length presets, and illustration `content_type` query mapping are done. Tool metadata remains documented but intentionally unwired until Pixiv app-api behavior is confirmed. |
| Novel HTML export | Done | TXT/Markdown export formatting moved into a reusable Swift formatter and HTML export is available from the novel detail menu. |
| Reader page preview | Done | Reader filmstrip visibility resolves from page count, platform, and available reader size; phone and portrait iPad stay hidden, while landscape iPad and macOS expose a leading-rail contract with stable artwork/page item IDs. The native AppKit/UIKit collection bridge is wired into the reader and validated with focused tests, full tests/builds, macOS Visual QA, and iPadOS 27 Device Hub screenshots. |
| Network diagnostics | Done | Runtime diagnostics now include safe `HEAD` probes for Pixiv App API, OAuth, Web, and image CDN hosts, with current app proxy mode in each result. |
| Search filter memory | Done for first Store/model slice | Search filters now persist per profile and switch cleanly among all artwork, illustrations, manga, and novels. Saved search presets reuse the same profile restoration path. |
| Download templates | Done for token insertion and preset slices | Download templates now expose the renderer-backed token catalog through a compact insertion menu and documented presets through a native menu in Downloads settings, while preserving the freeform native text field, unknown-token warning, and live previews. |
| Work subscriptions | Done for per-kind tracking and route-aware opening slices | Subscription state tracks illustration, manga, and novel buckets independently, migrates legacy artwork-only JSON into the illustration bucket, lets users toggle tracked work types from each subscription card menu while keeping at least one type active, uses total tracked new-work counts in the existing native grid, and opens cards into the best matching creator feed instead of writing a `user:` search query. |
| Latest novel feed | Done | Added `.novelLatest`, Pixiv app-api `/v1/novel/new` URL construction, Store loading, localized route title, compact mobile novel-menu entry, sidebar section entry, and dashboard novel-group entry. Verified with endpoint, route, dashboard, mobile menu, catalog JSON, and full Swift tests. |
| Novel bookmark tag suggestions | Done | Added `/v1/user/bookmark-tags/novel` URL construction, API fetch, Store suggestion hook, a compact novel bookmark editor sheet, gallery/detail/reader entry points, and `novel-bookmark-editor` Visual QA coverage. |
| Cross-page batch download | Done | Added `BatchDownloadPlan`, explicit loaded-feed following-page controls, bounded `nextURL` page gathering through `enqueueDownloadsFromCurrentFeed`, loading feedback, localized copy, and native-boundary coverage. Selected-work batch downloads remain selection-only and never fetch remote pages. |
| Reader rotate/mirror tools | Done | Added `ReaderImageTransform`, shared `ReaderImageTransformMenu`, detail-reader transform state, standalone-reader transform reuse, and image-layer transform application across single-page, double-page, and continuous artwork reader modes. Verified with focused transform tests, full Swift tests, macOS/iOS/iPadOS builds, macOS reader-window QA, and simulator verify screenshots. |
| Pixiv activity parser foundation | Done | Added `PixivActivityFeedParser`, `PixivActivityPage`, `PixivActivityItem`, `/stacc` URL construction, and `PixivAPI.pixivActivityFeedPage(page:)` behind an explicit Pixiv Web session requirement. Verified post/bookmark/follow fixture parsing, HTML fallback, duplicate suppression, and activity URL construction. |
| Advanced local filter model foundation | Done | Added `AdvancedLocalFilterDraft` and structured criteria for native token/menu editors, plus `ClientFilterDSL` support for generated title, author/artist aliases, GIF/ugoira include/exclude, and artwork ratio tokens. Verified with focused model/DSL tests, full Swift tests, diff check, and platform generic builds. |
| Advanced local filter quick menu | Done | Added a wide-header `Advanced Filter` menu for iPad compact and macOS/regular feed headers. It applies common structured quick presets without entering the iPhone toolbar menu, preserves quoted query text, and keeps full typed/range editing as a later advanced-editor slice. |
| Advanced local filter typed editor | Done | Added the wide-header `Edit Advanced Filter` flow with a native AppKit/UIKit text-field popover, typed text/range/flag/ratio controls, query round-tripping, passthrough preservation, localized copy, focused tests, platform builds, and macOS gallery Visual QA evidence. |
| Apple docs checkpoints | Ongoing reference | This row is not a completion gate; it records which Apple documentation families should guide future UI slices. |

## Apple Documentation Checkpoints

| Topic | Source | How KeiPix should use it |
| --- | --- | --- |
| UIKit collection data | `UICollectionViewDiffableDataSource` | Use stable item identifiers and snapshots for comment lists or threaded rows if the SwiftUI view becomes hot. |
| AppKit collection data | `NSCollectionViewDiffableDataSource` / `NSCollectionViewDataSource` | Prefer native collection/list updates for macOS comment and reader side panels when lists grow. |
| Reader filmstrip rail | `UICollectionViewCompositionalLayout`, `UICollectionViewDiffableDataSource`, and `NSCollectionView` | Use the tested `ReaderFilmstripPageItem` stable IDs as native collection item identifiers; keep thumbnail scrolling/reuse in UIKit/AppKit instead of a persistent SwiftUI `LazyVStack` on the online reader. |
| Menus and sheets | Apple HIG | Keep compact actions in menus on iPhone; use fuller sheets/panels on iPad landscape and macOS. |
| Advanced local filters | `SwiftUI.Menu`, UIKit `UIMenu`, and AppKit `NSMenu` | Use compact grouped menus for quick filter presets on wider headers, keep iPhone filtering lightweight, and keep the command model small enough to replace the SwiftUI shell with AppKit/UIKit wrappers if the menu becomes a hot path. |
| Work subscription menus | Apple HIG `Menu` guidance and SwiftUI `Menu` API | Put per-creator tracking toggles near the subscription card they affect instead of adding a broad toolbar control or a persistent segmented row. |
| Privacy | AppKit/UIKit platform controls | Keep remote writes explicit and preserve existing screenshot/privacy protections. |
