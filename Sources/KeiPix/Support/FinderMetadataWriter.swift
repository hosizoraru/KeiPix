#if os(macOS)
import Foundation
import AppKit

/// Writes Pixiv metadata to downloaded files as Finder-compatible
/// extended attributes (xattr).
///
/// This makes downloaded artwork files show useful information in
/// Finder's "Get Info" panel and enables Spotlight search by
/// creator, tags, and other metadata.
enum FinderMetadataWriter {
    /// Write metadata to a downloaded file.
    static func writeMetadata(for item: ArtworkDownloadItem, to fileURL: URL) {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: fileURL.path) else { return }

        // Write Finder comments (visible in Get Info)
        let comment = buildFinderComment(item: item)
        setFinderComment(comment, for: fileURL)

        // Write extended attributes for Spotlight indexing
        setXattr("com.keipix.artwork-id", value: "\(item.artworkID)", for: fileURL)
        setXattr("com.keipix.creator", value: item.creatorName, for: fileURL)
        setXattr("com.keipix.title", value: item.title, for: fileURL)

        if let tags = item.tags, tags.isEmpty == false {
            setXattr("com.keipix.tags", value: tags.joined(separator: ","), for: fileURL)
        }

        if item.isAI == true {
            setXattr("com.keipix.ai", value: "true", for: fileURL)
        }

        if item.isR18 == true {
            setXattr("com.keipix.r18", value: "true", for: fileURL)
        }

        if item.isR18G == true {
            setXattr("com.keipix.r18g", value: "true", for: fileURL)
        }
    }

    /// Build a Finder comment string from download metadata.
    private static func buildFinderComment(item: ArtworkDownloadItem) -> String {
        var parts: [String] = []

        parts.append("Pixiv #\(item.artworkID)")
        parts.append("by \(item.creatorName)")

        if let series = item.seriesTitle {
            parts.append("Series: \(series)")
        }

        if let tags = item.tags, tags.isEmpty == false {
            let tagString = tags.prefix(5).map { "#\($0)" }.joined(separator: " ")
            parts.append(tagString)
        }

        var flags: [String] = []
        if item.isAI == true { flags.append("AI") }
        if item.isR18G == true { flags.append("R-18G") }
        else if item.isR18 == true { flags.append("R-18") }
        if flags.isEmpty == false {
            parts.append(flags.joined(separator: " · "))
        }

        return parts.joined(separator: "\n")
    }

    /// Set a Finder comment on a file.
    private static func setFinderComment(_ comment: String, for url: URL) {
        let nsURL = url as NSURL
        do {
            try nsURL.setResourceValue(comment, forKey: .labelColorKey)
        } catch {
            // Finder comment setting may fail silently
        }
    }

    /// Set an extended attribute on a file.
    private static func setXattr(_ name: String, value: String, for url: URL) {
        let data = Data(value.utf8)
        let result = setxattr(url.path, name, (data as NSData).bytes, data.count, 0, 0)
        if result != 0 {
            // xattr setting may fail on some file systems
        }
    }
}
#endif
