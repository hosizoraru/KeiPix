# KeiPix Non-Novel Gap Audit

Date: 2026-05-25

Scope: non-novel Pixiv client features. Novel recommendation, novel search, novel ranking, novel reader, and novel comments are deferred by policy.

Reference projects:

- `tmp/pixez-flutter`
- `tmp/pixes`

KeiPix implementation route: native Swift + SwiftUI, with narrow AppKit/WebKit bridges for macOS integration. Pixez/Pixes are behavior references only; no Flutter/Dart/GPL code is copied into `Sources/KeiPix`.

## Current Comparison

| Area | Pixez / Pixes reference behavior | KeiPix current state | Gap / issue | Priority |
| --- | --- | --- | --- | --- |
| Native Apple route | Reference apps use Flutter UI with platform plugins. | SwiftPM macOS app, SwiftUI `NavigationSplitView`, AppKit bridges for trackpad/window/security, WebKit for in-app article content. | Keep Apple-native boundaries documented when porting behavior ideas. | P0 ongoing |
| Login and accounts | OAuth PKCE, token refresh, account persistence, account switching. | OAuth PKCE, Keychain storage, token refresh, stored accounts, privacy option for hiding account text. | Add a visible account health row and one-click token refresh check in QA/readiness. | P1 |
| Main discovery feeds | Recommended illust/manga, latest works, ranking, following feed, trending tags, Pixivision/Spotlight, recommended users. | All listed routes exist in sidebar or toolbar-driven surfaces. | Home dashboard density is still weaker than Pixez/Pixes; discovery surfaces feel separate instead of a compact command center. | P2 |
| Artwork gallery | Pixez/Pixes use masonry/staggered grids and special handling for wide images. | Custom SwiftUI `MasonryLayout`, fixed two/three/auto/compact modes, badges, selected state, context menus, and QA-gated window-scoped visual evidence for `gallery-feed`, `trending-tags`, `pixivision`, and `narrow-window`. | Extend the same evidence pattern to downloads and reader windows. | P1 QA |
| Trending tags | Dedicated tag cards with preview artwork and search entry. | Native `TrendingTagsView`, custom `TrendingTagMasonryLayout`, shared `DiscoveryCardPresentation`, and captured `trending-tags` evidence. | Keep this in regression coverage when changing card sizing or preview masking. | P1 QA |
| Pixivision / Spotlight | Article list opens details, usually through in-app route or web view. | `SpotlightView`, favorite/history, `SpotlightArticleDetailView`, `WebArticleView`, Pixiv link resolver, in-app article evidence, and native Pixiv link extraction. | Continue validating article link routing with live article content. | P1 QA |
| Artwork detail | Large preview, actions, tags, creator, stats, related works, comments. | Detail inspector, collapsible info, related works, tags, summaries, comments, feedback, mute/report handoff. | Add compact "focus reading" preset and richer detail state restoration per artwork. | P2 |
| Multi-page reader | Continuous manga reading, zoom page, page navigation, swipe/trackpad patterns. | Per-page aspect ratio, continuous/single/index modes, persisted mode defaults by work type, trackpad swipe, magnify, smart zoom, keyboard, reader window, full-screen focus preset, page-jump overlay, and optional per-artwork last-page restoration. | Add the same resume behavior to downloaded local artwork viewer if local-library reading becomes a main path. | P2 |
| Ugoira | Metadata load, animation playback, save/export. | Ugoira metadata, playback, ZIP download, local ZIP preview, GIF export. | Add playback speed controls and poster/frame export shortcuts. | P2 |
| Search | Keyword search, tag autocomplete, match mode, sort, popular preview, R18, AI, bookmark count, user search. | Advanced search model covers match, sort, age, date, bookmark min/max, AI, work type, ugoira, autocomplete, saved searches. | Add saved preset import/export and better Pixiv Web parity for copied search URLs. | P1 |
| Premium search | Pixiv Premium popular male/female sorts. | Premium-gated sorts and diagnostics exist. | Needs live Premium account evidence; keep skipped state explicit for non-Premium accounts. | P1 QA |
| Bookmarking | Public/private bookmark, bookmark tags, auto-tag preferences. | Quick bookmark, editor, bookmark tags, default visibility, use artwork tags, auto-download after bookmark. | Add batch bookmark edit for selected/visible works and safer conflict display when remote tags differ. | P2 |
| Following creators | Follow/unfollow, public/private follow, following/follower lists, recommended users. | Recommended/search/following creators, follow visibility checks, filters, bulk actions, related creators. | Add "creator collections" or pinned creators for macOS sidebar/library workflows. | P2 |
| Manga series and watchlist | Manga recommendation, series view, watchlist add/remove. | Manga recommended/new/ranking, series view, watchlist list and add/remove. | Add unread/new-update badges and stronger routing from every manga card/tag to series/watchlist. | P1 |
| Comments | Read comments, replies, add comments, mute/report comment. | Illust comments, replies, add comment, local comment feedback preview and mute phrase support. | Add stamp/emoji comment support if API payload is verified; add own-comment delete only after reversible endpoint is verified. | P2 |
| Safety badges | AI, R18/R18G, muted, ugoira markers on cards/detail/download names. | `ArtworkContentBadge`, R18/R18G/AI/ugoira/muted display, download template placeholders. | Add optional NSFW blur/mask for gallery cards and reader thumbnails. | P1 |
| AI and R18 filtering | Local AI/R18 hiding, Pixiv search filters, user setting for AI display. | Local hide AI, Pixiv search `search_ai_type`, age keyword suffix, restricted-mode setting, mute sync. | Pixiv account-wide AI display endpoint is still unverified; R18 gallery masking can be richer. | P1 |
| Mute/blocking | Mute tags, creators, artworks, comments; local import/export; Pixiv sync. | Muted content library, local mutes, Pixiv mute sync, undo flows, import/export. | Add bulk mute from selected/visible results and preview affected count before applying. | P1 |
| Downloads | Queue, concurrent tasks, naming templates, batch download, local library. | Queue, filters/search/sort, template placeholders, visible batch actions, page-range multi-P downloads, retry-all-failed backoff, local previews, Finder actions. | Add optional auto-bookmark-after-download parity. | P2 |
| Local cache/offline | Pixez has glance/cache layers and local persistence for feed previews/history. | URLCache-backed image cache, download library, local browsing/search/spotlight history. | Add feed snapshot cache for last successful route load and offline-friendly read-only gallery. | P2 |
| Deep links and Pixiv URLs | Pixes handles Pixiv URLs/app links for users, artworks, tags, novels. | Search prefixes and Pixiv web link resolver exist; ID open sheet exists. | Register macOS URL/document handlers and route pasted/dragged Pixiv URLs through one native resolver surface. | P1 |
| Sharing/copy actions | Copy image, copy Pixiv link, copy metadata templates, share image. | Copy links, copy summaries, pasteboard support, current-page image actions, privacy option. | Add customizable copy template parity for artwork/creator info. | P2 |
| Settings | Rich toggles for quality, layout, save behavior, AI/R18, language, network. | Layout, trackpad, privacy, language, downloads, filters, runtime readiness. | Settings should group "Reading", "Discovery", "Safety", "Downloads", "Advanced QA" with search in settings. | P1 |
| QA/readiness | Reference projects rely more on manual flows. | Runtime readiness, search diagnostics, ID diagnostics, mutable QA authorization, build script. | Add a single non-novel QA matrix view with route status, last run, screenshot evidence, and skipped reasons. | P0 |

