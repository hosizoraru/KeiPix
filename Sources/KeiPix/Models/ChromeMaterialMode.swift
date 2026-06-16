import Foundation

/// User-facing performance tier for app chrome that floats over artwork.
///
/// Full Liquid Glass gives artwork the richest reflections, while lighter
/// modes keep the same geometry but reduce or remove background blur work.
enum ChromeMaterialMode: String, CaseIterable, Codable, Hashable, Sendable, Identifiable {
    case plain
    case translucentBlur
    case liquidGlass

    var id: String { rawValue }

    var title: String {
        switch self {
        case .plain: L10n.chromeMaterialModePlain
        case .translucentBlur: L10n.chromeMaterialModeTranslucentBlur
        case .liquidGlass: L10n.chromeMaterialModeLiquidGlass
        }
    }

    var detail: String {
        switch self {
        case .plain: L10n.chromeMaterialModePlainHint
        case .translucentBlur: L10n.chromeMaterialModeTranslucentBlurHint
        case .liquidGlass: L10n.chromeMaterialModeLiquidGlassHint
        }
    }

    var systemImage: String {
        switch self {
        case .plain: "rectangle"
        case .translucentBlur: "rectangle.on.rectangle"
        case .liquidGlass: "sparkles.rectangle.stack"
        }
    }
}
