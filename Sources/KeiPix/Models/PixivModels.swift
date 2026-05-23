import CoreGraphics
import Foundation

struct PixivSession: Codable, Equatable, Sendable {
    var accessToken: String
    var refreshToken: String
    var user: PixivAccountUser
}

struct PixivAccountUser: Codable, Equatable, Sendable {
    let id: String
    let name: String
    let account: String
    let profileImageURL: URL?
    let isPremium: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case account
        case mailAddress = "mail_address"
        case profileImageURLs = "profile_image_urls"
        case isPremium = "is_premium"
    }

    enum ProfileKeys: String, CodingKey {
        case px170 = "px_170x170"
        case medium
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        account = try container.decode(String.self, forKey: .account)
        isPremium = try container.decodeIfPresent(Bool.self, forKey: .isPremium) ?? false

        let profile = try? container.nestedContainer(keyedBy: ProfileKeys.self, forKey: .profileImageURLs)
        let value = try profile?.decodeIfPresent(String.self, forKey: .px170)
            ?? profile?.decodeIfPresent(String.self, forKey: .medium)
        profileImageURL = value.flatMap(URL.init(string:))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(account, forKey: .account)
        try container.encode(isPremium, forKey: .isPremium)

        var profile = container.nestedContainer(keyedBy: ProfileKeys.self, forKey: .profileImageURLs)
        try profile.encodeIfPresent(profileImageURL?.absoluteString, forKey: .px170)
    }
}

struct PixivUser: Decodable, Identifiable, Hashable, Sendable {
    let id: Int
    let name: String
    let account: String
    let comment: String?
    let avatarURL: URL?
    var isFollowed: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case account
        case comment
        case profileImageURLs = "profile_image_urls"
        case isFollowed = "is_followed"
    }

    enum ProfileKeys: String, CodingKey {
        case medium
        case px170 = "px_170x170"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        account = try container.decode(String.self, forKey: .account)
        comment = try container.decodeIfPresent(String.self, forKey: .comment)
        isFollowed = try container.decodeIfPresent(Bool.self, forKey: .isFollowed) ?? false

        let profile = try? container.nestedContainer(keyedBy: ProfileKeys.self, forKey: .profileImageURLs)
        let value = try profile?.decodeIfPresent(String.self, forKey: .medium)
            ?? profile?.decodeIfPresent(String.self, forKey: .px170)
        avatarURL = value.flatMap(URL.init(string:))
    }
}

struct PixivTag: Decodable, Hashable, Sendable {
    let name: String
    let translatedName: String?

    enum CodingKeys: String, CodingKey {
        case name
        case translatedName = "translated_name"
    }
}

struct PixivImageSet: Decodable, Hashable, Sendable {
    let squareMedium: URL?
    let medium: URL?
    let large: URL?
    let original: URL?

    enum CodingKeys: String, CodingKey {
        case squareMedium = "square_medium"
        case medium
        case large
        case original
    }
}

struct PixivArtworkSeriesSummary: Decodable, Hashable, Sendable {
    let id: Int
    let title: String
}

struct PixivArtwork: Decodable, Identifiable, Hashable, Sendable {
    let id: Int
    let title: String
    let type: String
    let caption: String
    var user: PixivUser
    let tags: [PixivTag]
    let createDate: Date
    let pageCount: Int
    let width: Int
    let height: Int
    let totalView: Int
    let totalBookmarks: Int
    let totalComments: Int
    var isBookmarked: Bool
    let isMuted: Bool
    let isAI: Bool
    let sanityLevel: Int
    let xRestrict: Int
    let series: PixivArtworkSeriesSummary?
    let images: [PixivImageSet]

