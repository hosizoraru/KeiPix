import Foundation
import Testing
@testable import KeiPix

@Suite("Mobile bottom tab configuration")
struct MobileBottomTabConfigurationTests {
    @Test("Compact tabs are four fixed content families")
    func compactTabsAreFourFixedContentFamilies() {
        #expect(MobileBottomTabConfiguration.fixedKinds == [.illustrations, .novels, .discovery, .bookmarks])
        #expect(MobileBottomTabConfiguration.defaultRouteMap[.illustrations] == .illustrations)
        #expect(MobileBottomTabConfiguration.defaultRouteMap[.novels] == .novelRecommended)
        #expect(MobileBottomTabConfiguration.defaultRouteMap[.discovery] == .home)
        #expect(MobileBottomTabConfiguration.defaultRouteMap[.bookmarks] == .publicBookmarks)
        #expect(MobileBottomTabConfiguration.defaultLaunchTarget == .lastUsed)
        #expect(MobileBottomTabConfiguration.defaultRemembersLastRoute)
    }

    @Test("Default route storage round-trips every fixed content family")
    func defaultRouteStorageRoundTripsEveryFixedContentFamily() {
        let routeMap: [MobileBottomTabKind: PixivRoute] = [
            .illustrations: .mangaRankingWeekly,
            .novels: .novelRankingMonthly,
            .discovery: .pixivActivity,
            .bookmarks: .downloads
        ]
        let storageID = MobileBottomTabConfiguration.storageID(for: routeMap)
        let restored = MobileBottomTabConfiguration.defaultRouteMap(from: storageID)

        #expect(restored[.illustrations] == .mangaRankingWeekly)
        #expect(restored[.novels] == .novelRankingMonthly)
        #expect(restored[.discovery] == .pixivActivity)
        #expect(restored[.bookmarks] == .downloads)
    }

    @Test("Invalid defaults fall back inside their own content family")
    func invalidDefaultsFallBackInsideTheirOwnContentFamily() {
        let routeMap: [MobileBottomTabKind: PixivRoute] = [
            .illustrations: .novelRecommended,
            .novels: .mangaRecommended,
            .discovery: .publicBookmarks,
            .bookmarks: .rankingDaily
        ]
        let restored = MobileBottomTabConfiguration.defaultRouteMap(
            from: MobileBottomTabConfiguration.storageID(for: routeMap)
        )

        #expect(restored[.illustrations] == .illustrations)
        #expect(restored[.novels] == .novelRecommended)
        #expect(restored[.discovery] == .home)
        #expect(restored[.bookmarks] == .publicBookmarks)
    }

    @Test("Launch target resolves fixed tabs and last used tab")
    func launchTargetResolvesFixedTabsAndLastUsedTab() {
        #expect(MobileBottomTabLaunchTarget.illustrations.resolvedKind(lastUsedKindID: "bookmarks") == .illustrations)
        #expect(MobileBottomTabLaunchTarget.discovery.resolvedKind(lastUsedKindID: "bookmarks") == .discovery)
        #expect(MobileBottomTabLaunchTarget.manga.resolvedKind(lastUsedKindID: "bookmarks") == .illustrations)
        #expect(MobileBottomTabLaunchTarget.allCases.contains(.manga) == false)
        #expect(MobileBottomTabLaunchTarget.lastUsed.resolvedKind(lastUsedKindID: "bookmarks") == .bookmarks)
        #expect(MobileBottomTabLaunchTarget.lastUsed.resolvedKind(lastUsedKindID: "not-a-tab") == .illustrations)
    }

