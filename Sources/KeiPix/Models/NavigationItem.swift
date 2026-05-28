import Foundation

enum PixivRouteSection: Identifiable {
    case works
    case ranking
    case mangaRanking
    case novels
    case novelRanking
    case library

    /// Stable identifier suitable for persistence (e.g. UserDefaults keys).
    /// Unlike `title`, this never changes when the user switches locale.
    var storageID: String {
        switch self {
        case .works: "works"
        case .ranking: "ranking"
        case .mangaRanking: "mangaRanking"
        case .novels: "novels"
        case .novelRanking: "novelRanking"
        case .library: "library"
        }
    }

    var id: String { storageID }

    var title: String {
        switch self {
        case .works: L10n.works
        case .ranking: L10n.ranking
        case .mangaRanking: L10n.mangaRanking
        case .novels: L10n.novels
        case .novelRanking: L10n.novelRanking
        case .library: L10n.library
        }
    }

    var routes: [PixivRoute] {
        switch self {
        case .works:
            [
                .home,
                .illustrations,
                .mangaRecommended,
                .newIllustrations,
                .newManga,
                .trendingTags,
                .spotlight,
                .recommendedUsers,
                .search,
                .searchUsers,
                .savedSearches
            ]
        case .ranking:
            [
                .rankingDaily,
                .rankingWeekly,
                .rankingMonthly,
                .rankingDailyMale,
                .rankingDailyFemale,
                .rankingWeeklyOriginal,
                .rankingWeeklyRookie,
                .rankingDailyAI,
                .rankingDailyR18AI,
                .rankingDailyR18,
                .rankingWeeklyR18,
                .rankingWeeklyR18G
            ]
        case .mangaRanking:
            [.mangaRankingDaily, .mangaRankingWeekly, .mangaRankingMonthly, .mangaRankingDailyR18]
        case .novels:
            [
                .novelRecommended,
                .novelFollowing,
                .novelSearch,
                .novelPublicBookmarks,
                .novelPrivateBookmarks,
                .novelWatchlist
            ]
        case .novelRanking:
            [
                .novelRankingDaily,
                .novelRankingWeekly,
                .novelRankingMonthly,
                .novelRankingDailyMale,
                .novelRankingDailyFemale,
                .novelRankingWeeklyRookie,
                .novelRankingWeeklyAI,
                .novelRankingDailyR18,
                .novelRankingWeeklyR18,
                .novelRankingWeeklyR18AI,
                .novelRankingWeeklyR18G
            ]
        case .library:
            [
                .publicBookmarks,
                .privateBookmarks,
                .bookmarkTags,
                .allFollowing,
                .following,
                .privateFollowing,
                .followingCreators,
                .pinnedCreators,
                .history,
                .watchLater,
                .workSubscriptions,
                .mutedContent,
                .mangaWatchlist,
                .downloads
            ]
        }
    }
}

enum PixivRankingFamily: String, CaseIterable {
    case illustration
    case manga
    case novel
}

enum PixivRoute: String, CaseIterable, Identifiable, Codable {
    case home
    case illustrations = "explore"
    case mangaRecommended
    case newIllustrations
    case newManga
    case trendingTags
    case spotlight
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
    case rankingDailyAI
    case rankingDailyR18AI
    case rankingDailyR18
    case rankingWeeklyR18
    case rankingWeeklyR18G
    case mangaRankingDaily
    case mangaRankingWeekly
    case mangaRankingMonthly
    case mangaRankingDailyR18
    case publicBookmarks
    case privateBookmarks
    case bookmarkTags
    case allFollowing
    case following
    case privateFollowing
    case followingCreators
    case pinnedCreators
    case history
    case watchLater
    case workSubscriptions
    case mutedContent
    case mangaWatchlist
    case downloads
    case recommendedUsers
    // MARK: Novels
    case novelRecommended
    case novelFollowing
    case novelSearch
    case novelPublicBookmarks
    case novelPrivateBookmarks
    case novelWatchlist
    case novelRankingDaily
    case novelRankingWeekly
    case novelRankingMonthly
    case novelRankingDailyMale
    case novelRankingDailyFemale
    case novelRankingWeeklyRookie
    case novelRankingWeeklyAI
    case novelRankingDailyR18
    case novelRankingWeeklyR18
    case novelRankingWeeklyR18AI
    case novelRankingWeeklyR18G
    case userNovels
    case userNovelBookmarks

    static var sidebarSections: [PixivRouteSection] {
        [.works, .ranking, .mangaRanking, .novels, .novelRanking, .library]
    }

