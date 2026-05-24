import SwiftUI

enum UserPreviewListMode: Identifiable {
    case recommended
    case following
    case search
    case userFollowing(PixivUser)
    case userFollowers(PixivUser)
    case related(PixivUser)

    var title: String {
        switch self {
        case .recommended: L10n.recommendedCreators
        case .following: L10n.followingCreators
        case .search: L10n.searchCreators
        case .userFollowing(let user): "\(L10n.followingCreators) · \(user.name)"
        case .userFollowers(let user): "\(L10n.followers) · \(user.name)"
        case .related(let user): "\(L10n.relatedCreators) · \(user.name)"
        }
    }

    var usesRestrictPicker: Bool {
        switch self {
        case .following, .userFollowing, .userFollowers:
            true
        default:
            false
        }
    }

    var infersFollowRestrictFromPicker: Bool {
        switch self {
        case .following, .userFollowing:
            true
        default:
            false
        }
    }

    var requiresSearchKeyword: Bool {
        switch self {
        case .search:
            true
        default:
            false
        }
    }

    var key: String {
        switch self {
        case .recommended:
            "recommended"
        case .following:
            "following"
        case .search:
            "search"
        case .userFollowing(let user):
            "user-following-\(user.id)"
        case .userFollowers(let user):
            "user-followers-\(user.id)"
        case .related(let user):
            "related-\(user.id)"
        }
    }

    var id: String { key }
}

enum CreatorListFilter: String, CaseIterable, Identifiable {
    case all
    case followed
    case unfollowed
    case muted

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            L10n.allCreators
        case .followed:
            L10n.following
        case .unfollowed:
            L10n.unfollowed
        case .muted:
            L10n.muted
        }
    }
}

enum CreatorListSort: String, CaseIterable, Identifiable {
    case defaultOrder
    case name
    case account
    case previewWorks
    case followState

    var id: String { rawValue }

    var title: String {
        switch self {
        case .defaultOrder:
            L10n.defaultOrder
        case .name:
            L10n.creator
        case .account:
            L10n.account
        case .previewWorks:
            L10n.previewWorks
        case .followState:
            L10n.following
        }
    }
}

enum CreatorBulkAction: String, Identifiable {
    case followPublic
    case followPrivate
    case mute
    case unfollow

    var id: String { rawValue }

    var title: String {
        switch self {
        case .followPublic:
            L10n.followVisiblePublicly
        case .followPrivate:
            L10n.followVisiblePrivately
        case .mute:
            L10n.muteVisibleCreators
        case .unfollow:
            L10n.unfollowVisibleCreators
        }
    }

    var role: ButtonRole? {
        switch self {
        case .mute, .unfollow:
            .destructive
        case .followPublic, .followPrivate:
            nil
        }
    }

    func confirmationMessage(count: Int) -> String {
        switch self {
        case .followPublic:
            String(format: L10n.followVisiblePubliclyConfirmationFormat, count)
        case .followPrivate:
            String(format: L10n.followVisiblePrivatelyConfirmationFormat, count)
        case .mute:
            String(format: L10n.muteVisibleCreatorsConfirmationFormat, count)
        case .unfollow:
            String(format: L10n.unfollowVisibleCreatorsConfirmationFormat, count)
        }
    }
}

extension PixivUserPreview {
    func matchesCreatorQuery(_ query: String) -> Bool {
        let fields = [
            user.name,
            user.account,
            String(user.id)
        ]
        return fields.contains { field in
            field.localizedCaseInsensitiveContains(query)
        }
    }
}

extension BookmarkRestrict {
    var creatorVisibilityTitle: String {
        switch self {
        case .public:
            L10n.publicFollow
        case .private:
            L10n.privateFollow
        }
    }

    var creatorVisibilitySystemImage: String {
        switch self {
        case .public:
            "person.crop.circle.badge.checkmark"
        case .private:
            "lock.circle"
        }
    }
}
