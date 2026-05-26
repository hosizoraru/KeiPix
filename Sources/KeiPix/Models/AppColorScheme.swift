import SwiftUI

/// User-selectable app theme override.
///
/// Mirrors the System/Light/Dark picker macOS System Settings ships under
/// Apperance, and matches what Pixez/Pixes expose so users who prefer a
/// fixed scheme inside KeiPix don't have to flip the whole macOS theme.
enum AppColorScheme: String, CaseIterable, Identifiable, Codable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: L10n.themeSystem
        case .light: L10n.themeLight
        case .dark: L10n.themeDark
        }
    }

    var systemImage: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max"
        case .dark: "moon"
        }
    }

    /// Resolves the override into the SwiftUI `ColorScheme` to apply, or
    /// `nil` to inherit from the system. Wrap each scene's root view in
    /// `.preferredColorScheme(scheme.preferredColorScheme)` so the override
    /// flows down through the SwiftUI environment.
    var preferredColorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}
