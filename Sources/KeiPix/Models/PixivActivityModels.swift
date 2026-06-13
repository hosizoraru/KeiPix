import Foundation

enum PixivActivityKind: String, CaseIterable, Codable, Sendable {
    case postedArtwork
    case bookmarkedArtwork
    case followedUser
    case unknown

    static func resolving(_ rawValue: String?) -> PixivActivityKind {
        let value = rawValue?
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: " ", with: "_")
            .lowercased() ?? ""

        if value.contains("bookmark") || value.contains("favorite") {
            return .bookmarkedArtwork
        }
        if value.contains("follow") {
            return .followedUser
        }
        if value.contains("post") || value.contains("upload") || value.contains("illust") || value.contains("artwork") {
            return .postedArtwork
        }
        return .unknown
    }
}

enum PixivActivityTargetKind: String, Codable, Sendable {
    case artwork
    case user
    case unknown
}

struct PixivActivityActor: Equatable, Hashable, Sendable {
    let userID: Int?
    let name: String
    let avatarURL: URL?

    var pixivUser: PixivUser? {
        guard let userID else { return nil }
        return PixivUser(
            id: userID,
            name: name,
            account: "",
            avatarURL: avatarURL,
            isFollowed: false
        )
    }
}

struct PixivActivityTarget: Equatable, Hashable, Sendable {
    let kind: PixivActivityTargetKind
    let id: String
    let title: String
    let url: URL?
    let thumbnailURL: URL?
}

struct PixivActivityItem: Identifiable, Equatable, Hashable, Sendable {
    let id: String
    let kind: PixivActivityKind
    let actor: PixivActivityActor?
    let target: PixivActivityTarget?
    let occurredAt: Date?
    let summary: String
}

struct PixivActivityPage: Equatable, Sendable {
    let items: [PixivActivityItem]
    let nextURL: URL?
    let sourceURL: URL?
}

enum PixivActivityFeedParser {
    static func parsePage(_ html: String, sourceURL: URL? = nil) -> PixivActivityPage {
        let parsedItems = parseEmbeddedJSONActivities(in: html, sourceURL: sourceURL)
            + parseHTMLActivities(in: html, sourceURL: sourceURL)

        var seenIDs = Set<String>()
        let items = parsedItems.filter { item in
            guard seenIDs.contains(item.id) == false else { return false }
            seenIDs.insert(item.id)
            return true
        }

        return PixivActivityPage(
            items: items,
            nextURL: nextPageURL(in: html, sourceURL: sourceURL),
            sourceURL: sourceURL
        )
    }

    private static func parseEmbeddedJSONActivities(in html: String, sourceURL: URL?) -> [PixivActivityItem] {
        embeddedJSONStrings(in: html).flatMap { jsonString -> [PixivActivityItem] in
            guard let data = decodeHTMLText(jsonString).data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(with: data)
            else {
                return []
            }
            return activityItems(from: object, sourceURL: sourceURL)
        }
    }

    private static func embeddedJSONStrings(in html: String) -> [String] {
        let patterns = [
            #"<script\b[^>]*id=["']__NEXT_DATA__["'][^>]*>([\s\S]*?)</script>"#,
            #"<script\b[^>]*type=["']application/json["'][^>]*>([\s\S]*?)</script>"#
        ]
        return patterns.flatMap { groups(in: html, pattern: $0) }
    }

    private static func activityItems(from object: Any, sourceURL: URL?) -> [PixivActivityItem] {
        var items: [PixivActivityItem] = []

        func walk(_ value: Any) {
            if let dictionary = value as? [String: Any] {
                if let item = activityItem(from: dictionary, sourceURL: sourceURL) {
                    items.append(item)
                }
                dictionary.values.forEach(walk)
            } else if let array = value as? [Any] {
                array.forEach(walk)
            }
        }

        walk(object)
        return items
    }

