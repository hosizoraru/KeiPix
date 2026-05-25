import Foundation

struct DiscoveryDashboardSection: Identifiable {
    let id: String
    let title: String
    let systemImage: String
    let routes: [PixivRoute]

    static var all: [DiscoveryDashboardSection] {
        [
            DiscoveryDashboardSection(
                id: "works",
                title: L10n.works,
                systemImage: "photo.stack",
                routes: [
                    .illustrations,
                    .mangaRecommended,
                    .newIllustrations,
                    .newManga,
                    .trendingTags,
                    .spotlight
                ]
            ),
            DiscoveryDashboardSection(
                id: "creators-search",
                title: L10n.creatorNetwork,
                systemImage: "person.2.crop.square.stack",
                routes: [
                    .search,
                    .searchUsers,
                    .savedSearches,
                    .recommendedUsers,
                    .followingCreators,
                    .pinnedCreators
                ]
            ),
            DiscoveryDashboardSection(
                id: "ranking",
                title: L10n.ranking,
                systemImage: "chart.bar",
                routes: [
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
            ),
            DiscoveryDashboardSection(
                id: "manga-ranking",
                title: L10n.mangaRanking,
                systemImage: "chart.bar.doc.horizontal",
                routes: [
                    .mangaRankingDaily,
                    .mangaRankingWeekly,
                    .mangaRankingMonthly,
                    .mangaRankingDailyR18
                ]
            ),
            DiscoveryDashboardSection(
                id: "library",
                title: L10n.library,
                systemImage: "books.vertical",
                routes: [
                    .publicBookmarks,
                    .privateBookmarks,
                    .bookmarkTags,
                    .allFollowing,
                    .following,
                    .privateFollowing,
                    .history,
                    .mutedContent,
                    .mangaWatchlist,
                    .downloads
                ]
            )
        ]
    }

    static var dashboardRoutes: [PixivRoute] {
        all.flatMap(\.routes)
    }
}
