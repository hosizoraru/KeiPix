#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<USAGE
usage: $0 <marketing-version> [build-number]

Examples:
  $0 0.27.0
  $0 1.2.2 10202

This updates Config/AppVersion.xcconfig and the XcodeGen build settings in
project.yml. If the matching git tag already exists, it also runs
script/check_version_consistency.sh.
USAGE
}

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
  usage
  exit 2
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MARKETING_VERSION="$1"

# shellcheck source=version_settings.sh
source "$ROOT_DIR/script/version_settings.sh"
keipix_validate_marketing_version "$MARKETING_VERSION"
if [ "$#" -eq 2 ]; then
  BUILD_NUMBER="$2"
else
  BUILD_NUMBER="$(keipix_version_code_from_marketing_version "$MARKETING_VERSION")"
fi
keipix_validate_build_number "$BUILD_NUMBER"

EXPECTED_BUILD_NUMBER="$(keipix_version_code_from_marketing_version "$MARKETING_VERSION")"
if [ "$BUILD_NUMBER" != "$EXPECTED_BUILD_NUMBER" ]; then
  echo "build number $BUILD_NUMBER does not match tag code $EXPECTED_BUILD_NUMBER for $MARKETING_VERSION" >&2
  exit 1
fi

version_config="$ROOT_DIR/Config/AppVersion.xcconfig"
tmp_file="$(mktemp)"
awk -F '=' -v marketing="$MARKETING_VERSION" -v build="$BUILD_NUMBER" '
  $1 ~ /^[[:space:]]*MARKETING_VERSION[[:space:]]*$/ {
    print "MARKETING_VERSION = " marketing
    next
  }
  $1 ~ /^[[:space:]]*CURRENT_PROJECT_VERSION[[:space:]]*$/ {
    print "CURRENT_PROJECT_VERSION = " build
    next
  }
  { print }
' "$version_config" > "$tmp_file"
mv "$tmp_file" "$version_config"

perl -0pi -e 's/(MARKETING_VERSION:\s*")[^"]+(")/${1}'"$MARKETING_VERSION"'${2}/' "$ROOT_DIR/project.yml"
perl -0pi -e 's/(CURRENT_PROJECT_VERSION:\s*")[^"]+(")/${1}'"$BUILD_NUMBER"'${2}/' "$ROOT_DIR/project.yml"
perl -0pi -e 's/(KEIPIX_BUILD_BASE_NUMBER:\s*")[^"]*(")/${1}'"$BUILD_NUMBER"'${2}/' "$ROOT_DIR/project.yml"
perl -0pi -e 's/(KEIPIX_BUILD_DISPLAY_NUMBER:\s*")[^"]*(")/${1}'"$BUILD_NUMBER"'${2}/' "$ROOT_DIR/project.yml"
perl -0pi -e 's/(KEIPIX_BUILD_IDENTITY:\s*")[^"]*(")/${1}v'"$MARKETING_VERSION"'${2}/' "$ROOT_DIR/project.yml"

latest_tag="$(keipix_latest_reachable_version_tag "$ROOT_DIR")"
if [ -z "$latest_tag" ] || [ "$latest_tag" = "v$MARKETING_VERSION" ]; then
  "$ROOT_DIR/script/check_version_consistency.sh"
else
  KEIPIX_BUILD_NUMBER_STRATEGY=config "$ROOT_DIR/script/version_settings.sh" --print-json >/dev/null
  echo "Updated version files to $MARKETING_VERSION ($BUILD_NUMBER)."
  echo "Create the matching tag before packaging: git tag -a v$MARKETING_VERSION -m \"KeiPix $MARKETING_VERSION\""
fi