    private static func activityItem(from dictionary: [String: Any], sourceURL: URL?) -> PixivActivityItem? {
        let rawKind = firstString(in: dictionary, keys: [
            "activityType", "activity_type", "actionType", "action_type", "staccType", "eventType", "kind", "type", "action"
        ])
        let kind = PixivActivityKind.resolving(rawKind)
        guard kind != .unknown || rawKind != nil else { return nil }

        let actor = actor(in: dictionary, sourceURL: sourceURL)
        let target = target(in: dictionary, kind: kind, sourceURL: sourceURL)
        guard actor != nil || target != nil else { return nil }

        let occurredAt = firstString(in: dictionary, keys: [
            "createdAt", "created_at", "createdTime", "created_time", "postedAt", "publishedAt", "date"
        ]).flatMap(parseDate)
        let summary = firstString(in: dictionary, keys: ["summary", "text", "message", "comment", "description"])
            ?? target?.title
            ?? rawKind
            ?? ""
        let id = firstString(in: dictionary, keys: ["activityId", "activity_id", "staccId", "stacc_id", "id"])
            ?? [
                kind.rawValue,
                actor?.userID.map(String.init),
                target?.id,
                occurredAt.map { ISO8601DateFormatter().string(from: $0) }
            ]
            .compactMap(\.self)
            .joined(separator: ":")

        return PixivActivityItem(
            id: id,
            kind: kind,
            actor: actor,
            target: target,
            occurredAt: occurredAt,
            summary: summary
        )
    }

    private static func actor(in dictionary: [String: Any], sourceURL: URL?) -> PixivActivityActor? {
        let nested = firstDictionary(in: dictionary, keys: ["actor", "fromUser", "from_user", "user", "userInfo", "user_info"])
        let source = nested ?? dictionary
        let userID = firstInt(in: source, keys: ["userId", "userID", "user_id", "uid", "id"])
        let name = firstString(in: source, keys: ["userName", "user_name", "name", "account", "screenName"])
        let avatarURL = firstURL(in: source, keys: [
            "profileImageUrl", "profile_image_url", "profileImage", "avatar", "image", "imageUrl"
        ], sourceURL: sourceURL)

        guard userID != nil || name != nil || avatarURL != nil else { return nil }
        return PixivActivityActor(
            userID: userID,
            name: name ?? "",
            avatarURL: avatarURL
        )
    }

    private static func target(
        in dictionary: [String: Any],
        kind: PixivActivityKind,
        sourceURL: URL?
    ) -> PixivActivityTarget? {
        let nestedKeys: [String]
        switch kind {
        case .followedUser:
            nestedKeys = ["targetUser", "target_user", "followUser", "follow_user", "target"]
        case .postedArtwork, .bookmarkedArtwork, .unknown:
            nestedKeys = ["illust", "artwork", "work", "targetIllust", "target_illust", "targetArtwork", "target"]
        }

        let source = firstDictionary(in: dictionary, keys: nestedKeys) ?? dictionary
        let targetKind: PixivActivityTargetKind = kind == .followedUser ? .user : .artwork
        let idKeys: [String] = targetKind == .user
            ? ["userId", "userID", "user_id", "uid", "id", "targetUserId"]
            : ["illustId", "illustID", "illust_id", "artworkId", "artworkID", "workId", "id", "targetIllustId"]
        guard let id = firstString(in: source, keys: idKeys)
            ?? firstInt(in: source, keys: idKeys).map(String.init)
        else {
            return nil
        }

        let title = firstString(in: source, keys: [
            "title", "illustTitle", "illust_title", "workTitle", "work_title", "userName", "user_name", "name"
        ]) ?? ""
        let explicitURL = firstURL(in: source, keys: ["url", "href", "permalink", "link"], sourceURL: sourceURL)
        let fallbackURL = fallbackTargetURL(kind: targetKind, id: id)
        let thumbnailURL = firstURL(in: source, keys: [
            "thumbnailUrl", "thumbnail_url", "thumbnail", "imageUrl", "image_url", "profileImageUrl"
        ], sourceURL: sourceURL)

        return PixivActivityTarget(
            kind: targetKind,
            id: id,
            title: title,
            url: explicitURL ?? fallbackURL,
            thumbnailURL: thumbnailURL
        )
    }

