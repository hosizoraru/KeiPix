import SwiftUI

/// Accessibility support utilities for reduce motion and high contrast.

/// High contrast support utilities.
@MainActor
enum HighContrastSupport {
    /// Check if high contrast is enabled.
    static var isHighContrastEnabled: Bool {
        #if os(macOS)
        return NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
        #else
        return UIAccessibility.isDarkerSystemColorsEnabled
        #endif
    }

    /// Get border color that respects high contrast setting.
    static func borderColor(default: Color, highContrast: Color) -> Color {
        isHighContrastEnabled ? highContrast : `default`
    }

    /// Get opacity that respects high contrast setting.
    static func opacity(default: Double, highContrast: Double) -> Double {
        isHighContrastEnabled ? highContrast : `default`
    }
}

/// Reduce motion support utilities.
///
/// Respects the system's "Reduce Motion" accessibility setting
/// by disabling or simplifying animations when enabled.
@MainActor
enum ReduceMotionSupport {
    /// Check if reduce motion is enabled.
    static var isReduceMotionEnabled: Bool {
        #if os(macOS)
        return NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        #else
        return UIAccessibility.isReduceMotionEnabled
        #endif
    }

    /// Animation that respects reduce motion setting.
    /// Returns nil animation when reduce motion is enabled.
    static func animation<V: Equatable>(_ animation: Animation?, value: V) -> Animation? {
        isReduceMotionEnabled ? nil : animation
    }

    /// Transition that respects reduce motion setting.
    /// Returns identity transition when reduce motion is enabled.
    static func transition(_ transition: AnyTransition) -> AnyTransition {
        isReduceMotionEnabled ? .identity : transition
    }
}

// MARK: - SwiftUI View extension

extension View {
    /// Apply animation that respects reduce motion setting.
    @MainActor
    func accessibleAnimation<V: Equatable>(_ animation: Animation?, value: V) -> some View {
        self.animation(ReduceMotionSupport.animation(animation, value: value), value: value)
    }

    /// Apply transition that respects reduce motion setting.
    @MainActor
    func accessibleTransition(_ transition: AnyTransition) -> some View {
        self.transition(ReduceMotionSupport.transition(transition))
    }
}

// MARK: - Environment key

private struct ReduceMotionKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var isReduceMotionEnabled: Bool {
        get { self[ReduceMotionKey.self] }
        set { self[ReduceMotionKey.self] = newValue }
    }
}

// MARK: - Reduce motion modifier

struct ReduceMotionModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .environment(\.isReduceMotionEnabled, reduceMotion)
    }
}

extension View {
    /// Add reduce motion environment value.
    func withReduceMotion() -> some View {
        modifier(ReduceMotionModifier())
    }
}
