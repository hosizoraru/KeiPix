import AppKit
import Foundation

@MainActor
extension KeiPixStore {
    /// Length of the launch-time throttle window. 24 hours is the
    /// cadence Pixez and Pixes both ship — any tighter and we burn the
    /// GitHub anonymous rate limit on quit/reopen cycles, any looser
    /// and a same-day bug-fix release lands too late to matter.
    static let releaseUpdateCheckInterval: TimeInterval = 24 * 60 * 60

    /// Resolved CFBundleShortVersionString as a `SemanticVersion`. Falls
    /// back to `0.0.0` when the bundle key is missing — that path only
    /// triggers in unit-test harnesses that load the SwiftPM module
    /// directly, so the update banner stays silent there instead of
    /// firing a false positive against a placeholder version.
    var currentReleaseSemanticVersion: SemanticVersion {
        let raw = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
        return SemanticVersion(raw) ?? SemanticVersion(major: 0, minor: 0, patch: 0)
    }

    /// Launch-time entry point. Bails out unless the user opted in,
    /// the throttle window has elapsed, and the bundle reports a
    /// non-placeholder version. Cheap to call repeatedly so callers
    /// don't have to gate it themselves.
    func checkForReleaseUpdateIfDue(
        now: Date = Date(),
        checker: ReleaseUpdateChecker = ReleaseUpdateChecker()
    ) async {
        guard checkForUpdatesOnLaunch else { return }
        let current = currentReleaseSemanticVersion
        guard current > SemanticVersion(major: 0, minor: 0, patch: 0) else { return }
        if let lastCheck = lastUpdateCheckAt,
           now.timeIntervalSince(lastCheck) < Self.releaseUpdateCheckInterval {
            return
        }
        await performReleaseUpdateCheck(now: now, checker: checker, isManual: false)
    }

    /// Manual entry point used by `Help → Check for Updates…`. Always
    /// hits GitHub (no throttle), populates `manualUpdateCheckResult`
    /// or `manualUpdateCheckError`, and flips `isCheckingForUpdates`
    /// so the menu item can disable while the request runs.
    func checkForReleaseUpdateNow(
        now: Date = Date(),
        checker: ReleaseUpdateChecker = ReleaseUpdateChecker()
    ) async {
        guard isCheckingForUpdates == false else { return }
        await performReleaseUpdateCheck(now: now, checker: checker, isManual: true)
    }

    /// Records that the user explicitly skipped this exact tag. The
    /// launch-time banner stays silent for it, but the manual menu
    /// entry still surfaces the same release until a newer tag ships.
    func skipRelease(tagName: String) {
        skippedReleaseTagName = tagName
        UserDefaults.standard.set(tagName, forKey: "skippedReleaseTagName")
    }

    /// Opens the release notes URL in the user's default browser. We
    /// route through `NSWorkspace` instead of `openURL(_:)` because the
    /// store doesn't have a SwiftUI environment handle, and this keeps
    /// the call site testable (any future spy can swap NSWorkspace).
    func openReleaseNotes(_ update: ReleaseUpdate) {
        NSWorkspace.shared.open(update.htmlURL)
    }

    /// Whether a launch-time banner should surface for the latest
    /// observed release. Returns `false` when the user already skipped
    /// this exact tag or when the persisted release is somehow older
    /// than the running build (can happen if a user downgrades to a
    /// nightly).
    var shouldSurfaceLaunchUpdateBanner: Bool {
        guard let update = latestReleaseUpdate else { return false }
        guard update.tagName != skippedReleaseTagName else { return false }
        return update.version > currentReleaseSemanticVersion
    }

    /// Surfaces the launch-time banner if we already have a release on
    /// file that the user hasn't skipped. Called from the main scene
    /// after `checkForReleaseUpdateIfDue` returns so the prompt fires
    /// regardless of whether this run actually hit the network — a
    /// throttled launch still surfaces yesterday's unskipped release.
    func presentPendingReleaseUpdateIfNeeded() {
        guard shouldSurfaceLaunchUpdateBanner, let release = latestReleaseUpdate else { return }
        pendingReleaseUpdatePrompt = release
    }

    private func performReleaseUpdateCheck(
        now: Date,
        checker: ReleaseUpdateChecker,
        isManual: Bool
    ) async {
        if isManual {
            isCheckingForUpdates = true
            manualUpdateCheckError = nil
        }
        defer {
            if isManual {
                isCheckingForUpdates = false
            }
        }

        let current = currentReleaseSemanticVersion
        let mode = isManual ? "manual" : "auto"
        let version = current.displayString
        KeiPixLog.releaseUpdate.info(
            "Checking GitHub releases (mode=\(mode, privacy: .public), current=\(version, privacy: .public))"
        )
        do {
            let result = try await checker.latestRelease(forCurrent: current)
            lastUpdateCheckAt = now
            UserDefaults.standard.set(now, forKey: "lastUpdateCheckAt")
            switch result {
            case .upToDate:
                KeiPixLog.releaseUpdate.info("GitHub reports up-to-date")
                // Don't clobber a stale `latestReleaseUpdate` snapshot —
                // it's still useful as a "last release we observed"
                // anchor for Settings, and clearing it would also drop
                // the user's skip memory matching a release that's now
                // equal to current.
            case .update(let release):
                KeiPixLog.releaseUpdate.notice("New release available: \(release.tagName, privacy: .public)")
                latestReleaseUpdate = release
                persistLatestReleaseUpdate()
                if isManual == false, release.tagName != skippedReleaseTagName {
                    pendingReleaseUpdatePrompt = release
                }
            }
            if isManual {
                manualUpdateCheckResult = result
                switch result {
                case .upToDate:
                    presentingNoUpdatesAvailable = true
                case .update(let release):
                    pendingReleaseUpdatePrompt = release
                }
            }
        } catch {
            KeiPixLog.releaseUpdate.error("Update check failed: \(error.localizedDescription, privacy: .public)")
            if isManual {
                manualUpdateCheckError = error.localizedDescription
                presentingUpdateCheckFailed = true
            }
        }
    }

    private func persistLatestReleaseUpdate() {
        guard let release = latestReleaseUpdate else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(release) else { return }
        UserDefaults.standard.set(data, forKey: "latestReleaseUpdate")
    }
}
