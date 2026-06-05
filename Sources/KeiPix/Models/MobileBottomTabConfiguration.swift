import Foundation

enum MobileBottomTabItem: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case illustrations
    case manga
    case spotlight
    case following
    case publicBookmarks
    case privateBookmarks
    case creators
    case watchLater
    case history
    case savedSearches
    case downloads
    case novels
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .illustrations: L10n.illustrations
        case .manga: L10n.manga
        case .spotlight: L10n.spotlight
        case .following: L10n.following
        case .publicBookmarks: L10n.publicBookmarks
        case .privateBookmarks: L10n.privateBookmarks
        case .creators: L10n.followingCreators
        case .watchLater: L10n.watchLater
        case .history: L10n.history
        case .savedSearches: L10n.savedSearches
        case .downloads: L10n.downloads
        case .novels: L10n.recommendedNovels
        case .settings: L10n.settings
        }
    }

    var systemImage: String {
        switch self {
        case .illustrations: PixivRoute.illustrations.systemImage
        case .manga: PixivRoute.mangaRecommended.systemImage
        case .spotlight: PixivRoute.spotlight.systemImage
        case .following: PixivRoute.following.systemImage
        case .publicBookmarks: PixivRoute.publicBookmarks.systemImage
        case .privateBookmarks: PixivRoute.privateBookmarks.systemImage
        case .creators: PixivRoute.followingCreators.systemImage
        case .watchLater: PixivRoute.watchLater.systemImage
        case .history: PixivRoute.history.systemImage
        case .savedSearches: PixivRoute.savedSearches.systemImage
        case .downloads: PixivRoute.downloads.systemImage
        case .novels: PixivRoute.novelRecommended.systemImage
        case .settings: "gearshape"
        }
    }

    var route: PixivRoute? {
        switch self {
        case .illustrations: .illustrations
        case .manga: .mangaRecommended
        case .spotlight: .spotlight
        case .following: .following
        case .publicBookmarks: .publicBookmarks
        case .privateBookmarks: .privateBookmarks
        case .creators: .followingCreators
        case .watchLater: .watchLater
        case .history: .history
        case .savedSearches: .savedSearches
        case .downloads: .downloads
        case .novels: .novelRecommended
        case .settings: nil
        }
    }
}

enum MobileBottomTabConfiguration {
    static let maximumCustomItemCount = 3

    static let defaultItems: [MobileBottomTabItem] = [
        .illustrations,
        .manga,
        .publicBookmarks
    ]

    static var defaultStorageID: String {
        storageID(for: defaultItems)
    }

    static func items(from storageID: String) -> [MobileBottomTabItem] {
        let storedItems = storageID
            .split(separator: ",")
            .compactMap { item(forStorageID: String($0)) }
        return normalized(storedItems)
    }

    static func storageID(for items: [MobileBottomTabItem]) -> String {
        normalized(items).map(\.rawValue).joined(separator: ",")
    }

    static func replacing(
        itemAt index: Int,
        with item: MobileBottomTabItem,
        in items: [MobileBottomTabItem]
    ) -> [MobileBottomTabItem] {
        var result = normalized(items)
        guard result.indices.contains(index) else {
            return normalized(result + [item])
        }

        let previousItem = result[index]
        if let existingIndex = result.firstIndex(of: item), existingIndex != index {
            result[index] = item
            result[existingIndex] = previousItem
        } else {
            result[index] = item
        }
        return normalized(result)
    }

    private static func normalized(_ items: [MobileBottomTabItem]) -> [MobileBottomTabItem] {
        var result: [MobileBottomTabItem] = []

        for item in items where result.contains(item) == false {
            result.append(item)
            if result.count == maximumCustomItemCount {
                return result
            }
        }

        for item in defaultItems where result.contains(item) == false {
            result.append(item)
            if result.count == maximumCustomItemCount {
                return result
            }
        }

        for item in MobileBottomTabItem.allCases where result.contains(item) == false {
            result.append(item)
            if result.count == maximumCustomItemCount {
                return result
            }
        }

        return result
    }

    private static func item(forStorageID storageID: String) -> MobileBottomTabItem? {
        if storageID == "bookmarks" {
            return .publicBookmarks
        }
        return MobileBottomTabItem(rawValue: storageID)
    }
}
