import Foundation
import Testing
@testable import KeiPix

@Suite("Search options")
struct SearchOptionsTests {
    @Test("Remote Pixiv search options decode artwork and novel metadata")
    func remotePixivSearchOptionsDecode() throws {
        let payload = """
        {
          "illust": {
            "bookmark_ranges": [
              { "bookmark_num_min": "100", "bookmark_num_max": "999" },
              { "bookmark_num_min": "1000", "bookmark_num_max": "*" }
            ],
            "show_ai_condition": true,
            "lang": {
              "options": [
                { "code": "ja", "name": "日本語" },
                { "code": "en", "name": "English" }
              ]
            },
            "tool": {
              "options": ["CLIP STUDIO PAINT", "Photoshop"]
            }
          },
          "novel": {
            "bookmark_ranges": [
              { "bookmark_num_min": "*", "bookmark_num_max": "99" }
            ],
            "show_ai_condition": false,
            "lang": {
              "options": [
                { "code": "zh", "name": "中文" }
              ]
            },
            "genre": {
              "options": [
                { "id": 1, "label": "Fantasy" }
              ]
            },
            "word_count_supported_languages": "ja,en"
          }
        }
        """

        let options = try JSONDecoder().decode(PixivRemoteSearchOptions.self, from: Data(payload.utf8))

        #expect(options.illust.bookmarkRanges.count == 2)
        #expect(options.illust.bookmarkRanges[0].minimum == 100)
        #expect(options.illust.bookmarkRanges[0].maximum == 999)
        #expect(options.illust.bookmarkRanges[1].minimum == 1_000)
        #expect(options.illust.bookmarkRanges[1].maximum == nil)
        #expect(options.illust.showAICondition)
        #expect(options.illust.languages.options.map(\.code) == ["ja", "en"])
        #expect(options.illust.tools.options == ["CLIP STUDIO PAINT", "Photoshop"])
        #expect(options.novel.bookmarkRanges[0].minimum == nil)
        #expect(options.novel.bookmarkRanges[0].maximum == 99)
        #expect(options.novel.showAICondition == false)
        #expect(options.novel.languages.options.first?.name == "中文")
        #expect(options.novel.genres.options.first?.label == "Fantasy")
        #expect(options.novel.wordCountSupportedLanguageCodes == ["ja", "en"])
    }

