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
            restrict: .private,
            tags: ["favorite"],
            limit: 1
        )

        #expect(preview.applyArtworks.map(\.id) == [1])
        #expect(preview.omittedCandidateCount == 1)
        #expect(preview.skippedBookmarked.map(\.id) == [2])
        #expect(preview.restrict == .private)
        #expect(preview.tags == ["favorite"])
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
