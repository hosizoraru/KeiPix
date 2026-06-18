import Foundation
import Testing
@testable import KeiPix

struct BatchBookmarkTests {
    @Test("Batch bookmark preview separates candidates from existing bookmarks")
    func batchBookmarkPreviewSeparatesCandidates() throws {
        let artworks = try [
            artwork(id: 1, isBookmarked: false),
            artwork(id: 2, isBookmarked: true),
            artwork(id: 3, isBookmarked: false)
        ]

        let preview = BatchBookmarkPreview.make(
            artworks: artworks,
            scope: .selectedWorks,
            restrict: .private,
            tags: ["favorite"],
            limit: 1
        )

        #expect(preview.scope == .selectedWorks)
        #expect(preview.applyArtworks.map(\.id) == [1])
        #expect(preview.omittedCandidateCount == 1)
        #expect(preview.skippedBookmarked.map(\.id) == [2])
        #expect(preview.restrict == .private)
        #expect(preview.tags == ["favorite"])
        #expect(preview.sourceArtworkCount == 3)
    }

    @Test("Batch bookmark preview caps skipped bookmark samples")
    func batchBookmarkPreviewCapsSkippedSamples() throws {
        let artworks = try (1...7).map { try artwork(id: $0, isBookmarked: $0 <= 5) }

        let preview = BatchBookmarkPreview.make(
            artworks: artworks,
            restrict: .public,
            tags: [],
            limit: 30
        )

        #expect(preview.scope == .loadedFeed)
        #expect(preview.skippedBookmarkedPreview.map(\.id) == [1, 2, 3, 4])
        #expect(preview.omittedSkippedBookmarkedCount == 1)
        #expect(preview.applyArtworks.map(\.id) == [6, 7])
    }

    @Test("Bookmark visibility move plan keeps unique public bookmark candidates")
    func bookmarkVisibilityMovePlanKeepsUniqueCandidates() throws {
        let bookmarked = try artwork(id: 1, isBookmarked: true)
        let duplicate = try artwork(id: 1, isBookmarked: true)
        let unbookmarked = try artwork(id: 2, isBookmarked: false)
        let secondBookmarked = try artwork(id: 3, isBookmarked: true)

        let plan = BookmarkVisibilityMovePlan.publicToPrivate(
            artworks: [bookmarked, duplicate, unbookmarked, secondBookmarked]
        )

        #expect(plan.sourceRestrict == .public)
        #expect(plan.destinationRestrict == .private)
        #expect(plan.candidates.map(\.id) == [1, 3])
        #expect(plan.skippedUnbookmarked.map(\.id) == [2])
        #expect(plan.canApply)
    }

    @Test("Creator follow visibility move plan keeps unique followed authors from artworks")
    func creatorFollowVisibilityMovePlanKeepsUniqueFollowedArtworkAuthors() throws {
        let first = try artwork(id: 1, isBookmarked: false, userID: 10, isFollowed: true)
        let duplicateAuthor = try artwork(id: 2, isBookmarked: false, userID: 10, isFollowed: true)
        let unfollowed = try artwork(id: 3, isBookmarked: false, userID: 11, isFollowed: false)
        let secondFollowed = try artwork(id: 4, isBookmarked: false, userID: 12, isFollowed: true)

        let plan = CreatorFollowVisibilityMovePlan.publicToPrivate(
            artworks: [first, duplicateAuthor, unfollowed, secondFollowed]
        )

        #expect(plan.sourceRestrict == .public)
        #expect(plan.destinationRestrict == .private)
        #expect(plan.candidates.map(\.id) == [10, 12])
        #expect(plan.skippedUnfollowed.map(\.id) == [11])
        #expect(plan.canApply)
    }

