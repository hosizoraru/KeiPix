import Foundation
#if canImport(SwiftData)
import SwiftData

/// SwiftData models for persistent storage.
///
/// These models replace UserDefaults JSON blobs with proper
/// database-backed persistence for better query performance
/// and relationship modeling.

// MARK: - Browsing History

@Model
final class BrowsingHistoryEntry {
    var artworkID: Int
    var title: String
    var creatorName: String
    var thumbnailURL: String?
    var viewedAt: Date
    var route: String

    init(artworkID: Int, title: String, creatorName: String, thumbnailURL: String?, route: String) {
        self.artworkID = artworkID
        self.title = title
        self.creatorName = creatorName
        self.thumbnailURL = thumbnailURL
        self.viewedAt = Date()
        self.route = route
    }
}

// MARK: - Download History

@Model
final class DownloadHistoryEntry {
    var artworkID: Int
    var title: String
    var creatorName: String
    var pageCount: Int
    var downloadedAt: Date
    var filePath: String?
    var fileSize: Int64

    init(artworkID: Int, title: String, creatorName: String, pageCount: Int) {
        self.artworkID = artworkID
        self.title = title
        self.creatorName = creatorName
        self.pageCount = pageCount
        self.downloadedAt = Date()
        self.fileSize = 0
    }
}

// MARK: - Bookmarks

@Model
final class BookmarkEntry {
    var artworkID: Int
    var title: String
    var creatorName: String
    var tags: [String]
    var bookmarkedAt: Date
    var restrict: String

    init(artworkID: Int, title: String, creatorName: String, tags: [String], restrict: String) {
        self.artworkID = artworkID
        self.title = title
        self.creatorName = creatorName
        self.tags = tags
        self.bookmarkedAt = Date()
        self.restrict = restrict
    }
}

// MARK: - Watch Later

@Model
final class WatchLaterEntry {
    var artworkID: Int
    var title: String
    var creatorName: String
    var thumbnailURL: String?
    var addedAt: Date

    init(artworkID: Int, title: String, creatorName: String, thumbnailURL: String?) {
        self.artworkID = artworkID
        self.title = title
        self.creatorName = creatorName
        self.thumbnailURL = thumbnailURL
        self.addedAt = Date()
    }
}

// MARK: - Manga Watchlist

@Model
final class MangaWatchlistEntry {
    var seriesID: Int
    var seriesTitle: String
    var creatorName: String
    var lastReadChapter: Int
    var totalChapters: Int
    var addedAt: Date
    var lastReadAt: Date?

    init(seriesID: Int, seriesTitle: String, creatorName: String, totalChapters: Int) {
        self.seriesID = seriesID
        self.seriesTitle = seriesTitle
        self.creatorName = creatorName
        self.totalChapters = totalChapters
        self.lastReadChapter = 0
        self.addedAt = Date()
    }
}

// MARK: - Saved Searches

@Model
final class SavedSearchEntry {
    var keyword: String
    var options: Data // Encoded SearchOptions
    var savedAt: Date

    init(keyword: String, options: Data) {
        self.keyword = keyword
        self.options = options
        self.savedAt = Date()
    }
}

// MARK: - Model Container

/// Shared SwiftData model container.
extension KeiPixStore {
    static var modelContainer: ModelContainer {
        let schema = Schema([
            BrowsingHistoryEntry.self,
            DownloadHistoryEntry.self,
            BookmarkEntry.self,
            WatchLaterEntry.self,
            MangaWatchlistEntry.self,
            SavedSearchEntry.self
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        return try! ModelContainer(for: schema, configurations: [config])
    }
}
#else
// SwiftData not available on this platform
extension KeiPixStore {
    static var modelContainer: Any? { nil }
}
#endif
