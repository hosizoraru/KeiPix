#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 1 ]; then
  echo "usage: $0 <ios|ipados> [run|--build-only|--install-only|--logs|--verify|--help] [-- app-args...]" >&2
  exit 2
fi

PLATFORM_KEY="$1"
shift

MODE="${1:-run}"
if [ "$#" -gt 0 ]; then
  shift
fi

APP_ARGS=()
if [ "$MODE" = "--" ]; then
  MODE="run"
  APP_ARGS=("$@")
elif [ "$#" -gt 0 ] && [ "${1:-}" = "--" ]; then
  shift
  APP_ARGS=("$@")
elif [ "$#" -gt 0 ]; then
  APP_ARGS=("$@")
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/KeiPix.xcodeproj"
PROJECT_SPEC="$ROOT_DIR/project.yml"
CONFIGURATION="${KEIPIX_CONFIGURATION:-Debug}"
APP_NAME="KeiPix"

case "$PLATFORM_KEY" in
  ios)
    SCHEME="KeiPix iOS"
    BUNDLE_ID="com.keipix.client.ios"
    SIMULATOR_NAME="${KEIPIX_IOS_SIMULATOR_NAME:-KeiPix-iOS}"
    SIMULATOR_ID="${KEIPIX_SIMULATOR_ID:-${KEIPIX_IOS_SIMULATOR_ID:-}}"
    DEFAULT_DEVICE_TYPE="${KEIPIX_IOS_DEVICE_TYPE:-com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro}"
    DEVICE_FAMILY_LABEL="iPhone"
    DERIVED_DATA_PATH="${KEIPIX_DERIVED_DATA_PATH:-${KEIPIX_IOS_DERIVED_DATA_PATH:-$ROOT_DIR/.tmp/DerivedData-iOS-script}}"
    ;;
  ipados)
    SCHEME="KeiPix iPadOS"
    BUNDLE_ID="com.keipix.client.ipad"
    SIMULATOR_NAME="${KEIPIX_IPADOS_SIMULATOR_NAME:-KeiPix-iPadOS}"
    SIMULATOR_ID="${KEIPIX_SIMULATOR_ID:-${KEIPIX_IPADOS_SIMULATOR_ID:-}}"
    DEFAULT_DEVICE_TYPE="${KEIPIX_IPADOS_DEVICE_TYPE:-com.apple.CoreSimulator.SimDeviceType.iPad-Pro-13-inch-M5-12GB}"
    DEVICE_FAMILY_LABEL="iPad"
    DERIVED_DATA_PATH="${KEIPIX_DERIVED_DATA_PATH:-${KEIPIX_IPADOS_DERIVED_DATA_PATH:-$ROOT_DIR/.tmp/DerivedData-iPadOS-script}}"
    ;;
  *)
    echo "usage: $0 <ios|ipados> [run|--build-only|--install-only|--logs|--verify|--help] [-- app-args...]" >&2
    exit 2
    ;;
esac

usage() {
  cat <<USAGE
usage: $0 <ios|ipados> [run|--build-only|--install-only|--logs|--verify] [-- app-args...]

Modes:
  run            Generate the Xcode project if needed, build, install, and launch.
  --build-only   Generate and build, without booting or launching the simulator.
  --install-only Install and launch the latest built app from the derived data path.
  --logs         Launch, then stream unified logs for the app bundle id.
  --verify       Launch and print a simulator screenshot path for a quick smoke check.

Environment overrides:
  KEIPIX_CONFIGURATION=Debug|Release
  KEIPIX_SIMULATOR_ID=<udid>              Shared override for both platforms
  KEIPIX_IOS_SIMULATOR_ID=<udid>
  KEIPIX_IPADOS_SIMULATOR_ID=<udid>
  KEIPIX_IOS_SIMULATOR_NAME=KeiPix-iOS
  KEIPIX_IPADOS_SIMULATOR_NAME=KeiPix-iPadOS
  KEIPIX_IOS_DEVICE_TYPE=<simctl device type id>
  KEIPIX_IPADOS_DEVICE_TYPE=<simctl device type id>
  KEIPIX_DERIVED_DATA_PATH=<path>
  KEIPIX_VERIFY_SETTLE_SECONDS=3
  KEIPIX_XCODEBUILD_VERBOSE=1
USAGE
}

case "$MODE" in
  run|--build-only|build-only|--install-only|install-only|--logs|logs|--verify|verify)
    ;;
  --help|help|-h)
    usage
    exit 0
    ;;
  *)
    echo "unknown mode: $MODE" >&2
    usage >&2
    exit 2
    ;;
esac

cd "$ROOT_DIR"

ensure_xcode_project() {
  if [ ! -d "$PROJECT_PATH" ] || [ "$PROJECT_SPEC" -nt "$PROJECT_PATH/project.pbxproj" ]; then
    if ! command -v xcodegen >/dev/null 2>&1; then
      echo "KeiPix.xcodeproj is missing or stale. Install XcodeGen first: brew install xcodegen" >&2
      exit 1
    fi
    echo "==> Generating KeiPix.xcodeproj from project.yml"
    xcodegen generate >/dev/null
  fi
}

runtime_identifier() {
  xcrun simctl list runtimes | awk '
    /iOS .* - com.apple.CoreSimulator.SimRuntime.iOS/ && $0 !~ /unavailable/ {
      runtime = $NF
    }
    END {
      print runtime
    }
  '
}

device_type_exists() {
  xcrun simctl list devicetypes | grep -F "($1)" >/dev/null 2>&1
}

fallback_device_type() {
  local family="$1"
  xcrun simctl list devicetypes | awk -v family="$family" '
    index($0, family) > 0 {
      sub(/^.*\(/, "")
      sub(/\)$/, "")
      print
      exit
    }
  '
}