    @Test("Creator follow visibility move plan keeps followed creator previews")
    func creatorFollowVisibilityMovePlanKeepsFollowedCreatorPreviews() {
        let followed = PixivUser(id: 1, name: "Followed", account: "followed", isFollowed: true)
        let unfollowed = PixivUser(id: 2, name: "Unfollowed", account: "unfollowed", isFollowed: false)
        let duplicate = PixivUser(id: 1, name: "Followed", account: "followed", isFollowed: true)
        let previews = [
            PixivUserPreview(user: followed, illusts: [], isMuted: false),
            PixivUserPreview(user: unfollowed, illusts: [], isMuted: false),
            PixivUserPreview(user: duplicate, illusts: [], isMuted: false)
        ]

        let plan = CreatorFollowVisibilityMovePlan.publicToPrivate(previews: previews)

        #expect(plan.candidates.map(\.id) == [1])
        #expect(plan.skippedUnfollowed.map(\.id) == [2])
    }

    @Test("Novel bookmark visibility move plan keeps unique bookmarked novels")
    func novelBookmarkVisibilityMovePlanKeepsUniqueBookmarkedNovels() throws {
        let bookmarked = try novel(id: 1, isBookmarked: true)
        let duplicate = try novel(id: 1, isBookmarked: true)
        let unbookmarked = try novel(id: 2, isBookmarked: false)
        let secondBookmarked = try novel(id: 3, isBookmarked: true)

        let plan = NovelBookmarkVisibilityMovePlan.publicToPrivate(
            novels: [bookmarked, duplicate, unbookmarked, secondBookmarked]
        )

        #expect(plan.sourceRestrict == .public)
        #expect(plan.destinationRestrict == .private)
        #expect(plan.candidates.map(\.id) == [1, 3])
        #expect(plan.skippedUnbookmarked.map(\.id) == [2])
        #expect(plan.canApply)
    }

    @Test("Bookmark detail registered tag names preserve only active unique tags")
    func bookmarkDetailRegisteredTagNamesPreserveOnlyActiveTags() throws {
        let payload = """
        {
          "is_bookmarked": true,
          "restrict": "public",
          "tags": [
            { "name": " favorite ", "is_registered": true },
            { "name": "favorite", "is_registered": true },
            { "name": "suggested", "is_registered": false },
            { "name": " ", "is_registered": true },
            { "name": "watercolor", "is_registered": true }
          ]
        }
        """

        let detail = try JSONDecoder().decode(PixivBookmarkDetail.self, from: Data(payload.utf8))

        #expect(detail.registeredTagNames == ["favorite", "watercolor"])
    }

    private func artwork(
        id: Int,
        isBookmarked: Bool,
        userID: Int? = nil,
        isFollowed: Bool = false
    ) throws -> PixivArtwork {
        let resolvedUserID = userID ?? (100 + id)
        let payload = """
        {
          "id": \(id),
          "title": "Artwork \(id)",
          "type": "illust",
          "image_urls": {
            "medium": "https://example.com/\(id).jpg"
          },
          "caption": "",
          "create_date": 0,
          "user": {
            "id": \(resolvedUserID),
            "name": "Creator \(resolvedUserID)",
            "account": "creator\(resolvedUserID)",
            "is_followed": \(isFollowed)
          },
          "tags": [],
          "page_count": 1,
          "is_bookmarked": \(isBookmarked)
        }
        """
        return try JSONDecoder().decode(PixivArtwork.self, from: Data(payload.utf8))
    }

    private func novel(id: Int, isBookmarked: Bool) throws -> PixivNovel {
        let payload = """
        {
          "id": \(id),
          "title": "Novel \(id)",
          "caption": "",
          "restrict": 0,
          "x_restrict": 0,
          "is_original": true,
          "image_urls": {
            "square_medium": "https://example.com/\(id)_square.jpg",
            "medium": "https://example.com/\(id)_medium.jpg"
          },
          "create_date": "2024-08-01T12:00:00+09:00",
          "tags": [],
          "page_count": 3,
          "text_length": 1200,
          "user": {
            "id": \(200 + id),
            "name": "Novel Creator \(id)",
            "account": "novel_creator\(id)",
            "profile_image_urls": {}
          },
          "is_bookmarked": \(isBookmarked),
          "total_bookmarks": 0,
          "total_view": 0,
          "total_comments": 0,
          "visible": true,
          "is_muted": false,
          "is_mypixiv_only": false,
          "is_x_restricted": false,
          "novel_ai_type": 0
        }
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(PixivNovel.self, from: Data(payload.utf8))
    }
}
