import Foundation
import Testing
@testable import KeiPix

struct DiscoveryDashboardTests {
    @Test("Home is the first sidebar route")
    func homeIsFirstSidebarRoute() {
        #expect(PixivRoute.sidebarSections.first?.routes.first == .home)
        #expect(PixivRoute.home.isSidebarRoute)
        #expect(PixivRoute.home.usesArtworkFeed == false)
        #expect(PixivRoute.home.title.isEmpty == false)
    }

    @Test("Dashboard covers sidebar routes without duplication")
    func dashboardRouteCoverage() {
        let dashboardRoutes = DiscoveryDashboardSection.dashboardRoutes
        let sidebarRoutes = PixivRoute.sidebarSections.flatMap(\.routes).filter { $0 != .home }

        #expect(Set(dashboardRoutes) == Set(sidebarRoutes))
        #expect(dashboardRoutes.count == Set(dashboardRoutes).count)
    }

    @Test("Dashboard card storage repairs missing and duplicated entries")
    func dashboardCardStorageRepairsMissingAndDuplicatedEntries() {
        let repaired = DiscoveryDashboardCardKind.ordered(from: "forYou,highlights,forYou,unknown")

        #expect(repaired == [.forYou, .highlights, .tagRecommendations, .metrics, .routeGroups])
        #expect(DiscoveryDashboardCardKind.storageID(for: repaired) == "forYou,highlights,tagRecommendations,metrics,routeGroups")
        #expect(DiscoveryDashboardCardKind.ordered(from: nil) == DiscoveryDashboardCardKind.defaultOrder)
    }

    @Test("Dashboard card visibility keeps a useful dashboard")
    func dashboardCardVisibilityKeepsUsefulDashboard() {
        let order = DiscoveryDashboardCardKind.defaultOrder
        let hidden = Set(order.dropFirst().map(\.id))
        let rejected = DiscoveryDashboardCardKind.hiddenIDs(
            afterSetting: false,
            for: order[0],
            currentHiddenIDs: hidden,
            order: order
        )

        #expect(rejected == hidden)

        let shown = DiscoveryDashboardCardKind.hiddenIDs(
            afterSetting: true,
            for: .routeGroups,
            currentHiddenIDs: hidden,
            order: order
        )

        #expect(shown.contains(DiscoveryDashboardCardKind.routeGroups.id) == false)
        #expect(DiscoveryDashboardCardKind.visibleCards(order: order, hiddenIDs: shown) == [.highlights, .routeGroups])
        #expect(DiscoveryDashboardCardKind.visibleCards(order: order, hiddenIDs: Set(order.map(\.id))) == DiscoveryDashboardCardKind.defaultVisibleOrder)
    }

    @Test("Dashboard card movement clamps to valid order bounds")
    func dashboardCardMovementClampsToValidOrderBounds() {
        let order = DiscoveryDashboardCardKind.defaultOrder

        #expect(DiscoveryDashboardCardKind.moved(.highlights, offset: -1, in: order) == order)
        #expect(DiscoveryDashboardCardKind.moved(.highlights, offset: 1, in: order) == [.forYou, .highlights, .tagRecommendations, .metrics, .routeGroups])
        #expect(DiscoveryDashboardCardKind.moved(.routeGroups, offset: 10, in: order) == order)
        #expect(DiscoveryDashboardCardKind.moved(.routeGroups, offset: -2, in: order) == [.highlights, .forYou, .routeGroups, .tagRecommendations, .metrics])
    }

    @Test("Novel dashboard exposes latest novel feed")
    func novelDashboardExposesLatestNovelFeed() throws {
        let novels = try #require(DiscoveryDashboardSection.all.first { $0.id == "novels" })

        #expect(novels.routes.contains(.novelRecommended))
        #expect(novels.routes.contains(.novelLatest))
    }

