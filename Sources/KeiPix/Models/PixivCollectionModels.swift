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
}

struct PixivCollectionDetailResponse: Decodable, Sendable {
    let detail: PixivCollectionDetail

    private enum CodingKeys: String, CodingKey {
        case thumbnails
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
        detail = summary.detail(artworks: works.map { $0.artwork() })
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
        thumbnailImageURL = container.decodeCleanURLIfPresent(forKey: .thumbnailImageURL)
        status = try container.decodeIfPresent(String.self, forKey: .status) ?? ""
        publishedDate = Self.parsePublishedDate(try container.decodeIfPresent(String.self, forKey: .publishedDateTime))
    }

    func detail(artworks: [PixivArtwork]) -> PixivCollectionDetail {
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
            artworks: artworks
        )
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
}
