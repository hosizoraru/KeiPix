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

    @Test("Watchlist selection toggles all visible series and prunes hidden ids")
    func watchlistSelectionTracksVisibleSeries() {
        var selection = MangaWatchlistSelection()

        selection.toggle(10)
        selection.toggle(20)
        selection.isSelectionMode = true

        #expect(selection.contains(10))
        #expect(selection.contains(20))
        #expect(selection.count == 2)

        selection.toggle(10)
        #expect(selection.selectedIDs == [20])

        selection.selectAll([30, 40])
        #expect(selection.selectedIDs == [20, 30, 40])

        selection.prune(visibleSeriesIDs: [30, 50])
        #expect(selection.selectedIDs == [30])
        #expect(selection.isSelectionMode)

        selection.prune(visibleSeriesIDs: [50])
        #expect(selection.selectedIDs.isEmpty)
        #expect(selection.isSelectionMode == false)
    }

    @Test("Presentation filters by query across title creator and account")
    func presentationFiltersByQueryAcrossSeriesMetadata() {
        let presentation = MangaWatchlistPresentation(query: "panel")
        let visible = presentation.visibleSeries(from: [
            makeSeries(id: 10, title: "Weekend Panels", userName: "Aki", account: "aki"),
            makeSeries(id: 20, title: "Quiet Study", userName: "Panel Artist", account: "daily"),
            makeSeries(id: 30, title: "Garden", userName: "Mika", account: "mika_panel"),
            makeSeries(id: 40, title: "Kitchen", userName: "Mika", account: "mika")
        ]) { _ in .none }

        #expect(visible.map(\.id) == [10, 20, 30])
    }

    @Test("Presentation update filter uses local watchlist status")
    func presentationUpdateFilterUsesLocalStatus() {
        let presentation = MangaWatchlistPresentation(filter: .updated)
        let visible = presentation.visibleSeries(from: [
            makeSeries(id: 10),
            makeSeries(id: 20),
            makeSeries(id: 30)
        ]) { series in
            series.id == 20 ? MangaWatchlistUpdateStatus(hasUpdate: true, unreadCount: 2) : .none
        }

        #expect(visible.map(\.id) == [20])
    }

    @Test("Presentation sort can prioritize unread updates")
    func presentationSortPrioritizesUnreadUpdates() {
        let presentation = MangaWatchlistPresentation(sort: .unreadUpdates)
        let visible = presentation.visibleSeries(from: [
            makeSeries(id: 10, title: "B", lastPublishedContentDate: Date(timeIntervalSince1970: 200), publishedContentCount: 1),
            makeSeries(id: 20, title: "A", lastPublishedContentDate: Date(timeIntervalSince1970: 100), publishedContentCount: 1),
            makeSeries(id: 30, title: "C", lastPublishedContentDate: Date(timeIntervalSince1970: 300), publishedContentCount: 1)
        ]) { series in
            switch series.id {
            case 10:
                MangaWatchlistUpdateStatus(hasUpdate: true, unreadCount: 1)
            case 20:
                MangaWatchlistUpdateStatus(hasUpdate: true, unreadCount: 4)
            default:
                .none
            }
        }

        #expect(visible.map(\.id) == [20, 10, 30])
    }

    @Test("Presentation sort can order by latest publish date and work count")
    func presentationSortsByDateAndWorkCount() {
        let series = [
            makeSeries(id: 10, title: "B", lastPublishedContentDate: Date(timeIntervalSince1970: 100), publishedContentCount: 8),
            makeSeries(id: 20, title: "A", lastPublishedContentDate: Date(timeIntervalSince1970: 300), publishedContentCount: 3),
            makeSeries(id: 30, title: "C", lastPublishedContentDate: Date(timeIntervalSince1970: 200), publishedContentCount: 8)
        ]

        #expect(
            MangaWatchlistPresentation(sort: .recentlyUpdated)
                .visibleSeries(from: series) { _ in .none }
                .map(\.id) == [20, 30, 10]
        )
        #expect(
            MangaWatchlistPresentation(sort: .publishedCount)
                .visibleSeries(from: series) { _ in .none }
                .map(\.id) == [30, 10, 20]
        )
    }

    private func makeSeries(
        id: Int,
        title: String? = nil,
        userName: String? = nil,
        account: String? = nil,
        latestContentID: Int = 100,
        lastPublishedContentDate: Date? = nil,
        publishedContentCount: Int = 3,
        apiUnreadContentCount: Int? = nil,
        apiIsUnread: Bool? = nil
    ) -> PixivMangaSeriesPreview {
        PixivMangaSeriesPreview(
            id: id,
            title: title ?? "Series \(id)",
            user: userName.map { name in
                PixivMangaSeriesUser(user: PixivUser(
                    id: id + 1_000,
                    name: name,
                    account: account ?? ""
                ))
            },
            latestContentID: latestContentID,
            lastPublishedContentDate: lastPublishedContentDate,
            publishedContentCount: publishedContentCount,
            coverURL: nil,
            maskText: nil,
            apiUnreadContentCount: apiUnreadContentCount,
            apiIsUnread: apiIsUnread
        )
    }
}
