#!/usr/bin/env bash
# Shared KeiPix version helpers for local scripts and CI.
#
# Source this file and call `keipix_load_version_settings "$ROOT_DIR"` to export:
#   KEIPIX_MARKETING_VERSION
#   KEIPIX_VERSION_NAME
#   KEIPIX_CONFIG_MARKETING_VERSION
#   KEIPIX_BUILD_NUMBER
#   KEIPIX_BUILD_VERSION
#   KEIPIX_VERSION_CODE
#   KEIPIX_CONFIG_BUILD_NUMBER
#   KEIPIX_BUILD_NUMBER_SOURCE
#   KEIPIX_BUILD_ANCHOR_TAG
#   KEIPIX_BUILD_COMMIT_COUNT
#   KEIPIX_BUILD_BASE_NUMBER
#   KEIPIX_BUILD_DISPLAY_NUMBER
#   KEIPIX_BUILD_IDENTITY
#   KEIPIX_GIT_COMMIT
#   KEIPIX_GIT_SHORT_COMMIT
#   KEIPIX_GIT_DIRTY
#   KEIPIX_GIT_DESCRIBE
#   KEIPIX_VERSION_CONFIG
set -euo pipefail

keipix_read_xcconfig_setting() {
  local config_file="$1"
  local key="$2"

  awk -F '=' -v key="$key" '
    $1 ~ "^[[:space:]]*" key "[[:space:]]*$" {
      value = $2
      sub(/[[:space:]]*\/\/.*$/, "", value)
      sub(/[[:space:]]*#.*/, "", value)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
      print value
      exit
    }
  ' "$config_file"
}

keipix_validate_marketing_version() {
  local value="$1"
  if [[ ! "$value" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]]; then
    echo "MARKETING_VERSION must use x.y.z numeric form without leading zero components, got: $value" >&2
    return 1
  fi
}

keipix_validate_build_number() {
  local value="$1"
  if [[ ! "$value" =~ ^[1-9][0-9]*$ ]]; then
    echo "CURRENT_PROJECT_VERSION must be a positive integer tag code, got: $value" >&2
    return 1
  fi
}

keipix_version_code_from_marketing_version() {
  local value="$1"
  local major minor patch _

  keipix_validate_marketing_version "$value"
  IFS='.' read -r major minor patch _ <<< "$value"

  major=$((10#$major))
  minor=$((10#$minor))
  patch=$((10#$patch))

  if [ "$minor" -gt 99 ] || [ "$patch" -gt 99 ]; then
    echo "versionCode layout supports minor and patch components from 0 to 99, got: $value" >&2
    return 1
  fi

  local code=$((major * 10000 + minor * 100 + patch))
  if [ "$code" -le 0 ]; then
    echo "versionCode must be positive, got $code from $value" >&2
    return 1
  fi

  printf '%s\n' "$code"
}

keipix_latest_reachable_version_tag() {
  local root_dir="$1"
  git -C "$root_dir" describe --tags --match 'v[0-9]*.[0-9]*.[0-9]*' --abbrev=0 2>/dev/null || true
}

keipix_git_commit_count() {
  local root_dir="$1"
  local range="${2:-HEAD}"

  git -C "$root_dir" rev-list --count "$range" 2>/dev/null || printf '0\n'
}

keipix_resolve_git_metadata() {
  local root_dir="$1"
  local git_status

  export KEIPIX_GIT_COMMIT=""
  export KEIPIX_GIT_SHORT_COMMIT=""
  export KEIPIX_GIT_DIRTY="NO"
  export KEIPIX_GIT_DESCRIBE=""

  if ! git -C "$root_dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    return 0
  fi

  KEIPIX_GIT_COMMIT="$(git -C "$root_dir" rev-parse HEAD 2>/dev/null || true)"
  KEIPIX_GIT_SHORT_COMMIT="$(git -C "$root_dir" rev-parse --short=12 HEAD 2>/dev/null || true)"
  KEIPIX_GIT_DESCRIBE="$(git -C "$root_dir" describe --tags --match 'v[0-9]*' --always 2>/dev/null || true)"
  if [ -z "$KEIPIX_GIT_DESCRIBE" ]; then
    KEIPIX_GIT_DESCRIBE="$KEIPIX_GIT_SHORT_COMMIT"
  fi

  git_status="$(git -C "$root_dir" status --porcelain --untracked-files=normal 2>/dev/null || true)"
  if [ -n "$git_status" ]; then
    KEIPIX_GIT_DIRTY="YES"
  fi

  export KEIPIX_GIT_COMMIT
  export KEIPIX_GIT_SHORT_COMMIT
  export KEIPIX_GIT_DIRTY
  export KEIPIX_GIT_DESCRIBE
}

keipix_resolve_build_number() {
  local root_dir="$1"
  local marketing_version="$2"
  local config_build_number="$3"
  local strategy="${KEIPIX_BUILD_NUMBER_STRATEGY:-git}"
  local anchor_tag
  local commit_count
  local build_version
  local identity_anchor
  local version_code

  export KEIPIX_BUILD_ANCHOR_TAG=""
  export KEIPIX_BUILD_COMMIT_COUNT="0"
  export KEIPIX_BUILD_BASE_NUMBER="0"
  export KEIPIX_BUILD_DISPLAY_NUMBER=""
  export KEIPIX_BUILD_IDENTITY=""
  export KEIPIX_EFFECTIVE_MARKETING_VERSION="$marketing_version"

  anchor_tag="$(keipix_latest_reachable_version_tag "$root_dir")"
  if [ -n "$anchor_tag" ]; then
    build_version="${anchor_tag#v}"
    keipix_validate_marketing_version "$build_version"
    commit_count="$(keipix_git_commit_count "$root_dir" "$anchor_tag..HEAD")"
    identity_anchor="$anchor_tag"
  else
    build_version="$marketing_version"
    commit_count="$(keipix_git_commit_count "$root_dir" HEAD)"
    identity_anchor="v$marketing_version"
  fi
  export KEIPIX_BUILD_ANCHOR_TAG="$anchor_tag"
  export KEIPIX_BUILD_COMMIT_COUNT="$commit_count"

  if [ -n "${KEIPIX_BUILD_NUMBER_OVERRIDE:-}" ]; then
    keipix_validate_build_number "$KEIPIX_BUILD_NUMBER_OVERRIDE"
    export KEIPIX_BUILD_NUMBER="$KEIPIX_BUILD_NUMBER_OVERRIDE"
    export KEIPIX_BUILD_NUMBER_SOURCE="override"
    export KEIPIX_BUILD_BASE_NUMBER="$KEIPIX_BUILD_NUMBER_OVERRIDE"
    export KEIPIX_BUILD_DISPLAY_NUMBER="$KEIPIX_BUILD_NUMBER_OVERRIDE"
    if [ "$commit_count" -gt 0 ]; then
      export KEIPIX_BUILD_IDENTITY="$identity_anchor+$commit_count"
    else
      export KEIPIX_BUILD_IDENTITY="$identity_anchor"
    fi
    return 0
  fi

  case "$strategy" in
    config|"")
      version_code="$(keipix_version_code_from_marketing_version "$marketing_version")"
      if [ "$config_build_number" != "$version_code" ]; then
        echo "CURRENT_PROJECT_VERSION ($config_build_number) must match MARKETING_VERSION tag code ($version_code)" >&2
        return 1
      fi
      export KEIPIX_BUILD_NUMBER_SOURCE="config"
      export KEIPIX_BUILD_NUMBER="$version_code"
      export KEIPIX_BUILD_BASE_NUMBER="$version_code"
      export KEIPIX_BUILD_DISPLAY_NUMBER="$version_code"
      export KEIPIX_BUILD_IDENTITY="v$marketing_version"
      ;;
    git)
      version_code="$(keipix_version_code_from_marketing_version "$build_version")"
      export KEIPIX_BUILD_NUMBER="$version_code"
      if [ -n "$anchor_tag" ]; then
        export KEIPIX_BUILD_NUMBER_SOURCE="tag"
      else
        export KEIPIX_BUILD_NUMBER_SOURCE="config"
      fi
      export KEIPIX_EFFECTIVE_MARKETING_VERSION="$build_version"
      export KEIPIX_BUILD_BASE_NUMBER="$version_code"
      export KEIPIX_BUILD_DISPLAY_NUMBER="$version_code"
      if [ "$commit_count" -gt 0 ]; then
        export KEIPIX_BUILD_IDENTITY="$identity_anchor+$commit_count"
      else
        export KEIPIX_BUILD_IDENTITY="$identity_anchor"
      fi
      ;;
    *)
      echo "KEIPIX_BUILD_NUMBER_STRATEGY must be config or git, got: $strategy" >&2
      return 1
      ;;
  esac
}

keipix_load_version_settings() {
  local root_dir="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
  local config_file="$root_dir/Config/AppVersion.xcconfig"

  if [ ! -f "$config_file" ]; then
    echo "missing version config: $config_file" >&2
    return 1
  fi

  local marketing_version
  local build_number
  marketing_version="$(keipix_read_xcconfig_setting "$config_file" MARKETING_VERSION)"
  build_number="$(keipix_read_xcconfig_setting "$config_file" CURRENT_PROJECT_VERSION)"

  if [ -z "$marketing_version" ] || [ -z "$build_number" ]; then
    echo "version config must define MARKETING_VERSION and CURRENT_PROJECT_VERSION" >&2
    return 1
  fi

  keipix_validate_marketing_version "$marketing_version"
  keipix_validate_build_number "$build_number"

  export KEIPIX_CONFIG_MARKETING_VERSION="$marketing_version"
  export KEIPIX_CONFIG_BUILD_NUMBER="$build_number"
  keipix_resolve_build_number "$root_dir" "$marketing_version" "$build_number"
  export KEIPIX_MARKETING_VERSION="$KEIPIX_EFFECTIVE_MARKETING_VERSION"
  export KEIPIX_VERSION_NAME="$KEIPIX_MARKETING_VERSION"
  keipix_validate_build_number "$KEIPIX_BUILD_NUMBER"
  export KEIPIX_BUILD_NUMBER
  export KEIPIX_BUILD_VERSION="$KEIPIX_BUILD_NUMBER"
  export KEIPIX_VERSION_CODE
  KEIPIX_VERSION_CODE="$KEIPIX_BUILD_NUMBER"
  export KEIPIX_VERSION_CONFIG="$config_file"
  keipix_resolve_git_metadata "$root_dir"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  keipix_load_version_settings "$ROOT_DIR"

  case "${1:---print-shell}" in
    --print-shell)
      printf 'KEIPIX_MARKETING_VERSION=%q\n' "$KEIPIX_MARKETING_VERSION"
      printf 'KEIPIX_VERSION_NAME=%q\n' "$KEIPIX_VERSION_NAME"
      printf 'KEIPIX_CONFIG_MARKETING_VERSION=%q\n' "$KEIPIX_CONFIG_MARKETING_VERSION"
      printf 'KEIPIX_BUILD_NUMBER=%q\n' "$KEIPIX_BUILD_NUMBER"
      printf 'KEIPIX_BUILD_VERSION=%q\n' "$KEIPIX_BUILD_VERSION"
      printf 'KEIPIX_VERSION_CODE=%q\n' "$KEIPIX_VERSION_CODE"
      printf 'KEIPIX_CONFIG_BUILD_NUMBER=%q\n' "$KEIPIX_CONFIG_BUILD_NUMBER"
      printf 'KEIPIX_BUILD_NUMBER_SOURCE=%q\n' "$KEIPIX_BUILD_NUMBER_SOURCE"
      printf 'KEIPIX_BUILD_ANCHOR_TAG=%q\n' "$KEIPIX_BUILD_ANCHOR_TAG"
      printf 'KEIPIX_BUILD_COMMIT_COUNT=%q\n' "$KEIPIX_BUILD_COMMIT_COUNT"
      printf 'KEIPIX_BUILD_BASE_NUMBER=%q\n' "$KEIPIX_BUILD_BASE_NUMBER"
      printf 'KEIPIX_BUILD_DISPLAY_NUMBER=%q\n' "$KEIPIX_BUILD_DISPLAY_NUMBER"
      printf 'KEIPIX_BUILD_IDENTITY=%q\n' "$KEIPIX_BUILD_IDENTITY"
      printf 'KEIPIX_GIT_COMMIT=%q\n' "$KEIPIX_GIT_COMMIT"
      printf 'KEIPIX_GIT_SHORT_COMMIT=%q\n' "$KEIPIX_GIT_SHORT_COMMIT"
      printf 'KEIPIX_GIT_DIRTY=%q\n' "$KEIPIX_GIT_DIRTY"
      printf 'KEIPIX_GIT_DESCRIBE=%q\n' "$KEIPIX_GIT_DESCRIBE"
      ;;
    --print-json)
      git_dirty_json=false
      if [ "$KEIPIX_GIT_DIRTY" = "YES" ]; then
        git_dirty_json=true
      fi
      printf '{"marketingVersion":"%s","versionName":"%s","buildNumber":"%s","buildVersion":"%s","versionCode":%s,"configMarketingVersion":"%s","configBuildNumber":"%s","buildNumberSource":"%s","buildAnchorTag":"%s","buildCommitCount":%s,"buildBaseNumber":%s,"buildDisplayNumber":"%s","buildIdentity":"%s","gitCommit":"%s","gitShortCommit":"%s","gitDirty":%s,"gitDescribe":"%s"}\n' \
        "$KEIPIX_MARKETING_VERSION" \
        "$KEIPIX_VERSION_NAME" \
        "$KEIPIX_BUILD_NUMBER" \
        "$KEIPIX_BUILD_VERSION" \
        "$KEIPIX_VERSION_CODE" \
        "$KEIPIX_CONFIG_MARKETING_VERSION" \
        "$KEIPIX_CONFIG_BUILD_NUMBER" \
        "$KEIPIX_BUILD_NUMBER_SOURCE" \
        "$KEIPIX_BUILD_ANCHOR_TAG" \
        "$KEIPIX_BUILD_COMMIT_COUNT" \
        "$KEIPIX_BUILD_BASE_NUMBER" \
        "$KEIPIX_BUILD_DISPLAY_NUMBER" \
        "$KEIPIX_BUILD_IDENTITY" \
        "$KEIPIX_GIT_COMMIT" \
        "$KEIPIX_GIT_SHORT_COMMIT" \
        "$git_dirty_json" \
        "$KEIPIX_GIT_DESCRIBE"
      ;;
    *)
      echo "usage: $0 [--print-shell|--print-json]" >&2
      exit 2
      ;;
  esac
fi
