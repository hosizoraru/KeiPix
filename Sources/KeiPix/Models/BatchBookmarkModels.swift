import Foundation

struct BatchBookmarkPreview: Identifiable, Hashable, Sendable {
    let id = UUID()
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

    var canApply: Bool {
        applyArtworks.isEmpty == false
    }

    static func make(
        artworks: [PixivArtwork],
        restrict: BookmarkRestrict,
        tags: [String],
        limit: Int = 30
    ) -> BatchBookmarkPreview {
        BatchBookmarkPreview(
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
