import Foundation
import Testing
@testable import KeiPix

@Suite("Artwork reading modes")
struct ArtworkReadingModeTests {
    @Test("Reading mode preference kinds keep distinct defaults")
    func preferenceKindDefaults() {
        #expect(ArtworkReadingModePreferenceKind.artwork.storageKey == "defaultArtworkReadingMode")
        #expect(ArtworkReadingModePreferenceKind.artwork.fallbackMode == .singlePage)
        #expect(ArtworkReadingModePreferenceKind.manga.storageKey == "defaultMangaReadingMode")
        #expect(ArtworkReadingModePreferenceKind.manga.fallbackMode == .continuous)
    }

    @Test("Reader progress clamps and keeps recent entries first")
    func readerProgressLibrary() {
        var library = ArtworkReaderProgressLibrary()
        library.update(
            artworkID: 10,
            pageIndex: 8,
            pageCount: 5,
            updatedAt: Date(timeIntervalSince1970: 100)
        )
        library.update(
            artworkID: 20,
            pageIndex: 2,
            pageCount: 4,
            updatedAt: Date(timeIntervalSince1970: 200)
        )

        #expect(library.restoredPageIndex(for: 10, pageCount: 5) == 4)
        #expect(library.restoredPageIndex(for: 20, pageCount: 4) == 2)
        #expect(library.items.map(\.artworkID) == [20, 10])
    }

    @Test("Reader progress ignores single-page artworks")
    func readerProgressSkipsSinglePage() {
        var library = ArtworkReaderProgressLibrary()
        library.update(artworkID: 10, pageIndex: 0, pageCount: 1)

        #expect(library.restoredPageIndex(for: 10, pageCount: 1) == nil)
        #expect(library.items.isEmpty)
    }

    @Test("Downloaded reader progress is scoped by download record")
    func downloadedReaderProgressLibrary() {
        let fullDownloadID = UUID()
        let pageRangeDownloadID = UUID()
        var library = DownloadedArtworkReaderProgressLibrary()
        library.update(downloadID: fullDownloadID, pageIndex: 7, pageCount: 20)
        library.update(downloadID: pageRangeDownloadID, pageIndex: 2, pageCount: 4)

        #expect(library.restoredPageIndex(for: fullDownloadID, pageCount: 20) == 7)
        #expect(library.restoredPageIndex(for: pageRangeDownloadID, pageCount: 4) == 2)
        #expect(library.items.map(\.downloadID) == [pageRangeDownloadID, fullDownloadID])
    }
}
