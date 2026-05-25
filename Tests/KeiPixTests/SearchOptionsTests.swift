import Foundation
import Testing
@testable import KeiPix

@Suite("Search options")
struct SearchOptionsTests {
    @Test("Default options keep the native search baseline")
    func defaultOptions() {
        let options = SearchOptions.defaultValue

        #expect(options.matchType == .partialTags)
        #expect(options.sort == .dateDescending)
        #expect(options.ageLimit == .unlimited)
        #expect(options.dateRange == .anytime)
        #expect(options.minimumBookmarks == .none)
        #expect(options.maximumBookmarks == .none)
        #expect(options.artworkType == .all)
        #expect(options.aiFilter == .all)
        #expect(options.ugoiraFilter == .all)
        #expect(options.isDefault)
    }

    @Test("Saved search presets decode older payloads")
    func decodesLegacySavedSearchPresetOptions() throws {
        let json = """
        {
          "matchType": "exactTags",
          "sort": "dateAscending",
          "ageLimit": "r18",
          "dateRange": "pastWeek",
          "minimumBookmarks": 500,
          "artworkType": "manga",
          "ugoiraFilter": "onlyUgoira"
        }
        """

        let options = try JSONDecoder().decode(SearchOptions.self, from: Data(json.utf8))

        #expect(options.matchType == .exactTags)
        #expect(options.sort == .dateAscending)
        #expect(options.ageLimit == .r18)
        #expect(options.dateRange == .pastWeek)
        #expect(options.minimumBookmarks == .fiveHundred)
        #expect(options.maximumBookmarks == .none)
        #expect(options.artworkType == .manga)
        #expect(options.aiFilter == .all)
        #expect(options.ugoiraFilter == .onlyUgoira)
    }

    @Test("Summary includes advanced filter state")
    func summaryIncludesAdvancedFilters() {
        let options = SearchOptions(
            matchType: .titleAndCaption,
            sort: .popularFemale,
            ageLimit: .allAges,
            dateRange: .pastMonth,
            minimumBookmarks: .oneHundred,
            maximumBookmarks: .fiveThousand,
            artworkType: .illustrations,
            aiFilter: .excludeAI,
            ugoiraFilter: .noUgoira
        )

        #expect(options.summary.contains(SearchMaximumBookmarks.fiveThousand.title))
        #expect(options.summary.contains(SearchSort.popularFemale.title))
        #expect(options.summary.contains(SearchAIFilter.excludeAI.title))
        #expect(options.summary.contains(SearchUgoiraFilter.noUgoira.title))
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
        #expect(SearchSort.popularMale.apiValue == "popular_male_desc")
        #expect(SearchSort.popularFemale.apiValue == "popular_female_desc")
    }

    @Test("Bookmark thresholds match high-popularity search ranges")
    func bookmarkThresholdsIncludeHighPopularityRanges() {
        #expect(SearchMinimumBookmarks.allCases.contains(.twentyThousand))
        #expect(SearchMinimumBookmarks.allCases.contains(.fiftyThousand))
        #expect(SearchMinimumBookmarks.allCases.contains(.oneHundredThousand))
        #expect(SearchMaximumBookmarks.oneHundredThousand.title.contains("100,000"))
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
                minimumBookmarks: .none,
                maximumBookmarks: .none,
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
}
