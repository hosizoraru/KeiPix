import Foundation

/// Per-surface image quality tier mirroring Pixiv's `image_urls` ladder
/// (`medium` / `large` / `original`). Pixez exposes the same three-step
/// picker for feed previews, illust detail, and manga detail; we use a
/// single enum so all three surfaces stay aligned.
///
/// The cases line up with the JSON keys in `PixivImageSet` so resolution
/// is a direct lookup with a sensible fallback chain when a particular
/// tier is missing from the response.
enum ArtworkImageQualityTier: String, CaseIterable, Codable, Hashable, Sendable, Identifiable {
    case medium
    case large
    case original

    var id: String { rawValue }

    var title: String {
        switch self {
        case .medium: L10n.imageQualityTierMedium
        case .large: L10n.imageQualityTierLarge
        case .original: L10n.imageQualityTierOriginal
        }
    }

    /// Compact glyph used in toolbars / inline pickers. SF Symbols only,
    /// matching the reader's HD/Standard chip language.
    var systemImage: String {
        switch self {
        case .medium: "photo"
        case .large: "photo.on.rectangle"
        case .original: "photo.stack"
        }
    }

    /// Maps the legacy binary "use original" preference into the tier
    /// space so existing call sites that only know about a Bool can be
    /// promoted without behaviour drift. Off becomes `.large` (the
    /// previous resolver default), on becomes `.original`.
    static func legacy(preferOriginal: Bool) -> ArtworkImageQualityTier {
        preferOriginal ? .original : .large
    }

    /// Convenience used by call sites that still take a `preferOriginal`
    /// flag — they only care whether the user wants the source asset.
    var prefersOriginal: Bool { self == .original }

    /// Background warming should never fan out source-size originals through
    /// scroll prefetch. Visible cells and readers still honor `.original`;
    /// opportunistic work caps at `.large` so it helps without hoarding huge
    /// decoded bitmaps.
    var backgroundPrefetchTier: ArtworkImageQualityTier {
        switch self {
        case .medium, .large:
            return self
        case .original:
            return .large
        }
    }
}
