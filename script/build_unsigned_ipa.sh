#!/usr/bin/env bash
# Build an unsigned device IPA for LiveContainer-style import.
#
# Usage: ./script/build_unsigned_ipa.sh <ios|ipados>
#
# Output lands in ./artifacts/:
#   - artifacts/KeiPix-iOS-<version>-build.<build>-unsigned.ipa
#   - artifacts/KeiPix-iPadOS-<version>-build.<build>-unsigned.ipa
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLATFORM="${1:-}"
CONFIGURATION="${KEIPIX_CONFIGURATION:-Release}"

case "$PLATFORM" in
  ios)
    SCHEME="KeiPix iOS"
    ARTIFACT_PLATFORM="iOS"
    ;;
  ipados)
    SCHEME="KeiPix iPadOS"
    ARTIFACT_PLATFORM="iPadOS"
    ;;
  *)
    echo "usage: $0 <ios|ipados>" >&2
    exit 2
    ;;
esac

# shellcheck source=version_settings.sh
source "$ROOT_DIR/script/version_settings.sh"
keipix_load_version_settings "$ROOT_DIR"

VERSION="$KEIPIX_MARKETING_VERSION"
BUILD_NUMBER="$KEIPIX_BUILD_NUMBER"
ARTIFACTS_DIR="$ROOT_DIR/artifacts"
WORK_DIR="$ROOT_DIR/.tmp/unsigned-ipa-$PLATFORM"
PAYLOAD_DIR="$WORK_DIR/Payload"
DERIVED_DATA_PATH="${KEIPIX_DERIVED_DATA_PATH:-$ROOT_DIR/.tmp/DerivedData-unsigned-ipa-$PLATFORM}"
IPA_NAME="KeiPix-$ARTIFACT_PLATFORM-$VERSION-build.$BUILD_NUMBER-unsigned.ipa"
IPA_PATH="$ARTIFACTS_DIR/$IPA_NAME"
PROJECT_PATH="$ROOT_DIR/KeiPix.xcodeproj"
PROJECT_SPEC="$ROOT_DIR/project.yml"

ensure_xcode_project() {
  if [ ! -d "$PROJECT_PATH" ] || [ "$PROJECT_SPEC" -nt "$PROJECT_PATH/project.pbxproj" ]; then
    if ! command -v xcodegen >/dev/null 2>&1; then
      echo "KeiPix.xcodeproj is missing or stale. Install XcodeGen first: brew install xcodegen" >&2
      exit 1
    fi
    echo "==> Generating KeiPix.xcodeproj from project.yml"
    xcodegen generate --spec "$PROJECT_SPEC" >/dev/null
  fi
}

COMMON_XCODE_ARGS=(
  -project "$PROJECT_PATH"
  -scheme "$SCHEME"
  -configuration "$CONFIGURATION"
  -sdk iphoneos
  -destination "generic/platform=iOS"
  -derivedDataPath "$DERIVED_DATA_PATH"
  CODE_SIGNING_ALLOWED=NO
  CODE_SIGNING_REQUIRED=NO
  CODE_SIGN_IDENTITY=
  AD_HOC_CODE_SIGNING_ALLOWED=NO
)

cd "$ROOT_DIR"
ensure_xcode_project
mkdir -p "$ARTIFACTS_DIR"
rm -rf "$WORK_DIR"
mkdir -p "$PAYLOAD_DIR"

echo "==> Building unsigned $ARTIFACT_PLATFORM IPA from '$SCHEME' ($CONFIGURATION)"
xcodebuild "${COMMON_XCODE_ARGS[@]}" -quiet build

BUILD_SETTINGS="$(xcodebuild "${COMMON_XCODE_ARGS[@]}" -showBuildSettings)"
BUILT_PRODUCTS_DIR="$(
  awk -F ' = ' '/^[[:space:]]*BUILT_PRODUCTS_DIR = / { print $2; exit }' <<<"$BUILD_SETTINGS"
)"
FULL_PRODUCT_NAME="$(
  awk -F ' = ' '/^[[:space:]]*FULL_PRODUCT_NAME = / { print $2; exit }' <<<"$BUILD_SETTINGS"
)"

if [ -z "$BUILT_PRODUCTS_DIR" ] || [ -z "$FULL_PRODUCT_NAME" ]; then
  echo "failed to resolve Xcode build product path" >&2
  exit 1
fi

APP_BUNDLE="$BUILT_PRODUCTS_DIR/$FULL_PRODUCT_NAME"
if [ ! -d "$APP_BUNDLE" ]; then
  echo "build did not produce app bundle: $APP_BUNDLE" >&2
  exit 1
fi

/usr/bin/ditto "$APP_BUNDLE" "$PAYLOAD_DIR/$FULL_PRODUCT_NAME"

while IFS= read -r -d '' signature_dir; do
  rm -rf "$signature_dir"
done < <(/usr/bin/find "$PAYLOAD_DIR" -name _CodeSignature -type d -print0)

while IFS= read -r -d '' provisioning_file; do
  rm -f "$provisioning_file"
done < <(/usr/bin/find "$PAYLOAD_DIR" -name embedded.mobileprovision -type f -print0)

if codesign -dv "$PAYLOAD_DIR/$FULL_PRODUCT_NAME" >/dev/null 2>&1; then
  echo "expected an unsigned app bundle, but codesign still recognizes a signature" >&2
  exit 1
fi

rm -f "$IPA_PATH"
(
  cd "$WORK_DIR"
  /usr/bin/zip -qry -X "$IPA_PATH" Payload
)

if ! /usr/bin/unzip -Z1 "$IPA_PATH" | grep -qx "Payload/$FULL_PRODUCT_NAME/Info.plist"; then
  echo "IPA is missing Payload/$FULL_PRODUCT_NAME/Info.plist" >&2
  exit 1
fi

echo "wrote $IPA_PATH"
