import Foundation

/// Snapshot of a GitHub release that's newer than the running build.
///
/// Decoded from `https://api.github.com/repos/:owner/:repo/releases/latest`
/// and surfaced in the update banner. We deliberately keep only the fields
/// the UI consumes — the full release JSON has 30+ keys we'd never use,
/// and decoding extras would just bloat the test fixtures.
struct ReleaseUpdate: Equatable, Sendable, Codable {
    /// SemVer parsed out of `tag_name`. The local-vs-remote comparison
    /// is the only reason we hit GitHub at all, so we cache the parsed
    /// form rather than re-parsing on every UI render.
    let version: SemanticVersion
    /// Raw `tag_name` as published — preserved so the banner can show
    /// exactly what GitHub published (e.g. `v0.2.0-rc.1`) instead of our
    /// canonicalised `0.2.0-rc.1` form.
    let tagName: String
    /// Optional human-friendly release name (`name` field). Falls back
    /// to `tagName` when absent, matching how the GitHub web UI degrades.
    let displayName: String
    /// Release notes body. May be empty — the banner truncates / scrolls
    /// it for display.
    let body: String
    /// `html_url` for the release page on github.com. Used by the
    /// "Open Release Notes" button.
    let htmlURL: URL
    /// When GitHub published the release. Surfaces beneath the title in
    /// the banner so users can tell stale tags from fresh ones.
    let publishedAt: Date?
}

extension SemanticVersion: Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        guard let parsed = SemanticVersion(raw) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unrecognised semantic version: \(raw)"
            )
        }
        self = parsed
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(displayString)
    }
}
