import Foundation

struct CreatorArtworkTag: Decodable, Identifiable, Hashable, Sendable {
    let name: String
    let translatedName: String?
    let yomigana: String?
    let count: Int

    var id: String { name }

    enum CodingKeys: String, CodingKey {
        case name = "tag"
        case translatedName = "tag_translation"
        case yomigana = "tag_yomigana"
        case count = "cnt"
    }

    var displaySubtitle: String? {
        translatedName?.trimmedNonEmpty ?? yomigana?.trimmedNonEmpty
    }

    func matches(_ query: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return true }
        return name.localizedCaseInsensitiveContains(trimmed)
            || translatedName?.localizedCaseInsensitiveContains(trimmed) == true
            || yomigana?.localizedCaseInsensitiveContains(trimmed) == true
    }
}

struct CreatorArtworkTagFilter: Equatable, Hashable, Sendable {
    let userID: Int
    let tag: String
    let expectedCount: Int?

    init(userID: Int, tag: String, expectedCount: Int? = nil) {
        self.userID = userID
        self.tag = tag
        self.expectedCount = expectedCount
    }

    var snapshotKey: String {
        [String(userID), tag, expectedCount.map(String.init) ?? ""].joined(separator: "|")
    }
}

struct PixivWebResponse<Body: Decodable>: Decodable {
    let error: Bool
    let message: String
    let body: Body
}

struct PixivWebProfileAllResponse: Decodable, Sendable {
    let illustIDs: [Int]
    let mangaIDs: [Int]
    let collectionIDs: [String]

    private enum CodingKeys: String, CodingKey {
        case body
    }

    private enum BodyKeys: String, CodingKey {
        case illusts
        case manga
        case collections
        case collectionIDs = "collectionIds"
    }

    init(illustIDs: [Int], mangaIDs: [Int], collectionIDs: [String] = []) {
        self.illustIDs = illustIDs
        self.mangaIDs = mangaIDs
        self.collectionIDs = collectionIDs
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let body = try container.nestedContainer(keyedBy: BodyKeys.self, forKey: .body)
        illustIDs = Self.sortedIDs(from: try body.decodeIfPresent([String: EmptyJSONValue].self, forKey: .illusts) ?? [:])
        mangaIDs = Self.sortedIDs(from: try body.decodeIfPresent([String: EmptyJSONValue].self, forKey: .manga) ?? [:])
        collectionIDs = try body.decodeIfPresent([String].self, forKey: .collectionIDs)
            ?? Self.sortedCollectionIDs(from: try body.decodeIfPresent([String: EmptyJSONValue].self, forKey: .collections) ?? [:])
    }

    private static func sortedIDs(from dictionary: [String: EmptyJSONValue]) -> [Int] {
        dictionary.keys.compactMap(Int.init).sorted(by: >)
    }

    private static func sortedCollectionIDs(from dictionary: [String: EmptyJSONValue]) -> [String] {
        dictionary.keys.sorted(by: >)
    }
}

struct PixivWebProfileIllustsResponse: Decodable, Sendable {
    let works: [PixivWebProfileArtwork]

    private enum CodingKeys: String, CodingKey {
        case body
    }

    private enum BodyKeys: String, CodingKey {
        case works
    }

    init(works: [PixivWebProfileArtwork]) {
        self.works = works
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let body = try container.nestedContainer(keyedBy: BodyKeys.self, forKey: .body)
        let worksByID = try body.decodeIfPresent([String: PixivWebProfileArtwork].self, forKey: .works) ?? [:]
        works = worksByID.values.sorted { $0.id > $1.id }
    }
}

