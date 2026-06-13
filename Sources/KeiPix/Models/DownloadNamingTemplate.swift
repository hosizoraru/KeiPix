import Foundation

struct DownloadNamingTemplate: Sendable {
    static let defaultTemplate = "${id} - ${title}/${id}_p${page}.${ext}"

    static let documentedTokens: [Token] = [
        Token(key: "id", displayName: "ID", sampleValue: "100000000", group: .identity),
        Token(key: "title", displayName: "Title", sampleValue: "Sample Artwork", group: .identity),
        Token(key: "user", displayName: "Creator", sampleValue: "Sample Artist", group: .creator),
        Token(key: "userId", displayName: "Creator ID", sampleValue: "12345", group: .creator),
        Token(key: "series", displayName: "Series", sampleValue: "Morning Series", group: .series),
        Token(key: "seriesId", displayName: "Series ID", sampleValue: "9001", group: .series),
        Token(key: "page", displayName: "Page Index", sampleValue: "0", group: .page),
        Token(key: "page1", displayName: "Page Number", sampleValue: "1", group: .page),
        Token(key: "pages", displayName: "Total Pages", sampleValue: "8", group: .page),
        Token(key: "ext", displayName: "Extension", sampleValue: "jpg", group: .page),
        Token(key: "AI", displayName: "AI Flag", sampleValue: "AI", group: .flags),
        Token(key: "R18", displayName: "R-18 Flag", sampleValue: "R18", group: .flags),
        Token(key: "R18G", displayName: "R-18G Flag", sampleValue: "R18G", group: .flags),
        Token(key: "tag1", displayName: "First Tag", sampleValue: "original", group: .tags),
        Token(key: "tag2", displayName: "Second Tag", sampleValue: "landscape", group: .tags),
        Token(key: "tag(name)", displayName: "Named Tag", sampleValue: "landscape", group: .tags)
    ]

    static let documentedPresets: [Preset] = [
        Preset(id: .default, template: defaultTemplate),
        Preset(id: .creator, template: "${user}/${id} - ${title}/${id}_p${page}.${ext}"),
        Preset(id: .series, template: "${user}/${series}/${id}_p${page1}.${ext}"),
        Preset(id: .tagged, template: "${R18}${R18G}${AI}/${tag1}/${id}_p${page1}.${ext}")
    ]

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

    /// Renders the template against each documented preview scenario,
    /// returning the resulting relative paths so the Downloads settings
    /// page can show a side-by-side comparison without having to
    /// reconstruct the contexts itself.
    func previewScenarios() -> [PreviewScenario] {
        PreviewScenario.allCases.map { scenario in
            var copy = scenario
            copy.renderedPath = render(context: scenario.context).relativePath
            return copy
        }
    }

    struct PreviewScenario: Identifiable, Sendable {
        let id: PreviewScenarioKind
        let context: Context
        var renderedPath: String

        static let allCases: [PreviewScenario] = [
            PreviewScenario(id: .standalone, context: .previewStandalone, renderedPath: ""),
            PreviewScenario(id: .multiPage, context: .previewMultiPage, renderedPath: ""),
            PreviewScenario(id: .series, context: .previewSeries, renderedPath: "")
        ]
    }

    enum PreviewScenarioKind: String, CaseIterable, Sendable {
        case standalone
        case multiPage
        case series
    }

    /// Set of placeholder names the template references that aren't part
    /// of the documented token vocabulary. Surfaced inline by the
    /// Downloads settings page so a typo like `${ide}` doesn't silently
    /// collapse to an empty string at download time.
    var unknownPlaceholders: [String] {
        var seen: [String] = []
        var cursor = effectiveTemplate.startIndex
        let template = effectiveTemplate
        while let openRange = template[cursor...].range(of: "${") {
            let valueStart = openRange.upperBound
            guard let closeIndex = template[valueStart...].firstIndex(of: "}") else { break }
            let key = String(template[valueStart..<closeIndex])
            if Self.isKnownPlaceholder(key), seen.contains(key) == false {
                cursor = template.index(after: closeIndex)
                continue
            }
            if Self.isKnownPlaceholder(key) == false, seen.contains(key) == false {
                seen.append(key)
            }
            cursor = template.index(after: closeIndex)
        }
        return seen
    }

    private static let knownPlaceholders = Set(documentedTokens.map(\.key))

