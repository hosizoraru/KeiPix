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
APP_PROCESS_SUFFIX="/$APP_NAME.app/Contents/MacOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"

cd "$ROOT_DIR"

# shellcheck source=version_settings.sh
source "$ROOT_DIR/script/version_settings.sh"
keipix_load_version_settings "$ROOT_DIR"
# shellcheck source=macos_app_icon.sh
source "$ROOT_DIR/script/macos_app_icon.sh"

case "$MODE" in
  run|--debug|debug|--logs|logs|--telemetry|telemetry|--verify|verify|--package|package|--visual-qa-discover-dashboard|visual-qa-discover-dashboard|--visual-qa-discover-dashboard-customization|visual-qa-discover-dashboard-customization|--visual-qa-pixiv-link-drop|visual-qa-pixiv-link-drop|--visual-qa-pixiv-id-open|visual-qa-pixiv-id-open|--visual-qa-pixiv-activity|visual-qa-pixiv-activity|--visual-qa-creator-profile|visual-qa-creator-profile|--visual-qa-feedback-sheet|visual-qa-feedback-sheet|--visual-qa-artwork-detail-social|visual-qa-artwork-detail-social|--visual-qa-reader-window|visual-qa-reader-window|--visual-qa-bookmark-editor|visual-qa-bookmark-editor|--visual-qa-novel-bookmark-editor|visual-qa-novel-bookmark-editor|--visual-qa-manga-watchlist|visual-qa-manga-watchlist|--visual-qa-work-subscriptions|visual-qa-work-subscriptions|--visual-qa-series-sheet|visual-qa-series-sheet|--visual-qa-cached-feed|visual-qa-cached-feed|--visual-qa-search-workspace|visual-qa-search-workspace|--visual-qa-novel-feed|visual-qa-novel-feed|--visual-qa-ranking|visual-qa-ranking|--visual-qa-muted-content|visual-qa-muted-content|--visual-qa-about|visual-qa-about|--visual-qa-settings-window|visual-qa-settings-window|--visual-qa-download-settings|visual-qa-download-settings|--visual-qa-runtime-readiness|visual-qa-runtime-readiness|--visual-qa-sharing-templates|visual-qa-sharing-templates|--visual-qa-ugoira-player|visual-qa-ugoira-player|--visual-qa-download-queue|visual-qa-download-queue|--visual-qa-downloaded-reader|visual-qa-downloaded-reader|--visual-qa-gallery-auto|visual-qa-gallery-auto|--visual-qa-gallery-two-column|visual-qa-gallery-two-column|--visual-qa-gallery-three-column|visual-qa-gallery-three-column|--visual-qa-gallery-compact|visual-qa-gallery-compact)
    ;;
  *)
    echo "usage: $0 [run|--debug|--logs|--telemetry|--verify|--package|--visual-qa-discover-dashboard|--visual-qa-discover-dashboard-customization|--visual-qa-pixiv-link-drop|--visual-qa-pixiv-id-open|--visual-qa-pixiv-activity|--visual-qa-creator-profile|--visual-qa-feedback-sheet|--visual-qa-artwork-detail-social|--visual-qa-reader-window|--visual-qa-bookmark-editor|--visual-qa-novel-bookmark-editor|--visual-qa-manga-watchlist|--visual-qa-work-subscriptions|--visual-qa-series-sheet|--visual-qa-cached-feed|--visual-qa-search-workspace|--visual-qa-novel-feed|--visual-qa-ranking|--visual-qa-muted-content|--visual-qa-about|--visual-qa-settings-window|--visual-qa-download-settings|--visual-qa-runtime-readiness|--visual-qa-sharing-templates|--visual-qa-ugoira-player|--visual-qa-download-queue|--visual-qa-downloaded-reader|--visual-qa-gallery-auto|--visual-qa-gallery-two-column|--visual-qa-gallery-three-column|--visual-qa-gallery-compact]" >&2
    exit 2
    ;;
esac

