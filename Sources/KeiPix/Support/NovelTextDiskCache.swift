import Foundation

/// Persists `PixivNovelText` responses to disk so novels stay readable
/// when the device is offline or the Pixiv API is unreachable. Each
/// novel ID maps to a single JSON file under `~/Library/Caches/KeiPix/NovelText/`.
actor NovelTextDiskCache {
    static let shared = NovelTextDiskCache()

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys]
        return e
    }()

    private let decoder = JSONDecoder()

    nonisolated private let cacheDirectory: URL =
        URL.cachesDirectory
            .appendingPathComponent("KeiPix", isDirectory: true)
            .appendingPathComponent("NovelText", isDirectory: true)

    // MARK: - Public API

    func load(novelID: Int) -> PixivNovelText? {
        let fileURL = cacheDirectory.appendingPathComponent("\(novelID).json")
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? decoder.decode(PixivNovelText.self, from: data)
    }

    func save(_ text: PixivNovelText, novelID: Int) {
        ensureDirectoryExists()
        let fileURL = cacheDirectory.appendingPathComponent("\(novelID).json")
        guard let data = try? encoder.encode(text) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    func remove(novelID: Int) {
        let fileURL = cacheDirectory.appendingPathComponent("\(novelID).json")
        try? FileManager.default.removeItem(at: fileURL)
    }

    func clearAll() {
        try? FileManager.default.removeItem(at: cacheDirectory)
    }

    nonisolated static func clearAllSynchronously() {
        try? FileManager.default.removeItem(
            at: URL.cachesDirectory
                .appendingPathComponent("KeiPix", isDirectory: true)
                .appendingPathComponent("NovelText", isDirectory: true)
        )
    }

    nonisolated func cachedSize() -> Int {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: cacheDirectory,
            includingPropertiesForKeys: [.fileSizeKey]
        ) else { return 0 }
        return files.reduce(0) { sum, url in
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
            return sum + size
        }
    }

    nonisolated func cachedIDs() -> [Int] {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: cacheDirectory,
            includingPropertiesForKeys: nil
        ) else { return [] }
        return files.compactMap { url in
            let name = url.deletingPathExtension().lastPathComponent
            return Int(name)
        }
    }

    // MARK: - Private

    private func ensureDirectoryExists() {
        try? FileManager.default.createDirectory(
            at: cacheDirectory,
            withIntermediateDirectories: true
        )
    }
}
