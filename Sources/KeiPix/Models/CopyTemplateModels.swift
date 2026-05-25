import Foundation

struct ArtworkCopyTemplate: Sendable {
    static let defaultTemplate = """
    ${title}
    ${creator} (@${account})
    #${id} · @${userId}
    ${pages}P · ${views} · ${bookmarks}
    ${badges}
    ${tags}
    ${url}
    """

    var rawValue: String

    var effectiveTemplate: String {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? Self.defaultTemplate : rawValue
    }

    func render(context: Context) -> String {
        renderedPlaceholders(in: effectiveTemplate, values: context.values)
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
            .joined(separator: "\n")
    }

    struct Context: Sendable {
        let artworkID: Int
        let title: String
        let creatorName: String
        let creatorAccount: String
        let creatorID: Int
        let pageCount: Int
        let views: Int
        let bookmarks: Int
        let comments: Int
        let tags: [String]
        let badges: [String]
        let url: String

        var values: [String: String] {
            [
                "id": "\(artworkID)",
                "title": title,
                "creator": creatorName,
                "user": creatorName,
                "account": creatorAccount,
                "userId": "\(creatorID)",
                "pages": "\(pageCount)",
                "views": views.formatted(),
                "bookmarks": bookmarks.formatted(),
                "saves": bookmarks.formatted(),
                "comments": comments.formatted(),
                "tags": tags.map { "#\($0)" }.joined(separator: " "),
                "badges": badges.joined(separator: ", "),
                "url": url,
                "AI": badges.contains(ArtworkContentBadge.aiGenerated.title) ? "AI" : "",
                "R18": badges.contains(ArtworkContentBadge.r18.title) ? "R-18" : "",
                "R18G": badges.contains(ArtworkContentBadge.r18g.title) ? "R-18G" : ""
            ]
        }

        static var preview: Context {
            Context(
                artworkID: 12345678,
                title: "Blue Morning",
                creatorName: "Kei",
                creatorAccount: "kei_pixiv",
                creatorID: 24680,
                pageCount: 3,
                views: 12000,
                bookmarks: 3400,
                comments: 56,
                tags: ["original", "landscape"],
                badges: [ArtworkContentBadge.aiGenerated.title, ArtworkContentBadge.r18.title],
                url: "https://www.pixiv.net/artworks/12345678"
            )
        }
    }
}

struct CreatorCopyTemplate: Sendable {
    static let defaultTemplate = "${user}\t@${account}\t${userId}\t${url}"

    var rawValue: String

    var effectiveTemplate: String {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? Self.defaultTemplate : rawValue
    }

    func render(context: Context) -> String {
        renderedPlaceholders(in: effectiveTemplate, values: context.values)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    struct Context: Sendable {
        let name: String
        let account: String
        let userID: Int
        let url: String

        var values: [String: String] {
            [
                "user": name,
                "creator": name,
                "account": account,
                "userId": "\(userID)",
                "url": url
            ]
        }

        static var preview: Context {
            Context(
                name: "Kei",
                account: "kei_pixiv",
                userID: 24680,
                url: "https://www.pixiv.net/users/24680"
            )
        }
    }
}

private func renderedPlaceholders(in template: String, values: [String: String]) -> String {
    var output = ""
    var cursor = template.startIndex
    while let openRange = template[cursor...].range(of: "${") {
        output += template[cursor..<openRange.lowerBound]
        let valueStart = openRange.upperBound
        guard let closeIndex = template[valueStart...].firstIndex(of: "}") else {
            output += template[openRange.lowerBound...]
            return output
        }
        let key = String(template[valueStart..<closeIndex])
        output += values[key] ?? ""
        cursor = template.index(after: closeIndex)
    }
    output += template[cursor...]
    return output
}
