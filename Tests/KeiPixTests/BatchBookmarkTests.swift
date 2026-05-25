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
