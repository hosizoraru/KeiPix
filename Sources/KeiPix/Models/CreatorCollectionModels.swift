import Foundation

struct PinnedCreator: Identifiable, Codable, Hashable, Sendable {
    let id: Int
    var name: String
    var account: String
    var avatarURL: URL?
    var isFollowed: Bool
    var addedAt: Date

    init(user: PixivUser, addedAt: Date = Date()) {
        id = user.id
        name = user.name
        account = user.account
        avatarURL = user.avatarURL
        isFollowed = user.isFollowed
        self.addedAt = addedAt
    }

    var user: PixivUser {
        PixivUser(
            id: id,
            name: name,
            account: account,
            avatarURL: avatarURL,
            isFollowed: isFollowed
        )
    }

    var preview: PixivUserPreview {
        PixivUserPreview(user: user, illusts: [], isMuted: false)
    }
}

struct PinnedCreatorLibrary: Codable, Sendable {
    var creators: [PinnedCreator] = []

    var sortedCreators: [PinnedCreator] {
        creators.sorted { lhs, rhs in
            if lhs.addedAt == rhs.addedAt {
                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
            return lhs.addedAt > rhs.addedAt
        }
    }

    func contains(userID: Int) -> Bool {
        creators.contains { $0.id == userID }
    }

    mutating func pin(_ user: PixivUser, addedAt: Date = Date()) {
        if let index = creators.firstIndex(where: { $0.id == user.id }) {
            creators[index].name = user.name
            creators[index].account = user.account
            creators[index].avatarURL = user.avatarURL
            creators[index].isFollowed = user.isFollowed
        } else {
            creators.append(PinnedCreator(user: user, addedAt: addedAt))
        }
    }

    @discardableResult
    mutating func unpin(userID: Int) -> Bool {
        guard let index = creators.firstIndex(where: { $0.id == userID }) else {
            return false
        }
        creators.remove(at: index)
        return true
    }
}
