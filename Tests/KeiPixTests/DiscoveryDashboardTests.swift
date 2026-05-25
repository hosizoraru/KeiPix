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
}
