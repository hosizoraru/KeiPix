import Foundation

struct MutedUserEntry: Codable, Identifiable, Hashable, Sendable {
    let id: Int
    let name: String
}

struct MutedArtworkEntry: Codable, Identifiable, Hashable, Sendable {
    let id: Int
    let title: String
}

struct MutedContentArchive: Codable, Sendable {
    var schemaVersion = 1
    let exportedAt: Date
    let tags: [String]
    let users: [MutedUserEntry]
    let artworks: [MutedArtworkEntry]

    var totalCount: Int {
        tags.count + users.count + artworks.count
    }
}

struct PixivMuteList: Decodable, Sendable {
    let mutedTags: [PixivMutedTag]
    let mutedUsers: [PixivMutedUser]
    let muteLimitCount: Int

    enum CodingKeys: String, CodingKey {
        case mutedTags = "muted_tags"
        case mutedUsers = "muted_users"
        case muteLimitCount = "mute_limit_count"
    }
}

struct PixivMutedTag: Decodable, Hashable, Sendable {
    let tag: String
    let tagTranslation: String?

    enum CodingKeys: String, CodingKey {
        case tag
        case tagTranslation = "tag_translation"
    }
}

struct PixivMutedUser: Decodable, Identifiable, Hashable, Sendable {
    let id: Int
    let name: String
    let account: String?
    let avatarURL: URL?

    enum CodingKeys: String, CodingKey {
        case id = "user_id"
        case name = "user_name"
        case account = "user_account"
        case profileImageURLs = "user_profile_image_urls"
    }

    enum ProfileKeys: String, CodingKey {
        case medium
        case px170 = "px_170x170"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        account = try container.decodeIfPresent(String.self, forKey: .account)

        let profile = try? container.nestedContainer(keyedBy: ProfileKeys.self, forKey: .profileImageURLs)
        avatarURL = profile?.decodeCleanURLIfPresent(forKey: .medium)
            ?? profile?.decodeCleanURLIfPresent(forKey: .px170)
    }
}

struct PixivRestrictedModeSettings: Decodable, Sendable {
    let isRestrictedModeEnabled: Bool

    enum CodingKeys: String, CodingKey {
        case isRestrictedModeEnabled = "is_restricted_mode_enabled"
    }
}
