import Foundation

/// Curated set of routes the user can pick as the app's launch destination.
///
/// macOS / Apple-style apps typically remember a "what shows on launch"
/// preference — Apple Music, Mail, and Notes all expose this. KeiPix has a
/// long PixivRoute enum, but most cases are derived (search results, user
/// profiles, ranking variants, etc.) and don't make sense as a starting
/// page. Filter down to the destinations that genuinely make sense to land
/// on cold-launch.
enum LaunchDestination: String, CaseIterable, Identifiable, Codable {
    case home
    case illustrations
    case mangaRecommended
    case following
    case publicBookmarks
    case rankingDaily
    case spotlight
    case savedSearches

    var id: String { rawValue }

    /// Maps the curated launch destination back into the full PixivRoute
    /// space so the store can keep using its existing routing.
    var route: PixivRoute {
        switch self {
        case .home: .home
        case .illustrations: .illustrations
        case .mangaRecommended: .mangaRecommended
        case .following: .following
        case .publicBookmarks: .publicBookmarks
        case .rankingDaily: .rankingDaily
        case .spotlight: .spotlight
        case .savedSearches: .savedSearches
        }
    }

    var title: String {
        switch self {
        case .home: L10n.discover
        case .illustrations: L10n.illustrations
        case .mangaRecommended: L10n.manga
        case .following: L10n.following
        case .publicBookmarks: L10n.publicBookmarks
        case .rankingDaily: L10n.daily
        case .spotlight: L10n.spotlight
        case .savedSearches: L10n.savedSearches
        }
    }

    var systemImage: String {
        switch self {
        case .home: "house"
        case .illustrations: "sparkles"
        case .mangaRecommended: "book"
        case .following: "person.2"
        case .publicBookmarks: "bookmark"
        case .rankingDaily: "trophy"
        case .spotlight: "newspaper"
        case .savedSearches: "magnifyingglass.circle"
        }
    }
}

enum AppLaunchRouteResolver {
    static let launchDestinationDefaultsKey = "launchDestination"

    static func initialRoute(
        defaults: UserDefaults = .standard,
        usesMobileBottomTabs: Bool = usesMobileBottomTabsOnCurrentPlatform
    ) -> PixivRoute {
        if usesMobileBottomTabs {
            return mobileBottomTabRoute(defaults: defaults)
        }
        return launchDestinationRoute(defaults: defaults)
    }

    private static var usesMobileBottomTabsOnCurrentPlatform: Bool {
        #if os(iOS)
        true
        #else
        false
        #endif
    }

    private static func launchDestinationRoute(defaults: UserDefaults) -> PixivRoute {
        let rawValue = defaults.string(forKey: launchDestinationDefaultsKey) ?? ""
        return (LaunchDestination(rawValue: rawValue) ?? .home).route
    }

    private static func mobileBottomTabRoute(defaults: UserDefaults) -> PixivRoute {
        let launchTarget = defaults.string(forKey: MobileBottomTabConfiguration.DefaultsKey.launchTarget)
            .flatMap(MobileBottomTabLaunchTarget.init(rawValue:))
            ?? MobileBottomTabConfiguration.defaultLaunchTarget
        let lastKindID = defaults.string(forKey: MobileBottomTabConfiguration.DefaultsKey.lastKind)
            ?? MobileBottomTabConfiguration.defaultLastUsedKind.rawValue
        let kind = launchTarget.resolvedKind(lastUsedKindID: lastKindID)
        let defaultRouteStorageID = defaults.string(forKey: MobileBottomTabConfiguration.DefaultsKey.defaultRouteIDs)
            ?? MobileBottomTabConfiguration.defaultStorageID
        let rememberedRouteStorageID = defaults.string(forKey: MobileBottomTabConfiguration.DefaultsKey.rememberedRouteIDs)
            ?? MobileBottomTabConfiguration.defaultStorageID
        let remembersLastRoute = defaults.object(forKey: MobileBottomTabConfiguration.DefaultsKey.remembersLastRoute) as? Bool
            ?? MobileBottomTabConfiguration.defaultRemembersLastRoute

        return MobileBottomTabConfiguration.route(
            for: kind,
            defaultRouteStorageID: defaultRouteStorageID,
            rememberedRouteStorageID: rememberedRouteStorageID,
            remembersLastRoute: remembersLastRoute
        )
    }
}
