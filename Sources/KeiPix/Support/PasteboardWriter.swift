import AppKit

enum PasteboardWriter {
    static func copy(_ string: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
    }

    /// Returns the trimmed string currently on the general pasteboard,
    /// or `nil` if the pasteboard is empty / contains a non-string type.
    /// Sheets call this from "paste" affordances (e.g. paste a Pixiv ID
    /// from the clipboard) so we don't reach into `NSPasteboard` from
    /// the views.
    static func currentString() -> String? {
        guard let raw = NSPasteboard.general.string(forType: .string) else {
            return nil
        }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
