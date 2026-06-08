import Foundation

enum PixivCollectionListMode: String, Sendable {
    case discovery
    case created
    case saved

    var route: PixivRoute {
        switch self {
        case .discovery:
            .pixivCollections
        case .created:
            .myPixivCollections
        case .saved:
            .savedPixivCollections
        }
    }

    var title: String {
        switch self {
        case .discovery:
            L10n.pixivCollections
        case .created:
            L10n.myPixivCollections
        case .saved:
            L10n.savedPixivCollections
        }
    }

    var emptyHint: String {
        switch self {
        case .discovery:
            L10n.pixivCollectionsEmptyHint
        case .created:
            L10n.myPixivCollectionsEmptyHint
        case .saved:
            L10n.savedPixivCollectionsEmptyHint
        }
    }

    var webActionTitle: String {
        switch self {
        case .discovery:
            L10n.openPixivWebCollections
        case .created:
            L10n.openPixivWebMyCollections
        case .saved:
            L10n.openPixivWebSavedCollections
        }
    }
}

struct PixivCollectionListPage: Equatable, Sendable {
    let collections: [PixivCollectionDetail]
    let total: Int
    let offset: Int
    let limit: Int

    var nextOffset: Int? {
        let loadedCount = offset + collections.count
        guard collections.isEmpty == false, loadedCount < total else { return nil }
        return loadedCount
    }

    init(collections: [PixivCollectionDetail], total: Int, offset: Int, limit: Int) {
        self.collections = collections
        self.total = max(total, collections.count)
        self.offset = max(offset, 0)
        self.limit = max(limit, 1)
    }

    static let empty = PixivCollectionListPage(collections: [], total: 0, offset: 0, limit: 1)
}

struct PixivCollectionDetail: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let owner: PixivUser
    let tags: [PixivTag]
    let caption: String
    let bookmarkCount: Int
    let viewCount: Int
    let thumbnailImageURL: URL?
    let status: String
    let publishedDate: Date?
    let artworks: [PixivArtwork]
    let relatedCollections: [PixivCollectionDetail]

    init(
        id: String,
        title: String,
        owner: PixivUser,
        tags: [PixivTag],
        caption: String,
        bookmarkCount: Int,
        viewCount: Int,
        thumbnailImageURL: URL?,
        status: String,
        publishedDate: Date?,
        artworks: [PixivArtwork],
        relatedCollections: [PixivCollectionDetail] = []
    ) {
        self.id = id
        self.title = title
        self.owner = owner
        self.tags = tags
        self.caption = caption
        self.bookmarkCount = bookmarkCount
        self.viewCount = viewCount
        self.thumbnailImageURL = thumbnailImageURL
        self.status = status
        self.publishedDate = publishedDate
        self.artworks = artworks
        self.relatedCollections = relatedCollections
    }

    var pixivURL: URL? {
        PixivWebURLBuilder.collectionURL(id: id)
    }

    var subtitle: String {
        var parts: [String] = []
        if owner.name.isEmpty == false {
            parts.append(owner.name)
        }
        if artworks.isEmpty == false {
            parts.append(String(format: L10n.collectionWorksCountFormat, artworks.count))
        }
        return parts.joined(separator: " · ")
    }

    var masonryAspectRatio: CGFloat {
        var textReserve: CGFloat = 0.28
        if title.count > 24 {
            textReserve += 0.08
        }
        if tags.isEmpty == false {
            textReserve += 0.07
        }
        return max(0.62, 1.0 - textReserve)
    }
}

struct PixivCollectionDetailResponse: Decodable, Sendable {
    let detail: PixivCollectionDetail

    private enum CodingKeys: String, CodingKey {
        case data
        case thumbnails
    }

    private enum DataKeys: String, CodingKey {
        case userCollections
    }

    private enum ThumbnailKeys: String, CodingKey {
        case illust
        case collection
    }

