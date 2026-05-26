import Foundation

/// Per-artwork (and per-user) record of which detail-pane cards the
/// reader has expanded. The detail surface ships six collapsible
/// sections — caption / tags / metadata / series / comments / related
/// — and we want each one to remember its open state both within a
/// single artwork (so scrolling the reader doesn't blow it away) and
/// across artworks (so a user who likes seeing tags doesn't have to
/// re-expand on every new piece).
///
/// The two-level memory works like this:
///
///   1. `ArtworkDetailExpansionState.default` is the user's
///      cross-artwork preference. It's seeded with the design
///      default (tags expanded) and overridden whenever the user
///      flips a section in any reader. Persisted under a single
///      `artworkDetailDefaultExpansion` UserDefaults key.
///   2. `ArtworkDetailStateLibrary` is the per-artwork override
///      cache. When a card is flipped on artwork X, we record the
///      whole expansion bundle for X *and* update the default so
///      subsequent first-time visits to other artworks pick it up.
///   3. When opening artwork Y for the first time, the library has
///      no entry for Y, so we fall back to the persisted default.
struct ArtworkDetailExpansionState: Codable, Equatable, Sendable {
    var isCaptionExpanded: Bool
    var isSeriesExpanded: Bool
    var isCommentsExpanded: Bool
    var isRelatedExpanded: Bool
    var isTagsExpanded: Bool
    var isMetadataExpanded: Bool

    /// Initial design default. Tags is the most-asked-for piece of
    /// metadata (translation, search, mute) so it ships open; the
    /// rest stay collapsed to keep the first viewport focused on
    /// the artwork itself.
    static let designDefault = ArtworkDetailExpansionState(
        isCaptionExpanded: false,
        isSeriesExpanded: false,
        isCommentsExpanded: false,
        isRelatedExpanded: false,
        isTagsExpanded: true,
        isMetadataExpanded: false
    )

    @available(*, deprecated, renamed: "designDefault")
    static let defaultValue = designDefault
}

struct ArtworkDetailStateEntry: Codable, Equatable, Sendable {
    let artworkID: Int
    var expansionState: ArtworkDetailExpansionState
    var updatedAt: Date
}

struct ArtworkDetailStateLibrary: Codable, Equatable, Sendable {
    private(set) var entries: [ArtworkDetailStateEntry]

    init(entries: [ArtworkDetailStateEntry] = []) {
        self.entries = entries
    }

    /// Resolved expansion state for an artwork. Falls back to the
    /// caller-supplied `default` (typically the user's cross-artwork
    /// preference) when no per-artwork entry exists yet.
    func expansionState(
        for artworkID: Int,
        default fallback: ArtworkDetailExpansionState = .designDefault
    ) -> ArtworkDetailExpansionState {
        entries.first { $0.artworkID == artworkID }?.expansionState ?? fallback
    }

    mutating func setExpansionState(
        _ state: ArtworkDetailExpansionState,
        for artworkID: Int,
        now: Date = Date(),
        limit: Int = 400
    ) {
        entries.removeAll { $0.artworkID == artworkID }
        entries.insert(
            ArtworkDetailStateEntry(artworkID: artworkID, expansionState: state, updatedAt: now),
            at: 0
        )
        if entries.count > limit {
            entries.removeLast(entries.count - limit)
        }
    }
}
