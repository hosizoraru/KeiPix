import CoreGraphics

struct MobileWorkspaceLayout: Equatable, Sendable {
    static let iPadLandscapeSidebarMinimumWidth: CGFloat = 700
    static let compactChromeMaximumWidth: CGFloat = 620
    static let articleTextMaximumWidth: CGFloat = 720

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

    /// iPad portrait uses the compact root but still has enough top chrome
    /// room for a portrait-only shortcut tab. Phones keep the smaller bottom
    /// tab bar, and iPad landscape uses the sidebar instead.
    var usesPortraitTopCustomization: Bool {
        platform == .pad && usesCompactTabs && isPortrait
    }

    var isPortrait: Bool {
        validHeight >= validWidth
    }

    var usesCondensedChrome: Bool {
        platform == .phone || validWidth < Self.compactChromeMaximumWidth
    }

    var articleHorizontalPadding: CGFloat {
        if platform == .phone || validWidth < 500 {
            return 16
        }
        if isPortrait {
            return 22
        }
        return 28
    }

    var articleContentMaximumWidth: CGFloat {
        min(Self.articleTextMaximumWidth, max(0, validWidth - articleHorizontalPadding * 2))
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
