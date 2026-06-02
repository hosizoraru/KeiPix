## Summary

<!-- What changed? -->

## Why

<!-- Why does this change belong in KeiPix? -->

## Scope

- [ ] AppKit/UIKit hot path
- [ ] SwiftUI shell/composition
- [ ] Model/store/service
- [ ] Build/CI/scripts
- [ ] Docs only

## Validation

- [ ] `swift build`
- [ ] `swift test`
- [ ] Targeted tests:
- [ ] `./script/build_and_run.sh --verify`

## Visual QA

If this touches UI, list the surface and evidence path.

- Surface:
- Launch command:
- Manifest path:

## Risk And Rollback

- User-visible risk:
- Data/privacy/write risk:
- Rollback notes:

## Checklist

- [ ] I kept the change to one theme.
- [ ] I preserved the AppKit/UIKit-first, SwiftUI-as-glue boundary for hot paths.
- [ ] I did not copy reference-client Flutter/Dart/Kotlin source into `Sources/KeiPix`.
- [ ] I removed tokens, cookies, request headers and private account data from logs/screenshots.
- [ ] I updated README/docs/visual QA notes when behavior changed.