    @Test("Pixiv collections are classified with work discovery")
    func pixivCollectionsAreClassifiedWithWorkDiscovery() throws {
        let sidebarWorks = try #require(PixivRoute.sidebarSections.first { $0 == .works })
        let sidebarLibrary = try #require(PixivRoute.sidebarSections.first { $0 == .library })
        let dashboardWorks = try #require(DiscoveryDashboardSection.all.first { $0.id == "works" })
        let dashboardLibrary = try #require(DiscoveryDashboardSection.all.first { $0.id == "library" })

        #expect(sidebarWorks.routes.contains(.spotlight))
        #expect(sidebarWorks.routes.contains(.pixivCollections))
        #expect(sidebarLibrary.routes.contains(.pixivCollections) == false)
        #expect(dashboardWorks.routes.contains(.pixivCollections))
        #expect(dashboardLibrary.routes.contains(.pixivCollections) == false)
    }

    @Test("Pixiv activity feed is reachable from discovery navigation")
    func pixivActivityFeedIsReachableFromDiscoveryNavigation() throws {
        let sidebarWorks = try #require(PixivRoute.sidebarSections.first { $0 == .works })
        let dashboardWorks = try #require(DiscoveryDashboardSection.all.first { $0.id == "works" })
        let mobileDiscoveryRoutes = MobileRouteMenuConfiguration.sections(for: .discovery).flatMap(\.routes)

        #expect(PixivRoute.pixivActivity.title.isEmpty == false)
        #expect(PixivRoute.pixivActivity.systemImage == "bolt.horizontal.circle")
        #expect(PixivRoute.pixivActivity.usesArtworkFeed == false)
        #expect(PixivRoute.pixivActivity.usesNovelFeed == false)
        #expect(sidebarWorks.routes.contains(.pixivActivity))
        #expect(dashboardWorks.routes.contains(.pixivActivity))
        #expect(mobileDiscoveryRoutes.contains(.pixivActivity))
    }

    @Test("Saved Pixivision and Pixiv collection library routes stay out of work discovery")
    func savedEditorialCollectionsAreClassifiedWithLibrary() throws {
        let sidebarWorks = try #require(PixivRoute.sidebarSections.first { $0 == .works })
        let sidebarLibrary = try #require(PixivRoute.sidebarSections.first { $0 == .library })
        let dashboardLibrary = try #require(DiscoveryDashboardSection.all.first { $0.id == "library" })

        #expect(sidebarWorks.routes.contains(.savedPixivisionArticles) == false)
        #expect(sidebarWorks.routes.contains(.myPixivCollections) == false)
        #expect(sidebarWorks.routes.contains(.savedPixivCollections) == false)
        #expect(sidebarLibrary.routes.contains(.savedPixivisionArticles))
        #expect(sidebarLibrary.routes.contains(.myPixivCollections))
        #expect(sidebarLibrary.routes.contains(.savedPixivCollections) == false)
        #expect(dashboardLibrary.routes.contains(.savedPixivisionArticles))
        #expect(dashboardLibrary.routes.contains(.myPixivCollections))
        #expect(dashboardLibrary.routes.contains(.savedPixivCollections) == false)
    }

