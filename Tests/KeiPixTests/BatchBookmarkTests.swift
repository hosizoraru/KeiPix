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

    private func artwork(id: Int, isBookmarked: Bool) throws -> PixivArtwork {
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
            "id": \(100 + id),
            "name": "Creator \(id)",
            "account": "creator\(id)"
          },
          "tags": [],
          "page_count": 1,
          "is_bookmarked": \(isBookmarked)
        }
        """
        return try JSONDecoder().decode(PixivArtwork.self, from: Data(payload.utf8))
    }
}
