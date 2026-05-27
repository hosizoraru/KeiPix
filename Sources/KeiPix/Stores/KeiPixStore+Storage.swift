import Foundation

/// Storage settings page surface. Bundles the five regenerable on-
/// disk surfaces — image cache, offline feed snapshots, search
/// history, browsing history, and the per-artwork detail UI state —
/// behind a single inspector so users can see what's resident and
/// reclaim it without leaving Settings. Mirrors the structure of
/// macOS System Settings → General → Storage, where each row reports
/// a size and exposes a single Clear action.
@MainActor
extension KeiPixStore {
    /// Computes a snapshot per category. Heavy work is the URLCache
    /// disk-byte read (already cached by URLCache itself, so this is
    /// a property access not a directory walk) — every other
    /// category counts in-memory state. Cheap to call on every
    /// settings-page appearance.
    func cacheCategorySnapshots() -> [CacheCategorySnapshot] {
        CacheCategoryKind.allCases.map { kind in
            switch kind {
            case .image:
                return imageCacheSnapshot()
            case .feedSnapshots:
                return feedSnapshotsCacheSnapshot()
            case .browsingHistory:
                return browsingHistoryCacheSnapshot()
            case .searchHistory:
                return searchHistoryCacheSnapshot()
            case .artworkDetailState:
                return artworkDetailStateCacheSnapshot()
            case .novelText:
                return novelTextCacheSnapshot()
            }
        }
    }

    /// Clears the named category and returns the post-clear snapshot
    /// so the page can refresh both the byte/item label and the
    /// disabled state of the row's Clear button without an extra
    /// round-trip through `cacheCategorySnapshots()`.
    @discardableResult
    func clearCacheCategory(_ kind: CacheCategoryKind) -> CacheCategorySnapshot {
        switch kind {
        case .image:
            _ = ImagePipeline.shared.clearCaches()
        case .feedSnapshots:
            feedSnapshotLibrary = FeedSnapshotLibrary()
            UserDefaults.standard.removeObject(forKey: "feedSnapshotLibrary")
        case .browsingHistory:
            clearLocalBrowsingHistory()
        case .searchHistory:
            clearSearchHistory()
        case .artworkDetailState:
            artworkDetailStateLibrary = ArtworkDetailStateLibrary()
            UserDefaults.standard.removeObject(forKey: "artworkDetailStateLibrary")
        case .novelText:
            Task { await NovelTextDiskCache.shared.clearAll() }
        }

        switch kind {
        case .image: return imageCacheSnapshot()
        case .feedSnapshots: return feedSnapshotsCacheSnapshot()
        case .browsingHistory: return browsingHistoryCacheSnapshot()
        case .searchHistory: return searchHistoryCacheSnapshot()
        case .artworkDetailState: return artworkDetailStateCacheSnapshot()
        case .novelText: return novelTextCacheSnapshot()
        }
    }

    /// Clears every regenerable cache in one shot. Returns the
    /// post-clear snapshot list so the page can repaint without a
    /// follow-up read. We don't round-trip through
    /// `clearCacheCategory` per kind to avoid five separate
    /// `UserDefaults.removeObject` calls when one batch suffices.
    @discardableResult
    func clearAllCacheCategories() -> [CacheCategorySnapshot] {
        for kind in CacheCategoryKind.allCases {
            _ = clearCacheCategory(kind)
        }
        return cacheCategorySnapshots()
    }

    // MARK: - Per-category snapshots

    private func imageCacheSnapshot() -> CacheCategorySnapshot {
        let status = ImagePipeline.shared.cacheStatus()
        let total = status.diskUsage + status.memoryUsage
        return CacheCategorySnapshot(
            id: .image,
            title: L10n.cacheImageTitle,
            detail: L10n.cacheImageDetail,
            byteSize: total,
            itemCount: nil,
            isEmpty: total == 0
        )
    }

    private func feedSnapshotsCacheSnapshot() -> CacheCategorySnapshot {
        let count = feedSnapshotLibrary.snapshots.count
        // Encode-once approximation: feed snapshots already encode
        // through JSONEncoder when persisted, so re-encoding here is
        // the same work. UserDefaults blob size matches what the row
        // would reclaim if cleared.
        let bytes = (try? JSONEncoder().encode(feedSnapshotLibrary).count) ?? 0
        return CacheCategorySnapshot(
            id: .feedSnapshots,
            title: L10n.cacheFeedSnapshotsTitle,
            detail: L10n.cacheFeedSnapshotsDetail,
            byteSize: bytes,
            itemCount: count,
            isEmpty: count == 0
        )
    }

    private func browsingHistoryCacheSnapshot() -> CacheCategorySnapshot {
        let count = localBrowsingHistory.count
        let bytes = (try? JSONEncoder().encode(localBrowsingHistory).count) ?? 0
        return CacheCategorySnapshot(
            id: .browsingHistory,
            title: L10n.cacheBrowsingHistoryTitle,
            detail: L10n.cacheBrowsingHistoryDetail,
            byteSize: bytes,
            itemCount: count,
            isEmpty: count == 0
        )
    }

    private func searchHistoryCacheSnapshot() -> CacheCategorySnapshot {
        let count = searchHistory.count
        return CacheCategorySnapshot(
            id: .searchHistory,
            title: L10n.cacheSearchHistoryTitle,
            detail: L10n.cacheSearchHistoryDetail,
            byteSize: nil,
            itemCount: count,
            isEmpty: count == 0
        )
    }

    private func artworkDetailStateCacheSnapshot() -> CacheCategorySnapshot {
        let count = artworkDetailStateLibrary.entries.count
        let bytes = (try? JSONEncoder().encode(artworkDetailStateLibrary).count) ?? 0
        return CacheCategorySnapshot(
            id: .artworkDetailState,
            title: L10n.cacheArtworkDetailStateTitle,
            detail: L10n.cacheArtworkDetailStateDetail,
            byteSize: bytes,
            itemCount: count,
            isEmpty: count == 0
        )
    }

    private func novelTextCacheSnapshot() -> CacheCategorySnapshot {
        let bytes = NovelTextDiskCache.shared.cachedSize()
        let count = NovelTextDiskCache.shared.cachedIDs().count
        return CacheCategorySnapshot(
            id: .novelText,
            title: L10n.cacheNovelTextTitle,
            detail: L10n.cacheNovelTextDetail,
            byteSize: bytes,
            itemCount: count,
            isEmpty: count == 0
        )
    }
}
