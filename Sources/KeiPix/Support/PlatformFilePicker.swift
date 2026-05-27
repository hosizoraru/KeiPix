import SwiftUI
import UniformTypeIdentifiers
#if os(macOS)
import AppKit
#endif

/// Cross-platform file picker facade. On macOS wraps `NSSavePanel` /
/// `NSOpenPanel`; on iPadOS wraps `.fileExporter` / `.fileImporter`
/// view modifiers. Phase 1 creates the surface — Phase 3 migrates
/// the 15 call sites.
enum PlatformFilePicker {

    // MARK: - Save

    /// Presents a save panel and writes `data` to the user-chosen URL.
    /// Returns the chosen URL on success, `nil` on cancel.
    @MainActor
    static func saveFile(
        data: Data,
        suggestedFilename: String,
        allowedContentTypes: [UTType]
    ) -> URL? {
        #if os(macOS)
        let panel = NSSavePanel()
        panel.nameFieldStringValue = suggestedFilename
        panel.canCreateDirectories = true
        panel.allowedContentTypes = allowedContentTypes
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        try? data.write(to: url, options: .atomic)
        return url
        #else
        // iPadOS path will use .fileExporter modifier at the call site.
        // This synchronous wrapper is a placeholder — the real iPadOS
        // implementation drives the view modifier and receives the URL
        // through a binding.
        return nil
        #endif
    }

    /// Presents a save panel and writes `string` to the user-chosen URL.
    @MainActor
    static func saveFile(
        string: String,
        suggestedFilename: String,
        allowedContentTypes: [UTType]
    ) -> URL? {
        saveFile(
            data: Data(string.utf8),
            suggestedFilename: suggestedFilename,
            allowedContentTypes: allowedContentTypes
        )
    }

    // MARK: - Open

    /// Presents an open panel and returns the selected file URL(s).
    @MainActor
    static func openFile(
        allowedContentTypes: [UTType],
        allowsMultipleSelection: Bool = false
    ) -> [URL] {
        #if os(macOS)
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = allowsMultipleSelection
        panel.allowedContentTypes = allowedContentTypes
        guard panel.runModal() == .OK else { return [] }
        return panel.urls
        #else
        return []
        #endif
    }

    // MARK: - Directory

    /// Presents an open panel for selecting a directory.
    @MainActor
    static func openDirectory(
        allowsMultipleSelection: Bool = false
    ) -> URL? {
        #if os(macOS)
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = allowsMultipleSelection
        guard panel.runModal() == .OK else { return nil }
        return panel.url
        #else
        return nil
        #endif
    }
}