struct PixivWebProfileArtwork: Decodable, Identifiable, Hashable, Sendable {
    let id: Int
    let title: String
    let illustType: Int
    let xRestrict: Int
    let sanityLevel: Int
    let thumbnailURL: URL?
    let caption: String
    let tags: [String]
    let userID: Int
    let userName: String
    let width: Int
    let height: Int
    let pageCount: Int
    let isBookmarked: Bool
    let createDate: Date
    let isAI: Bool
    let profileImageURL: URL?

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case illustType
        case xRestrict
        case sanityLevel = "sl"
        case thumbnailURL = "url"
        case caption = "description"
        case tags
        case userID = "userId"
        case userName
        case width
        case height
        case pageCount
        case bookmarkData
        case createDate
        case aiType
        case profileImageURL = "profileImageUrl"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawID = try container.decode(String.self, forKey: .id)
        let rawUserID = try container.decode(String.self, forKey: .userID)
        guard let id = Int(rawID), let userID = Int(rawUserID) else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: container.codingPath, debugDescription: "Pixiv Web artwork IDs must be numeric")
            )
        }

        self.id = id
        self.userID = userID
        title = try container.decode(String.self, forKey: .title)
        illustType = try container.decodeIfPresent(Int.self, forKey: .illustType) ?? 0
        xRestrict = try container.decodeIfPresent(Int.self, forKey: .xRestrict) ?? 0
        sanityLevel = try container.decodeIfPresent(Int.self, forKey: .sanityLevel) ?? 0
        thumbnailURL = container.decodeCleanURLIfPresent(forKey: .thumbnailURL)
        caption = try container.decodeIfPresent(String.self, forKey: .caption) ?? ""
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        userName = try container.decodeIfPresent(String.self, forKey: .userName) ?? ""
        width = try container.decodeIfPresent(Int.self, forKey: .width) ?? 1
        height = try container.decodeIfPresent(Int.self, forKey: .height) ?? 1
        pageCount = try container.decodeIfPresent(Int.self, forKey: .pageCount) ?? 1
        isBookmarked = (try? container.decodeIfPresent(EmptyJSONValue.self, forKey: .bookmarkData) != nil) ?? false
        createDate = Self.parseDate(try container.decodeIfPresent(String.self, forKey: .createDate))
        isAI = (try container.decodeIfPresent(Int.self, forKey: .aiType) ?? 0) == 2
        profileImageURL = container.decodeCleanURLIfPresent(forKey: .profileImageURL)
    }

    var matchesTypeName: String {
        switch illustType {
        case 1: "manga"
        case 2: "ugoira"
        default: "illust"
        }
    }

    func containsTag(_ tag: String) -> Bool {
        tags.contains { $0.localizedCaseInsensitiveCompare(tag) == .orderedSame }
    }

    func artwork(fallbackUser: PixivUser? = nil) -> PixivArtwork {
        let resolvedUser = fallbackUser.map { user in
            PixivUser(
                id: user.id,
                name: user.name.isEmpty ? userName : user.name,
                account: user.account,
                comment: user.comment,
                avatarURL: user.avatarURL ?? profileImageURL,
                isFollowed: user.isFollowed
            )
        } ?? PixivUser(
            id: userID,
            name: userName,
            account: "",
            avatarURL: profileImageURL,
            isFollowed: false
        )

        let image = PixivImageSet(
            squareMedium: thumbnailURL,
            medium: thumbnailURL,
            large: thumbnailURL,
            original: nil
        )

        return PixivArtwork(
            id: id,
            title: title,
            type: matchesTypeName,
            caption: caption,
            user: resolvedUser,
            tags: tags.map { PixivTag(name: $0, translatedName: nil) },
            createDate: createDate,
            pageCount: pageCount,
            width: width,
            height: height,
            totalView: 0,
            totalBookmarks: 0,
            totalComments: 0,
            isBookmarked: isBookmarked,
            isMuted: false,
            isAI: isAI,
            sanityLevel: sanityLevel,
            xRestrict: xRestrict,
            series: nil,
            images: thumbnailURL == nil ? [] : [image]
        )
    }

    private static func parseDate(_ rawValue: String?) -> Date {
        guard let rawValue else { return Date(timeIntervalSince1970: 0) }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: rawValue) ?? Date(timeIntervalSince1970: 0)
    }
}

struct EmptyJSONValue: Decodable, Hashable, Sendable {
    init() {}

    init(from decoder: Decoder) throws {
        _ = try? decoder.singleValueContainer()
    }
}

extension PixivArtwork {
    func containsTag(_ tag: String) -> Bool {
        tags.contains { $0.name.localizedCaseInsensitiveCompare(tag) == .orderedSame }
    }

    var isPixivWebProfileSummary: Bool {
        guard let image = images.first,
              image.original == nil,
              let url = image.squareMedium ?? image.medium ?? image.large else {
            return false
        }

        let rawValue = url.absoluteString
        return rawValue.contains("i.pximg.net/c/")
            && rawValue.contains("_square")
    }
}
