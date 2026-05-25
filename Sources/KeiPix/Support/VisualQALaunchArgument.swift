import Foundation

enum VisualQALaunchArgument: String, CaseIterable {
    case pixivLinkDrop = "--visual-qa-pixiv-link-drop"
    case mangaWatchlist = "--visual-qa-manga-watchlist"

    var surface: VisualQASurface {
        switch self {
        case .pixivLinkDrop:
            .pixivLinkDrop
        case .mangaWatchlist:
            .mangaWatchlist
        }
    }

    static func contains(_ argument: VisualQALaunchArgument) -> Bool {
        ProcessInfo.processInfo.arguments.contains(argument.rawValue)
    }
}
