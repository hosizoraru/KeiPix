import Foundation

enum VisualQALaunchArgument: String, CaseIterable {
    case discoverDashboard = "--visual-qa-discover-dashboard"
    case discoverDashboardCustomization = "--visual-qa-discover-dashboard-customization"
    case pixivLinkDrop = "--visual-qa-pixiv-link-drop"
    case pixivIDOpen = "--visual-qa-pixiv-id-open"
    case pixivActivity = "--visual-qa-pixiv-activity"
    case creatorProfile = "--visual-qa-creator-profile"
    case mangaWatchlist = "--visual-qa-manga-watchlist"
    case workSubscriptions = "--visual-qa-work-subscriptions"
    case seriesSheet = "--visual-qa-series-sheet"
    case cachedFeed = "--visual-qa-cached-feed"
    case galleryAuto = "--visual-qa-gallery-auto"
    case galleryTwoColumn = "--visual-qa-gallery-two-column"
    case galleryThreeColumn = "--visual-qa-gallery-three-column"
    case galleryCompact = "--visual-qa-gallery-compact"
    case novelFeed = "--visual-qa-novel-feed"
    case novelTranslationSmoke = "--visual-qa-novel-translation-smoke"
    case searchWorkspace = "--visual-qa-search-workspace"
    case ranking = "--visual-qa-ranking"
    case mutedContent = "--visual-qa-muted-content"
    case settingsWindow = "--visual-qa-settings-window"
    case downloadSettings = "--visual-qa-download-settings"
    case bottomTabs = "--visual-qa-bottom-tabs"
    case runtimeReadiness = "--visual-qa-runtime-readiness"
    case sharingTemplates = "--visual-qa-sharing-templates"
    case ugoiraPlayer = "--visual-qa-ugoira-player"
    case downloadQueue = "--visual-qa-download-queue"
    case downloadedReader = "--visual-qa-downloaded-reader"
    case readerWindow = "--visual-qa-reader-window"
    case feedbackSheet = "--visual-qa-feedback-sheet"
    case artworkDetailSocial = "--visual-qa-artwork-detail-social"
    case bookmarkEditor = "--visual-qa-bookmark-editor"
    case novelBookmarkEditor = "--visual-qa-novel-bookmark-editor"
    case about = "--visual-qa-about"

    var surface: VisualQASurface {
        switch self {
        case .discoverDashboard, .discoverDashboardCustomization:
            .discoverDashboard
        case .pixivLinkDrop:
            .pixivLinkDrop
        case .pixivIDOpen:
            .pixivIDOpen
        case .pixivActivity:
            .pixivActivity
        case .creatorProfile:
            .creatorProfile
        case .mangaWatchlist:
            .mangaWatchlist
        case .workSubscriptions:
            .workSubscriptions
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
        case .novelFeed:
            .novelFeed
        case .novelTranslationSmoke:
            .novelTranslationSmoke
        case .searchWorkspace:
            .searchWorkspace
        case .ranking:
            .ranking
        case .mutedContent:
            .mutedContent
        case .settingsWindow:
            .settingsWindow
        case .downloadSettings:
            .downloadSettings
        case .bottomTabs:
            .bottomTabs
        case .runtimeReadiness:
            .runtimeReadiness
        case .sharingTemplates:
            .sharingTemplates
        case .ugoiraPlayer:
            .ugoiraPlayer
        case .downloadQueue:
            .downloadQueue
        case .downloadedReader:
            .downloadedReader
        case .readerWindow:
            .readerWindow
        case .feedbackSheet:
            .feedbackSheet
        case .artworkDetailSocial:
            .artworkDetailSocial
        case .bookmarkEditor:
            .bookmarkEditor
        case .novelBookmarkEditor:
            .novelBookmarkEditor
        case .about:
            .about
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
