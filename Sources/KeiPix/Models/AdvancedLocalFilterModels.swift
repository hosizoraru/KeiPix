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
    var quotedIfNeededForLocalFilter: String {
        if contains(where: \.isWhitespace) {
            "\"\(replacingOccurrences(of: "\"", with: "\\\""))\""
        } else {
            self
        }
    }
}
