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
