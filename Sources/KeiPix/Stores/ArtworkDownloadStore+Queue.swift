import Foundation

@MainActor
extension ArtworkDownloadStore {
    @discardableResult
    func pauseQueue() -> Bool {
        guard isPaused == false, activeCount > 0 || isDownloading else { return false }
        isPaused = true
        UserDefaults.standard.set(true, forKey: "downloadQueuePaused")

        var changedItems = false
        for index in items.indices where items[index].status == .downloading {
            items[index].status = .queued
            items[index].errorMessage = nil
            items[index].updatedAt = Date()
            changedItems = true
        }
        if changedItems {
            persistItems()
        }

        workerTasks.values.forEach { $0.cancel() }
        return true
    }

    @discardableResult
    func resumeQueue(preferOriginal: Bool = true) -> Bool {
        let hadQueuedItems = items.contains { $0.status == .queued }
        guard isPaused || hadQueuedItems else { return false }
        isPaused = false
        UserDefaults.standard.set(false, forKey: "downloadQueuePaused")
        startWorkerIfNeeded(preferOriginal: preferOriginal)
        return hadQueuedItems
    }

    func setMaxConcurrentDownloads(_ count: Int) {
        let clampedCount = Self.clampedConcurrentDownloadCount(count)
        maxConcurrentDownloads = clampedCount
        UserDefaults.standard.set(clampedCount, forKey: "maxConcurrentDownloads")
        startWorkerIfNeeded(preferOriginal: true)
    }

