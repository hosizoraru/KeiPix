import Foundation

enum DiscoveryDashboardCardKind: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case highlights
    case forYou
    case tagRecommendations
    case metrics
    case routeGroups

    var id: String { rawValue }

    var title: String {
        switch self {
        case .highlights:
            L10n.discoveryHighlights
        case .forYou:
            L10n.discoveryForYou
        case .tagRecommendations:
            L10n.recommendedTags
        case .metrics:
            L10n.discoveryMetrics
        case .routeGroups:
            L10n.dashboardSections
        }
    }

    var systemImage: String {
        switch self {
        case .highlights:
            "sparkles.rectangle.stack"
        case .forYou:
            "person.crop.circle.badge.sparkles"
        case .tagRecommendations:
            "number"
        case .metrics:
            "chart.bar.xaxis"
        case .routeGroups:
            "rectangle.grid.2x2"
        }
    }

    static let defaultOrder: [DiscoveryDashboardCardKind] = [
        .highlights,
        .forYou,
        .tagRecommendations,
        .metrics,
        .routeGroups
    ]

    static let defaultHiddenIDs: Set<String> = [
        DiscoveryDashboardCardKind.routeGroups.id
    ]

    static var defaultVisibleOrder: [DiscoveryDashboardCardKind] {
        defaultOrder.filter { defaultHiddenIDs.contains($0.id) == false }
    }

    static func ordered(from storageID: String?) -> [DiscoveryDashboardCardKind] {
        let stored = (storageID ?? "")
            .split(separator: ",")
            .compactMap { DiscoveryDashboardCardKind(rawValue: String($0)) }

        var seen = Set<DiscoveryDashboardCardKind>()
        var ordered = stored.filter { seen.insert($0).inserted }
        for card in defaultOrder where seen.insert(card).inserted {
            ordered.append(card)
        }
        return ordered.isEmpty ? defaultOrder : ordered
    }

    static func storageID(for cards: [DiscoveryDashboardCardKind]) -> String {
        cards.map(\.rawValue).joined(separator: ",")
    }

    static func visibleCards(order: [DiscoveryDashboardCardKind], hiddenIDs: Set<String>) -> [DiscoveryDashboardCardKind] {
        let visible = order.filter { hiddenIDs.contains($0.id) == false }
        return visible.isEmpty ? defaultVisibleOrder : visible
    }

    static func hiddenIDs(
        afterSetting visible: Bool,
        for card: DiscoveryDashboardCardKind,
        currentHiddenIDs: Set<String>,
        order: [DiscoveryDashboardCardKind]
    ) -> Set<String> {
        var hiddenIDs = currentHiddenIDs
        if visible {
            hiddenIDs.remove(card.id)
            return hiddenIDs
        }

        let visibleCount = order.filter { hiddenIDs.contains($0.id) == false }.count
        guard visibleCount > 1 else { return hiddenIDs }
        hiddenIDs.insert(card.id)
        return hiddenIDs
    }

    static func moved(
        _ card: DiscoveryDashboardCardKind,
        offset: Int,
        in order: [DiscoveryDashboardCardKind]
    ) -> [DiscoveryDashboardCardKind] {
        guard let sourceIndex = order.firstIndex(of: card), order.isEmpty == false else { return order }

        let destinationIndex = max(0, min(order.count - 1, sourceIndex + offset))
        guard destinationIndex != sourceIndex else { return order }

        var cards = order
        cards.remove(at: sourceIndex)
        cards.insert(card, at: destinationIndex)
        return cards
    }
}

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
                    .pixivCollections,
                    .pixivActivity
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
                    .followingCreators
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
                    .bookmarkTags,
                    .savedPixivisionArticles,
                    .myPixivCollections,
                    .following,
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
