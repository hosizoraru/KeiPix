import Foundation

enum ArtworkReadingMode: String, CaseIterable, Identifiable {
    case singlePage
    case doublePage
    case continuous
    case index

    var id: String { rawValue }

    var title: String {
        switch self {
        case .singlePage:
            L10n.singlePage
        case .doublePage:
            L10n.doublePage
        case .continuous:
            L10n.continuousReading
        case .index:
            L10n.pageIndex
        }
    }

    var systemImage: String {
        switch self {
        case .singlePage:
            "rectangle"
        case .doublePage:
            "rectangle.split.2x1"
        case .continuous:
            "rectangle.stack"
        case .index:
            "square.grid.3x3"
        }
    }

    static func defaultMode(for pageCount: Int) -> ArtworkReadingMode {
        pageCount >= 12 ? .continuous : .singlePage
    }
}

enum ArtworkReadingModePreferenceKind: String {
    case artwork
    case manga

    var storageKey: String {
        switch self {
        case .artwork:
            "defaultArtworkReadingMode"
        case .manga:
            "defaultMangaReadingMode"
        }
    }

    var fallbackMode: ArtworkReadingMode {
        switch self {
        case .artwork:
            .singlePage
        case .manga:
            .continuous
        }
    }

    static func kind(for artwork: PixivArtwork, pageCount: Int) -> ArtworkReadingModePreferenceKind {
        artwork.type == "manga" || pageCount >= 12 ? .manga : .artwork
    }
}