    @Test("Remembered routes restore the last concrete page only when enabled")
    func rememberedRoutesRestoreLastConcretePageOnlyWhenEnabled() {
        let defaultRoutes: [MobileBottomTabKind: PixivRoute] = [
            .illustrations: .newIllustrations,
            .novels: .novelRecommended,
            .discovery: .home,
            .bookmarks: .publicBookmarks
        ]
        let rememberedRoutes: [MobileBottomTabKind: PixivRoute] = [
            .illustrations: .mangaWatchlist,
            .novels: .novelRankingDaily,
            .discovery: .spotlight,
            .bookmarks: .history
        ]
        let defaultStorageID = MobileBottomTabConfiguration.storageID(for: defaultRoutes)
        let rememberedStorageID = MobileBottomTabConfiguration.storageID(for: rememberedRoutes)

        #expect(MobileBottomTabConfiguration.route(
            for: .illustrations,
            defaultRouteStorageID: defaultStorageID,
            rememberedRouteStorageID: rememberedStorageID,
            remembersLastRoute: true
        ) == .mangaWatchlist)
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

        let discoveryStorageID = MobileBottomTabConfiguration.recordingRememberedRoute(
            .pixivActivity,
            in: storageID
        )
        let discoveryRestored = MobileBottomTabConfiguration.defaultRouteMap(from: discoveryStorageID)
        #expect(discoveryRestored[.discovery] == .pixivActivity)

        let mangaStorageID = MobileBottomTabConfiguration.recordingRememberedRoute(
            .mangaRankingWeekly,
            in: discoveryStorageID
        )
        let mangaRestored = MobileBottomTabConfiguration.defaultRouteMap(from: mangaStorageID)
        #expect(mangaRestored[.illustrations] == .mangaRankingWeekly)

        let unchanged = MobileBottomTabConfiguration.recordingRememberedRoute(
            .search,
            in: mangaStorageID
        )
        #expect(unchanged == mangaStorageID)
    }

    @Test("Legacy route storage is migrated into category defaults")
    func legacyRouteStorageMigratesIntoCategoryDefaults() {
        let restored = MobileBottomTabConfiguration.defaultRouteMap(
            from: "downloads,novels,spotlight,manga"
        )

        #expect(restored[.illustrations] == .mangaRecommended)
        #expect(restored[.novels] == .novelRecommended)
        #expect(restored[.discovery] == .spotlight)
        #expect(restored[.bookmarks] == .downloads)
    }

    @Test("Legacy keyed route storage preserves routes that moved between tabs")
    func legacyKeyedRouteStoragePreservesRoutesThatMovedBetweenTabs() {
        let restored = MobileBottomTabConfiguration.defaultRouteMap(
            from: "illustrations=spotlight,manga=mangaRankingWeekly,novels=novelLatest,bookmarks=watchLater"
        )

        #expect(restored[.illustrations] == .mangaRankingWeekly)
        #expect(restored[.novels] == .novelLatest)
        #expect(restored[.discovery] == .spotlight)
        #expect(restored[.bookmarks] == .watchLater)

        let savedDiscovery = MobileBottomTabConfiguration.defaultRouteMap(
            from: "bookmarks=savedPixivisionArticles"
        )
        #expect(savedDiscovery[.discovery] == .savedPixivisionArticles)
        #expect(savedDiscovery[.bookmarks] == .publicBookmarks)
    }

    @Test("Route menus are split by the four bottom tab families")
    func routeMenusAreSplitByFourBottomTabFamilies() {
        let illustrationRoutes = MobileRouteMenuConfiguration.sections(for: .illustrations).flatMap(\.routes)
        let novelRoutes = MobileRouteMenuConfiguration.sections(for: .novels).flatMap(\.routes)
        let discoveryRoutes = MobileRouteMenuConfiguration.sections(for: .discovery).flatMap(\.routes)
        let bookmarkRoutes = MobileRouteMenuConfiguration.sections(for: .bookmarks).flatMap(\.routes)

        #expect(illustrationRoutes.contains(.illustrations))
        #expect(illustrationRoutes.contains(.search) == false)
        #expect(illustrationRoutes.contains(.searchUsers) == false)
        #expect(illustrationRoutes.contains(.savedSearches) == false)
        #expect(illustrationRoutes.contains(.trendingTags) == false)
        #expect(illustrationRoutes.contains(.pixivCollections) == false)
        #expect(illustrationRoutes.contains(.pixivActivity) == false)
        #expect(illustrationRoutes.contains(.spotlight) == false)
        #expect(illustrationRoutes.contains(.rankingDaily))
        #expect(illustrationRoutes.contains(.mangaRecommended))
        #expect(illustrationRoutes.contains(.newManga))
        #expect(illustrationRoutes.contains(.mangaWatchlist))
        #expect(illustrationRoutes.contains(.mangaRankingDaily))
        #expect(illustrationRoutes.contains(.recommendedUsers) == false)

        #expect(novelRoutes.contains(.novelRecommended))
        #expect(novelRoutes.contains(.novelLatest))
        #expect(novelRoutes.contains(.novelSearch) == false)
        #expect(novelRoutes.contains(.novelRankingWeekly))
        #expect(novelRoutes.contains(.publicBookmarks) == false)

        #expect(discoveryRoutes == [
            .home,
            .recommendedUsers,
            .spotlight,
            .pixivCollections,
            .pixivActivity,
            .savedPixivisionArticles,
            .myPixivCollections,
            .savedPixivCollections
        ])
        #expect(discoveryRoutes.contains(.illustrations) == false)
        #expect(discoveryRoutes.contains(.mangaRecommended) == false)

        #expect(bookmarkRoutes.contains(.publicBookmarks))
        #expect(bookmarkRoutes.contains(.pixivCollections) == false)
        #expect(bookmarkRoutes.contains(.pixivCollectionWorks) == false)
        #expect(bookmarkRoutes.contains(.savedPixivisionArticles) == false)
        #expect(bookmarkRoutes.contains(.myPixivCollections) == false)
        #expect(bookmarkRoutes.contains(.savedPixivCollections) == false)
        #expect(bookmarkRoutes.contains(.privateBookmarks))
        #expect(bookmarkRoutes.contains(.privateFollowing))
        #expect(bookmarkRoutes.contains(.pinnedCreators))
        #expect(bookmarkRoutes.contains(.allFollowing) == false)
        #expect(bookmarkRoutes.contains(.followingCreators))
        #expect(bookmarkRoutes.contains(.downloads))
        #expect(bookmarkRoutes.contains(.search) == false)
    }

    @Test("Ranking route groups collapse behind one submenu entry")
    func rankingRouteGroupsCollapseBehindOneSubmenuEntry() throws {
        let illustrationSections = MobileRouteMenuConfiguration.sections(for: .illustrations)
        let illustrationFeed = try #require(illustrationSections.first { $0.id == "illustration-feed" })
        let mangaFeed = try #require(illustrationSections.first { $0.id == "manga-feed" })
        let ranking = try #require(illustrationSections.first { $0.id == "illustration-ranking" })
        let mangaRanking = try #require(illustrationSections.first { $0.id == "manga-ranking" })
        let novelRanking = try #require(MobileRouteMenuConfiguration.sections(for: .novels).first { $0.id == "novel-ranking" })

        #expect(illustrationSections.map(\.id) == ["illustration-feed", "illustration-ranking", "manga-feed", "manga-ranking"])
        #expect(illustrationFeed.presentation == .inline)
        #expect(mangaFeed.presentation == .inline)
        #expect(ranking.title == L10n.illustrationRanking)
        #expect(mangaRanking.title == L10n.mangaRanking)
        #expect(ranking.presentation == .submenu(systemImage: "chart.bar"))
        #expect(mangaRanking.presentation == .submenu(systemImage: "chart.bar.doc.horizontal"))
        #expect(novelRanking.presentation == .submenu(systemImage: "chart.bar.doc.horizontal"))
        #expect(ranking.routes == PixivRoute.illustrationRankingRoutes)
        #expect(mangaRanking.routes == PixivRoute.mangaRankingRoutes)
        #expect(novelRanking.routes == PixivRoute.novelRankingRoutes)
    }

    @Test("Discovery menus own creator, editorial, activity, and collection library routes")
    func discoveryMenusOwnCreatorEditorialActivityAndCollectionLibraryRoutes() throws {
        let discoverySections = MobileRouteMenuConfiguration.sections(for: .discovery)
        let explore = try #require(discoverySections.first { $0.id == "discovery-explore" })
        let savedArticles = try #require(discoverySections.first { $0.id == "discovery-saved-articles" })
        let collections = try #require(discoverySections.first { $0.id == "discovery-pixiv-collections" })

        #expect(discoverySections.map(\.id) == ["discovery-explore", "discovery-saved-articles", "discovery-pixiv-collections"])
        #expect(explore.routes == [.home, .recommendedUsers, .spotlight, .pixivCollections, .pixivActivity])
        #expect(savedArticles.title == L10n.savedArticles)
        #expect(savedArticles.routes == [.savedPixivisionArticles])
        #expect(collections.title == L10n.pixivCollections)
        #expect(collections.routes == PixivRoute.routes(for: .pixivCollectionsLibrary))
        #expect(collections.presentation == .submenu(systemImage: "rectangle.stack.badge.person.crop"))
    }

    @Test("Novel bookmark routes collapse behind one submenu entry")
    func novelBookmarkRoutesCollapseBehindOneSubmenuEntry() throws {
        let novelSections = MobileRouteMenuConfiguration.sections(for: .novels)
        let novelBookmarks = try #require(novelSections.first { $0.id == "novel-bookmarks" })
        let inlineRoutes = novelSections
            .filter { $0.presentation == .inline }
            .flatMap(\.routes)

        #expect(novelBookmarks.title == L10n.novelBookmarks)
        #expect(novelBookmarks.presentation == .submenu(systemImage: "bookmark.square"))
        #expect(novelBookmarks.routes == PixivRoute.routes(for: .ownNovelBookmarks))
        #expect(inlineRoutes.contains(.novelPublicBookmarks) == false)
        #expect(inlineRoutes.contains(.novelPrivateBookmarks) == false)
    }

    @Test("Following artwork menus expose public and private feeds without the aggregate route")
    func followingArtworkMenusExposePublicAndPrivateFeedsWithoutAggregateRoute() throws {
        let bookmarkSections = MobileRouteMenuConfiguration.sections(for: .bookmarks)
        let followingSection = try #require(bookmarkSections.first { $0.id == "bookmarks-following-artwork" })

        #expect(followingSection.presentation == .submenu(systemImage: "person.2"))
        #expect(followingSection.routes.contains(.following))
        #expect(followingSection.routes.contains(.privateFollowing))
        #expect(followingSection.routes.contains(.allFollowing) == false)
        #expect(PixivRoute.following.title == L10n.publicFollowing)
        #expect(PixivRouteSection.library.routes.contains(.following))
        #expect(PixivRouteSection.library.routes.contains(.privateFollowing) == false)
        #expect(PixivRouteSection.library.routes.contains(.allFollowing) == false)
        #expect(DiscoveryDashboardSection.dashboardRoutes.contains(.allFollowing) == false)
    }

    @Test("Bookmark library families collapse behind submenu entries")
    func bookmarkLibraryFamiliesCollapseBehindSubmenuEntries() throws {
        let bookmarkSections = MobileRouteMenuConfiguration.sections(for: .bookmarks)
        let ownBookmarks = try #require(bookmarkSections.first { $0.id == "bookmarks-owned" })
        let bookmarkTags = try #require(bookmarkSections.first { $0.id == "bookmarks-tags" })
        let followingArtwork = try #require(bookmarkSections.first { $0.id == "bookmarks-following-artwork" })
        let followingCreators = try #require(bookmarkSections.first { $0.id == "bookmarks-following-creators" })
        let inlineRoutes = bookmarkSections
            .filter { $0.presentation == .inline }
            .flatMap(\.routes)

        #expect(ownBookmarks.presentation == .submenu(systemImage: "bookmark"))
        #expect(bookmarkTags.presentation == .inline)
        #expect(bookmarkTags.routes == [.bookmarkTags])
        #expect(followingArtwork.presentation == .submenu(systemImage: "person.2"))
        #expect(followingCreators.presentation == .submenu(systemImage: "person.2.crop.square.stack"))
        #expect(ownBookmarks.routes == PixivRoute.routes(for: .ownBookmarks))
        #expect(followingArtwork.routes == PixivRoute.routes(for: .followingArtwork))
        #expect(followingCreators.routes == PixivRoute.routes(for: .followedCreators))
        #expect(bookmarkSections.contains { $0.id == "bookmarks-pixiv-collections" } == false)
        #expect(inlineRoutes.contains(.privateBookmarks) == false)
        #expect(inlineRoutes.contains(.savedPixivCollections) == false)
        #expect(inlineRoutes.contains(.privateFollowing) == false)
        #expect(inlineRoutes.contains(.pinnedCreators) == false)
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
        #expect(MobileBottomTabKind.kind(containing: .mangaRankingMonthly) == .illustrations)
        #expect(MobileBottomTabKind.kind(containing: .novelSearch) == nil)
        #expect(MobileBottomTabKind.kind(containing: .watchLater) == .bookmarks)
        #expect(MobileBottomTabKind.kind(containing: .home) == .discovery)
        #expect(MobileBottomTabKind.kind(containing: .spotlight) == .discovery)
        #expect(MobileBottomTabKind.kind(containing: .pixivCollections) == .discovery)
        #expect(MobileBottomTabKind.kind(containing: .pixivCollectionWorks) == .discovery)
        #expect(MobileBottomTabKind.kind(containing: .pixivActivity) == .discovery)
        #expect(MobileBottomTabKind.kind(containing: .recommendedUsers) == .discovery)
        #expect(MobileBottomTabKind.kind(containing: .savedPixivisionArticles) == .discovery)
        #expect(MobileBottomTabKind.kind(containing: .myPixivCollections) == .discovery)
        #expect(MobileBottomTabKind.kind(containing: .savedPixivCollections) == .discovery)
        #expect(MobileBottomTabKind.kind(containing: .privateBookmarks) == .bookmarks)
        #expect(MobileBottomTabKind.kind(containing: .privateFollowing) == .bookmarks)
        #expect(MobileBottomTabKind.kind(containing: .pinnedCreators) == .bookmarks)
    }

    @Test("Mobile cold launch restores the last concrete bottom-tab page")
    func mobileColdLaunchRestoresLastConcreteBottomTabPage() {
        let suiteName = "MobileBottomTabConfigurationTests.mobile.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let rememberedRoutes = MobileBottomTabConfiguration.storageID(for: [
            .illustrations: .illustrations,
            .novels: .novelRecommended,
            .discovery: .home,
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
