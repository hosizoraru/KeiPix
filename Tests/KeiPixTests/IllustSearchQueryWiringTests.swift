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

    @Test("Artwork and ugoira filters map to Pixiv content_type when available")
    func artworkAndUgoiraFiltersMapToContentType() {
        var illustrationsOnly = SearchOptions.defaultValue
        illustrationsOnly.artworkType = .illustrations
        illustrationsOnly.ugoiraFilter = .noUgoira
        #expect(PixivAPI.illustSearchQuery(keyword: "kei", options: illustrationsOnly)["content_type"] == "illust")

        var ugoiraOnly = SearchOptions.defaultValue
        ugoiraOnly.ugoiraFilter = .onlyUgoira
        #expect(PixivAPI.illustSearchQuery(keyword: "kei", options: ugoiraOnly)["content_type"] == "ugoira")

        var mangaOnly = SearchOptions.defaultValue
        mangaOnly.artworkType = .manga
        #expect(PixivAPI.illustSearchQuery(keyword: "kei", options: mangaOnly)["content_type"] == "manga")

        var allNonUgoira = SearchOptions.defaultValue
        allNonUgoira.ugoiraFilter = .noUgoira
        #expect(PixivAPI.illustSearchQuery(keyword: "kei", options: allNonUgoira)["content_type"] == nil)
    }
}

@Suite("Novel search query wiring")
struct NovelSearchQueryWiringTests {
    @Test("Default options keep the current novel search baseline")
    func defaultOptionsKeepBaseline() {
        let query = PixivAPI.novelSearchQuery(keyword: "静海", options: .defaultValue)

        #expect(query["word"] == "静海")
        #expect(query["search_target"] == SearchMatchType.partialTags.apiValue)
        #expect(query["sort"] == SearchSort.dateDescending.apiValue)
        #expect(query["merge_plain_keyword_results"] == "true")
        #expect(query["include_translated_tag_results"] == "true")
        #expect(query["filter"] == "for_android")
        #expect(query["bookmark_num"] == nil)
        #expect(query["search_ai_type"] == nil)
    }

    @Test("Existing search filters map into novel search query parameters")
    func existingSearchFiltersMapIntoNovelSearchQuery() throws {
        var options = SearchOptions.defaultValue
        options.matchType = .titleAndCaption
        options.sort = .dateAscending
        options.ageLimit = .allAges
        options.dateRange = .pastWeek
        options.minimumBookmarks = SearchBookmarkThreshold(value: 500)
        options.maximumBookmarks = SearchBookmarkThreshold(value: 2_000)
        options.aiFilter = .onlyAI
        options.novelLanguageCode = "ja"
        options.novelGenreID = 7
        options.novelTextLength = .medium

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        let now = try #require(DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: 2026,
            month: 6,
            day: 13
        ).date)
        let query = PixivAPI.novelSearchQuery(keyword: "novel", options: options, now: now, calendar: calendar)

        #expect(query["word"] == "novel -R-18")
        #expect(query["search_target"] == SearchMatchType.titleAndCaption.apiValue)
        #expect(query["sort"] == SearchSort.dateAscending.apiValue)
        #expect(query["search_ai_type"] == "2")
        #expect(query["bookmark_num"] == "500")
        #expect(query["start_date"] == "2026-06-06")
        #expect(query["end_date"] == "2026-06-13")
        #expect(query["lang"] == "ja")
        #expect(query["genre"] == "7")
        #expect(query["text_length_min"] == "20000")
        #expect(query["text_length_max"] == "79999")
        #expect(query["bookmark_num_max"] == nil)
    }
}

@MainActor
@Suite("Novel search filter wiring")
struct NovelSearchFilterWiringTests {
    @MainActor
    @Test("Creator preview artwork cache honors current content filters")
    func creatorPreviewArtworkCacheHonorsCurrentContentFilters() {
        let store = KeiPixStore(
            downloads: ArtworkDownloadStore(completionNotifier: DownloadCompletionNotifier(
                center: FakeUserNotificationCenter(isAuthorized: false),
                authorizationStore: InMemoryAuthorizationCacheStore(hasRequested: true),
                coalesceWindowSeconds: 0.05
            )),
            bootstrapsAutomatically: false
        )
        let creator = PixivUser(id: 900, name: "Creator", account: "creator")
        let allAges = artwork(id: 1, user: creator, isAI: false, xRestrict: 0)
        let ai = artwork(id: 2, user: creator, isAI: true, xRestrict: 0)
        let r18 = artwork(id: 3, user: creator, isAI: false, xRestrict: 1)
        let r18g = artwork(id: 4, user: creator, isAI: false, xRestrict: 2)
        store.creatorPreviewArtworkCache[creator.id] = [allAges, ai, r18, r18g]

        #expect(r18.requiresScreenCaptureProtection)
        #expect(r18g.requiresScreenCaptureProtection)

        store.hideAIArtworks = false
        store.hideR18Artworks = true
        store.hideR18GArtworks = false
        #expect(store.cachedCreatorPreviewArtworks(for: creator).map(\.id) == [1, 2, 4])

        store.hideR18Artworks = false
        store.hideR18GArtworks = true
        #expect(store.cachedCreatorPreviewArtworks(for: creator).map(\.id) == [1, 2, 3])

        store.hideAIArtworks = true
        store.hideR18Artworks = true
        store.hideR18GArtworks = true
        #expect(store.cachedCreatorPreviewArtworks(for: creator).map(\.id) == [1])

        store.hideAIArtworks = false
        store.hideR18Artworks = false
        store.hideR18GArtworks = false
        #expect(store.cachedCreatorPreviewArtworks(for: creator).map(\.id) == [1, 2, 3, 4])
    }

