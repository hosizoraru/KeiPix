import Foundation
import Testing
@testable import KeiPix

@Suite("Manga watchlist progress")
struct MangaWatchlistProgressTests {
    @Test("First watchlist snapshot becomes the local baseline")
    func firstSnapshotCreatesBaseline() {
        var library = MangaWatchlistReadStateLibrary()
        let series = makeSeries(id: 10, latestContentID: 100, publishedContentCount: 3)

        library.registerSnapshot([series], now: Date(timeIntervalSince1970: 100))

        #expect(library.status(for: series) == .none)
        #expect(library.items.map(\.seriesID) == [10])
    }

    @Test("New content after the baseline produces an update badge")
    func newContentProducesUpdateStatus() {
        var library = MangaWatchlistReadStateLibrary()
        let baseline = makeSeries(id: 10, latestContentID: 100, publishedContentCount: 3)
        let updated = makeSeries(id: 10, latestContentID: 101, publishedContentCount: 5)

        library.markRead(baseline, now: Date(timeIntervalSince1970: 100))
        let status = library.status(for: updated)

        #expect(status.hasUpdate)
        #expect(status.unreadCount == 2)
    }

    @Test("Marking a series read clears the local update badge")
    func markReadClearsUpdateStatus() {
        var library = MangaWatchlistReadStateLibrary()
        let baseline = makeSeries(id: 10, latestContentID: 100, publishedContentCount: 3)
        let updated = makeSeries(id: 10, latestContentID: 101, publishedContentCount: 5)

        library.markRead(baseline, now: Date(timeIntervalSince1970: 100))
        library.markRead(updated, now: Date(timeIntervalSince1970: 200))

        #expect(library.status(for: updated) == .none)
        #expect(library.items.first?.latestContentID == 101)
    }

    @Test("API unread fields produce badges until the user marks the series read")
    func apiUnreadFieldsProduceUpdateStatusUntilMarkedRead() {
        var library = MangaWatchlistReadStateLibrary()
        let apiUnread = makeSeries(
            id: 10,
            latestContentID: 100,
            publishedContentCount: 3,
            apiUnreadContentCount: 4
        )
        let apiUpdated = makeSeries(
            id: 11,
            latestContentID: 200,
            publishedContentCount: 1,
            apiIsUnread: true
        )

        #expect(library.status(for: apiUnread).unreadCount == 4)
        #expect(library.status(for: apiUpdated).unreadCount == 1)

        library.markRead(apiUnread)

        #expect(library.status(for: apiUnread) == .none)
    }

    @Test("Removing a series clears the stored baseline")
    func removeClearsStoredBaseline() {
        var library = MangaWatchlistReadStateLibrary()
        library.markRead(makeSeries(id: 10))
        library.markRead(makeSeries(id: 20))

        library.remove(seriesID: 10)

        #expect(library.items.map(\.seriesID) == [20])
    }

    private func makeSeries(
        id: Int,
        latestContentID: Int = 100,
        publishedContentCount: Int = 3,
        apiUnreadContentCount: Int? = nil,
        apiIsUnread: Bool? = nil
    ) -> PixivMangaSeriesPreview {
        PixivMangaSeriesPreview(
            id: id,
            title: "Series \(id)",
            user: nil,
            latestContentID: latestContentID,
            lastPublishedContentDate: nil,
            publishedContentCount: publishedContentCount,
            coverURL: nil,
            maskText: nil,
            apiUnreadContentCount: apiUnreadContentCount,
            apiIsUnread: apiIsUnread
        )
    }
}
