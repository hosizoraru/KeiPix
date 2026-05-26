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
}
