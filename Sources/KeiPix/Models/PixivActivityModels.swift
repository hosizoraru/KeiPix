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

        if value.contains("bookmark")
            || value.contains("favorite")
            || value.contains("收藏")
            || value.contains("ブックマーク") {
            return .bookmarkedArtwork
        }
        if value.contains("follow")
            || value.contains("关注")
            || value.contains("フォロー") {
            return .followedUser
        }
        if value.contains("post")
            || value.contains("upload")
            || value.contains("illust")
            || value.contains("artwork")
            || value.contains("投稿")
            || value.contains("作品") {
            return .postedArtwork
        }
        return .unknown
    }
}

enum PixivActivityTargetKind: String, Codable, Sendable {
    case artwork
    case novel
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
        let preloadPages = parsePreloadStaccPages(in: html, sourceURL: sourceURL)
        let parsedItems = preloadPages.flatMap(\.items)
            + parseEmbeddedJSONActivities(in: html, sourceURL: sourceURL)
            + parseHTMLActivities(in: html, sourceURL: sourceURL)

        return PixivActivityPage(
            items: deduplicated(parsedItems),
            nextURL: preloadPages.lazy.compactMap(\.nextURL).first ?? nextPageURL(in: html, sourceURL: sourceURL),
            sourceURL: sourceURL
        )
    }

    static func parseJSONPage(_ json: String, sourceURL: URL? = nil) -> PixivActivityPage {
        guard let data = json.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data),
              let stacc = staccDictionary(from: object) else {
            return PixivActivityPage(items: [], nextURL: nil, sourceURL: sourceURL)
        }

        return PixivActivityPage(
            items: deduplicated(staccActivityItems(in: stacc, sourceURL: sourceURL)),
            nextURL: nextStaccPageURL(in: stacc, token: staccToken(from: sourceURL)),
            sourceURL: sourceURL
        )
    }

    private static func parsePreloadStaccPages(in html: String, sourceURL: URL?) -> [PixivActivityPage] {
        let token = staccToken(in: html)
        return preloadStaccJSONStrings(in: html).compactMap { jsonString in
            guard let data = jsonString.data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(with: data),
                  let stacc = staccDictionary(from: object) else {
                return nil
            }
            return PixivActivityPage(
                items: deduplicated(staccActivityItems(in: stacc, sourceURL: sourceURL)),
                nextURL: nextStaccPageURL(in: stacc, token: token),
                sourceURL: sourceURL
            )
        }
    }

    private static func preloadStaccJSONStrings(in html: String) -> [String] {
        groups(
            in: html,
            pattern: #"pixiv\.stacc\.env\.preload\.stacc\s*=\s*(\{[\s\S]*?\});"#,
            decodeAsText: false
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

    private static func staccActivityItems(in stacc: [String: Any], sourceURL: URL?) -> [PixivActivityItem] {
        let users = dictionaryMap(in: stacc, key: "user")
        let illusts = dictionaryMap(in: stacc, key: "illust")
        let novels = dictionaryMap(in: stacc, key: "novel")
        let statuses = dictionaryMap(in: stacc, key: "status")
        let timelines = dictionaryMap(in: stacc, key: "timeline")

        let statusIDs = timelines.compactMap { key, value -> String? in
            if let dictionary = value as? [String: Any] {
                return stringValue(dictionary["id"]) ?? key
            }
            return key
        }
        .sorted { lhs, rhs in
            (Int64(lhs) ?? 0) > (Int64(rhs) ?? 0)
        }

        return statusIDs.compactMap { statusID -> PixivActivityItem? in
            guard let status = statuses[statusID] as? [String: Any] else { return nil }
            return staccActivityItem(
                id: statusID,
                status: status,
                users: users,
                illusts: illusts,
                novels: novels,
                sourceURL: sourceURL
            )
        }
    }

    private static func staccActivityItem(
        id statusID: String,
        status: [String: Any],
        users: [String: Any],
        illusts: [String: Any],
        novels: [String: Any],
        sourceURL: URL?
    ) -> PixivActivityItem? {
        let rawType = firstString(in: status, keys: ["type", "action", "status_type"])
        let kind = staccActivityKind(rawType)
        let actor = staccActor(in: status, users: users, sourceURL: sourceURL)
        let target = staccTarget(in: status, kind: kind, users: users, illusts: illusts, novels: novels, sourceURL: sourceURL)
        guard actor != nil || target != nil else { return nil }

        let artistName = staccArtworkArtistName(status: status, users: users, illusts: illusts, novels: novels)
        let summary = [
            firstString(in: status, keys: ["message", "text", "comment"]),
            artistName
        ]
        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
        .first { $0.isEmpty == false } ?? ""

        return PixivActivityItem(
            id: "stacc-\(statusID)",
            kind: kind,
            actor: actor,
            target: target,
            occurredAt: firstString(in: status, keys: ["post_date", "created_at", "createdAt", "date"]).flatMap(parseDate),
            summary: summary
        )
    }

    private static func staccActivityKind(_ rawType: String?) -> PixivActivityKind {
        let value = rawType?.lowercased() ?? ""
        if value.contains("favorite") || value.contains("mypixiv") || value.contains("follow") {
            return .followedUser
        }
        if value.contains("bookmark") {
            return .bookmarkedArtwork
        }
        if value.contains("illust") || value.contains("novel") {
            return .postedArtwork
        }
        return PixivActivityKind.resolving(rawType)
    }

    private static func staccActor(in status: [String: Any], users: [String: Any], sourceURL: URL?) -> PixivActivityActor? {
        guard let reference = status["post_user"] as? [String: Any],
              let id = stringValue(reference["id"]) else {
            return nil
        }
        let user = users[id] as? [String: Any]
        return PixivActivityActor(
            userID: Int(id),
            name: firstString(in: user ?? [:], keys: ["name", "account", "user_name"]) ?? "",
            avatarURL: imageURL(from: user?["profile_image"], sourceURL: sourceURL)
        )
    }

    private static func staccTarget(
        in status: [String: Any],
        kind: PixivActivityKind,
        users: [String: Any],
        illusts: [String: Any],
        novels: [String: Any],
        sourceURL: URL?
    ) -> PixivActivityTarget? {
        if kind == .followedUser,
           let target = staccReferencedUser(in: status, users: users, sourceURL: sourceURL) {
            return target
        }
        if let target = staccReferencedArtwork(in: status, illusts: illusts, sourceURL: sourceURL) {
            return target
        }
        if let target = staccReferencedNovel(in: status, novels: novels, sourceURL: sourceURL) {
            return target
        }
        return staccReferencedUser(in: status, users: users, sourceURL: sourceURL)
    }

    private static func staccReferencedArtwork(
        in status: [String: Any],
        illusts: [String: Any],
        sourceURL: URL?
    ) -> PixivActivityTarget? {
        guard let reference = status["ref_illust"] as? [String: Any],
              let id = stringValue(reference["id"]) else {
            return nil
        }
        let illust = illusts[id] as? [String: Any]
        return PixivActivityTarget(
            kind: .artwork,
            id: id,
            title: firstString(in: illust ?? [:], keys: ["title", "name"]) ?? "",
            url: fallbackTargetURL(kind: .artwork, id: id),
            thumbnailURL: imageURL(from: illust?["url"], sourceURL: sourceURL)
        )
    }

    private static func staccReferencedNovel(
        in status: [String: Any],
        novels: [String: Any],
        sourceURL: URL?
    ) -> PixivActivityTarget? {
        guard let reference = status["ref_novel"] as? [String: Any],
              let id = stringValue(reference["id"]) else {
            return nil
        }
        let novel = novels[id] as? [String: Any]
        return PixivActivityTarget(
            kind: .novel,
            id: id,
            title: firstString(in: novel ?? [:], keys: ["title", "name"]) ?? "",
            url: fallbackTargetURL(kind: .novel, id: id),
            thumbnailURL: imageURL(from: novel?["url"], sourceURL: sourceURL)
        )
    }

    private static func staccReferencedUser(
        in status: [String: Any],
        users: [String: Any],
        sourceURL: URL?
    ) -> PixivActivityTarget? {
        guard let reference = status["ref_user"] as? [String: Any],
              let id = stringValue(reference["id"]) else {
            return nil
        }
        let user = users[id] as? [String: Any]
        return PixivActivityTarget(
            kind: .user,
            id: id,
            title: firstString(in: user ?? [:], keys: ["name", "account", "user_name"]) ?? "",
            url: fallbackTargetURL(kind: .user, id: id),
            thumbnailURL: imageURL(from: user?["profile_image"], sourceURL: sourceURL)
        )
    }

    private static func staccArtworkArtistName(
        status: [String: Any],
        users: [String: Any],
        illusts: [String: Any],
        novels: [String: Any]
    ) -> String? {
        let illustID = (status["ref_illust"] as? [String: Any]).flatMap { stringValue($0["id"]) }
        let novelID = (status["ref_novel"] as? [String: Any]).flatMap { stringValue($0["id"]) }
        let work = illustID.flatMap { illusts[$0] as? [String: Any] }
            ?? novelID.flatMap { novels[$0] as? [String: Any] }
        guard let postUser = work?["post_user"] as? [String: Any],
              let postUserID = stringValue(postUser["id"]),
              let user = users[postUserID] as? [String: Any] else {
            return nil
        }
        return firstString(in: user, keys: ["name", "account", "user_name"])
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
        let genericBlocks = groups(in: html, pattern: "(\(pattern))", decodeAsText: false)
        let legacyBlocks = legacyStaccStatusBlocks(in: html)
        return (legacyBlocks + genericBlocks)
            .compactMap { htmlActivityItem(from: $0, sourceURL: sourceURL) }
    }

    private static func htmlActivityItem(from block: String, sourceURL: URL?) -> PixivActivityItem? {
        guard block.contains("{{") == false, block.contains("}}") == false else {
            return nil
        }

        let text = strippedText(block)
        guard text.contains("{{") == false, text.contains("}}") == false else {
            return nil
        }

        let classValue = firstAttributeValue(named: "class", in: block) ?? ""
        let kind = PixivActivityKind.resolving("\(classValue) \(text)")
        let userLinks = userAnchors(in: block, sourceURL: sourceURL)
        let artworkLinks = artworkAnchors(in: block, sourceURL: sourceURL)

        let actorLink = userLinks.first(where: { $0.title.isEmpty == false }) ?? userLinks.first
        let actor = actorLink.map { link in
            PixivActivityActor(userID: Int(link.id), name: link.title, avatarURL: nil)
        }
        let target: PixivActivityTarget? = {
            if kind == .followedUser, let link = userLinks.dropFirst().first ?? userLinks.first {
                return PixivActivityTarget(kind: .user, id: link.id, title: link.title, url: link.url, thumbnailURL: nil)
            }
            if let link = artworkLinks.first(where: { $0.title.isEmpty == false }) ?? artworkLinks.first {
                let thumbnailURL = artworkLinks.first(where: { $0.thumbnailURL != nil })?.thumbnailURL
                    ?? link.thumbnailURL
                return PixivActivityTarget(
                    kind: .artwork,
                    id: link.id,
                    title: link.title,
                    url: fallbackTargetURL(kind: .artwork, id: link.id) ?? link.url,
                    thumbnailURL: thumbnailURL
                )
            }
            return nil
        }()

        guard actor != nil || target != nil else { return nil }
        let id = firstAttributeValue(named: "data-activity-id", in: block)
            ?? legacyStaccStatusID(in: block)
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

    private static func nextStaccPageURL(in stacc: [String: Any], token: String?) -> URL? {
        guard intValue(stacc["is_last_page"]) != 1,
              let nextSID = stringValue(stacc["next_max_sid"]),
              nextSID.isEmpty == false,
              nextSID != "0",
              let token,
              token.isEmpty == false else {
            return nil
        }

        let rawPathComponents = stringArray(stacc["path"])
        let pathComponents = rawPathComponents.isEmpty ? ["my", "home", "all", "all"] : rawPathComponents

        var components = URLComponents()
        components.scheme = "https"
        components.host = "www.pixiv.net"
        components.path = "/stacc/" + (pathComponents + [nextSID, ".json"]).joined(separator: "/")

        let param = stacc["param"] as? [String: Any] ?? [:]
        var queryItems = param.keys.sorted().compactMap { key -> URLQueryItem? in
            guard let value = stringValue(param[key]), value.isEmpty == false else { return nil }
            return URLQueryItem(name: key, value: value)
        }
        queryItems.append(URLQueryItem(name: "tt", value: token))
        components.queryItems = queryItems
        return components.url
    }

    private struct Anchor {
        let id: String
        let title: String
        let url: URL?
        let thumbnailURL: URL?
    }

    private static func userAnchors(in html: String, sourceURL: URL?) -> [Anchor] {
        legacyStaccProfileAnchors(in: html, sourceURL: sourceURL)
            + anchors(in: html, path: "users", sourceURL: sourceURL)
            + legacyMemberUserAnchors(in: html, sourceURL: sourceURL)
    }

    private static func artworkAnchors(in html: String, sourceURL: URL?) -> [Anchor] {
        anchors(in: html, path: "artworks", sourceURL: sourceURL)
            + legacyArtworkAnchors(in: html, sourceURL: sourceURL)
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
            return Anchor(
                id: id,
                title: anchorTitle(in: anchorHTML),
                url: href.flatMap { resolvedURL(from: $0, sourceURL: sourceURL) },
                thumbnailURL: firstAttributeValue(named: "src", in: anchorHTML).flatMap { resolvedURL(from: $0, sourceURL: sourceURL) }
            )
        }
    }

    private static func legacyArtworkAnchors(in html: String, sourceURL: URL?) -> [Anchor] {
        let pattern = #"(<a\b[^>]*href=["']([^"']*member_illust\.php\?[^"']*illust_id=([0-9]+)[^"']*)["'][^>]*>[\s\S]*?</a>)"#
        return legacyAnchors(in: html, pattern: pattern, sourceURL: sourceURL) { anchorHTML, href, id in
            Anchor(
                id: id,
                title: anchorTitle(in: anchorHTML),
                url: fallbackTargetURL(kind: .artwork, id: id) ?? resolvedURL(from: href, sourceURL: sourceURL),
                thumbnailURL: firstAttributeValue(named: "src", in: anchorHTML).flatMap { resolvedURL(from: $0, sourceURL: sourceURL) }
            )
        }
    }

    private static func legacyMemberUserAnchors(in html: String, sourceURL: URL?) -> [Anchor] {
        let pattern = #"(<a\b[^>]*href=["']([^"']*member\.php\?[^"']*(?:\?|&amp;|&)id=([0-9]+)[^"']*)["'][^>]*>[\s\S]*?</a>)"#
        return legacyAnchors(in: html, pattern: pattern, sourceURL: sourceURL) { anchorHTML, href, id in
            Anchor(
                id: id,
                title: anchorTitle(in: anchorHTML),
                url: resolvedURL(from: href, sourceURL: sourceURL),
                thumbnailURL: firstAttributeValue(named: "src", in: anchorHTML).flatMap { resolvedURL(from: $0, sourceURL: sourceURL) }
            )
        }
    }

    private static func legacyStaccProfileAnchors(in html: String, sourceURL: URL?) -> [Anchor] {
        let pattern = #"(<a\b[^>]*href=["'](/stacc/(?!s/)([^"'/?#]+))["'][^>]*>[\s\S]*?</a>)"#
        return legacyAnchors(in: html, pattern: pattern, sourceURL: sourceURL) { anchorHTML, href, id in
            Anchor(
                id: id,
                title: anchorTitle(in: anchorHTML),
                url: resolvedURL(from: href, sourceURL: sourceURL),
                thumbnailURL: firstAttributeValue(named: "src", in: anchorHTML).flatMap { resolvedURL(from: $0, sourceURL: sourceURL) }
            )
        }
    }

    private static func legacyAnchors(
        in html: String,
        pattern: String,
        sourceURL: URL?,
        makeAnchor: (String, String, String) -> Anchor
    ) -> [Anchor] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else {
            return []
        }

        let nsRange = NSRange(html.startIndex..<html.endIndex, in: html)
        return regex.matches(in: html, options: [], range: nsRange).compactMap { match in
            guard match.numberOfRanges > 3,
                  let anchorRange = Range(match.range(at: 1), in: html),
                  let hrefRange = Range(match.range(at: 2), in: html),
                  let idRange = Range(match.range(at: 3), in: html)
            else {
                return nil
            }

            let href = decodeHTMLText(String(html[hrefRange]))
            let id = decodeHTMLText(String(html[idRange]))
            return makeAnchor(String(html[anchorRange]), href, id)
        }
    }

    private static func legacyStaccStatusBlocks(in html: String) -> [String] {
        let pattern = #"<div\b[^>]*class=["'][^"']*\bstacc_status\b[^"']*["'][^>]*>"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return []
        }

        let nsRange = NSRange(html.startIndex..<html.endIndex, in: html)
        let matches = regex.matches(in: html, options: [], range: nsRange)
        return matches.enumerated().compactMap { index, match in
            guard let start = Range(match.range, in: html)?.lowerBound else { return nil }
            let end: String.Index
            if index + 1 < matches.count,
               let next = Range(matches[index + 1].range, in: html)?.lowerBound {
                end = next
            } else {
                end = html.endIndex
            }
            return String(html[start..<end])
        }
    }

    private static func legacyStaccStatusID(in html: String) -> String? {
        guard let id = firstAttributeValue(named: "id", in: html),
              id.hasPrefix("stacc_elemid_") else {
            return nil
        }
        return "legacy-\(id.dropFirst("stacc_elemid_".count))"
    }

    private static func anchorTitle(in html: String) -> String {
        [
            firstAttributeValue(named: "title", in: html),
            firstAttributeValue(named: "alt", in: html),
            strippedText(html)
        ]
        .compactMap { value -> String? in
            let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed?.isEmpty == false ? trimmed : nil
        }
        .first ?? ""
    }

    private static func fallbackTargetURL(kind: PixivActivityTargetKind, id: String) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "www.pixiv.net"
        switch kind {
        case .artwork:
            components.path = "/artworks/\(id)"
        case .novel:
            components.path = "/novel/show.php"
            components.queryItems = [URLQueryItem(name: "id", value: id)]
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
        if let date = formatter.date(from: value) {
            return date
        }

        let pixivFormatter = DateFormatter()
        pixivFormatter.locale = Locale(identifier: "en_US_POSIX")
        pixivFormatter.timeZone = TimeZone(identifier: "Asia/Tokyo")
        pixivFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return pixivFormatter.date(from: value)
    }

    private static func staccDictionary(from object: Any) -> [String: Any]? {
        guard let dictionary = object as? [String: Any] else { return nil }
        if let stacc = dictionary["stacc"] as? [String: Any] {
            return stacc
        }
        if dictionary["status"] != nil || dictionary["timeline"] != nil {
            return dictionary
        }
        return nil
    }

    private static func dictionaryMap(in dictionary: [String: Any], key: String) -> [String: Any] {
        dictionary[key] as? [String: Any] ?? [:]
    }

    private static func deduplicated(_ items: [PixivActivityItem]) -> [PixivActivityItem] {
        var seenIDs = Set<String>()
        return items.filter { item in
            guard seenIDs.contains(item.id) == false else { return false }
            seenIDs.insert(item.id)
            return true
        }
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

    private static func stringValue(_ value: Any?) -> String? {
        switch value {
        case let value as String:
            let trimmed = decodeHTMLText(value).trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        case let value as NSNumber:
            return value.stringValue
        case let value as Int:
            return String(value)
        case let value as Int64:
            return String(value)
        case let value as Double where value.rounded() == value:
            return String(Int64(value))
        default:
            return nil
        }
    }

    private static func intValue(_ value: Any?) -> Int? {
        switch value {
        case let value as Int:
            return value
        case let value as NSNumber:
            return value.intValue
        case let value as String:
            return Int(value)
        default:
            return nil
        }
    }

    private static func stringArray(_ value: Any?) -> [String] {
        guard let array = value as? [Any] else { return [] }
        return array.compactMap(stringValue)
    }

    private static func imageURL(from value: Any?, sourceURL: URL?) -> URL? {
        if let string = stringValue(value) {
            return resolvedURL(from: string, sourceURL: sourceURL)
        }

        if let array = value as? [Any] {
            return array.lazy.compactMap { imageURL(from: $0, sourceURL: sourceURL) }.first
        }

        guard let dictionary = value as? [String: Any] else { return nil }
        let priorityKeys = ["m", "s", "ss", "240", "120", "crop_128", "crop_64", "url"]
        for key in priorityKeys {
            if let url = imageURL(from: dictionary[key], sourceURL: sourceURL) {
                return url
            }
        }
        return dictionary.keys
            .sorted()
            .lazy
            .compactMap { imageURL(from: dictionary[$0], sourceURL: sourceURL) }
            .first
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

    private static func staccToken(from sourceURL: URL?) -> String? {
        guard let sourceURL,
              let components = URLComponents(url: sourceURL, resolvingAgainstBaseURL: true) else {
            return nil
        }
        return components.queryItems?.first(where: { $0.name == "tt" })?.value
    }

    private static func staccToken(in html: String) -> String? {
        let patterns = [
            #"id=["']STACC_token["'][^>]*value=["']([^"']+)["']"#,
            #"name=["']STACC_token["'][^>]*value=["']([^"']+)["']"#,
            #"tt:\s*["']([^"']+)["']"#
        ]
        return patterns.lazy.compactMap { firstMatchedGroup(in: html, pattern: $0) }.first
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
