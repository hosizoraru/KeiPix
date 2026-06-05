import CoreGraphics
import Foundation

enum GalleryAutoLoadMorePolicy: Sendable {
    static let defaultPrefetchScreens: CGFloat = 1.15

    static func shouldTrigger(
        nextURL: URL?,
        isLoadingMore: Bool,
        hasRestoration: Bool,
        lastTriggeredURL: URL?
    ) -> Bool {
        guard let nextURL,
              isLoadingMore == false,
              hasRestoration == false else {
            return false
        }
        return nextURL != lastTriggeredURL
    }

    static func isNearContentEnd(
        contentOffsetY: CGFloat,
        viewportHeight: CGFloat,
        contentHeight: CGFloat,
        adjustedBottomInset: CGFloat = 0,
        prefetchScreens: CGFloat = defaultPrefetchScreens
    ) -> Bool {
        guard contentHeight > 0,
              viewportHeight > 0,
              prefetchScreens >= 0 else {
            return false
        }

        let visibleBottomY = max(contentOffsetY, 0) + max(viewportHeight - adjustedBottomInset, 0)
        let remainingDistance = contentHeight - visibleBottomY
        return remainingDistance <= viewportHeight * prefetchScreens
    }
}
