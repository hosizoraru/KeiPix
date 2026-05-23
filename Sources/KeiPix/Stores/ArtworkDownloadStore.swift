import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class ArtworkDownloadStore {
    var items: [ArtworkDownloadItem] = []
    var isDownloading = false
    var downloadDirectoryPath: String

    private let fileManager = FileManager.default
    private var workerTask: Task<Void, Never>?

    init() {
        downloadDirectoryPath = UserDefaults.standard.string(forKey: "downloadDirectoryPath")
            ?? ArtworkDownloadStore.defaultDownloadDirectory.path(percentEncoded: false)
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
            $0.artworkID == artwork.id && ($0.status == .queued || $0.status == .downloading)
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
            pageCount: sourceImageURLs(for: artwork, preferOriginal: preferOriginal).count,
            completedPages: 0,
            status: .queued,
            folderPath: nil,
            sourceImageURLs: sourceImageURLs(for: artwork, preferOriginal: preferOriginal),
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
        let existingArtworkIDs = Set(items.filter { $0.status != .failed }.map(\.artworkID))
        let candidates = artworks.prefix(max(limit, 0)).filter { existingArtworkIDs.contains($0.id) == false }
        guard candidates.isEmpty == false else { return 0 }

        let now = Date()
        let newItems = candidates.map { artwork in
            ArtworkDownloadItem(
                id: UUID(),
                artworkID: artwork.id,
                title: artwork.title,
                creatorName: artwork.user.name,
                pageCount: sourceImageURLs(for: artwork, preferOriginal: preferOriginal).count,
                completedPages: 0,
                status: .queued,
                folderPath: nil,
                sourceImageURLs: sourceImageURLs(for: artwork, preferOriginal: preferOriginal),
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

    func clearCompleted() {
        items.removeAll { $0.status == .completed }
        persistItems()
    }

    @discardableResult
    func clearInvalidItems() -> Int {
        let initialCount = items.count
        items.removeAll { item in
            item.status == .completed && hasReadableImages(for: item) == false
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
        items[index].errorMessage = nil
        items[index].updatedAt = Date()
        persistItems()
        startWorkerIfNeeded(preferOriginal: true)
    }

    func delete(_ item: ArtworkDownloadItem) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items.remove(at: index)
        }
        if let folderPath = item.folderPath {
            moveToTrash(URL(fileURLWithPath: folderPath, isDirectory: true))
        }
        persistItems()
    }

    func reveal(_ item: ArtworkDownloadItem) {
        guard let folderPath = item.folderPath else {
            openDownloadDirectory()
            return
        }
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: folderPath, isDirectory: true)])
    }

    func imageFileURLs(for item: ArtworkDownloadItem) -> [URL] {
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
        let folder = root.appending(path: "\(item.artworkID) - \(item.title.safePathComponent)", directoryHint: .isDirectory)
        try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)

        let totalPages = sourceURLs.count
        for (pageIndex, url) in sourceURLs.enumerated() {
            let data = try await ImagePipeline.shared.data(for: url)
            let fileURL = folder.appending(path: fileName(artworkID: item.artworkID, pageIndex: pageIndex, totalPages: totalPages, sourceURL: url))
            try data.write(to: fileURL, options: .atomic)
            markPageCompleted(itemID: item.id, completedPages: pageIndex + 1, folder: folder)
        }

        return folder
    }

    private func sourceImageURLs(for artwork: PixivArtwork, preferOriginal: Bool) -> [URL] {
        let pageCount = max(artwork.images.count, 1)
        return (0..<pageCount).compactMap {
            artwork.imageURL(at: $0, preferOriginal: preferOriginal)
        }
    }

    private func fileName(artworkID: Int, pageIndex: Int, totalPages: Int, sourceURL: URL) -> String {
        let ext = sourceURL.pathExtension.isImageExtension ? sourceURL.pathExtension.lowercased() : "jpg"
        let pageSuffix = totalPages > 1 ? "_p\(pageIndex)" : ""
        return "\(artworkID)\(pageSuffix).\(ext)"
    }

    private func markPageCompleted(itemID: UUID, completedPages: Int, folder: URL) {
        guard let index = items.firstIndex(where: { $0.id == itemID }) else { return }
        items[index].completedPages = completedPages
        items[index].folderPath = folder.path(percentEncoded: false)
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

    private func moveToTrash(_ url: URL) {
        guard fileManager.fileExists(atPath: url.path(percentEncoded: false)) else { return }
        do {
            _ = try fileManager.trashItem(at: url, resultingItemURL: nil)
        } catch {
            try? fileManager.removeItem(at: url)
        }
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
