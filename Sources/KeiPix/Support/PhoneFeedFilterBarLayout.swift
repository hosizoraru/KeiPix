import CoreGraphics

struct PhoneFeedFilterChromeLayout: Equatable {
    static let pillHeight: CGFloat = 34
    static let panelHeight: CGFloat = 46

    private static let aboveTabGap: CGFloat = 10
    private static let minimumSideMargin: CGFloat = 16
    private static let maximumPanelWidth: CGFloat = 440
    private static let minimumPillWidth: CGFloat = 72
    private static let maximumPillWidth: CGFloat = 132

    let pillFrame: CGRect
    let panelFrame: CGRect

    static func resolve(
        containerSize: CGSize,
        tabBarGeometry: TabBarGeometrySnapshot?,
        preferredPillWidth: CGFloat = minimumPillWidth
    ) -> PhoneFeedFilterChromeLayout? {
        guard containerSize.width > 0,
              containerSize.height > 0,
              let tabBarGeometry else {
            return nil
        }

        let containerBounds = CGRect(origin: .zero, size: containerSize)
        let tabFrame = tabBarGeometry.tabBarFrame.intersection(containerBounds)
        guard tabFrame.isNull == false,
              tabFrame.width > 0,
              tabFrame.height > 0 else {
            return nil
        }

        let panelWidth = min(
            maximumPanelWidth,
            max(0, containerBounds.width - minimumSideMargin * 2)
        )
        guard panelWidth > 0 else { return nil }
        let panelX = containerBounds.midX - panelWidth / 2
        let pillWidth = clamp(
            preferredPillWidth.rounded(.up),
            min: minimumPillWidth,
            max: min(maximumPillWidth, containerBounds.width - minimumSideMargin * 2)
        )
        let proposedY = tabFrame.minY - aboveTabGap - panelHeight
        let y = clamp(
            proposedY,
            min: minimumSideMargin,
            max: containerBounds.maxY - panelHeight - minimumSideMargin
        )
        let panelFrame = CGRect(x: panelX, y: y, width: panelWidth, height: panelHeight)
        return PhoneFeedFilterChromeLayout(
            pillFrame: CGRect(
                x: containerBounds.midX - pillWidth / 2,
                y: panelFrame.midY - pillHeight / 2,
                width: pillWidth,
                height: pillHeight
            ),
            panelFrame: panelFrame
        )
    }

    private static func clamp(_ value: CGFloat, min minimum: CGFloat, max maximum: CGFloat) -> CGFloat {
        Swift.min(Swift.max(value, minimum), maximum)
    }
}
