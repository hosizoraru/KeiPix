import Foundation

/// Single-file backup of every locally-persisted library KeiPix
/// owns. Designed for users moving to a new Mac, or rolling back
/// a botched experiment without losing months of saved searches,
/// pinned creators, or reader progress. Mirrors what System
/// Migration Assistant would copy if the app participated, but
/// keeps the format file-portable so a JSON exporter is enough.
///
/// The shape is additive on import: each section is restored via
/// the same `restoreX(_:)` helpers `KeiPixStore` already exposes
/// for danger-action undo. That means importing twice is harmless
/// (duplicates are deduped) and partial archives — produced by
/// older builds — apply cleanly without overwriting bits the user
/// hasn't seen yet.
///
/// Schema versioning is explicit so a future incompatible change
/// can refuse the import politely instead of silently dropping
/// fields. `currentSchemaVersion` bumps any time we add a section
/// or change a wire shape that older builds shouldn't try to
/// decode.
struct KeiPixBackupArchive: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int
    var exportedAt: Date
    var appVersion: String?
    var savedSearches: SavedSearchLibraryExport?
    var localBrowsingHistory: [LocalArtworkHistoryItem]
    var pinnedCreators: PinnedCreatorLibrary
    var pinnedBookmarkTags: [String]
    var readerProgress: ArtworkReaderProgressLibrary
    var downloadedReaderProgress: DownloadedArtworkReaderProgressLibrary
    var mangaWatchlistReadState: MangaWatchlistReadStateLibrary
    var artworkDetailState: ArtworkDetailStateLibrary
    var mutedContent: MutedContentArchive?
    var preferences: PreferenceSnapshot

    init(
        schemaVersion: Int = KeiPixBackupArchive.currentSchemaVersion,
        exportedAt: Date,
        appVersion: String? = nil,
        savedSearches: SavedSearchLibraryExport? = nil,
        localBrowsingHistory: [LocalArtworkHistoryItem] = [],
        pinnedCreators: PinnedCreatorLibrary = PinnedCreatorLibrary(),
        pinnedBookmarkTags: [String] = [],
        readerProgress: ArtworkReaderProgressLibrary = ArtworkReaderProgressLibrary(),
        downloadedReaderProgress: DownloadedArtworkReaderProgressLibrary = DownloadedArtworkReaderProgressLibrary(),
        mangaWatchlistReadState: MangaWatchlistReadStateLibrary = MangaWatchlistReadStateLibrary(),
        artworkDetailState: ArtworkDetailStateLibrary = ArtworkDetailStateLibrary(),
        mutedContent: MutedContentArchive? = nil,
        preferences: PreferenceSnapshot = PreferenceSnapshot()
    ) {
        self.schemaVersion = schemaVersion
        self.exportedAt = exportedAt
        self.appVersion = appVersion
        self.savedSearches = savedSearches
        self.localBrowsingHistory = localBrowsingHistory
        self.pinnedCreators = pinnedCreators
        self.pinnedBookmarkTags = pinnedBookmarkTags
        self.readerProgress = readerProgress
        self.downloadedReaderProgress = downloadedReaderProgress
        self.mangaWatchlistReadState = mangaWatchlistReadState
        self.artworkDetailState = artworkDetailState
        self.mutedContent = mutedContent
        self.preferences = preferences
    }

    /// Curated preference slice. We deliberately ship a *small*
    /// set of toggles users would notice missing on a new Mac —
    /// content filters, bookmark/follow defaults, and the copy
    /// templates they hand-crafted. Volatile bits (last route,
    /// scroll positions, the last-checked release tag) are left
    /// out so an import doesn't surprise the recipient with old
    /// session state.
    struct PreferenceSnapshot: Codable, Equatable, Sendable {
        var defaultBookmarkRestrict: String?
        var defaultIllustrationBookmarkRestrict: String?
        var defaultMangaBookmarkRestrict: String?
        var defaultNovelBookmarkRestrict: String?
        var defaultFollowRestrict: String?
        var followCreatorAfterBookmark: Bool?
        var autoDownloadBookmarkedArtworks: Bool?
        var autoBookmarkDownloadedArtworks: Bool?
        var autoTagBookmarksWithArtworkTags: Bool?
        var artworkCopyTemplate: String?
        var creatorCopyTemplate: String?
        var hideAIArtworks: Bool?
        var hideR18Artworks: Bool?
        var hideR18GArtworks: Bool?
        var hideMutedContent: Bool?
        var maskSensitivePreviews: Bool?
        var showContentBadges: Bool?
    }
}

/// Summary returned to the UI after a successful import so the
/// user sees how many entries actually moved over (matching the
/// pattern `SavedSearchLibraryImportSummary` already establishes).
struct KeiPixBackupImportSummary: Equatable, Sendable {
    let savedSearchPresetCount: Int
    let savedSearchCount: Int
    let searchHistoryCount: Int
    let browsingHistoryCount: Int
    let pinnedCreatorCount: Int
    let pinnedBookmarkTagCount: Int
    let readerProgressCount: Int
    let downloadedReaderProgressCount: Int
    let mangaWatchlistCount: Int
    let artworkDetailStateCount: Int
    let mutedTotalCount: Int
    let preferenceFieldCount: Int

    var totalCount: Int {
        savedSearchPresetCount
            + savedSearchCount
            + searchHistoryCount
            + browsingHistoryCount
            + pinnedCreatorCount
            + pinnedBookmarkTagCount
            + readerProgressCount
            + downloadedReaderProgressCount
            + mangaWatchlistCount
            + artworkDetailStateCount
            + mutedTotalCount
            + preferenceFieldCount
    }
}

/// Errors the backup pipeline can raise. Rendered in the Storage
/// page so a user gets a helpful message instead of a stack trace
/// when their archive is from a future build or wasn't a valid
/// JSON file in the first place.
enum KeiPixBackupError: Error, Equatable, Sendable {
    case unsupportedSchemaVersion(found: Int, supported: Int)
    case decodingFailed(message: String)

    var localizedMessage: String {
        switch self {
        case .unsupportedSchemaVersion(let found, let supported):
            return String(
                format: L10n.backupUnsupportedSchemaFormat,
                found,
                supported
            )
        case .decodingFailed(let message):
            return String(format: L10n.backupDecodingFailedFormat, message)
        }
    }
}
