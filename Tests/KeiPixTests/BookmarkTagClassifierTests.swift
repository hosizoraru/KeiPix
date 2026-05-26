import Testing
@testable import KeiPix

struct BookmarkTagClassifierTests {
    @Test("Tags shared between artwork and library land in Recommended")
    func intersectionRecommends() {
        let grouping = BookmarkTagClassifier.classify(
            artworkTags: [
                PixivTag(name: "風景", translatedName: "landscape"),
                PixivTag(name: "オリジナル", translatedName: "original"),
                PixivTag(name: "rare-tag", translatedName: nil)
            ],
            libraryTags: [
                PixivBookmarkTag(name: "風景", count: 14),
                PixivBookmarkTag(name: "オリジナル", count: 7),
                PixivBookmarkTag(name: "favorites", count: 102)
            ],
            selectedTags: [],
            pinnedTags: []
        )

        #expect(grouping.recommended.map(\.name) == ["風景", "オリジナル"])
        #expect(grouping.artwork.map(\.name) == ["rare-tag"])
        #expect(grouping.library.map(\.name) == ["favorites"])
        #expect(grouping.custom.isEmpty)
    }

    @Test("Recommended candidates carry both translated names and library counts")
    func recommendedCarriesBothSignals() {
        let grouping = BookmarkTagClassifier.classify(
            artworkTags: [PixivTag(name: "風景", translatedName: "landscape")],
            libraryTags: [PixivBookmarkTag(name: "風景", count: 14)],
            selectedTags: [],
            pinnedTags: []
        )

        let candidate = try! #require(grouping.recommended.first)
        #expect(candidate.translatedName == "landscape")
        #expect(candidate.usageCount == 14)
        #expect(candidate.source == .recommended)
    }

    @Test("Library tags sort pinned first, then by descending usage count")
    func librarySortRespectsPinAndUsage() {
        let grouping = BookmarkTagClassifier.classify(
            artworkTags: [],
            libraryTags: [
                PixivBookmarkTag(name: "rare", count: 1),
                PixivBookmarkTag(name: "popular", count: 100),
                PixivBookmarkTag(name: "starred", count: 5)
            ],
            selectedTags: [],
            pinnedTags: ["starred"]
        )

        // starred is pinned -> first; popular has highest count -> next;
        // rare brings up the rear.
        #expect(grouping.library.map(\.name) == ["starred", "popular", "rare"])
    }

    @Test("Selected tags missing from both sources surface in Custom")
    func customCapturesUnknownSelections() {
        let grouping = BookmarkTagClassifier.classify(
            artworkTags: [PixivTag(name: "風景", translatedName: nil)],
            libraryTags: [PixivBookmarkTag(name: "favorites", count: 5)],
            selectedTags: ["my-private-tag", "風景"],
            pinnedTags: []
        )

        // 風景 already classified under Artwork, so it shouldn't double-list
        // in Custom; only the truly unknown tag lands there.
        #expect(grouping.custom.map(\.name) == ["my-private-tag"])
    }

    @Test("Translated names equal to the raw name are dropped as redundant")
    func dropsRedundantTranslations() {
        let grouping = BookmarkTagClassifier.classify(
            artworkTags: [
                PixivTag(name: "Original", translatedName: "original")
            ],
            libraryTags: [],
            selectedTags: [],
            pinnedTags: []
        )

        #expect(grouping.artwork.first?.translatedName == nil)
    }

    @Test("Empty tag names are skipped during classification")
    func skipsEmptyNames() {
        let grouping = BookmarkTagClassifier.classify(
            artworkTags: [
                PixivTag(name: "  ", translatedName: nil),
                PixivTag(name: "valid", translatedName: nil)
            ],
            libraryTags: [
                PixivBookmarkTag(name: "", count: 0),
                PixivBookmarkTag(name: "favorites", count: 1)
            ],
            selectedTags: [],
            pinnedTags: []
        )

        #expect(grouping.artwork.map(\.name) == ["valid"])
        #expect(grouping.library.map(\.name) == ["favorites"])
    }

    @Test("Duplicated artwork tags are deduplicated, preserving first occurrence")
    func dedupesArtworkTags() {
        let grouping = BookmarkTagClassifier.classify(
            artworkTags: [
                PixivTag(name: "風景", translatedName: "landscape"),
                PixivTag(name: "風景", translatedName: nil)
            ],
            libraryTags: [],
            selectedTags: [],
            pinnedTags: []
        )

        #expect(grouping.artwork.count == 1)
        #expect(grouping.artwork.first?.translatedName == "landscape")
    }

    @Test("orderedSections only emits non-empty sources in priority order")
    func orderedSectionsSkipsEmpty() {
        let grouping = BookmarkTagClassifier.classify(
            artworkTags: [PixivTag(name: "風景", translatedName: nil)],
            libraryTags: [],
            selectedTags: [],
            pinnedTags: []
        )

        let sources = grouping.orderedSections.map(\.source)
        #expect(sources == [.artwork])
    }
}
