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

struct BookmarkVisibilityMovePlan: Equatable, Sendable {
    let sourceRestrict: BookmarkRestrict
    let destinationRestrict: BookmarkRestrict
    let candidates: [PixivArtwork]
    let skippedUnbookmarked: [PixivArtwork]

    var canApply: Bool {
        candidates.isEmpty == false
    }

    static func publicToPrivate(artworks: [PixivArtwork]) -> BookmarkVisibilityMovePlan {
        var seenIDs = Set<Int>()
        var candidates: [PixivArtwork] = []
        var skippedUnbookmarked: [PixivArtwork] = []

        for artwork in artworks where seenIDs.insert(artwork.id).inserted {
            if artwork.isBookmarked {
                candidates.append(artwork)
            } else {
                skippedUnbookmarked.append(artwork)
            }
        }

        return BookmarkVisibilityMovePlan(
            sourceRestrict: .public,
            destinationRestrict: .private,
            candidates: candidates,
            skippedUnbookmarked: skippedUnbookmarked
        )
    }
}

struct BookmarkVisibilityMoveResult: Equatable, Sendable {
    let movedCount: Int
    let failedCount: Int
}

struct CreatorFollowVisibilityMovePlan: Equatable, Sendable {
    let sourceRestrict: BookmarkRestrict
    let destinationRestrict: BookmarkRestrict
    let candidates: [PixivUser]
    let skippedUnfollowed: [PixivUser]

    var canApply: Bool {
        candidates.isEmpty == false
    }

    static func publicToPrivate(artworks: [PixivArtwork]) -> CreatorFollowVisibilityMovePlan {
        publicToPrivate(users: artworks.map(\.user))
    }

    static func publicToPrivate(previews: [PixivUserPreview]) -> CreatorFollowVisibilityMovePlan {
        publicToPrivate(users: previews.map(\.user))
    }

    static func publicToPrivate(users: [PixivUser]) -> CreatorFollowVisibilityMovePlan {
        var seenIDs = Set<Int>()
        var candidates: [PixivUser] = []
        var skippedUnfollowed: [PixivUser] = []

        for user in users where seenIDs.insert(user.id).inserted {
            if user.isFollowed {
                candidates.append(user)
            } else {
                skippedUnfollowed.append(user)
            }
        }

        return CreatorFollowVisibilityMovePlan(
            sourceRestrict: .public,
            destinationRestrict: .private,
            candidates: candidates,
            skippedUnfollowed: skippedUnfollowed
        )
    }
}

struct NovelBookmarkVisibilityMovePlan: Equatable, Sendable {
    let sourceRestrict: BookmarkRestrict
    let destinationRestrict: BookmarkRestrict
    let candidates: [PixivNovel]
    let skippedUnbookmarked: [PixivNovel]

    var canApply: Bool {
        candidates.isEmpty == false
    }

    static func publicToPrivate(novels: [PixivNovel]) -> NovelBookmarkVisibilityMovePlan {
        var seenIDs = Set<Int>()
        var candidates: [PixivNovel] = []
        var skippedUnbookmarked: [PixivNovel] = []

        for novel in novels where seenIDs.insert(novel.id).inserted {
            if novel.isBookmarked {
                candidates.append(novel)
            } else {
                skippedUnbookmarked.append(novel)
            }
        }

        return NovelBookmarkVisibilityMovePlan(
            sourceRestrict: .public,
            destinationRestrict: .private,
            candidates: candidates,
            skippedUnbookmarked: skippedUnbookmarked
        )
    }
}

struct VisibilityMoveResult: Equatable, Sendable {
    let movedCount: Int
    let failedCount: Int
}
