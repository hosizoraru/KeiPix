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
| Novel comments | Pixeval/Mako and pixez-flutter expose novel comments, replies, posting, deletion, and stamp comments. | Novel detail explicitly lacks comments; KeiPix currently wires illustration comments only. | High priority. Start here. |
| Comment actions | Pixeval exposes delete and stamp variants for illustration and novel comments. | KeiPix decodes stamp display but does not expose stamp sending or delete actions. | High priority after novel comments list/post path. |
| MyPixiv | Pixeval exposes user, illustration, and novel MyPixiv surfaces. pixez-flutter displays total MyPixiv users. | KeiPix has following/followers/related users but no dedicated MyPixiv route. | Medium-high priority; add under creator network/library after comment work. |
| Activity feed | Pixeval parses Pixiv Web stacc activity feed. | KeiPix has content feeds, not a social activity stream. | Medium priority; Web-backed, parser-first, failure-tolerant. |
| Remote search options | Pixeval exposes `/v1/search/options`. | KeiPix uses strong local search options. | Medium priority; use remote metadata to refine novel/search filters. |
| Download templates | Pixeval has conditional macro paths. | KeiPix has placeholder templates, previews, and unknown-token warnings. | Enhancement; add native token/condition editor rather than copying macro syntax. |
| Novel export | Pixeval supports HTML, Markdown, and original text. | KeiPix supports TXT and Markdown. | Add HTML next; consider EPUB/PDF later. |
| Reader tools | Pixeval has image viewer modes, page preview slider, rotate/mirror tools. | KeiPix has native readers, paging, continuous/double page, zoom, and basic slider. | Add thumbnail scrubber/filmstrip first for iPad landscape and macOS. |
| Dashboard cards | Pixeval supports configurable home cards, including single work/novel/user cards. | KeiPix has section visibility customization. | Evolve discovery dashboard later with native card presets. |
| Network/direct connect | Pixeval/Pixiv-Nginx provide domain fronting, IP sets, mirror/proxy patterns. | KeiPix has app-level system/direct/manual proxy. | Add diagnostics and clearer host-level checks; do not bundle MITM/self-signed proxy. |
| Widget-style surfaces | pixez-flutter has Android widgets. | KeiPix has `WidgetDataProvider` but no WidgetKit target. | Low priority; track for future WidgetKit/live surface work. |

## Phase Roadmap

| Phase | Scope | Implementation shape | Evidence |
| --- | --- | --- | --- |
| 1 | Novel comment read path | Add Pixiv API methods for `/v3/novel/comments`, `/v2/novel/comment/replies`, `nextNovelComments`; expose Store helpers. | Focused API query tests and store wiring tests. |
| 2 | Novel comment UI | Adapt existing comment presentation into a content-kind-aware component; compact iOS sheet, fuller iPad/macOS panel. | Swift tests, iOS/iPadOS screenshots, macOS visual QA if added. |
| 3 | Comment writes | Add normal comment post for novels, then comment deletion for own comments; keep remote writes explicit. | Unit tests for form shape, signed-out/permission failure states, Simulator smoke. |
| 4 | Stamp comments | Add stamp send support for illustration and novel comments after normal comment chain is stable. | Model/API tests plus visual proof that stamp comments display and send affordance is clear. |
| 5 | MyPixiv | Add models/endpoints/routes for MyPixiv users, illustration feed, and novel feed; surface counts in user profile. | Route coverage tests, API query tests, iPad/macOS navigation check. |
| 6 | Search options | Fetch and cache `/v1/search/options`, then map safe server-provided metadata into search filters. | Parser/model tests and search UI screenshots. |
| 7 | Reader/export polish | Add novel HTML export and reader thumbnail scrubber on wider layouts. | Export fixture tests, macOS/iPad visual QA, reader interaction smoke. |
| 8 | Network diagnostics | Add host-by-host Pixiv reachability diagnostics and clearer proxy guidance. | Deterministic diagnostics tests and Settings screenshot. |

## Current Slice

| Item | Status | Notes |
| --- | --- | --- |
| Novel comments API tests | Done | Covered `/v3/novel/comments`, `/v2/novel/comment/replies`, and novel comment post form fields. |
| Novel comments Store wiring | Done | Store now exposes novel comment list, replies, and post helpers alongside artwork comments. |
| Novel comments UI | Pending | Defer until read path is model/API green. |
| Apple docs checkpoints | In progress | Keep UIKit/AppKit diffable data-source and native sheet/menu guidance in mind for the upcoming UI phase. |

## Apple Documentation Checkpoints

| Topic | Source | How KeiPix should use it |
| --- | --- | --- |
| UIKit collection data | `UICollectionViewDiffableDataSource` | Use stable item identifiers and snapshots for comment lists or threaded rows if the SwiftUI view becomes hot. |
| AppKit collection data | `NSCollectionViewDiffableDataSource` / `NSCollectionViewDataSource` | Prefer native collection/list updates for macOS comment and reader side panels when lists grow. |
| Menus and sheets | Apple HIG | Keep compact actions in menus on iPhone; use fuller sheets/panels on iPad landscape and macOS. |
| Privacy | AppKit/UIKit platform controls | Keep remote writes explicit and preserve existing screenshot/privacy protections. |