    @Test("Merged library route families keep a single visible entry")
    func mergedLibraryRouteFamiliesKeepSingleVisibleEntry() throws {
        let sidebarLibrary = try #require(PixivRoute.sidebarSections.first { $0 == .library })
        let dashboardLibrary = try #require(DiscoveryDashboardSection.all.first { $0.id == "library" })
        let dashboardNovels = try #require(DiscoveryDashboardSection.all.first { $0.id == "novels" })
        let creatorNetwork = try #require(DiscoveryDashboardSection.all.first { $0.id == "creators-search" })

        #expect(PixivRoute.privateBookmarks.routeScopeFamily == .ownBookmarks)
        #expect(PixivRoute.savedPixivCollections.routeScopeFamily == .pixivCollectionsLibrary)
        #expect(PixivRoute.privateFollowing.routeScopeFamily == .followingArtwork)
        #expect(PixivRoute.pinnedCreators.routeScopeFamily == .followedCreators)
        #expect(PixivRoute.novelPrivateBookmarks.routeScopeFamily == .ownNovelBookmarks)
        #expect(PixivRoute.privateBookmarks.visibleLibraryRoute == .publicBookmarks)
        #expect(PixivRoute.savedPixivCollections.visibleLibraryRoute == .myPixivCollections)
        #expect(PixivRoute.privateFollowing.visibleLibraryRoute == .following)
        #expect(PixivRoute.pinnedCreators.visibleLibraryRoute == .followingCreators)
        #expect(PixivRoute.novelPrivateBookmarks.visibleLibraryRoute == .novelPublicBookmarks)

        #expect(sidebarLibrary.routes.contains(.publicBookmarks))
        #expect(sidebarLibrary.routes.contains(.privateBookmarks) == false)
        #expect(sidebarLibrary.routes.contains(.myPixivCollections))
        #expect(sidebarLibrary.routes.contains(.savedPixivCollections) == false)
        #expect(sidebarLibrary.routes.contains(.following))
        #expect(sidebarLibrary.routes.contains(.privateFollowing) == false)
        #expect(sidebarLibrary.routes.contains(.followingCreators))
        #expect(sidebarLibrary.routes.contains(.pinnedCreators) == false)

        #expect(dashboardLibrary.routes.contains(.publicBookmarks))
        #expect(dashboardLibrary.routes.contains(.privateBookmarks) == false)
        #expect(dashboardLibrary.routes.contains(.myPixivCollections))
        #expect(dashboardLibrary.routes.contains(.savedPixivCollections) == false)
        #expect(dashboardLibrary.routes.contains(.following))
        #expect(dashboardLibrary.routes.contains(.privateFollowing) == false)
        #expect(dashboardNovels.routes.contains(.novelPublicBookmarks))
        #expect(dashboardNovels.routes.contains(.novelPrivateBookmarks) == false)
        #expect(creatorNetwork.routes.contains(.followingCreators))
        #expect(creatorNetwork.routes.contains(.pinnedCreators) == false)
    }

    @Test("Compact dashboard route previews keep density without hiding selection")
    func compactDashboardRoutePreviewsKeepDensityWithoutHidingSelection() throws {
        let ranking = try #require(DiscoveryDashboardSection.all.first { $0.id == "ranking" })
        let collapsed = DiscoveryDashboardRoutePreview(
            section: ranking,
            isExpanded: false,
            selectedRoute: nil
        )

        #expect(collapsed.routes == Array(ranking.routes.prefix(4)))
        #expect(collapsed.isTruncated)

        let hiddenSelection = try #require(ranking.routes.last)
        let selectedCollapsed = DiscoveryDashboardRoutePreview(
            section: ranking,
            isExpanded: false,
            selectedRoute: hiddenSelection
        )

        #expect(selectedCollapsed.routes == Array(ranking.routes.prefix(4)) + [hiddenSelection])
        #expect(selectedCollapsed.isTruncated)

        let expanded = DiscoveryDashboardRoutePreview(
            section: ranking,
            isExpanded: true,
            selectedRoute: hiddenSelection
        )

        #expect(expanded.routes == ranking.routes)
        #expect(expanded.isTruncated == false)

        let mangaRanking = try #require(DiscoveryDashboardSection.all.first { $0.id == "manga-ranking" })
        let shortSection = DiscoveryDashboardRoutePreview(
            section: mangaRanking,
            isExpanded: false,
            selectedRoute: nil
        )

        #expect(shortSection.routes == mangaRanking.routes)
        #expect(shortSection.isTruncated == false)
    }

    @Test("Ranking route families support in-page mode switching")
    func rankingRouteFamiliesSupportInPageModeSwitching() {
        let rankingSection = PixivRoute.sidebarSections.first { $0 == .ranking }?.routes ?? []
        let mangaRankingSection = PixivRoute.sidebarSections.first { $0 == .mangaRanking }?.routes ?? []

        #expect(PixivRoute.rankingRoutes(for: .illustration) == rankingSection)
        #expect(PixivRoute.rankingRoutes(for: .manga) == mangaRankingSection)
        #expect(PixivRoute.rankingRoutes(for: .illustration).allSatisfy { $0.rankingFamily == .illustration })
        #expect(PixivRoute.rankingRoutes(for: .manga).allSatisfy { $0.rankingFamily == .manga })
        #expect(PixivRoute.illustrations.rankingFamily == nil)
    }

