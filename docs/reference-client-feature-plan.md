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

| Area | Reference signal | KeiPix state | Decision |
| --- | --- | --- | --- |
| Novel comments | Pixeval/Mako and pixez-flutter expose novel comments, replies, posting, deletion, and stamp comments. | KeiPix now loads, displays, replies to, posts normal comments, deletes authored comments, and posts stamp comments through the shared comment surface. | Keep as a shared artwork/novel surface; continue improving the native list container without splitting artwork and novel comments. |
| Comment actions | Pixeval exposes delete and stamp variants for illustration and novel comments. | KeiPix now exposes authored-comment deletion and stamp sending for illustration and novel comments. | Keep remote writes explicit; do not live-test destructive actions without authorization. |
| MyPixiv | Pixeval exposes user, illustration, and novel MyPixiv surfaces. pixez-flutter displays total MyPixiv users. | KeiPix now has MyPixiv API/store entry points, profile MyPixiv counts, profile menu entry points, and dedicated artwork/novel feed routes. | Treat the first MyPixiv slice as complete; later polish can focus on richer navigation affordances if real-account QA exposes gaps. |
| Activity feed | Pixeval parses Pixiv Web stacc activity feed. | KeiPix has content feeds, not a social activity stream. | Medium priority; Web-backed, parser-first, failure-tolerant. |
| Remote search options | Pixeval exposes `/v1/search/options`, and Pixeval's search paths use the same match/sort/AI/date vocabulary plus novel-specific language, genre, and length knobs. | KeiPix now decodes and caches Pixiv remote search metadata, uses server-provided bookmark ranges as search filter presets, routes existing search filters into novel search query/local filtering, maps remote novel language/genre options into compact menus, applies Pixiv's safe novel text-length presets, and sends supported illustration `content_type` filters. | Keep Pixiv tool metadata as research-only until a confirmed app-api query parameter is observed. |
| Download templates | Pixeval has conditional macro paths. | KeiPix has placeholder templates, previews, unknown-token warnings, and a native token insertion menu backed by the renderer's documented token catalog. | Keep growing this as a native editor: token insertion is done, condition/preset editing can come later without copying macro syntax. |
| Novel export | Pixeval supports HTML, Markdown, and original text. | KeiPix now supports TXT, Markdown, and static HTML export. | Consider EPUB/PDF later only if the native reader/export workflow needs them. |
| Reader tools | Pixeval has image viewer modes, page preview slider, rotate/mirror tools. | KeiPix has native readers, paging, continuous/double page, zoom, and basic slider. | Add thumbnail scrubber/filmstrip first for iPad landscape and macOS. |
| Dashboard cards | Pixeval supports configurable home cards, including single work/novel/user cards. | KeiPix has section visibility customization. | Evolve discovery dashboard later with native card presets. |
| Network/direct connect | Pixeval/Pixiv-Nginx provide domain fronting, IP sets, mirror/proxy patterns. | KeiPix has app-level system/direct/manual proxy and now reports host-by-host Pixiv reachability for App API, OAuth, Web, and image CDN. | Keep diagnostics read-only and platform-networking based; do not bundle MITM/self-signed proxy. |
| Widget-style surfaces | pixez-flutter has Android widgets. | KeiPix has `WidgetDataProvider` but no WidgetKit target. | Low priority; track for future WidgetKit/live surface work. |
| Search filter memory | pixez-flutter remembers search sort, target, AI, and ugoira options per search result context. | KeiPix now keeps separate search option profiles for all artwork, illustrations, manga, and novels; saved presets restore through the same profile chain. | Keep this as lightweight per-search-kind memory, not a replacement for saved searches or the in-feed client filter. |
| Novel follow and bookmarks | pixez-flutter exposes novel follow, public/private novel bookmarks, novel ranking, novel watchlist, and series pages as one novel workflow. | KeiPix has novel recommended, ranking, search, series, watchlist, and bookmark actions, but navigation density still needs platform-specific polish. | Continue unifying novel surfaces with compact iPhone menus and fuller iPad landscape/macOS panes. |
| Reader page preview | Pixeval has a page preview slider/filmstrip for image readers. | KeiPix has native readers, page restore, and paging modes. | Add thumbnail scrubber/filmstrip first on iPad landscape and macOS; keep iPhone transient and unobtrusive. |
| Work subscriptions | Pixeval can subscribe to creator work updates and queue sync. | KeiPix already has work subscription models and a view. | Strengthen the existing subscription surface instead of adding a parallel feature: auto-check, per-kind subscription, and clear update feedback. |
| Local filtering DSL | Pixeval has a rich work filter language for title, author, tag, ratio, date, R-18, AI, GIF, bookmark, and index checks. | KeiPix has `ClientFilterDSL` plus bottom-bar in-feed filtering. | Keep iPhone lightweight; consider an advanced native editor for iPad landscape/macOS later. |

## Do Not Copy Directly

| Reference pattern | Reason | Native KeiPix translation |
| --- | --- | --- |
| Pixiv-Nginx self-signed certificate and MITM proxy setup | This is too risky for a native client and conflicts with privacy expectations. | Host-by-host diagnostics, proxy status, and clear troubleshooting text. |
| pixez-flutter certificate bypass / SNI bypass implementation | It is a network workaround, not a safe default client behavior. | Advanced diagnostics only; keep normal requests on platform networking. |
| Flutter/Avalonia layout and implementation structure | Reference projects are behavior references only. | Rebuild workflows with Swift models, AppKit/UIKit hot paths, and SwiftUI shells. |
| Desktop-style filter DSL as the iPhone default | It would overload small-screen input and conflict with compact feed filtering. | Use chips/dropdowns on iPhone; reserve advanced editors for wider layouts. |

