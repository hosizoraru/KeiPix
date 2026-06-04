#!/usr/bin/env bash
# Shared KeiPix version helpers for local scripts and CI.
#
# Source this file and call `keipix_load_version_settings "$ROOT_DIR"` to export:
#   KEIPIX_MARKETING_VERSION
#   KEIPIX_BUILD_NUMBER
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
  if [[ ! "$value" =~ ^[1-9][0-9]*(\.[0-9]+){0,2}$ ]]; then
    echo "CURRENT_PROJECT_VERSION must be one to three positive integer components, got: $value" >&2
    return 1
  fi
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
  export KEIPIX_BUILD_NUMBER="$build_number"
  export KEIPIX_VERSION_CONFIG="$config_file"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  keipix_load_version_settings "$ROOT_DIR"

  case "${1:---print-shell}" in
    --print-shell)
      printf 'KEIPIX_MARKETING_VERSION=%q\n' "$KEIPIX_MARKETING_VERSION"
      printf 'KEIPIX_BUILD_NUMBER=%q\n' "$KEIPIX_BUILD_NUMBER"
      ;;
    --print-json)
      printf '{"marketingVersion":"%s","buildNumber":"%s"}\n' "$KEIPIX_MARKETING_VERSION" "$KEIPIX_BUILD_NUMBER"
      ;;
    *)
      echo "usage: $0 [--print-shell|--print-json]" >&2
      exit 2
      ;;
  esac
fi
