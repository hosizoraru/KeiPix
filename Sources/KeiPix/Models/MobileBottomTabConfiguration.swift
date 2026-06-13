import CoreGraphics
import Foundation

enum MobileBottomTabKind: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case illustrations
    case manga
    case novels
    case bookmarks

    var id: String { rawValue }

    var title: String {
        switch self {
        case .illustrations: L10n.illustrations
        case .manga: L10n.manga
        case .novels: L10n.novels
        case .bookmarks: L10n.mobileBookmarkTab
        }
    }

    var systemImage: String {
        switch self {
        case .illustrations: "photo.on.rectangle"
        case .manga: "book.pages"
        case .novels: "book"
        case .bookmarks: "bookmark"
        }
    }

    var defaultRoute: PixivRoute {
        switch self {
        case .illustrations: .illustrations
        case .manga: .mangaRecommended
        case .novels: .novelRecommended
        case .bookmarks: .publicBookmarks
        }
    }

    var menuSections: [MobileRouteMenuSection] {
        MobileRouteMenuConfiguration.sections(for: self)
    }

    var routes: [PixivRoute] {
        menuSections.flatMap(\.routes)
    }

    func contains(_ route: PixivRoute) -> Bool {
        routes.contains(route)
    }

    static func kind(containing route: PixivRoute) -> MobileBottomTabKind? {
        if route == .pixivCollectionWorks {
            return .illustrations
        }
        return allCases.first { $0.contains(route) }
    }
}

struct MobileBottomTabDefaultRoute: Identifiable, Equatable {
    let kind: MobileBottomTabKind
    let route: PixivRoute

    var id: String { kind.id }
}

enum MobileBottomTabLaunchTarget: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case lastUsed
    case illustrations
    case manga
    case novels
    case bookmarks

    var id: String { rawValue }

    var title: String {
        switch self {
        case .lastUsed: L10n.mobileBottomTabLaunchLastUsed
        case .illustrations: MobileBottomTabKind.illustrations.title
        case .manga: MobileBottomTabKind.manga.title
        case .novels: MobileBottomTabKind.novels.title
        case .bookmarks: MobileBottomTabKind.bookmarks.title
        }
    }

    var systemImage: String {
        switch self {
        case .lastUsed: "clock.arrow.circlepath"
        case .illustrations: MobileBottomTabKind.illustrations.systemImage
        case .manga: MobileBottomTabKind.manga.systemImage
        case .novels: MobileBottomTabKind.novels.systemImage
        case .bookmarks: MobileBottomTabKind.bookmarks.systemImage
        }
    }

    var fixedKind: MobileBottomTabKind? {
        switch self {
        case .lastUsed: nil
        case .illustrations: .illustrations
        case .manga: .manga
        case .novels: .novels
        case .bookmarks: .bookmarks
        }
    }

    func resolvedKind(lastUsedKindID: String) -> MobileBottomTabKind {
        if let fixedKind {
            return fixedKind
        }
        return MobileBottomTabKind(rawValue: lastUsedKindID) ?? .illustrations
    }
}

enum MobileSearchTabConfiguration {
    static let routes: [PixivRoute] = [
        .search,
        .searchUsers,
        .novelSearch,
        .trendingTags,
        .savedSearches
    ]

    static func contains(_ route: PixivRoute) -> Bool {
        routes.contains(route)
    }
}

enum MobileBottomTabConfiguration {
    enum DefaultsKey {
        static let defaultRouteIDs = "mobileBottomTabItemIDs"
        static let launchTarget = "mobileBottomTabLaunchTarget"
        static let remembersLastRoute = "mobileBottomTabRemembersLastRoute"
        static let lastKind = "mobileBottomTabLastKind"
        static let rememberedRouteIDs = "mobileBottomTabRememberedRouteIDs"
    }

    static let fixedKinds = MobileBottomTabKind.allCases
    static let defaultLaunchTarget = MobileBottomTabLaunchTarget.lastUsed
    static let defaultLastUsedKind = MobileBottomTabKind.illustrations
    static let defaultRemembersLastRoute = true

