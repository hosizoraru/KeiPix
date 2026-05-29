#if os(macOS)
import AppKit

/// Enhanced workspace integration for macOS.
///
/// Provides richer NSWorkspace operations:
/// - Custom file icons for downloaded artwork
/// - Finder tags for categorization
/// - File metadata utilities
enum WorkspaceEnhancer {

    /// Set a custom icon for a file or folder.
    static func setCustomIcon(_ icon: NSImage, for url: URL) {
        NSWorkspace.shared.setIcon(icon, forFile: url.path)
    }

    /// Add a Finder tag to a file.
    static func addTag(_ tag: String, to url: URL) {
        let tags = getTags(for: url)
        if !tags.contains(tag) {
            var newTags = tags
            newTags.append(tag)
            setTags(newTags, for: url)
        }
    }

    /// Remove a Finder tag from a file.
    static func removeTag(_ tag: String, from url: URL) {
        let tags = getTags(for: url)
        var newTags = tags
        newTags.removeAll { $0 == tag }
        setTags(newTags, for: url)
    }

    /// Get all Finder tags for a file.
    static func getTags(for url: URL) -> [String] {
        let data = getxattr(url.path, "com.apple.metadata:_kMDItemUserTags", nil, 0, 0, 0)
        guard data > 0 else { return [] }
        var buffer = [UInt8](repeating: 0, count: data)
        getxattr(url.path, "com.apple.metadata:_kMDItemUserTags", &buffer, data, 0, 0)
        let tagString = String(bytes: buffer, encoding: .utf8) ?? ""
        return tagString.components(separatedBy: "\n").filter { !$0.isEmpty }
    }

    private static func setTags(_ tags: [String], for url: URL) {
        let tagString = tags.joined(separator: "\n")
        let data = Data(tagString.utf8)
        setxattr(url.path, "com.apple.metadata:_kMDItemUserTags", (data as NSData).bytes, data.count, 0, 0)
    }

    /// Check if a file is currently being used by another process.
    static func isFileInUse(_ url: URL) -> Bool {
        return NSWorkspace.shared.isFilePackage(atPath: url.path)
    }

    /// Get the default application for a file type.
    static func defaultApplication(for url: URL) -> URL? {
        return NSWorkspace.shared.urlForApplication(toOpen: url)
    }

    /// Open a file with a specific application.
    static func open(_ url: URL, withApplication appURL: URL) {
        NSWorkspace.shared.open([url], withApplicationAt: appURL, configuration: NSWorkspace.OpenConfiguration())
    }

    /// Get file type identifier for a URL.
    static func fileTypeIdentifier(for url: URL) -> String? {
        let resourceValues = try? url.resourceValues(forKeys: [.typeIdentifierKey])
        return resourceValues?.typeIdentifier
    }

    /// Get the file size in a human-readable format.
    static func fileSizeDescription(for url: URL) -> String? {
        let resourceValues = try? url.resourceValues(forKeys: [.fileSizeKey])
        guard let size = resourceValues?.fileSize else { return nil }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(size))
    }
}
#endif