find_simulator_by_name() {
  local name="$1"
  local line
  line="$(
    xcrun simctl list devices \
      | grep -F "$name (" \
      | head -n 1 || true
  )"
  if [ -n "$line" ]; then
    printf '%s\n' "$line" | sed -nE 's/.*\(([0-9A-Fa-f-]{36})\).*/\1/p'
  fi
}

simulator_state() {
  local udid="$1"
  local line
  line="$(
    xcrun simctl list devices \
      | grep -F "($udid)" \
      | head -n 1 || true
  )"
  if [ -n "$line" ]; then
    printf '%s\n' "$line" | sed -nE 's/^.*\([0-9A-Fa-f-]{36}\) \(([^)]*)\).*$/\1/p'
  fi
}

ensure_simulator() {
  if [ -n "$SIMULATOR_ID" ]; then
    return
  fi

  SIMULATOR_ID="$(find_simulator_by_name "$SIMULATOR_NAME")"
  if [ -n "$SIMULATOR_ID" ]; then
    return
  fi

  local runtime
  runtime="$(runtime_identifier)"
  if [ -z "$runtime" ]; then
    echo "No available iOS Simulator runtime found. Install an iOS runtime in Xcode first." >&2
    exit 1
  fi

  local device_type="$DEFAULT_DEVICE_TYPE"
  if ! device_type_exists "$device_type"; then
    device_type="$(fallback_device_type "$DEVICE_FAMILY_LABEL")"
  fi
  if [ -z "$device_type" ]; then
    echo "No $DEVICE_FAMILY_LABEL simulator device type found." >&2
    exit 1
  fi

  echo "==> Creating $SIMULATOR_NAME ($device_type, $runtime)"
  SIMULATOR_ID="$(xcrun simctl create "$SIMULATOR_NAME" "$device_type" "$runtime")"
}

boot_simulator() {
  local state
  state="$(simulator_state "$SIMULATOR_ID")"
  if [ "$state" != "Booted" ]; then
    echo "==> Booting simulator $SIMULATOR_NAME ($SIMULATOR_ID)"
    xcrun simctl boot "$SIMULATOR_ID" >/dev/null 2>&1 || true
    echo "==> Waiting for simulator boot"
    xcrun simctl bootstatus "$SIMULATOR_ID" -b >/dev/null
  fi
  open -a Simulator --args -CurrentDeviceUDID "$SIMULATOR_ID" >/dev/null 2>&1 || true
}

build_app() {
  echo "==> Building $SCHEME ($CONFIGURATION)"
  if [ "${KEIPIX_XCODEBUILD_VERBOSE:-0}" = "1" ]; then
    xcodebuild \
      -project "$PROJECT_PATH" \
      -scheme "$SCHEME" \
      -configuration "$CONFIGURATION" \
      -destination "platform=iOS Simulator,id=$SIMULATOR_ID" \
      -derivedDataPath "$DERIVED_DATA_PATH" \
      build
  else
    xcodebuild \
      -quiet \
      -project "$PROJECT_PATH" \
      -scheme "$SCHEME" \
      -configuration "$CONFIGURATION" \
      -destination "platform=iOS Simulator,id=$SIMULATOR_ID" \
      -derivedDataPath "$DERIVED_DATA_PATH" \
      build
  fi
}

app_bundle_path() {
  local products_dir="$DERIVED_DATA_PATH/Build/Products/${CONFIGURATION}-iphonesimulator"
  if [ -d "$products_dir" ]; then
    find "$products_dir" \
      -maxdepth 1 \
      -name "$APP_NAME.app" \
      -print \
      -quit
  fi
}

install_app() {
  local app_bundle
  app_bundle="$(app_bundle_path)"
  if [ -z "$app_bundle" ] || [ ! -d "$app_bundle" ]; then
    echo "Could not find built app in $DERIVED_DATA_PATH. Run without --install-only first." >&2
    exit 1
  fi
  echo "==> Installing $app_bundle"
  xcrun simctl install "$SIMULATOR_ID" "$app_bundle"
}

launch_app() {
  echo "==> Launching $BUNDLE_ID"
  if [ "${#APP_ARGS[@]}" -gt 0 ]; then
    xcrun simctl launch --terminate-running-process "$SIMULATOR_ID" "$BUNDLE_ID" "${APP_ARGS[@]}"
  else
    xcrun simctl launch --terminate-running-process "$SIMULATOR_ID" "$BUNDLE_ID"
  fi
}

ensure_xcode_project
ensure_simulator

case "$MODE" in
  --build-only|build-only)
    build_app
    exit 0
    ;;
esac

boot_simulator

case "$MODE" in
  --install-only|install-only)
    install_app
    launch_app
    ;;
  run)
    build_app
    install_app
    launch_app
    ;;
  --verify|verify)
    build_app
    install_app
    launch_app
    SCREENSHOT_PATH="$ROOT_DIR/artifacts/simulator-${PLATFORM_KEY}-$(date -u +%Y%m%dT%H%M%SZ).png"
    mkdir -p "$(dirname "$SCREENSHOT_PATH")"
    echo "==> Waiting ${KEIPIX_VERIFY_SETTLE_SECONDS:-3}s for first frame on $SIMULATOR_NAME ($SIMULATOR_ID)"
    sleep "${KEIPIX_VERIFY_SETTLE_SECONDS:-3}"
    xcrun simctl io "$SIMULATOR_ID" screenshot "$SCREENSHOT_PATH" >/dev/null
    echo "==> Screenshot: $SCREENSHOT_PATH"
    ;;
  --logs|logs)
    build_app
    install_app
    launch_app
    echo "==> Streaming logs for subsystem == $BUNDLE_ID"
    xcrun simctl spawn "$SIMULATOR_ID" log stream --level=debug --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
esac
