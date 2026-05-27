import Foundation

/// Lightweight semantic-version comparator for the GitHub release-update
/// check. We only need ordering against the local `CFBundleShortVersionString`
/// — not full `MAJOR.MINOR.PATCH-PRERELEASE+BUILD` semantics — so this stays
/// deliberately small.
///
/// Tolerates the strings GitHub release tags ship in practice:
/// - leading `v` (`v0.1.0`)
/// - any `-suffix` (`0.2.0-rc.1`) — treated as **less than** the same trio
///   without a suffix, mirroring `MAJOR.MINOR.PATCH` SemVer's pre-release
///   rule. This stops a `0.2.0-rc.1` tag from triggering a "new version"
///   prompt for users already on the released `0.2.0`.
/// - any trailing `+build` metadata (stripped before parsing)
/// - `0.1`-style two-component strings (padded with a trailing `.0`)
///
/// The store and checker both consult this type so the parser lives in one
/// place — drift between "what we ship as `MARKETING_VERSION`" and "what we
/// compare against `tag_name`" would silently break the whole feature.
struct SemanticVersion: Equatable, Comparable, Sendable {
    let major: Int
    let minor: Int
    let patch: Int
    /// `nil` means a final release. Any non-nil suffix sorts **before** the
    /// equivalent final release, matching SemVer's pre-release rule.
    let prerelease: String?

    init(major: Int, minor: Int, patch: Int, prerelease: String? = nil) {
        self.major = major
        self.minor = minor
        self.patch = patch
        self.prerelease = prerelease
    }

    init?(_ raw: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return nil }

        // Strip a leading `v` / `V` so `v0.1.0` and `0.1.0` parse the same.
        var working = trimmed
        if let first = working.first, first == "v" || first == "V" {
            working = String(working.dropFirst())
        }

        // Drop any `+build` metadata — irrelevant for ordering.
        if let plusRange = working.range(of: "+") {
            working = String(working[..<plusRange.lowerBound])
        }

        // Split off pre-release (`-suffix`) before counting dots so `0.2.0-rc.1`
        // doesn't get parsed as four numeric segments.
        let prereleaseValue: String?
        if let dashRange = working.range(of: "-") {
            let suffix = String(working[dashRange.upperBound...])
            prereleaseValue = suffix.isEmpty ? nil : suffix
            working = String(working[..<dashRange.lowerBound])
        } else {
            prereleaseValue = nil
        }

        let components = working.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
        guard (1...3).contains(components.count) else { return nil }

        let parsed = components.compactMap(Int.init)
        guard parsed.count == components.count, parsed.allSatisfy({ $0 >= 0 }) else { return nil }

        self.major = parsed[0]
        self.minor = parsed.count > 1 ? parsed[1] : 0
        self.patch = parsed.count > 2 ? parsed[2] : 0
        self.prerelease = prereleaseValue
    }

    var displayString: String {
        let core = "\(major).\(minor).\(patch)"
        if let prerelease, prerelease.isEmpty == false {
            return "\(core)-\(prerelease)"
        }
        return core
    }

    static func < (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        if lhs.major != rhs.major { return lhs.major < rhs.major }
        if lhs.minor != rhs.minor { return lhs.minor < rhs.minor }
        if lhs.patch != rhs.patch { return lhs.patch < rhs.patch }
        // SemVer rule: a version with a pre-release tag is *less than* the
        // same trio without one. Two pre-release strings compare
        // lexicographically — we don't ship a long-lived rc cadence so this
        // is fine; the test suite locks the canonical cases in.
        switch (lhs.prerelease, rhs.prerelease) {
        case (nil, nil): return false
        case (nil, _?): return false
        case (_?, nil): return true
        case let (left?, right?): return left < right
        }
    }
}