    private static func parseHTMLActivities(in html: String, sourceURL: URL?) -> [PixivActivityItem] {
        let pattern = #"<(?:article|li|div)\b[^>]*(?:data-activity-id|stacc|activity)[^>]*>[\s\S]*?</(?:article|li|div)>"#
        return groups(in: html, pattern: "(\(pattern))", decodeAsText: false)
            .compactMap { htmlActivityItem(from: $0, sourceURL: sourceURL) }
    }

    private static func htmlActivityItem(from block: String, sourceURL: URL?) -> PixivActivityItem? {
        let text = strippedText(block)
        let classValue = firstAttributeValue(named: "class", in: block) ?? ""
        let kind = PixivActivityKind.resolving("\(classValue) \(text)")
        let userLinks = userAnchors(in: block, sourceURL: sourceURL)
        let artworkLinks = artworkAnchors(in: block, sourceURL: sourceURL)

        let actor = userLinks.first.map { link in
            PixivActivityActor(userID: Int(link.id), name: link.title, avatarURL: nil)
        }
        let target: PixivActivityTarget? = {
            if kind == .followedUser, let link = userLinks.dropFirst().first ?? userLinks.first {
                return PixivActivityTarget(kind: .user, id: link.id, title: link.title, url: link.url, thumbnailURL: nil)
            }
            if let link = artworkLinks.first {
                return PixivActivityTarget(kind: .artwork, id: link.id, title: link.title, url: link.url, thumbnailURL: link.thumbnailURL)
            }
            return nil
        }()

        guard actor != nil || target != nil else { return nil }
        let id = firstAttributeValue(named: "data-activity-id", in: block)
            ?? [kind.rawValue, actor?.userID.map(String.init), target?.id].compactMap(\.self).joined(separator: ":")

        return PixivActivityItem(
            id: id,
            kind: kind,
            actor: actor,
            target: target,
            occurredAt: firstAttributeValue(named: "datetime", in: block).flatMap(parseDate),
            summary: text
        )
    }

    private static func nextPageURL(in html: String, sourceURL: URL?) -> URL? {
        let patterns = [
            #"<a\b[^>]*rel=["']next["'][^>]*href=["']([^"']+)["']"#,
            #"<link\b[^>]*rel=["']next["'][^>]*href=["']([^"']+)["']"#,
            #"data-next-url=["']([^"']+)["']"#,
            #""next(?:Url|URL|_url)"\s*:\s*"([^"]+)""#
        ]

        return patterns
            .lazy
            .compactMap { firstMatchedGroup(in: html, pattern: $0, decodeAsText: true) }
            .compactMap { value in
                let unescaped = value.replacingOccurrences(of: #"\/"#, with: "/")
                return resolvedURL(from: unescaped, sourceURL: sourceURL)
            }
            .first
    }

    private struct Anchor {
        let id: String
        let title: String
        let url: URL?
        let thumbnailURL: URL?
    }

    private static func userAnchors(in html: String, sourceURL: URL?) -> [Anchor] {
        anchors(in: html, path: "users", sourceURL: sourceURL)
    }

    private static func artworkAnchors(in html: String, sourceURL: URL?) -> [Anchor] {
        anchors(in: html, path: "artworks", sourceURL: sourceURL)
    }

    private static func anchors(in html: String, path: String, sourceURL: URL?) -> [Anchor] {
        let pattern = #"(<a\b[^>]*href=["']/\#(path)/([0-9]+)["'][^>]*>[\s\S]*?</a>)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else {
            return []
        }

        let nsRange = NSRange(html.startIndex..<html.endIndex, in: html)
        return regex.matches(in: html, options: [], range: nsRange).compactMap { match in
            guard let anchorRange = Range(match.range(at: 1), in: html),
                  let idRange = Range(match.range(at: 2), in: html)
            else {
                return nil
            }
            let anchorHTML = String(html[anchorRange])
            let id = String(html[idRange])
            let href = firstAttributeValue(named: "href", in: anchorHTML)
            let title = firstAttributeValue(named: "title", in: anchorHTML)
                ?? firstAttributeValue(named: "alt", in: anchorHTML)
                ?? strippedText(anchorHTML)
            return Anchor(
                id: id,
                title: title,
                url: href.flatMap { resolvedURL(from: $0, sourceURL: sourceURL) },
                thumbnailURL: firstAttributeValue(named: "src", in: anchorHTML).flatMap { resolvedURL(from: $0, sourceURL: sourceURL) }
            )
        }
    }

