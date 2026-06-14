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

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ARTIFACT_DIR="${KEIPIX_OS27_ARTIFACT_DIR:-$ROOT_DIR/artifacts/os27}"
TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
DEVICE_ID="${1:-${KEIPIX_SIMULATOR_ID:-${KEIPIX_IOS_SIMULATOR_ID:-}}}"

mkdir -p "$ARTIFACT_DIR"

xcode_app="${KEIPIX_XCODE_APP_PATH:-}"
if [ -z "$xcode_app" ]; then
  xcode_app="$(selected_xcode_app_path || true)"
fi

device_hub_app="${KEIPIX_DEVICE_HUB_APP:-}"
if [ -z "$device_hub_app" ] && [ -n "$xcode_app" ]; then
  device_hub_app="$xcode_app/Contents/Applications/DeviceHub.app"
fi

echo "Xcode app: ${xcode_app:-unresolved}"
echo "Device Hub: ${device_hub_app:-unresolved}"
if [ -d "${device_hub_app:-}" ]; then
  /usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$device_hub_app/Contents/Info.plist" 2>/dev/null | sed 's/^/Device Hub bundle: /' || true
  /usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$device_hub_app/Contents/Info.plist" 2>/dev/null | sed 's/^/Device Hub executable: /' || true
fi

echo "DeviceKit/CoreDevice frameworks:"
if [ -n "$xcode_app" ]; then
  for framework in \
    "$xcode_app/Contents/SharedFrameworks/DeviceKit.framework" \
    "$xcode_app/Contents/SharedFrameworks/DVTDeviceKit.framework" \
    "$xcode_app/Contents/SharedFrameworks/DTDeviceKit.framework" \
    "$xcode_app/Contents/SharedFrameworks/DTDeviceKitBase.framework" \
    "$xcode_app/Contents/SharedFrameworks/DVTCoreDeviceCore.framework" \
    "/Library/Developer/PrivateFrameworks/CoreDevice.framework"; do
    if [ -d "$framework" ]; then
      echo "  present: $framework"
    else
      echo "  missing: $framework"
    fi
  done
fi

devicectl_path="$(xcrun --find devicectl 2>/dev/null || true)"
if [ -z "$devicectl_path" ]; then
  echo "devicectl: unavailable"
  exit 0
fi
echo "devicectl: $devicectl_path"
echo "devicectl version: $(xcrun devicectl --version 2>/dev/null || echo unknown)"

devices_json="$ARTIFACT_DIR/devices-$TIMESTAMP.json"
xcrun devicectl list devices --json-output "$devices_json" --timeout 15 >/dev/null
echo "CoreDevice devices JSON: $devices_json"

if command -v jq >/dev/null 2>&1; then
  jq -r '
    .result.devices[]
    | [
        .deviceProperties.name,
        .hardwareProperties.udid,
        .deviceProperties.osVersionNumber,
        .hardwareProperties.platform,
        .hardwareProperties.reality,
        .deviceProperties.bootState
      ]
    | @tsv
  ' "$devices_json" \
    | awk -F '\t' 'BEGIN { print "CoreDevice devices:" } { printf "  %s (%s) %s %s %s boot=%s\n", $1, $2, $3, $4, $5, $6 }'
fi

if [ -n "$DEVICE_ID" ]; then
  displays_json="$ARTIFACT_DIR/displays-$DEVICE_ID-$TIMESTAMP.json"
  if xcrun devicectl device info displays --device "$DEVICE_ID" --json-output "$displays_json" --timeout 15 >/dev/null; then
    echo "Display JSON: $displays_json"
    if command -v jq >/dev/null 2>&1; then
      jq -r '
        .result.displays[]
        | [
            .name,
            .uniqueId,
            (.primary | tostring),
            (.nativeSize | join("x")),
            (.pointScale | tostring),
            .currentOrientation
          ]
        | @tsv
      ' "$displays_json" \
        | awk -F '\t' 'BEGIN { print "Displays:" } { printf "  %s uniqueId=%s primary=%s size=%s scale=%s orientation=%s\n", $1, $2, $3, $4, $5, $6 }'
    fi
  fi
fi
