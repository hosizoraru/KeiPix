#!/usr/bin/env bash
# Generate the LiveContainer/AltStore-compatible nightly source for KeiPix.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/script/version_settings.sh"
keipix_load_version_settings "$ROOT_DIR"

OUTPUT_PATH="${1:-$ROOT_DIR/apps_nightly.json}"
ARTIFACTS_DIR="${KEIPIX_ARTIFACTS_DIR:-$ROOT_DIR/artifacts}"
REPOSITORY_URL="${KEIPIX_REPOSITORY_URL:-https://github.com/hosizoraru/KeiPix}"
RELEASE_TAG="${KEIPIX_RELEASE_TAG:-nightly}"
DOWNLOAD_BASE_URL="${KEIPIX_DOWNLOAD_BASE_URL:-$REPOSITORY_URL/releases/download/$RELEASE_TAG}"
SOURCE_URL="${KEIPIX_SOURCE_URL:-$DOWNLOAD_BASE_URL/apps_nightly.json}"
ICON_URL="${KEIPIX_ICON_URL:-$REPOSITORY_URL/raw/master/Sources/KeiPix/Resources/keipixiv.icon/Assets/1.png}"
TINT_COLOR="${KEIPIX_TINT_COLOR:-#0099FF}"
MIN_OS_VERSION="${KEIPIX_MIN_OS_VERSION:-26.0}"

IOS_IPA_NAME="KeiPix-iOS-$KEIPIX_VERSION_NAME-build.$KEIPIX_BUILD_NUMBER-unsigned.ipa"
IPADOS_IPA_NAME="KeiPix-iPadOS-$KEIPIX_VERSION_NAME-build.$KEIPIX_BUILD_NUMBER-unsigned.ipa"
IOS_IPA_PATH="${KEIPIX_IOS_IPA_PATH:-$ARTIFACTS_DIR/$IOS_IPA_NAME}"
IPADOS_IPA_PATH="${KEIPIX_IPADOS_IPA_PATH:-$ARTIFACTS_DIR/$IPADOS_IPA_NAME}"

file_size_or_zero() {
  local path="$1"
  if [ ! -f "$path" ]; then
    printf '0\n'
    return 0
  fi

  stat -c '%s' "$path" 2>/dev/null || stat -f '%z' "$path"
}

iso8601_now() {
  date -u '+%Y-%m-%dT%H:%M:%SZ'
}

git_value_or_default() {
  local default="$1"
  shift
  git -C "$ROOT_DIR" "$@" 2>/dev/null || printf '%s\n' "$default"
}

VERSION_DATE="${KEIPIX_VERSION_DATE:-$(iso8601_now)}"
COMMIT="${KEIPIX_COMMIT:-$(git_value_or_default nightly rev-parse --short=12 HEAD)}"
HEADLINE="${KEIPIX_HEADLINE:-$(git_value_or_default 'Nightly build' log -1 --pretty=%s)}"
IOS_IPA_SIZE="${KEIPIX_IOS_IPA_SIZE:-$(file_size_or_zero "$IOS_IPA_PATH")}"
IPADOS_IPA_SIZE="${KEIPIX_IPADOS_IPA_SIZE:-$(file_size_or_zero "$IPADOS_IPA_PATH")}"
RUN_URL="${KEIPIX_RUN_URL:-}"

if [ -z "$RUN_URL" ] && [ -n "${GITHUB_SERVER_URL:-}" ] && [ -n "${GITHUB_REPOSITORY:-}" ] && [ -n "${GITHUB_RUN_ID:-}" ]; then
  RUN_URL="$GITHUB_SERVER_URL/$GITHUB_REPOSITORY/actions/runs/$GITHUB_RUN_ID"
fi

export KEIPIX_VERSION_NAME KEIPIX_BUILD_NUMBER KEIPIX_BUILD_VERSION KEIPIX_VERSION_CODE KEIPIX_BUILD_DISPLAY_NUMBER KEIPIX_BUILD_IDENTITY
export REPOSITORY_URL SOURCE_URL DOWNLOAD_BASE_URL ICON_URL TINT_COLOR MIN_OS_VERSION
export VERSION_DATE COMMIT HEADLINE RUN_URL IOS_IPA_NAME IPADOS_IPA_NAME IOS_IPA_SIZE IPADOS_IPA_SIZE

python3 - "$OUTPUT_PATH" <<'PY'
import json
import os
import sys
from pathlib import Path

