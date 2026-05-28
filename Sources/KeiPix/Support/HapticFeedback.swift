#if os(macOS)
import AppKit
#endif

/// Provides haptic feedback for key user actions.
///
/// Uses `NSHapticFeedbackManager` on macOS to give tactile
/// confirmation for bookmarks, downloads, and destructive actions.
enum HapticFeedback {
    /// Light feedback for bookmark toggles.
    static func bookmark() {
        #if os(macOS)
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
        #endif
    }

    /// Medium feedback for download completion.
    static func downloadComplete() {
        #if os(macOS)
        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .default)
        #endif
    }

    /// Success feedback for completed actions.
    static func success() {
        #if os(macOS)
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
        #endif
    }

    /// Generic feedback for UI interactions.
    static func impact() {
        #if os(macOS)
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .default)
        #endif
    }
}
