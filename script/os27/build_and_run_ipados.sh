#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

export KEIPIX_IPADOS_SIMULATOR_NAME="${KEIPIX_IPADOS_SIMULATOR_NAME:-KeiPix-iPadOS-OS27}"
export KEIPIX_IPADOS_SIMULATOR_RUNTIME="${KEIPIX_IPADOS_SIMULATOR_RUNTIME:-com.apple.CoreSimulator.SimRuntime.iOS-27-0}"
export KEIPIX_IPADOS_DEVICE_TYPE="${KEIPIX_IPADOS_DEVICE_TYPE:-com.apple.CoreSimulator.SimDeviceType.iPad-Pro-13-inch-M5-12GB}"
export KEIPIX_IPADOS_DERIVED_DATA_PATH="${KEIPIX_IPADOS_DERIVED_DATA_PATH:-$ROOT_DIR/.tmp/DerivedData-iPadOS-OS27-script}"
export KEIPIX_VERIFY_SETTLE_SECONDS="${KEIPIX_VERIFY_SETTLE_SECONDS:-45}"

exec "$ROOT_DIR/script/build_and_run_simulator.sh" ipados "$@"