    init(detail: PixivCollectionDetail) {
        self.detail = detail
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let thumbnails = try container.nestedContainer(keyedBy: ThumbnailKeys.self, forKey: .thumbnails)
        let summaries = try thumbnails.decodeIfPresent([PixivCollectionSummary].self, forKey: .collection) ?? []
        guard let summary = summaries.first else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: thumbnails.codingPath,
                    debugDescription: "Pixiv collection detail response must include collection metadata"
                )
            )
        }
        let works = try thumbnails.decodeIfPresent([PixivWebProfileArtwork].self, forKey: .illust) ?? []

        let relatedSummaries: [PixivCollectionSummary]
        if let data = try? container.nestedContainer(keyedBy: DataKeys.self, forKey: .data),
           let userCollections = try data.decodeIfPresent(PixivCollectionSummaryList.self, forKey: .userCollections) {
            relatedSummaries = userCollections.summaries
                .filter { $0.id != summary.id }
                .sorted(by: PixivCollectionSummary.relatedSort)
        } else {
            relatedSummaries = []
        }

        detail = summary.detail(
            artworks: works.map { $0.artwork() },
            relatedCollections: relatedSummaries.map { $0.detail(artworks: []) }
        )
    }
}

struct PixivCollectionSearchResponse: Decodable, Sendable {
    let collections: [PixivCollectionDetail]
    let total: Int

    private enum CodingKeys: String, CodingKey {
        case thumbnails
        case data
    }

    private enum ThumbnailKeys: String, CodingKey {
        case collection
    }

    private enum DataKeys: String, CodingKey {
        case ids
        case total
    }

    init(collections: [PixivCollectionDetail], total: Int) {
        self.collections = collections
        self.total = total
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let thumbnails = try container.nestedContainer(keyedBy: ThumbnailKeys.self, forKey: .thumbnails)
        let summaries = try thumbnails.decodeIfPresent([PixivCollectionSummary].self, forKey: .collection) ?? []

        let data = try container.nestedContainer(keyedBy: DataKeys.self, forKey: .data)
        let orderedIDs = try data.decodeIfPresent([String].self, forKey: .ids) ?? []
        total = try data.decodeIfPresent(Int.self, forKey: .total) ?? summaries.count

        if orderedIDs.isEmpty {
            collections = summaries.map { $0.detail(artworks: []) }
        } else {
            let summariesByID = Dictionary(uniqueKeysWithValues: summaries.map { ($0.id, $0) })
            collections = orderedIDs.compactMap { summariesByID[$0]?.detail(artworks: []) }
        }
    }
}

struct PixivUserCollectionsResponse: Decodable, Sendable {
    let collections: [PixivCollectionDetail]
    let total: Int

    private enum CodingKeys: String, CodingKey {
        case works
        case thumbnails
        case total
    }

    private enum ThumbnailKeys: String, CodingKey {
        case collection
    }

    init(collections: [PixivCollectionDetail], total: Int) {
        self.collections = collections
        self.total = total
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let works = try container.decodeIfPresent([PixivCollectionSummary].self, forKey: .works) ?? []
        let thumbnailSummaries: [PixivCollectionSummary]
        if let thumbnails = try? container.nestedContainer(keyedBy: ThumbnailKeys.self, forKey: .thumbnails) {
            thumbnailSummaries = try thumbnails.decodeIfPresent([PixivCollectionSummary].self, forKey: .collection) ?? []
        } else {
            thumbnailSummaries = []
        }

        let summaries = works.isEmpty ? thumbnailSummaries : works
        collections = summaries.map { $0.detail(artworks: []) }
        total = try container.decodeIfPresent(Int.self, forKey: .total) ?? summaries.count
    }
}

struct PixivBookmarkedCollectionsResponse: Decodable, Sendable {
    let collections: [PixivCollectionDetail]
    let total: Int

    init(collections: [PixivCollectionDetail], total: Int) {
        self.collections = collections
        self.total = total
    }

    init(from decoder: Decoder) throws {
        let response = try PixivUserCollectionsResponse(from: decoder)
        collections = response.collections
        total = response.total
    }
}

private struct PixivCollectionSummaryList: Decodable, Sendable {
    let summaries: [PixivCollectionSummary]

