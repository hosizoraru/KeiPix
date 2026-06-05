import Testing
@testable import KeiPix

@Suite("Mobile bottom tab configuration")
struct MobileBottomTabConfigurationTests {
    @Test("Compact tabs are four fixed content families")
    func compactTabsAreFourFixedContentFamilies() {
        #expect(MobileBottomTabConfiguration.fixedKinds == [.illustrations, .manga, .novels, .bookmarks])
        #expect(MobileBottomTabConfiguration.defaultRouteMap[.illustrations] == .illustrations)
        #expect(MobileBottomTabConfiguration.defaultRouteMap[.manga] == .mangaRecommended)
        #expect(MobileBottomTabConfiguration.defaultRouteMap[.novels] == .novelRecommended)
        #expect(MobileBottomTabConfiguration.defaultRouteMap[.bookmarks] == .publicBookmarks)
    }

    @Test("Default route storage round-trips every fixed content family")
    func defaultRouteStorageRoundTripsEveryFixedContentFamily() {
        let routeMap: [MobileBottomTabKind: PixivRoute] = [
            .illustrations: .newIllustrations,
            .manga: .mangaRankingWeekly,
            .novels: .novelRankingMonthly,
            .bookmarks: .downloads
        ]
        let storageID = MobileBottomTabConfiguration.storageID(for: routeMap)
        let restored = MobileBottomTabConfiguration.defaultRouteMap(from: storageID)

        #expect(restored[.illustrations] == .newIllustrations)
        #expect(restored[.manga] == .mangaRankingWeekly)
        #expect(restored[.novels] == .novelRankingMonthly)
        #expect(restored[.bookmarks] == .downloads)
    }

    @Test("Invalid defaults fall back inside their own content family")
    func invalidDefaultsFallBackInsideTheirOwnContentFamily() {
        let routeMap: [MobileBottomTabKind: PixivRoute] = [
            .illustrations: .novelRecommended,
            .manga: .publicBookmarks,
            .novels: .mangaRecommended,
            .bookmarks: .rankingDaily
        ]
        let restored = MobileBottomTabConfiguration.defaultRouteMap(
            from: MobileBottomTabConfiguration.storageID(for: routeMap)
        )

        #expect(restored[.illustrations] == .illustrations)
        #expect(restored[.manga] == .mangaRecommended)
        #expect(restored[.novels] == .novelRecommended)
        #expect(restored[.bookmarks] == .publicBookmarks)
    }

    @Test("Legacy three-slot storage is migrated into category defaults")
    func legacyThreeSlotStorageMigratesIntoCategoryDefaults() {
        let restored = MobileBottomTabConfiguration.defaultRouteMap(
            from: "downloads,novels,spotlight"
        )

        #expect(restored[.illustrations] == .spotlight)
        #expect(restored[.manga] == .mangaRecommended)
        #expect(restored[.novels] == .novelRecommended)
        #expect(restored[.bookmarks] == .downloads)
    }

    @Test("Route menus are split by the four bottom tab families")
    func routeMenusAreSplitByFourBottomTabFamilies() {
        let illustrationRoutes = MobileRouteMenuConfiguration.sections(for: .illustrations).flatMap(\.routes)
        let mangaRoutes = MobileRouteMenuConfiguration.sections(for: .manga).flatMap(\.routes)
        let novelRoutes = MobileRouteMenuConfiguration.sections(for: .novels).flatMap(\.routes)
        let bookmarkRoutes = MobileRouteMenuConfiguration.sections(for: .bookmarks).flatMap(\.routes)

        #expect(illustrationRoutes.contains(.illustrations))
        #expect(illustrationRoutes.contains(.search) == false)
        #expect(illustrationRoutes.contains(.searchUsers) == false)
        #expect(illustrationRoutes.contains(.savedSearches) == false)
        #expect(illustrationRoutes.contains(.trendingTags) == false)
        #expect(illustrationRoutes.contains(.rankingDaily))
        #expect(illustrationRoutes.contains(.mangaRecommended) == false)

        #expect(mangaRoutes.contains(.mangaRecommended))
        #expect(mangaRoutes.contains(.mangaRankingDaily))
        #expect(mangaRoutes.contains(.novelRecommended) == false)

        #expect(novelRoutes.contains(.novelRecommended))
        #expect(novelRoutes.contains(.novelSearch) == false)
        #expect(novelRoutes.contains(.novelRankingWeekly))
        #expect(novelRoutes.contains(.publicBookmarks) == false)

        #expect(bookmarkRoutes.contains(.publicBookmarks))
        #expect(bookmarkRoutes.contains(.followingCreators))
        #expect(bookmarkRoutes.contains(.downloads))
        #expect(bookmarkRoutes.contains(.search) == false)
    }

    @Test("Dedicated search tab owns search-related routes")
    func dedicatedSearchTabOwnsSearchRelatedRoutes() {
        #expect(MobileSearchTabConfiguration.routes == [.search, .searchUsers, .novelSearch, .trendingTags, .savedSearches])
        #expect(MobileSearchTabConfiguration.contains(.search))
        #expect(MobileSearchTabConfiguration.contains(.searchUsers))
        #expect(MobileSearchTabConfiguration.contains(.novelSearch))
        #expect(MobileSearchTabConfiguration.contains(.trendingTags))
        #expect(MobileSearchTabConfiguration.contains(.savedSearches))
        #expect(MobileSearchTabConfiguration.contains(.illustrations) == false)
    }

    @Test("Route kind detection keeps tab selection stable")
    func routeKindDetectionKeepsTabSelectionStable() {
        #expect(MobileBottomTabKind.kind(containing: .rankingWeekly) == .illustrations)
        #expect(MobileBottomTabKind.kind(containing: .mangaRankingMonthly) == .manga)
        #expect(MobileBottomTabKind.kind(containing: .novelSearch) == nil)
        #expect(MobileBottomTabKind.kind(containing: .watchLater) == .bookmarks)
    }
}
