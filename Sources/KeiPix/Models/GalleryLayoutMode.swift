import Foundation

enum GalleryLayoutMode: String, CaseIterable, Identifiable {
    case autoMasonry
    case twoColumnMasonry
    case threeColumnMasonry
    case compactGrid
    case listRow

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
        case .listRow:
            L10n.listRow
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
        case .listRow:
            "list.bullet"
        }
    }

    var fixedColumnCount: Int? {
        switch self {
        case .autoMasonry, .compactGrid, .listRow:
            nil
        case .twoColumnMasonry:
            2
        case .threeColumnMasonry:
            3
        }
    }

    var usesArtworkMasonry: Bool {
        switch self {
        case .autoMasonry, .twoColumnMasonry, .threeColumnMasonry:
            true
        case .compactGrid, .listRow:
            false
        }
    }

    var usesCompactGrid: Bool {
        self == .compactGrid
    }

    var usesListRow: Bool {
        self == .listRow
    }
}
