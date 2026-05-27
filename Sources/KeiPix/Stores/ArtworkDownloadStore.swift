import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class ArtworkDownloadStore {
    var items: [ArtworkDownloadItem] = []
    var isDownloading = false
    var downloadDirectoryPath: String
    var downloadNamingTemplate: String
    var downloadQueueFilter: DownloadQueueFilter
    var downloadQueueSort: DownloadQueueSort
    var downloadSearchText = ""
    var isPaused: Bool
    var maxConcurrentDownloads: Int
    /// User-facing toggle for the macOS Notification Center banner that
    /// fires when a download wraps up. Persisted via UserDefaults so
    /// the preference survives launches; defaults to `false` so we
    /// don't surprise a fresh-install user with a banner before they've
    /// seen Settings.
    var notifyOnDownloadFinish: Bool

    let fileManager = FileManager.default
    var workerTasks: [UUID: Task<Void, Never>] = [:]
    var activeWorkerItemIDs: [UUID: UUID] = [:]
    var queueWakeTask: Task<Void, Never>?
    /// Sliding-window byte/sec sampler. Mutates whenever a worker
    /// finishes a page (live samples) or an item leaves
    /// `.downloading` (resets). Read by the row badge and the
    /// nav-subtitle aggregate.
    var throughputSampler = DownloadThroughputSampler()
    /// Posts (and coalesces) Notification Center banners when a
    /// download wraps up. Behind a protocol-typed reference so unit
    /// tests can swap in a fake center; the real `init` always wires
    /// the system center.
    let completionNotifier: DownloadCompletionNotifier

    /// Hook fired on every queue mutation that affects Spotlight
    /// indexing — completion, deletion, clear-completed, etc. Wired
    /// by `KeiPixStore` to forward to the CoreSpotlight surface
    /// without dragging the indexer dependency into the download
    /// store. Optional so the store stays usable in isolation (and
    /// in tests).
    var spotlightSink: SpotlightSink?

    /// Side-effect channel for CoreSpotlight. Lets the download
    /// store stay ignorant of CoreSpotlight while still letting
    /// `KeiPixStore` keep the system index in sync as items finish
    /// or get removed.
    struct SpotlightSink {
        let didComplete: @MainActor (ArtworkDownloadItem) -> Void
        let didRemoveArtworkIDs: @MainActor ([Int]) -> Void
    }

    init(completionNotifier: DownloadCompletionNotifier = DownloadCompletionNotifier()) {
        self.completionNotifier = completionNotifier
        downloadDirectoryPath = UserDefaults.standard.string(forKey: "downloadDirectoryPath")
            ?? ArtworkDownloadStore.defaultDownloadDirectory.path(percentEncoded: false)
        downloadNamingTemplate = UserDefaults.standard.string(forKey: "downloadNamingTemplate")
            ?? DownloadNamingTemplate.defaultTemplate
        downloadQueueFilter = UserDefaults.standard.string(forKey: "downloadQueueFilter")
            .flatMap(DownloadQueueFilter.init(rawValue:)) ?? .all
        downloadQueueSort = UserDefaults.standard.string(forKey: "downloadQueueSort")
            .flatMap(DownloadQueueSort.init(rawValue:)) ?? .newest
        isPaused = UserDefaults.standard.bool(forKey: "downloadQueuePaused")
        maxConcurrentDownloads = Self.clampedConcurrentDownloadCount(
            UserDefaults.standard.object(forKey: "maxConcurrentDownloads") as? Int ?? 2
        )
        notifyOnDownloadFinish = UserDefaults.standard.bool(forKey: "notifyOnDownloadFinish")
        items = ArtworkDownloadStore.loadItems()
        var restoredInterruptedItems = false
        for index in items.indices {
            var itemChanged = false
            if items[index].status == .downloading {
                items[index].status = .queued
                items[index].errorMessage = isPaused ? nil : L10n.downloadInterrupted
                itemChanged = true
            }

            if items[index].status == .queued, isPaused == false {
                items[index].errorMessage = nil
                itemChanged = true
            }

            if itemChanged {
                items[index].updatedAt = Date()
                restoredInterruptedItems = true
            }
        }
        if restoredInterruptedItems {
            persistItems()
        }
    }

    var hasQueuedItems: Bool {
        items.contains { $0.status == .queued }
    }

    var downloadingCount: Int {
        items.filter { $0.status == .downloading }.count
    }

    var filteredCancellableCount: Int {
        filteredItems.filter { $0.status == .queued || $0.status == .downloading }.count
    }

    func downloadState(for artworkID: Int) -> ArtworkDownloadArtworkState {
        let matches = items.filter { $0.artworkID == artworkID }
        guard matches.isEmpty == false else { return .none }

        if matches.contains(where: { $0.status == .downloading }) {
            return .downloading
        }
        if matches.contains(where: { $0.status == .queued }) {
            return .queued
        }
        if matches.contains(where: { $0.status == .completed && hasReadableDownload(for: $0) }) {
            return .downloaded
        }
        if matches.contains(where: { $0.status == .failed }) {
            return .failed
        }
        return .none
    }

    func completedDownloadItem(for artworkID: Int) -> ArtworkDownloadItem? {
        items
            .filter { $0.artworkID == artworkID && $0.status == .completed && hasReadableDownload(for: $0) }
            .sorted { first, second in
                first.updatedAt > second.updatedAt
            }
            .first
    }

    var filteredItems: [ArtworkDownloadItem] {
        let query = downloadSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let filtered = items
            .filter(downloadQueueFilter.includes)
            .filter { $0.matchesDownloadSearch(query) }
        return downloadQueueSort.sorted(filtered)
    }

    var activeCount: Int {
        items.filter { $0.status == .queued || $0.status == .downloading }.count
    }

    var completedCount: Int {
        items.filter { $0.status == .completed }.count
    }

    var completedItems: [ArtworkDownloadItem] {
        items.filter { $0.status == .completed }
    }

    var invalidCompletedItems: [ArtworkDownloadItem] {
        items.filter { $0.status == .completed && hasReadableDownload(for: $0) == false }
    }

    var filteredDownloadedByteCount: Int64 {
        filteredItems.reduce(Int64(0)) { partialResult, item in
            partialResult + downloadedByteCount(for: item)
        }
    }

    var filteredDownloadedSizeText: String {
        Self.fileSizeFormatter.string(fromByteCount: filteredDownloadedByteCount)
    }

    var filteredPixivLinks: [String] {
        filteredItems.compactMap { $0.pixivURL?.absoluteString }
    }

    var filteredDeletableCount: Int {
        filteredItems.filter { $0.status != .downloading }.count
    }

    var failedFilteredCount: Int {
        filteredItems.filter { $0.status == .failed }.count
    }

    @discardableResult
    func reveal(_ item: ArtworkDownloadItem) -> Bool {
        if let filePath = item.downloadedFilePaths?.first {
            PlatformWorkspace.revealInFiles(URL(fileURLWithPath: filePath, isDirectory: false))
            return true
        }
        guard let folderPath = item.folderPath else {
            openDownloadDirectory()
            return false
        }
        PlatformWorkspace.revealInFiles(URL(fileURLWithPath: folderPath, isDirectory: true))
        return true
    }

    @discardableResult
    func revealFirstFilteredDownload() -> Bool {
        guard let item = filteredItems.first(where: { hasReadableDownload(for: $0) || $0.folderPath != nil }) else {
            return false
        }
        reveal(item)
        return true
    }

    func imageFileURLs(for item: ArtworkDownloadItem) -> [URL] {
        guard item.resolvedArtifactKind == .imagePages else { return [] }

        if let filePaths = item.downloadedFilePaths, filePaths.isEmpty == false {
            return validImageURLs(from: filePaths)
        }

        guard item.status == .completed, let folderPath = item.folderPath else { return [] }
        let folder = URL(fileURLWithPath: folderPath, isDirectory: true)
        let urls = (try? fileManager.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )) ?? []
        return urls
            .filter { url in
                let isRegularFile = (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) ?? false
                return isRegularFile && url.pathExtension.isImageExtension
            }
            .sorted { first, second in
                first.lastPathComponent.localizedStandardCompare(second.lastPathComponent) == .orderedAscending
            }
    }

    func downloadedImageURL(artworkID: Int, pageIndex: Int) -> URL? {
        let candidates = items
            .filter { item in
                item.artworkID == artworkID
                    && item.status == .completed
                    && item.resolvedArtifactKind == .imagePages
                    && hasReadableImages(for: item)
            }
            .sorted { first, second in
                first.updatedAt > second.updatedAt
            }

        for item in candidates {
            if let url = downloadedImageURL(in: item, pageIndex: pageIndex) {
                return url
            }
        }
        return nil
    }

    func downloadedImageURLs(artworkID: Int, expectedPageCount: Int) -> [URL] {
        (0..<max(expectedPageCount, 1)).compactMap { pageIndex in
            downloadedImageURL(artworkID: artworkID, pageIndex: pageIndex)
        }
    }

    func hasReadableImages(for item: ArtworkDownloadItem) -> Bool {
        imageFileURLs(for: item).isEmpty == false
    }

    func hasReadableDownload(for item: ArtworkDownloadItem) -> Bool {
        switch item.resolvedArtifactKind {
        case .imagePages:
            hasReadableImages(for: item)
        case .ugoiraZip:
            item.downloadedFilePaths?.contains { fileManager.fileExists(atPath: $0) } == true
        }
    }

    func downloadedByteCount(for item: ArtworkDownloadItem) -> Int64 {
        if let filePaths = item.downloadedFilePaths, filePaths.isEmpty == false {
            return filePaths.reduce(Int64(0)) { partialResult, filePath in
                partialResult + byteCount(at: URL(fileURLWithPath: filePath, isDirectory: false))
            }
        }

        guard let folderPath = item.folderPath else { return 0 }
        return byteCount(at: URL(fileURLWithPath: folderPath, isDirectory: true))
    }

    func downloadedSizeText(for item: ArtworkDownloadItem) -> String? {
        let byteCount = downloadedByteCount(for: item)
        guard byteCount > 0 else { return nil }
        return Self.fileSizeFormatter.string(fromByteCount: byteCount)
    }

    /// Formatted bytes-per-second for the row, or `nil` when the item
    /// isn't actively downloading or no samples are recent enough to
    /// quote a rate. Reads `throughputSampler` so SwiftUI invalidates
    /// the row whenever the sampler mutates through `record`.
    func throughputText(for item: ArtworkDownloadItem) -> String? {
        guard item.status == .downloading else { return nil }
        guard let bytesPerSecond = throughputSampler.bytesPerSecond(for: item.id) else { return nil }
        return Self.formatThroughput(bytesPerSecond: bytesPerSecond)
    }

    /// Aggregate "X MB/s" line used in the navigation subtitle. Only
    /// shows when at least one item is downloading; the sampler's
    /// sliding window already drops stale numbers, but the explicit
    /// `downloadingCount > 0` guard keeps the label from lingering on
    /// the very last sample after a worker exits.
    var aggregateThroughputText: String? {
        guard downloadingCount > 0 else { return nil }
        guard let bytesPerSecond = throughputSampler.aggregateBytesPerSecond() else { return nil }
        return Self.formatThroughput(bytesPerSecond: bytesPerSecond)
    }

    private static func formatThroughput(bytesPerSecond: Double) -> String {
        let bytes = Int64(bytesPerSecond.rounded())
        let formatted = Self.throughputByteFormatter.string(fromByteCount: max(bytes, 0))
        return String(format: L10n.downloadThroughputPerSecondFormat, formatted)
    }

    private func downloadedImageURL(in item: ArtworkDownloadItem, pageIndex: Int) -> URL? {
        let urls = validImageURLs(from: item.downloadedFilePaths ?? [])
        guard urls.isEmpty == false else { return nil }

        if let sourcePageIndexes = item.sourcePageIndexes {
            guard let localIndex = sourcePageIndexes.firstIndex(of: pageIndex),
                  urls.indices.contains(localIndex) else {
                return nil
            }
            return urls[localIndex]
        }

        if urls.indices.contains(pageIndex) {
            return urls[pageIndex]
        }

        if pageIndex == 0, urls.count == 1 {
            return urls[0]
        }
        return nil
    }

    private func validImageURLs(from filePaths: [String]) -> [URL] {
        filePaths
            .map { URL(fileURLWithPath: $0, isDirectory: false) }
            .filter { fileManager.fileExists(atPath: $0.path(percentEncoded: false)) && $0.pathExtension.isImageExtension }
    }

    @discardableResult
    func chooseDownloadDirectory() -> Bool {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.directoryURL = URL(fileURLWithPath: downloadDirectoryPath, isDirectory: true)
        panel.prompt = L10n.choose
        if panel.runModal() == .OK, let url = panel.url {
            setDownloadDirectory(url)
            return true
        }
        return false
    }

    @discardableResult
    func openDownloadDirectory() -> Bool {
        let url = URL(fileURLWithPath: downloadDirectoryPath, isDirectory: true)
        do {
            try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
            return PlatformWorkspace.open(url)
        } catch {
            return false
        }
    }

    private func setDownloadDirectory(_ url: URL) {
        downloadDirectoryPath = url.path(percentEncoded: false)
        UserDefaults.standard.set(downloadDirectoryPath, forKey: "downloadDirectoryPath")
    }

    func setDownloadNamingTemplate(_ template: String) {
        downloadNamingTemplate = template
        UserDefaults.standard.set(downloadNamingTemplate, forKey: "downloadNamingTemplate")
    }

    @discardableResult
    func resetDownloadNamingTemplate() -> Bool {
        guard downloadNamingTemplate != DownloadNamingTemplate.defaultTemplate else {
            return false
        }
        setDownloadNamingTemplate(DownloadNamingTemplate.defaultTemplate)
        return true
    }

    var downloadNamingTemplatePreview: String {
        DownloadNamingTemplate(rawValue: downloadNamingTemplate).previewPath()
    }

    /// Live preview rows for the Downloads settings page. Each row
    /// renders the user's current template against a documented scenario
    /// (standalone illust, multi-page artwork, serialized manga) so a
    /// typo or token swap surfaces immediately instead of showing up the
    /// next time a download lands.
    var downloadNamingTemplatePreviewScenarios: [DownloadNamingTemplate.PreviewScenario] {
        DownloadNamingTemplate(rawValue: downloadNamingTemplate).previewScenarios()
    }

    /// Names of placeholders in the user's template that don't match any
    /// known token. Returns an empty list when the template is clean.
    var unknownNamingPlaceholders: [String] {
        DownloadNamingTemplate(rawValue: downloadNamingTemplate).unknownPlaceholders
    }

    func startWorkerIfNeeded(preferOriginal: Bool) {
        guard isPaused == false else { return }
        guard items.contains(where: { $0.status == .queued }) else { return }
        let now = Date()
        let queuedCount = items.filter { $0.isQueuedAndReady(at: now) }.count
        guard queuedCount > 0 else {
            scheduleQueueWake(preferOriginal: preferOriginal)
            return
        }

        let targetWorkerCount = min(maxConcurrentDownloads, queuedCount + workerTasks.count)
        guard workerTasks.count < targetWorkerCount else { return }

        queueWakeTask?.cancel()
        queueWakeTask = nil
        for _ in workerTasks.count..<targetWorkerCount {
            let workerID = UUID()
            workerTasks[workerID] = Task { [weak self] in
                await self?.drainQueue(workerID: workerID, preferOriginal: preferOriginal)
            }
        }
        isDownloading = workerTasks.isEmpty == false
    }

    private func drainQueue(workerID: UUID, preferOriginal: Bool) async {
        guard isPaused == false else { return }
        defer {
            activeWorkerItemIDs[workerID] = nil
            workerTasks[workerID] = nil
            isDownloading = workerTasks.isEmpty == false
            scheduleQueueWake(preferOriginal: preferOriginal)
        }

        while isPaused == false,
              Task.isCancelled == false,
              let index = items.firstIndex(where: { $0.isQueuedAndReady(at: Date()) }) {
            var item = items[index]
            guard let sourceURLs = item.sourceImageURLs, sourceURLs.isEmpty == false else {
                markFailed(itemID: item.id, error: ArtworkDownloadError.missingSourceURLs)
                continue
            }
            activeWorkerItemIDs[workerID] = item.id
            item.status = .downloading
            item.queuedAfter = nil
            item.errorMessage = nil
            item.updatedAt = Date()
            items[index] = item
            persistItems()

            do {
                let folder = try await download(item, sourceURLs: sourceURLs)
                markCompleted(itemID: item.id, folder: folder)
            } catch is CancellationError {
                markQueued(itemID: item.id)
            } catch {
                markFailed(itemID: item.id, error: error)
            }
            activeWorkerItemIDs[workerID] = nil
        }
    }

    private func scheduleQueueWake(preferOriginal: Bool) {
        guard isPaused == false, queueWakeTask == nil, workerTasks.isEmpty else { return }
        let nextDate = items
            .filter { $0.status == .queued }
            .compactMap(\.queuedAfter)
            .filter { $0 > Date() }
            .min()
        guard let nextDate else { return }

        let delay = max(nextDate.timeIntervalSinceNow, 0)
        queueWakeTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            await MainActor.run {
                self?.queueWakeTask = nil
                self?.startWorkerIfNeeded(preferOriginal: preferOriginal)
            }
        }
    }

    func cancelWorkers(for itemIDs: Set<UUID>) {
        guard itemIDs.isEmpty == false else { return }
        for (workerID, itemID) in activeWorkerItemIDs where itemIDs.contains(itemID) {
            workerTasks[workerID]?.cancel()
        }
    }

    func restorableCancelledItem(_ item: ArtworkDownloadItem) -> ArtworkDownloadItem {
        var restoredItem = item
        if restoredItem.status == .downloading {
            restoredItem.status = .queued
            restoredItem.errorMessage = nil
        }
        return restoredItem
    }

    private func download(_ item: ArtworkDownloadItem, sourceURLs: [URL]) async throws -> URL {
        let root = URL(fileURLWithPath: downloadDirectoryPath, isDirectory: true)
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        let template = DownloadNamingTemplate(rawValue: downloadNamingTemplate)

        let totalPages = item.sourceTotalPageCount ?? sourceURLs.count
        var lastFolder = root
        for (pageIndex, url) in sourceURLs.enumerated() {
            try Task.checkCancellation()
            let pageStart = Date()
            let data = try await ImagePipeline.shared.data(for: url)
            try Task.checkCancellation()
            // Record one sample per page. Wall-clock duration includes
            // the cooperative-yield gaps between `await`s, but those
            // dominate only on a saturated worker pool — close enough
            // for a UX speedometer where the goal is "is it moving".
            let pageDuration = Date().timeIntervalSince(pageStart)
            throughputSampler.record(
                itemID: item.id,
                bytes: data.count,
                durationSeconds: pageDuration
            )
            let sourcePageIndex = item.sourcePageIndexes?[safe: pageIndex] ?? pageIndex
            let renderedPath = template.render(context: .init(
                item: item,
                pageIndex: sourcePageIndex,
                totalPages: totalPages,
                sourceURL: url
            ))
            let folder = folderURL(root: root, components: renderedPath.parentComponents)
            let fileURL = fileURL(root: root, components: renderedPath.components)
            try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
            try data.write(to: fileURL, options: .atomic)
            lastFolder = folder
            markPageCompleted(itemID: item.id, completedPages: pageIndex + 1, folder: folder, file: fileURL)
        }

        return lastFolder
    }

    func sourceImageURLs(for artwork: PixivArtwork, preferOriginal: Bool) -> [URL] {
        let pageCount = max(artwork.images.count, 1)
        return (0..<pageCount).compactMap {
            artwork.imageURL(at: $0, preferOriginal: preferOriginal)
        }
    }

    private func fileURL(root: URL, components: [String]) -> URL {
        components.enumerated().reduce(root) { partialResult, element in
            let isFile = element.offset == components.count - 1
            return partialResult.appending(
                path: element.element,
                directoryHint: isFile ? .notDirectory : .isDirectory
            )
        }
    }

    private func folderURL(root: URL, components: [String]) -> URL {
        components.reduce(root) { partialResult, component in
            partialResult.appending(path: component, directoryHint: .isDirectory)
        }
    }

    private func markPageCompleted(itemID: UUID, completedPages: Int, folder: URL, file: URL) {
        guard let index = items.firstIndex(where: { $0.id == itemID }) else { return }
        items[index].completedPages = completedPages
        items[index].folderPath = folder.path(percentEncoded: false)
        var filePaths = items[index].downloadedFilePaths ?? []
        let filePath = file.path(percentEncoded: false)
        if filePaths.contains(filePath) == false {
            filePaths.append(filePath)
        }
        items[index].downloadedFilePaths = filePaths
        items[index].updatedAt = Date()
        persistItems()
    }

    private func markCompleted(itemID: UUID, folder: URL) {
        guard let index = items.firstIndex(where: { $0.id == itemID }) else { return }
        items[index].status = .completed
        items[index].completedPages = items[index].pageCount
        items[index].folderPath = folder.path(percentEncoded: false)
        items[index].updatedAt = Date()
        throughputSampler.reset(itemID: itemID)
        // Fire-and-forget banner so the worker stays on its hot path.
        // The notifier coalesces a burst of completions into one
        // banner — same shape Finder uses when a copy of many files
        // wraps up — so a 50-image queue doesn't spam Notification
        // Center.
        if notifyOnDownloadFinish {
            completionNotifier.recordCompletion(title: items[index].title)
        }
        // Mirror to CoreSpotlight via the sink so a freshly-finished
        // download is searchable from `Cmd+Space` immediately. The
        // sink itself decides whether indexing is enabled.
        spotlightSink?.didComplete(items[index])
        persistItems()
    }

    private func markQueued(itemID: UUID) {
        guard let index = items.firstIndex(where: { $0.id == itemID }) else { return }
        items[index].status = .queued
        items[index].errorMessage = nil
        items[index].updatedAt = Date()
        throughputSampler.reset(itemID: itemID)
        persistItems()
    }

    private func markFailed(itemID: UUID, error: Error) {
        guard let index = items.firstIndex(where: { $0.id == itemID }) else { return }
        items[index].status = .failed
        items[index].errorMessage = error.localizedDescription
        items[index].updatedAt = Date()
        throughputSampler.reset(itemID: itemID)
        persistItems()
    }

    func persistItems() {
        do {
            let url = try Self.manifestURL()
            try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try JSONEncoder.keiPixDownloads.encode(items)
            try data.write(to: url, options: .atomic)
        } catch {
        }
    }

    private func byteCount(at url: URL) -> Int64 {
        let path = url.path(percentEncoded: false)
        guard fileManager.fileExists(atPath: path) else { return 0 }

        if let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey, .totalFileAllocatedSizeKey]),
           values.isDirectory != true {
            return Int64(values.totalFileAllocatedSize ?? values.fileSize ?? 0)
        }

        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey, .totalFileAllocatedSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }

        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey, .totalFileAllocatedSizeKey]),
                  values.isRegularFile == true else {
                continue
            }
            total += Int64(values.totalFileAllocatedSize ?? values.fileSize ?? 0)
        }
        return total
    }

    private static func loadItems() -> [ArtworkDownloadItem] {
        do {
            let url = try manifestURL()
            let data = try Data(contentsOf: url)
            return try JSONDecoder.keiPixDownloads.decode([ArtworkDownloadItem].self, from: data)
        } catch {
            return []
        }
    }

    private static func manifestURL() throws -> URL {
        let root = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return root.appending(path: "KeiPix/Downloads/downloads.json")
    }

    static func clampedConcurrentDownloadCount(_ count: Int) -> Int {
        min(max(count, 1), 4)
    }

    private static var defaultDownloadDirectory: URL {
        FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first?
            .appending(path: "KeiPix", directoryHint: .isDirectory)
        ?? URL.homeDirectory.appending(path: "Downloads/KeiPix", directoryHint: .isDirectory)
    }

    private static let fileSizeFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter
    }()

    /// Distinct formatter for throughput so we can drop down to bytes
    /// when the rate is tiny (a sub-1 KB/s residual after the window
    /// nearly empties) without polluting the per-file size labels
    /// elsewhere.
    private static let throughputByteFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        formatter.countStyle = .binary
        formatter.includesUnit = true
        formatter.zeroPadsFractionDigits = false
        return formatter
    }()
}

private enum ArtworkDownloadError: LocalizedError {
    case missingSourceURLs

    var errorDescription: String? {
        L10n.downloadInterrupted
    }
}

private extension JSONEncoder {
    static var keiPixDownloads: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}

private extension JSONDecoder {
    static var keiPixDownloads: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

private extension String {
    var safePathComponent: String {
        let invalid = CharacterSet(charactersIn: "/\\:*?\"<>|")
            .union(.newlines)
            .union(.controlCharacters)
        let cleaned = components(separatedBy: invalid)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "Untitled" : String(cleaned.prefix(80))
    }

    var isImageExtension: Bool {
        ["jpg", "jpeg", "png", "gif", "webp", "avif"].contains(lowercased())
    }
}
