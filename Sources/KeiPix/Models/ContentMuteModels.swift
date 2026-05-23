import Foundation

struct MutedUserEntry: Identifiable, Hashable {
    let id: Int
    let name: String
}

struct MutedArtworkEntry: Identifiable, Hashable {
    let id: Int
    let title: String
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
        let value = try profile?.decodeIfPresent(String.self, forKey: .medium)
            ?? profile?.decodeIfPresent(String.self, forKey: .px170)
        avatarURL = value.flatMap(URL.init(string:))
    }
}
