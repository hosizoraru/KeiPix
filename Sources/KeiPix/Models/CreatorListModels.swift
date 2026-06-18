import SwiftUI

enum UserPreviewListMode: Identifiable {
    case recommended
    case following
    case pinned
    case search
    case userFollowing(PixivUser)
    case userFollowers(PixivUser)
    case userMyPixiv(PixivUser)
    case related(PixivUser)

    var title: String {
        switch self {
        case .recommended: L10n.recommendedCreators
        case .following: L10n.followingCreators
        case .pinned: L10n.pinnedCreators
        case .search: L10n.searchCreators
        case .userFollowing(let user): "\(L10n.followingCreators) · \(user.name)"
        case .userFollowers(let user): "\(L10n.followers) · \(user.name)"
        case .userMyPixiv(let user): "\(L10n.myPixivUsers) · \(user.name)"
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

    var emptySystemImage: String {
        switch self {
        case .pinned:
            "pin"
        default:
            "person.2"
        }
    }

    var key: String {
        switch self {
        case .recommended:
            "recommended"
        case .following:
            "following"
        case .pinned:
            "pinned"
        case .search:
            "search"
        case .userFollowing(let user):
            "user-following-\(user.id)"
        case .userFollowers(let user):
            "user-followers-\(user.id)"
        case .userMyPixiv(let user):
            "user-mypixiv-\(user.id)"
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

struct CreatorListSelection: Hashable, Sendable {
    var selectedIDs: Set<Int> = []
    var isSelectionMode = false

    var count: Int { selectedIDs.count }
    var hasSelection: Bool { selectedIDs.isEmpty == false }

    func contains(_ userID: Int) -> Bool {
        selectedIDs.contains(userID)
    }

    mutating func toggle(_ userID: Int) {
        if selectedIDs.contains(userID) {
            selectedIDs.remove(userID)
        } else {
            selectedIDs.insert(userID)
        }
    }

    mutating func selectAll(_ userIDs: some Sequence<Int>) {
        selectedIDs.formUnion(userIDs)
    }

    mutating func clear() {
        selectedIDs.removeAll()
        isSelectionMode = false
    }

    mutating func prune(visibleCreatorIDs: some Sequence<Int>) {
        selectedIDs.formIntersection(Set(visibleCreatorIDs))
        if selectedIDs.isEmpty {
            isSelectionMode = false
        }
    }
}

enum CreatorBulkAction: String, Identifiable {
    case followPublic
    case followPrivate
    case moveToPrivateFollow
    case mute
    case unfollow

    var id: String { rawValue }

    var title: String {
        switch self {
        case .followPublic:
            L10n.followSelectedPublicly
        case .followPrivate:
            L10n.followSelectedPrivately
        case .moveToPrivateFollow:
            L10n.moveSelectedCreatorsToPrivateFollow
        case .mute:
            L10n.muteSelectedCreators
        case .unfollow:
            L10n.unfollowSelectedCreators
        }
    }

    var role: ButtonRole? {
        switch self {
        case .mute, .unfollow:
            .destructive
        case .followPublic, .followPrivate, .moveToPrivateFollow:
            nil
        }
    }

    func confirmationMessage(count: Int) -> String {
        switch self {
        case .followPublic:
            String(format: L10n.followSelectedPubliclyConfirmationFormat, count)
        case .followPrivate:
            String(format: L10n.followSelectedPrivatelyConfirmationFormat, count)
        case .moveToPrivateFollow:
            String(format: L10n.moveSelectedCreatorsToPrivateFollowConfirmationFormat, count)
        case .mute:
            String(format: L10n.muteSelectedCreatorsConfirmationFormat, count)
        case .unfollow:
            String(format: L10n.unfollowSelectedCreatorsConfirmationFormat, count)
        }
    }
}

struct CreatorDangerAction: Identifiable {
    enum Kind {
        case unfollow
        case mute
    }

    let id = UUID()
    let kind: Kind
    let user: PixivUser
    let restoreRestrict: BookmarkRestrict?

    var title: String {
        switch kind {
        case .unfollow:
            L10n.unfollow
        case .mute:
            L10n.muteCreator
        }
    }

    var confirmationMessage: String {
        switch kind {
        case .unfollow:
            String(format: L10n.unfollowCreatorConfirmationFormat, user.name)
        case .mute:
            String(format: L10n.muteCreatorConfirmationFormat, user.name)
        }
    }
}

struct CreatorFollowRestore: Identifiable {
    let user: PixivUser
    let restrict: BookmarkRestrict

    var id: Int { user.id }
}

struct CreatorUndoAction: Identifiable {
    enum Kind {
        case restoreFollows([CreatorFollowRestore])
        case unmuteUsers([PixivUser])
        case unfollowUsers([PixivUser])
    }

    let id = UUID()
    let kind: Kind

    var message: String {
        switch kind {
        case .restoreFollows(let restores):
            restores.count == 1
                ? String(format: L10n.unfollowedCreatorFormat, restores[0].user.name)
                : String(format: L10n.unfollowedCreatorsFormat, restores.count)
        case .unmuteUsers(let users):
            users.count == 1
                ? String(format: L10n.mutedCreatorFormat, users[0].name)
                : String(format: L10n.mutedCreatorsFormat, users.count)
        case .unfollowUsers(let users):
            users.count == 1
                ? String(format: L10n.followedCreatorFormat, users[0].name)
                : String(format: L10n.followedCreatorsFormat, users.count)
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
