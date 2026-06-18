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
        queueWakeTask?.cancel()
        queueWakeTask = nil
        // Pausing should clear the speedometer right away — the
        // sliding window would otherwise keep showing the last
        // pre-pause sample for ~8 seconds.
        throughputSampler.resetAll()
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

    /// Updates the "notify when downloads finish" preference and lazily
    /// asks Notification Center for authorization the first time the
    /// user opts in. Returns the resolved authorization state so the
    /// settings page can flash a hint when macOS denied the prompt;
    /// the toggle itself is kept in sync with whatever the user picked
    /// regardless, so they can flip it off again without bouncing
    /// through System Settings.
    @discardableResult
    func setNotifyOnDownloadFinish(_ value: Bool) async -> Bool {
        notifyOnDownloadFinish = value
        UserDefaults.standard.set(value, forKey: "notifyOnDownloadFinish")
        if value == false {
            // Drop any debounced banner — turning the toggle off mid-
            // window otherwise lets a stray banner slip through after
            // the user said no.
            completionNotifier.flushBuffer()
            return true
        }
        return await completionNotifier.requestAuthorizationIfNeeded()
    }

    func enqueue(_ artwork: PixivArtwork, preferOriginal: Bool = true) {
        enqueue(artwork, tier: .legacy(preferOriginal: preferOriginal))
    }

    func enqueue(_ artwork: PixivArtwork, tier: ArtworkImageQualityTier) {
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

        let sourceURLs = sourceImageURLs(for: artwork, tier: tier)
        let item = ArtworkDownloadItem(
            id: UUID(),
            artworkID: artwork.id,
            title: artwork.title,
            creatorName: artwork.user.name,
            creatorID: artwork.user.id,
            seriesTitle: artwork.series?.title,
            seriesID: artwork.series?.id,
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
        startWorkerIfNeeded(preferOriginal: tier.prefersOriginal)
    }

    func enqueuePage(_ artwork: PixivArtwork, pageIndex: Int, preferOriginal: Bool = true) {
        enqueuePage(artwork, pageIndex: pageIndex, tier: .legacy(preferOriginal: preferOriginal))
    }

    func enqueuePage(_ artwork: PixivArtwork, pageIndex: Int, tier: ArtworkImageQualityTier) {
        let clampedPageIndex = min(max(pageIndex, 0), max(artwork.displayPageCount - 1, 0))
        guard let sourceURL = artwork.imageURL(at: clampedPageIndex, tier: tier) else { return }

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
            seriesTitle: artwork.series?.title,
            seriesID: artwork.series?.id,
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
        startWorkerIfNeeded(preferOriginal: tier.prefersOriginal)
    }

    @discardableResult
    func enqueuePages(_ artwork: PixivArtwork, pageRange: ClosedRange<Int>, preferOriginal: Bool = true) -> Int {
        enqueuePages(artwork, pageIndexes: Array(pageRange), preferOriginal: preferOriginal)
    }

    @discardableResult
    func enqueuePages(_ artwork: PixivArtwork, pageRange: ClosedRange<Int>, tier: ArtworkImageQualityTier) -> Int {
        enqueuePages(artwork, pageIndexes: Array(pageRange), tier: tier)
    }

    /// Queues an arbitrary subset of pages from a multi-page artwork.
    ///
    /// Mirrors `enqueuePages(_:pageRange:)` but accepts a non-contiguous
    /// set of indexes so the selective-save sheet can hand over whichever
    /// pages the user ticked. Indexes are clamped, deduped and sorted
    /// before being enqueued, so callers can pass anything resembling a
    /// page list without first sanitising it.
    @discardableResult
    func enqueuePages(_ artwork: PixivArtwork, pageIndexes: [Int], preferOriginal: Bool = true) -> Int {
        enqueuePages(artwork, pageIndexes: pageIndexes, tier: .legacy(preferOriginal: preferOriginal))
    }

    @discardableResult
    func enqueuePages(_ artwork: PixivArtwork, pageIndexes: [Int], tier: ArtworkImageQualityTier) -> Int {
        let displayPageCount = max(artwork.displayPageCount, 1)
        let normalized = Array(Set(pageIndexes.map { min(max($0, 0), displayPageCount - 1) })).sorted()
        guard normalized.isEmpty == false else { return 0 }

        let sourcePairs = normalized.compactMap { pageIndex -> (Int, URL)? in
            guard let sourceURL = artwork.imageURL(at: pageIndex, tier: tier) else { return nil }
            return (pageIndex, sourceURL)
        }
        guard sourcePairs.isEmpty == false else { return 0 }

        let sourcePageIndexes = sourcePairs.map(\.0)
        if let existingIndex = items.firstIndex(where: {
            $0.artworkID == artwork.id
                && $0.resolvedArtifactKind == .imagePages
                && $0.sourcePageIndexes == sourcePageIndexes
                && ($0.status == .queued || $0.status == .downloading)
        }) {
            items[existingIndex].updatedAt = Date()
            persistItems()
            return 0
        }

        let item = ArtworkDownloadItem(
            id: UUID(),
            artworkID: artwork.id,
            title: artwork.title,
            creatorName: artwork.user.name,
            creatorID: artwork.user.id,
            seriesTitle: artwork.series?.title,
            seriesID: artwork.series?.id,
            tags: artwork.tags.map(\.name),
            isAI: artwork.isAI,
            isR18: artwork.isR18,
            isR18G: artwork.isR18G,
            artifactKind: .imagePages,
            ugoiraFrameCount: nil,
            ugoiraFrames: nil,
            pageCount: sourcePairs.count,
            completedPages: 0,
            status: .queued,
            folderPath: nil,
            sourceImageURLs: sourcePairs.map(\.1),
            sourcePageIndexes: sourcePageIndexes,
            sourceTotalPageCount: displayPageCount,
            downloadedFilePaths: nil,
            errorMessage: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
        items.insert(item, at: 0)
        persistItems()
        startWorkerIfNeeded(preferOriginal: tier.prefersOriginal)
        return sourcePairs.count
    }

    @discardableResult
    func enqueue(_ artworks: [PixivArtwork], limit: Int, preferOriginal: Bool = true) -> Int {
        enqueue(artworks, limit: limit, tier: .legacy(preferOriginal: preferOriginal))
    }

    @discardableResult
    func enqueue(_ artworks: [PixivArtwork], limit: Int, tier: ArtworkImageQualityTier) -> Int {
        enqueue(artworks, limit: limit) { _ in tier }
    }

    @discardableResult
    func enqueue(
        _ artworks: [PixivArtwork],
        limit: Int,
        tierForArtwork: (PixivArtwork) -> ArtworkImageQualityTier
    ) -> Int {
        let existingArtworkIDs = Set(items.filter {
            $0.status != .failed && $0.resolvedArtifactKind == .imagePages && $0.sourcePageIndexes == nil
        }.map(\.artworkID))
        let candidates = artworks.prefix(max(limit, 0)).filter { existingArtworkIDs.contains($0.id) == false }
        guard candidates.isEmpty == false else { return 0 }

        let now = Date()
        let tieredCandidates = candidates.map { artwork in
            (artwork: artwork, tier: tierForArtwork(artwork))
        }
        let newItems = tieredCandidates.map { candidate in
            let artwork = candidate.artwork
            let tier = candidate.tier
            let sourceURLs = sourceImageURLs(for: artwork, tier: tier)
            return ArtworkDownloadItem(
                id: UUID(),
                artworkID: artwork.id,
                title: artwork.title,
                creatorName: artwork.user.name,
                creatorID: artwork.user.id,
                seriesTitle: artwork.series?.title,
                seriesID: artwork.series?.id,
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
        startWorkerIfNeeded(preferOriginal: tieredCandidates.contains { $0.tier.prefersOriginal })
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
            seriesTitle: artwork.series?.title,
            seriesID: artwork.series?.id,
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
        let removed = items.filter { $0.status == .completed }.map(\.artworkID)
        items.removeAll { $0.status == .completed }
        spotlightSink?.didRemoveArtworkIDs(removed)
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
        let retryableItems = filteredItems.filter {
            $0.status == .failed && $0.sourceImageURLs?.isEmpty == false
        }
        let ids = Set(retryableItems.map(\.id))
        guard ids.isEmpty == false else { return 0 }

        let now = Date()
        for (retryIndex, item) in retryableItems.enumerated() {
            guard let index = items.firstIndex(where: { $0.id == item.id }) else { continue }
            let retryDate = now.addingTimeInterval(DownloadRetryBackoff.delay(forRetryIndex: retryIndex))
            resetFailedItem(at: index, queuedAfter: retryDate)
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
        let removed = items.filter { item in
            item.status == .completed && hasReadableDownload(for: item) == false
        }.map(\.artworkID)
        items.removeAll { item in
            item.status == .completed && hasReadableDownload(for: item) == false
        }
        spotlightSink?.didRemoveArtworkIDs(removed)
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
        throughputSampler.reset(itemID: item.id)
        spotlightSink?.didRemoveArtworkIDs([item.artworkID])
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
        throughputSampler.reset(itemID: removedItem.id)
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
        let removedArtworkIDs = targets.map(\.artworkID)
        items.removeAll { ids.contains($0.id) }
        for id in ids {
            throughputSampler.reset(itemID: id)
        }
        spotlightSink?.didRemoveArtworkIDs(removedArtworkIDs)
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
        for id in ids {
            throughputSampler.reset(itemID: id)
        }
        persistItems()
        return targets.map(restorableCancelledItem)
    }

    private func resetFailedItem(at index: Int, queuedAfter: Date? = nil) {
        items[index].status = .queued
        items[index].completedPages = 0
        items[index].folderPath = nil
        items[index].downloadedFilePaths = nil
        items[index].queuedAfter = queuedAfter
        items[index].errorMessage = nil
        items[index].updatedAt = Date()
    }
}
