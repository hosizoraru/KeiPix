import Foundation

/// Provides data for WidgetKit widgets.
///
/// Shares artwork data between the main app and widget extension
/// via App Group UserDefaults. The widget reads this data to
/// display "Artwork of the Day" and download queue status.
enum WidgetDataProvider {
    static let appGroupIdentifier = "group.com.keipix"
    static let artworkKey = "widget.artwork"
    static let downloadStatsKey = "widget.downloadStats"

    /// Shared UserDefaults for the app group.
    private static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupIdentifier)
    }

    // MARK: - Artwork of the Day

    struct ArtworkSnapshot: Codable {
        let id: Int
        let title: String
        let creatorName: String
        let thumbnailURL: String?
        let pixivURL: String?
        let updatedAt: Date
    }

    /// Save the current artwork for the widget to display.
    static func saveArtwork(_ artwork: PixivArtwork) {
        guard let defaults = sharedDefaults else { return }
        let snapshot = ArtworkSnapshot(
            id: artwork.id,
            title: artwork.title,
            creatorName: artwork.user.name,
            thumbnailURL: artwork.thumbnailURL?.absoluteString,
            pixivURL: artwork.pixivURL?.absoluteString,
            updatedAt: Date()
        )
        if let data = try? JSONEncoder().encode(snapshot) {
            defaults.set(data, forKey: artworkKey)
        }
    }

    /// Load the saved artwork snapshot for the widget.
    static func loadArtwork() -> ArtworkSnapshot? {
        guard let defaults = sharedDefaults,
              let data = defaults.data(forKey: artworkKey) else {
            return nil
        }
        return try? JSONDecoder().decode(ArtworkSnapshot.self, from: data)
    }

    // MARK: - Download Stats

    struct DownloadStats: Codable {
        let totalDownloads: Int
        let completedDownloads: Int
        let activeDownloads: Int
        let updatedAt: Date
    }

    /// Save download statistics for the widget to display.
    static func saveDownloadStats(
        total: Int,
        completed: Int,
        active: Int
    ) {
        guard let defaults = sharedDefaults else { return }
        let stats = DownloadStats(
            totalDownloads: total,
            completedDownloads: completed,
            activeDownloads: active,
            updatedAt: Date()
        )
        if let data = try? JSONEncoder().encode(stats) {
            defaults.set(data, forKey: downloadStatsKey)
        }
    }

    /// Load the saved download stats for the widget.
    static func loadDownloadStats() -> DownloadStats? {
        guard let defaults = sharedDefaults,
              let data = defaults.data(forKey: downloadStatsKey) else {
            return nil
        }
        return try? JSONDecoder().decode(DownloadStats.self, from: data)
    }

    // MARK: - Update from Store

    /// Update widget data from the current store state.
    @MainActor
    static func updateFromStore(_ store: KeiPixStore) {
        // Save current artwork if available
        if let artwork = store.selectedArtwork {
            saveArtwork(artwork)
        }

        // Save download stats
        let downloads = store.downloads
        saveDownloadStats(
            total: downloads.items.count,
            completed: downloads.items.filter { $0.status == .completed }.count,
            active: downloads.activeCount
        )
    }
}