    @MainActor
    @Test("Content filter setters refresh creator preview surfaces")
    func contentFilterSettersRefreshCreatorPreviewSurfaces() {
        let defaults = UserDefaults.standard
        let previousHideR18Value = defaults.object(forKey: "hideR18Artworks")
        defer {
            if let previousHideR18Value {
                defaults.set(previousHideR18Value, forKey: "hideR18Artworks")
            } else {
                defaults.removeObject(forKey: "hideR18Artworks")
            }
        }
        let store = KeiPixStore(
            downloads: ArtworkDownloadStore(completionNotifier: DownloadCompletionNotifier(
                center: FakeUserNotificationCenter(isAuthorized: false),
                authorizationStore: InMemoryAuthorizationCacheStore(hasRequested: true),
                coalesceWindowSeconds: 0.05
            )),
            bootstrapsAutomatically: false
        )
        store.hideR18Artworks = false
        store.contentFilterGeneration = 0
        store.creatorPreviewArtworkCacheGeneration = 0

        store.setHideR18Artworks(true)

        #expect(store.contentFilterGeneration == 1)
        #expect(store.creatorPreviewArtworkCacheGeneration == 1)
    }

    @MainActor
    @Test("Creator preview artwork cache evicts least recent authors")
    func creatorPreviewArtworkCacheEvictsLeastRecentAuthors() {
        let store = KeiPixStore(
            downloads: ArtworkDownloadStore(completionNotifier: DownloadCompletionNotifier(
                center: FakeUserNotificationCenter(isAuthorized: false),
                authorizationStore: InMemoryAuthorizationCacheStore(hasRequested: true),
                coalesceWindowSeconds: 0.05
            )),
            bootstrapsAutomatically: false
        )

        for userID in 0..<(KeiPixStore.creatorPreviewArtworkCacheLimit + 4) {
            let user = PixivUser(id: userID, name: "Creator \(userID)", account: "creator_\(userID)")
            store.cacheCreatorPreviewArtworks(
                [artwork(id: userID, user: user, isAI: false, xRestrict: 0)],
                forUserID: userID
            )
        }

        #expect(store.creatorPreviewArtworkCache.count == KeiPixStore.creatorPreviewArtworkCacheLimit)
        #expect(store.creatorPreviewArtworkCache[0] == nil)
        #expect(store.creatorPreviewArtworkCache[1] == nil)
        #expect(store.creatorPreviewArtworkCache[2] == nil)
        #expect(store.creatorPreviewArtworkCache[3] == nil)
        #expect(store.creatorPreviewArtworkCache[4]?.first?.id == 4)
    }

    @MainActor
    @Test("Novel detail cache evicts least recent novels")
    func novelDetailCacheEvictsLeastRecentNovels() throws {
        let store = KeiPixStore(
            downloads: ArtworkDownloadStore(completionNotifier: DownloadCompletionNotifier(
                center: FakeUserNotificationCenter(isAuthorized: false),
                authorizationStore: InMemoryAuthorizationCacheStore(hasRequested: true),
                coalesceWindowSeconds: 0.05
            )),
            bootstrapsAutomatically: false
        )

        for novelID in 0..<(NovelFeatureStore.novelDetailCacheLimit + 4) {
            store.novels.cacheNovelDetailForTesting(try novel(id: novelID))
        }

        #expect(store.novels.cachedNovelDetailCountForTesting == NovelFeatureStore.novelDetailCacheLimit)
        #expect(store.novels.cachedNovelDetailForTesting(id: 0) == nil)
        #expect(store.novels.cachedNovelDetailForTesting(id: 1) == nil)
        #expect(store.novels.cachedNovelDetailForTesting(id: 2) == nil)
        #expect(store.novels.cachedNovelDetailForTesting(id: 3) == nil)
        #expect(store.novels.cachedNovelDetailForTesting(id: 4)?.id == 4)
    }

