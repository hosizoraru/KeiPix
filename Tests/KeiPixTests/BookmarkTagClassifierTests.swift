import Testing
@testable import KeiPix

struct BookmarkTagClassifierTests {
    @Test("Low-usage intersection tags do NOT auto-recommend; they stay in the artwork section")
    func conservativeRecommendation() {
        // Every artwork tag also lives in the library, but each library
        // entry only has 1-2 bookmarks under it — well under the
        // recommendation threshold. The previous classifier promoted all
        // of them to Recommended; the new one keeps Recommended empty.
        let grouping = BookmarkTagClassifier.classify(
            artworkTags: [
                PixivTag(name: "風景", translatedName: "landscape"),
                PixivTag(name: "オリジナル", translatedName: "original"),
                PixivTag(name: "rare-tag", translatedName: nil)
            ],
            libraryTags: [
                PixivBookmarkTag(name: "風景", count: 1),
                PixivBookmarkTag(name: "オリジナル", count: 2),
                PixivBookmarkTag(name: "favorites", count: 102)
            ],
            selectedTags: [],
            pinnedTags: []
        )

        #expect(grouping.recommended.isEmpty)
        // Artwork section keeps every artwork tag — including the ones
        // also in the library — and stamps them with the library count
        // so the chip can show usage even outside of Recommended.
        #expect(grouping.artwork.map(\.name) == ["風景", "オリジナル", "rare-tag"])
        #expect(grouping.library.map(\.name) == ["favorites"])
        #expect(grouping.custom.isEmpty)
    }

    @Test("High-usage library tags on the artwork are promoted to Recommended")
    func highUsageRecommendation() {
        let grouping = BookmarkTagClassifier.classify(
            artworkTags: [
                PixivTag(name: "風景", translatedName: "landscape"),
                PixivTag(name: "rare-tag", translatedName: nil)
            ],
            libraryTags: [
                PixivBookmarkTag(name: "風景", count: 14),
                PixivBookmarkTag(name: "favorites", count: 100)
            ],
            selectedTags: [],
            pinnedTags: []
        )

        #expect(grouping.recommended.map(\.name) == ["風景"])
        // Promoted tag is removed from the artwork section so each chip
        // only renders once in the sheet.
        #expect(grouping.artwork.map(\.name) == ["rare-tag"])
        #expect(grouping.library.map(\.name) == ["favorites"])
    }

    @Test("Pinned artwork tags always land in Recommended, even with low usage")
    func pinnedAlwaysRecommended() {
        let grouping = BookmarkTagClassifier.classify(
            artworkTags: [
                PixivTag(name: "starred", translatedName: nil),
                PixivTag(name: "風景", translatedName: nil)
            ],
            libraryTags: [
                PixivBookmarkTag(name: "starred", count: 1) // below threshold
            ],
            selectedTags: [],
            pinnedTags: ["starred"]
        )

        #expect(grouping.recommended.map(\.name) == ["starred"])
        #expect(grouping.recommended.first?.isPinned == true)
    }

    @Test("Selected tags from the library are promoted into Recommended")
    func selectedTagsPromoted() {
        // Even with a count of 1 (under the threshold), a selected tag
        // gets pushed up so the user's current picks stay at the top of
        // the sheet next to their other recommendations.
        let grouping = BookmarkTagClassifier.classify(
            artworkTags: [PixivTag(name: "風景", translatedName: nil)],
            libraryTags: [PixivBookmarkTag(name: "風景", count: 1)],
            selectedTags: ["風景"],
            pinnedTags: []
        )

        #expect(grouping.recommended.map(\.name) == ["風景"])
        #expect(grouping.artwork.isEmpty)
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

    @Test("Recommended section is capped at the configured maximum")
    func recommendedHasHardCap() {
        // Build artworkTags + libraryTags so every artwork tag would
        // qualify as recommended — then check that we trim to the cap.
        let count = BookmarkTagClassifier.recommendMaxCount + 4
        let artworkTags = (0..<count).map { PixivTag(name: "tag-\($0)", translatedName: nil) }
        let libraryTags = (0..<count).map { PixivBookmarkTag(name: "tag-\($0)", count: 50) }

        let grouping = BookmarkTagClassifier.classify(
            artworkTags: artworkTags,
            libraryTags: libraryTags,
            selectedTags: [],
            pinnedTags: []
        )

        #expect(grouping.recommended.count == BookmarkTagClassifier.recommendMaxCount)
        // Whatever didn't make the cut still shows up in the artwork
        // section so the user can still pick it.
        #expect(grouping.artwork.count == count - BookmarkTagClassifier.recommendMaxCount)
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

    @Test("Library section excludes any tag also on the artwork to avoid duplicate chips")
    func librarySkipsArtworkOverlap() {
        let grouping = BookmarkTagClassifier.classify(
            artworkTags: [PixivTag(name: "風景", translatedName: nil)],
            libraryTags: [
                PixivBookmarkTag(name: "風景", count: 1),
                PixivBookmarkTag(name: "favorites", count: 5)
            ],
            selectedTags: [],
            pinnedTags: []
        )

        #expect(grouping.artwork.map(\.name) == ["風景"])
        #expect(grouping.library.map(\.name) == ["favorites"])
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
        #expect(grouping.custom.first?.source == .custom)
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

    @Test("orderedSections only emits non-empty primary sources, never custom")
    func orderedSectionsSkipsEmptyAndCustom() {
        let grouping = BookmarkTagClassifier.classify(
            artworkTags: [PixivTag(name: "風景", translatedName: nil)],
            libraryTags: [],
            selectedTags: ["my-private-tag"],
            pinnedTags: []
        )

        // Custom has an entry, but `orderedSections` is for the three
        // primary buckets only — the editor renders custom in its own
        // inline panel above the sections.
        let sources = grouping.orderedSections.map(\.source)
        #expect(sources == [.artwork])
        #expect(grouping.custom.map(\.name) == ["my-private-tag"])
    }
}