    private static func isKnownPlaceholder(_ key: String) -> Bool {
        if knownPlaceholders.contains(key) { return true }
        if key.hasPrefix("tag("), key.hasSuffix(")") { return true }
        return false
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
        case "series":
            return context.seriesTitle ?? ""
        case "seriesId":
            return context.seriesID.map(String.init) ?? ""
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

    struct Token: Identifiable, Hashable, Sendable {
        let key: String
        let displayName: String
        let sampleValue: String
        let group: TokenGroup

        var id: String { key }

        var placeholder: String {
            "${\(key)}"
        }
    }

    enum TokenGroup: String, CaseIterable, Identifiable, Sendable {
        case identity
        case creator
        case series
        case page
        case flags
        case tags

        var id: String { rawValue }
    }

    struct Preset: Identifiable, Hashable, Sendable {
        let id: PresetID
        let template: String
    }

    enum PresetID: String, CaseIterable, Identifiable, Sendable {
        case `default`
        case creator
        case series
        case tagged

        var id: String { rawValue }
    }

    struct Context: Sendable {
        let artworkID: Int
        let title: String
        let creatorName: String
        let creatorID: Int?
        let seriesTitle: String?
        let seriesID: Int?
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
            seriesTitle = item.seriesTitle
            seriesID = item.seriesID
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
            seriesTitle = artwork.series?.title
            seriesID = artwork.series?.id
            tags = artwork.tags.map(\.name)
            isAI = artwork.isAI
            isR18 = artwork.isR18
            isR18G = artwork.isR18G
            self.pageIndex = pageIndex
            self.totalPages = totalPages
            extensionName = Self.normalizedExtension(from: sourceURL)
        }

        fileprivate init(
            artworkID: Int,
            title: String,
            creatorName: String,
            creatorID: Int?,
            seriesTitle: String?,
            seriesID: Int?,
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
            self.seriesTitle = seriesTitle
            self.seriesID = seriesID
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

// Documented sample contexts used by the Downloads settings page to
// preview a template against three real-world shapes: a standalone
// single-page illustration, a multi-page set, and a serialized manga
// chapter. Pulled out into an extension so the Context struct body
// stays under the swiftlint type_body_length budget.
extension DownloadNamingTemplate.Context {
    /// Default preview context used by `previewPath()`. Models a
    /// serialized work so the canonical preview surfaces ${series}
    /// folders — keeps the existing snapshot test honest about how the
    /// folder hierarchy looks for the most common Pixez-parity setup.
    static let preview = Self(
        artworkID: 100000000,
        title: "Sample Artwork",
        creatorName: "Sample Artist",
        creatorID: 12345,
        seriesTitle: "Morning Series",
        seriesID: 9001,
        tags: ["original", "landscape"],
        isAI: false,
        isR18: false,
        isR18G: false,
        pageIndex: 0,
        totalPages: 1,
        extensionName: "png"
    )

    /// Standalone single-page illustration. No series, single page,
    /// PNG extension. Anchors the "common case" preview row.
    static let previewStandalone = Self(
        artworkID: 100000001,
        title: "Standalone Illustration",
        creatorName: "Sample Artist",
        creatorID: 12345,
        seriesTitle: nil,
        seriesID: nil,
        tags: ["illustration"],
        isAI: false,
        isR18: false,
        isR18G: false,
        pageIndex: 0,
        totalPages: 1,
        extensionName: "png"
    )

    /// Multi-page set, second page of three. Surfaces how `${page}`
    /// and `${pages}` collaborate when more than one image lands.
    static let previewMultiPage = Self(
        artworkID: 100000002,
        title: "Multi Page Set",
        creatorName: "Sample Artist",
        creatorID: 12345,
        seriesTitle: nil,
        seriesID: nil,
        tags: ["original"],
        isAI: false,
        isR18: false,
        isR18G: false,
        pageIndex: 1,
        totalPages: 3,
        extensionName: "jpg"
    )

    /// Serialized manga chapter, page 2 of 8 inside chapter 4. Lets
    /// users see what `${series}` / `${seriesId}` resolve to before
    /// they queue a real download.
    static let previewSeries = Self(
        artworkID: 100000003,
        title: "Chapter 4",
        creatorName: "Sample Mangaka",
        creatorID: 67890,
        seriesTitle: "Sample Series",
        seriesID: 999,
        tags: ["manga"],
        isAI: false,
        isR18: false,
        isR18G: false,
        pageIndex: 1,
        totalPages: 8,
        extensionName: "jpg"
    )
}

private extension String {
    var isDownloadExtension: Bool {
        ["jpg", "jpeg", "png", "gif", "webp", "avif", "zip"].contains(lowercased())
    }

    var pathExtension: String {
        (self as NSString).pathExtension
    }
}