running_app_pids() {
  /bin/ps -axo pid=,command= | /usr/bin/awk -v suffix="$APP_PROCESS_SUFFIX" 'index($0, suffix) > 0 { print $1 }'
}

terminate_running_app() {
  local pids
  pids="$(running_app_pids)"

  if [ -z "$pids" ]; then
    return 0
  fi

  # shellcheck disable=SC2086
  /bin/kill $pids >/dev/null 2>&1 || true
  sleep 0.5

  pids="$(running_app_pids)"
  if [ -n "$pids" ]; then
    # shellcheck disable=SC2086
    /bin/kill -9 $pids >/dev/null 2>&1 || true
  fi
}

assert_app_running() {
  running_app_pids | /usr/bin/grep -q .
}

case "$MODE" in
  --package|package)
    ;;
  *)
    terminate_running_app
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
  <key>CFBundleShortVersionString</key>
  <string>$KEIPIX_MARKETING_VERSION</string>
  <key>CFBundleVersion</key>
  <string>$KEIPIX_BUILD_NUMBER</string>
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

keipix_compile_macos_app_icon "$ROOT_DIR" "$APP_RESOURCES" "$MIN_SYSTEM_VERSION" "$INFO_PLIST"

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
    assert_app_running
    ;;
  --visual-qa-discover-dashboard|visual-qa-discover-dashboard)
    open_app --visual-qa-discover-dashboard
    sleep 1
    assert_app_running
    ;;
  --visual-qa-discover-dashboard-customization|visual-qa-discover-dashboard-customization)
    open_app --visual-qa-discover-dashboard-customization
    sleep 2
    assert_app_running
    ;;
  --visual-qa-pixiv-link-drop|visual-qa-pixiv-link-drop)
    open_app --visual-qa-pixiv-link-drop
    sleep 1
    assert_app_running
    ;;
  --visual-qa-pixiv-id-open|visual-qa-pixiv-id-open)
    open_app --visual-qa-pixiv-id-open
    sleep 1
    assert_app_running
    ;;
  --visual-qa-pixiv-activity|visual-qa-pixiv-activity)
    open_app --visual-qa-pixiv-activity
    sleep 1
    assert_app_running
    ;;
  --visual-qa-creator-profile|visual-qa-creator-profile)
    open_app --visual-qa-creator-profile
    sleep 1
    assert_app_running
    ;;
  --visual-qa-feedback-sheet|visual-qa-feedback-sheet)
    open_app --visual-qa-feedback-sheet
    sleep 1
    assert_app_running
    ;;
  --visual-qa-artwork-detail-social|visual-qa-artwork-detail-social)
    open_app --visual-qa-artwork-detail-social
    sleep 2
    assert_app_running
    ;;
  --visual-qa-reader-window|visual-qa-reader-window)
    open_app --visual-qa-reader-window
    sleep 2
    assert_app_running
    ;;
  --visual-qa-bookmark-editor|visual-qa-bookmark-editor)
    open_app --visual-qa-bookmark-editor
    sleep 2
    assert_app_running
    ;;
  --visual-qa-novel-bookmark-editor|visual-qa-novel-bookmark-editor)
    open_app --visual-qa-novel-bookmark-editor
    sleep 2
    assert_app_running
    ;;
  --visual-qa-manga-watchlist|visual-qa-manga-watchlist)
    open_app --visual-qa-manga-watchlist
    sleep 1
    assert_app_running
    ;;
  --visual-qa-work-subscriptions|visual-qa-work-subscriptions)
    open_app --visual-qa-work-subscriptions
    sleep 1
    assert_app_running
    ;;
  --visual-qa-series-sheet|visual-qa-series-sheet)
    open_app --visual-qa-series-sheet
    sleep 1
    assert_app_running
    ;;
  --visual-qa-cached-feed|visual-qa-cached-feed)
    open_app --visual-qa-cached-feed
    sleep 1
    assert_app_running
    ;;
  --visual-qa-search-workspace|visual-qa-search-workspace)
    open_app --visual-qa-search-workspace
    sleep 1
    assert_app_running
    ;;
  --visual-qa-novel-feed|visual-qa-novel-feed)
    open_app --visual-qa-novel-feed
    sleep 1
    assert_app_running
    ;;
  --visual-qa-ranking|visual-qa-ranking)
    open_app --visual-qa-ranking
    sleep 1
    assert_app_running
    ;;
  --visual-qa-muted-content|visual-qa-muted-content)
    open_app --visual-qa-muted-content
    sleep 1
    assert_app_running
    ;;
  --visual-qa-about|visual-qa-about)
    open_app --visual-qa-about
    sleep 2
    assert_app_running
    ;;
  --visual-qa-settings-window|visual-qa-settings-window)
    open_app --visual-qa-settings-window
    sleep 2
    assert_app_running
    ;;
  --visual-qa-download-settings|visual-qa-download-settings)
    open_app --visual-qa-download-settings
    sleep 2
    assert_app_running
    ;;
  --visual-qa-runtime-readiness|visual-qa-runtime-readiness)
    open_app --visual-qa-runtime-readiness
    sleep 2
    assert_app_running
    ;;
  --visual-qa-sharing-templates|visual-qa-sharing-templates)
    open_app --visual-qa-sharing-templates
    sleep 2
    assert_app_running
    ;;
  --visual-qa-ugoira-player|visual-qa-ugoira-player)
    open_app --visual-qa-ugoira-player
    sleep 3
    assert_app_running
    ;;
  --visual-qa-download-queue|visual-qa-download-queue)
    open_app --visual-qa-download-queue
    sleep 2
    assert_app_running
    ;;
  --visual-qa-downloaded-reader|visual-qa-downloaded-reader)
    open_app --visual-qa-downloaded-reader
    sleep 2
    assert_app_running
    ;;
  --visual-qa-gallery-auto|visual-qa-gallery-auto)
    open_app --visual-qa-gallery-auto
    sleep 1
    assert_app_running
    ;;
  --visual-qa-gallery-two-column|visual-qa-gallery-two-column)
    open_app --visual-qa-gallery-two-column
    sleep 1
    assert_app_running
    ;;
  --visual-qa-gallery-three-column|visual-qa-gallery-three-column)
    open_app --visual-qa-gallery-three-column
    sleep 1
    assert_app_running
    ;;
  --visual-qa-gallery-compact|visual-qa-gallery-compact)
    open_app --visual-qa-gallery-compact
    sleep 1
    assert_app_running
    ;;
  --package|package)
    plutil -lint "$INFO_PLIST"
    test -x "$APP_BINARY"
    echo "$APP_BUNDLE"
    ;;
  *)
    echo "usage: $0 [run|--debug|--logs|--telemetry|--verify|--package|--visual-qa-discover-dashboard|--visual-qa-discover-dashboard-customization|--visual-qa-pixiv-link-drop|--visual-qa-pixiv-id-open|--visual-qa-pixiv-activity|--visual-qa-creator-profile|--visual-qa-feedback-sheet|--visual-qa-artwork-detail-social|--visual-qa-reader-window|--visual-qa-bookmark-editor|--visual-qa-novel-bookmark-editor|--visual-qa-manga-watchlist|--visual-qa-work-subscriptions|--visual-qa-series-sheet|--visual-qa-cached-feed|--visual-qa-search-workspace|--visual-qa-novel-feed|--visual-qa-ranking|--visual-qa-muted-content|--visual-qa-about|--visual-qa-settings-window|--visual-qa-download-settings|--visual-qa-runtime-readiness|--visual-qa-sharing-templates|--visual-qa-ugoira-player|--visual-qa-download-queue|--visual-qa-downloaded-reader|--visual-qa-gallery-auto|--visual-qa-gallery-two-column|--visual-qa-gallery-three-column|--visual-qa-gallery-compact]" >&2
    exit 2
    ;;
esac
