#!/usr/bin/env bash
set -euo pipefail

selected_xcode_app_path() {
  local developer_dir="${DEVELOPER_DIR:-}"
  if [ -z "$developer_dir" ]; then
    developer_dir="$(xcode-select -p 2>/dev/null || true)"
  fi

  case "$developer_dir" in
    */Contents/Developer)
      printf '%s\n' "${developer_dir%/Contents/Developer}"
      ;;
  esac
}

# Xcode 27 beta replaces the standalone Simulator window with Device Hub.
# `simctl` still owns boot/install/launch; this script only opens the UI shell.
SIMULATOR_ID="${1:-}"
if [ -z "$SIMULATOR_ID" ]; then
  exit 2
fi

xcode_app="${KEIPIX_XCODE_APP_PATH:-}"
if [ -z "$xcode_app" ]; then
  xcode_app="$(selected_xcode_app_path || true)"
fi

device_hub_app="${KEIPIX_DEVICE_HUB_APP:-}"
if [ -z "$device_hub_app" ] && [ -n "$xcode_app" ]; then
  device_hub_app="$xcode_app/Contents/Applications/DeviceHub.app"
fi

if [ -d "$device_hub_app" ]; then
  open "$device_hub_app"
  exit 0
fi

open -b com.apple.dt.Devices
