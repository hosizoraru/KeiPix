import CoreGraphics
import Testing
@testable import KeiPix

@Suite("Tab bar reselection hit policy")
struct TabBarReselectionHitPolicyTests {
    @Test("A single tap on the selected item is treated as reselection")
    func selectedItemTapIsReselection() {
        let policy = TabBarReselectionHitPolicy(itemCount: 5, selectedIndex: 2, tabBarWidth: 500)

        #expect(policy.isSelectedItemTap(at: CGPoint(x: 250, y: 12)))
    }

    @Test("A single tap on a different item does not request scroll-to-top")
    func otherItemTapIsNotReselection() {
        let policy = TabBarReselectionHitPolicy(itemCount: 5, selectedIndex: 2, tabBarWidth: 500)

        #expect(policy.isSelectedItemTap(at: CGPoint(x: 50, y: 12)) == false)
        #expect(policy.isSelectedItemTap(at: CGPoint(x: 450, y: 12)) == false)
    }

    @Test("Touches outside the tab bar slots are ignored")
    func touchesOutsideSlotsAreIgnored() {
        let policy = TabBarReselectionHitPolicy(itemCount: 5, selectedIndex: 2, tabBarWidth: 500)

        #expect(policy.isSelectedItemTap(at: CGPoint(x: -1, y: 12)) == false)
        #expect(policy.isSelectedItemTap(at: CGPoint(x: 500, y: 12)) == false)
        #expect(TabBarReselectionHitPolicy(itemCount: 0, selectedIndex: 0, tabBarWidth: 500)
            .isSelectedItemTap(at: CGPoint(x: 10, y: 12)) == false)
    }

    @Test("Real tab item frame wins over full-width fallback slots")
    func selectedItemFrameWinsOverFullWidthFallbackSlots() {
        let policy = TabBarReselectionHitPolicy(
            itemCount: 5,
            selectedIndex: 4,
            tabBarWidth: 500,
            selectedItemFrame: CGRect(x: 430, y: 6, width: 44, height: 44)
        )

        #expect(policy.isSelectedItemTap(at: CGPoint(x: 452, y: 28)))
        #expect(policy.isSelectedItemTap(at: CGPoint(x: 406, y: 28)) == false)
        #expect(policy.isSelectedItemTap(at: CGPoint(x: 452, y: 72)) == false)
    }
}