    @Test("Novel search applies shared search filters locally")
    func novelSearchAppliesSharedSearchFiltersLocally() throws {
        let store = KeiPixStore(
            downloads: ArtworkDownloadStore(completionNotifier: DownloadCompletionNotifier(
                center: FakeUserNotificationCenter(isAuthorized: false),
                authorizationStore: InMemoryAuthorizationCacheStore(hasRequested: true),
                coalesceWindowSeconds: 0.05
            )),
            bootstrapsAutomatically: false
        )
        store.selectedRoute = .novelSearch
        store.searchMaximumBookmarks = SearchBookmarkThreshold(value: 500)
        store.searchAIFilter = .excludeAI

        let aiR18Novel = try #require(VisualQASampleData.novelFeedNovels.first { $0.isAI && $0.totalBookmarks > 500 })
        let r18gLowBookmarkNovel = try #require(VisualQASampleData.novelFeedNovels.first { $0.isR18G && $0.totalBookmarks <= 500 })
        let allAgesLowBookmarkNovel = try #require(VisualQASampleData.novelFeedNovels.first { $0.isR18 == false && $0.totalBookmarks <= 500 })

        #expect(store.passesNovelContentFilter(aiR18Novel) == false)
        #expect(store.passesNovelContentFilter(r18gLowBookmarkNovel))
        #expect(store.passesNovelContentFilter(allAgesLowBookmarkNovel))

        store.searchAgeLimit = .allAges
        #expect(store.passesNovelContentFilter(r18gLowBookmarkNovel) == false)
        #expect(store.passesNovelContentFilter(allAgesLowBookmarkNovel))

        store.searchAgeLimit = .r18
        #expect(store.passesNovelContentFilter(r18gLowBookmarkNovel))
        #expect(store.passesNovelContentFilter(allAgesLowBookmarkNovel) == false)

        store.searchAgeLimit = .unlimited
        store.searchMaximumBookmarks = .unlimited
        store.searchAIFilter = .all
        store.searchNovelTextLength = .short
        let mediumLengthNovel = try #require(VisualQASampleData.novelFeedNovels.first { $0.textLength >= 20_000 })
        #expect(store.passesNovelContentFilter(allAgesLowBookmarkNovel))
        #expect(store.passesNovelContentFilter(mediumLengthNovel) == false)
    }

    @Test("Non-search novel feeds ignore search-only filters")
    func nonSearchNovelFeedsIgnoreSearchOnlyFilters() throws {
        let store = KeiPixStore(
            downloads: ArtworkDownloadStore(completionNotifier: DownloadCompletionNotifier(
                center: FakeUserNotificationCenter(isAuthorized: false),
                authorizationStore: InMemoryAuthorizationCacheStore(hasRequested: true),
                coalesceWindowSeconds: 0.05
            )),
            bootstrapsAutomatically: false
        )
        store.selectedRoute = .novelRecommended
        store.searchMaximumBookmarks = SearchBookmarkThreshold(value: 1)
        store.searchNovelTextLength = .short
        let popularNovel = try #require(VisualQASampleData.novelFeedNovels.first { $0.totalBookmarks > 1 })

        #expect(store.passesNovelContentFilter(popularNovel))
    }

    private func artwork(
        id: Int,
        user: PixivUser,
        isAI: Bool,
        xRestrict: Int
    ) -> PixivArtwork {
        PixivArtwork(
            id: id,
            title: "Artwork \(id)",
            type: "illust",
            caption: "",
            user: user,
            tags: [],
            createDate: Date(timeIntervalSince1970: TimeInterval(id)),
            pageCount: 1,
            width: 1200,
            height: 1600,
            totalView: 100,
            totalBookmarks: 10,
            totalComments: 0,
            isBookmarked: false,
            isMuted: false,
            isAI: isAI,
            sanityLevel: 2,
            xRestrict: xRestrict,
            series: nil,
            images: [
                PixivImageSet(
                    squareMedium: URL(string: "https://example.com/\(id)-square.jpg"),
                    medium: URL(string: "https://example.com/\(id)-medium.jpg"),
                    large: URL(string: "https://example.com/\(id)-large.jpg"),
                    original: URL(string: "https://example.com/\(id)-original.jpg")
                )
            ]
        )
    }

    private func novel(id: Int) throws -> PixivNovel {
        let payload = """
        {
          "id": \(id),
          "title": "Novel \(id)",
          "caption": "",
          "restrict": 0,
          "x_restrict": 0,
          "is_original": false,
          "image_urls": {
            "square_medium": "https://example.com/novel-\(id)-square.jpg",
            "medium": "https://example.com/novel-\(id)-medium.jpg",
            "large": "https://example.com/novel-\(id)-large.jpg"
          },
          "create_date": \(id),
          "tags": [],
          "page_count": 1,
          "text_length": 1000,
          "user": {
            "id": 5001,
            "name": "Novel QA Creator",
            "account": "novel_qa",
            "is_followed": false
          },
          "series": {},
          "is_bookmarked": false,
          "total_bookmarks": 0,
          "total_view": 0,
          "total_comments": 0,
          "visible": true,
          "is_muted": false,
          "is_mypixiv_only": false,
          "is_x_restricted": false,
          "novel_ai_type": 0
        }
        """
        return try JSONDecoder().decode(PixivNovel.self, from: Data(payload.utf8))
    }
}
