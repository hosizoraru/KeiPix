import Foundation

struct PixivArtworkSeriesResponse: Decodable, Sendable {
    let detail: PixivArtworkSeriesDetail?
    let firstArtwork: PixivArtwork?
    let illusts: [PixivArtwork]
    let nextURL: URL?

    enum CodingKeys: String, CodingKey {
        case detail = "illust_series_detail"
        case firstArtwork = "illust_series_first_illust"
        case illusts
        case nextURL = "next_url"
    }

    init(
        detail: PixivArtworkSeriesDetail?,
        firstArtwork: PixivArtwork?,
        illusts: [PixivArtwork],
        nextURL: URL?
    ) {
        self.detail = detail
        self.firstArtwork = firstArtwork
        self.illusts = illusts
        self.nextURL = nextURL
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        detail = try container.decodeIfPresent(PixivArtworkSeriesDetail.self, forKey: .detail)
        firstArtwork = try container.decodeIfPresent(PixivArtwork.self, forKey: .firstArtwork)
        illusts = try container.decodeIfPresent([PixivArtwork].self, forKey: .illusts) ?? []
        nextURL = container.decodeCleanURLIfPresent(forKey: .nextURL)
    }
}

struct PixivArtworkSeriesDetail: Decodable, Identifiable, Hashable, Sendable {
    let id: Int
    let title: String
    let caption: String
    let createDate: Date?
    let coverImageURLs: PixivImageSet?
    let workCount: Int
    let user: PixivUser?
    let watchlistAdded: Bool

    var pixivURL: URL? {
        guard let user else { return nil }
        return URL(string: "https://www.pixiv.net/user/\(user.id)/series/\(id)")
    }

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case caption
        case createDate = "create_date"
        case coverImageURLs = "cover_image_urls"
        case workCount = "series_work_count"
        case user
        case watchlistAdded = "watchlist_added"
    }

    init(
        id: Int,
        title: String,
        caption: String,
        createDate: Date?,
        coverImageURLs: PixivImageSet?,
        workCount: Int,
        user: PixivUser?,
        watchlistAdded: Bool
    ) {
        self.id = id
        self.title = title
        self.caption = caption
        self.createDate = createDate
        self.coverImageURLs = coverImageURLs
        self.workCount = workCount
        self.user = user
        self.watchlistAdded = watchlistAdded
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        caption = try container.decodeIfPresent(String.self, forKey: .caption) ?? ""
        createDate = try container.decodeIfPresent(Date.self, forKey: .createDate)
        coverImageURLs = try container.decodeIfPresent(PixivImageSet.self, forKey: .coverImageURLs)
        workCount = try container.decodeIfPresent(Int.self, forKey: .workCount) ?? 0
        user = try container.decodeIfPresent(PixivUser.self, forKey: .user)
        watchlistAdded = try container.decodeIfPresent(Bool.self, forKey: .watchlistAdded) ?? false
    }
}

struct PixivMangaWatchlistResponse: Decodable, Sendable {
    let series: [PixivMangaSeriesPreview]
    let nextURL: URL?

    enum CodingKeys: String, CodingKey {
        case series
        case nextURL = "next_url"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        series = try container.decodeIfPresent([PixivMangaSeriesPreview].self, forKey: .series) ?? []
        nextURL = container.decodeCleanURLIfPresent(forKey: .nextURL)
    }
}

struct PixivMangaSeriesPreview: Decodable, Identifiable, Hashable, Sendable {
    let id: Int
    let title: String
    let user: PixivMangaSeriesUser?
    let latestContentID: Int
    let lastPublishedContentDate: Date?
    let publishedContentCount: Int
    let coverURL: URL?
    let maskText: String?

    var pixivURL: URL? {
        guard let user else { return nil }
        return URL(string: "https://www.pixiv.net/user/\(user.id)/series/\(id)")
    }

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case user
        case latestContentID = "latest_content_id"
        case lastPublishedContentDate = "last_published_content_datetime"
        case publishedContentCount = "published_content_count"
        case coverURL = "url"
        case maskText = "mask_text"
    }

    init(
        id: Int,
        title: String,
        user: PixivMangaSeriesUser?,
        latestContentID: Int,
        lastPublishedContentDate: Date?,
        publishedContentCount: Int,
        coverURL: URL?,
        maskText: String?
    ) {
        self.id = id
        self.title = title
        self.user = user
        self.latestContentID = latestContentID
        self.lastPublishedContentDate = lastPublishedContentDate
        self.publishedContentCount = publishedContentCount
        self.coverURL = coverURL
        self.maskText = maskText
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        user = try container.decodeIfPresent(PixivMangaSeriesUser.self, forKey: .user)
        latestContentID = try container.decodeIfPresent(Int.self, forKey: .latestContentID) ?? 0
        lastPublishedContentDate = try container.decodeIfPresent(Date.self, forKey: .lastPublishedContentDate)
        publishedContentCount = try container.decodeIfPresent(Int.self, forKey: .publishedContentCount) ?? 0
        coverURL = container.decodeCleanURLIfPresent(forKey: .coverURL)
        maskText = try container.decodeIfPresent(String.self, forKey: .maskText)
    }
}

struct PixivMangaSeriesUser: Decodable, Identifiable, Hashable, Sendable {
    let id: Int
    let name: String
    let account: String?
    let avatarURL: URL?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case account
        case profileImageURLs = "profile_image_urls"
    }

    enum ProfileKeys: String, CodingKey {
        case medium
        case px170 = "px_170x170"
    }

    init(user: PixivUser) {
        id = user.id
        name = user.name
        account = user.account
        avatarURL = user.avatarURL
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        account = try container.decodeIfPresent(String.self, forKey: .account)

        let profile = try? container.nestedContainer(keyedBy: ProfileKeys.self, forKey: .profileImageURLs)
        avatarURL = profile?.decodeCleanURLIfPresent(forKey: .medium)
            ?? profile?.decodeCleanURLIfPresent(forKey: .px170)
    }
}
