#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<USAGE
usage: $0 <marketing-version> <build-number>

Examples:
  $0 0.2.0 2
  $0 1.0.0 100

This updates Config/AppVersion.xcconfig and the XcodeGen build settings in
project.yml, then runs script/check_version_consistency.sh.
USAGE
}

if [ "$#" -ne 2 ]; then
  usage
  exit 2
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MARKETING_VERSION="$1"
BUILD_NUMBER="$2"

# shellcheck source=version_settings.sh
source "$ROOT_DIR/script/version_settings.sh"
keipix_validate_marketing_version "$MARKETING_VERSION"
keipix_validate_build_number "$BUILD_NUMBER"

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

"$ROOT_DIR/script/check_version_consistency.sh"
