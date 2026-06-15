import Foundation
import Testing
@testable import KeiPix

/// Pins the privacy gating + content shape of the CoreSpotlight
/// mapping. The actual `CSSearchableIndex` work lives in
/// `SpotlightIndexer` and is gated behind privacy + opt-in toggles —
/// this suite exercises the pure mapping so the gating rules are
/// fixed without needing to spin up the system index.
@Suite("Download Spotlight attributes mapping")
struct DownloadSpotlightAttributesTests {

    @Test("Returns nil when indexing is disabled even for a completed item")
    func optOutBlocksMapping() {
        let item = makeItem()
        let gating = SpotlightIndexingGating(
            indexingEnabled: false,
            hideAI: false,
            hideR18: false,
            hideR18G: false
        )

        #expect(DownloadSpotlightAttributes.make(item: item, gating: gating) == nil)
    }

    @Test("Skips items that have not finished downloading")
    func nonCompletedItemsAreSkipped() {
        let item = makeItem(status: .downloading)
        let gating = enabledGating()

        #expect(DownloadSpotlightAttributes.make(item: item, gating: gating) == nil)
    }

    @Test("AI items are dropped when hide AI is on")
    func hideAIDropsAIItem() {
        let item = makeItem(isAI: true)
        let gating = SpotlightIndexingGating(
            indexingEnabled: true,
            hideAI: true,
            hideR18: false,
            hideR18G: false
        )

        #expect(DownloadSpotlightAttributes.make(item: item, gating: gating) == nil)
    }

    @Test("R-18 items are dropped when hide R-18 is on")
    func hideR18DropsR18Item() {
        let item = makeItem(isR18: true)
        let gating = SpotlightIndexingGating(
            indexingEnabled: true,
            hideAI: false,
            hideR18: true,
            hideR18G: false
        )

        #expect(DownloadSpotlightAttributes.make(item: item, gating: gating) == nil)
    }

    @Test("R-18G items are dropped when hide R-18G is on")
    func hideR18GDropsR18GItem() {
        let item = makeItem(isR18G: true)
        let gating = SpotlightIndexingGating(
            indexingEnabled: true,
            hideAI: false,
            hideR18: false,
            hideR18G: true
        )

        #expect(DownloadSpotlightAttributes.make(item: item, gating: gating) == nil)
    }

    @Test("R-18G items are not dropped by the R-18-only hide toggle")
    func hideR18DoesNotDropR18GItem() {
        let item = makeItem(isR18: true, isR18G: true)
        let gating = SpotlightIndexingGating(
            indexingEnabled: true,
            hideAI: false,
            hideR18: true,
            hideR18G: false
        )

        #expect(DownloadSpotlightAttributes.make(item: item, gating: gating) != nil)
    }

    @Test("Tags are stripped entirely when any hide toggle is on, even if the item is clean")
    func tagsAreRedactedWhenAnyHideToggleIsOn() {
        let item = makeItem(tags: ["風景", "オリジナル"])
        let gating = SpotlightIndexingGating(
            indexingEnabled: true,
            hideAI: true,  // toggle is on but item isn't AI
            hideR18: false,
            hideR18G: false
        )

        let attributes = DownloadSpotlightAttributes.make(item: item, gating: gating)

        #expect(attributes != nil)
        #expect(attributes?.keywords.contains("風景") == false)
        #expect(attributes?.keywords.contains("オリジナル") == false)
        // Creator name and artwork id remain — those are the
        // baseline keywords every entry carries.
        #expect(attributes?.keywords.contains("Creator") == true)
    }

    @Test("Tags are kept when no hide toggle is on")
    func tagsAreKeptWhenAllTogglesOff() {
        let item = makeItem(tags: ["風景", "オリジナル"])
        let attributes = DownloadSpotlightAttributes.make(item: item, gating: enabledGating())

        #expect(attributes != nil)
        #expect(attributes?.keywords.contains("風景") == true)
        #expect(attributes?.keywords.contains("オリジナル") == true)
    }

    @Test("Title and byline shape match what Spotlight surfaces")
    func displayShapeMatchesExpectations() {
        let item = makeItem(title: "Morning Light", pageCount: 3)
        let attributes = DownloadSpotlightAttributes.make(item: item, gating: enabledGating())

        #expect(attributes?.title == "Morning Light")
        #expect(attributes?.contentDescription == "Creator · 3P")
    }

    @Test("Empty title falls back to a Pixiv id-prefixed string so Spotlight never shows a blank row")
    func emptyTitleFallsBackToPixivID() {
        let item = makeItem(title: "")
        let attributes = DownloadSpotlightAttributes.make(item: item, gating: enabledGating())

        #expect(attributes?.title == "Pixiv #42")
    }

    @Test("Identifier is stable across re-indexes")
    func identifierIsStable() {
        let first = DownloadSpotlightAttributes.make(item: makeItem(), gating: enabledGating())
        let second = DownloadSpotlightAttributes.make(item: makeItem(), gating: enabledGating())

        #expect(first?.identifier == second?.identifier)
        #expect(first?.identifier == "artwork.42")
    }

    @Test("Thumbnail prefers an image file over other downloaded paths")
    func thumbnailPrefersImageFile() {
        let item = makeItem(downloadedFilePaths: [
            "/tmp/keipix-test/42.json",
            "/tmp/keipix-test/42.zip",
            "/tmp/keipix-test/42_p0.jpg"
        ])
        let attributes = DownloadSpotlightAttributes.make(item: item, gating: enabledGating())

        #expect(attributes?.thumbnailFileURL?.lastPathComponent == "42_p0.jpg")
    }

    private func enabledGating() -> SpotlightIndexingGating {
        SpotlightIndexingGating(
            indexingEnabled: true,
            hideAI: false,
            hideR18: false,
            hideR18G: false
        )
    }

    private func makeItem(
        title: String = "Sample",
        pageCount: Int = 1,
        status: ArtworkDownloadStatus = .completed,
        tags: [String]? = nil,
        isAI: Bool? = nil,
        isR18: Bool? = nil,
        isR18G: Bool? = nil,
        downloadedFilePaths: [String]? = nil
    ) -> ArtworkDownloadItem {
        ArtworkDownloadItem(
            id: UUID(),
            artworkID: 42,
            title: title,
            creatorName: "Creator",
            tags: tags,
            isAI: isAI,
            isR18: isR18,
            isR18G: isR18G,
            artifactKind: .imagePages,
            pageCount: pageCount,
            completedPages: pageCount,
            status: status,
            folderPath: "/tmp/keipix-test",
            sourceImageURLs: [],
            downloadedFilePaths: downloadedFilePaths,
            errorMessage: nil,
            createdAt: Date(timeIntervalSince1970: 0),
            updatedAt: Date(timeIntervalSince1970: 0)
        )
    }
}