    static var defaultRouteMap: [MobileBottomTabKind: PixivRoute] {
        Dictionary(uniqueKeysWithValues: fixedKinds.map { kind in
            (kind, kind.defaultRoute)
        })
    }

    static var defaultStorageID: String {
        storageID(for: defaultRouteMap)
    }

    static func defaultRouteMap(from storageID: String) -> [MobileBottomTabKind: PixivRoute] {
        let trimmedStorageID = storageID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedStorageID.isEmpty == false else {
            return defaultRouteMap
        }

        if trimmedStorageID.contains("=") == false {
            return legacyDefaultRouteMap(from: trimmedStorageID)
        }

        var result = defaultRouteMap
        for component in trimmedStorageID.split(separator: ",") {
            let pair = component.split(separator: "=", maxSplits: 1).map(String.init)
            guard pair.count == 2,
                  let kind = MobileBottomTabKind(rawValue: pair[0]),
                  let route = PixivRoute(rawValue: pair[1]) else {
                continue
            }
            result[kind] = sanitized(route, for: kind)
        }
        return result
    }

    static func defaultRoute(for kind: MobileBottomTabKind, from storageID: String) -> PixivRoute {
        defaultRouteMap(from: storageID)[kind] ?? kind.defaultRoute
    }

    static func route(
        for kind: MobileBottomTabKind,
        defaultRouteStorageID: String,
        rememberedRouteStorageID: String,
        remembersLastRoute: Bool
    ) -> PixivRoute {
        if remembersLastRoute {
            return defaultRoute(for: kind, from: rememberedRouteStorageID)
        }
        return defaultRoute(for: kind, from: defaultRouteStorageID)
    }

    static func defaultRoutes(from storageID: String) -> [MobileBottomTabDefaultRoute] {
        let routeMap = defaultRouteMap(from: storageID)
        return fixedKinds.map { kind in
            MobileBottomTabDefaultRoute(kind: kind, route: routeMap[kind] ?? kind.defaultRoute)
        }
    }

    static func storageID(for routeMap: [MobileBottomTabKind: PixivRoute]) -> String {
        fixedKinds.map { kind in
            let route = sanitized(routeMap[kind] ?? kind.defaultRoute, for: kind)
            return "\(kind.rawValue)=\(route.rawValue)"
        }
        .joined(separator: ",")
    }

    static func replacingDefaultRoute(
        for kind: MobileBottomTabKind,
        with route: PixivRoute,
        in routeMap: [MobileBottomTabKind: PixivRoute]
    ) -> [MobileBottomTabKind: PixivRoute] {
        var result = defaultRouteMap
        for fixedKind in fixedKinds {
            result[fixedKind] = sanitized(routeMap[fixedKind] ?? fixedKind.defaultRoute, for: fixedKind)
        }
        result[kind] = sanitized(route, for: kind)
        return result
    }

    static func recordingRememberedRoute(_ route: PixivRoute, in storageID: String) -> String {
        guard let kind = MobileBottomTabKind.kind(containing: route) else {
            return storageID
        }
        let routeMap = replacingDefaultRoute(
            for: kind,
            with: route,
            in: defaultRouteMap(from: storageID)
        )
        return self.storageID(for: routeMap)
    }

    private static func legacyDefaultRouteMap(from storageID: String) -> [MobileBottomTabKind: PixivRoute] {
        var result = defaultRouteMap
        for component in storageID.split(separator: ",") {
            guard let route = legacyRoute(forStorageID: String(component)),
                  let kind = MobileBottomTabKind.kind(containing: route) else {
                continue
            }
            result[kind] = sanitized(route, for: kind)
        }
        return result
    }

    private static func legacyRoute(forStorageID storageID: String) -> PixivRoute? {
        if storageID == "bookmarks" {
            return .publicBookmarks
        }

        switch storageID {
        case "illustrations":
            return .illustrations
        case "manga":
            return .mangaRecommended
        case "spotlight":
            return .spotlight
        case "following":
            return .following
        case "publicBookmarks":
            return .publicBookmarks
        case "privateBookmarks":
            return .privateBookmarks
        case "creators":
            return .followingCreators
        case "watchLater":
            return .watchLater
        case "history":
            return .history
        case "savedSearches":
            return .savedSearches
        case "downloads":
            return .downloads
        case "novels":
            return .novelRecommended
        default:
            return PixivRoute(rawValue: storageID)
        }
    }

