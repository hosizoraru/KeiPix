import Foundation

enum NovelGalleryLayoutMode: String, CaseIterable, Identifiable {
    case list
    case grid

    var id: String { rawValue }

    var title: String {
        switch self {
        case .list: L10n.listRow
        case .grid: L10n.compact
        }
    }

    var systemImage: String {
        switch self {
        case .list: "list.bullet"
        case .grid: "square.grid.2x2"
        }
    }
}
