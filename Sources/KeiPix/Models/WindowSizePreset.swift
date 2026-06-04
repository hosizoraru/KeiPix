import CoreGraphics
import SwiftUI
#if os(macOS)
import AppKit
#endif

enum MainWindowSizing {
    static let minimumHeight: CGFloat = 760
    static let defaultSize = CGSize(width: 1440, height: 860)

    static func minimumWidth(sidebarVisible: Bool) -> CGFloat {
        if sidebarVisible {
            1240
        } else {
            920
        }
    }
}

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
            CGSize(width: MainWindowSizing.minimumWidth(sidebarVisible: true), height: MainWindowSizing.minimumHeight)
        case (.balanced, true):
            MainWindowSizing.defaultSize
        case (.wide, true):
            CGSize(width: 1640, height: 940)
        case (.reading, true):
            CGSize(width: 1500, height: 940)
        case (.small, false):
            CGSize(width: MainWindowSizing.minimumWidth(sidebarVisible: false), height: 720)
        case (.balanced, false):
            CGSize(width: 1120, height: 780)
        case (.wide, false):
            CGSize(width: 1280, height: 860)
        case (.reading, false):
            CGSize(width: 1100, height: 860)
        }
    }

    #if os(macOS)
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
    #endif
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
