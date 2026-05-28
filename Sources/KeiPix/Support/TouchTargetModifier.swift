import SwiftUI

/// Ensures interactive elements meet the minimum touch target size
/// on iPadOS (44pt × 44pt per Apple HIG).
///
/// On macOS, this is a no-op since pointer precision is higher.
struct TouchTargetModifier: ViewModifier {
    func body(content: Content) -> some View {
        #if os(iOS)
        content
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
        #else
        content
        #endif
    }
}

extension View {
    /// Apply minimum touch target size on iPadOS.
    func touchTarget() -> some View {
        modifier(TouchTargetModifier())
    }
}
