import Foundation

/// Column layout for the Pixivision article list.
///
/// `.auto` keeps the existing adaptive grid (the surface picks columns
/// based on the window width). `.single` forces one card per row, which
/// gives the article hero card a wide treatment that matches Pixivision
/// Web's own desktop layout. `.twoUp` pins exactly two columns for
/// users who want the denser "magazine spread" look.
enum SpotlightListLayoutMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case auto
    case single
    case twoUp

    var id: String { rawValue }

    var title: String {
        switch self {
        case .auto:
            L10n.creatorLayoutAuto
        case .single:
            L10n.creatorLayoutSingle
        case .twoUp:
            L10n.creatorLayoutTwoUp
        }
    }

    var systemImage: String {
        switch self {
        case .auto:
            "rectangle.grid.1x2"
        case .single:
            "rectangle"
        case .twoUp:
            "rectangle.split.2x1"
        }
    }

    /// True when each card should render the wide hero variant — used
    /// by the `.single` column mode so an article gets a magazine-style
    /// hero strip instead of a packed-down portrait.
    var usesHeroCardLayout: Bool {
        self == .single
    }
}
