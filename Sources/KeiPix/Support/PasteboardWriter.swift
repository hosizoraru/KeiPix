import SwiftUI

/// Cross-platform clipboard facade. On macOS wraps `NSPasteboard`,
/// on iPadOS wraps `UIPasteboard`. Call sites never touch the
/// platform clipboard directly — they go through this enum so a
/// future iPadOS build compiles without `#if` blocks in views.
enum PasteboardWriter {
    static func copy(_ string: String) {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
        #else
        UIPasteboard.general.string = string
        #endif
    }

    /// Returns the trimmed string currently on the general pasteboard,
    /// or `nil` if the pasteboard is empty / contains a non-string type.
    static func currentString() -> String? {
        #if os(macOS)
        guard let raw = NSPasteboard.general.string(forType: .string) else {
            return nil
        }
        #else
        guard let raw = UIPasteboard.general.string else {
            return nil
        }
        #endif
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
