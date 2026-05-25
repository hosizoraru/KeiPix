#!/usr/bin/env bash
set -euo pipefail

APP_NAME="KeiPix"
SURFACE="${1:-manual}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STAMP="$(date -u +"%Y%m%dT%H%M%SZ")"
OUTPUT_DIR="$ROOT_DIR/artifacts/visual-qa/$STAMP"
SCREENSHOT_PATH="$OUTPUT_DIR/${SURFACE}.png"
MANIFEST_PATH="$OUTPUT_DIR/${SURFACE}.md"

mkdir -p "$OUTPUT_DIR"

WINDOW_ID="$(
  /usr/bin/swift - "$APP_NAME" <<'SWIFT'
import CoreGraphics
import Foundation

let appName = CommandLine.arguments.dropFirst().first ?? "KeiPix"
let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
let ownerKey = kCGWindowOwnerName as String
let numberKey = kCGWindowNumber as String
let layerKey = kCGWindowLayer as String
let boundsKey = kCGWindowBounds as String

let candidates = windows.compactMap { window -> (id: Int, area: Double)? in
    guard window[ownerKey] as? String == appName,
          (window[layerKey] as? Int) == 0,
          let id = window[numberKey] as? Int,
          let bounds = window[boundsKey] as? [String: Any],
          let width = bounds["Width"] as? Double,
          let height = bounds["Height"] as? Double,
          width >= 240,
          height >= 240
    else {
        return nil
    }
    return (id, width * height)
}

if let window = candidates.sorted(by: { $0.area > $1.area }).first {
    print(window.id)
}
SWIFT
)"

if [[ -z "$WINDOW_ID" ]]; then
  echo "Unable to find an on-screen KeiPix window. Launch KeiPix and try again." >&2
  exit 1
fi

SCREEN_CAPTURE_BIN="/usr/sbin/screencapture"
if [[ ! -x "$SCREEN_CAPTURE_BIN" ]]; then
  SCREEN_CAPTURE_BIN="$(command -v screencapture || true)"
fi
if [[ -z "$SCREEN_CAPTURE_BIN" ]]; then
  echo "Unable to find screencapture on this system." >&2
  exit 1
fi

"$SCREEN_CAPTURE_BIN" -x -l "$WINDOW_ID" "$SCREENSHOT_PATH"

GIT_COMMIT="$(git -C "$ROOT_DIR" rev-parse --short HEAD 2>/dev/null || true)"
APP_PID="$(pgrep -x "$APP_NAME" | head -1 || true)"

cat >"$MANIFEST_PATH" <<MANIFEST
# KeiPix Visual QA

- Captured at: $STAMP
- Surface: $SURFACE
- App: $APP_NAME
- PID: ${APP_PID:-unknown}
- Window ID: $WINDOW_ID
- Git commit: ${GIT_COMMIT:-unknown}
- Screenshot: $(basename "$SCREENSHOT_PATH")

Checklist:
- No overlapping cards or controls.
- No unexpected gray gutters around image cards.
- Wide and tall images keep stable positions.
- Text remains readable and clipped only where intended.
- Native in-app routes remain visible for the current surface.
MANIFEST

echo "$SCREENSHOT_PATH"
echo "$MANIFEST_PATH"
