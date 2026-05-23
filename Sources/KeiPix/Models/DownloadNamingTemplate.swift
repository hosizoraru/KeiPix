import Foundation

struct DownloadNamingTemplate: Sendable {
    static let defaultTemplate = "${id} - ${title}/${id}_p${page}.${ext}"

    var rawValue: String

    var effectiveTemplate: String {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? Self.defaultTemplate : trimmed
    }

    func render(context: Context) -> RenderedPath {
        var components = sanitizedComponents(from: effectiveTemplate, context: context)
        if components.isEmpty {
            components = defaultComponents(context: context)
        }
        if components.count == 1 {
            components.insert(defaultFolderName(context: context), at: 0)
        }
        if let last = components.last, last.pathExtension.isEmpty {
            components[components.count - 1] = "\(last).\(context.extensionName)"
        }
        return RenderedPath(components: components)
    }

    func previewPath() -> String {
        render(context: .preview).relativePath
    }

    private func replacedPlaceholders(in template: String, context: Context) -> String {
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
            output += placeholderValue(for: key, context: context)
            cursor = template.index(after: closeIndex)
        }

        output += template[cursor...]
        return output
    }

    private func placeholderValue(for key: String, context: Context) -> String {
        switch key {
        case "id":
            return String(context.artworkID)
        case "title":
            return context.title
        case "user":
            return context.creatorName
        case "userId":
            return context.creatorID.map(String.init) ?? ""
        case "page":
            return String(context.pageIndex)
        case "page1":
            return String(context.pageIndex + 1)
        case "pages":
            return String(context.totalPages)
        case "ext":
            return context.extensionName
        case "AI":
            return context.isAI ? "AI" : ""
        case "R18":
            return context.isR18 ? "R18" : ""
        case "R18G":
            return context.isR18G ? "R18G" : ""
        case "tag1":
            return context.tags.first ?? ""
        case "tag2":
            return context.tags.dropFirst().first ?? ""
        default:
            if key.hasPrefix("tag("), key.hasSuffix(")") {
                let start = key.index(key.startIndex, offsetBy: 4)
                let end = key.index(before: key.endIndex)
                let tagName = String(key[start..<end])
                return context.tags.first { $0.localizedCaseInsensitiveCompare(tagName) == .orderedSame } ?? ""
            }
            return ""
        }
    }

    private func sanitizedComponents(from path: String, context: Context) -> [String] {
        path.components(separatedBy: CharacterSet(charactersIn: "/\\"))
            .compactMap { component in
                Self.sanitizedComponent(replacedPlaceholders(in: component, context: context))
            }
    }

    private func defaultComponents(context: Context) -> [String] {
        [
            defaultFolderName(context: context),
            "\(context.artworkID)_p\(context.pageIndex).\(context.extensionName)"
        ]
    }

    private func defaultFolderName(context: Context) -> String {
        Self.sanitizedComponent("\(context.artworkID) - \(context.title)") ?? "\(context.artworkID)"
    }

    private static func sanitizedComponent(_ component: String) -> String? {
        let invalid = CharacterSet(charactersIn: "/\\:*?\"<>|")
            .union(.newlines)
            .union(.controlCharacters)
        let cleaned = component
            .components(separatedBy: invalid)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleaned.isEmpty == false, cleaned != ".", cleaned != ".." else {
            return nil
        }
        return String(cleaned.prefix(96))
    }

    struct RenderedPath: Sendable {
        let components: [String]

        var relativePath: String {
            components.joined(separator: "/")
        }

        var parentComponents: [String] {
            Array(components.dropLast())
        }
    }

    struct Context: Sendable {
        let artworkID: Int
        let title: String
        let creatorName: String
        let creatorID: Int?
        let tags: [String]
        let isAI: Bool
        let isR18: Bool
        let isR18G: Bool
        let pageIndex: Int
        let totalPages: Int
        let extensionName: String

        init(item: ArtworkDownloadItem, pageIndex: Int, totalPages: Int, sourceURL: URL) {
            artworkID = item.artworkID
            title = item.title
            creatorName = item.creatorName
            creatorID = item.creatorID
            tags = item.tags ?? []
            isAI = item.isAI ?? false
            isR18 = item.isR18 ?? false
            isR18G = item.isR18G ?? false
            self.pageIndex = pageIndex
            self.totalPages = totalPages
            extensionName = Self.normalizedExtension(from: sourceURL)
        }

        init(artwork: PixivArtwork, pageIndex: Int, totalPages: Int, sourceURL: URL) {
            artworkID = artwork.id
            title = artwork.title
            creatorName = artwork.user.name
            creatorID = artwork.user.id
            tags = artwork.tags.map(\.name)
            isAI = artwork.isAI
            isR18 = artwork.isR18
            isR18G = artwork.isR18G
            self.pageIndex = pageIndex
            self.totalPages = totalPages
            extensionName = Self.normalizedExtension(from: sourceURL)
        }

        static let preview = Context(
            artworkID: 12345678,
            title: "Blue Morning",
            creatorName: "kei",
            creatorID: 424242,
            tags: ["landscape", "original"],
            isAI: false,
            isR18: false,
            isR18G: false,
            pageIndex: 0,
            totalPages: 3,
            extensionName: "jpg"
        )

        private init(
            artworkID: Int,
            title: String,
            creatorName: String,
            creatorID: Int?,
            tags: [String],
            isAI: Bool,
            isR18: Bool,
            isR18G: Bool,
            pageIndex: Int,
            totalPages: Int,
            extensionName: String
        ) {
            self.artworkID = artworkID
            self.title = title
            self.creatorName = creatorName
            self.creatorID = creatorID
            self.tags = tags
            self.isAI = isAI
            self.isR18 = isR18
            self.isR18G = isR18G
            self.pageIndex = pageIndex
            self.totalPages = totalPages
            self.extensionName = extensionName
        }

        private static func normalizedExtension(from url: URL) -> String {
            let ext = url.pathExtension.lowercased()
            return ext.isDownloadExtension ? ext : "jpg"
        }
    }
}

private extension String {
    var isDownloadExtension: Bool {
        ["jpg", "jpeg", "png", "gif", "webp", "avif", "zip"].contains(lowercased())
    }

    var pathExtension: String {
        (self as NSString).pathExtension
    }
}
