#if os(macOS)
import AppKit
import Foundation
import UniformTypeIdentifiers

@MainActor
extension KeiPixStore {
    func exportMutedContentToFile() throws -> Bool {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = "keipix-muted-content-\(Self.fileDateFormatter.string(from: Date())).json"
        panel.title = L10n.exportMutedContent
        panel.prompt = L10n.export

        guard panel.runModal() == .OK, let url = panel.url else { return false }
        try exportMutedContentData().write(to: url, options: .atomic)
        return true
    }

    func importMutedContentFromFile() throws -> Bool {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.title = L10n.importMutedContent
        panel.prompt = L10n.import

        guard panel.runModal() == .OK, let url = panel.url else { return false }
        try importMutedContentData(Data(contentsOf: url))
        return true
    }

    private static let fileDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter
    }()
}
#endif
