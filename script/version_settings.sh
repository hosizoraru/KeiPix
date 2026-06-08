#!/usr/bin/env bash
# Shared KeiPix version helpers for local scripts and CI.
#
# Source this file and call `keipix_load_version_settings "$ROOT_DIR"` to export:
#   KEIPIX_MARKETING_VERSION
#   KEIPIX_VERSION_NAME
#   KEIPIX_BUILD_NUMBER
#   KEIPIX_BUILD_VERSION
#   KEIPIX_VERSION_CODE
#   KEIPIX_CONFIG_BUILD_NUMBER
#   KEIPIX_BUILD_NUMBER_SOURCE
#   KEIPIX_BUILD_ANCHOR_TAG
#   KEIPIX_BUILD_COMMIT_COUNT
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
  if [[ ! "$value" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "MARKETING_VERSION must use x.y.z numeric form, got: $value" >&2
    return 1
  fi
}

keipix_validate_build_number() {
  local value="$1"
  if [[ ! "$value" =~ ^[1-9][0-9]*(\.(0|[1-9][0-9]{0,2})){0,2}$ ]]; then
    echo "CURRENT_PROJECT_VERSION must be one to three positive integer components; dotted components after the first must be 0-999, got: $value" >&2
    return 1
  fi
}

keipix_version_code_from_build_number() {
  local value="$1"
  IFS='.' read -r major minor patch _ <<< "$value"

  if [ -z "${minor:-}" ]; then
    printf '%s\n' "$major"
    return 0
  fi

  local code="$major"
  code=$((code * 1000 + minor))
  if [ -n "${patch:-}" ]; then
    code=$((code * 1000 + patch))
  fi
  printf '%s\n' "$code"
}

keipix_latest_reachable_version_tag() {
  local root_dir="$1"
  local marketing_version="$2"
  local exact_tag="v$marketing_version"

  if git -C "$root_dir" rev-parse -q --verify "refs/tags/$exact_tag" >/dev/null 2>&1 \
    && git -C "$root_dir" merge-base --is-ancestor "$exact_tag" HEAD >/dev/null 2>&1; then
    printf '%s\n' "$exact_tag"
    return 0
  fi

  git -C "$root_dir" describe --tags --match 'v[0-9]*' --abbrev=0 2>/dev/null || true
}

keipix_git_commit_count() {
  local root_dir="$1"
  local range="${2:-HEAD}"

  git -C "$root_dir" rev-list --count "$range" 2>/dev/null || printf '0\n'
}

keipix_resolve_build_number() {
  local root_dir="$1"
  local marketing_version="$2"
  local config_build_number="$3"
  local strategy="${KEIPIX_BUILD_NUMBER_STRATEGY:-config}"
  local anchor_tag
  local commit_count
  local config_build_code
  local build_number

  export KEIPIX_BUILD_ANCHOR_TAG=""
  export KEIPIX_BUILD_COMMIT_COUNT="0"

  if [ -n "${KEIPIX_BUILD_NUMBER_OVERRIDE:-}" ]; then
    keipix_validate_build_number "$KEIPIX_BUILD_NUMBER_OVERRIDE"
    export KEIPIX_BUILD_NUMBER="$KEIPIX_BUILD_NUMBER_OVERRIDE"
    export KEIPIX_BUILD_NUMBER_SOURCE="override"
    return 0
  fi

  case "$strategy" in
    config|"")
      export KEIPIX_BUILD_NUMBER="$config_build_number"
      export KEIPIX_BUILD_NUMBER_SOURCE="config"
      ;;
    git)
      config_build_code="$(keipix_version_code_from_build_number "$config_build_number")"
      anchor_tag="$(keipix_latest_reachable_version_tag "$root_dir" "$marketing_version")"
      if [ -n "$anchor_tag" ]; then
        commit_count="$(keipix_git_commit_count "$root_dir" "$anchor_tag..HEAD")"
        build_number=$((config_build_code + commit_count))
      else
        commit_count="$(keipix_git_commit_count "$root_dir" HEAD)"
        build_number="$commit_count"
        if [ "$build_number" -lt "$config_build_code" ]; then
          build_number="$config_build_code"
        fi
      fi

      export KEIPIX_BUILD_NUMBER="$build_number"
      export KEIPIX_BUILD_NUMBER_SOURCE="git"
      export KEIPIX_BUILD_ANCHOR_TAG="$anchor_tag"
      export KEIPIX_BUILD_COMMIT_COUNT="$commit_count"
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

  export KEIPIX_MARKETING_VERSION="$marketing_version"
  export KEIPIX_VERSION_NAME="$marketing_version"
  export KEIPIX_CONFIG_BUILD_NUMBER="$build_number"
  keipix_resolve_build_number "$root_dir" "$marketing_version" "$build_number"
  keipix_validate_build_number "$KEIPIX_BUILD_NUMBER"
  export KEIPIX_BUILD_NUMBER
  export KEIPIX_BUILD_VERSION="$KEIPIX_BUILD_NUMBER"
  export KEIPIX_VERSION_CODE
  KEIPIX_VERSION_CODE="$(keipix_version_code_from_build_number "$KEIPIX_BUILD_NUMBER")"
  export KEIPIX_VERSION_CONFIG="$config_file"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  keipix_load_version_settings "$ROOT_DIR"

  case "${1:---print-shell}" in
    --print-shell)
      printf 'KEIPIX_MARKETING_VERSION=%q\n' "$KEIPIX_MARKETING_VERSION"
      printf 'KEIPIX_VERSION_NAME=%q\n' "$KEIPIX_VERSION_NAME"
      printf 'KEIPIX_BUILD_NUMBER=%q\n' "$KEIPIX_BUILD_NUMBER"
      printf 'KEIPIX_BUILD_VERSION=%q\n' "$KEIPIX_BUILD_VERSION"
      printf 'KEIPIX_VERSION_CODE=%q\n' "$KEIPIX_VERSION_CODE"
      printf 'KEIPIX_CONFIG_BUILD_NUMBER=%q\n' "$KEIPIX_CONFIG_BUILD_NUMBER"
      printf 'KEIPIX_BUILD_NUMBER_SOURCE=%q\n' "$KEIPIX_BUILD_NUMBER_SOURCE"
      printf 'KEIPIX_BUILD_ANCHOR_TAG=%q\n' "$KEIPIX_BUILD_ANCHOR_TAG"
      printf 'KEIPIX_BUILD_COMMIT_COUNT=%q\n' "$KEIPIX_BUILD_COMMIT_COUNT"
      ;;
    --print-json)
      printf '{"marketingVersion":"%s","versionName":"%s","buildNumber":"%s","buildVersion":"%s","versionCode":%s,"configBuildNumber":"%s","buildNumberSource":"%s","buildAnchorTag":"%s","buildCommitCount":%s}\n' \
        "$KEIPIX_MARKETING_VERSION" \
        "$KEIPIX_VERSION_NAME" \
        "$KEIPIX_BUILD_NUMBER" \
        "$KEIPIX_BUILD_VERSION" \
        "$KEIPIX_VERSION_CODE" \
        "$KEIPIX_CONFIG_BUILD_NUMBER" \
        "$KEIPIX_BUILD_NUMBER_SOURCE" \
        "$KEIPIX_BUILD_ANCHOR_TAG" \
        "$KEIPIX_BUILD_COMMIT_COUNT"
      ;;
    *)
      echo "usage: $0 [--print-shell|--print-json]" >&2
      exit 2
      ;;
  esac
fi
