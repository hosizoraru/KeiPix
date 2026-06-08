#!/usr/bin/env bash
# Build a release-mode KeiPix.app and package it for distribution.
#
# Usage: ./script/build_release_app.sh [zip|dmg|both]   (default: zip)
#
# Output lands in ./artifacts/:
#   - artifacts/KeiPix.app         (assembled bundle)
#   - artifacts/KeiPix-<version>-build.<build>.zip   (ditto-archived, preserves attrs)
#   - artifacts/KeiPix-<version>-build.<build>.dmg   (UDZO compressed)
#
# Used by the macOS Build GitHub Actions workflow and reproducible
# locally with the same command.
set -euo pipefail

APP_NAME="KeiPix"
BUNDLE_ID="com.keipix.client"
MIN_SYSTEM_VERSION="26.0"
FORMAT="${1:-zip}"

case "$FORMAT" in
  zip|dmg|both) ;;
  *) echo "usage: $0 [zip|dmg|both]" >&2; exit 2 ;;
esac

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACTS_DIR="$ROOT_DIR/artifacts"
APP_BUNDLE="$ARTIFACTS_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"

# shellcheck source=version_settings.sh
source "$ROOT_DIR/script/version_settings.sh"
keipix_load_version_settings "$ROOT_DIR"
# shellcheck source=macos_app_icon.sh
source "$ROOT_DIR/script/macos_app_icon.sh"
# shellcheck source=build_parallelism.sh
source "$ROOT_DIR/script/build_parallelism.sh"
VERSION="$KEIPIX_MARKETING_VERSION"
BUILD_NUMBER="$KEIPIX_BUILD_NUMBER"
BUILD_JOBS="$(keipix_resolve_build_jobs "${KEIPIX_BUILD_JOBS:-}")"

cd "$ROOT_DIR"
mkdir -p "$ARTIFACTS_DIR"

echo "==> Building $APP_NAME $VERSION ($BUILD_NUMBER) in release configuration with $BUILD_JOBS jobs"
swift build -c release --product "$APP_NAME" --jobs "$BUILD_JOBS"

BUILD_DIR="$(swift build -c release --show-bin-path)"
BUILD_BINARY="$BUILD_DIR/$APP_NAME"

if [ ! -x "$BUILD_BINARY" ]; then
  echo "release build did not produce $BUILD_BINARY" >&2
  exit 1
fi

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS" "$APP_RESOURCES"
cp "$BUILD_BINARY" "$APP_BINARY"
chmod +x "$APP_BINARY"

# SwiftPM emits the `.process("Resources")` payload as a sibling
# `KeiPix_KeiPix.bundle` next to the binary. The bundle has to live
# under `Contents/Resources/` so (a) `Bundle.main.resourceURL` finds
# it as the first lookup candidate inside `Bundle.module`, and (b)
# codesign treats it as sealed contents instead of an unsealed
# bundle-root payload (which would refuse `--deep` signing).
RESOURCE_BUNDLE="$BUILD_DIR/${APP_NAME}_${APP_NAME}.bundle"
if [ -d "$RESOURCE_BUNDLE" ]; then
  cp -R "$RESOURCE_BUNDLE" "$APP_RESOURCES/"
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
  <string>$VERSION</string>
  <key>CFBundleVersion</key>
  <string>$BUILD_NUMBER</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleLocalizations</key>
  <array>
    <string>en</string>
    <string>zh-Hans</string>
    <string>zh-Hant</string>
    <string>ja</string>
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
  <key>NSHumanReadableCopyright</key>
  <string>Copyright (c) KeiPix.</string>
</dict>
</plist>
PLIST

keipix_compile_macos_app_icon "$ROOT_DIR" "$APP_RESOURCES" "$MIN_SYSTEM_VERSION" "$INFO_PLIST"
plutil -lint "$INFO_PLIST" >/dev/null

# Ad-hoc codesign keeps the bundle structurally valid (so launchd will
# accept it on the build machine and Gatekeeper will only complain
# about provenance, not corruption). CI runs without Developer ID
# secrets, so this is the strongest signature we can offer for free.
codesign --force --deep --sign - --timestamp=none "$APP_BUNDLE"

cd "$ARTIFACTS_DIR"

write_zip() {
  local zip_name="$APP_NAME-$VERSION-build.$BUILD_NUMBER.zip"
  rm -f "$zip_name"
  # `ditto -c -k` writes a PKZip archive that preserves macOS metadata
  # (resource forks, extended attrs, codesign seal). `zip` and `tar`
  # would silently strip these and break the bundle on extraction.
  /usr/bin/ditto -c -k --sequesterRsrc --keepParent "$APP_NAME.app" "$zip_name"
  echo "wrote $ARTIFACTS_DIR/$zip_name"
}

write_dmg() {
  local dmg_name="$APP_NAME-$VERSION-build.$BUILD_NUMBER.dmg"
  rm -f "$dmg_name"
  hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$APP_NAME.app" \
    -ov \
    -format UDZO \
    "$dmg_name" >/dev/null
  echo "wrote $ARTIFACTS_DIR/$dmg_name"
}

case "$FORMAT" in
  zip)  write_zip ;;
  dmg)  write_dmg ;;
  both)
    write_zip &
    zip_pid=$!
    write_dmg &
    dmg_pid=$!
    status=0
    wait "$zip_pid" || status=$?
    wait "$dmg_pid" || status=$?
    exit "$status"
    ;;
esac
