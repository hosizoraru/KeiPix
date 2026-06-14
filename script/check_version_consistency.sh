#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# shellcheck source=version_settings.sh
source "$ROOT_DIR/script/version_settings.sh"
keipix_load_version_settings "$ROOT_DIR"

read_project_setting() {
  local key="$1"
  sed -nE "s/^[[:space:]]*${key}:[[:space:]]*\"?([^\"[:space:]]+)\"?.*$/\1/p" "$ROOT_DIR/project.yml" | head -n 1
}

expect_file_contains() {
  local file="$1"
  local needle="$2"
  if ! grep -Fq "$needle" "$ROOT_DIR/$file"; then
    echo "$file does not contain expected text: $needle" >&2
    exit 1
  fi
}

project_marketing="$(read_project_setting MARKETING_VERSION)"
project_build="$(read_project_setting CURRENT_PROJECT_VERSION)"

if [ "$project_marketing" != "$KEIPIX_CONFIG_MARKETING_VERSION" ]; then
  echo "project.yml MARKETING_VERSION ($project_marketing) does not match $KEIPIX_VERSION_CONFIG ($KEIPIX_CONFIG_MARKETING_VERSION)" >&2
  exit 1
fi

if [ "$project_build" != "$KEIPIX_CONFIG_BUILD_NUMBER" ]; then
  echo "project.yml CURRENT_PROJECT_VERSION ($project_build) does not match $KEIPIX_VERSION_CONFIG ($KEIPIX_CONFIG_BUILD_NUMBER)" >&2
  exit 1
fi

if [ -n "$KEIPIX_BUILD_ANCHOR_TAG" ] && [ "$KEIPIX_CONFIG_MARKETING_VERSION" != "$KEIPIX_MARKETING_VERSION" ]; then
  echo "$KEIPIX_VERSION_CONFIG MARKETING_VERSION ($KEIPIX_CONFIG_MARKETING_VERSION) does not match latest reachable version tag $KEIPIX_BUILD_ANCHOR_TAG ($KEIPIX_MARKETING_VERSION)" >&2
  echo "run ./script/set_app_version.sh $KEIPIX_MARKETING_VERSION before tagging or packaging" >&2
  exit 1
fi

expected_config_build="$(keipix_version_code_from_marketing_version "$KEIPIX_CONFIG_MARKETING_VERSION")"
if [ "$KEIPIX_CONFIG_BUILD_NUMBER" != "$expected_config_build" ]; then
  echo "$KEIPIX_VERSION_CONFIG CURRENT_PROJECT_VERSION ($KEIPIX_CONFIG_BUILD_NUMBER) must be the tag code for $KEIPIX_CONFIG_MARKETING_VERSION ($expected_config_build)" >&2
  exit 1
fi

for plist in App/Info.plist App/Info-iOS.plist App/Info-iPadOS.plist; do
  expect_file_contains "$plist" '<key>CFBundleShortVersionString</key>'
  expect_file_contains "$plist" '<string>$(MARKETING_VERSION)</string>'
  expect_file_contains "$plist" '<key>CFBundleVersion</key>'
  expect_file_contains "$plist" '<string>$(CURRENT_PROJECT_VERSION)</string>'
done

expect_file_contains script/build_and_run.sh "version_settings.sh"
expect_file_contains script/build_release_app.sh "version_settings.sh"
expect_file_contains script/build_unsigned_ipa.sh "version_settings.sh"
expect_file_contains script/generate_livecontainer_apps_nightly.sh "version_settings.sh"
expect_file_contains script/generate_livecontainer_apps_nightly.sh "KEIPIX_VERSION_NAME"
expect_file_contains script/generate_livecontainer_apps_nightly.sh "KEIPIX_VERSION_CODE"
expect_file_contains script/generate_livecontainer_apps_nightly.sh "KEIPIX_BUILD_DISPLAY_NUMBER"
expect_file_contains script/generate_livecontainer_apps_nightly.sh "KEIPIX_BUILD_IDENTITY"
expect_file_contains .github/workflows/macos-build.yml "script/version_settings.sh"
expect_file_contains .github/workflows/macos-build.yml "script/generate_livecontainer_apps_nightly.sh"
expect_file_contains .github/workflows/macos-build.yml "apps_nightly.json"

