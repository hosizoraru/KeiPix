import CoreGraphics
import Testing
@testable import KeiPix

struct PhoneFeedFilterBarLayoutTests {
    @Test("Collapsed filter follows the selected dock item frame")
    func collapsedFilterFollowsSelectedDockItemFrame() {
        let layout = PhoneFeedFilterBarLayout.resolve(
            containerSize: CGSize(width: 390, height: 844),
            tabBarGeometry: TabBarGeometrySnapshot(
                tabBarFrame: CGRect(x: 20, y: 758, width: 350, height: 70),
                selectedItemFrame: CGRect(x: 24, y: 776, width: 56, height: 56)
            ),
            contentIsAtStart: false,
            hasActiveFilter: false
        )

        #expect(layout?.placement == .besideCollapsedDock)
        #expect(layout?.frame == CGRect(x: 88, y: 782, width: 278, height: 44))
    }

    @Test("Expanded active filter follows the real tab bar frame")
    func expandedActiveFilterFollowsRealTabBarFrame() {
        let layout = PhoneFeedFilterBarLayout.resolve(
            containerSize: CGSize(width: 390, height: 844),
            tabBarGeometry: TabBarGeometrySnapshot(
                tabBarFrame: CGRect(x: 24, y: 748, width: 342, height: 76),
                selectedItemFrame: CGRect(x: 250, y: 758, width: 72, height: 56)
            ),
            contentIsAtStart: true,
            hasActiveFilter: true
        )

        #expect(layout?.placement == .aboveExpandedTabBar)
        #expect(layout?.frame == CGRect(x: 24, y: 696, width: 342, height: 44))
    }

    @Test("Collapsed filter can use the left side when the dock leaves no room on the right")
    func collapsedFilterFallsBackToLeftSideWhenNeeded() {
        let layout = PhoneFeedFilterBarLayout.resolve(
            containerSize: CGSize(width: 390, height: 844),
            tabBarGeometry: TabBarGeometrySnapshot(
                tabBarFrame: CGRect(x: 20, y: 758, width: 350, height: 70),
                selectedItemFrame: CGRect(x: 310, y: 776, width: 56, height: 56)
            ),
            contentIsAtStart: false,
            hasActiveFilter: false
        )

        #expect(layout?.placement == .besideCollapsedDock)
        #expect(layout?.frame == CGRect(x: 24, y: 782, width: 278, height: 44))
    }

    @Test("Empty filter hides when content is at the top")
    func emptyFilterHidesAtContentStart() {
        let layout = PhoneFeedFilterBarLayout.resolve(
            containerSize: CGSize(width: 390, height: 844),
            tabBarGeometry: TabBarGeometrySnapshot(
                tabBarFrame: CGRect(x: 24, y: 748, width: 342, height: 76),
                selectedItemFrame: CGRect(x: 250, y: 758, width: 72, height: 56)
            ),
            contentIsAtStart: true,
            hasActiveFilter: false
        )

        #expect(layout == nil)
    }

    @Test("Active filter uses the expanded tab bar when dock geometry has no side room")
    func activeFilterUsesExpandedPlacementWhenDockGeometryHasNoSideRoom() {
        let layout = PhoneFeedFilterBarLayout.resolve(
            containerSize: CGSize(width: 390, height: 844),
            tabBarGeometry: TabBarGeometrySnapshot(
                tabBarFrame: CGRect(x: 24, y: 748, width: 342, height: 76),
                selectedItemFrame: CGRect(x: 155, y: 758, width: 80, height: 56)
            ),
            contentIsAtStart: false,
            hasActiveFilter: true
        )

        #expect(layout?.placement == .aboveExpandedTabBar)
        #expect(layout?.frame == CGRect(x: 24, y: 696, width: 342, height: 44))
    }

    @Test("Filter waits for tab bar geometry instead of guessing device-specific padding")
    func filterWaitsForTabBarGeometry() {
        let layout = PhoneFeedFilterBarLayout.resolve(
            containerSize: CGSize(width: 390, height: 844),
            tabBarGeometry: nil,
            contentIsAtStart: false,
            hasActiveFilter: false
        )

        #expect(layout == nil)
    }
}
