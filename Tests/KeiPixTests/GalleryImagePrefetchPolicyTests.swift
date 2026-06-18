import Foundation
import Testing
@testable import KeiPix

struct GalleryImagePrefetchPolicyTests {
    @Test("Preview prefetch URLs are unique, ordered, and capped")
    func previewURLsAreUniqueOrderedAndCapped() {
        let duplicate = URL(string: "https://example.com/shared-medium.jpg")!
        let artworks = [
            artwork(id: 1, mediumURL: duplicate, largeURL: URL(string: "https://example.com/1-large.jpg")!),
            artwork(id: 2, mediumURL: duplicate, largeURL: URL(string: "https://example.com/2-large.jpg")!),
            artwork(id: 3, mediumURL: URL(string: "https://example.com/3-medium.jpg")!, largeURL: nil)
        ]

        let urls = GalleryImagePrefetchPolicy.previewURLs(for: artworks, tier: .medium, limit: 2)

        #expect(urls.map(\.absoluteString) == [
            "https://example.com/shared-medium.jpg",
            "https://example.com/3-medium.jpg"
        ])
    }

    @Test("Preview prefetch honors the configured image tier")
    func previewURLsHonorTier() {
        let artworks = [
            artwork(
                id: 1,
                mediumURL: URL(string: "https://example.com/1-medium.jpg")!,
                largeURL: URL(string: "https://example.com/1-large.jpg")!
            )
        ]

        let urls = GalleryImagePrefetchPolicy.previewURLs(for: artworks, tier: .large)

        #expect(urls.map(\.absoluteString) == ["https://example.com/1-large.jpg"])
    }

    @Test("Preview prefetch avoids original assets when original quality is selected")
    func previewURLsAvoidOriginalAssetsForOriginalTier() {
        let artworks = [
            artwork(
                id: 1,
                mediumURL: URL(string: "https://example.com/1-medium.jpg")!,
                largeURL: URL(string: "https://example.com/1-large.jpg")!,
                originalURL: URL(string: "https://example.com/1-original.jpg")!
            )
        ]

        let urls = GalleryImagePrefetchPolicy.previewURLs(for: artworks, tier: .original)

        #expect(urls.map(\.absoluteString) == ["https://example.com/1-large.jpg"])
    }

    private func artwork(
        id: Int,
        mediumURL: URL,
        largeURL: URL?,
        originalURL: URL? = nil
    ) -> PixivArtwork {
        PixivArtwork(
            id: id,
            title: "Artwork \(id)",
            type: "illust",
            caption: "",
            user: PixivUser(id: 42, name: "Creator", account: "creator"),
            tags: [],
            createDate: Date(timeIntervalSince1970: 0),
            pageCount: 1,
            width: 1000,
            height: 1000,
            totalView: 0,
            totalBookmarks: 0,
            totalComments: 0,
            isBookmarked: false,
            isMuted: false,
            isAI: false,
            sanityLevel: 0,
            xRestrict: 0,
            series: nil,
            images: [
                PixivImageSet(
                    squareMedium: nil,
                    medium: mediumURL,
                    large: largeURL,
                    original: originalURL
                )
            ]
        )
    }
}