jq empty "$ROOT_DIR/apps_nightly.json"
jq -e \
  --arg version "$KEIPIX_VERSION_NAME" \
  --arg build "$KEIPIX_BUILD_NUMBER" \
  --arg build_display "$KEIPIX_BUILD_DISPLAY_NUMBER" \
  --arg build_identity_prefix "${KEIPIX_BUILD_ANCHOR_TAG:-v$KEIPIX_VERSION_NAME}" \
  --argjson code "$KEIPIX_VERSION_CODE" \
  '
    .identifier == "com.keipix.source.nightly"
    and (.sourceURL | endswith("/releases/download/nightly/apps_nightly.json"))
    and ((.apps[] | select(.bundleIdentifier == "com.keipix.client.ios") | .versionName) == $version)
    and ((.apps[] | select(.bundleIdentifier == "com.keipix.client.ios") | .versionCode) == $code)
    and ((.apps[] | select(.bundleIdentifier == "com.keipix.client.ios") | .buildNumber) == $build)
    and ((.apps[] | select(.bundleIdentifier == "com.keipix.client.ios") | .buildDisplayNumber) == $build_display)
    and ((.apps[] | select(.bundleIdentifier == "com.keipix.client.ios") | .buildIdentity) | startswith($build_identity_prefix))
    and ((.apps[] | select(.bundleIdentifier == "com.keipix.client.ios") | .versions[0].buildNumber) == $build)
    and ((.apps[] | select(.bundleIdentifier == "com.keipix.client.ios") | .versions[0].buildDisplayNumber) == $build_display)
    and ((.apps[] | select(.bundleIdentifier == "com.keipix.client.ios") | .versions[0].buildIdentity) | startswith($build_identity_prefix))
    and ((.apps[] | select(.bundleIdentifier == "com.keipix.client.ios") | .downloadURL) | endswith("/releases/download/nightly/KeiPix-iOS-\($version)-build.\($build)-unsigned.ipa"))
    and ((.apps[] | select(.bundleIdentifier == "com.keipix.client.ipad") | .versionName) == $version)
    and ((.apps[] | select(.bundleIdentifier == "com.keipix.client.ipad") | .versionCode) == $code)
    and ((.apps[] | select(.bundleIdentifier == "com.keipix.client.ipad") | .buildNumber) == $build)
    and ((.apps[] | select(.bundleIdentifier == "com.keipix.client.ipad") | .buildDisplayNumber) == $build_display)
    and ((.apps[] | select(.bundleIdentifier == "com.keipix.client.ipad") | .buildIdentity) | startswith($build_identity_prefix))
    and ((.apps[] | select(.bundleIdentifier == "com.keipix.client.ipad") | .versions[0].buildNumber) == $build)
    and ((.apps[] | select(.bundleIdentifier == "com.keipix.client.ipad") | .versions[0].buildDisplayNumber) == $build_display)
    and ((.apps[] | select(.bundleIdentifier == "com.keipix.client.ipad") | .versions[0].buildIdentity) | startswith($build_identity_prefix))
    and ((.apps[] | select(.bundleIdentifier == "com.keipix.client.ipad") | .downloadURL) | endswith("/releases/download/nightly/KeiPix-iPadOS-\($version)-build.\($build)-unsigned.ipa"))
  ' "$ROOT_DIR/apps_nightly.json" >/dev/null

rg_output="$(mktemp)"
trap 'rm -f "$rg_output"' EXIT
if command -v rg >/dev/null 2>&1; then
  search_legacy_user_agent() {
    rg -n "KeiPix/1\\.0" "$ROOT_DIR/Sources"
  }
else
  search_legacy_user_agent() {
    grep -R -n "KeiPix/1\\.0" "$ROOT_DIR/Sources"
  }
fi

if search_legacy_user_agent >"$rg_output"; then
  cat "$rg_output" >&2
  echo "replace hard-coded KeiPix/1.0 user agents with AppVersion.current.userAgentProduct" >&2
  exit 1
fi

echo "KeiPix version settings are consistent: $KEIPIX_MARKETING_VERSION ($KEIPIX_BUILD_NUMBER), revision $KEIPIX_BUILD_IDENTITY"
