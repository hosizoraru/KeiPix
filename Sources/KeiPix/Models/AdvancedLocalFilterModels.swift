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

enum AdvancedLocalFilterRatio: String, CaseIterable, Equatable, Sendable {
    case landscape
    case portrait
    case square
}

enum AdvancedLocalFilterFlagRule: String, CaseIterable, Equatable, Sendable {
    case any
    case include
    case exclude
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

struct AdvancedLocalFilterEditorDraft: Equatable, Sendable {
    var tagText: String = ""
    var titleText: String = ""
    var authorText: String = ""
    var bookmarkRange = AdvancedLocalFilterNumberRange()
    var viewRange = AdvancedLocalFilterNumberRange()
    var pageRange = AdvancedLocalFilterNumberRange()
    var r18Rule: AdvancedLocalFilterFlagRule = .any
    var r18gRule: AdvancedLocalFilterFlagRule = .any
    var aiRule: AdvancedLocalFilterFlagRule = .any
    var ugoiraRule: AdvancedLocalFilterFlagRule = .any
    var bookmarkedRule: AdvancedLocalFilterFlagRule = .any
    var ratio: AdvancedLocalFilterRatio?
    var passthroughQuery: String = ""

    init(
        tagText: String = "",
        titleText: String = "",
        authorText: String = "",
        bookmarkRange: AdvancedLocalFilterNumberRange = AdvancedLocalFilterNumberRange(),
        viewRange: AdvancedLocalFilterNumberRange = AdvancedLocalFilterNumberRange(),
        pageRange: AdvancedLocalFilterNumberRange = AdvancedLocalFilterNumberRange(),
        r18Rule: AdvancedLocalFilterFlagRule = .any,
        r18gRule: AdvancedLocalFilterFlagRule = .any,
        aiRule: AdvancedLocalFilterFlagRule = .any,
        ugoiraRule: AdvancedLocalFilterFlagRule = .any,
        bookmarkedRule: AdvancedLocalFilterFlagRule = .any,
        ratio: AdvancedLocalFilterRatio? = nil,
        passthroughQuery: String = ""
    ) {
        self.tagText = tagText
        self.titleText = titleText
        self.authorText = authorText
        self.bookmarkRange = bookmarkRange
        self.viewRange = viewRange
        self.pageRange = pageRange
        self.r18Rule = r18Rule
        self.r18gRule = r18gRule
        self.aiRule = aiRule
        self.ugoiraRule = ugoiraRule
        self.bookmarkedRule = bookmarkedRule
        self.ratio = ratio
        self.passthroughQuery = passthroughQuery
    }

    init(query: String) {
        self.init()
        var passthroughTokens: [String] = []

        for token in LocalFilterQueryTokens.tokenize(query) {
            if applyStructuredToken(token) == false {
                passthroughTokens.append(token)
            }
        }

        passthroughQuery = passthroughTokens.joined(separator: " ")
    }

    var query: String {
        queryTokens.joined(separator: " ")
    }

    var isEmpty: Bool {
        query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    mutating func clear() {
        self = AdvancedLocalFilterEditorDraft()
    }

    private var queryTokens: [String] {
        var tokens: [String] = []
        appendTextToken(field: .tag, value: tagText, to: &tokens)
        appendTextToken(field: .title, value: titleText, to: &tokens)
        appendTextToken(field: .author, value: authorText, to: &tokens)
        appendNumberTokens(field: .bookmarkCount, range: bookmarkRange, to: &tokens)
        appendNumberTokens(field: .viewCount, range: viewRange, to: &tokens)
        appendNumberTokens(field: .pageCount, range: pageRange, to: &tokens)
        appendFlagToken(flag: .r18, rule: r18Rule, to: &tokens)
        appendFlagToken(flag: .r18g, rule: r18gRule, to: &tokens)
        appendFlagToken(flag: .ai, rule: aiRule, to: &tokens)
        appendFlagToken(flag: .ugoira, rule: ugoiraRule, to: &tokens)
        appendFlagToken(flag: .bookmarked, rule: bookmarkedRule, to: &tokens)
        if let ratio {
            tokens.append("ratio:\(ratio.rawValue)")
        }
        let passthrough = passthroughQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        if passthrough.isEmpty == false {
            tokens.append(passthrough)
        }
        return tokens
    }

    private func appendTextToken(
        field: AdvancedLocalFilterTextField,
        value: String,
        to tokens: inout [String]
    ) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return }
        tokens.append("\(field.queryKey):\(trimmed.quotedIfNeededForLocalFilter)")
    }

