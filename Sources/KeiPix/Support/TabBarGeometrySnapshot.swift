import CoreGraphics

struct TabBarGeometrySnapshot: Equatable {
    let tabBarFrame: CGRect
    let selectedItemFrame: CGRect?

    init(tabBarFrame: CGRect, selectedItemFrame: CGRect? = nil) {
        self.tabBarFrame = tabBarFrame
        self.selectedItemFrame = selectedItemFrame
    }
}
