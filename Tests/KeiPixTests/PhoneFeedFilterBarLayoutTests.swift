import CoreGraphics
import Testing
@testable import KeiPix

struct PhoneFeedFilterBarLayoutTests {
    @Test("Filter chrome stays anchored above the tab bar")
    func filterChromeStaysAnchoredAboveTabBar() {
        let layout = PhoneFeedFilterChromeLayout.resolve(
            containerSize: CGSize(width: 390, height: 844),
            tabBarGeometry: TabBarGeometrySnapshot(
                tabBarFrame: CGRect(x: 20, y: 758, width: 350, height: 70),
                selectedItemFrame: CGRect(x: 24, y: 776, width: 56, height: 56)
            )
        )

        #expect(layout?.pillFrame == CGRect(x: 159, y: 708, width: 72, height: 34))
        #expect(layout?.panelFrame == CGRect(x: 16, y: 702, width: 358, height: 46))
    }

    @Test("Filter chrome follows the real expanded tab bar frame")
    func filterChromeFollowsExpandedTabBarFrame() {
        let layout = PhoneFeedFilterChromeLayout.resolve(
            containerSize: CGSize(width: 390, height: 844),
            tabBarGeometry: TabBarGeometrySnapshot(
                tabBarFrame: CGRect(x: 24, y: 748, width: 342, height: 76),
                selectedItemFrame: CGRect(x: 250, y: 758, width: 72, height: 56)
            )
        )

        #expect(layout?.pillFrame == CGRect(x: 159, y: 698, width: 72, height: 34))
        #expect(layout?.panelFrame == CGRect(x: 16, y: 692, width: 358, height: 46))
    }

    @Test("Filter chrome caps panel width on wider compact devices")
    func filterChromeCapsPanelWidthOnWiderCompactDevices() {
        let layout = PhoneFeedFilterChromeLayout.resolve(
            containerSize: CGSize(width: 820, height: 1180),
            tabBarGeometry: TabBarGeometrySnapshot(
                tabBarFrame: CGRect(x: 180, y: 1070, width: 460, height: 84),
                selectedItemFrame: CGRect(x: 560, y: 1086, width: 64, height: 56)
            )
        )

        #expect(layout?.pillFrame == CGRect(x: 374, y: 1020, width: 72, height: 34))
        #expect(layout?.panelFrame == CGRect(x: 190, y: 1014, width: 440, height: 46))
    }

    @Test("Filter chrome clamps above small tab bar frames")
    func filterChromeClampsAboveSmallTabBarFrames() {
        let layout = PhoneFeedFilterChromeLayout.resolve(
            containerSize: CGSize(width: 320, height: 180),
            tabBarGeometry: TabBarGeometrySnapshot(
                tabBarFrame: CGRect(x: 0, y: 54, width: 320, height: 72),
                selectedItemFrame: CGRect(x: 0, y: 60, width: 58, height: 58)
            )
        )

        #expect(layout?.pillFrame == CGRect(x: 124, y: 22, width: 72, height: 34))
        #expect(layout?.panelFrame == CGRect(x: 16, y: 16, width: 288, height: 46))
    }

    @Test("Filter pill width follows content while staying bounded")
    func filterPillWidthFollowsContentWhileStayingBounded() {
        let compact = PhoneFeedFilterChromeLayout.resolve(
            containerSize: CGSize(width: 390, height: 844),
            tabBarGeometry: TabBarGeometrySnapshot(tabBarFrame: CGRect(x: 20, y: 758, width: 350, height: 70)),
            preferredPillWidth: 96
        )
        let oversized = PhoneFeedFilterChromeLayout.resolve(
            containerSize: CGSize(width: 390, height: 844),
            tabBarGeometry: TabBarGeometrySnapshot(tabBarFrame: CGRect(x: 20, y: 758, width: 350, height: 70)),
            preferredPillWidth: 220
        )

        #expect(compact?.pillFrame == CGRect(x: 147, y: 708, width: 96, height: 34))
        #expect(oversized?.pillFrame == CGRect(x: 129, y: 708, width: 132, height: 34))
    }

    @Test("Filter waits for tab bar geometry instead of guessing device-specific padding")
    func filterWaitsForTabBarGeometry() {
        let layout = PhoneFeedFilterChromeLayout.resolve(
            containerSize: CGSize(width: 390, height: 844),
            tabBarGeometry: nil
        )

        #expect(layout == nil)
    }
}
