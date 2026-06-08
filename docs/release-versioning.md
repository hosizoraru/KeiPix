# Release Versioning

KeiPix keeps release metadata explicit so macOS, iOS, iPadOS, SwiftPM packaging,
CI artifacts, About, backups, release checks, and User-Agent diagnostics all
describe the same build.

## Source Of Truth

The human-edited version source is [`Config/AppVersion.xcconfig`](../Config/AppVersion.xcconfig):

```xcconfig
MARKETING_VERSION = 0.27.0
CURRENT_PROJECT_VERSION = 2700
```

Those names intentionally match Apple build settings:

- `MARKETING_VERSION` is written to `CFBundleShortVersionString`.
- `CURRENT_PROJECT_VERSION` is written to `CFBundleVersion`.
- `versionName` is the release/feed alias for `MARKETING_VERSION`.
- `buildNumber` and `buildVersion` are release/feed aliases for
  `CURRENT_PROJECT_VERSION`.
- `versionCode` is the integer build code used by scripts and the
  LiveContainer source. A plain integer build number is used directly; dotted
  Apple build versions are packed with three digit components, so `7.8.9`
  becomes `7008009`.

Apple documents `CFBundleShortVersionString` as the release version string and
`CFBundleVersion` as the bundle build version. KeiPix keeps the marketing
version in numeric `x.y.z` form and keeps the build number as one to three
positive integer components. That makes App Store, Xcode, GitHub release, and
the in-app update comparator easy to reason about.

## Build Number Strategies

`script/version_settings.sh` is the shared resolver for local scripts and CI.
It always reads `MARKETING_VERSION` and the configured build number from
`Config/AppVersion.xcconfig`, then chooses the effective build number with one
of these strategies:

- `config`: use `CURRENT_PROJECT_VERSION` exactly. This is the default for local
  scripts and for `v*` release tag builds.
- `git`: derive a moving build number from repository history. If a reachable
  `v<MARKETING_VERSION>` tag exists, it uses that tag as the anchor. Otherwise
  it uses the nearest reachable `v[0-9]*` tag. The effective build number is the
  configured build number plus the number of commits since the anchor. If no
  version tag exists, it falls back to the total `HEAD` commit count, never below
  the configured build number. Dotted configured builds are first packed with the
  same `versionCode` rule, so `7.8.9` becomes the integer baseline `7008009`
  before any commit distance is added.
- `override`: set `KEIPIX_BUILD_NUMBER_OVERRIDE=<number>` to force a specific
  build number for a one-off local or CI run.

GitHub Actions sets `KEIPIX_BUILD_NUMBER_STRATEGY=git` for non-tag builds so
nightly LiveContainer updates naturally advance with commits. Release tag builds
keep `config` so the maintainer can lock the final build number intentionally.

Useful local checks:

```bash
./script/version_settings.sh --print-json
KEIPIX_BUILD_NUMBER_STRATEGY=git ./script/version_settings.sh --print-json
KEIPIX_BUILD_NUMBER_OVERRIDE=1001 ./script/version_settings.sh --print-json
```

Apple references:

- [`CFBundleShortVersionString`](https://developer.apple.com/documentation/bundleresources/information_property_list/cfbundleshortversionstring)
- [`CFBundleVersion`](https://developer.apple.com/documentation/bundleresources/information_property_list/cfbundleversion)

## How To Change Versions

Use the helper so the config file and XcodeGen settings stay aligned:

```bash
./script/set_app_version.sh 0.27.0 2700
```

Then regenerate the Xcode project if you need to inspect Xcode project output:

```bash
xcodegen generate --spec project.yml
```

Do not hand-edit `KeiPix.xcodeproj/project.pbxproj`; it is generated from
`project.yml`.

## Validation

Run the version check before release packaging:

```bash
./script/check_version_consistency.sh
swift test --filter AppVersionTests
```

The check verifies:

- `Config/AppVersion.xcconfig` is syntactically valid.
- `project.yml` uses the same `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION`.
- macOS, iOS, and iPadOS plist templates use the expected build-setting
  placeholders.
- SwiftPM macOS packaging and CI read `script/version_settings.sh`.
- source code no longer hard-codes the legacy `KeiPix/1.0` User-Agent.

## Runtime Metadata

The app reads its shipping bundle through `AppVersion.current`, not through the
repo config file. This matters because users run the packaged app, not the
working tree. The runtime metadata feeds:

- About version and diagnostics copy.
- Release-update comparison against GitHub release tags.
- Backup/export metadata.
- Product User-Agent strings such as `KeiPix/0.27.0`.

## Packaging

`script/build_and_run.sh` writes the SwiftPM-generated macOS app bundle with the
shared version fields.

`script/build_release_app.sh` writes release artifacts named like:

```text
KeiPix-0.27.0-build.2700.zip
KeiPix-0.27.0-build.2700.dmg
```

`script/build_unsigned_ipa.sh ios` and `script/build_unsigned_ipa.sh ipados`
write unsigned device IPA artifacts named like:

```text
KeiPix-iOS-0.27.0-build.2700-unsigned.ipa
KeiPix-iPadOS-0.27.0-build.2700-unsigned.ipa
```

The GitHub Actions workflow uses the same metadata and uploads artifacts named:

```text
KeiPix-macOS-<marketing-version>-build.<build-number>-app
KeiPix-iOS-<marketing-version>-build.<build-number>-unsigned-ipa
KeiPix-iPadOS-<marketing-version>-build.<build-number>-unsigned-ipa
```

## LiveContainer Nightly Source

`apps_nightly.json` is a LiveContainer/AltStore-style source for unsigned
nightly IPA imports. The canonical subscription URL is:

```text
https://github.com/hosizoraru/KeiPix/releases/download/nightly/apps_nightly.json
```

The checked-in file is a valid seed generated from
`Config/AppVersion.xcconfig`. On `master` pushes, GitHub Actions regenerates the
source after both iOS and iPadOS unsigned IPA artifacts succeed, fills in the
actual IPA sizes, commit, build date, and workflow URL, then uploads:

```text
apps_nightly.json
KeiPix-iOS-<marketing-version>-build.<build-number>-unsigned.ipa
KeiPix-iPadOS-<marketing-version>-build.<build-number>-unsigned.ipa
```

to the moving `nightly` GitHub Release. Local refreshes use the same generator:

```bash
./script/generate_livecontainer_apps_nightly.sh apps_nightly.json
```

## Release Tags

Use GitHub release tags that match the marketing version:

```text
v0.27.0
```

The app's update checker strips the leading `v` and compares the tag against
the running bundle's `CFBundleShortVersionString`.
