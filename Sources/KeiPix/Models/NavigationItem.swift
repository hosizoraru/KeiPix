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
            [
                .rankingDaily,
                .rankingWeekly,
                .rankingMonthly,
                .rankingDailyMale,
                .rankingDailyFemale,
                .rankingWeeklyOriginal,
                .rankingWeeklyRookie,
                .rankingDailyR18
            ]
        case .mangaRanking:
            [.mangaRankingDaily, .mangaRankingWeekly, .mangaRankingMonthly, .mangaRankingDailyR18]
        case .library:
            [
                .publicBookmarks,
                .privateBookmarks,
                .allFollowing,
                .following,
                .privateFollowing,
                .followingCreators,
                .history,
                .mangaWatchlist,
                .downloads
            ]
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
    case rankingDailyMale
    case rankingDailyFemale
    case rankingWeeklyOriginal
    case rankingWeeklyRookie
    case rankingDailyR18
    case mangaRankingDaily
    case mangaRankingWeekly
    case mangaRankingMonthly
    case mangaRankingDailyR18
    case publicBookmarks
    case privateBookmarks
    case allFollowing
    case following
    case privateFollowing
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
        case .rankingDailyMale: L10n.forMale
        case .rankingDailyFemale: L10n.forFemale
        case .rankingWeeklyOriginal: L10n.originals
        case .rankingWeeklyRookie: L10n.rookies
        case .rankingDailyR18: L10n.dailyR18
        case .mangaRankingDaily: L10n.dailyManga
        case .mangaRankingWeekly: L10n.weeklyManga
        case .mangaRankingMonthly: L10n.monthlyManga
        case .mangaRankingDailyR18: L10n.dailyR18Manga
        case .publicBookmarks: L10n.publicBookmarks
        case .privateBookmarks: L10n.privateBookmarks
        case .allFollowing: L10n.allFollowing
        case .following: L10n.following
        case .privateFollowing: L10n.privateFollowing
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

    var isRankingRoute: Bool {
        switch self {
        case .rankingDaily,
             .rankingWeekly,
             .rankingMonthly,
             .rankingDailyMale,
             .rankingDailyFemale,
             .rankingWeeklyOriginal,
             .rankingWeeklyRookie,
             .rankingDailyR18,
             .mangaRankingDaily,
             .mangaRankingWeekly,
             .mangaRankingMonthly,
             .mangaRankingDailyR18:
            true
        default:
            false
        }
    }

    var isOwnBookmarkRoute: Bool {
        self == .publicBookmarks || self == .privateBookmarks
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
        case .rankingDailyMale, .rankingDailyFemale: "person.2"
        case .rankingWeeklyOriginal: "paintpalette"
        case .rankingWeeklyRookie: "sparkles"
        case .rankingDailyR18: "exclamationmark.triangle"
        case .mangaRankingDaily, .mangaRankingWeekly, .mangaRankingMonthly: "chart.bar.doc.horizontal"
        case .mangaRankingDailyR18: "exclamationmark.triangle"
        case .publicBookmarks, .privateBookmarks: "bookmark"
        case .allFollowing: "person.2.wave.2"
        case .following: "person.2"
        case .privateFollowing: "person.2.badge.key"
        case .followingCreators: "person.2.crop.square.stack"
        case .history: "clock.arrow.circlepath"
        case .mangaWatchlist: "rectangle.stack.badge.person.crop"
        case .downloads: "arrow.down.circle"
        }
    }
}