    private static func sanitized(_ route: PixivRoute, for kind: MobileBottomTabKind) -> PixivRoute {
        kind.contains(route) ? route : kind.defaultRoute
    }
}

struct MobileRouteMenuSection: Identifiable, Equatable {
    let id: String
    let title: String
    let routes: [PixivRoute]
}

enum MobileRouteMenuConfiguration {
    static func sections(for kind: MobileBottomTabKind) -> [MobileRouteMenuSection] {
        switch kind {
        case .illustrations:
            [
                MobileRouteMenuSection(
                    id: "illustration-discover",
                    title: L10n.discover,
                    routes: [
                        .home,
                        .illustrations,
                        .newIllustrations,
                        .spotlight,
                        .pixivCollections,
                        .pixivActivity,
                        .recommendedUsers
                    ]
                ),
                MobileRouteMenuSection(
                    id: "illustration-ranking",
                    title: L10n.ranking,
                    routes: PixivRoute.illustrationRankingRoutes
                )
            ]
        case .manga:
            [
                MobileRouteMenuSection(
                    id: "manga-feed",
                    title: L10n.manga,
                    routes: [
                        .mangaRecommended,
                        .newManga,
                        .mangaWatchlist
                    ]
                ),
                MobileRouteMenuSection(
                    id: "manga-ranking",
                    title: L10n.mangaRanking,
                    routes: PixivRoute.mangaRankingRoutes
                )
            ]
        case .novels:
            [
                MobileRouteMenuSection(
                    id: "novel-feed",
                    title: L10n.novels,
                    routes: [
                        .novelRecommended,
                        .novelLatest,
                        .novelFollowing,
                        .novelPublicBookmarks,
                        .novelPrivateBookmarks,
                        .novelWatchlist
                    ]
                ),
                MobileRouteMenuSection(
                    id: "novel-ranking",
                    title: L10n.novelRanking,
                    routes: PixivRoute.novelRankingRoutes
                )
            ]
        case .bookmarks:
            [
                MobileRouteMenuSection(
                    id: "bookmarks",
                    title: L10n.bookmarks,
                    routes: [
                        .publicBookmarks,
                        .privateBookmarks,
                        .bookmarkTags,
                        .savedPixivisionArticles,
                        .myPixivCollections,
                        .savedPixivCollections
                    ]
                ),
                MobileRouteMenuSection(
                    id: "bookmarks-following",
                    title: L10n.following,
                    routes: [
                        .following,
                        .privateFollowing,
                        .followingCreators,
                        .pinnedCreators
                    ]
                ),
                MobileRouteMenuSection(
                    id: "bookmarks-library",
                    title: L10n.library,
                    routes: [
                        .history,
                        .watchLater,
                        .workSubscriptions,
                        .mutedContent,
                        .downloads
                    ]
                )
            ]
        }
    }
}

struct TabBarReselectionHitPolicy: Equatable {
    let itemCount: Int
    let selectedIndex: Int
    let tabBarWidth: CGFloat
    var selectedItemFrame: CGRect? = nil

    func isSelectedItemTap(at point: CGPoint) -> Bool {
        guard itemCount > 0,
              selectedIndex >= 0,
              selectedIndex < itemCount,
              tabBarWidth > 0,
              point.x >= 0,
              point.x < tabBarWidth else {
            return false
        }

        if let selectedItemFrame,
           selectedItemFrame.isEmpty == false {
            return selectedItemFrame.insetBy(dx: -8, dy: -8).contains(point)
        }

        let slotWidth = tabBarWidth / CGFloat(itemCount)
        guard slotWidth > 0 else { return false }
        return Int(point.x / slotWidth) == selectedIndex
    }
}
