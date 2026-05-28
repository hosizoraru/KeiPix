import SwiftUI

/// Automatically dismisses a status message after a delay.
///
/// Replaces the duplicated pattern of:
/// ```swift
/// .task(id: actionMessage) {
///     try? await Task.sleep(for: .seconds(2.5))
///     if actionMessage == message { actionMessage = nil }
/// }
/// ```
///
/// Usage:
/// ```swift
/// .statusMessageAutoDismiss($actionMessage)
/// ```
struct StatusMessageAutoDismissModifier: ViewModifier {
    @Binding var message: String?
    var duration: Duration = .seconds(2.5)

    func body(content: Content) -> some View {
        content
            .task(id: message) {
                guard message != nil else { return }
                try? await Task.sleep(for: duration)
                // Only dismiss if the message hasn't changed
                if message != nil {
                    message = nil
                }
            }
    }
}

extension View {
    /// Auto-dismiss a status message after a delay.
    func statusMessageAutoDismiss(_ message: Binding<String?>, duration: Duration = .seconds(2.5)) -> some View {
        modifier(StatusMessageAutoDismissModifier(message: message, duration: duration))
    }
}
