import Foundation

/// Client-side filter DSL for artwork galleries.
///
/// Supports expressions like:
/// - `tag:原神` / `#原神` — match tag name
/// - `title:水着` — match artwork title
/// - `user:username` / `artist:username` / `author:username` — match creator name
/// - `bookmark:>1000` / `bookmark:<500` — bookmark count comparison
/// - `view:>5000` — view count comparison
/// - `page:>3` — page count comparison
/// - `r18` / `!r18` — include/exclude R18
/// - `ai` / `!ai` — include/exclude AI works
/// - `gif` / `!gif` / `+gif` / `-gif` — include/exclude ugoira works
/// - `ratio:landscape` / `ratio:portrait` / `ratio:square` — aspect ratio checks
/// - `bookmarked` / `!bookmarked` — filter by bookmark status
/// - Free text — match title or creator name
enum ClientFilterDSL {
    enum FilterExpression: Equatable {
        case tag(String)
        case title(String)
        case user(String)
        case bookmarkCount(ComparisonOp, Int)
        case viewCount(ComparisonOp, Int)
        case pageCount(ComparisonOp, Int)
        case r18(Bool)
        case r18g(Bool)
        case ai(Bool)
        case ugoira(Bool)
        case ratio(ArtworkRatio)
        case bookmarked(Bool)
        case textMatch(String)
    }

    enum ArtworkRatio: String, Equatable {
        case landscape
        case portrait
        case square
    }

    enum ComparisonOp: String {
        case greaterThan = ">"
        case lessThan = "<"
        case greaterThanOrEqual = ">="
        case lessThanOrEqual = "<="
        case equal = "="
        case notEqual = "!="

        func evaluate(_ lhs: Int, _ rhs: Int) -> Bool {
            switch self {
            case .greaterThan: lhs > rhs
            case .lessThan: lhs < rhs
            case .greaterThanOrEqual: lhs >= rhs
            case .lessThanOrEqual: lhs <= rhs
            case .equal: lhs == rhs
            case .notEqual: lhs != rhs
            }
        }
    }

    /// Parse a filter query string into a list of expressions.
    /// Tokens are separated by whitespace. Quoted strings are supported
    /// for multi-word tag/user names.
    static func parse(_ query: String) -> [FilterExpression] {
        let tokens = tokenize(query)
        return tokens.compactMap(parseToken)
    }

    /// Check if an artwork matches all given filter expressions.
    static func matches(artwork: PixivArtwork, expressions: [FilterExpression]) -> Bool {
        expressions.allSatisfy { evaluate($0, artwork: artwork) }
    }

