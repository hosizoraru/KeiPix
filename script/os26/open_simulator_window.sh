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

SIMULATOR_ID="${1:-}"
if [ -z "$SIMULATOR_ID" ]; then
  exit 2
fi

xcode_app="${KEIPIX_XCODE_APP_PATH:-}"
if [ -z "$xcode_app" ]; then
  xcode_app="$(selected_xcode_app_path || true)"
fi

simulator_app="${KEIPIX_SIMULATOR_APP:-}"
if [ -n "$simulator_app" ] && [ -d "$simulator_app" ]; then
  open "$simulator_app" --args -CurrentDeviceUDID "$SIMULATOR_ID"
  exit 0
fi

for candidate in \
  "${xcode_app:+$xcode_app/Contents/Developer/Applications/Simulator.app}" \
  "${xcode_app:+$xcode_app/Contents/Applications/Simulator.app}" \
  "/Applications/Xcode.app/Contents/Developer/Applications/Simulator.app" \
  "/Applications/Xcode.app/Contents/Applications/Simulator.app" \
  "/Applications/Xcode-beta.app/Contents/Developer/Applications/Simulator.app" \
  "/Applications/Xcode-beta.app/Contents/Applications/Simulator.app"; do
  if [ -n "$candidate" ] && [ -d "$candidate" ]; then
    open "$candidate" --args -CurrentDeviceUDID "$SIMULATOR_ID"
    exit 0
  fi
done

open -b com.apple.iphonesimulator --args -CurrentDeviceUDID "$SIMULATOR_ID"