## Completion Snapshot

| Board | Completion | Current confidence | Next action |
| --- | ---: | --- | --- |
| Illust feeds and ranking | 92% | Good for daily use; main API routes exist. | Add QA matrix evidence and visual regression screenshots. |
| Manga feeds, series, watchlist | 88% | Strong base, weaker update/read-state UX. | Add update badges and stronger series/watchlist routing. |
| Search | 94% | Feature-rich, close to Pixiv Web for artwork search. | Add preset import/export and live Premium evidence. |
| Gallery / masonry | 94% | Core layout exists, window-scoped visual QA capture is available, and P0 gallery surfaces have captured manifests. | Add download and reader visual captures as P1 coverage. |
| Reader | 98% | Strong macOS trackpad, persisted reading defaults, full-screen focus preset, page jump, multi-P support, and per-artwork resume. | Keep reader resume in regression coverage and extend it to downloaded local artwork viewer later. |
| Artwork detail/social | 90% | Core actions and comments work. | Add comment stamps only after endpoint verification. |
| Downloads | 96% | Strong queue, page-range multi-P downloads, staggered failed-item retry, and local library. | Add optional auto-bookmark-after-download. |
| Safety/filtering | 88% | AI/R18/mute foundations exist. | Add optional NSFW mask and bulk mute previews. |
| Pixivision / Spotlight | 90% | Native list/detail exists, article content stays in app, and Pixiv links resolve through the native resolver. | Keep live article link routing in regression coverage. |
| QA and diagnostics | 92% | Non-novel QA matrix exists and P0 visual surfaces read stored screenshot evidence. | Run the matrix after signed-in route changes and keep manifests fresh. |

## Implementation Plan

| Wave | Goal | Concrete work | Acceptance |
| --- | --- | --- | --- |
| 1 | Stabilize visual surfaces | Refactor trending tag and Spotlight/Pixivision card sizing onto one shared presentation model; add screenshot QA cases for auto/two/three/compact gallery modes; verify no overlap, gray gutters, or clipped wide images. | Done for P0 surfaces: `gallery-feed`, `trending-tags`, `pixivision`, and `narrow-window` manifests exist and are read by the QA matrix. |
| 2 | Keep Pixiv links in app | Expand `PixivWebLinkResolver` and Spotlight article handling so artwork/user/tag links open native KeiPix routes by default; external browser stays as explicit menu action. | Native resolver is in place; keep live Pixivision article link routing in regression runs. |
| 3 | Build the non-novel QA matrix | Add a Settings/Readiness panel that runs read-only checks for feeds, ranking, search, bookmarks, following creators, trending tags, Spotlight, downloads, reader availability, and selected artwork detail. Store last run, skipped reason, and copyable results. | Done for read-only route and visual evidence tracking; continue refreshing signed-in matrix results after major route changes. |
| 4 | Improve safety and filtering | Add optional gallery NSFW blur/mask, bulk mute preview for visible selected tags/creators/artworks, and clearer account-wide AI-display status. | R18/AI visibility can be audited from Settings; bulk mute shows affected count and undo path. |
| 5 | Deepen reader/download parity | Add optional auto-bookmark-after-download and per-artwork reader resume. | Reader resume is done for Pixiv artwork views; next work is auto-bookmark-after-download and downloaded local viewer resume. |
| 6 | Polish power-user portability | Add import/export for saved search presets/history and customizable copy templates for artwork/creator metadata. | JSON import/export round-trips locally; copy templates support artwork ID, user ID, title, tags, URL, AI/R18 markers. |

Recommended next implementation wave: Wave 5 continuation, focused on optional auto-bookmark-after-download and downloaded local viewer resume.
