import Foundation
import Testing
@testable import KeiPix

struct ArtworkSeriesPresentationTests {
    @Test("Series presentation preserves API order by default")
    func seriesPresentationPreservesAPIOrderByDefault() throws {
        let artworks = try [
            artwork(id: 3, title: "C", createdAt: 300),
            artwork(id: 1, title: "A", createdAt: 100),
            artwork(id: 2, title: "B", createdAt: 200)
        ]

        let displayed = ArtworkSeriesPresentation.displayedArtworks(
            artworks,
            sortMode: .seriesOrder,
            readFilter: .all,
            viewedArtworkIDs: []
        )

        #expect(displayed.map(\.id) == [3, 1, 2])
    }

    @Test("Series presentation sorts and filters local read state")
    func seriesPresentationSortsAndFiltersLocalReadState() throws {
        let artworks = try [
            artwork(id: 1, title: "A", createdAt: 100),
            artwork(id: 2, title: "B", createdAt: 300),
            artwork(id: 3, title: "C", createdAt: 200)
        ]

        let unreadNewest = ArtworkSeriesPresentation.displayedArtworks(
            artworks,
            sortMode: .newestFirst,
            readFilter: .unread,
            viewedArtworkIDs: [2]
        )
        let viewedOldest = ArtworkSeriesPresentation.displayedArtworks(
            artworks,
            sortMode: .oldestFirst,
            readFilter: .viewed,
            viewedArtworkIDs: [2, 3]
        )

        #expect(unreadNewest.map(\.id) == [3, 1])
        #expect(viewedOldest.map(\.id) == [3, 2])
    }

    private func artwork(id: Int, title: String, createdAt: Int) throws -> PixivArtwork {
        let payload = """
        {
          "id": \(id),
          "title": "\(title)",
          "type": "manga",
          "image_urls": {
            "medium": "https://example.com/\(id).jpg"
          },
          "caption": "",
          "create_date": \(createdAt),
          "user": {
            "id": \(100 + id),
            "name": "Creator \(id)",
            "account": "creator\(id)"
          },
          "tags": [],
          "page_count": 1,
          "is_bookmarked": false
        }
        """
        return try JSONDecoder().decode(PixivArtwork.self, from: Data(payload.utf8))
    }
}
