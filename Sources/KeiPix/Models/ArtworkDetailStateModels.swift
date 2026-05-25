import Foundation

struct ArtworkDetailExpansionState: Codable, Equatable, Sendable {
    var isCaptionExpanded: Bool
    var isSeriesExpanded: Bool
    var isCommentsExpanded: Bool
    var isRelatedExpanded: Bool
    var isTagsExpanded: Bool
    var isMetadataExpanded: Bool

    static let defaultValue = ArtworkDetailExpansionState(
        isCaptionExpanded: false,
        isSeriesExpanded: false,
        isCommentsExpanded: false,
        isRelatedExpanded: false,
        isTagsExpanded: false,
        isMetadataExpanded: false
    )
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

    func expansionState(for artworkID: Int) -> ArtworkDetailExpansionState {
        entries.first { $0.artworkID == artworkID }?.expansionState ?? .defaultValue
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
