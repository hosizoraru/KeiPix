import Foundation

enum VisualQALaunchArgument: String, CaseIterable {
    case pixivLinkDrop = "--visual-qa-pixiv-link-drop"
    case pixivIDOpen = "--visual-qa-pixiv-id-open"
    case mangaWatchlist = "--visual-qa-manga-watchlist"
    case seriesSheet = "--visual-qa-series-sheet"
    case cachedFeed = "--visual-qa-cached-feed"
    case galleryAuto = "--visual-qa-gallery-auto"
    case galleryTwoColumn = "--visual-qa-gallery-two-column"
    case galleryThreeColumn = "--visual-qa-gallery-three-column"
    case galleryCompact = "--visual-qa-gallery-compact"
    case ranking = "--visual-qa-ranking"
    case mutedContent = "--visual-qa-muted-content"
    case settingsWindow = "--visual-qa-settings-window"
    case ugoiraPlayer = "--visual-qa-ugoira-player"
    case downloadedReader = "--visual-qa-downloaded-reader"
    case feedbackSheet = "--visual-qa-feedback-sheet"

    var surface: VisualQASurface {
        switch self {
        case .pixivLinkDrop:
            .pixivLinkDrop
        case .pixivIDOpen:
            .pixivIDOpen
        case .mangaWatchlist:
            .mangaWatchlist
        case .seriesSheet:
            .seriesSheet
        case .cachedFeed:
            .cachedFeed
        case .galleryAuto:
            .galleryAuto
        case .galleryTwoColumn:
            .galleryTwoColumn
        case .galleryThreeColumn:
            .galleryThreeColumn
        case .galleryCompact:
            .galleryCompact
        case .ranking:
            .ranking
        case .mutedContent:
            .mutedContent
        case .settingsWindow:
            .settingsWindow
        case .ugoiraPlayer:
            .ugoiraPlayer
        case .downloadedReader:
            .downloadedReader
        case .feedbackSheet:
            .feedbackSheet
        }
    }

    var galleryLayoutMode: GalleryLayoutMode? {
        switch self {
        case .galleryAuto:
            .autoMasonry
        case .galleryTwoColumn:
            .twoColumnMasonry
        case .galleryThreeColumn:
            .threeColumnMasonry
        case .galleryCompact:
            .compactGrid
        default:
            nil
        }
    }

    static func contains(_ argument: VisualQALaunchArgument) -> Bool {
        contains(argument, in: ProcessInfo.processInfo.arguments)
    }

    static func contains(_ argument: VisualQALaunchArgument, in arguments: [String]) -> Bool {
        arguments.contains(argument.rawValue)
    }

    static var isActive: Bool {
        isActive(in: ProcessInfo.processInfo.arguments)
    }

    static func isActive(in arguments: [String]) -> Bool {
        Self.allCases.contains { contains($0, in: arguments) }
    }

    static var activeGalleryLayoutMode: GalleryLayoutMode? {
        activeGalleryLayoutMode(in: ProcessInfo.processInfo.arguments)
    }

    static func activeGalleryLayoutMode(in arguments: [String]) -> GalleryLayoutMode? {
        Self.allCases.first { argument in
            argument.galleryLayoutMode != nil && contains(argument, in: arguments)
        }?.galleryLayoutMode
    }
}
