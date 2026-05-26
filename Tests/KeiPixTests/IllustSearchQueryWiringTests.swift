import Foundation
import Testing
@testable import KeiPix

/// Pins the `/v1/search/illust` query wiring so we never silently drop
/// a bookmark threshold again. The earlier code had `bookmark_num_min`
/// connected and `bookmark_num_max` ignored — these tests would have
/// caught it.
@Suite("Illust search query wiring")
struct IllustSearchQueryWiringTests {
    @Test("Default options send no bookmark filters and inherit sort")
    func defaultOptionsOmitBookmarkFilters() {
        let query = PixivAPI.illustSearchQuery(keyword: "landscape", options: .defaultValue)

        #expect(query["sort"] == SearchSort.dateDescending.apiValue)
        #expect(query["word"] == "landscape")
        #expect(query["bookmark_num_min"] == nil)
        #expect(query["bookmark_num_max"] == nil)
    }

    @Test("Lower bookmark threshold maps to bookmark_num_min")
    func lowerBookmarkThresholdMapsToMin() {
        var options = SearchOptions.defaultValue
        options.minimumBookmarks = SearchBookmarkThreshold(value: 1_337)

        let query = PixivAPI.illustSearchQuery(keyword: "kei", options: options)

        #expect(query["bookmark_num_min"] == "1337")
        #expect(query["bookmark_num_max"] == nil)
    }

    @Test("Upper bookmark threshold maps to bookmark_num_max")
    func upperBookmarkThresholdMapsToMax() {
        var options = SearchOptions.defaultValue
        options.maximumBookmarks = SearchBookmarkThreshold(value: 9_876)

        let query = PixivAPI.illustSearchQuery(keyword: "kei", options: options)

        #expect(query["bookmark_num_max"] == "9876")
        #expect(query["bookmark_num_min"] == nil)
    }

    @Test("Both bookmark thresholds emit both query params")
    func bothBookmarkThresholdsEmitBothParams() {
        var options = SearchOptions.defaultValue
        options.minimumBookmarks = SearchBookmarkThreshold(value: 100)
        options.maximumBookmarks = SearchBookmarkThreshold(value: 5_000)

        let query = PixivAPI.illustSearchQuery(keyword: "kei", options: options)

        #expect(query["bookmark_num_min"] == "100")
        #expect(query["bookmark_num_max"] == "5000")
    }

    @Test("Age limit suffix is folded into the keyword")
    func ageLimitFoldsIntoKeyword() {
        var options = SearchOptions.defaultValue
        options.ageLimit = .allAges

        let query = PixivAPI.illustSearchQuery(keyword: "landscape", options: options)

        #expect(query["word"] == "landscape -R-18")
    }

    @Test("AI filter exclusion sends search_ai_type=1")
    func aiFilterExclusion() {
        var options = SearchOptions.defaultValue
        options.aiFilter = .excludeAI

        let query = PixivAPI.illustSearchQuery(keyword: "kei", options: options)

        #expect(query["search_ai_type"] == "1")
    }

    @Test("Match type controls search_target")
    func matchTypeControlsSearchTarget() {
        var options = SearchOptions.defaultValue
        options.matchType = .titleAndCaption

        let query = PixivAPI.illustSearchQuery(keyword: "kei", options: options)

        #expect(query["search_target"] == "title_and_caption")
    }
}
