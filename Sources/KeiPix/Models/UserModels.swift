import Foundation

struct PixivUserDetail: Decodable, Sendable {
    let user: PixivUser
    let profile: PixivUserProfile
    let workspace: PixivUserWorkspace?
}

struct PixivUserProfile: Decodable, Hashable, Sendable {
    let webpage: URL?
    let region: String?
    let job: String?
    let totalFollowUsers: Int
    let totalIllusts: Int
    let totalManga: Int
    let totalIllustBookmarksPublic: Int
    let backgroundImageURL: URL?
    let twitterURL: URL?
    let pawooURL: URL?
    let isPremium: Bool

    enum CodingKeys: String, CodingKey {
        case webpage
        case region
        case job
        case totalFollowUsers = "total_follow_users"
        case totalIllusts = "total_illusts"
        case totalManga = "total_manga"
        case totalIllustBookmarksPublic = "total_illust_bookmarks_public"
        case backgroundImageURL = "background_image_url"
        case twitterURL = "twitter_url"
        case pawooURL = "pawoo_url"
        case isPremium = "is_premium"
    }
}

struct PixivUserWorkspace: Decodable, Hashable, Sendable {
    let tool: String?
    let tablet: String?
    let mouse: String?
    let comment: String?
}

struct PixivFollowDetailResponse: Decodable, Sendable {
    let followDetail: PixivFollowDetail

    enum CodingKeys: String, CodingKey {
        case followDetail = "follow_detail"
    }
}

struct PixivFollowDetail: Decodable, Hashable, Sendable {
    let isFollowed: Bool
    let restrict: String?

    var restrictValue: BookmarkRestrict {
        restrict.flatMap(BookmarkRestrict.init(rawValue:)) ?? .public
    }

    enum CodingKeys: String, CodingKey {
        case isFollowed = "is_followed"
        case restrict
    }
}

struct PixivUserPreviewResponse: Decodable, Sendable {
    let userPreviews: [PixivUserPreview]
    let nextURL: URL?

    enum CodingKeys: String, CodingKey {
        case userPreviews = "user_previews"
        case nextURL = "next_url"
    }
}

struct PixivUserPreview: Decodable, Identifiable, Hashable, Sendable {
    let user: PixivUser
    let illusts: [PixivArtwork]
    let isMuted: Bool

    var id: Int { user.id }

    enum CodingKeys: String, CodingKey {
        case user
        case illusts
        case isMuted = "is_muted"
    }

    init(user: PixivUser, illusts: [PixivArtwork], isMuted: Bool) {
        self.user = user
        self.illusts = illusts
        self.isMuted = isMuted
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        user = try container.decode(PixivUser.self, forKey: .user)
        illusts = try container.decodeIfPresent([PixivArtwork].self, forKey: .illusts) ?? []
        isMuted = try container.decodeIfPresent(Bool.self, forKey: .isMuted) ?? false
    }
}
