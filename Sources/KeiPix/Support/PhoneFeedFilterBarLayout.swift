import CoreGraphics

struct TabBarGeometrySnapshot: Equatable {
    let tabBarFrame: CGRect
    let selectedItemFrame: CGRect?

    init(tabBarFrame: CGRect, selectedItemFrame: CGRect? = nil) {
        self.tabBarFrame = tabBarFrame
        self.selectedItemFrame = selectedItemFrame
    }
}

struct PhoneFeedFilterBarLayout: Equatable {
    enum Placement: Equatable {
        case aboveExpandedTabBar
        case besideCollapsedDock
    }

    static let height: CGFloat = 44

    private static let dockGap: CGFloat = 8
    private static let aboveTabGap: CGFloat = 8
    private static let minimumSideMargin: CGFloat = 16
    private static let minimumWidth: CGFloat = 150

    let placement: Placement
    let frame: CGRect

    static func resolve(
        containerSize: CGSize,
        tabBarGeometry: TabBarGeometrySnapshot?,
        contentIsAtStart: Bool,
        hasActiveFilter: Bool
    ) -> PhoneFeedFilterBarLayout? {
        guard containerSize.width > 0,
              containerSize.height > 0,
              let tabBarGeometry else {
            return nil
        }

        let containerBounds = CGRect(origin: .zero, size: containerSize)
        if contentIsAtStart {
            guard hasActiveFilter else { return nil }
            return layoutAboveExpandedTabBar(
                containerBounds: containerBounds,
                tabBarFrame: tabBarGeometry.tabBarFrame
            )
        }

        if let selectedItemFrame = tabBarGeometry.selectedItemFrame,
           let dockLayout = layoutBesideCollapsedDock(
                containerBounds: containerBounds,
                selectedItemFrame: selectedItemFrame
           ) {
            return dockLayout
        }

        guard hasActiveFilter else { return nil }
        return layoutAboveExpandedTabBar(
            containerBounds: containerBounds,
            tabBarFrame: tabBarGeometry.tabBarFrame
        )
    }

    private static func layoutAboveExpandedTabBar(
        containerBounds: CGRect,
        tabBarFrame: CGRect
    ) -> PhoneFeedFilterBarLayout? {
        let tabFrame = tabBarFrame.intersection(containerBounds)
        guard tabFrame.isNull == false,
              tabFrame.width >= minimumWidth else {
            return nil
        }

        let sideMargin = max(minimumSideMargin, tabFrame.minX)
        let maxX = min(containerBounds.maxX - sideMargin, tabFrame.maxX)
        let width = maxX - sideMargin
        guard width >= minimumWidth else { return nil }

        let proposedY = tabFrame.minY - aboveTabGap - height
        let y = clamp(
            proposedY,
            min: minimumSideMargin,
            max: containerBounds.maxY - height - minimumSideMargin
        )
        return PhoneFeedFilterBarLayout(
            placement: .aboveExpandedTabBar,
            frame: CGRect(x: sideMargin, y: y, width: width, height: height)
        )
    }

    private static func layoutBesideCollapsedDock(
        containerBounds: CGRect,
        selectedItemFrame: CGRect
    ) -> PhoneFeedFilterBarLayout? {
        let dockFrame = selectedItemFrame.intersection(containerBounds)
        guard dockFrame.isNull == false,
              dockFrame.width > 0,
              dockFrame.height > 0 else {
            return nil
        }

        let sideMargin = max(
            minimumSideMargin,
            min(dockFrame.minX, containerBounds.maxX - dockFrame.maxX)
        )
        let proposedY = dockFrame.midY - height / 2
        let y = clamp(
            proposedY,
            min: minimumSideMargin,
            max: containerBounds.maxY - height - minimumSideMargin
        )

        let rightX = dockFrame.maxX + dockGap
        let rightMaxX = containerBounds.maxX - sideMargin
        let rightWidth = rightMaxX - rightX
        if rightWidth >= minimumWidth {
            return PhoneFeedFilterBarLayout(
                placement: .besideCollapsedDock,
                frame: CGRect(x: rightX, y: y, width: rightWidth, height: height)
            )
        }

        let leftX = sideMargin
        let leftWidth = dockFrame.minX - dockGap - sideMargin
        guard leftWidth >= minimumWidth else { return nil }
        return PhoneFeedFilterBarLayout(
            placement: .besideCollapsedDock,
            frame: CGRect(x: leftX, y: y, width: leftWidth, height: height)
        )
    }

    private static func clamp(_ value: CGFloat, min minimum: CGFloat, max maximum: CGFloat) -> CGFloat {
        Swift.min(Swift.max(value, minimum), maximum)
    }
}
