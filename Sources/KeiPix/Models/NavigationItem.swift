import Foundation

enum PixivRouteSection: Identifiable {
    case works
    case ranking
    case mangaRanking
    case library

    var id: String { title }

    var title: String {
        switch self {
        case .works: L10n.works
        case .ranking: L10n.ranking
        case .mangaRanking: L10n.mangaRanking
        case .library: L10n.library
        }
    }

    var routes: [PixivRoute] {
        switch self {
        case .works:
            [.illustrations, .mangaRecommended, .search]
        case .ranking:
            [.rankingDaily, .rankingWeekly, .rankingMonthly]
        case .mangaRanking:
            [.mangaRankingDaily, .mangaRankingWeekly, .mangaRankingMonthly]
        case .library:
            [.publicBookmarks, .privateBookmarks, .following]
        }
    }
}

enum PixivRoute: String, CaseIterable, Identifiable, Codable {
    case illustrations = "explore"
    case mangaRecommended
    case search
    case rankingDaily
    case rankingWeekly
    case rankingMonthly
    case mangaRankingDaily
    case mangaRankingWeekly
    case mangaRankingMonthly
    case publicBookmarks
    case privateBookmarks
    case following

    static var sidebarSections: [PixivRouteSection] {
        [.works, .ranking, .mangaRanking, .library]
    }

    var id: String { rawValue }

    var title: String {
        switch self {
        case .illustrations: L10n.illustrations
        case .mangaRecommended: L10n.manga
        case .search: L10n.search
        case .rankingDaily: L10n.daily
        case .rankingWeekly: L10n.weekly
        case .rankingMonthly: L10n.monthly
        case .mangaRankingDaily: L10n.dailyManga
        case .mangaRankingWeekly: L10n.weeklyManga
        case .mangaRankingMonthly: L10n.monthlyManga
        case .publicBookmarks: L10n.publicBookmarks
        case .privateBookmarks: L10n.privateBookmarks
        case .following: L10n.following
        }
    }

    var systemImage: String {
        switch self {
        case .illustrations: "photo.on.rectangle"
        case .mangaRecommended: "book.closed"
        case .search: "magnifyingglass"
        case .rankingDaily, .rankingWeekly, .rankingMonthly: "chart.bar"
        case .mangaRankingDaily, .mangaRankingWeekly, .mangaRankingMonthly: "chart.bar.doc.horizontal"
        case .publicBookmarks, .privateBookmarks: "bookmark"
        case .following: "person.2"
        }
    }
}
