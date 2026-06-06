#!/usr/bin/env bash

keipix_set_plist_string() {
  local plist_path="$1"
  local key="$2"
  local value="$3"

  /usr/libexec/PlistBuddy -c "Set :$key $value" "$plist_path" >/dev/null 2>&1 || \
    /usr/libexec/PlistBuddy -c "Add :$key string $value" "$plist_path" >/dev/null
}

keipix_compile_macos_app_icon() {
  local root_dir="$1"
  local resources_dir="$2"
  local minimum_system_version="$3"
  local info_plist="$4"
  local app_icon_name="${5:-keipixiv}"
  local icon_package="$root_dir/Sources/KeiPix/Resources/$app_icon_name.icon"
  local partial_plist
  local bundle_icon_file
  local bundle_icon_name

  if [ ! -d "$icon_package" ]; then
    echo "missing Icon Composer package: $icon_package" >&2
    exit 1
  fi

  mkdir -p "$resources_dir"
  partial_plist="$(mktemp "${TMPDIR:-/tmp}/keipix-icon-partial.XXXXXX.plist")"

  xcrun actool \
    --compile "$resources_dir" \
    --platform macosx \
    --minimum-deployment-target "$minimum_system_version" \
    --app-icon "$app_icon_name" \
    --output-partial-info-plist "$partial_plist" \
    "$icon_package" >/dev/null

  bundle_icon_file="$(/usr/libexec/PlistBuddy -c "Print :CFBundleIconFile" "$partial_plist")"
  bundle_icon_name="$(/usr/libexec/PlistBuddy -c "Print :CFBundleIconName" "$partial_plist")"
  rm -f "$partial_plist"

  if [ ! -f "$resources_dir/$bundle_icon_file.icns" ]; then
    echo "actool did not produce $resources_dir/$bundle_icon_file.icns" >&2
    exit 1
  fi

  keipix_set_plist_string "$info_plist" CFBundleIconFile "$bundle_icon_file"
  keipix_set_plist_string "$info_plist" CFBundleIconName "$bundle_icon_name"
}
