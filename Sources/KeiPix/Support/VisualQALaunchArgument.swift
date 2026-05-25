import Foundation

enum VisualQALaunchArgument: String, CaseIterable {
    case pixivLinkDrop = "--visual-qa-pixiv-link-drop"
    case mangaWatchlist = "--visual-qa-manga-watchlist"
    case seriesSheet = "--visual-qa-series-sheet"
    case cachedFeed = "--visual-qa-cached-feed"

    var surface: VisualQASurface {
        switch self {
        case .pixivLinkDrop:
            .pixivLinkDrop
        case .mangaWatchlist:
            .mangaWatchlist
        case .seriesSheet:
            .seriesSheet
        case .cachedFeed:
            .cachedFeed
        }
    }

    static func contains(_ argument: VisualQALaunchArgument) -> Bool {
        ProcessInfo.processInfo.arguments.contains(argument.rawValue)
    }
}
