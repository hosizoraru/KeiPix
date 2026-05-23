import Foundation

enum ArtworkReadingMode: String, CaseIterable, Identifiable {
    case singlePage
    case continuous
    case index

    var id: String { rawValue }

    var title: String {
        switch self {
        case .singlePage:
            L10n.singlePage
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