    var isSidebarRoute: Bool {
        Self.sidebarSections.flatMap(\.routes).contains(self)
    }

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: L10n.discover
        case .illustrations: L10n.illustrations
        case .mangaRecommended: L10n.manga
        case .newIllustrations: L10n.newIllustrations
        case .newManga: L10n.newManga
        case .trendingTags: L10n.trendingTags
        case .spotlight: L10n.spotlight
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
        case .rankingDailyAI: L10n.dailyAI
        case .rankingDailyR18AI: L10n.dailyR18AI
        case .rankingDailyR18: L10n.dailyR18
        case .rankingWeeklyR18: L10n.weeklyR18
        case .rankingWeeklyR18G: L10n.weeklyR18G
        case .mangaRankingDaily: L10n.dailyManga
        case .mangaRankingWeekly: L10n.weeklyManga
        case .mangaRankingMonthly: L10n.monthlyManga
        case .mangaRankingDailyR18: L10n.dailyR18Manga
        case .publicBookmarks: L10n.publicBookmarks
        case .privateBookmarks: L10n.privateBookmarks
        case .bookmarkTags: L10n.bookmarkTags
        case .allFollowing: L10n.allFollowing
        case .following: L10n.following
        case .privateFollowing: L10n.privateFollowing
        case .followingCreators: L10n.followingCreators
        case .pinnedCreators: L10n.pinnedCreators
        case .history: L10n.history
        case .watchLater: L10n.watchLater
        case .workSubscriptions: L10n.workSubscriptions
        case .mutedContent: L10n.mutedContent
        case .mangaWatchlist: L10n.mangaWatchlist
        case .downloads: L10n.downloads
        case .recommendedUsers: L10n.recommendedCreators
        case .novelRecommended: L10n.recommendedNovels
        case .novelFollowing: L10n.followingNovels
        case .novelSearch: L10n.searchNovels
        case .novelPublicBookmarks: L10n.novelPublicBookmarks
        case .novelPrivateBookmarks: L10n.novelPrivateBookmarks
        case .novelWatchlist: L10n.novelWatchlist
        case .novelRankingDaily: L10n.daily
        case .novelRankingWeekly: L10n.weekly
        case .novelRankingMonthly: L10n.monthly
        case .novelRankingDailyMale: L10n.forMale
        case .novelRankingDailyFemale: L10n.forFemale
        case .novelRankingWeeklyRookie: L10n.rookies
        case .novelRankingWeeklyAI: L10n.weeklyAI
        case .novelRankingDailyR18: L10n.dailyR18
        case .novelRankingWeeklyR18: L10n.weeklyR18
        case .novelRankingWeeklyR18AI: L10n.weeklyR18AI
        case .novelRankingWeeklyR18G: L10n.weeklyR18G
        case .userNovels: L10n.creatorNovels
        case .userNovelBookmarks: L10n.creatorNovelBookmarks
        }
    }

    var usesArtworkFeed: Bool {
        switch self {
        case .home,
             .mangaWatchlist,
             .downloads,
             .followingCreators,
             .pinnedCreators,
             .recommendedUsers,
             .searchUsers,
             .savedSearches,
             .trendingTags,
             .spotlight,
             .bookmarkTags,
             .mutedContent,
             .watchLater,
             .novelRecommended,
             .novelFollowing,
             .novelSearch,
             .novelPublicBookmarks,
             .novelPrivateBookmarks,
             .novelWatchlist,
             .novelRankingDaily,
             .novelRankingWeekly,
             .novelRankingMonthly,
             .novelRankingDailyMale,
             .novelRankingDailyFemale,
             .novelRankingWeeklyRookie,
             .novelRankingWeeklyAI,
             .novelRankingDailyR18,
             .novelRankingWeeklyR18,
             .novelRankingWeeklyR18AI,
             .novelRankingWeeklyR18G,
             .userNovels,
             .userNovelBookmarks:
            false
        default:
            true
        }
    }

    var usesNovelFeed: Bool {
        switch self {
        case .novelRecommended,
             .novelFollowing,
             .novelSearch,
             .novelPublicBookmarks,
             .novelPrivateBookmarks,
             .novelWatchlist,
             .novelRankingDaily,
             .novelRankingWeekly,
             .novelRankingMonthly,
             .novelRankingDailyMale,
             .novelRankingDailyFemale,
             .novelRankingWeeklyRookie,
             .novelRankingWeeklyAI,
             .novelRankingDailyR18,
             .novelRankingWeeklyR18,
             .novelRankingWeeklyR18AI,
             .novelRankingWeeklyR18G,
             .userNovels,
             .userNovelBookmarks:
            true
        default:
            false
        }
    }

    var isRankingRoute: Bool {
        rankingFamily != nil
    }

    var rankingFamily: PixivRankingFamily? {
        if Self.illustrationRankingRoutes.contains(self) {
            return .illustration
        }
        if Self.mangaRankingRoutes.contains(self) {
            return .manga
        }
        if Self.novelRankingRoutes.contains(self) {
            return .novel
        }
        return nil
    }

    /// pixiv `mode` query value for the ranking endpoints. Returns `nil` for
    /// non-ranking routes so callers can short-circuit on the optional.
    var rankingMode: String? {
        switch self {
        case .rankingDaily, .mangaRankingDaily, .novelRankingDaily: "day"
        case .rankingWeekly, .mangaRankingWeekly, .novelRankingWeekly: "week"
        case .rankingMonthly, .mangaRankingMonthly, .novelRankingMonthly: "month"
        case .rankingDailyMale, .novelRankingDailyMale: "day_male"
        case .rankingDailyFemale, .novelRankingDailyFemale: "day_female"
        case .rankingWeeklyOriginal: "week_original"
        case .rankingWeeklyRookie, .novelRankingWeeklyRookie: "week_rookie"
        case .rankingDailyAI: "day_ai"
        case .rankingDailyR18AI: "day_r18_ai"
        case .rankingDailyR18, .mangaRankingDailyR18, .novelRankingDailyR18: "day_r18"
        case .rankingWeeklyR18, .novelRankingWeeklyR18: "week_r18"
        case .rankingWeeklyR18G, .novelRankingWeeklyR18G: "week_r18g"
        case .novelRankingWeeklyAI: "week_ai"
        case .novelRankingWeeklyR18AI: "week_ai_r18"
        default: nil
        }
    }

    static var illustrationRankingRoutes: [PixivRoute] {
        [
            .rankingDaily,
            .rankingWeekly,
            .rankingMonthly,
            .rankingDailyMale,
            .rankingDailyFemale,
            .rankingWeeklyOriginal,
            .rankingWeeklyRookie,
            .rankingDailyAI,
            .rankingDailyR18AI,
            .rankingDailyR18,
            .rankingWeeklyR18,
            .rankingWeeklyR18G
        ]
    }

    static var mangaRankingRoutes: [PixivRoute] {
        [
            .mangaRankingDaily,
            .mangaRankingWeekly,
            .mangaRankingMonthly,
            .mangaRankingDailyR18
        ]
    }

    static var novelRankingRoutes: [PixivRoute] {
        [
            .novelRankingDaily,
            .novelRankingWeekly,
            .novelRankingMonthly,
            .novelRankingDailyMale,
            .novelRankingDailyFemale,
            .novelRankingWeeklyRookie,
            .novelRankingWeeklyAI,
            .novelRankingDailyR18,
            .novelRankingWeeklyR18,
            .novelRankingWeeklyR18AI,
            .novelRankingWeeklyR18G
        ]
    }

    static func rankingRoutes(for family: PixivRankingFamily) -> [PixivRoute] {
        switch family {
        case .illustration:
            illustrationRankingRoutes
        case .manga:
            mangaRankingRoutes
        case .novel:
            novelRankingRoutes
        }
    }

    var isOwnBookmarkRoute: Bool {
        self == .publicBookmarks || self == .privateBookmarks
    }

    var isOwnNovelBookmarkRoute: Bool {
        self == .novelPublicBookmarks || self == .novelPrivateBookmarks
    }

    var systemImage: String {
        switch self {
        case .home: "square.grid.2x2"
        case .illustrations: "photo.on.rectangle"
        case .mangaRecommended: "book.closed"
        case .newIllustrations: "sparkle.magnifyingglass"
        case .newManga: "book.pages"
        case .trendingTags: "number"
        case .spotlight: "newspaper"
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
        case .rankingDailyAI: "sparkles"
        case .rankingDailyR18AI: "sparkles.rectangle.stack"
        case .rankingDailyR18, .rankingWeeklyR18: "exclamationmark.triangle"
        case .rankingWeeklyR18G: "exclamationmark.octagon"
        case .mangaRankingDaily, .mangaRankingWeekly, .mangaRankingMonthly: "chart.bar.doc.horizontal"
        case .mangaRankingDailyR18: "exclamationmark.triangle"
        case .publicBookmarks, .privateBookmarks: "bookmark"
        case .bookmarkTags: "tag"
        case .allFollowing: "person.2.wave.2"
        case .following: "person.2"
        case .privateFollowing: "person.2.badge.key"
        case .followingCreators: "person.2.crop.square.stack"
        case .pinnedCreators: "pin"
        case .history: "clock.arrow.circlepath"
        case .watchLater: "bookmark.circle"
        case .workSubscriptions: "bell.badge"
        case .mutedContent: "eye.slash"
        case .mangaWatchlist: "rectangle.stack.badge.person.crop"
        case .downloads: "arrow.down.circle"
        case .novelRecommended: "book"
        case .novelFollowing: "book.and.wrench"
        case .novelSearch: "text.magnifyingglass"
        case .novelPublicBookmarks, .novelPrivateBookmarks: "bookmark.square"
        case .novelWatchlist: "books.vertical"
        case .novelRankingDaily, .novelRankingWeekly, .novelRankingMonthly: "chart.bar.doc.horizontal"
        case .novelRankingDailyMale, .novelRankingDailyFemale: "person.2"
        case .novelRankingWeeklyRookie: "sparkles"
        case .novelRankingWeeklyAI, .novelRankingWeeklyR18AI: "sparkles.rectangle.stack"
        case .novelRankingDailyR18, .novelRankingWeeklyR18: "exclamationmark.triangle"
        case .novelRankingWeeklyR18G: "exclamationmark.octagon"
        case .userNovels: "person.crop.rectangle"
        case .userNovelBookmarks: "person.crop.circle.badge.checkmark"
        }
    }
}
