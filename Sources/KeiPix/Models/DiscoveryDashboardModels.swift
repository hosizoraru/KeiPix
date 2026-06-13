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
                    .spotlight,
                    .pixivCollections
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
                id: "novels",
                title: L10n.novels,
                systemImage: "book",
                routes: [
                    .novelRecommended,
                    .novelLatest,
                    .novelFollowing,
                    .novelSearch,
                    .novelPublicBookmarks,
                    .novelPrivateBookmarks,
                    .novelWatchlist
                ]
            ),
            DiscoveryDashboardSection(
                id: "novel-ranking",
                title: L10n.novelRanking,
                systemImage: "chart.bar",
                routes: [
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
            ),
            DiscoveryDashboardSection(
                id: "library",
                title: L10n.library,
                systemImage: "books.vertical",
                routes: [
                    .publicBookmarks,
                    .privateBookmarks,
                    .bookmarkTags,
                    .savedPixivisionArticles,
                    .myPixivCollections,
                    .savedPixivCollections,
                    .following,
                    .privateFollowing,
                    .history,
                    .watchLater,
                    .workSubscriptions,
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

struct DiscoveryDashboardRoutePreview: Equatable {
    static let compactRouteLimit = 4

    let routes: [PixivRoute]
    let isTruncated: Bool

    init(
        section: DiscoveryDashboardSection,
        isExpanded: Bool,
        selectedRoute: PixivRoute?,
        compactRouteLimit: Int = Self.compactRouteLimit
    ) {
        guard isExpanded == false, section.routes.count > compactRouteLimit else {
            routes = section.routes
            isTruncated = false
            return
        }

        var visibleRoutes = Array(section.routes.prefix(compactRouteLimit))
        if let selectedRoute,
           section.routes.contains(selectedRoute),
           visibleRoutes.contains(selectedRoute) == false {
            visibleRoutes.append(selectedRoute)
        }

        routes = visibleRoutes
        isTruncated = true
    }
}
