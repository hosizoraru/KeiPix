import Foundation

// MARK: - Novel

/// A pixiv novel as returned by `/v2/novel/detail`, `/v1/novel/recommended`,
/// `/v1/novel/follow`, `/v1/novel/ranking`, `/v1/search/novel`,
/// `/v1/user/novels`, and `/v1/user/bookmarks/novel`. Mirrors the Dart
/// `Novel` shape used by pixez/pixes — single source of truth for both
/// list cards and the detail header (the reader fetches the body
/// separately via `/v1/novel/text`).
struct PixivNovel: Codable, Identifiable, Hashable, Sendable {
    let id: Int
    let title: String
    let caption: String
    let restrict: Int
    let xRestrict: Int
    let isOriginal: Bool
    let imageURLs: PixivImageSet
    let createDate: Date
    let tags: [PixivTag]
    let pageCount: Int
    let textLength: Int
    var user: PixivUser
    let series: PixivNovelSeriesSummary?
    var isBookmarked: Bool
    let totalBookmarks: Int
    let totalView: Int
    let totalComments: Int
    let visible: Bool
    let isMuted: Bool
    let isMyPixivOnly: Bool
    let isXRestricted: Bool
    let novelAIType: Int

    /// `novel_ai_type == 2` is the same convention pixiv uses for illusts.
    var isAI: Bool { novelAIType == 2 }
    /// pixiv tags `R-18G` works with `x_restrict == 2`.
    var isR18G: Bool {
        xRestrict == 2 || tags.contains { $0.name.localizedCaseInsensitiveCompare("R-18G") == .orderedSame }
    }
    var isR18: Bool {
        xRestrict == 1 || isR18G || tags.contains { $0.name.localizedCaseInsensitiveContains("R-18") }
    }
    var isR18Only: Bool {
        isR18 && isR18G == false
    }
    var pixivURL: URL? { URL(string: "https://www.pixiv.net/novel/show.php?id=\(id)") }
    var seriesPixivURL: URL? {
        guard let series, let id = series.id else { return nil }
        return URL(string: "https://www.pixiv.net/novel/series/\(id)")
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
        if isMuted {
            badges.append(.muted)
        }
        return badges
    }

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case caption
        case restrict
        case xRestrict = "x_restrict"
        case isOriginal = "is_original"
        case imageURLs = "image_urls"
        case createDate = "create_date"
        case tags
        case pageCount = "page_count"
        case textLength = "text_length"
        case user
        case series
        case isBookmarked = "is_bookmarked"
        case totalBookmarks = "total_bookmarks"
        case totalView = "total_view"
        case totalComments = "total_comments"
        case visible
        case isMuted = "is_muted"
        case isMyPixivOnly = "is_mypixiv_only"
        case isXRestricted = "is_x_restricted"
        case novelAIType = "novel_ai_type"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        caption = try container.decodeIfPresent(String.self, forKey: .caption) ?? ""
        restrict = try container.decodeIfPresent(Int.self, forKey: .restrict) ?? 0
        xRestrict = try container.decodeIfPresent(Int.self, forKey: .xRestrict) ?? 0
        isOriginal = try container.decodeIfPresent(Bool.self, forKey: .isOriginal) ?? false
        imageURLs = (try container.decodeIfPresent(PixivImageSet.self, forKey: .imageURLs))
            ?? PixivImageSet(squareMedium: nil, medium: nil, large: nil, original: nil)
        createDate = try container.decode(Date.self, forKey: .createDate)
        tags = try container.decodeIfPresent([PixivTag].self, forKey: .tags) ?? []
        pageCount = try container.decodeIfPresent(Int.self, forKey: .pageCount) ?? 1
        textLength = try container.decodeIfPresent(Int.self, forKey: .textLength) ?? 0
        user = try container.decode(PixivUser.self, forKey: .user)
        // pixiv hands back `series: {}` for novels that aren't in a series, so
        // a lenient decode is required — use `try?` and fall back to nil if
        // the nested object exists but lacks both `id` and `title`.
        series = (try? container.decodeIfPresent(PixivNovelSeriesSummary.self, forKey: .series))
            ?? nil
        isBookmarked = try container.decodeIfPresent(Bool.self, forKey: .isBookmarked) ?? false
        totalBookmarks = try container.decodeIfPresent(Int.self, forKey: .totalBookmarks) ?? 0
        totalView = try container.decodeIfPresent(Int.self, forKey: .totalView) ?? 0
        totalComments = try container.decodeIfPresent(Int.self, forKey: .totalComments) ?? 0
        visible = try container.decodeIfPresent(Bool.self, forKey: .visible) ?? true
        isMuted = try container.decodeIfPresent(Bool.self, forKey: .isMuted) ?? false
        isMyPixivOnly = try container.decodeIfPresent(Bool.self, forKey: .isMyPixivOnly) ?? false
        isXRestricted = try container.decodeIfPresent(Bool.self, forKey: .isXRestricted) ?? false
        novelAIType = try container.decodeIfPresent(Int.self, forKey: .novelAIType) ?? 0
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(caption, forKey: .caption)
        try container.encode(restrict, forKey: .restrict)
        try container.encode(xRestrict, forKey: .xRestrict)
        try container.encode(isOriginal, forKey: .isOriginal)
        try container.encode(imageURLs, forKey: .imageURLs)
        try container.encode(createDate, forKey: .createDate)
        try container.encode(tags, forKey: .tags)
        try container.encode(pageCount, forKey: .pageCount)
        try container.encode(textLength, forKey: .textLength)
        try container.encode(user, forKey: .user)
        try container.encodeIfPresent(series, forKey: .series)
        try container.encode(isBookmarked, forKey: .isBookmarked)
        try container.encode(totalBookmarks, forKey: .totalBookmarks)
        try container.encode(totalView, forKey: .totalView)
        try container.encode(totalComments, forKey: .totalComments)
        try container.encode(visible, forKey: .visible)
        try container.encode(isMuted, forKey: .isMuted)
        try container.encode(isMyPixivOnly, forKey: .isMyPixivOnly)
        try container.encode(isXRestricted, forKey: .isXRestricted)
        try container.encode(novelAIType, forKey: .novelAIType)
    }
}

