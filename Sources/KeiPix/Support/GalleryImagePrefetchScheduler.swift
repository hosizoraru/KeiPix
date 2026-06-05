import Foundation

actor GalleryImagePrefetchScheduler {
    private var pendingURLs: [URL] = []
    private var pendingURLSet = Set<URL>()
    private var flushTask: Task<Void, Never>?

    func enqueue(_ urls: [URL]) {
        for url in urls where pendingURLs.count < GalleryImagePrefetchPolicy.pendingURLLimit {
            guard pendingURLSet.insert(url).inserted else { continue }
            pendingURLs.append(url)
        }
        scheduleFlushIfNeeded()
    }

    func cancel() {
        flushTask?.cancel()
        flushTask = nil
        pendingURLs.removeAll(keepingCapacity: true)
        pendingURLSet.removeAll(keepingCapacity: true)
    }

    private func scheduleFlushIfNeeded() {
        guard flushTask == nil else { return }
        flushTask = Task(priority: .utility) { [weak self] in
            await self?.flushLoop()
        }
    }

    private func flushLoop() async {
        while Task.isCancelled == false {
            do {
                try await Task.sleep(for: .milliseconds(GalleryImagePrefetchPolicy.delayMilliseconds))
            } catch {
                return
            }
            guard Task.isCancelled == false else { return }

            let batch = takeNextBatch()
            guard batch.isEmpty == false else {
                flushTask = nil
                return
            }

            await ImagePipeline.shared.prefetch(
                batch,
                concurrency: GalleryImagePrefetchPolicy.concurrency
            )

            guard pendingURLs.isEmpty == false else {
                flushTask = nil
                return
            }
        }
    }

    private func takeNextBatch() -> [URL] {
        let batchCount = min(GalleryImagePrefetchPolicy.batchURLLimit, pendingURLs.count)
        guard batchCount > 0 else { return [] }

        let batch = Array(pendingURLs.prefix(batchCount))
        pendingURLs.removeFirst(batchCount)
        for url in batch {
            pendingURLSet.remove(url)
        }
        return batch
    }
}
