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
    private var queuedArtworkSnapshots: [UUID: PixivArtwork] = [:]

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
            return
        }

        let item = ArtworkDownloadItem(
            id: UUID(),
            artworkID: artwork.id,
            title: artwork.title,
            creatorName: artwork.user.name,
            pageCount: downloadPageCount(for: artwork),
            completedPages: 0,
            status: .queued,
            folderPath: nil,
            errorMessage: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
        items.insert(item, at: 0)
        queuedArtworkSnapshots[item.id] = artwork
        persistItems()
        startWorkerIfNeeded(preferOriginal: preferOriginal)
    }

    func clearCompleted() {
        items.removeAll { $0.status == .completed }
        persistItems()
    }

    func reveal(_ item: ArtworkDownloadItem) {
        guard let folderPath = item.folderPath else {
            openDownloadDirectory()
            return
        }
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: folderPath, isDirectory: true)])
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
            guard let artwork = queuedArtworkSnapshots[item.id] else {
                markFailed(itemID: item.id, error: ArtworkDownloadError.missingArtworkSnapshot)
                continue
            }
            item.status = .downloading
            item.errorMessage = nil
            item.updatedAt = Date()
            items[index] = item
            persistItems()

            do {
                let folder = try await download(artwork, itemID: item.id, preferOriginal: preferOriginal)
                markCompleted(itemID: item.id, folder: folder)
                queuedArtworkSnapshots[item.id] = nil
            } catch {
                markFailed(itemID: item.id, error: error)
                queuedArtworkSnapshots[item.id] = nil
            }
        }
    }

    private func download(_ artwork: PixivArtwork, itemID: UUID, preferOriginal: Bool) async throws -> URL {
        let root = URL(fileURLWithPath: downloadDirectoryPath, isDirectory: true)
        let folder = root.appending(path: "\(artwork.id) - \(artwork.title.safePathComponent)", directoryHint: .isDirectory)
        try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)

        let totalPages = downloadPageCount(for: artwork)
        for pageIndex in 0..<totalPages {
            guard let url = artwork.imageURL(at: pageIndex, preferOriginal: preferOriginal) else { continue }
            let data = try await ImagePipeline.shared.data(for: url)
            let fileURL = folder.appending(path: fileName(for: artwork, pageIndex: pageIndex, totalPages: totalPages, sourceURL: url))
            try data.write(to: fileURL, options: .atomic)
            markPageCompleted(itemID: itemID, completedPages: pageIndex + 1, folder: folder)
        }

        return folder
    }

    private func downloadPageCount(for artwork: PixivArtwork) -> Int {
        max(artwork.images.count, 1)
    }

    private func fileName(for artwork: PixivArtwork, pageIndex: Int, totalPages: Int, sourceURL: URL) -> String {
        let ext = sourceURL.pathExtension.isImageExtension ? sourceURL.pathExtension.lowercased() : "jpg"
        let pageSuffix = totalPages > 1 ? "_p\(pageIndex)" : ""
        return "\(artwork.id)\(pageSuffix).\(ext)"
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
    case missingArtworkSnapshot

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