output_path = Path(sys.argv[1])
version_name = os.environ["KEIPIX_VERSION_NAME"]
build_number = os.environ["KEIPIX_BUILD_NUMBER"]
build_version = os.environ["KEIPIX_BUILD_VERSION"]
version_code = int(os.environ["KEIPIX_VERSION_CODE"])
build_display_number = os.environ["KEIPIX_BUILD_DISPLAY_NUMBER"]
build_identity = os.environ["KEIPIX_BUILD_IDENTITY"]
repository_url = os.environ["REPOSITORY_URL"].rstrip("/")
source_url = os.environ["SOURCE_URL"]
download_base_url = os.environ["DOWNLOAD_BASE_URL"].rstrip("/")
icon_url = os.environ["ICON_URL"]
tint_color = os.environ["TINT_COLOR"]
min_os_version = os.environ["MIN_OS_VERSION"]
version_date = os.environ["VERSION_DATE"]
commit = os.environ["COMMIT"]
headline = os.environ["HEADLINE"]
run_url = os.environ["RUN_URL"]


def version_description(device: str) -> str:
    description = (
        f"{device} nightly {version_name} build {build_number}"
        f" ({build_identity}) from {commit}: {headline}"
    )
    if run_url:
        description += f"\n\nBuilt by GitHub Actions: {run_url}"
    return description


def app_entry(
    *,
    name: str,
    bundle_identifier: str,
    subtitle: str,
    description: str,
    ipa_name: str,
    size: int,
) -> dict:
    download_url = f"{download_base_url}/{ipa_name}"
    latest_version = {
        "version": version_name,
        "versionName": version_name,
        "versionCode": version_code,
            "buildNumber": build_number,
            "buildVersion": build_version,
            "buildDisplayNumber": build_display_number,
            "buildIdentity": build_identity,
            "date": version_date,
        "localizedDescription": version_description(name),
        "downloadURL": download_url,
        "size": size,
        "minOSVersion": min_os_version,
        "commit": commit,
        "headline": headline,
    }
    return {
        "beta": True,
        "name": name,
        "bundleIdentifier": bundle_identifier,
        "developerName": "KeiPix contributors",
        "subtitle": subtitle,
        "version": version_name,
        "versionName": version_name,
        "versionCode": version_code,
        "buildNumber": build_number,
        "buildVersion": build_version,
        "buildDisplayNumber": build_display_number,
        "buildIdentity": build_identity,
        "versionDate": version_date,
        "versionDescription": version_description(name),
        "downloadURL": download_url,
        "localizedDescription": description,
        "iconURL": icon_url,
        "tintColor": tint_color,
        "category": "utilities",
        "size": size,
        "minOSVersion": min_os_version,
        "appPermissions": {
            "privacy": {
                "NSPhotoLibraryAddUsageDescription": (
                    "KeiPix saves artworks to the photo library when the user downloads or saves them."
                )
            }
        },
        "versions": [latest_version],
        "commit": commit,
        "headline": headline,
    }


source = {
    "name": "KeiPix Nightly",
    "identifier": "com.keipix.source.nightly",
    "website": repository_url,
    "sourceURL": source_url,
    "subtitle": "KeiPix nightly LiveContainer source.",
    "description": (
        "Nightly unsigned KeiPix IPA builds for LiveContainer-compatible sideload testing environments."
    ),
    "tintColor": tint_color,
    "iconURL": icon_url,
    "apps": [
        app_entry(
            name="KeiPix iOS",
            bundle_identifier="com.keipix.client.ios",
            subtitle="Native Pixiv client for iPhone.",
            description="Native Swift Pixiv client packaged as an unsigned iPhone IPA for LiveContainer import.",
            ipa_name=os.environ["IOS_IPA_NAME"],
            size=int(os.environ["IOS_IPA_SIZE"]),
        ),
        app_entry(
            name="KeiPix iPadOS",
            bundle_identifier="com.keipix.client.ipad",
            subtitle="Native Pixiv client for iPad.",
            description="Native Swift Pixiv client packaged as an unsigned iPad IPA for LiveContainer import.",
            ipa_name=os.environ["IPADOS_IPA_NAME"],
            size=int(os.environ["IPADOS_IPA_SIZE"]),
        ),
    ],
    "news": [],
}

encoded = json.dumps(source, ensure_ascii=False, indent=2)
if str(output_path) == "-":
    print(encoded)
else:
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(encoded + "\n", encoding="utf-8")
PY
