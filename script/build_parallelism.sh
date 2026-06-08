#!/usr/bin/env bash
# Shared build parallelism helpers for local scripts and CI.

keipix_resolve_build_jobs() {
  local requested="${1:-}"
  local detected=""

  if [ -n "$requested" ]; then
    case "$requested" in
      *[!0-9]*|0)
        echo "invalid build job count: $requested" >&2
        return 2
        ;;
      *)
        echo "$requested"
        return 0
        ;;
    esac
  fi

  if command -v sysctl >/dev/null 2>&1; then
    detected="$(sysctl -n hw.logicalcpu 2>/dev/null || true)"
  fi

  if [ -z "$detected" ] && command -v nproc >/dev/null 2>&1; then
    detected="$(nproc 2>/dev/null || true)"
  fi

  case "$detected" in
    *[!0-9]*|0|"") echo 4 ;;
    *) echo "$detected" ;;
  esac
}
