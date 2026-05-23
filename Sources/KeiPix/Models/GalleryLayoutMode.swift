import Foundation

enum GalleryLayoutMode: String, CaseIterable, Identifiable {
    case autoMasonry
    case twoColumnMasonry
    case threeColumnMasonry
    case compactGrid

    var id: String { rawValue }

    var title: String {
        switch self {
        case .autoMasonry:
            L10n.auto
        case .twoColumnMasonry:
            L10n.twoColumns
        case .threeColumnMasonry:
            L10n.threeColumns
        case .compactGrid:
            L10n.compact
        }
    }

    var systemImage: String {
        switch self {
        case .autoMasonry:
            "wand.and.stars"
        case .twoColumnMasonry:
            "rectangle.split.2x1"
        case .threeColumnMasonry:
            "rectangle.split.3x1"
        case .compactGrid:
            "square.grid.3x3"
        }
    }

    var fixedColumnCount: Int? {
        switch self {
        case .autoMasonry, .compactGrid:
            nil
        case .twoColumnMasonry:
            2
        case .threeColumnMasonry:
            3
        }
    }

    var usesCompactGrid: Bool {
        self == .compactGrid
    }
}