    private func appendNumberTokens(
        field: AdvancedLocalFilterNumberField,
        range: AdvancedLocalFilterNumberRange,
        to tokens: inout [String]
    ) {
        if let minimum = range.minimum {
            tokens.append("\(field.queryKey):>=\(minimum)")
        }
        if let maximum = range.maximum {
            tokens.append("\(field.queryKey):<=\(maximum)")
        }
    }

    private func appendFlagToken(
        flag: AdvancedLocalFilterFlag,
        rule: AdvancedLocalFilterFlagRule,
        to tokens: inout [String]
    ) {
        switch rule {
        case .any:
            return
        case .include:
            tokens.append(flag.queryToken(isIncluded: true))
        case .exclude:
            tokens.append(flag.queryToken(isIncluded: false))
        }
    }

    private mutating func applyStructuredToken(_ token: String) -> Bool {
        let normalized = token.normalizedLocalFilterToken
        switch normalized {
        case "r18":
            r18Rule = .include
            return true
        case "!r18":
            r18Rule = .exclude
            return true
        case "r18g":
            r18gRule = .include
            return true
        case "!r18g":
            r18gRule = .exclude
            return true
        case "ai":
            aiRule = .include
            return true
        case "!ai":
            aiRule = .exclude
            return true
        case "gif", "+gif", "ugoira", "+ugoira":
            ugoiraRule = .include
            return true
        case "!gif", "-gif", "!ugoira", "-ugoira":
            ugoiraRule = .exclude
            return true
        case "bookmarked":
            bookmarkedRule = .include
            return true
        case "!bookmarked":
            bookmarkedRule = .exclude
            return true
        default:
            break
        }

        if token.hasPrefix("#") {
            let value = String(token.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
            guard value.isEmpty == false else { return false }
            tagText = value.unquotedForLocalFilter
            return true
        }

        guard let colonIndex = token.firstIndex(of: ":") else {
            return false
        }

        let key = token[token.startIndex..<colonIndex].lowercased()
        let value = String(token[token.index(after: colonIndex)...])
        switch key {
        case "tag":
            tagText = value.unquotedForLocalFilter
            return true
        case "title":
            titleText = value.unquotedForLocalFilter
            return true
        case "user", "author", "artist", "a":
            authorText = value.unquotedForLocalFilter
            return true
        case "bookmark":
            return applyNumberValue(value, to: .bookmarkCount)
        case "view":
            return applyNumberValue(value, to: .viewCount)
        case "page":
            return applyNumberValue(value, to: .pageCount)
        case "ratio":
            ratio = AdvancedLocalFilterRatio(rawValue: value.lowercased())
            return ratio != nil
        default:
            return false
        }
    }

    private mutating func applyNumberValue(
        _ value: String,
        to field: AdvancedLocalFilterNumberField
    ) -> Bool {
        if value.hasPrefix(">="), let number = Int(value.dropFirst(2)) {
            updateNumberRange(field) { $0.minimum = number }
            return true
        }
        if value.hasPrefix("<="), let number = Int(value.dropFirst(2)) {
            updateNumberRange(field) { $0.maximum = number }
            return true
        }
        if let number = Int(value) {
            updateNumberRange(field) {
                $0.minimum = number
                $0.maximum = number
            }
            return true
        }
        return false
    }

    private mutating func updateNumberRange(
        _ field: AdvancedLocalFilterNumberField,
        _ update: (inout AdvancedLocalFilterNumberRange) -> Void
    ) {
        switch field {
        case .bookmarkCount:
            update(&bookmarkRange)
        case .viewCount:
            update(&viewRange)
        case .pageCount:
            update(&pageRange)
        }
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

    static func tokenize(_ query: String) -> [String] {
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

    var unquotedForLocalFilter: String {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2,
              let first = trimmed.first,
              let last = trimmed.last,
              (first == "\"" || first == "'"),
              first == last else {
            return trimmed
        }
        let start = trimmed.index(after: trimmed.startIndex)
        let end = trimmed.index(before: trimmed.endIndex)
        return String(trimmed[start..<end]).replacingOccurrences(of: "\\\(first)", with: String(first))
    }
}
