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
