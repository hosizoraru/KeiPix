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

    private let fileManager = FileManager.default
    private var workerTask: Task<Void, Never>?

    init() {
        downloadDirectoryPath = UserDefaults.standard.string(forKey: "downloadDirectoryPath")
            ?? ArtworkDownloadStore.defaultDownloadDirectory.path(percentEncoded: false)
        downloadNamingTemplate = UserDefaults.standard.string(forKey: "downloadNamingTemplate")
            ?? DownloadNamingTemplate.defaultTemplate
        downloadQueueFilter = UserDefaults.standard.string(forKey: "downloadQueueFilter")
            .flatMap(DownloadQueueFilter.init(rawValue:)) ?? .all
        downloadQueueSort = UserDefaults.standard.string(forKey: "downloadQueueSort")
            .flatMap(DownloadQueueSort.init(rawValue:)) ?? .newest
        items = ArtworkDownloadStore.loadItems()
        var restoredInterruptedItems = false
        for index in items.indices where items[index].status == .downloading || items[index].status == .queued {
            items[index].status = .failed
            items[index].errorMessage = L10n.downloadInterrupted
            restoredInterruptedItems = true
        }
        if restoredInterruptedItems {
            persistItems()
        }
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

    var failedFilteredCount: Int {
        filteredItems.filter { $0.status == .failed }.count
    }

    @discardableResult
    func retryFailedFilteredItems() -> Int {
        let ids = Set(filteredItems.filter {
            $0.status == .failed && $0.sourceImageURLs?.isEmpty == false
        }.map(\.id))
        guard ids.isEmpty == false else { return 0 }

        for index in items.indices where ids.contains(items[index].id) {
            items[index].status = .queued
            items[index].completedPages = 0
            items[index].folderPath = nil
            items[index].downloadedFilePaths = nil
            items[index].errorMessage = nil
            items[index].updatedAt = Date()
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

    func retry(_ item: ArtworkDownloadItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }),
              items[index].status == .failed,
              items[index].sourceImageURLs?.isEmpty == false else {
            return
        }
        items[index].status = .queued
        items[index].completedPages = 0
        items[index].folderPath = nil
        items[index].downloadedFilePaths = nil
        items[index].errorMessage = nil
        items[index].updatedAt = Date()
        persistItems()
        startWorkerIfNeeded(preferOriginal: true)
    }

    func delete(_ item: ArtworkDownloadItem) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items.remove(at: index)
        }
        persistItems()
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

    func reveal(_ item: ArtworkDownloadItem) {
        if let filePath = item.downloadedFilePaths?.first {
            NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: filePath, isDirectory: false)])
            return
        }
        guard let folderPath = item.folderPath else {
            openDownloadDirectory()
            return
        }
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: folderPath, isDirectory: true)])
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
            return filePaths
                .map { URL(fileURLWithPath: $0, isDirectory: false) }
                .filter { fileManager.fileExists(atPath: $0.path(percentEncoded: false)) && $0.pathExtension.isImageExtension }
                .sorted { first, second in
                    first.lastPathComponent.localizedStandardCompare(second.lastPathComponent) == .orderedAscending
                }
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

    func chooseDownloadDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.directoryURL = URL(fileURLWithPath: downloadDirectoryPath, isDirectory: true)
        panel.prompt = L10n.choose
        if panel.runModal() == .OK, let url = panel.url {
            setDownloadDirectory(url)
        }
    }

    func openDownloadDirectory() {
        let url = URL(fileURLWithPath: downloadDirectoryPath, isDirectory: true)
        try? fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        NSWorkspace.shared.open(url)
    }

    private func setDownloadDirectory(_ url: URL) {
        downloadDirectoryPath = url.path(percentEncoded: false)
        UserDefaults.standard.set(downloadDirectoryPath, forKey: "downloadDirectoryPath")
    }

    func setDownloadNamingTemplate(_ template: String) {
        downloadNamingTemplate = template
        UserDefaults.standard.set(downloadNamingTemplate, forKey: "downloadNamingTemplate")
    }

    func resetDownloadNamingTemplate() {
        setDownloadNamingTemplate(DownloadNamingTemplate.defaultTemplate)
    }

    var downloadNamingTemplatePreview: String {
        DownloadNamingTemplate(rawValue: downloadNamingTemplate).previewPath()
    }

    private func startWorkerIfNeeded(preferOriginal: Bool) {
        guard workerTask == nil else { return }
        workerTask = Task { [weak self] in
            await self?.drainQueue(preferOriginal: preferOriginal)
        }
    }

    private func drainQueue(preferOriginal: Bool) async {
        guard isDownloading == false else { return }
        isDownloading = true
        defer {
            isDownloading = false
            workerTask = nil
        }

        while let index = items.firstIndex(where: { $0.status == .queued }) {
            var item = items[index]
            guard let sourceURLs = item.sourceImageURLs, sourceURLs.isEmpty == false else {
                markFailed(itemID: item.id, error: ArtworkDownloadError.missingSourceURLs)
                continue
            }
            item.status = .downloading
            item.errorMessage = nil
            item.updatedAt = Date()
            items[index] = item
            persistItems()

            do {
                let folder = try await download(item, sourceURLs: sourceURLs)
                markCompleted(itemID: item.id, folder: folder)
            } catch {
                markFailed(itemID: item.id, error: error)
            }
        }
    }

    private func download(_ item: ArtworkDownloadItem, sourceURLs: [URL]) async throws -> URL {
        let root = URL(fileURLWithPath: downloadDirectoryPath, isDirectory: true)
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        let template = DownloadNamingTemplate(rawValue: downloadNamingTemplate)

        let totalPages = item.sourceTotalPageCount ?? sourceURLs.count
        var lastFolder = root
        for (pageIndex, url) in sourceURLs.enumerated() {
            let data = try await ImagePipeline.shared.data(for: url)
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

    private func sourceImageURLs(for artwork: PixivArtwork, preferOriginal: Bool) -> [URL] {
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
        persistItems()
    }

    private func markFailed(itemID: UUID, error: Error) {
        guard let index = items.firstIndex(where: { $0.id == itemID }) else { return }
        items[index].status = .failed
        items[index].errorMessage = error.localizedDescription
        items[index].updatedAt = Date()
        persistItems()
    }

    private func persistItems() {
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
