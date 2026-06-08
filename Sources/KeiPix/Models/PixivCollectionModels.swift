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

    var coverImageURL: URL? {
        thumbnailImageURL ?? artworks.first?.thumbnailURL
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

enum PixivCollectionHTMLParser {
    private struct CollectionCardCandidate {
        let id: String
        let thumbnailURL: URL?
        let range: Range<String.Index>
    }

    static func parseListPage(
        _ html: String,
        sourceURL: URL,
        offset: Int = 0,
        limit: Int = 48
    ) -> PixivCollectionListPage {
        let normalizedOffset = max(offset, 0)
        let normalizedLimit = max(limit, 1)
        let collections = parseCards(in: html, sourceURL: sourceURL)
        let total = parsedTotalCount(in: html)
            ?? fallbackTotalCount(
                in: html,
                collectionCount: collections.count,
                offset: normalizedOffset
            )
        return PixivCollectionListPage(
            collections: collections,
            total: total,
            offset: normalizedOffset,
            limit: normalizedLimit
        )
    }

    private static func parseCards(in html: String, sourceURL: URL) -> [PixivCollectionDetail] {
        let candidates = collectionCardCandidates(in: html, sourceURL: sourceURL)
        guard candidates.isEmpty == false else { return [] }

        var collections: [PixivCollectionDetail] = []
        var seenIDs = Set<String>()

        for (index, candidate) in candidates.enumerated() {
            guard seenIDs.insert(candidate.id).inserted else { continue }

            let endIndex = cardEndIndex(
                after: candidate,
                nextCandidate: candidates.dropFirst(index + 1).first,
                in: html
            )
            let cardHTML = String(html[candidate.range.lowerBound..<endIndex])
            let title = title(in: cardHTML, id: candidate.id) ?? ""
            let owner = owner(in: cardHTML, sourceURL: sourceURL)

            collections.append(
                PixivCollectionDetail(
                    id: candidate.id,
                    title: title,
                    owner: owner,
                    tags: [],
                    caption: "",
                    bookmarkCount: 0,
                    viewCount: 0,
                    thumbnailImageURL: normalizedThumbnailImageURL(candidate.thumbnailURL),
                    status: "",
                    publishedDate: nil,
                    artworks: []
                )
            )
        }
        return collections
    }

    private static func collectionCardCandidates(
        in html: String,
        sourceURL: URL
    ) -> [CollectionCardCandidate] {
        let pattern = #"<a\b[^>]*href="/collections/([0-9]+)"[^>]*>[\s\S]*?</a>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else {
            return []
        }

        var candidates: [CollectionCardCandidate] = []
        let nsRange = NSRange(html.startIndex..<html.endIndex, in: html)
        regex.enumerateMatches(in: html, options: [], range: nsRange) { match, _, _ in
            guard let match,
                  let idRange = Range(match.range(at: 1), in: html),
                  let matchRange = Range(match.range(at: 0), in: html) else {
                return
            }

            let id = String(html[idRange])
            let anchorHTML = String(html[matchRange])
            let thumbnailURL = imageURL(in: anchorHTML, sourceURL: sourceURL)
            let isCoverAnchor = anchorHTML.contains(#"data-ga4-label="collection_link""#)
                || thumbnailURL != nil
            guard isCoverAnchor else {
                return
            }

            candidates.append(
                CollectionCardCandidate(
                    id: id,
                    thumbnailURL: thumbnailURL,
                    range: matchRange
                )
            )
        }
        return candidates
    }

    private static func cardEndIndex(
        after candidate: CollectionCardCandidate,
        nextCandidate: CollectionCardCandidate?,
        in html: String
    ) -> String.Index {
        if let nextCandidate {
            return nextCandidate.range.lowerBound
        }

        let searchRange = candidate.range.upperBound..<html.endIndex
        let sectionEnd = html.range(of: "</section>", range: searchRange)?.lowerBound
        let navStart = html.range(of: "<nav", range: searchRange)?.lowerBound
        return [sectionEnd, navStart]
            .compactMap(\.self)
            .min() ?? html.endIndex
    }

    private static func title(in html: String, id: String) -> String? {
        let escapedID = NSRegularExpression.escapedPattern(for: id)
        let pattern = #"<a\b[^>]*href="/collections/\#(escapedID)"[^>]*>[\s\S]*?</a>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else {
            return nil
        }

        let nsRange = NSRange(html.startIndex..<html.endIndex, in: html)
        let baseURL = PixivWebURLBuilder.collectionsURL()
            ?? URL(string: "https://www.pixiv.net/collections")!
        for match in regex.matches(in: html, options: [], range: nsRange) {
            guard let matchRange = Range(match.range(at: 0), in: html) else { continue }
            let anchorHTML = String(html[matchRange])
            guard imageURL(in: anchorHTML, sourceURL: baseURL) == nil else {
                continue
            }
            let value = firstAttributeValue(named: "title", in: anchorHTML)
                ?? strippedText(anchorHTML)
            if value.isEmpty == false {
                return value
            }
        }
        return nil
    }

    private static func owner(in html: String, sourceURL: URL) -> PixivUser {
        let ownerAnchor = firstMatchedGroup(
            in: html,
            pattern: #"(<a\b[^>]*href="/users/[0-9]+"[^>]*>[\s\S]*?</a>)"#,
            decodeAsText: false
        ) ?? ""
        let ownerID = firstMatchedGroup(in: ownerAnchor, pattern: #"href="/users/([0-9]+)""#)
            .flatMap(Int.init)
            ?? firstMatchedGroup(in: html, pattern: #"href="/users/([0-9]+)""#).flatMap(Int.init)
            ?? 0
        let ownerName = firstAttributeValue(named: "alt", in: ownerAnchor)
            ?? firstAttributeValue(named: "title", in: ownerAnchor)
            ?? strippedText(ownerAnchor)
        let avatarURL = imageURL(in: ownerAnchor, sourceURL: sourceURL)

        return PixivUser(
            id: ownerID,
            name: ownerName,
            account: "",
            avatarURL: avatarURL,
            isFollowed: false
        )
    }

    private static func parsedTotalCount(in html: String) -> Int? {
        let headingPattern = #"<h2\b[^>]*>[\s\S]*?</h2>[\s\S]{0,1200}?<span\b[^>]*>([0-9][0-9,]*)</span>"#
        return firstMatchedGroup(in: html, pattern: headingPattern)
            .map { $0.replacingOccurrences(of: ",", with: "") }
            .flatMap(Int.init)
    }

    private static func fallbackTotalCount(
        in html: String,
        collectionCount: Int,
        offset: Int
    ) -> Int {
        let loadedCount = offset + collectionCount
        guard hasEnabledNextPage(in: html) else {
            return loadedCount
        }
        return loadedCount + 1
    }

    private static func hasEnabledNextPage(in html: String) -> Bool {
        if let nextAnchor = firstMatchedGroup(
            in: html,
            pattern: #"(<a\b[^>]*aria-label="Next"[^>]*>)"#,
            decodeAsText: false
        ) {
            return isEnabledPaginationAnchor(nextAnchor)
        }
        return paginationAnchorWithPageNumber(in: html).map(isEnabledPaginationAnchor) ?? false
    }

    private static func paginationAnchorWithPageNumber(in html: String) -> String? {
        firstMatchedGroup(
            in: html,
            pattern: #"(<a\b[^>]*href="[^"]*[?&]p=[0-9]+[^"]*"[^>]*>)"#,
            decodeAsText: false
        )
    }

    private static func isEnabledPaginationAnchor(_ anchor: String) -> Bool {
        anchor.contains("hidden") == false
            && anchor.contains(#"aria-disabled="true""#) == false
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

    private static func imageURL(in html: String, sourceURL: URL) -> URL? {
        let rawValue = firstAttributeValue(named: "src", in: html)
            ?? firstAttributeValue(named: "data-src", in: html)
            ?? firstSrcsetURL(in: html)
        return rawValue.flatMap { absoluteURL(from: $0, sourceURL: sourceURL) }
    }

    private static func firstSrcsetURL(in html: String) -> String? {
        guard let srcset = firstAttributeValue(named: "srcset", in: html) else {
            return nil
        }
        return srcset
            .split(separator: ",")
            .lazy
            .compactMap { candidate -> String? in
                let parts = candidate.split(whereSeparator: \.isWhitespace)
                return parts.first.map(String.init)
            }
            .first
    }

    private static func absoluteURL(from rawValue: String, sourceURL: URL) -> URL? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return nil }
        return URL(string: trimmed, relativeTo: sourceURL)?.absoluteURL
    }

    private static func firstAttributeValue(named name: String, in html: String) -> String? {
        let escaped = NSRegularExpression.escapedPattern(for: name)
        return firstMatchedGroup(in: html, pattern: #"\b\#(escaped)="([^"]*)""#)
    }

    private static func firstMatchedGroup(
        in html: String,
        pattern: String,
        decodeAsText: Bool = true
    ) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else {
            return nil
        }
        let nsRange = NSRange(html.startIndex..<html.endIndex, in: html)
        guard let match = regex.firstMatch(in: html, options: [], range: nsRange),
              match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: html) else {
            return nil
        }
        let value = String(html[range])
        return decodeAsText ? htmlDecoded(value) : value
    }

    private static func strippedText(_ html: String) -> String {
        let withoutTags = html.replacingOccurrences(
            of: #"<[^>]+>"#,
            with: " ",
            options: .regularExpression
        )
        return htmlDecoded(withoutTags)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func htmlDecoded(_ input: String) -> String {
        var output = input
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#34;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&apos;", with: "'")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&amp;", with: "&")

        guard let regex = try? NSRegularExpression(pattern: #"&#x?([0-9A-Fa-f]+);"#) else {
            return output
        }
        let matches = regex.matches(
            in: output,
            options: [],
            range: NSRange(output.startIndex..<output.endIndex, in: output)
        )
        for match in matches.reversed() {
            guard let fullRange = Range(match.range(at: 0), in: output),
                  let valueRange = Range(match.range(at: 1), in: output) else {
                continue
            }
            let rawValue = String(output[valueRange])
            let radix = output[fullRange].hasPrefix("&#x") ? 16 : 10
            guard let scalarValue = UInt32(rawValue, radix: radix),
                  let scalar = UnicodeScalar(scalarValue) else {
                continue
            }
            output.replaceSubrange(fullRange, with: String(Character(scalar)))
        }
        return output
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
