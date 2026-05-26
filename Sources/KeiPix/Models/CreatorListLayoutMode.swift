import Foundation

/// Column layout for the creator list surfaces (recommended /
/// search / following / pinned).
///
/// `.auto` mirrors the existing adaptive grid (cards stretch to fill
/// the window, with as many columns as fit at the minimum width).
/// `.single` and `.twoUp` are explicit overrides for users who want a
/// specific density — single is especially useful because the wider
/// card lets the preview strip become a scrollable horizontal shelf
/// (think Apple Music's "Latest Releases" carousel) so trackpad users
/// can swipe through more recent works at a glance.
enum CreatorListLayoutMode: String, CaseIterable, Identifiable, Codable, Sendable {
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

    /// True when the card should expand its artwork strip into a
    /// horizontally scrollable shelf instead of a fixed three-thumb row.
    var usesExpandedPreview: Bool {
        self == .single
    }
}
