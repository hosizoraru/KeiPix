import AppKit
import CoreGraphics

enum WindowSizePreset: String, CaseIterable, Identifiable {
    case small
    case balanced
    case wide
    case reading

    var id: String { rawValue }

    var title: String {
        switch self {
        case .small:
            L10n.smallWindow
        case .balanced:
            L10n.balancedWindow
        case .wide:
            L10n.wideWindow
        case .reading:
            L10n.readingWindow
        }
    }

    func size(sidebarVisible: Bool) -> CGSize {
        switch (self, sidebarVisible) {
        case (.small, true):
            CGSize(width: 1060, height: 720)
        case (.balanced, true):
            CGSize(width: 1240, height: 800)
        case (.wide, true):
            CGSize(width: 1400, height: 860)
        case (.reading, true):
            CGSize(width: 1320, height: 860)
        case (.small, false):
            CGSize(width: 940, height: 700)
        case (.balanced, false):
            CGSize(width: 1120, height: 760)
        case (.wide, false):
            CGSize(width: 1280, height: 840)
        case (.reading, false):
            CGSize(width: 1080, height: 840)
        }
    }

    @MainActor
    func apply(sidebarVisible: Bool) {
        guard let window = NSApp.keyWindow ?? NSApp.mainWindow else { return }
        let targetSize = size(sidebarVisible: sidebarVisible)
        let visibleFrame = window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? window.frame
        let fittedSize = CGSize(
            width: min(targetSize.width, visibleFrame.width),
            height: min(targetSize.height, visibleFrame.height)
        )
        let currentFrame = window.frame
        var nextFrame = CGRect(origin: currentFrame.origin, size: fittedSize)
        nextFrame.origin.x = currentFrame.midX - fittedSize.width / 2
        nextFrame.origin.y = currentFrame.maxY - fittedSize.height
        nextFrame.origin.x = nextFrame.origin.x.clamped(to: visibleFrame.minX...(visibleFrame.maxX - fittedSize.width))
        nextFrame.origin.y = nextFrame.origin.y.clamped(to: visibleFrame.minY...(visibleFrame.maxY - fittedSize.height))
        window.setFrame(nextFrame, display: true, animate: true)
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
