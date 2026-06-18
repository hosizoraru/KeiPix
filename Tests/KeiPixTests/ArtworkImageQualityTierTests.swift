import Foundation
import Testing
@testable import KeiPix

@Suite("Artwork image quality tiers")
struct ArtworkImageQualityTierTests {
    @Test("Tier resolver picks the requested rung when all sizes are present")
    func tierResolverHonorsRequest() throws {
        let artwork = try sampleArtwork()
        #expect(artwork.imageURL(at: 0, tier: .medium)?.absoluteString == "https://example.com/1_medium.jpg")
        #expect(artwork.imageURL(at: 0, tier: .large)?.absoluteString == "https://example.com/1_large.jpg")
        #expect(artwork.imageURL(at: 0, tier: .original)?.absoluteString == "https://example.com/1_original.jpg")
    }

    @Test("Feed preview tier walks the medium-first ladder")
    func feedPreviewTierFallsBackThroughMediumFirst() throws {
        let artwork = try sampleArtwork()
        #expect(artwork.feedPreviewURL(tier: .medium)?.absoluteString == "https://example.com/1_medium.jpg")
        #expect(artwork.feedPreviewURL(tier: .large)?.absoluteString == "https://example.com/1_large.jpg")
        #expect(artwork.feedPreviewURL(tier: .original)?.absoluteString == "https://example.com/1_original.jpg")
    }

    @Test("Legacy preferOriginal flag promotes to large or original tier")
    func legacyPromotionMapsBoolToTier() {
        #expect(ArtworkImageQualityTier.legacy(preferOriginal: false) == .large)
        #expect(ArtworkImageQualityTier.legacy(preferOriginal: true) == .original)
    }

    @Test("Tier resolver falls back without downgrading below the requested rung")
    func tierResolverFallsBackPredictably() throws {
        // Drop the `large` rung so callers requesting `.large` should
        // fall to `.medium`, not silently to `.original`.
        let artwork = try sampleArtwork(includeLarge: false)
        #expect(artwork.imageURL(at: 0, tier: .large)?.absoluteString == "https://example.com/1_medium.jpg")
        #expect(artwork.imageURL(at: 0, tier: .original)?.absoluteString == "https://example.com/1_original.jpg")
    }

    @Test("Original prefetch is bounded to the current and next page")
    func originalPrefetchOnlyWarmsCurrentAndNextPage() {
        let artwork = samplePagedArtwork(pageCount: 4)

        let urls = artwork.prefetchURLs(around: 1, tier: .original)

        #expect(urls.map(\.absoluteString) == [
            "https://example.com/1_original.jpg",
            "https://example.com/2_original.jpg"
        ])
    }

    @Test("Large prefetch keeps the wider neighbor window")
    func largePrefetchKeepsWiderNeighborWindow() {
        let artwork = samplePagedArtwork(pageCount: 4)

        let urls = artwork.prefetchURLs(around: 1, tier: .large)

        #expect(urls.map(\.absoluteString) == [
            "https://example.com/1_large.jpg",
            "https://example.com/2_large.jpg",
            "https://example.com/3_large.jpg",
            "https://example.com/0_large.jpg"
        ])
    }

    private func sampleArtwork(includeLarge: Bool = true) throws -> PixivArtwork {
        let largeKV = includeLarge ? "\"large\": \"https://example.com/1_large.jpg\"," : ""
        let payload = """
        {
          "id": 1,
          "title": "Sample",
          "type": "illust",
          "image_urls": {
            "square_medium": "https://example.com/1_square.jpg",
            "medium": "https://example.com/1_medium.jpg",
            \(largeKV)
            "original": "https://example.com/1_original.jpg"
          },
          "meta_single_page": {
            "original_image_url": "https://example.com/1_original.jpg"
          },
          "caption": "",
          "create_date": 1700000000,
          "user": {
            "id": 9001,
            "name": "Creator",
            "account": "creator9001"
          },
          "tags": [],
          "page_count": 1,
          "is_bookmarked": false
        }
        """
        return try JSONDecoder().decode(PixivArtwork.self, from: Data(payload.utf8))
    }

    private func samplePagedArtwork(pageCount: Int) -> PixivArtwork {
        PixivArtwork(
            id: 10,
            title: "Paged Sample",
            type: "manga",
            caption: "",
            user: PixivUser(id: 9001, name: "Creator", account: "creator9001"),
            tags: [],
            createDate: Date(timeIntervalSince1970: 1_700_000_000),
            pageCount: pageCount,
            width: 1200,
            height: 1600,
            totalView: 0,
            totalBookmarks: 0,
            totalComments: 0,
            isBookmarked: false,
            isMuted: false,
            isAI: false,
            sanityLevel: 0,
            xRestrict: 0,
            series: nil,
            images: (0..<pageCount).map { page in
                PixivImageSet(
                    squareMedium: URL(string: "https://example.com/\(page)_square.jpg")!,
                    medium: URL(string: "https://example.com/\(page)_medium.jpg")!,
                    large: URL(string: "https://example.com/\(page)_large.jpg")!,
                    original: URL(string: "https://example.com/\(page)_original.jpg")!
                )
            }
        )
    }
}
