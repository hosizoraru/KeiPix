import Foundation

/// A single lexed element from a pixiv novel body.
///
/// pixiv text uses an inline-tag dialect (see `NovelTextTokenizer.tokenize`)
/// for page breaks, chapter headers, embedded images, jump links, and ruby
/// annotations. Each occurrence becomes one `NovelToken`; plain runs of text
/// become `.text(...)`. The reader walks the token stream once and renders
/// each kind in its own SwiftUI view, which keeps the rendering layer free
/// of regex.
enum NovelToken: Equatable, Sendable {
    case text(String)
    case newPage
    case chapter(String)
    /// `[pixivimage:<illustID>]` or `[pixivimage:<illustID>-<page>]`.
    /// `page` is 1-based; `nil` when the tag has no page suffix.
    case pixivImage(illustID: Int, page: Int?)
    /// `[uploadedimage:<key>]` — references an author-uploaded image whose
    /// CDN URL only ships in the webview JSON. The reader displays a
    /// placeholder until that JSON is wired through.
    case uploadedImage(key: String)
    /// `[[jumpuri:label > url]]` — pixiv inline link with a label.
    case jumpURL(label: String, url: URL)
    /// `[[rb:base > reading]]` — ruby annotation. Rendered as `base(reading)`
    /// inline because SwiftUI's `Text` doesn't have a true `<ruby>` style on
    /// macOS without per-glyph attachment.
    case ruby(base: String, reading: String)
    /// `[jump:N]` — internal page jump. We surface the destination but the
    /// reader currently treats it as a plain marker (no action).
    case jumpPage(Int)
}

enum NovelTextTokenizer {
    /// Lex a pixiv novel body into a stream of `NovelToken`. The output
    /// preserves order, so a renderer can iterate it exactly once.
    ///
    /// Unknown bracketed sequences (e.g., a stray `[notatag:...]`) and
    /// malformed close brackets fall through to `.text(...)` verbatim — this
    /// matches pixez/pixes behaviour and avoids dropping author content if
    /// pixiv ever introduces a new tag.
    static func tokenize(_ source: String) -> [NovelToken] {
        var tokens: [NovelToken] = []
        var buffer = ""
        var index = source.startIndex

        while index < source.endIndex {
            let ch = source[index]

            // Newlines stay in the text run — paragraph breaks are decided
            // by the renderer, not the tokenizer.
            if ch != "[" {
                buffer.append(ch)
                index = source.index(after: index)
                continue
            }

            // Try the double-bracket forms first because `[[rb:...]]` and
            // `[[jumpuri:...]]` look like a `[` followed by another `[` to
            // a single-bracket scanner.
            if let (token, end) = matchDoubleBracketTag(in: source, at: index) {
                if buffer.isEmpty == false {
                    tokens.append(.text(buffer))
                    buffer.removeAll(keepingCapacity: true)
                }
                tokens.append(token)
                index = end
                continue
            }

            if let (token, end) = matchSingleBracketTag(in: source, at: index) {
                if buffer.isEmpty == false {
                    tokens.append(.text(buffer))
                    buffer.removeAll(keepingCapacity: true)
                }
                tokens.append(token)
                index = end
                continue
            }

            // Unmatched `[` — keep it as literal text.
            buffer.append(ch)
            index = source.index(after: index)
        }

        if buffer.isEmpty == false {
            tokens.append(.text(buffer))
        }
        return tokens
    }

    // MARK: - Single-bracket tags