    var thumbnailURL: URL? { images.first?.medium ?? images.first?.squareMedium }
    var detailURL: URL? { images.first?.large ?? images.first?.medium }
    var originalURL: URL? { images.first?.original ?? detailURL }
    var pixivURL: URL? { URL(string: "https://www.pixiv.net/artworks/\(id)") }
    var aspectRatio: CGFloat {
        guard width > 0, height > 0 else { return 0.75 }
        return CGFloat(width) / CGFloat(height)
    }
    var isUgoira: Bool { type == "ugoira" }
    var isR18G: Bool {
        xRestrict == 2 || tags.contains { $0.name.localizedCaseInsensitiveCompare("R-18G") == .orderedSame }
    }
    var isR18: Bool {
        xRestrict == 1 || isR18G || tags.contains { $0.name.localizedCaseInsensitiveContains("R-18") }
    }
    var requiresScreenCaptureProtection: Bool {
        isR18 || isR18G
    }
    var contentBadges: [ArtworkContentBadge] {
        var badges: [ArtworkContentBadge] = []
        if isR18G {
            badges.append(.r18g)
        } else if isR18 {
            badges.append(.r18)
        }
        if isAI {
            badges.append(.aiGenerated)
        }
        if isUgoira {
            badges.append(.ugoira)
        }
        if isMuted {
            badges.append(.muted)
        }
        return badges
    }

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case type
        case imageURLs = "image_urls"
        case metaSinglePage = "meta_single_page"
        case metaPages = "meta_pages"
        case caption
        case user
        case tags
        case createDate = "create_date"
        case pageCount = "page_count"
        case width
        case height
        case totalView = "total_view"
        case totalBookmarks = "total_bookmarks"
        case totalComments = "total_comments"
        case isBookmarked = "is_bookmarked"
        case isMuted = "is_muted"
        case illustAIType = "illust_ai_type"
        case sanityLevel = "sanity_level"
        case xRestrict = "x_restrict"
        case series
    }

    enum MetaSingleKeys: String, CodingKey {
        case originalImageURL = "original_image_url"
    }

    enum MetaPageKeys: String, CodingKey {
        case imageURLs = "image_urls"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        type = try container.decode(String.self, forKey: .type)
        caption = try container.decodeIfPresent(String.self, forKey: .caption) ?? ""
        user = try container.decode(PixivUser.self, forKey: .user)
        tags = try container.decodeIfPresent([PixivTag].self, forKey: .tags) ?? []
        createDate = try container.decode(Date.self, forKey: .createDate)
        pageCount = try container.decodeIfPresent(Int.self, forKey: .pageCount) ?? 1
        width = try container.decodeIfPresent(Int.self, forKey: .width) ?? 1
        height = try container.decodeIfPresent(Int.self, forKey: .height) ?? 1
        totalView = try container.decodeIfPresent(Int.self, forKey: .totalView) ?? 0
        totalBookmarks = try container.decodeIfPresent(Int.self, forKey: .totalBookmarks) ?? 0
        totalComments = try container.decodeIfPresent(Int.self, forKey: .totalComments) ?? 0
        isBookmarked = try container.decodeIfPresent(Bool.self, forKey: .isBookmarked) ?? false
        isMuted = try container.decodeIfPresent(Bool.self, forKey: .isMuted) ?? false
        isAI = (try container.decodeIfPresent(Int.self, forKey: .illustAIType) ?? 0) == 2
        sanityLevel = try container.decodeIfPresent(Int.self, forKey: .sanityLevel) ?? 0
        xRestrict = try container.decodeIfPresent(Int.self, forKey: .xRestrict) ?? 0
        series = try container.decodeIfPresent(PixivArtworkSeriesSummary.self, forKey: .series)

        let metaPages = try container.decodeIfPresent([[String: PixivImageSet]].self, forKey: .metaPages) ?? []
        var decodedImages = metaPages.compactMap { $0["image_urls"] }
        if decodedImages.isEmpty {
            let base = try container.decodeIfPresent(PixivImageSet.self, forKey: .imageURLs)
            let singlePage = try? container.nestedContainer(keyedBy: MetaSingleKeys.self, forKey: .metaSinglePage)
            let original = try singlePage?.decodeIfPresent(URL.self, forKey: .originalImageURL)
            if let base {
                decodedImages = [PixivImageSet(
                    squareMedium: base.squareMedium,
                    medium: base.medium,
                    large: base.large,
                    original: original ?? base.original
                )]
            }
        }
        images = decodedImages
    }
}

struct PixivFeedResponse: Decodable, Sendable {
    let illusts: [PixivArtwork]
    let nextURL: URL?

    enum CodingKeys: String, CodingKey {
        case illusts
        case nextURL = "next_url"
    }
}

struct PixivAuthResponse: Decodable, Sendable {
    let accessToken: String
    let refreshToken: String
    let user: PixivAccountUser

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case user
    }

    var session: PixivSession {
        PixivSession(accessToken: accessToken, refreshToken: refreshToken, user: user)
    }
}
