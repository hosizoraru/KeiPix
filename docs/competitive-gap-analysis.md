# Competitive Gap Analysis: KeiPix vs Third-Party Pixiv Clients

> Generated 2026-05-28 from `.tmp/` repos: Pixeval, pixez-flutter, pixes, Pixiv-Nginx

## Repo Overview

| Repo | Stack | Platform | Positioning |
|------|-------|----------|-------------|
| **Pixeval** | C# / Avalonia (.NET) | Win/Linux/macOS/Android/iOS/Web | Most complete cross-platform client, plugin architecture |
| **pixez-flutter** | Flutter / Dart | Android/iOS/Windows/macOS | Most popular 3rd-party Pixiv client |
| **pixes** | Flutter / Dart | macOS/iOS/Android/Linux | Lightweight desktop-first, Fluent UI |
| **Pixiv-Nginx** | Nginx config + tools | Windows (primarily) | GFW proxy tool, not a client |
| **KeiPix** | Swift / SwiftUI | macOS 26 | Native macOS client, strongest QA system |

## Gap Table — Features KeiPix Lacks

### A. High Priority — Core UX Gaps

| # | Feature | Source | Description | Effort |
|---|---------|--------|-------------|--------|
| 1 | Novel reader enhancement | pixes, pixez | Adjustable font size/line height/paragraph spacing, inline image rendering, chapter nav | Low |
| 2 | Novel translation | pixes | Google Translate API integration, 5000-char chunking | Medium |
| 3 | Novel export | pixez, Pixeval | Export as TXT/Markdown/HTML | Low |
| 4 | Download path macro templates | Pixeval | `@{id}`, `@{title}`, `@{artist_name}` + conditionals `@{if_r18?...:}` | Medium |
| 5 | Reverse image search API | pixez, Pixeval | SauceNAO API integration (KeiPix already has UI entry, missing API call) | Low |
| 6 | Keyboard shortcuts config | pixes | Configurable reader shortcuts (page/fav/download/follow/comments) | Low |

### B. Medium Priority — Feature Completion

| # | Feature | Source | Description | Effort |
|---|---------|--------|-------------|--------|
| 7 | Client-side filter DSL | Pixeval | Syntax filter: `tag:#原神 bookmark:>1000 !r18 aspect:>1.5` | High |
| 8 | Work subscriptions | Pixeval | Subscribe to users' new posts/bookmark activity, local persistence | Medium |
| 9 | Customizable home page | Pixeval | User-configurable home card grid (15 source types × row/col layout) | High |
| 10 | Thumbnail layout variety | Pixeval | 7 layout types: lined/grid/uniform stack/staggered etc. | Medium |
| 11 | Continuous + swipe reading | Pixeval | Continuous scroll reading + 4-direction swipe switching | Medium |
| 12 | Image manipulation | Pixeval | Mirror/flip, rotate in reader | Low |
| 13 | JS filename templates | pixez | User writes JS script for filename generation (more flexible than macros) | Medium |
| 14 | Watch Later queue | Pixeval | Local queue, no server sync | Low |
| 15 | Batch operations | pixez, Pixeval | Multi-select works → save/bookmark/open all | Medium |
| 16 | Local history export | pixez | Export history as JSON | Low |
| 17 | Auto-follow on bookmark | pixez | Auto-follow author when bookmarking, configurable public/private | Low |
| 18 | Auto-tag on bookmark | pixez | Auto-use artwork tags when bookmarking | Low |

### C. Low Priority — Architecture / Niche

| # | Feature | Source | Description | Effort |
|---|---------|--------|-------------|--------|
| 19 | Plugin/extension system | Pixeval | DLL plugin host, COM interop, extensible image/text/downloaders | Very High |
| 20 | Domain Fronting | Pixeval | SNI fragmentation bypass, configurable IP resolvers | High |
| 21 | SNI bypass + DNS | pixez | Custom DNS resolution + TLS ECH support | High |
| 22 | Built-in HTTP server | pixez | Local HTTP server for cross-device access | Medium |
| 23 | Dynamic theming / AMOLED | pixez | Seed color dynamic theme | Medium |
| 24 | Pixivision HTML scraping | pixez | Scrape pixivision.net HTML for featured works (KeiPix has API version) | Low |
| 25 | Mouse side button nav | pixes | Mouse back button triggers pop navigation | Low |
| 26 | Local tag/user blocking | pixes | Client-side blocklist independent of Pixiv server | Medium |
| 27 | gRPC proxy | Pixiv-Nginx | Pixiv main site uses gRPC (KeiPix uses REST API, N/A) | N/A |

## KeiPix Unique Advantages (not in any competitor)

| Feature | Description |
|---------|-------------|
| **QA Matrix System** | NonNovelQA matrix, VisualQA evidence manifests, runtime readiness checks |
| **Search Diagnostic Probe** | Dedicated search debugging tool |
| **Feed Snapshot Cache** | Offline-capable feed snapshots, graceful network failure degradation |
| **Dual Reverse Image Search** | SauceNAO + Ascii2D native integration |
| **CoreSpotlight Indexing** | macOS native Spotlight search for downloaded content |
| **AppIntents / Shortcuts** | Open Pixiv Link, Refresh Feed as system-level integrations |
| **Screen Capture Protection** | macOS WindowCaptureProtectionBridge |
| **Backup/Restore** | Full JSON export/import of all local libraries |
| **Download Naming Templates** | Already has `${id}`, `${title}`, `${user}` variables |

## Implementation Priority

**P0 — Immediate (1-2 days, low risk high reward):**
1. Novel reader enhancement (font/line-height/paragraph-spacing)
2. Novel export (TXT/Markdown)
3. Keyboard shortcuts configuration
4. Watch Later queue
5. Image flip/rotate in reader
6. History export

**P1 — Short term (3-7 days, medium complexity):**
7. Download path macro templates upgrade (conditional macros)
8. Novel translation integration (Google Translate / DeepL)
9. Auto-tag on bookmark / auto-follow
10. SauceNAO API implementation (UI entry exists)
11. Local tag/user blocklist (independent of Pixiv server)

**P2 — Medium term (1-3 weeks, needs architecture):**
12. Client-side filter DSL
13. Work subscription system
14. Customizable home page cards
15. Thumbnail layout variety
16. Continuous reading mode
17. Batch operations enhancement

**P3 — Long term / watch:**
18. Plugin system (extremely high architecture cost)
19. Domain Fronting / SNI bypass (legal risk)
20. Dynamic theme system