    func enqueue(_ artwork: PixivArtwork, preferOriginal: Bool = true) {
        if let existingIndex = items.firstIndex(where: {
            $0.artworkID == artwork.id
                && $0.resolvedArtifactKind == .imagePages
                && $0.sourcePageIndexes == nil
                && ($0.status == .queued || $0.status == .downloading)
        }) {
            items[existingIndex].updatedAt = Date()
            persistItems()
            return
        }

        let sourceURLs = sourceImageURLs(for: artwork, preferOriginal: preferOriginal)
        let item = ArtworkDownloadItem(
            id: UUID(),
            artworkID: artwork.id,
            title: artwork.title,
            creatorName: artwork.user.name,
            creatorID: artwork.user.id,
            tags: artwork.tags.map(\.name),
            isAI: artwork.isAI,
            isR18: artwork.isR18,
            isR18G: artwork.isR18G,
            artifactKind: .imagePages,
            ugoiraFrameCount: nil,
            ugoiraFrames: nil,
            pageCount: sourceURLs.count,
            completedPages: 0,
            status: .queued,
            folderPath: nil,
            sourceImageURLs: sourceURLs,
            downloadedFilePaths: nil,
            errorMessage: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
        items.insert(item, at: 0)
        persistItems()
        startWorkerIfNeeded(preferOriginal: preferOriginal)
    }

    func enqueuePage(_ artwork: PixivArtwork, pageIndex: Int, preferOriginal: Bool = true) {
        let clampedPageIndex = min(max(pageIndex, 0), max(artwork.displayPageCount - 1, 0))
        guard let sourceURL = artwork.imageURL(at: clampedPageIndex, preferOriginal: preferOriginal) else { return }

        if let existingIndex = items.firstIndex(where: {
            $0.artworkID == artwork.id
                && $0.resolvedArtifactKind == .imagePages
                && $0.sourcePageIndexes == [clampedPageIndex]
                && ($0.status == .queued || $0.status == .downloading)
        }) {
            items[existingIndex].updatedAt = Date()
            persistItems()
            return
        }

        let item = ArtworkDownloadItem(
            id: UUID(),
            artworkID: artwork.id,
            title: artwork.title,
            creatorName: artwork.user.name,
            creatorID: artwork.user.id,
            tags: artwork.tags.map(\.name),
            isAI: artwork.isAI,
            isR18: artwork.isR18,
            isR18G: artwork.isR18G,
            artifactKind: .imagePages,
            ugoiraFrameCount: nil,
            ugoiraFrames: nil,
            pageCount: 1,
            completedPages: 0,
            status: .queued,
            folderPath: nil,
            sourceImageURLs: [sourceURL],
            sourcePageIndexes: [clampedPageIndex],
            sourceTotalPageCount: artwork.displayPageCount,
            downloadedFilePaths: nil,
            errorMessage: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
        items.insert(item, at: 0)
        persistItems()
        startWorkerIfNeeded(preferOriginal: preferOriginal)
    }

    @discardableResult
    func enqueue(_ artworks: [PixivArtwork], limit: Int, preferOriginal: Bool = true) -> Int {
        let existingArtworkIDs = Set(items.filter {
            $0.status != .failed && $0.resolvedArtifactKind == .imagePages && $0.sourcePageIndexes == nil
        }.map(\.artworkID))
        let candidates = artworks.prefix(max(limit, 0)).filter { existingArtworkIDs.contains($0.id) == false }
        guard candidates.isEmpty == false else { return 0 }

        let now = Date()
        let newItems = candidates.map { artwork in
            let sourceURLs = sourceImageURLs(for: artwork, preferOriginal: preferOriginal)
            return ArtworkDownloadItem(
                id: UUID(),
                artworkID: artwork.id,
                title: artwork.title,
                creatorName: artwork.user.name,
                creatorID: artwork.user.id,
                tags: artwork.tags.map(\.name),
                isAI: artwork.isAI,
                isR18: artwork.isR18,
                isR18G: artwork.isR18G,
                artifactKind: .imagePages,
                ugoiraFrameCount: nil,
                ugoiraFrames: nil,
                pageCount: sourceURLs.count,
                completedPages: 0,
                status: .queued,
                folderPath: nil,
                sourceImageURLs: sourceURLs,
                downloadedFilePaths: nil,
                errorMessage: nil,
                createdAt: now,
                updatedAt: now
            )
        }

        items.insert(contentsOf: newItems, at: 0)
        persistItems()
        startWorkerIfNeeded(preferOriginal: preferOriginal)
        return newItems.count
    }

    func enqueueUgoira(_ artwork: PixivArtwork, zipURL: URL, frames: [PixivUgoiraFrame]) {
        if let existingIndex = items.firstIndex(where: {
            $0.artworkID == artwork.id
                && $0.resolvedArtifactKind == .ugoiraZip
                && ($0.status == .queued || $0.status == .downloading)
        }) {
            items[existingIndex].updatedAt = Date()
            persistItems()
            return
        }

        let item = ArtworkDownloadItem(
            id: UUID(),
            artworkID: artwork.id,
            title: artwork.title,
            creatorName: artwork.user.name,
            creatorID: artwork.user.id,
            tags: artwork.tags.map(\.name),
            isAI: artwork.isAI,
            isR18: artwork.isR18,
            isR18G: artwork.isR18G,
            artifactKind: .ugoiraZip,
            ugoiraFrameCount: frames.count,
            ugoiraFrames: frames,
            pageCount: 1,
            completedPages: 0,
            status: .queued,
            folderPath: nil,
            sourceImageURLs: [zipURL],
            downloadedFilePaths: nil,
            errorMessage: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
        items.insert(item, at: 0)
        persistItems()
        startWorkerIfNeeded(preferOriginal: true)
    }

    func clearCompleted() {
        items.removeAll { $0.status == .completed }
        persistItems()
    }

    func setDownloadQueueFilter(_ filter: DownloadQueueFilter) {
        downloadQueueFilter = filter
        UserDefaults.standard.set(filter.rawValue, forKey: "downloadQueueFilter")
    }

    func setDownloadQueueSort(_ sort: DownloadQueueSort) {
        downloadQueueSort = sort
        UserDefaults.standard.set(sort.rawValue, forKey: "downloadQueueSort")
    }

    func setDownloadSearchText(_ text: String) {
        downloadSearchText = text
    }

    @discardableResult
    func retryFailedFilteredItems() -> Int {
        let ids = Set(filteredItems.filter {
            $0.status == .failed && $0.sourceImageURLs?.isEmpty == false
        }.map(\.id))
        guard ids.isEmpty == false else { return 0 }

        for index in items.indices where ids.contains(items[index].id) {
            resetFailedItem(at: index)
        }
        persistItems()
        startWorkerIfNeeded(preferOriginal: true)
        return ids.count
    }

    @discardableResult
    func clearFailedFilteredItems() -> Int {
        let failedItems = filteredItems.filter { $0.status == .failed }
        guard failedItems.isEmpty == false else { return 0 }

        let ids = Set(failedItems.map(\.id))
        items.removeAll { ids.contains($0.id) }
        persistItems()
        return ids.count
    }

    @discardableResult
    func clearInvalidItems() -> Int {
        let initialCount = items.count
        items.removeAll { item in
            item.status == .completed && hasReadableDownload(for: item) == false
        }
        persistItems()
        return initialCount - items.count
    }

    @discardableResult
    func retry(_ item: ArtworkDownloadItem) -> Bool {
        guard let index = items.firstIndex(where: { $0.id == item.id }),
              items[index].status == .failed,
              items[index].sourceImageURLs?.isEmpty == false else {
            return false
        }
        resetFailedItem(at: index)
        persistItems()
        startWorkerIfNeeded(preferOriginal: true)
        return true
    }

    func delete(_ item: ArtworkDownloadItem) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items.remove(at: index)
        }
        persistItems()
    }

    @discardableResult
    func cancel(_ item: ArtworkDownloadItem) -> ArtworkDownloadItem? {
        guard item.status == .queued || item.status == .downloading,
              let index = items.firstIndex(where: { $0.id == item.id }) else {
            return nil
        }

        let removedItem = items.remove(at: index)
        cancelWorkers(for: Set([removedItem.id]))
        persistItems()
        return restorableCancelledItem(removedItem)
    }

    func restoreItems(_ restoredItems: [ArtworkDownloadItem]) {
        guard restoredItems.isEmpty == false else { return }
        let restoredIDs = Set(restoredItems.map(\.id))
        items.removeAll { restoredIDs.contains($0.id) }
        items.insert(contentsOf: restoredItems, at: 0)
        persistItems()
    }

    @discardableResult
    func deleteFilteredItems() -> Int {
        let targets = filteredItems.filter { $0.status != .downloading }
        guard targets.isEmpty == false else { return 0 }

        let ids = Set(targets.map(\.id))
        items.removeAll { ids.contains($0.id) }
        persistItems()
        return targets.count
    }

    @discardableResult
    func cancelFilteredActiveItems() -> [ArtworkDownloadItem] {
        let targets = filteredItems.filter { $0.status == .queued || $0.status == .downloading }
        guard targets.isEmpty == false else { return [] }

        let ids = Set(targets.map(\.id))
        items.removeAll { ids.contains($0.id) }
        cancelWorkers(for: ids)
        persistItems()
        return targets.map(restorableCancelledItem)
    }

    private func resetFailedItem(at index: Int) {
        items[index].status = .queued
        items[index].completedPages = 0
        items[index].folderPath = nil
        items[index].downloadedFilePaths = nil
        items[index].errorMessage = nil
        items[index].updatedAt = Date()
    }
}