// MARK: - Series summary embedded on a novel

struct PixivNovelSeriesSummary: Codable, Hashable, Sendable {
    let id: Int?
    let title: String?

    enum CodingKeys: String, CodingKey {
        case id
        case title
    }

    init(id: Int?, title: String?) {
        self.id = id
        self.title = title
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // pixiv sends `series: {}` on standalone novels — both keys absent.
        id = try container.decodeIfPresent(Int.self, forKey: .id)
        title = try container.decodeIfPresent(String.self, forKey: .title)
    }

    var hasSeries: Bool { id != nil && title?.isEmpty == false }
}

// MARK: - Lightweight novel reference (series prev/next, etc.)

struct PixivNovelStub: Codable, Hashable, Sendable, Identifiable {
    let id: Int
    let title: String

    enum CodingKeys: String, CodingKey {
        case id
        case title
    }
}

// MARK: - List response (recommended, follow, ranking, search, user, bookmarks, related)

struct PixivNovelListResponse: Decodable, Sendable {
    let novels: [PixivNovel]
    let nextURL: URL?

    enum CodingKeys: String, CodingKey {
        case novels
        case nextURL = "next_url"
    }

    init(novels: [PixivNovel], nextURL: URL?) {
        self.novels = novels
        self.nextURL = nextURL
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        novels = try container.decodeIfPresent([PixivNovel].self, forKey: .novels) ?? []
        nextURL = container.decodeCleanURLIfPresent(forKey: .nextURL)
    }
}

// MARK: - Detail

struct PixivNovelDetailResponse: Decodable, Sendable {
    let novel: PixivNovel
}

// MARK: - Text (`/v1/novel/text`)

struct PixivNovelText: Codable, Sendable {
    /// Last reading position pixiv has remembered for this account; we
    /// surface it but currently don't auto-jump to it.
    let novelMarker: PixivNovelMarker?
    let novelText: String
    let seriesPrev: PixivNovelStub?
    let seriesNext: PixivNovelStub?

    enum CodingKeys: String, CodingKey {
        case novelMarker = "novel_marker"
        case novelText = "novel_text"
        case seriesPrev = "series_prev"
        case seriesNext = "series_next"
    }
}

struct PixivNovelMarker: Codable, Sendable {
    let page: Int?
}

// MARK: - Series (`/v2/novel/series`)

struct PixivNovelSeriesResponse: Decodable, Sendable {
    let detail: PixivNovelSeriesDetail
    let firstNovel: PixivNovel?
    let latestNovel: PixivNovel?
    let novels: [PixivNovel]
    let nextURL: URL?

    enum CodingKeys: String, CodingKey {
        case detail = "novel_series_detail"
        case firstNovel = "novel_series_first_novel"
        case latestNovel = "novel_series_latest_novel"
        case novels
        case nextURL = "next_url"
    }

    init(
        detail: PixivNovelSeriesDetail,
        firstNovel: PixivNovel? = nil,
        latestNovel: PixivNovel? = nil,
        novels: [PixivNovel],
        nextURL: URL?
    ) {
        self.detail = detail
        self.firstNovel = firstNovel
        self.latestNovel = latestNovel
        self.novels = novels
        self.nextURL = nextURL
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        detail = try container.decode(PixivNovelSeriesDetail.self, forKey: .detail)
        firstNovel = try container.decodeIfPresent(PixivNovel.self, forKey: .firstNovel)
        latestNovel = try container.decodeIfPresent(PixivNovel.self, forKey: .latestNovel)
        novels = try container.decodeIfPresent([PixivNovel].self, forKey: .novels) ?? []
        nextURL = container.decodeCleanURLIfPresent(forKey: .nextURL)
    }
}