    /// Matches `[newpage]`, `[chapter:...]`, `[pixivimage:...]`,
    /// `[uploadedimage:...]`, `[jump:N]`. Returns the token and the index of
    /// the character after the closing `]`. Returns nil when no tag matches.
    private static func matchSingleBracketTag(
        in source: String,
        at start: String.Index
    ) -> (NovelToken, String.Index)? {
        precondition(source[start] == "[")

        // Single-bracket tags can't contain `[` or `]` in their payload, so
        // the first `]` after `[` ends the tag.
        let bodyStart = source.index(after: start)
        guard bodyStart < source.endIndex,
              source[bodyStart] != "[",
              let closeIndex = source[bodyStart..<source.endIndex].firstIndex(of: "]") else {
            return nil
        }

        let body = String(source[bodyStart..<closeIndex])
        let after = source.index(after: closeIndex)

        if body.lowercased() == "newpage" {
            return (.newPage, after)
        }

        if let value = body.afterCaseInsensitivePrefix("chapter:") {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return (.chapter(trimmed), after)
        }

        if let value = body.afterCaseInsensitivePrefix("pixivimage:") {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if let parsed = parsePixivImageReference(trimmed) {
                return (.pixivImage(illustID: parsed.illustID, page: parsed.page), after)
            }
            return nil
        }

        if let value = body.afterCaseInsensitivePrefix("uploadedimage:") {
            let key = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard key.isEmpty == false else { return nil }
            return (.uploadedImage(key: key), after)
        }

        if let value = body.afterCaseInsensitivePrefix("jump:") {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let page = Int(trimmed), page > 0 else { return nil }
            return (.jumpPage(page), after)
        }

        return nil
    }

    // MARK: - Double-bracket tags

    /// Matches `[[rb:base>reading]]` and `[[jumpuri:label>url]]`. Returns
    /// the token and the index past the closing `]]`.
    private static func matchDoubleBracketTag(
        in source: String,
        at start: String.Index
    ) -> (NovelToken, String.Index)? {
        precondition(source[start] == "[")
        let secondIndex = source.index(after: start)
        guard secondIndex < source.endIndex, source[secondIndex] == "[" else {
            return nil
        }

        // `[[ ... ]]` — search for the literal `]]` close. Use a manual scan
        // instead of `range(of:)` so the search is bounded and there's no
        // surprise allocation.
        let bodyStart = source.index(after: secondIndex)
        var scanIndex = bodyStart
        var closeIndex: String.Index?
        while scanIndex < source.endIndex {
            if source[scanIndex] == "]" {
                let nextIndex = source.index(after: scanIndex)
                if nextIndex < source.endIndex, source[nextIndex] == "]" {
                    closeIndex = scanIndex
                    break
                }
            }
            scanIndex = source.index(after: scanIndex)
        }

        guard let closeIndex else { return nil }
        let body = String(source[bodyStart..<closeIndex])
        let after = source.index(closeIndex, offsetBy: 2)

        if let value = body.afterCaseInsensitivePrefix("jumpuri:") {
            // Format: `label > url`. The `>` is the separator pixiv uses;
            // surrounding whitespace is trimmed.
            guard let separator = value.firstIndex(of: ">") else { return nil }
            let label = value[..<separator].trimmingCharacters(in: .whitespacesAndNewlines)
            let urlRaw = value[value.index(after: separator)...].trimmingCharacters(in: .whitespacesAndNewlines)
            guard urlRaw.isEmpty == false, let url = URL(string: urlRaw) else { return nil }
            return (.jumpURL(label: label, url: url), after)
        }

        if let value = body.afterCaseInsensitivePrefix("rb:") {
            guard let separator = value.firstIndex(of: ">") else { return nil }
            let base = value[..<separator].trimmingCharacters(in: .whitespacesAndNewlines)
            let reading = value[value.index(after: separator)...].trimmingCharacters(in: .whitespacesAndNewlines)
            guard base.isEmpty == false, reading.isEmpty == false else { return nil }
            return (.ruby(base: base, reading: reading), after)
        }

        return nil
    }

    // MARK: - Pixiv image reference

    private struct PixivImageReference {
        let illustID: Int
        let page: Int?
    }

    private static func parsePixivImageReference(_ raw: String) -> PixivImageReference? {
        let parts = raw.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: false)
        guard let first = parts.first, let illustID = Int(first), illustID > 0 else { return nil }
        if parts.count == 2 {
            guard let page = Int(parts[1]), page > 0 else { return nil }
            return PixivImageReference(illustID: illustID, page: page)
        }
        return PixivImageReference(illustID: illustID, page: nil)
    }
}

private extension String {
    /// If the receiver case-insensitively starts with `prefix`, return the
    /// remainder; otherwise nil. Used to peel known tag heads off a body
    /// without normalizing the whole string.
    func afterCaseInsensitivePrefix(_ prefix: String) -> String? {
        guard count >= prefix.count else { return nil }
        let head = self.prefix(prefix.count)
        guard head.caseInsensitiveCompare(prefix) == .orderedSame else { return nil }
        return String(self.dropFirst(prefix.count))
    }
}
