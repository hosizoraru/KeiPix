# KeiPix

KeiPix is a native Swift + SwiftUI Pixiv client for macOS 26 and newer Apple platforms.

## Current Surface

- Pixiv OAuth PKCE login in an embedded `WKWebView`
- Keychain-backed token storage
- Pixiv app API client with `X-Client-Time`, `X-Client-Hash`, bearer auth, token refresh, and form POST support
- Native `NavigationSplitView` layout with sidebar, adaptive artwork grid, and detail inspector
- Feeds for recommended artworks, ranking, bookmarks, following, and tag search
- Native image loader with Pixiv `Referer` header and URLCache-backed disk cache
- Bookmark and follow actions
- Localized English and Simplified Chinese strings

## References

The two open-source Flutter clients are cloned under `tmp/` for reference:

- `tmp/pixez-flutter`
- `tmp/pixes`

The first implementation borrows product and backend architecture ideas only: OAuth PKCE, Pixiv app API headers, token refresh, image `Referer`, sidebar sections, grid browsing, and detail actions. The app code in `Sources/KeiPix` is a fresh native SwiftUI implementation.

## Run

```bash
./script/build_and_run.sh
```

The Codex app Run action is wired to the same script through `.codex/environments/environment.toml`.

Useful modes:

```bash
./script/build_and_run.sh --verify
./script/build_and_run.sh --logs
./script/build_and_run.sh --debug
```
