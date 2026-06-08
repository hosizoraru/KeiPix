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

human_size() {
  local path="$1"
  if [ -e "$path" ]; then
    du -sh "$path" 2>/dev/null | awk '{ print $1 }'
  else
    printf 'missing'
  fi
}

xcode_app="${KEIPIX_XCODE_APP_PATH:-}"
if [ -z "$xcode_app" ]; then
  xcode_app="$(selected_xcode_app_path || true)"
fi

documentation_selected="$(defaults read com.apple.dt.Xcode IDEDeveloperDocumentationSelectedDuringFirstLaunch 2>/dev/null || printf 'unknown')"
documentation_last_accessed="$(defaults read com.apple.dt.Xcode IDEDocumentationIndexedStoreLastAccessed 2>/dev/null || printf 'unknown')"
documentation_cache="$HOME/Library/Developer/Xcode/DocumentationCache"
documentation_index="$HOME/Library/Developer/Xcode/DocumentationIndex"
docc_path="$(xcrun --find docc 2>/dev/null || true)"

cat <<STATUS
Xcode app: ${xcode_app:-unknown}
$(xcodebuild -version 2>/dev/null || printf 'Xcode version: unknown')
docc: ${docc_path:-missing}
Developer Documentation selected during first launch: $documentation_selected
Documentation indexed store last accessed: $documentation_last_accessed
DocumentationCache: $documentation_cache ($(human_size "$documentation_cache"))
DocumentationIndex: $documentation_index ($(human_size "$documentation_index"))
CoreDocumentation.framework: $xcode_app/Contents/SharedFrameworks/CoreDocumentation.framework
DVTDocumentation.framework: $xcode_app/Contents/SharedFrameworks/DVTDocumentation.framework
DNTDocumentationModel.framework: $xcode_app/Contents/SharedFrameworks/DNTDocumentationModel.framework
DNTDocumentationSupport.framework: $xcode_app/Contents/SharedFrameworks/DNTDocumentationSupport.framework
IDEDocumentation.framework: $xcode_app/Contents/PlugIns/IDEDocumentation.framework
IDEDocumentationLivePreview.framework: $xcode_app/Contents/PlugIns/IDEDocumentationLivePreview.framework
STATUS

for framework in \
  "$xcode_app/Contents/SharedFrameworks/CoreDocumentation.framework" \
  "$xcode_app/Contents/SharedFrameworks/DVTDocumentation.framework" \
  "$xcode_app/Contents/SharedFrameworks/DNTDocumentationModel.framework" \
  "$xcode_app/Contents/SharedFrameworks/DNTDocumentationSupport.framework" \
  "$xcode_app/Contents/PlugIns/IDEDocumentation.framework" \
  "$xcode_app/Contents/PlugIns/IDEDocumentationLivePreview.framework"; do
  if [ ! -d "$framework" ]; then
    echo "Missing framework: $framework" >&2
    exit 1
  fi
done

if xcodebuild -showComponent DeveloperDocumentation -json >/dev/null 2>&1; then
  echo "xcodebuild component API: DeveloperDocumentation is supported"
else
  echo "xcodebuild component API: DeveloperDocumentation is not exposed yet"
fi
