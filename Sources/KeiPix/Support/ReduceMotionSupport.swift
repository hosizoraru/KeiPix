import SwiftUI

/// Reduce motion support utilities.
///
/// Respects the system's "Reduce Motion" accessibility setting
/// by disabling or simplifying animations when enabled.
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
    func accessibleAnimation<V: Equatable>(_ animation: Animation?, value: V) -> some View {
        self.animation(ReduceMotionSupport.animation(animation, value: value), value: value)
    }

    /// Apply transition that respects reduce motion setting.
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