    @Test("Discovery dashboard leads with Highlights and For You")
    func dashboardLeadsWithHighlightsAndForYou() throws {
        let root = try packageRoot()
        let dashboard = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/DiscoveryDashboardView.swift"),
            encoding: .utf8
        )
        let trendingStrip = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/DiscoveryTrendingTagsStrip.swift"),
            encoding: .utf8
        )
        let recommendationSections = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/DiscoveryDashboardRecommendationSections.swift"),
            encoding: .utf8
        )
        let localizable = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Resources/Localizable.xcstrings"),
            encoding: .utf8
        )
        let iPadContent = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/ContentView_iPadOS.swift"),
            encoding: .utf8
        )
        let visualQASampleData = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Support/VisualQASampleData.swift"),
            encoding: .utf8
        )

        let cards = try #require(dashboard.range(of: "ForEach(store.visibleDashboardCards)"))
        let highlights = try #require(dashboard.range(of: "case .highlights:"))
        let forYou = try #require(dashboard.range(of: "case .forYou:"))
        let tags = try #require(dashboard.range(of: "case .tagRecommendations:"))
        let metrics = try #require(dashboard.range(of: "case .metrics:"))
        let routeGroups = try #require(dashboard.range(of: "case .routeGroups:"))

        #expect(cards.lowerBound < highlights.lowerBound)
        #expect(highlights.lowerBound < forYou.lowerBound)
        #expect(forYou.lowerBound < tags.lowerBound)
        #expect(tags.lowerBound < metrics.lowerBound)
        #expect(metrics.lowerBound < routeGroups.lowerBound)
        #expect(dashboard.contains("DashboardCustomizationCardRow("))
        #expect(dashboard.contains("store.moveDashboardCard(card, offset: -1)"))
        #expect(dashboard.contains("store.moveDashboardCard(card, offset: 1)"))
        #expect(dashboard.contains("MobileWorkspaceLayout(size: proxy.size, platform: ReaderPlatformKind.current)"))
        #expect(dashboard.contains("layout.usesCondensedChrome ? .compact : .full"))
        #expect(dashboard.contains("AccountIdentityMenuButton("))
        #expect(dashboard.contains("displayStyle: .heroAvatar("))
        #expect(dashboard.contains("private var showsBoardTitle: Bool"))
        #expect(dashboard.contains("UIDevice.current.userInterfaceIdiom != .phone"))
        #expect(dashboard.contains("if showsBoardTitle {\n                        Text(L10n.discover)"))
        #expect(dashboard.contains("DiscoveryDashboardHeroControlRow("))
        #expect(dashboard.contains("DiscoveryDashboardPageMenu(") == false)
        #expect(dashboard.contains("Toggle(L10n.showContentBadges, isOn: store.settings_showContentBadgesBinding)") == false)
        #expect(dashboard.contains("Toggle(L10n.hideR18GArtworks, isOn: store.settings_hideR18GBinding)") == false)
        #expect(dashboard.contains("DiscoveryDashboardTagRecommendationsSection(store: store)"))
        #expect(dashboard.contains("DashboardMetric(id: \"feed\"") == false)
        #expect(dashboard.contains("surpriseButton(showsTitle:") == false)
        #expect(dashboard.contains("customizeButton(showsTitle:") == false)
        #expect(dashboard.contains("DashboardStatusPill") == false)
        #expect(dashboard.contains("DashboardStatusPill(title: L10n.currentRoute") == false)
        #expect(dashboard.contains("header\n\n                    DiscoveryTrendingTagsStrip(store: store)") == false)
        #expect(recommendationSections.contains("DiscoveryTrendingTagsStrip(store: store, showsHeader: false)") == false)
        #expect(recommendationSections.contains("struct DiscoveryDashboardTagRecommendationsSection: View"))
        #expect(recommendationSections.contains("title: L10n.recommendedTags"))
        #expect(recommendationSections.contains("route: .trendingTags") == false)
        #expect(recommendationSections.contains("struct DiscoveryDashboardHighlightsSection: View"))
        #expect(recommendationSections.contains("struct DiscoveryDashboardForYouSection: View"))
        #expect(recommendationSections.contains("private struct DiscoveryDashboardForYouCard: View"))
        #expect(recommendationSections.contains("LazyVGrid(columns: style.recommendationColumns"))
        #expect(recommendationSections.contains(".clipShape(cardShape)"))
        #expect(recommendationSections.contains(".containerShape(cardShape)"))
        #expect(recommendationSections.contains(".shadow(color:") == false)
        #expect(recommendationSections.contains(".blur(radius:") == false)
        #expect(recommendationSections.contains("RadialGradient"))
        #expect(recommendationSections.contains("GlassEffectContainer(spacing: 12)"))
        #expect(iPadContent.contains("VisualQALaunchArgument.contains(.discoverDashboard)"))
        #expect(iPadContent.contains("VisualQALaunchArgument.contains(.discoverDashboardCustomization)"))
        #expect(iPadContent.contains("store.presentDiscoverDashboardVisualQA()"))
        #expect(iPadContent.contains("store.presentDiscoverDashboardVisualQA()\n                    hasAppliedMobileBottomTabLaunchTarget = true"))
        #expect(iPadContent.contains("isDashboardCustomizationPresented = true"))
        let discoveryMenuRange = try #require(iPadContent.range(of: "private var discoveryDashboardToolbarMenu: NativeToolbarMenu"))
        let nextMenuRange = try #require(iPadContent.range(of: "private var pixivCollectionsToolbarMenu: NativeToolbarMenu"))
        let discoveryMenuSource = iPadContent[discoveryMenuRange.lowerBound..<nextMenuRange.lowerBound]
        #expect(discoveryMenuSource.contains("id: IPadToolbarMenuAction.customizeDashboard"))
        #expect(discoveryMenuSource.contains("L10n.viewOptions") == false)
        #expect(discoveryMenuSource.contains("L10n.contentFilters") == false)
        #expect(discoveryMenuSource.contains("IPadToolbarMenuAction.showContentBadges") == false)
        #expect(discoveryMenuSource.contains("IPadToolbarMenuAction.hideMutedContent") == false)
        #expect(dashboard.contains("VisualQALaunchArgument.contains(.discoverDashboardCustomization)") == false)
        #expect(visualQASampleData.contains("func presentDiscoverDashboardVisualQA()"))
        #expect(visualQASampleData.contains("selectedRoute = .home"))
        #expect(trendingStrip.contains("showsEmptyState: Bool = false,\n        title: String? = nil"))
        #expect(trendingStrip.contains("private var emptyRecommendationCard: some View"))
        #expect(localizable.contains("\"Discovery Highlights\""))
        #expect(localizable.contains("\"value\": \"亮点\""))
        #expect(localizable.contains("\"For You\""))
        #expect(localizable.contains("\"value\": \"为你推荐\""))
        #expect(localizable.contains("\"Recommended Tags\""))
        #expect(localizable.contains("\"value\": \"推荐标签\""))
        #expect(localizable.contains("\"Discovery Settings\""))
        #expect(localizable.contains("\"Dashboard Cards\""))
        #expect(localizable.contains("\"Move Up\""))
        #expect(localizable.contains("\"Move Down\""))
        #expect(localizable.contains("\"Reorder\""))
    }

    private func packageRoot() throws -> URL {
        var candidate = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        for _ in 0..<8 {
            if FileManager.default.fileExists(atPath: candidate.appending(path: "Package.swift").path(percentEncoded: false)) {
                return candidate
            }
            candidate.deleteLastPathComponent()
        }

        var fileBased = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        for _ in 0..<10 {
            if FileManager.default.fileExists(atPath: fileBased.appending(path: "Package.swift").path(percentEncoded: false)) {
                return fileBased
            }
            fileBased.deleteLastPathComponent()
        }

        throw CocoaError(.fileNoSuchFile)
    }
}
