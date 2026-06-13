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
        #expect(sidebarLibrary.routes.contains(.savedPixivCollections))
        #expect(dashboardLibrary.routes.contains(.savedPixivisionArticles))
        #expect(dashboardLibrary.routes.contains(.myPixivCollections))
        #expect(dashboardLibrary.routes.contains(.savedPixivCollections))
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

        let highlights = try #require(dashboard.range(of: "DiscoveryDashboardHighlightsSection(store: store, style: featureStyle)"))
        let forYou = try #require(dashboard.range(of: "DiscoveryDashboardForYouSection(store: store, style: featureStyle)"))
        let routeSections = try #require(dashboard.range(of: "ForEach(store.visibleDashboardSections)"))

        #expect(highlights.lowerBound < forYou.lowerBound)
        #expect(forYou.lowerBound < routeSections.lowerBound)
        #expect(dashboard.contains("MobileWorkspaceLayout(size: proxy.size, platform: ReaderPlatformKind.current)"))
        #expect(dashboard.contains("layout.usesCondensedChrome ? .compact : .full"))
        #expect(dashboard.contains("AccountIdentityMenuButton("))
        #expect(dashboard.contains("displayStyle: .heroAvatar("))
        #expect(dashboard.contains("DashboardStatusPill") == false)
        #expect(dashboard.contains("DashboardStatusPill(title: L10n.currentRoute") == false)
        #expect(dashboard.contains("header\n\n                    DiscoveryTrendingTagsStrip(store: store)") == false)
        #expect(recommendationSections.contains("DiscoveryTrendingTagsStrip(store: store, showsHeader: false)"))
        #expect(recommendationSections.contains("struct DiscoveryDashboardHighlightsSection: View"))
        #expect(recommendationSections.contains("struct DiscoveryDashboardForYouSection: View"))
        #expect(recommendationSections.contains(".clipShape(cardShape)"))
        #expect(recommendationSections.contains(".containerShape(cardShape)"))
        #expect(recommendationSections.contains(".shadow(color:") == false)
        #expect(recommendationSections.contains(".blur(radius:") == false)
        #expect(recommendationSections.contains("RadialGradient"))
        #expect(recommendationSections.contains("GlassEffectContainer(spacing: 12)"))
        #expect(iPadContent.contains("VisualQALaunchArgument.contains(.discoverDashboard)"))
        #expect(iPadContent.contains("store.presentDiscoverDashboardVisualQA()"))
        #expect(visualQASampleData.contains("func presentDiscoverDashboardVisualQA()"))
        #expect(visualQASampleData.contains("selectedRoute = .home"))
        #expect(trendingStrip.contains("init(store: KeiPixStore, showsHeader: Bool = true)"))
        #expect(localizable.contains("\"Discovery Highlights\""))
        #expect(localizable.contains("\"value\": \"亮点\""))
        #expect(localizable.contains("\"For You\""))
        #expect(localizable.contains("\"value\": \"为你推荐\""))
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
