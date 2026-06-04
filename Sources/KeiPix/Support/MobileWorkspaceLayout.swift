import CoreGraphics

struct MobileWorkspaceLayout: Equatable, Sendable {
    static let iPadLandscapeSidebarMinimumWidth: CGFloat = 700

    let size: CGSize
    let platform: ReaderPlatformKind

    init(size: CGSize, platform: ReaderPlatformKind) {
        self.size = size
        self.platform = platform
    }

    var usesLandscapeSidebar: Bool {
        guard platform == .pad else { return false }
        return validWidth >= Self.iPadLandscapeSidebarMinimumWidth
            && validWidth > validHeight
    }

    var usesCompactTabs: Bool {
        usesLandscapeSidebar == false
    }

    private var validWidth: CGFloat {
        guard size.width.isFinite, size.width > 0 else { return 0 }
        return size.width
    }

    private var validHeight: CGFloat {
        guard size.height.isFinite, size.height > 0 else { return 0 }
        return size.height
    }
}
