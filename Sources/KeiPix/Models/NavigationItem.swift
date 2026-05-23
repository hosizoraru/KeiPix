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
            [.illustrations, .mangaRecommended, .recommendedUsers, .search, .searchUsers, .savedSearches]
        case .ranking:
            [.rankingDaily, .rankingWeekly, .rankingMonthly]
        case .mangaRanking:
            [.mangaRankingDaily, .mangaRankingWeekly, .mangaRankingMonthly]
        case .library:
            [.publicBookmarks, .privateBookmarks, .following, .followingCreators, .history, .mangaWatchlist, .downloads]
        }
    }
}

enum PixivRoute: String, CaseIterable, Identifiable, Codable {
    case illustrations = "explore"
    case mangaRecommended
    case search
    case searchUsers
    case savedSearches
    case userIllustrations
    case userManga
    case userPublicBookmarks
    case rankingDaily
    case rankingWeekly
    case rankingMonthly
    case mangaRankingDaily
    case mangaRankingWeekly
    case mangaRankingMonthly
    case publicBookmarks
    case privateBookmarks
    case following
    case followingCreators
    case history
    case mangaWatchlist
    case downloads
    case recommendedUsers

    static var sidebarSections: [PixivRouteSection] {
        [.works, .ranking, .mangaRanking, .library]
    }

    var isSidebarRoute: Bool {
        Self.sidebarSections.flatMap(\.routes).contains(self)
    }

    var id: String { rawValue }

    var title: String {
        switch self {
        case .illustrations: L10n.illustrations
        case .mangaRecommended: L10n.manga
        case .search: L10n.search
        case .searchUsers: L10n.searchCreators
        case .savedSearches: L10n.savedSearches
        case .userIllustrations: L10n.creatorIllustrations
        case .userManga: L10n.creatorManga
        case .userPublicBookmarks: L10n.creatorPublicBookmarks
        case .rankingDaily: L10n.daily
        case .rankingWeekly: L10n.weekly
        case .rankingMonthly: L10n.monthly
        case .mangaRankingDaily: L10n.dailyManga
        case .mangaRankingWeekly: L10n.weeklyManga
        case .mangaRankingMonthly: L10n.monthlyManga
        case .publicBookmarks: L10n.publicBookmarks
        case .privateBookmarks: L10n.privateBookmarks
        case .following: L10n.following
        case .followingCreators: L10n.followingCreators
        case .history: L10n.history
        case .mangaWatchlist: L10n.mangaWatchlist
        case .downloads: L10n.downloads
        case .recommendedUsers: L10n.recommendedCreators
        }
    }

    var usesArtworkFeed: Bool {
        switch self {
        case .mangaWatchlist, .downloads, .followingCreators, .recommendedUsers, .searchUsers, .savedSearches:
            false
        default:
            true
        }
    }

    var systemImage: String {
        switch self {
        case .illustrations: "photo.on.rectangle"
        case .mangaRecommended: "book.closed"
        case .recommendedUsers: "person.crop.circle.badge.plus"
        case .search: "magnifyingglass"
        case .searchUsers: "person.crop.circle.badge.questionmark"
        case .savedSearches: "tag.circle"
        case .userIllustrations: "person.crop.rectangle.stack"
        case .userManga: "person.crop.square"
        case .userPublicBookmarks: "person.crop.circle.badge.checkmark"
        case .rankingDaily, .rankingWeekly, .rankingMonthly: "chart.bar"
        case .mangaRankingDaily, .mangaRankingWeekly, .mangaRankingMonthly: "chart.bar.doc.horizontal"
        case .publicBookmarks, .privateBookmarks: "bookmark"
        case .following: "person.2"
        case .followingCreators: "person.2.crop.square.stack"
        case .history: "clock.arrow.circlepath"
        case .mangaWatchlist: "rectangle.stack.badge.person.crop"
        case .downloads: "arrow.down.circle"
        }
    }
}
