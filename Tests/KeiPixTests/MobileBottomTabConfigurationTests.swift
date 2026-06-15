import Foundation
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
        #expect(MobileBottomTabConfiguration.defaultLaunchTarget == .lastUsed)
        #expect(MobileBottomTabConfiguration.defaultRemembersLastRoute)
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

    @Test("Launch target resolves fixed tabs and last used tab")
    func launchTargetResolvesFixedTabsAndLastUsedTab() {
        #expect(MobileBottomTabLaunchTarget.illustrations.resolvedKind(lastUsedKindID: "bookmarks") == .illustrations)
        #expect(MobileBottomTabLaunchTarget.manga.resolvedKind(lastUsedKindID: "bookmarks") == .manga)
        #expect(MobileBottomTabLaunchTarget.lastUsed.resolvedKind(lastUsedKindID: "bookmarks") == .bookmarks)
        #expect(MobileBottomTabLaunchTarget.lastUsed.resolvedKind(lastUsedKindID: "not-a-tab") == .illustrations)
    }

    @Test("Remembered routes restore the last concrete page only when enabled")
    func rememberedRoutesRestoreLastConcretePageOnlyWhenEnabled() {
        let defaultRoutes: [MobileBottomTabKind: PixivRoute] = [
            .illustrations: .newIllustrations,
            .manga: .mangaRecommended,
            .novels: .novelRecommended,
            .bookmarks: .publicBookmarks
        ]
        let rememberedRoutes: [MobileBottomTabKind: PixivRoute] = [
            .illustrations: .rankingWeekly,
            .manga: .mangaWatchlist,
            .novels: .novelRankingDaily,
            .bookmarks: .history
        ]
        let defaultStorageID = MobileBottomTabConfiguration.storageID(for: defaultRoutes)
        let rememberedStorageID = MobileBottomTabConfiguration.storageID(for: rememberedRoutes)

        #expect(MobileBottomTabConfiguration.route(
            for: .illustrations,
            defaultRouteStorageID: defaultStorageID,
            rememberedRouteStorageID: rememberedStorageID,
            remembersLastRoute: true
        ) == .rankingWeekly)
        #expect(MobileBottomTabConfiguration.route(
            for: .illustrations,
            defaultRouteStorageID: defaultStorageID,
            rememberedRouteStorageID: rememberedStorageID,
            remembersLastRoute: false
        ) == .newIllustrations)
    }

    @Test("Remembered route storage sanitizes routes into their tab family")
    func rememberedRouteStorageSanitizesRoutesIntoTheirTabFamily() {
        let storageID = MobileBottomTabConfiguration.recordingRememberedRoute(
            .novelRankingWeekly,
            in: MobileBottomTabConfiguration.defaultStorageID
        )
        let restored = MobileBottomTabConfiguration.defaultRouteMap(from: storageID)

        #expect(restored[.novels] == .novelRankingWeekly)
        #expect(restored[.illustrations] == .illustrations)

        let unchanged = MobileBottomTabConfiguration.recordingRememberedRoute(
            .search,
            in: storageID
        )
        #expect(unchanged == storageID)
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
        #expect(illustrationRoutes.contains(.pixivCollections))
        #expect(illustrationRoutes.contains(.rankingDaily))
        #expect(illustrationRoutes.contains(.mangaRecommended) == false)

        #expect(mangaRoutes.contains(.mangaRecommended))
        #expect(mangaRoutes.contains(.mangaRankingDaily))
        #expect(mangaRoutes.contains(.novelRecommended) == false)

        #expect(novelRoutes.contains(.novelRecommended))
        #expect(novelRoutes.contains(.novelLatest))
        #expect(novelRoutes.contains(.novelSearch) == false)
        #expect(novelRoutes.contains(.novelRankingWeekly))
        #expect(novelRoutes.contains(.publicBookmarks) == false)

        #expect(bookmarkRoutes.contains(.publicBookmarks))
        #expect(bookmarkRoutes.contains(.pixivCollections) == false)
        #expect(bookmarkRoutes.contains(.pixivCollectionWorks) == false)
        #expect(bookmarkRoutes.contains(.savedPixivisionArticles))
        #expect(bookmarkRoutes.contains(.myPixivCollections))
        #expect(bookmarkRoutes.contains(.savedPixivCollections))
        #expect(bookmarkRoutes.contains(.allFollowing) == false)
        #expect(bookmarkRoutes.contains(.followingCreators))
        #expect(bookmarkRoutes.contains(.downloads))
        #expect(bookmarkRoutes.contains(.search) == false)
    }

    @Test("Ranking route groups collapse behind one submenu entry")
    func rankingRouteGroupsCollapseBehindOneSubmenuEntry() throws {
        let illustrationSections = MobileRouteMenuConfiguration.sections(for: .illustrations)
        let discover = try #require(illustrationSections.first { $0.id == "illustration-discover" })
        let ranking = try #require(illustrationSections.first { $0.id == "illustration-ranking" })
        let mangaRanking = try #require(MobileRouteMenuConfiguration.sections(for: .manga).first { $0.id == "manga-ranking" })
        let novelRanking = try #require(MobileRouteMenuConfiguration.sections(for: .novels).first { $0.id == "novel-ranking" })

        #expect(discover.presentation == .inline)
        #expect(ranking.presentation == .submenu(systemImage: "chart.bar"))
        #expect(mangaRanking.presentation == .submenu(systemImage: "chart.bar.doc.horizontal"))
        #expect(novelRanking.presentation == .submenu(systemImage: "chart.bar.doc.horizontal"))
        #expect(ranking.routes == PixivRoute.illustrationRankingRoutes)
        #expect(mangaRanking.routes == PixivRoute.mangaRankingRoutes)
        #expect(novelRanking.routes == PixivRoute.novelRankingRoutes)
    }

    @Test("Following artwork menus expose public and private feeds without the aggregate route")
    func followingArtworkMenusExposePublicAndPrivateFeedsWithoutAggregateRoute() throws {
        let bookmarkSections = MobileRouteMenuConfiguration.sections(for: .bookmarks)
        let followingSection = try #require(bookmarkSections.first { $0.id == "bookmarks-following" })

        #expect(followingSection.routes.contains(.following))
        #expect(followingSection.routes.contains(.privateFollowing))
        #expect(followingSection.routes.contains(.allFollowing) == false)
        #expect(PixivRoute.following.title == L10n.publicFollowing)
        #expect(PixivRouteSection.library.routes.contains(.following))
        #expect(PixivRouteSection.library.routes.contains(.privateFollowing))
        #expect(PixivRouteSection.library.routes.contains(.allFollowing) == false)
        #expect(DiscoveryDashboardSection.dashboardRoutes.contains(.allFollowing) == false)
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
        #expect(MobileBottomTabKind.kind(containing: .pixivCollections) == .illustrations)
        #expect(MobileBottomTabKind.kind(containing: .pixivCollectionWorks) == .illustrations)
        #expect(MobileBottomTabKind.kind(containing: .savedPixivisionArticles) == .bookmarks)
        #expect(MobileBottomTabKind.kind(containing: .myPixivCollections) == .bookmarks)
        #expect(MobileBottomTabKind.kind(containing: .savedPixivCollections) == .bookmarks)
    }

    @Test("Mobile cold launch restores the last concrete bottom-tab page")
    func mobileColdLaunchRestoresLastConcreteBottomTabPage() {
        let suiteName = "MobileBottomTabConfigurationTests.mobile.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let rememberedRoutes = MobileBottomTabConfiguration.storageID(for: [
            .illustrations: .illustrations,
            .manga: .mangaRecommended,
            .novels: .novelRecommended,
            .bookmarks: .bookmarkTags
        ])
        defaults.set(LaunchDestination.home.rawValue, forKey: AppLaunchRouteResolver.launchDestinationDefaultsKey)
        defaults.set(MobileBottomTabLaunchTarget.lastUsed.rawValue, forKey: MobileBottomTabConfiguration.DefaultsKey.launchTarget)
        defaults.set(MobileBottomTabKind.bookmarks.rawValue, forKey: MobileBottomTabConfiguration.DefaultsKey.lastKind)
        defaults.set(true, forKey: MobileBottomTabConfiguration.DefaultsKey.remembersLastRoute)
        defaults.set(rememberedRoutes, forKey: MobileBottomTabConfiguration.DefaultsKey.rememberedRouteIDs)

        #expect(AppLaunchRouteResolver.initialRoute(defaults: defaults, usesMobileBottomTabs: true) == .bookmarkTags)
    }

    @Test("Desktop cold launch keeps the general launch destination")
    func desktopColdLaunchKeepsGeneralLaunchDestination() {
        let suiteName = "MobileBottomTabConfigurationTests.desktop.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set(LaunchDestination.spotlight.rawValue, forKey: AppLaunchRouteResolver.launchDestinationDefaultsKey)
        defaults.set(MobileBottomTabLaunchTarget.lastUsed.rawValue, forKey: MobileBottomTabConfiguration.DefaultsKey.launchTarget)
        defaults.set(MobileBottomTabKind.bookmarks.rawValue, forKey: MobileBottomTabConfiguration.DefaultsKey.lastKind)

        #expect(AppLaunchRouteResolver.initialRoute(defaults: defaults, usesMobileBottomTabs: false) == .spotlight)
    }
}
