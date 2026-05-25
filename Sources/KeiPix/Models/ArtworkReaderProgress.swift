import Foundation

struct ArtworkReaderProgress: Codable, Hashable, Sendable {
    let artworkID: Int
    var pageIndex: Int
    var pageCount: Int
    var updatedAt: Date

    func restoredPageIndex(for currentPageCount: Int) -> Int? {
        guard currentPageCount > 1 else { return nil }
        return min(max(pageIndex, 0), currentPageCount - 1)
    }
}

struct ArtworkReaderProgressLibrary: Codable, Hashable, Sendable {
    private(set) var items: [ArtworkReaderProgress]

    init(items: [ArtworkReaderProgress] = []) {
        self.items = items.sorted { $0.updatedAt > $1.updatedAt }
    }

    func restoredPageIndex(for artworkID: Int, pageCount: Int) -> Int? {
        items.first { $0.artworkID == artworkID }?.restoredPageIndex(for: pageCount)
    }

    mutating func update(
        artworkID: Int,
        pageIndex: Int,
        pageCount: Int,
        updatedAt: Date = Date(),
        limit: Int = 500
    ) {
        guard pageCount > 1 else {
            items.removeAll { $0.artworkID == artworkID }
            return
        }

        let clampedIndex = min(max(pageIndex, 0), pageCount - 1)
        items.removeAll { $0.artworkID == artworkID }
        items.insert(
            ArtworkReaderProgress(
                artworkID: artworkID,
                pageIndex: clampedIndex,
                pageCount: pageCount,
                updatedAt: updatedAt
            ),
            at: 0
        )

        if items.count > limit {
            items = Array(items.prefix(limit))
        }
    }
}

struct DownloadedArtworkReaderProgress: Codable, Hashable, Sendable {
    let downloadID: UUID
    var pageIndex: Int
    var pageCount: Int
    var updatedAt: Date

    func restoredPageIndex(for currentPageCount: Int) -> Int? {
        guard currentPageCount > 1 else { return nil }
        return min(max(pageIndex, 0), currentPageCount - 1)
    }
}

struct DownloadedArtworkReaderProgressLibrary: Codable, Hashable, Sendable {
    private(set) var items: [DownloadedArtworkReaderProgress]

    init(items: [DownloadedArtworkReaderProgress] = []) {
        self.items = items.sorted { $0.updatedAt > $1.updatedAt }
    }

    func restoredPageIndex(for downloadID: UUID, pageCount: Int) -> Int? {
        items.first { $0.downloadID == downloadID }?.restoredPageIndex(for: pageCount)
    }

    mutating func update(
        downloadID: UUID,
        pageIndex: Int,
        pageCount: Int,
        updatedAt: Date = Date(),
        limit: Int = 500
    ) {
        guard pageCount > 1 else {
            items.removeAll { $0.downloadID == downloadID }
            return
        }

        let clampedIndex = min(max(pageIndex, 0), pageCount - 1)
        items.removeAll { $0.downloadID == downloadID }
        items.insert(
            DownloadedArtworkReaderProgress(
                downloadID: downloadID,
                pageIndex: clampedIndex,
                pageCount: pageCount,
                updatedAt: updatedAt
            ),
            at: 0
        )

        if items.count > limit {
            items = Array(items.prefix(limit))
        }
    }
}
