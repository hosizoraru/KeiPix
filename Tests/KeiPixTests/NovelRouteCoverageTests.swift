import Testing
@testable import KeiPix

@Suite("Novel route coverage")
struct NovelRouteCoverageTests {
    @Test("Latest novel route is reachable from novel navigation")
    func latestNovelRouteIsReachable() {
        #expect(PixivRoute.novelLatest.usesNovelFeed)
        #expect(PixivRoute.novelLatest.usesArtworkFeed == false)
        #expect(PixivRouteSection.novels.routes.contains(.novelLatest))

        let mobileNovelRoutes = MobileRouteMenuConfiguration.sections(for: .novels).flatMap(\.routes)
        #expect(mobileNovelRoutes.contains(.novelLatest))
    }

    @Test("Every novel ranking route maps to a non-empty pixiv mode string")
    func everyRankingRouteHasMode() {
        for route in PixivRoute.novelRankingRoutes {
            #expect(route.rankingMode?.isEmpty == false, "Missing rankingMode for \(route)")
            #expect(route.usesNovelFeed, "novel ranking route \(route) should use the novel feed")
            #expect(route.rankingFamily == .novel, "ranking family for \(route) should be .novel")
        }
    }

    @Test("Specialised novel ranking modes match the pixiv app-api convention")
    func novelRankingModeStrings() {
        // The pixez Dart code uses these literal mode strings — locking
        // them here keeps the wiring honest if someone refactors the
        // mapping without re-reading the upstream doc.
        #expect(PixivRoute.novelRankingDaily.rankingMode == "day")
        #expect(PixivRoute.novelRankingWeekly.rankingMode == "week")
        #expect(PixivRoute.novelRankingMonthly.rankingMode == "month")
        #expect(PixivRoute.novelRankingDailyMale.rankingMode == "day_male")
        #expect(PixivRoute.novelRankingDailyFemale.rankingMode == "day_female")
        #expect(PixivRoute.novelRankingWeeklyRookie.rankingMode == "week_rookie")
        #expect(PixivRoute.novelRankingWeeklyAI.rankingMode == "week_ai")
        #expect(PixivRoute.novelRankingDailyR18.rankingMode == "day_r18")
        #expect(PixivRoute.novelRankingWeeklyR18.rankingMode == "week_r18")
        #expect(PixivRoute.novelRankingWeeklyR18AI.rankingMode == "week_ai_r18")
        #expect(PixivRoute.novelRankingWeeklyR18G.rankingMode == "week_r18g")
    }

    @Test("Non-novel ranking routes don't claim the novel feed")
    func illustrationRanksDontClaimNovelFeed() {
        for route in PixivRoute.illustrationRankingRoutes {
            #expect(route.usesNovelFeed == false, "\(route) leaked into novel feed")
        }
        for route in PixivRoute.mangaRankingRoutes {
            #expect(route.usesNovelFeed == false, "\(route) leaked into novel feed")
        }
    }

    @Test("Own-novel-bookmark routes are flagged correctly")
    func ownNovelBookmarkFlag() {
        #expect(PixivRoute.novelPublicBookmarks.isOwnNovelBookmarkRoute)
        #expect(PixivRoute.novelPrivateBookmarks.isOwnNovelBookmarkRoute)
        #expect(PixivRoute.novelPublicBookmarks.routeScopeFamily == .ownNovelBookmarks)
        #expect(PixivRoute.novelPrivateBookmarks.routeScopeFamily == .ownNovelBookmarks)
        #expect(PixivRoute.novelPrivateBookmarks.visibleLibraryRoute == .novelPublicBookmarks)
        #expect(PixivRoute.novelWatchlist.isOwnNovelBookmarkRoute == false)
        #expect(PixivRoute.publicBookmarks.isOwnNovelBookmarkRoute == false)
        #expect(PixivRouteSection.novels.routes.contains(.novelPublicBookmarks))
        #expect(PixivRouteSection.novels.routes.contains(.novelPrivateBookmarks) == false)
    }

    @Test("usesNovelFeed and usesArtworkFeed are mutually exclusive for every route")
    func usesNovelOrArtworkExclusive() {
        for route in PixivRoute.allCases {
            #expect(
                !(route.usesNovelFeed && route.usesArtworkFeed),
                "\(route) claims both novel + artwork feeds"
            )
        }
    }
}
