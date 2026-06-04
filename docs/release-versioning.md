# Release Versioning

KeiPix keeps release metadata explicit so macOS, iOS, iPadOS, SwiftPM packaging,
CI artifacts, About, backups, release checks, and User-Agent diagnostics all
describe the same build.

## Source Of Truth

The human-edited version source is [`Config/AppVersion.xcconfig`](../Config/AppVersion.xcconfig):

```xcconfig
MARKETING_VERSION = 0.1.0
CURRENT_PROJECT_VERSION = 1
```

Those names intentionally match Apple build settings:

- `MARKETING_VERSION` is written to `CFBundleShortVersionString`.
- `CURRENT_PROJECT_VERSION` is written to `CFBundleVersion`.

Apple documents `CFBundleShortVersionString` as the release version string and
`CFBundleVersion` as the bundle build version. KeiPix keeps the marketing
version in numeric `x.y.z` form and keeps the build number as one to three
positive integer components. That makes App Store, Xcode, GitHub release, and
the in-app update comparator easy to reason about.

Apple references:

- [`CFBundleShortVersionString`](https://developer.apple.com/documentation/bundleresources/information_property_list/cfbundleshortversionstring)
- [`CFBundleVersion`](https://developer.apple.com/documentation/bundleresources/information_property_list/cfbundleversion)

## How To Change Versions

Use the helper so the config file and XcodeGen settings stay aligned:

```bash
./script/set_app_version.sh 0.2.0 2
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
- Product User-Agent strings such as `KeiPix/0.1.0`.

## Packaging

`script/build_and_run.sh` writes the SwiftPM-generated macOS app bundle with the
shared version fields.

`script/build_release_app.sh` writes release artifacts named like:

```text
KeiPix-0.1.0-build.1.zip
KeiPix-0.1.0-build.1.dmg
```

The GitHub Actions workflow uses the same metadata and uploads artifacts named
`KeiPix-<marketing-version>-build.<build-number>`.

## Release Tags

Use GitHub release tags that match the marketing version:

```text
v0.2.0
```

The app's update checker strips the leading `v` and compares the tag against
the running bundle's `CFBundleShortVersionString`.