    private static func fallbackTargetURL(kind: PixivActivityTargetKind, id: String) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "www.pixiv.net"
        switch kind {
        case .artwork:
            components.path = "/artworks/\(id)"
        case .user:
            components.path = "/users/\(id)"
        case .unknown:
            return nil
        }
        return components.url
    }

    private static func parseDate(_ value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) {
            return date
        }

        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
    }

    private static func firstDictionary(in dictionary: [String: Any], keys: [String]) -> [String: Any]? {
        for key in keys {
            if let value = dictionary[key] as? [String: Any] {
                return value
            }
        }
        return nil
    }

    private static func firstString(in dictionary: [String: Any], keys: [String]) -> String? {
        for key in keys {
            if let value = dictionary[key] as? String {
                let trimmed = decodeHTMLText(value).trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty == false {
                    return trimmed
                }
            }
            if let value = dictionary[key] as? NSNumber {
                return value.stringValue
            }
        }
        return nil
    }

    private static func firstInt(in dictionary: [String: Any], keys: [String]) -> Int? {
        for key in keys {
            if let value = dictionary[key] as? Int {
                return value
            }
            if let value = dictionary[key] as? NSNumber {
                return value.intValue
            }
            if let value = dictionary[key] as? String, let intValue = Int(value) {
                return intValue
            }
        }
        return nil
    }

    private static func firstURL(in dictionary: [String: Any], keys: [String], sourceURL: URL?) -> URL? {
        firstString(in: dictionary, keys: keys).flatMap { resolvedURL(from: $0, sourceURL: sourceURL) }
    }

    private static func resolvedURL(from rawValue: String, sourceURL: URL?) -> URL? {
        let decoded = decodeHTMLText(rawValue)
        if let absolute = URL(string: decoded), absolute.scheme != nil {
            return absolute
        }
        if let sourceURL, let relative = URL(string: decoded, relativeTo: sourceURL) {
            return relative.absoluteURL
        }
        if decoded.hasPrefix("/") {
            return URL(string: "https://www.pixiv.net\(decoded)")
        }
        return nil
    }

    private static func firstAttributeValue(named name: String, in html: String) -> String? {
        let escaped = NSRegularExpression.escapedPattern(for: name)
        let pattern = #"\#(escaped)=["']([^"']*)["']"#
        return firstMatchedGroup(in: html, pattern: pattern, decodeAsText: true)
    }

    private static func firstMatchedGroup(
        in html: String,
        pattern: String,
        decodeAsText: Bool = true
    ) -> String? {
        groups(in: html, pattern: pattern, decodeAsText: decodeAsText).first
    }

    private static func groups(in html: String, pattern: String, decodeAsText: Bool = true) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else {
            return []
        }

        let nsRange = NSRange(html.startIndex..<html.endIndex, in: html)
        return regex.matches(in: html, options: [], range: nsRange).compactMap { match in
            guard match.numberOfRanges > 1,
                  let range = Range(match.range(at: 1), in: html)
            else {
                return nil
            }
            let value = String(html[range])
            return decodeAsText ? decodeHTMLText(value) : value
        }
    }

    private static func strippedText(_ html: String) -> String {
        let withoutTags = html.replacingOccurrences(
            of: #"<[^>]+>"#,
            with: " ",
            options: .regularExpression
        )
        return decodeHTMLText(withoutTags)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func decodeHTMLText(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#039;", with: "'")
            .replacingOccurrences(of: "&#x2F;", with: "/")
    }
}
