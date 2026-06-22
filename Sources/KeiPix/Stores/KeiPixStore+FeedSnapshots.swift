import Foundation

@MainActor
extension KeiPixStore {
    func storeFeedSnapshot(_ response: PixivFeedResponse, for context: FeedRequestContext) {
        let artworks = ArtworkFeedDeduplication.unique(response.illusts)
        guard artworks.isEmpty == false else { return }
        feedSnapshotLibrary.store(
            FeedSnapshot(
                key: context.snapshotKey,
                routeRawValue: context.route.rawValue,
                title: context.snapshotTitle,
                savedAt: Date(),
                artworks: artworks,
                nextURL: response.nextURL
            )
        )
        routeActivationFreshSnapshotKeys.insert(context.snapshotKey)
        saveFeedSnapshotLibrary()
    }

    func restoreFeedSnapshotForRouteActivation(_ snapshot: FeedSnapshot) {
        allArtworks = ArtworkFeedDeduplication.unique(snapshot.artworks)
        nextURL = snapshot.nextURL
        applyContentFilters()
        activeFeedSnapshotRestoration = nil
        errorMessage = nil
    }

    @discardableResult
    func restoreFeedSnapshot(for context: FeedRequestContext, error: Error) -> Bool {
        guard let snapshot = feedSnapshotLibrary.snapshot(for: context.snapshotKey),
              snapshot.artworks.isEmpty == false else {
            return false
        }
        allArtworks = ArtworkFeedDeduplication.unique(snapshot.artworks)
        nextURL = snapshot.nextURL
        applyContentFilters()
        let restoredSnapshot = FeedSnapshot(
            key: snapshot.key,
            routeRawValue: snapshot.routeRawValue,
            title: snapshot.title,
            savedAt: snapshot.savedAt,
            artworks: allArtworks,
            nextURL: snapshot.nextURL
        )
        activeFeedSnapshotRestoration = FeedSnapshotRestoration(snapshot: restoredSnapshot, error: error)
        errorMessage = String(
            format: L10n.loadedCachedFeedFormat,
            snapshot.title,
            allArtworks.count,
            error.localizedDescription
        )
        return true
    }

    var feedSnapshotCount: Int {
        feedSnapshotLibrary.snapshots.count
    }

    static func loadFeedSnapshotLibrary() -> FeedSnapshotLibrary {
        guard let data = UserDefaults.standard.data(forKey: "feedSnapshotLibrary") else {
            return FeedSnapshotLibrary()
        }
        return (try? JSONDecoder().decode(FeedSnapshotLibrary.self, from: data)) ?? FeedSnapshotLibrary()
    }

    private func saveFeedSnapshotLibrary() {
        guard let data = try? JSONEncoder().encode(feedSnapshotLibrary) else { return }
        UserDefaults.standard.set(data, forKey: "feedSnapshotLibrary")
    }
}

extension FeedRequestContext {
    var snapshotKey: String {
        [
            route.rawValue,
            focusedUserID.map(String.init) ?? "",
            searchText,
            bookmarkTagFilter ?? "",
            bookmarkFeedOptions.sort.rawValue,
            bookmarkFeedOptions.ageLimit.rawValue,
            bookmarkFeedOptions.normalizedArtworkTagFilter ?? "",
            creatorArtworkTagFilter?.snapshotKey ?? "",
            pixivCollectionID ?? "",
            useRankingDate ? "\(rankingDate.timeIntervalSince1970)" : "",
            searchOptions.matchType.rawValue,
            searchOptions.sort.rawValue,
            searchOptions.ageLimit.rawValue,
            searchOptions.dateRange.rawValue,
            String(searchOptions.minimumBookmarks.value),
            String(searchOptions.maximumBookmarks.value),
            searchOptions.artworkType.rawValue,
            searchOptions.aiFilter.rawValue,
            searchOptions.ugoiraFilter.rawValue
        ]
        .joined(separator: "|")
    }

    var snapshotTitle: String {
        if searchText.isEmpty == false {
            return "\(route.title) · \(searchText)"
        }
        if let bookmarkTagFilter {
            return "\(route.title) · #\(bookmarkTagFilter)"
        }
        if let creatorArtworkTagFilter {
            return "\(route.title) · #\(creatorArtworkTagFilter.tag)"
        }
        if let pixivCollectionID {
            return "\(route.title) · \(pixivCollectionID)"
        }
        return route.title
    }
}