    init(from decoder: Decoder) throws {
        if let summaries = try? [PixivCollectionSummary](from: decoder) {
            self.summaries = summaries
            return
        }

        let container = try decoder.container(keyedBy: DynamicCodingKey.self)
        summaries = try container.allKeys.compactMap { key in
            try container.decodeIfPresent(PixivCollectionSummary.self, forKey: key)
        }
    }
}

private struct DynamicCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int?

    init?(stringValue: String) {
        self.stringValue = stringValue
        intValue = nil
    }

    init?(intValue: Int) {
        stringValue = String(intValue)
        self.intValue = intValue
    }
}

private struct PixivCollectionSummary: Decodable, Sendable {
    let id: String
    let title: String
    let owner: PixivUser
    let tags: [PixivTag]
    let caption: String
    let bookmarkCount: Int
    let viewCount: Int
    let thumbnailImageURL: URL?
    let status: String
    let publishedDate: Date?

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case userID = "userId"
        case userName
        case profileImageURL = "profileImageUrl"
        case tags
        case caption
        case bookmarkCount
        case viewCount
        case thumbnailImageURL = "thumbnailImageUrl"
        case status
        case publishedDateTime
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""

        let rawUserID = try container.decodeIfPresent(String.self, forKey: .userID) ?? ""
        guard let userID = Int(rawUserID) else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: container.codingPath,
                    debugDescription: "Pixiv collection owner ID must be numeric"
                )
            )
        }
        owner = PixivUser(
            id: userID,
            name: try container.decodeIfPresent(String.self, forKey: .userName) ?? "",
            account: "",
            avatarURL: container.decodeCleanURLIfPresent(forKey: .profileImageURL),
            isFollowed: false
        )

        let rawTags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        tags = rawTags.map { PixivTag(name: $0, translatedName: nil) }
        caption = try container.decodeIfPresent(String.self, forKey: .caption) ?? ""
        bookmarkCount = try container.decodeIfPresent(Int.self, forKey: .bookmarkCount) ?? 0
        viewCount = try container.decodeIfPresent(Int.self, forKey: .viewCount) ?? 0
        thumbnailImageURL = Self.normalizedThumbnailImageURL(
            container.decodeCleanURLIfPresent(forKey: .thumbnailImageURL)
        )
        status = try container.decodeIfPresent(String.self, forKey: .status) ?? ""
        publishedDate = Self.parsePublishedDate(try container.decodeIfPresent(String.self, forKey: .publishedDateTime))
    }

    func detail(
        artworks: [PixivArtwork],
        relatedCollections: [PixivCollectionDetail] = []
    ) -> PixivCollectionDetail {
        PixivCollectionDetail(
            id: id,
            title: title,
            owner: owner,
            tags: tags,
            caption: caption,
            bookmarkCount: bookmarkCount,
            viewCount: viewCount,
            thumbnailImageURL: thumbnailImageURL,
            status: status,
            publishedDate: publishedDate,
            artworks: artworks,
            relatedCollections: relatedCollections
        )
    }

    static func relatedSort(_ lhs: PixivCollectionSummary, _ rhs: PixivCollectionSummary) -> Bool {
        switch (lhs.publishedDate, rhs.publishedDate) {
        case let (lhsDate?, rhsDate?) where lhsDate != rhsDate:
            return lhsDate > rhsDate
        case (_?, nil):
            return true
        case (nil, _?):
            return false
        default:
            return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
        }
    }

    private static func parsePublishedDate(_ rawValue: String?) -> Date? {
        guard let rawValue else { return nil }
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.date(from: rawValue)
    }

    private static func normalizedThumbnailImageURL(_ url: URL?) -> URL? {
        guard let url,
              var components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.host?.lowercased() == "embed.pixiv.net",
              components.path.contains("/next/collection/") else {
            return url
        }

        var queryItems = components.queryItems ?? []
        if queryItems.contains(where: { $0.name == "format" }) == false {
            queryItems.append(URLQueryItem(name: "format", value: "png"))
            components.queryItems = queryItems
        }
        return components.url ?? url
    }
}
