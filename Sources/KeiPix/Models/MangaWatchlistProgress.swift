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

struct MangaWatchlistSelection: Hashable, Sendable {
    var selectedIDs: Set<Int> = []
    var isSelectionMode = false

    var count: Int { selectedIDs.count }
    var hasSelection: Bool { selectedIDs.isEmpty == false }

    func contains(_ seriesID: Int) -> Bool {
        selectedIDs.contains(seriesID)
    }

    mutating func toggle(_ seriesID: Int) {
        if selectedIDs.contains(seriesID) {
            selectedIDs.remove(seriesID)
        } else {
            selectedIDs.insert(seriesID)
        }
    }

    mutating func selectAll(_ seriesIDs: some Sequence<Int>) {
        selectedIDs.formUnion(seriesIDs)
    }

    mutating func clear() {
        selectedIDs.removeAll()
        isSelectionMode = false
    }

    mutating func prune(visibleSeriesIDs: some Sequence<Int>) {
        selectedIDs.formIntersection(Set(visibleSeriesIDs))
        if selectedIDs.isEmpty {
            isSelectionMode = false
        }
    }
}

enum MangaWatchlistFilter: String, CaseIterable, Identifiable, Sendable {
    case all
    case updated
    case caughtUp

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            L10n.all
        case .updated:
            L10n.updatedSeries
        case .caughtUp:
            L10n.noUpdates
        }
    }

    var systemImage: String {
        switch self {
        case .all:
            "rectangle.stack"
        case .updated:
            "sparkle.magnifyingglass"
        case .caughtUp:
            "checkmark.circle"
        }
    }

    func includes(_ status: MangaWatchlistUpdateStatus) -> Bool {
        switch self {
        case .all:
            true
        case .updated:
            status.hasUpdate
        case .caughtUp:
            status.hasUpdate == false
        }
    }
}

enum MangaWatchlistSort: String, CaseIterable, Identifiable, Sendable {
    case defaultOrder
    case recentlyUpdated
    case unreadUpdates
    case title
    case publishedCount

    var id: String { rawValue }

    var title: String {
        switch self {
        case .defaultOrder:
            L10n.defaultOrder
        case .recentlyUpdated:
            L10n.recentlyUpdated
        case .unreadUpdates:
            L10n.unreadUpdates
        case .title:
            L10n.title
        case .publishedCount:
            L10n.seriesCount
        }
    }

    var systemImage: String {
        switch self {
        case .defaultOrder:
            "arrow.up.arrow.down"
        case .recentlyUpdated:
            "calendar.badge.clock"
        case .unreadUpdates:
            "text.badge.checkmark"
        case .title:
            "textformat"
        case .publishedCount:
            "number"
        }
    }
}

struct MangaWatchlistPresentation: Hashable, Sendable {
    var query: String = ""
    var filter: MangaWatchlistFilter = .all
    var sort: MangaWatchlistSort = .defaultOrder

    func visibleSeries(
        from series: [PixivMangaSeriesPreview],
        statusProvider: (PixivMangaSeriesPreview) -> MangaWatchlistUpdateStatus
    ) -> [PixivMangaSeriesPreview] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let filtered = series.filter { item in
            let status = statusProvider(item)
            return item.matchesMangaWatchlistQuery(normalizedQuery)
                && filter.includes(status)
        }

        switch sort {
        case .defaultOrder:
            return filtered
        case .recentlyUpdated:
            return filtered.sorted { lhs, rhs in
                compareByPublishedDate(lhs, rhs)
            }
        case .unreadUpdates:
            return filtered.sorted { lhs, rhs in
                let lhsStatus = statusProvider(lhs)
                let rhsStatus = statusProvider(rhs)
                if lhsStatus.hasUpdate != rhsStatus.hasUpdate {
                    return lhsStatus.hasUpdate
                }
                if lhsStatus.unreadCount != rhsStatus.unreadCount {
                    return lhsStatus.unreadCount > rhsStatus.unreadCount
                }
                return compareByPublishedDate(lhs, rhs)
            }
        case .title:
            return filtered.sorted { lhs, rhs in
                lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
            }
        case .publishedCount:
            return filtered.sorted { lhs, rhs in
                if lhs.publishedContentCount != rhs.publishedContentCount {
                    return lhs.publishedContentCount > rhs.publishedContentCount
                }
                return compareByPublishedDate(lhs, rhs)
            }
        }
    }

    private func compareByPublishedDate(
        _ lhs: PixivMangaSeriesPreview,
        _ rhs: PixivMangaSeriesPreview
    ) -> Bool {
        switch (lhs.lastPublishedContentDate, rhs.lastPublishedContentDate) {
        case let (lhsDate?, rhsDate?) where lhsDate != rhsDate:
            return lhsDate > rhsDate
        case (_?, nil):
            return true
        case (nil, _?):
            return false
        default:
            return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
        }
    }
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

extension PixivMangaSeriesPreview {
    func matchesMangaWatchlistQuery(_ query: String) -> Bool {
        guard query.isEmpty == false else { return true }
        return title.localizedCaseInsensitiveContains(query)
            || user?.name.localizedCaseInsensitiveContains(query) == true
            || user?.account?.localizedCaseInsensitiveContains(query) == true
    }
}
