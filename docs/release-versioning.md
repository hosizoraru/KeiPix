# Release Versioning

KeiPix keeps version metadata boring on purpose: the user-visible version and
the install/build code come from the same semantic version tag. Git commit data
is recorded for debugging and rollback, but it never changes the version number
that package managers, LiveContainer, TestFlight, or Xcode compare.

## Source Of Truth

The release baseline is the latest reachable semantic `v*` tag, for example:

```text
v0.27.6
```

`script/version_settings.sh` strips the leading `v` and exports:

```text
versionName = 0.27.6
buildNumber = 2706
versionCode = 2706
revision = v0.27.6+<commits-since-tag>
```

`Config/AppVersion.xcconfig` is the checked-in fallback and XcodeGen baseline:

```xcconfig
MARKETING_VERSION = 0.27.6
CURRENT_PROJECT_VERSION = 2706
```

Keep it aligned with the latest version tag. This matters because Xcode direct
builds read the checked-in build settings, while packaging scripts and GitHub
Actions also resolve git tags. If those disagree, local QA can end up testing a
bundle with a different version than the nightly artifacts.

## Version Code Layout

KeiPix uses the same integer layout as the Android-style examples:

```text
major * 10000 + minor * 100 + patch
```

Examples:

| Tag | versionName | versionCode / CFBundleVersion |
| --- | --- | --- |
| `v0.27.0` | `0.27.0` | `2700` |
| `v0.27.2` | `0.27.2` | `2702` |
| `v1.2.3` | `1.2.3` | `10203` |

`versionCode` does not include commit count. A nightly built 12 commits after
`v0.27.6` still uses `versionName=0.27.6` and `versionCode=2706`; its revision
identity is `v0.27.6+12`.

The layout supports minor and patch components from `0...99`. If a component
would exceed that, choose the next major/minor version instead of widening the
integer format.

## Debug Provenance

The following fields are injected into every packaged app and nightly feed:

- `KeiPixBuildAnchorTag`: nearest reachable semantic version tag.
- `KeiPixBuildCommitCount`: commit count since that tag.
- `KeiPixBuildIdentity`: `vX.Y.Z` or `vX.Y.Z+N`.
- `KeiPixGitShortCommit`: short commit hash for quick debugging.
- `KeiPixGitCommit`: full commit hash for exact reproduction.
- `KeiPixGitDirty`: whether local uncommitted changes were present.
- `KeiPixGitDescribe`: git describe output.

About keeps the primary visible version clean (`Version 0.27.6`, `Build 2706`)
and includes the revision plus commit hash in copied version/diagnostics
payloads.

## Resolver Strategy

`script/version_settings.sh` is the shared resolver for local scripts and CI:

```bash
./script/version_settings.sh --print-json
KEIPIX_BUILD_NUMBER_STRATEGY=config ./script/version_settings.sh --print-json
```

Supported strategies:

- `git`: default. Use the latest reachable `v*` tag as `versionName` and derive
  `buildNumber` / `versionCode` from that tag. Commit count is diagnostic only.
- `config`: use `Config/AppVersion.xcconfig` exactly. This is mainly for
  auditing the checked-in Xcode baseline.
- `override`: set `KEIPIX_BUILD_NUMBER_OVERRIDE=<number>` for a one-off build.
  Avoid this for normal nightly and release work because it intentionally
  bypasses the tag-code rule.

If no semantic version tag is reachable, `git` falls back to the config version
and still records the total commit count as diagnostic provenance.

## Changing Versions

Use the helper so the config file and XcodeGen settings stay aligned:

```bash
./script/set_app_version.sh 0.27.7
```

Then tag the commit that contains that version bump:

```bash
git tag -a v0.27.7 -m "KeiPix 0.27.7 daily baseline"
git push origin master v0.27.7
```

For daily/nightly anchors, tag the last useful commit of the day only after the
config/project baseline has been updated. That keeps Xcode local builds,
packaging scripts, GitHub Actions, About, and LiveContainer feeds on the same
version.

Do not hand-edit `KeiPix.xcodeproj/project.pbxproj`; it is generated from
`project.yml`.

## Validation

Run the version check before release packaging or after changing workflows,
plist templates, tags, or nightly feed generation:

```bash
./script/check_version_consistency.sh
swift test --filter AppVersionTests
```

The check verifies:

- `Config/AppVersion.xcconfig` is syntactically valid.
- `CURRENT_PROJECT_VERSION` is the tag code for `MARKETING_VERSION`.
- `project.yml` matches the checked-in config baseline.
- when a reachable `v*` tag exists, the checked-in baseline matches that tag.
- macOS, iOS, and iPadOS plist templates use build-setting placeholders.
- packaging scripts inject the shared version and git provenance fields.
- `.github/workflows/macos-build.yml` fetches full tag history.
- `apps_nightly.json` matches the current effective version metadata.
- source code no longer hard-codes the legacy `KeiPix/1.0` User-Agent.

## Packaging

`script/build_release_app.sh` writes release artifacts named like:

```text
KeiPix-0.27.6-build.2706.zip
KeiPix-0.27.6-build.2706.dmg
```

`script/build_unsigned_ipa.sh ios` and `script/build_unsigned_ipa.sh ipados`
write unsigned device IPA artifacts named like:

```text
KeiPix-iOS-0.27.6-build.2706-unsigned.ipa
KeiPix-iPadOS-0.27.6-build.2706-unsigned.ipa
```

The GitHub Actions workflow uploads artifacts named:

```text
KeiPix-macOS-<version>-build.<build>-app
KeiPix-iOS-<version>-build.<build>-unsigned-ipa
KeiPix-iPadOS-<version>-build.<build>-unsigned-ipa
```

On `master` pushes, the unsigned iOS and iPadOS IPAs feed the moving `nightly`
release. On `v*` tag pushes, the macOS zip and optional DMG are attached to the
matching GitHub Release.

## LiveContainer Nightly Source

`apps_nightly.json` is a LiveContainer/AltStore-style source for unsigned
nightly IPA imports. The canonical subscription URL is:

```text
https://github.com/hosizoraru/KeiPix/releases/download/nightly/apps_nightly.json
```

On `master` pushes, GitHub Actions waits for both iOS and iPadOS unsigned IPA
artifacts, regenerates the source with real IPA sizes, commit, build date, and
workflow URL, then uploads:

```text
apps_nightly.json
KeiPix-iOS-<version>-build.<build>-unsigned.ipa
KeiPix-iPadOS-<version>-build.<build>-unsigned.ipa
```

to the moving `nightly` GitHub Release. Local refreshes use the same generator:

```bash
./script/generate_livecontainer_apps_nightly.sh apps_nightly.json
```

The release job force-moves the `nightly` tag to the successful `master` commit,
prunes the previous nightly feed/IPAs, and republishes only the current feed and
the two current unsigned IPAs. It does not mark the nightly release as latest.