## Phase Roadmap

| Phase | Scope | Implementation shape | Evidence |
| --- | --- | --- | --- |
| 1 | Novel comment read/post path | Completed API, Store, and detail UI wiring for `/v3/novel/comments`, `/v2/novel/comment/replies`, and `/v1/novel/comment/add`. | Existing endpoint, boundary, Visual QA fixture, and full Swift tests. |
| 2 | Comment delete actions | Completed delete endpoints for illustration and novel comments, plus a destructive row action scoped to comments authored by the signed-in user. | Endpoint/form tests, authored-by-current-user tests, comment UI boundary tests, no live remote delete unless explicitly authorized. |
| 3 | Stamp comments | Completed stamp send support for illustration and novel comments after delete flow is stable. | Model/API tests plus visual proof that stamp comments display and send affordance is clear. |
| 4 | Native comment list | Completed the first top-level comment list container move toward AppKit/UIKit ownership while SwiftUI remains row-hosting glue. | Native boundary tests, macOS Visual QA, and iOS/iPadOS builds. |
| 5 | MyPixiv | Completed models/endpoints/routes for MyPixiv users, illustration feed, and novel feed; surfaced counts and route entry points in user profile. | Route coverage tests, API query tests, profile native-boundary checks, platform builds, and macOS creator-profile Visual QA. |
| 6 | Search options | Fetch and cache `/v1/search/options`; first UI slice maps server-provided bookmark ranges into the minimum/maximum bookmark preset menus, second slice makes novel search honor the shared search filters, third slice exposes remote novel language/genre menus, fourth slice adds Pixiv's non-premium novel text-length ranges, and fifth slice maps existing artwork/ugoira filters to supported `content_type` query values. | Parser/model tests, search option tests, novel query/filter tests, search UI boundary tests, and search UI screenshots when the visible pane changes further. |
| 7 | Reader/export polish | Completed novel HTML export; next add reader thumbnail scrubber on wider layouts. | Export formatter tests, platform builds, and novel-feed Visual QA for the first export slice. |
| 8 | Network diagnostics | Completed host-by-host Pixiv reachability diagnostics with selected proxy summaries. | Deterministic diagnostics tests, platform builds, and Runtime Readiness screenshot. |
| 9 | Search filter memory | Completed first slice of per-kind option memory for all artwork, illustrations, manga, and novel search profiles. | SearchOptions profile tests, search regression tests, and platform builds. |
| 10 | Download templates | Completed first editor slice: documented token catalog plus compact insertion menu in Downloads settings. | Download naming template tests, settings native-boundary test, string catalog validation, platform builds, and settings Visual QA when the settings surface is reviewed. |
| 11 | Work subscriptions | Extend creator work subscriptions from illustration-only checks to illustration, manga, and novel update buckets while preserving existing saved state; expose per-kind local tracking controls in the existing native grid. | WorkSubscription migration/bucket tests, native boundary checks, platform builds, and Work Subscriptions Visual QA evidence. |

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
| Network diagnostics | Done | Runtime diagnostics now include safe `HEAD` probes for Pixiv App API, OAuth, Web, and image CDN hosts, with current app proxy mode in each result. |
| Search filter memory | Done for first Store/model slice | Search filters now persist per profile and switch cleanly among all artwork, illustrations, manga, and novels. Saved search presets reuse the same profile restoration path. |
| Download templates | Done for token insertion slice | Download templates now expose the renderer-backed token catalog through a compact insertion menu in Downloads settings, while preserving the freeform native text field, unknown-token warning, and live previews. |
| Work subscriptions | Done for per-kind tracking slice | Subscription state tracks illustration, manga, and novel buckets independently, migrates legacy artwork-only JSON into the illustration bucket, lets users toggle tracked work types from each subscription card menu while keeping at least one type active, and uses total tracked new-work counts in the existing native grid. |
| Apple docs checkpoints | In progress | Keep UIKit/AppKit diffable data-source and native sheet/menu guidance in mind for the upcoming UI phase. |

## Apple Documentation Checkpoints

| Topic | Source | How KeiPix should use it |
| --- | --- | --- |
| UIKit collection data | `UICollectionViewDiffableDataSource` | Use stable item identifiers and snapshots for comment lists or threaded rows if the SwiftUI view becomes hot. |
| AppKit collection data | `NSCollectionViewDiffableDataSource` / `NSCollectionViewDataSource` | Prefer native collection/list updates for macOS comment and reader side panels when lists grow. |
| Menus and sheets | Apple HIG | Keep compact actions in menus on iPhone; use fuller sheets/panels on iPad landscape and macOS. |
| Work subscription menus | Apple HIG `Menu` guidance and SwiftUI `Menu` API | Put per-creator tracking toggles near the subscription card they affect instead of adding a broad toolbar control or a persistent segmented row. |
| Privacy | AppKit/UIKit platform controls | Keep remote writes explicit and preserve existing screenshot/privacy protections. |
