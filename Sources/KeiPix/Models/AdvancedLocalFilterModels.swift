import Foundation

enum AdvancedLocalFilterTextField: Equatable, Sendable {
    case tag
    case title
    case author
}

enum AdvancedLocalFilterNumberField: Equatable, Sendable {
    case bookmarkCount
    case viewCount
    case pageCount
}

enum AdvancedLocalFilterFlag: Equatable, Sendable {
    case r18
    case r18g
    case ai
    case ugoira
    case bookmarked
}

enum AdvancedLocalFilterRatio: String, Equatable, Sendable {
    case landscape
    case portrait
    case square
}

struct AdvancedLocalFilterNumberRange: Equatable, Sendable {
    var minimum: Int?
    var maximum: Int?

    init(minimum: Int? = nil, maximum: Int? = nil) {
        self.minimum = minimum
        self.maximum = maximum
    }

    var isEmpty: Bool {
        minimum == nil && maximum == nil
    }
}

enum AdvancedLocalFilterCriterion: Equatable, Sendable {
    case text(field: AdvancedLocalFilterTextField, value: String)
    case number(AdvancedLocalFilterNumberField, range: AdvancedLocalFilterNumberRange)
    case flag(AdvancedLocalFilterFlag, isIncluded: Bool)
    case ratio(AdvancedLocalFilterRatio)
}

struct AdvancedLocalFilterDraft: Equatable, Sendable {
    var criteria: [AdvancedLocalFilterCriterion]

    init(criteria: [AdvancedLocalFilterCriterion] = []) {
        self.criteria = criteria
    }

    var query: String {
        criteria.flatMap(\.queryTokens).joined(separator: " ")
    }

    var isEmpty: Bool {
        query.isEmpty
    }

    var prefersWideEditor: Bool {
        let activeCriteria = criteria.filter { $0.queryTokens.isEmpty == false }
        guard activeCriteria.count > 1 else {
            return activeCriteria.contains { $0.requiresWideEditor }
        }
        return true
    }
}

enum AdvancedLocalFilterQuickPreset: Hashable, Sendable {
    case bookmarkedOnly
    case excludeAI
    case onlyAI
    case excludeR18
    case excludeR18G
    case onlyUgoira
    case excludeUgoira
    case landscape
    case portrait
    case square

    static let contentFlags: [AdvancedLocalFilterQuickPreset] = [
        .bookmarkedOnly,
        .excludeAI,
        .onlyAI,
        .excludeR18,
        .excludeR18G
    ]

    static let workTypes: [AdvancedLocalFilterQuickPreset] = [
        .onlyUgoira,
        .excludeUgoira
    ]

    static let ratios: [AdvancedLocalFilterQuickPreset] = [
        .landscape,
        .portrait,
        .square
    ]

    func applying(to query: String) -> String {
        var tokens = LocalFilterQueryTokens(query)
        if isActive(in: query) {
            tokens.remove(token)
        } else {
            tokens.remove(contentsOf: tokenGroup)
            tokens.append(token)
        }
        return tokens.query
    }

    func isActive(in query: String) -> Bool {
        LocalFilterQueryTokens(query).contains(token)
    }

    private var token: String {
        switch self {
        case .bookmarkedOnly: "bookmarked"
        case .excludeAI: "!ai"
        case .onlyAI: "ai"
        case .excludeR18: "!r18"
        case .excludeR18G: "!r18g"
        case .onlyUgoira: "gif"
        case .excludeUgoira: "!gif"
        case .landscape: "ratio:landscape"
        case .portrait: "ratio:portrait"
        case .square: "ratio:square"
        }
    }

    private var tokenGroup: Set<String> {
        switch self {
        case .bookmarkedOnly:
            ["bookmarked", "!bookmarked"]
        case .excludeAI, .onlyAI:
            ["ai", "!ai"]
        case .excludeR18:
            ["r18", "!r18"]
        case .excludeR18G:
            ["r18g", "!r18g"]
        case .onlyUgoira, .excludeUgoira:
            ["gif", "+gif", "!gif", "-gif", "ugoira", "+ugoira", "!ugoira", "-ugoira"]
        case .landscape, .portrait, .square:
            ["ratio:landscape", "ratio:portrait", "ratio:square"]
        }
    }
}

private struct LocalFilterQueryTokens {
    private var tokens: [String]

    init(_ query: String) {
        tokens = Self.tokenize(query)
    }

    var query: String {
        tokens.joined(separator: " ")
    }

    mutating func append(_ token: String) {
        tokens.append(token)
    }

    mutating func remove(_ token: String) {
        remove(contentsOf: [token])
    }

    mutating func remove(contentsOf tokenGroup: Set<String>) {
        tokens.removeAll { tokenGroup.contains($0.normalizedLocalFilterToken) }
    }

    func contains(_ token: String) -> Bool {
        tokens.contains { $0.normalizedLocalFilterToken == token.lowercased() }
    }

    private static func tokenize(_ query: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        var inQuotes = false
        var quoteChar: Character = "\""

        for char in query {
            if inQuotes {
                current.append(char)
                if char == quoteChar {
                    inQuotes = false
                }
            } else if char == "\"" || char == "'" {
                inQuotes = true
                quoteChar = char
                current.append(char)
            } else if char.isWhitespace {
                if current.isEmpty == false {
                    tokens.append(current)
                    current = ""
                }
            } else {
                current.append(char)
            }
        }

        if current.isEmpty == false {
            tokens.append(current)
        }

        return tokens
    }
}

private extension AdvancedLocalFilterCriterion {
    var queryTokens: [String] {
        switch self {
        case .text(let field, let value):
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.isEmpty == false else { return [] }
            return ["\(field.queryKey):\(trimmed.quotedIfNeededForLocalFilter)"]

        case .number(let field, let range):
            guard range.isEmpty == false else { return [] }
            var tokens: [String] = []
            if let minimum = range.minimum {
                tokens.append("\(field.queryKey):>=\(minimum)")
            }
            if let maximum = range.maximum {
                tokens.append("\(field.queryKey):<=\(maximum)")
            }
            return tokens

        case .flag(let flag, let isIncluded):
            return [flag.queryToken(isIncluded: isIncluded)]

        case .ratio(let ratio):
            return ["ratio:\(ratio.rawValue)"]
        }
    }

    var requiresWideEditor: Bool {
        switch self {
        case .text, .number, .ratio:
            true
        case .flag(let flag, _):
            flag != .bookmarked
        }
    }
}

private extension AdvancedLocalFilterTextField {
    var queryKey: String {
        switch self {
        case .tag: "tag"
        case .title: "title"
        case .author: "user"
        }
    }
}

private extension AdvancedLocalFilterNumberField {
    var queryKey: String {
        switch self {
        case .bookmarkCount: "bookmark"
        case .viewCount: "view"
        case .pageCount: "page"
        }
    }
}

private extension AdvancedLocalFilterFlag {
    func queryToken(isIncluded: Bool) -> String {
        switch self {
        case .r18:
            isIncluded ? "r18" : "!r18"
        case .r18g:
            isIncluded ? "r18g" : "!r18g"
        case .ai:
            isIncluded ? "ai" : "!ai"
        case .ugoira:
            isIncluded ? "gif" : "!gif"
        case .bookmarked:
            isIncluded ? "bookmarked" : "!bookmarked"
        }
    }
}

private extension String {
    var normalizedLocalFilterToken: String {
        trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    var quotedIfNeededForLocalFilter: String {
        if contains(where: \.isWhitespace) {
            "\"\(replacingOccurrences(of: "\"", with: "\\\""))\""
        } else {
            self
        }
    }
}
