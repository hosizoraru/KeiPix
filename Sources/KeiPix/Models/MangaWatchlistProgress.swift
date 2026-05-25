import Foundation

struct MangaWatchlistReadState: Codable, Hashable, Sendable {
    let seriesID: Int
    var latestContentID: Int
    var publishedContentCount: Int
    var updatedAt: Date
}

struct MangaWatchlistUpdateStatus: Hashable, Sendable {
    let hasUpdate: Bool
    let unreadCount: Int

    static let none = MangaWatchlistUpdateStatus(hasUpdate: false, unreadCount: 0)
}

struct MangaWatchlistReadStateLibrary: Codable, Hashable, Sendable {
    private(set) var items: [MangaWatchlistReadState]

    init(items: [MangaWatchlistReadState] = []) {
        self.items = items.sorted { $0.updatedAt > $1.updatedAt }
    }

    func status(for series: PixivMangaSeriesPreview) -> MangaWatchlistUpdateStatus {
        let state = items.first { $0.seriesID == series.id }
        if series.hasAPIUnreadUpdate {
            if let state, state.covers(series) {
                return .none
            }
            return MangaWatchlistUpdateStatus(
                hasUpdate: true,
                unreadCount: max(series.apiUnreadContentCount ?? 1, 1)
            )
        }

        guard let state else {
            return .none
        }

        let countDelta = max(series.publishedContentCount - state.publishedContentCount, 0)
        let latestChanged = series.latestContentID != 0 && series.latestContentID != state.latestContentID
        guard latestChanged || countDelta > 0 else { return .none }

        return MangaWatchlistUpdateStatus(
            hasUpdate: true,
            unreadCount: max(countDelta, 1)
        )
    }

    mutating func registerSnapshot(_ series: [PixivMangaSeriesPreview], now: Date = Date()) {
        let knownIDs = Set(items.map(\.seriesID))
        for item in series where knownIDs.contains(item.id) == false && item.hasAPIUnreadUpdate == false {
            markRead(item, now: now)
        }
    }

    mutating func markRead(_ series: PixivMangaSeriesPreview, now: Date = Date(), limit: Int = 500) {
        items.removeAll { $0.seriesID == series.id }
        items.insert(
            MangaWatchlistReadState(
                seriesID: series.id,
                latestContentID: series.latestContentID,
                publishedContentCount: series.publishedContentCount,
                updatedAt: now
            ),
            at: 0
        )

        if items.count > limit {
            items = Array(items.prefix(limit))
        }
    }

    mutating func remove(seriesID: Int) {
        items.removeAll { $0.seriesID == seriesID }
    }
}

private extension MangaWatchlistReadState {
    func covers(_ series: PixivMangaSeriesPreview) -> Bool {
        latestContentID == series.latestContentID
            && publishedContentCount >= series.publishedContentCount
    }
}

private extension PixivMangaSeriesPreview {
    var hasAPIUnreadUpdate: Bool {
        apiIsUnread == true || (apiUnreadContentCount ?? 0) > 0
    }
}
