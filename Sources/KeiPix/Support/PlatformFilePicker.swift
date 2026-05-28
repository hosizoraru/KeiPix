import SwiftUI
import UniformTypeIdentifiers
#if os(macOS)
import AppKit
#endif

/// Cross-platform file picker facade.
///
/// macOS: wraps `NSSavePanel` / `NSOpenPanel`
/// iPadOS: uses SwiftUI `.fileExporter` / `.fileImporter` modifiers
enum PlatformFilePicker {

    // MARK: - Save (macOS only — iPadOS uses view modifiers)

    /// Presents a save panel and writes `data` to the user-chosen URL.
    /// Returns the chosen URL on success, `nil` on cancel.
    /// macOS only — iPadOS should use `.fileExporter` view modifier.
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
        // iPadOS uses .fileExporter view modifier at the call site.
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

    // MARK: - Open (macOS only — iPadOS uses view modifiers)

    /// Presents an open panel and returns the selected file URL(s).
    /// macOS only — iPadOS should use `.fileImporter` view modifier.
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
        // iPadOS uses .fileImporter view modifier at the call site.
        return []
        #endif
    }

    // MARK: - Directory (macOS only — iPadOS uses view modifiers)

    /// Presents an open panel for selecting a directory.
    /// macOS only — iPadOS should use `.fileImporter` view modifier.
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
        // iPadOS uses .fileImporter view modifier at the call site.
        return nil
        #endif
    }
}

// MARK: - iPadOS File Export Modifier

#if os(iOS)
/// View modifier for iPadOS file export using `.fileExporter`.
struct FileExportModifier: ViewModifier {
    @Binding var isPresented: Bool
    let document: FileExportDocument
    let onCompletion: (Result<URL, Error>) -> Void

    func body(content: Content) -> some View {
        content
            .fileExporter(
                isPresented: $isPresented,
                document: document,
                contentType: document.contentType,
                defaultFilename: document.filename
            ) { result in
                onCompletion(result)
            }
    }
}

/// Simple document type for file export on iPadOS.
struct FileExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.data] }

    let data: Data
    let contentType: UTType
    let filename: String

    init(data: Data, contentType: UTType, filename: String) {
        self.data = data
        self.contentType = contentType
        self.filename = filename
    }

    init(configuration: ReadConfiguration) throws {
        self.data = configuration.file.regularFileContents ?? Data()
        self.contentType = .data
        self.filename = "export"
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

extension View {
    /// Present a file exporter on iPadOS.
    func fileExport(
        isPresented: Binding<Bool>,
        document: FileExportDocument,
        onCompletion: @escaping (Result<URL, Error>) -> Void
    ) -> some View {
        modifier(FileExportModifier(
            isPresented: isPresented,
            document: document,
            onCompletion: onCompletion
        ))
    }
}
#endif