    @Test("Remote Pixiv search options endpoint uses app-api search options path")
    func remotePixivSearchOptionsEndpoint() throws {
        let url = try PixivAPI.remoteSearchOptionsURL()
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))

        #expect(components.path == "/v1/search/options")
        #expect(components.queryItems?.isEmpty ?? true)
    }

    @Test("Default options keep the native search baseline")
    func defaultOptions() {
        let options = SearchOptions.defaultValue

        #expect(options.matchType == .partialTags)
        #expect(options.sort == .dateDescending)
        #expect(options.ageLimit == .unlimited)
        #expect(options.dateRange == .anytime)
        #expect(options.minimumBookmarks.isUnlimited)
        #expect(options.maximumBookmarks.isUnlimited)
        #expect(options.artworkType == .all)
        #expect(options.aiFilter == .all)
        #expect(options.ugoiraFilter == .all)
        #expect(options.isDefault)
    }

    @Test("Saved search presets decode legacy raw-int bookmark thresholds")
    func decodesLegacySavedSearchPresetOptions() throws {
        // Pre-refactor presets serialised the threshold as a raw `Int`
        // because `SearchMinimumBookmarks` / `SearchMaximumBookmarks`
        // were `Int`-backed enums. The new keyed `SearchBookmarkThreshold`
        // accepts both shapes so existing libraries keep working.
        let json = """
        {
          "matchType": "exactTags",
          "sort": "dateAscending",
          "ageLimit": "r18",
          "dateRange": "pastWeek",
          "minimumBookmarks": 500,
          "maximumBookmarks": 12345,
          "artworkType": "manga",
          "ugoiraFilter": "onlyUgoira"
        }
        """

        let options = try JSONDecoder().decode(SearchOptions.self, from: Data(json.utf8))

        #expect(options.matchType == .exactTags)
        #expect(options.sort == .dateAscending)
        #expect(options.ageLimit == .r18)
        #expect(options.dateRange == .pastWeek)
        #expect(options.minimumBookmarks.value == 500)
        #expect(options.maximumBookmarks.value == 12_345)
        #expect(options.artworkType == .manga)
        #expect(options.aiFilter == .all)
        #expect(options.ugoiraFilter == .onlyUgoira)
    }

    @Test("Saved search library export round trips with custom thresholds")
    func savedSearchLibraryExportRoundTrips() throws {
        let preset = SavedSearchPreset(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            keyword: "landscape",
            options: SearchOptions(
                matchType: .exactTags,
                sort: .dateAscending,
                ageLimit: .allAges,
                dateRange: .pastMonth,
                minimumBookmarks: SearchBookmarkThreshold(value: 1_337),
                maximumBookmarks: SearchBookmarkThreshold(value: 9_876),
                artworkType: .illustrations,
                aiFilter: .excludeAI,
                ugoiraFilter: .noUgoira
            ),
            createdAt: Date(timeIntervalSince1970: 1),
            updatedAt: Date(timeIntervalSince1970: 2)
        )
        let library = SavedSearchLibraryExport(
            exportedAt: Date(timeIntervalSince1970: 3),
            presets: [preset],
            savedSearches: ["landscape", "blue archive"],
            searchHistory: ["cat"]
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(library)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(SavedSearchLibraryExport.self, from: data)

        #expect(decoded.schemaVersion == 1)
        #expect(decoded.presets.first?.keyword == "landscape")
        #expect(decoded.presets.first?.options.minimumBookmarks.value == 1_337)
        #expect(decoded.presets.first?.options.maximumBookmarks.value == 9_876)
        #expect(decoded.savedSearches == ["landscape", "blue archive"])
        #expect(decoded.searchHistory == ["cat"])
    }

    @Test("Summary collapses bookmark thresholds into a single human range")
    func summaryFormatsBookmarkThresholds() {
        let unlimited = SearchOptions.defaultValue
        #expect(unlimited.summary.contains(L10n.noBookmarkLimit))

        let lower = SearchOptions(
            matchType: .partialTags,
            sort: .dateDescending,
            ageLimit: .unlimited,
            dateRange: .anytime,
            minimumBookmarks: SearchBookmarkThreshold(value: 500),
            maximumBookmarks: .unlimited,
            artworkType: .all,
            aiFilter: .all,
            ugoiraFilter: .all
        )
        #expect(lower.summary.contains("≥") && lower.summary.contains("500"))

        let upper = SearchOptions(
            matchType: .partialTags,
            sort: .dateDescending,
            ageLimit: .unlimited,
            dateRange: .anytime,
            minimumBookmarks: .unlimited,
            maximumBookmarks: SearchBookmarkThreshold(value: 5_000),
            artworkType: .all,
            aiFilter: .all,
            ugoiraFilter: .all
        )
        #expect(upper.summary.contains("≤") && upper.summary.contains("5,000"))

        let both = SearchOptions(
            matchType: .partialTags,
            sort: .dateDescending,
            ageLimit: .unlimited,
            dateRange: .anytime,
            minimumBookmarks: SearchBookmarkThreshold(value: 100),
            maximumBookmarks: SearchBookmarkThreshold(value: 1_000),
            artworkType: .all,
            aiFilter: .all,
            ugoiraFilter: .all
        )
        #expect(both.summary.contains("100") && both.summary.contains("1,000"))
    }

    @Test("Premium search sorts are gated")
    func premiumSearchSortsAreGated() {
        let regularSorts = SearchSort.availableCases(isPremium: false)
        let premiumSorts = SearchSort.availableCases(isPremium: true)

        #expect(regularSorts.contains(.popularPreview))
        #expect(regularSorts.contains(.popularMale) == false)
        #expect(regularSorts.contains(.popularFemale) == false)
        #expect(premiumSorts.contains(.popularMale))
        #expect(premiumSorts.contains(.popularFemale))
        #expect(SearchSort.selectableCases(isPremium: false) == [.dateDescending, .dateAscending, .popularPreview])
        #expect(SearchSort.premiumOnlyCases == [.popularMale, .popularFemale])
        #expect(SearchSort.popularMale.apiValue == "popular_male_desc")
        #expect(SearchSort.popularFemale.apiValue == "popular_female_desc")
    }

    @Test("Non-premium popular sorting uses limited preview language")
    func nonPremiumPopularSortingUsesLimitedPreviewLanguage() {
        #expect(SearchSort.popularPreview.title(isPremium: false) == L10n.popularLimitedPreview)
        #expect(SearchSort.popularPreview.title(isPremium: true) == L10n.popular)
        #expect(SearchSort.popularPreview.requiresPixivPremium == false)
        #expect(SearchSort.popularPreview.apiValue == "popular_desc")
        #expect(SearchSort.popularPreview.showsPixivPremiumMarker(isPremium: false))
        #expect(SearchSort.popularPreview.showsPixivPremiumMarker(isPremium: true) == false)
        #expect(SearchSort.popularMale.showsPixivPremiumMarker(isPremium: true))
    }

    @Test("Bookmark threshold tolerates negative input by clamping to unlimited")
    func bookmarkThresholdClampsNegative() {
        let clamped = SearchBookmarkThreshold(value: -42)
        #expect(clamped.isUnlimited)
        #expect(clamped.title == L10n.noBookmarkLimit)
    }

    @Test("Bookmark threshold preset rungs match Pixez ladder")
    func bookmarkThresholdPresetRungs() {
        #expect(SearchBookmarkThreshold.presetRungs.contains(100))
        #expect(SearchBookmarkThreshold.presetRungs.contains(500))
        #expect(SearchBookmarkThreshold.presetRungs.contains(1_000))
        #expect(SearchBookmarkThreshold.presetRungs.contains(5_000))
        #expect(SearchBookmarkThreshold.presetRungs.contains(100_000))
        #expect(SearchBookmarkThreshold.presetRungs.first == 0)
    }

    @Test("Search diagnostics cover premium popularity probes")
    func searchDiagnosticsCoverPremiumPopularityProbes() {
        let probes = SearchDiagnosticProbe.defaultProbes

        #expect(probes.map(\.options.sort) == [.popularPreview, .popularMale, .popularFemale])
        #expect(probes.allSatisfy { $0.keyword == SearchDiagnosticProbe.defaultKeyword })
        #expect(probes.first?.options.ageLimit == .allAges)
        #expect(probes.filter { $0.options.sort.requiresPixivPremium }.count == 2)
    }

    @Test("Pixiv Web links preserve searchable options")
    func pixivWebSearchURL() throws {
        let url = try #require(PixivWebURLBuilder.searchURL(
            keyword: "landscape",
            options: SearchOptions(
                matchType: .titleAndCaption,
                sort: .popularMale,
                ageLimit: .allAges,
                dateRange: .anytime,
                minimumBookmarks: .unlimited,
                maximumBookmarks: .unlimited,
                artworkType: .all,
                aiFilter: .all,
                ugoiraFilter: .all
            )
        ))

        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let queryItems = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).compactMap { item in
            item.value.map { (item.name, $0) }
        })

        #expect(components.scheme == "https")
        #expect(components.host == "www.pixiv.net")
        #expect(components.path == "/tags/landscape -R-18/artworks")
        #expect(queryItems["s_mode"] == "s_tc")
        #expect(queryItems["order"] == "popular_male_d")
    }

    @Test("Pixiv Web bookmark URLs point at profile bookmark surfaces")
    func pixivWebBookmarkURLs() throws {
        let bookmarksURL = try #require(PixivWebURLBuilder.userBookmarkArtworksURL(userID: "41657557"))
        let createdCollectionsURL = try #require(PixivWebURLBuilder.userPublishedCollectionsURL(userID: "41657557"))
        let bookmarkedCollectionsURL = try #require(PixivWebURLBuilder.userBookmarkCollectionsURL(userID: "41657557"))
        let allCollectionsURL = try #require(PixivWebURLBuilder.collectionsURL())
        let collectionURL = try #require(PixivWebURLBuilder.collectionURL(id: "49895345339794251171"))

        #expect(bookmarksURL.absoluteString == "https://www.pixiv.net/users/41657557/bookmarks/artworks")
        #expect(createdCollectionsURL.absoluteString == "https://www.pixiv.net/users/41657557/collections")
        #expect(bookmarkedCollectionsURL.absoluteString == "https://www.pixiv.net/users/41657557/bookmarks/collections")
        #expect(allCollectionsURL.absoluteString == "https://www.pixiv.net/collections")
        #expect(collectionURL.absoluteString == "https://www.pixiv.net/collections/49895345339794251171")
    }
}
