#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

export KEIPIX_IOS_SIMULATOR_NAME="${KEIPIX_IOS_SIMULATOR_NAME:-KeiPix-iOS-OS27}"
export KEIPIX_IOS_SIMULATOR_RUNTIME="${KEIPIX_IOS_SIMULATOR_RUNTIME:-com.apple.CoreSimulator.SimRuntime.iOS-27-0}"
export KEIPIX_IOS_DEVICE_TYPE="${KEIPIX_IOS_DEVICE_TYPE:-com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro}"
export KEIPIX_IOS_DERIVED_DATA_PATH="${KEIPIX_IOS_DERIVED_DATA_PATH:-$ROOT_DIR/.tmp/DerivedData-iOS-OS27-script}"
export KEIPIX_VERIFY_SETTLE_SECONDS="${KEIPIX_VERIFY_SETTLE_SECONDS:-45}"

exec "$ROOT_DIR/script/build_and_run_simulator.sh" ios "$@"