struct PixivNovelSeriesDetail: Codable, Hashable, Sendable, Identifiable {
    let id: Int
    let title: String
    let caption: String
    let isOriginal: Bool
    let isConcluded: Bool
    let contentCount: Int
    let totalCharacterCount: Int
    let user: PixivUser
    let displayText: String
    let novelAIType: Int
    /// pixiv adds `watchlist_added` on the series detail when fetched while
    /// authenticated. Optional because the watchlist endpoints don't return
    /// the same shape and older snapshots may lack the field.
    let watchlistAdded: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case caption
        case isOriginal = "is_original"
        case isConcluded = "is_concluded"
        case contentCount = "content_count"
        case totalCharacterCount = "total_character_count"
        case user
        case displayText = "display_text"
        case novelAIType = "novel_ai_type"
        case watchlistAdded = "watchlist_added"
    }

    init(
        id: Int,
        title: String,
        caption: String = "",
        isOriginal: Bool = false,
        isConcluded: Bool = false,
        contentCount: Int,
        totalCharacterCount: Int,
        user: PixivUser,
        displayText: String = "",
        novelAIType: Int = 0,
        watchlistAdded: Bool? = nil
    ) {
        self.id = id
        self.title = title
        self.caption = caption
        self.isOriginal = isOriginal
        self.isConcluded = isConcluded
        self.contentCount = contentCount
        self.totalCharacterCount = totalCharacterCount
        self.user = user
        self.displayText = displayText
        self.novelAIType = novelAIType
        self.watchlistAdded = watchlistAdded
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        caption = try container.decodeIfPresent(String.self, forKey: .caption) ?? ""
        isOriginal = try container.decodeIfPresent(Bool.self, forKey: .isOriginal) ?? false
        isConcluded = try container.decodeIfPresent(Bool.self, forKey: .isConcluded) ?? false
        contentCount = try container.decodeIfPresent(Int.self, forKey: .contentCount) ?? 0
        totalCharacterCount = try container.decodeIfPresent(Int.self, forKey: .totalCharacterCount) ?? 0
        user = try container.decode(PixivUser.self, forKey: .user)
        displayText = try container.decodeIfPresent(String.self, forKey: .displayText) ?? ""
        novelAIType = try container.decodeIfPresent(Int.self, forKey: .novelAIType) ?? 0
        watchlistAdded = try container.decodeIfPresent(Bool.self, forKey: .watchlistAdded)
    }

    var pixivURL: URL? { URL(string: "https://www.pixiv.net/novel/series/\(id)") }
}

// MARK: - Watchlist (`/v1/watchlist/novel`)

struct PixivNovelWatchlistResponse: Decodable, Sendable {
    let series: [PixivNovelSeriesItem]
    let nextURL: URL?

    enum CodingKeys: String, CodingKey {
        case series
        case nextURL = "next_url"
    }

    init(series: [PixivNovelSeriesItem], nextURL: URL?) {
        self.series = series
        self.nextURL = nextURL
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        series = try container.decodeIfPresent([PixivNovelSeriesItem].self, forKey: .series) ?? []
        nextURL = container.decodeCleanURLIfPresent(forKey: .nextURL)
    }
}

struct PixivNovelSeriesItem: Codable, Hashable, Sendable, Identifiable {
    let id: Int
    let title: String
    let coverURL: URL?
    let publishedContentCount: Int
    let lastPublishedContentDateTime: Date?
    let latestContentID: Int?
    let user: PixivUser

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case url
        case publishedContentCount = "published_content_count"
        case lastPublishedContentDateTime = "last_published_content_datetime"
        case latestContentID = "latest_content_id"
        case user
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        coverURL = container.decodeCleanURLIfPresent(forKey: .url)
        publishedContentCount = try container.decodeIfPresent(Int.self, forKey: .publishedContentCount) ?? 0
        // pixiv sends an ISO8601-with-offset string here.
        lastPublishedContentDateTime = try container.decodeIfPresent(Date.self, forKey: .lastPublishedContentDateTime)
        latestContentID = try container.decodeIfPresent(Int.self, forKey: .latestContentID)
        user = try container.decode(PixivUser.self, forKey: .user)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(coverURL?.absoluteString, forKey: .url)
        try container.encode(publishedContentCount, forKey: .publishedContentCount)
        try container.encodeIfPresent(lastPublishedContentDateTime, forKey: .lastPublishedContentDateTime)
        try container.encodeIfPresent(latestContentID, forKey: .latestContentID)
        try container.encode(user, forKey: .user)
    }

    var pixivURL: URL? { URL(string: "https://www.pixiv.net/novel/series/\(id)") }
}

// MARK: - Trending tags (`/v1/trending-tags/novel`)

struct PixivNovelTrendingTagsResponse: Decodable, Sendable {
    let trendTags: [PixivNovelTrendTag]

    enum CodingKeys: String, CodingKey {
        case trendTags = "trend_tags"
    }
}

struct PixivNovelTrendTag: Decodable, Hashable, Sendable {
    let tag: String
    let translatedName: String?
    let novel: PixivNovel?

    enum CodingKeys: String, CodingKey {
        case tag
        case translatedName = "translated_name"
        case novel
    }
}
