#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="KeiPix"
BUNDLE_ID="com.keipix.client"
MIN_SYSTEM_VERSION="26.0"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"

cd "$ROOT_DIR"

case "$MODE" in
  run|--debug|debug|--logs|logs|--telemetry|telemetry|--verify|verify|--package|package|--visual-qa-pixiv-link-drop|visual-qa-pixiv-link-drop|--visual-qa-pixiv-id-open|visual-qa-pixiv-id-open|--visual-qa-manga-watchlist|visual-qa-manga-watchlist|--visual-qa-series-sheet|visual-qa-series-sheet|--visual-qa-cached-feed|visual-qa-cached-feed|--visual-qa-ranking|visual-qa-ranking|--visual-qa-muted-content|visual-qa-muted-content|--visual-qa-settings-window|visual-qa-settings-window|--visual-qa-ugoira-player|visual-qa-ugoira-player|--visual-qa-downloaded-reader|visual-qa-downloaded-reader|--visual-qa-gallery-auto|visual-qa-gallery-auto|--visual-qa-gallery-two-column|visual-qa-gallery-two-column|--visual-qa-gallery-three-column|visual-qa-gallery-three-column|--visual-qa-gallery-compact|visual-qa-gallery-compact)
    ;;
  *)
    echo "usage: $0 [run|--debug|--logs|--telemetry|--verify|--package|--visual-qa-pixiv-link-drop|--visual-qa-pixiv-id-open|--visual-qa-manga-watchlist|--visual-qa-series-sheet|--visual-qa-cached-feed|--visual-qa-ranking|--visual-qa-muted-content|--visual-qa-settings-window|--visual-qa-ugoira-player|--visual-qa-downloaded-reader|--visual-qa-gallery-auto|--visual-qa-gallery-two-column|--visual-qa-gallery-three-column|--visual-qa-gallery-compact]" >&2
    exit 2
    ;;
esac

case "$MODE" in
  --package|package)
    ;;
  *)
    pkill -x "$APP_NAME" >/dev/null 2>&1 || true
    ;;
esac

swift build
BUILD_DIR="$(swift build --show-bin-path)"
BUILD_BINARY="$BUILD_DIR/$APP_NAME"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS" "$APP_RESOURCES"
cp "$BUILD_BINARY" "$APP_BINARY"
chmod +x "$APP_BINARY"

if [ -d "$BUILD_DIR/KeiPix_KeiPix.bundle" ]; then
  cp -R "$BUILD_DIR/KeiPix_KeiPix.bundle" "$APP_BUNDLE/"
fi

cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleLocalizations</key>
  <array>
    <string>en</string>
    <string>zh-Hans</string>
  </array>
  <key>CFBundleURLTypes</key>
  <array>
    <dict>
      <key>CFBundleURLName</key>
      <string>$BUNDLE_ID</string>
      <key>CFBundleURLSchemes</key>
      <array>
        <string>keipix</string>
      </array>
    </dict>
  </array>
  <key>CFBundleDocumentTypes</key>
  <array>
    <dict>
      <key>CFBundleTypeName</key>
      <string>Web Internet Location</string>
      <key>CFBundleTypeRole</key>
      <string>Viewer</string>
      <key>LSHandlerRank</key>
      <string>Alternate</string>
      <key>LSItemContentTypes</key>
      <array>
        <string>com.apple.web-internet-location</string>
        <string>public.url</string>
      </array>
    </dict>
  </array>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

open_app() {
  if [ "$#" -gt 0 ]; then
    /usr/bin/open -n "$APP_BUNDLE" --args "$@"
  else
    /usr/bin/open -n "$APP_BUNDLE"
  fi
}

case "$MODE" in
  run)
    open_app
    ;;
  --debug|debug)
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    open_app --visual-qa-cached-feed
    sleep 1
    pgrep -x "$APP_NAME" >/dev/null
    ;;
  --visual-qa-pixiv-link-drop|visual-qa-pixiv-link-drop)
    open_app --visual-qa-pixiv-link-drop
    sleep 1
    pgrep -x "$APP_NAME" >/dev/null
    ;;
  --visual-qa-pixiv-id-open|visual-qa-pixiv-id-open)
    open_app --visual-qa-pixiv-id-open
    sleep 1
    pgrep -x "$APP_NAME" >/dev/null
    ;;
  --visual-qa-manga-watchlist|visual-qa-manga-watchlist)
    open_app --visual-qa-manga-watchlist
    sleep 1
    pgrep -x "$APP_NAME" >/dev/null
    ;;
  --visual-qa-series-sheet|visual-qa-series-sheet)
    open_app --visual-qa-series-sheet
    sleep 1
    pgrep -x "$APP_NAME" >/dev/null
    ;;
  --visual-qa-cached-feed|visual-qa-cached-feed)
    open_app --visual-qa-cached-feed
    sleep 1
    pgrep -x "$APP_NAME" >/dev/null
    ;;
  --visual-qa-ranking|visual-qa-ranking)
    open_app --visual-qa-ranking
    sleep 1
    pgrep -x "$APP_NAME" >/dev/null
    ;;
  --visual-qa-muted-content|visual-qa-muted-content)
    open_app --visual-qa-muted-content
    sleep 1
    pgrep -x "$APP_NAME" >/dev/null
    ;;
  --visual-qa-settings-window|visual-qa-settings-window)
    open_app --visual-qa-settings-window
    sleep 2
    pgrep -x "$APP_NAME" >/dev/null
    ;;
  --visual-qa-ugoira-player|visual-qa-ugoira-player)
    open_app --visual-qa-ugoira-player
    sleep 3
    pgrep -x "$APP_NAME" >/dev/null
    ;;
  --visual-qa-downloaded-reader|visual-qa-downloaded-reader)
    open_app --visual-qa-downloaded-reader
    sleep 2
    pgrep -x "$APP_NAME" >/dev/null
    ;;
  --visual-qa-gallery-auto|visual-qa-gallery-auto)
    open_app --visual-qa-gallery-auto
    sleep 1
    pgrep -x "$APP_NAME" >/dev/null
    ;;
  --visual-qa-gallery-two-column|visual-qa-gallery-two-column)
    open_app --visual-qa-gallery-two-column
    sleep 1
    pgrep -x "$APP_NAME" >/dev/null
    ;;
  --visual-qa-gallery-three-column|visual-qa-gallery-three-column)
    open_app --visual-qa-gallery-three-column
    sleep 1
    pgrep -x "$APP_NAME" >/dev/null
    ;;
  --visual-qa-gallery-compact|visual-qa-gallery-compact)
    open_app --visual-qa-gallery-compact
    sleep 1
    pgrep -x "$APP_NAME" >/dev/null
    ;;
  --package|package)
    plutil -lint "$INFO_PLIST"
    test -x "$APP_BINARY"
    echo "$APP_BUNDLE"
    ;;
  *)
    echo "usage: $0 [run|--debug|--logs|--telemetry|--verify|--package|--visual-qa-pixiv-link-drop|--visual-qa-pixiv-id-open|--visual-qa-manga-watchlist|--visual-qa-series-sheet|--visual-qa-cached-feed|--visual-qa-ranking|--visual-qa-muted-content|--visual-qa-settings-window|--visual-qa-ugoira-player|--visual-qa-downloaded-reader|--visual-qa-gallery-auto|--visual-qa-gallery-two-column|--visual-qa-gallery-three-column|--visual-qa-gallery-compact]" >&2
    exit 2
    ;;
esac
