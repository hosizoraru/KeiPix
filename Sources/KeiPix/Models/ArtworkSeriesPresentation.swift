import Foundation

enum ArtworkSeriesSortMode: String, CaseIterable, Identifiable, Sendable {
    case seriesOrder
    case newestFirst
    case oldestFirst
    case title

    var id: String { rawValue }

    var title: String {
        switch self {
        case .seriesOrder:
            L10n.seriesOrder
        case .newestFirst:
            L10n.newestFirst
        case .oldestFirst:
            L10n.oldestFirst
        case .title:
            L10n.title
        }
    }
}

enum ArtworkSeriesReadFilter: String, CaseIterable, Identifiable, Sendable {
    case all
    case unread
    case viewed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            L10n.allWorks
        case .unread:
            L10n.unreadWorks
        case .viewed:
            L10n.viewedWorks
        }
    }
}

enum ArtworkSeriesPresentation {
    static func displayedArtworks(
        _ artworks: [PixivArtwork],
        sortMode: ArtworkSeriesSortMode,
        readFilter: ArtworkSeriesReadFilter,
        viewedArtworkIDs: Set<Int>
    ) -> [PixivArtwork] {
        let filtered = artworks.filter { artwork in
            switch readFilter {
            case .all:
                true
            case .unread:
                viewedArtworkIDs.contains(artwork.id) == false
            case .viewed:
                viewedArtworkIDs.contains(artwork.id)
            }
        }

        switch sortMode {
        case .seriesOrder:
            return filtered
        case .newestFirst:
            return filtered.sorted { $0.createDate > $1.createDate }
        case .oldestFirst:
            return filtered.sorted { $0.createDate < $1.createDate }
        case .title:
            return filtered.sorted {
                $0.title.localizedStandardCompare($1.title) == .orderedAscending
            }
        }
    }
}