    /// Filter a list of artworks by the given query.
    static func filter(_ artworks: [PixivArtwork], query: String) -> [PixivArtwork] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard trimmed.isEmpty == false else { return artworks }
        let expressions = parse(trimmed)
        guard expressions.isEmpty == false else { return artworks }
        return artworks.filter { matches(artwork: $0, expressions: expressions) }
    }

    // MARK: - Tokenizer

    private static func tokenize(_ query: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        var inQuotes = false
        var quoteChar: Character = "\""

        for char in query {
            if inQuotes {
                if char == quoteChar {
                    inQuotes = false
                    if current.isEmpty == false {
                        tokens.append(current)
                        current = ""
                    }
                } else {
                    current.append(char)
                }
            } else if char == "\"" || char == "'" {
                inQuotes = true
                quoteChar = char
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

    // MARK: - Parser

    private static func parseToken(_ token: String) -> FilterExpression? {
        let lower = token.lowercased()

        // Negated boolean flags: !r18, !ai, !gif, !bookmarked
        if token.hasPrefix("!") {
            let flag = String(token.dropFirst()).lowercased()
            switch flag {
            case "r18": return .r18(false)
            case "r18g": return .r18g(false)
            case "ai": return .ai(false)
            case "gif", "ugoira": return .ugoira(false)
            case "bookmarked": return .bookmarked(false)
            default: break
            }
        }

        if token.hasPrefix("+") || token.hasPrefix("-") {
            let isIncluded = token.hasPrefix("+")
            let flag = String(token.dropFirst()).lowercased()
            switch flag {
            case "gif", "ugoira": return .ugoira(isIncluded)
            default: break
            }
        }

        // Boolean flags
        switch lower {
        case "r18": return .r18(true)
        case "r18g": return .r18g(true)
        case "ai": return .ai(true)
        case "gif", "ugoira": return .ugoira(true)
        case "bookmarked": return .bookmarked(true)
        default: break
        }

        // Tag shorthand: #tagname
        if token.hasPrefix("#") {
            let name = String(token.dropFirst())
            guard name.isEmpty == false else { return nil }
            return .tag(name)
        }

        // Key:value or key:opvalue
        if let colonIndex = token.firstIndex(of: ":") {
            let key = token[token.startIndex..<colonIndex].lowercased()
            let value = String(token[token.index(after: colonIndex)...])

            switch key {
            case "tag":
                return .tag(value)
            case "title":
                return .title(value)
            case "user", "author", "artist", "a":
                return .user(value)
            case "ratio":
                return ArtworkRatio(rawValue: value.lowercased()).map(FilterExpression.ratio)
            case "bookmark":
                return parseComparison(value, expression: FilterExpression.bookmarkCount)
            case "view":
                return parseComparison(value, expression: FilterExpression.viewCount)
            case "page":
                return parseComparison(value, expression: FilterExpression.pageCount)
            default:
                break
            }
        }

        // Free text — match title or creator name
        guard token.isEmpty == false else { return nil }
        return .textMatch(token)
    }

    private static func parseComparison(
        _ value: String,
        expression: (ComparisonOp, Int) -> FilterExpression
    ) -> FilterExpression? {
        // Try operator prefix: >1000, >=1000, <500, !=0
        let operators: [(String, ComparisonOp)] = [
            (">=", .greaterThanOrEqual),
            ("<=", .lessThanOrEqual),
            ("!=", .notEqual),
            (">", .greaterThan),
            ("<", .lessThan),
            ("=", .equal)
        ]

        for (opStr, op) in operators {
            if value.hasPrefix(opStr) {
                let numStr = String(value.dropFirst(opStr.count))
                if let num = Int(numStr) {
                    return expression(op, num)
                }
            }
        }

        // No operator — treat as equality
        if let num = Int(value) {
            return expression(.equal, num)
        }

        return nil
    }

    // MARK: - Evaluator

    private static func evaluate(_ expression: FilterExpression, artwork: PixivArtwork) -> Bool {
        switch expression {
        case .tag(let name):
            let lower = name.lowercased()
            return artwork.tags.contains { $0.name.lowercased().contains(lower) }

        case .title(let title):
            let lower = title.lowercased()
            return artwork.title.lowercased().contains(lower)

        case .user(let name):
            let lower = name.lowercased()
            return artwork.user.name.lowercased().contains(lower)
                || artwork.user.account.lowercased().contains(lower)

        case .bookmarkCount(let op, let value):
            return op.evaluate(artwork.totalBookmarks, value)

        case .viewCount(let op, let value):
            return op.evaluate(artwork.totalView, value)

        case .pageCount(let op, let value):
            return op.evaluate(artwork.displayPageCount, value)

        case .r18(let wanted):
            let isR18 = artwork.xRestrict > 0
            return isR18 == wanted

        case .r18g(let wanted):
            let isR18G = artwork.xRestrict >= 2
            return isR18G == wanted

        case .ai(let wanted):
            return artwork.isAI == wanted

        case .ugoira(let wanted):
            return artwork.isUgoira == wanted

        case .ratio(let ratio):
            switch ratio {
            case .landscape:
                return artwork.width > artwork.height
            case .portrait:
                return artwork.height > artwork.width
            case .square:
                return artwork.width == artwork.height
            }

        case .bookmarked(let wanted):
            return artwork.isBookmarked == wanted

        case .textMatch(let text):
            let lower = text.lowercased()
            return artwork.title.lowercased().contains(lower)
                || artwork.user.name.lowercased().contains(lower)
                || artwork.user.account.lowercased().contains(lower)
        }
    }
}
