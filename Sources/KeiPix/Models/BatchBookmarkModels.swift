import Foundation

enum BatchBookmarkScope: String, Hashable, Sendable {
    case loadedFeed
    case selectedWorks

    var title: String {
        switch self {
        case .loadedFeed:
            L10n.loadedFeed
        case .selectedWorks:
            L10n.selectedWorks
        }
    }

    var emptyStateTitle: String {
        switch self {
        case .loadedFeed:
            L10n.noBatchBookmarkCandidates
        case .selectedWorks:
            L10n.noSelectedBatchBookmarkCandidates
        }
    }
}

struct BatchBookmarkCommandRequest: Identifiable, Equatable {
    let id = UUID()
    let scope: BatchBookmarkScope
    let artworkIDs: [Int]
}

struct BatchBookmarkPreview: Identifiable, Hashable, Sendable {
    let id = UUID()
    let scope: BatchBookmarkScope
    let restrict: BookmarkRestrict
    let tags: [String]
    let limit: Int
    let candidates: [PixivArtwork]
    let skippedBookmarked: [PixivArtwork]

    var applyArtworks: [PixivArtwork] {
        Array(candidates.prefix(limit))
    }

    var omittedCandidateCount: Int {
        max(candidates.count - applyArtworks.count, 0)
    }

    var sourceArtworkCount: Int {
        candidates.count + skippedBookmarked.count
    }

    var skippedBookmarkedPreview: [PixivArtwork] {
        Array(skippedBookmarked.prefix(4))
    }

    var omittedSkippedBookmarkedCount: Int {
        max(skippedBookmarked.count - skippedBookmarkedPreview.count, 0)
    }

    var canApply: Bool {
        applyArtworks.isEmpty == false
    }

    static func make(
        artworks: [PixivArtwork],
        scope: BatchBookmarkScope = .loadedFeed,
        restrict: BookmarkRestrict,
        tags: [String],
        limit: Int = 30
    ) -> BatchBookmarkPreview {
        BatchBookmarkPreview(
            scope: scope,
            restrict: restrict,
            tags: tags,
            limit: max(limit, 1),
            candidates: artworks.filter { $0.isBookmarked == false },
            skippedBookmarked: artworks.filter(\.isBookmarked)
        )
    }
}

struct BatchBookmarkResult: Equatable, Sendable {
    let savedCount: Int
    let failedCount: Int
}
