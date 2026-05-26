import Foundation

/// Structured representation of a Pixivision article body.
///
/// Replaces the previous "render the whole HTML in a `WKWebView`"
/// approach with native data the SwiftUI reader can lay out the same
/// way Apple News / Reader Mode does. Each article has a hero, an
/// optional category + date overline, a title, and a sequential block
/// list — interleaved paragraphs, section headings, and pixiv work
/// cards exactly as Pixivision arranges them.
struct PixivisionArticleContent: Sendable, Equatable {
    let articleID: Int
    let title: String
    let summary: String?
    let category: String?
    let publishDateText: String?
    let heroImageURL: URL?
    let blocks: [PixivisionArticleBlock]
    let tags: [PixivisionArticleTag]
}

/// Body block discovered in document order. The reader renders each
/// case with its own native treatment (paragraph text, section header,
/// or full artwork card with the pixiv navigation hooks already wired).
enum PixivisionArticleBlock: Sendable, Equatable, Identifiable {
    case heading(text: String)
    case paragraph(text: String)
    case work(PixivisionArticleWork)

    var id: String {
        switch self {
        case .heading(let text):
            return "h:" + text.prefix(60)
        case .paragraph(let text):
            return "p:" + text.prefix(60)
        case .work(let work):
            return "w:\(work.artworkID)"
        }
    }
}

/// Pixiv illustration referenced inline in the article body.
struct PixivisionArticleWork: Sendable, Equatable {
    let artworkID: Int
    let title: String
    let creatorID: Int
    let creatorName: String
    let creatorAvatarURL: URL?
    let illustImageURL: URL?
}

/// Tag chip Pixivision attaches to the article header. We carry the
/// raw `tagID` (Pixivision's own taxonomy) alongside the human label
/// so the reader can still link out — for now we open Pixivision Web,
/// but native tag landing pages can plug in later without touching the
/// reader view.
struct PixivisionArticleTag: Sendable, Equatable, Identifiable {
    let tagID: String
    let label: String

    var id: String { tagID }
}

/// Pure HTML → `PixivisionArticleContent` parser.
///
/// Every anchor we read out of Pixivision's HTML is a CSS class that
/// has been stable for years (`am__work`, `am__title`, `am__eyecatch`,
/// `am__article-body-container`, `am__header-tags`). We deliberately
/// avoid `og:` meta tags for the title because the og value is the
/// share-card variant; the in-page `<h1 class="am__title">` is the
/// canonical reader title.
///
/// The parser is intentionally conservative — when it can't recognise
/// a chunk it omits it, leaving the rendered article shorter rather
/// than lying about content. Any failures fall back to the seed
/// metadata Pixivision's API already shipped to us, so the reader
/// surface degrades gracefully (title + hero + share controls) instead
/// of going blank.
enum PixivisionArticleParser {
    /// Parse a Pixivision article from its raw HTML response.
    ///
    /// - Parameters:
    ///   - html: Full document body. We make no assumption about the
    ///     locale subdirectory (`/en/a/...`, `/zh/a/...`) — the same
    ///     class names ship across every language variant.
    ///   - articleID: Used purely as the resulting model's identifier.
    ///   - sourceURL: Used to resolve relative URLs (eg. tag links).
    static func parse(html: String, articleID: Int, sourceURL: URL) -> PixivisionArticleContent {
        let title = extractFirstString(in: html, pattern: #"<h1[^>]*class="am__title"[^>]*>(.*?)</h1>"#)
            ?? extractMetaContent(in: html, property: "og:title")
            ?? ""
        let summary = extractMetaContent(in: html, property: "og:description")
        let category = extractFirstString(
            in: html,
            pattern: #"<a[^>]*class="_category[^"]*"[^>]*>(.*?)</a>"#
        )
        let publishDate = extractFirstString(
            in: html,
            pattern: #"<time[^>]*class="_date[^"]*"[^>]*>(.*?)</time>"#
        )
        let heroImage = extractFirstString(
            in: html,
            pattern: #"<img[^>]*class="aie__image"[^>]*src="([^"]+)""#,
            decodeAsText: false
        ).flatMap { URL(string: $0) }
            ?? extractMetaContent(in: html, property: "og:image", decodeAsText: false)
                .flatMap { URL(string: $0) }

        let bodyHTML = extractBodyHTML(in: html)
        let blocks = parseBlocks(in: bodyHTML)
        let tags = parseTags(in: html, sourceURL: sourceURL)

        return PixivisionArticleContent(
            articleID: articleID,
            title: title,
            summary: summary,
            category: category,
            publishDateText: publishDate,
            heroImageURL: heroImage,
            blocks: blocks,
            tags: tags
        )
    }

    // MARK: - Body block parsing

    /// Walks the article-body container in document order, emitting a
    /// block per recognised element. Order matters: the renderer relies
    /// on the original sequence so headings introduce the right work
    /// card and paragraphs sit between the right two illustrations.
    ///
    /// The walk has two passes for a reason. A naive single regex that
    /// alternates between `am__work` and `<p>` / `<h3>` produces double
    /// hits on the work card's own inner `<h3 class="am__work__title">`
    /// and `<p class="am__work__user-name">`. We instead carve the
    /// body at every `am__work` boundary and only scan the *gaps*
    /// between cards for prose blocks — the cards themselves are
    /// parsed as a single unit, so their inner markup never bleeds
    /// into the rendered article body.
    static func parseBlocks(in bodyHTML: String) -> [PixivisionArticleBlock] {
        guard bodyHTML.isEmpty == false else { return [] }

        let workRanges = findWorkCardRanges(in: bodyHTML)

        var blocks: [PixivisionArticleBlock] = []
        var seenWorkIDs = Set<Int>()
        var cursor = bodyHTML.startIndex

        for workRange in workRanges {
            // Prose chunk that appeared between the last cursor and
            // the start of this work card — scan it for paragraphs +
            // headings so they keep their original document order.
            if cursor < workRange.lowerBound {
                appendProseBlocks(
                    from: String(bodyHTML[cursor..<workRange.lowerBound]),
                    into: &blocks
                )
            }

            if let work = parseWork(in: String(bodyHTML[workRange])),
               seenWorkIDs.insert(work.artworkID).inserted {
                blocks.append(.work(work))
            }
            cursor = workRange.upperBound
        }

        // Trailing prose after the last work card.
        if cursor < bodyHTML.endIndex {
            appendProseBlocks(
                from: String(bodyHTML[cursor..<bodyHTML.endIndex]),
                into: &blocks
            )
        }

        return blocks
    }

    /// Finds every `<div class="am__work">…</div>` block in the body,
    /// counting balanced `<div>` opens/closes so the matched range
    /// always wraps the *whole* card — even when the inner markup
    /// nests divs at different depths.
    private static func findWorkCardRanges(in bodyHTML: String) -> [Range<String.Index>] {
        let openMarker = "<div class=\"am__work\">"
        let openTag = "<div"
        let closeTag = "</div>"

        var results: [Range<String.Index>] = []
        var searchStart = bodyHTML.startIndex

        while let openRange = bodyHTML.range(of: openMarker, range: searchStart..<bodyHTML.endIndex) {
            var depth = 1
            var cursor = openRange.upperBound

            while depth > 0, cursor < bodyHTML.endIndex {
                let nextOpen = bodyHTML.range(of: openTag, range: cursor..<bodyHTML.endIndex)
                let nextClose = bodyHTML.range(of: closeTag, range: cursor..<bodyHTML.endIndex)

                guard let close = nextClose else { break }

                if let open = nextOpen, open.lowerBound < close.lowerBound {
                    depth += 1
                    cursor = open.upperBound
                } else {
                    depth -= 1
                    cursor = close.upperBound
                }
            }

            if depth == 0 {
                results.append(openRange.lowerBound..<cursor)
                searchStart = cursor
            } else {
                // Unbalanced — bail out instead of looping forever.
                break
            }
        }

        return results
    }

    /// Scans a prose-only chunk (no work cards inside) for `<h2>` /
    /// `<h3>` / `<p>` blocks and appends them in order.
    private static func appendProseBlocks(from chunk: String, into blocks: inout [PixivisionArticleBlock]) {
        guard chunk.isEmpty == false else { return }
        let pattern = #"(?s)(<h[23][^>]*>.*?</h[23]>)|(<p[^>]*>.*?</p>)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return }

        let nsRange = NSRange(chunk.startIndex..<chunk.endIndex, in: chunk)
        regex.enumerateMatches(in: chunk, options: [], range: nsRange) { match, _, _ in
            guard let match else { return }

            if let headingRange = Range(match.range(at: 1), in: chunk) {
                let text = stripTags(String(chunk[headingRange]))
                if text.isEmpty == false {
                    blocks.append(.heading(text: text))
                }
                return
            }
            if let paragraphRange = Range(match.range(at: 2), in: chunk) {
                let text = stripTags(String(chunk[paragraphRange]))
                if text.isEmpty == false {
                    blocks.append(.paragraph(text: text))
                }
            }
        }
    }

    private static func parseWork(in html: String) -> PixivisionArticleWork? {
        // Artwork ID — first `pixiv.net/artworks/{id}` link inside the card.
        guard let artworkID = firstCapturedInt(
            in: html,
            pattern: #"pixiv\.net/artworks/(\d+)"#
        ) else {
            return nil
        }

        let creatorID = firstCapturedInt(in: html, pattern: #"pixiv\.net/users/(\d+)"#) ?? 0
        let title = extractFirstString(
            in: html,
            pattern: #"<h3[^>]*class="am__work__title"[^>]*>\s*<a[^>]*>(.*?)</a>"#
        ) ?? ""
        let creatorName = extractFirstString(
            in: html,
            pattern: #"<p[^>]*class="am__work__user-name"[^>]*>.*?<a[^>]*>(.*?)</a>"#
        ) ?? ""
        // Pixivision's `<img>` tags don't enforce a fixed attribute
        // order — `src` can appear before or after `class`. We grab
        // the whole tag by its class anchor first, then extract `src`
        // from anywhere inside it.
        let avatarURL = extractImageSource(in: html, classAnchor: "am__work__uesr-icon")
            .flatMap(URL.init(string:))
        let illustURL = extractImageSource(in: html, classAnchor: "am__work__illust")
            .flatMap(URL.init(string:))

        return PixivisionArticleWork(
            artworkID: artworkID,
            title: title,
            creatorID: creatorID,
            creatorName: creatorName,
            creatorAvatarURL: avatarURL,
            illustImageURL: illustURL
        )
    }

    /// Find the first `<img>` tag whose `class` attribute contains the
    /// given anchor word, and return its `src` attribute. Robust to
    /// attribute ordering (`<img src=… class=…>` vs `<img class=… src=…>`).
    private static func extractImageSource(in html: String, classAnchor: String) -> String? {
        let escaped = NSRegularExpression.escapedPattern(for: classAnchor)
        let pattern = #"(<img\b[^>]*class="[^"]*\#(escaped)[^"]*"[^>]*>)"#
        guard let imgTag = extractFirstString(in: html, pattern: pattern, decodeAsText: false) else {
            return nil
        }
        return extractFirstString(in: imgTag, pattern: #"\bsrc="([^"]+)""#, decodeAsText: false)
    }

    private static func parseTags(in html: String, sourceURL: URL) -> [PixivisionArticleTag] {
        guard let tagListHTML = extractFirstString(
            in: html,
            pattern: #"<ul[^>]*class="am__header-tags[^"]*"[^>]*>(.*?)</ul>"#,
            decodeAsText: false
        ) else { return [] }

        var tags: [PixivisionArticleTag] = []
        var seenIDs = Set<String>()
        let pattern = #"<a[^>]*href="(?:[^"]*?/t/)?([^"/]+)"[^>]*>(.*?)</a>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else {
            return []
        }

        let nsRange = NSRange(tagListHTML.startIndex..<tagListHTML.endIndex, in: tagListHTML)
        regex.enumerateMatches(in: tagListHTML, options: [], range: nsRange) { match, _, _ in
            guard let match,
                  let idRange = Range(match.range(at: 1), in: tagListHTML),
                  let textRange = Range(match.range(at: 2), in: tagListHTML) else {
                return
            }
            let tagID = String(tagListHTML[idRange])
            let label = stripTags(String(tagListHTML[textRange]))
            guard tagID.isEmpty == false,
                  label.isEmpty == false,
                  seenIDs.insert(tagID).inserted else { return }
            tags.append(PixivisionArticleTag(tagID: tagID, label: label))
        }

        return tags
    }

    // MARK: - HTML helpers

    private static func extractBodyHTML(in html: String) -> String {
        // Pixivision wraps the prose in `am__article-body-container`.
        // Stop at the share-buttons block; everything below that is
        // the social/related-articles footer that we render with our
        // own controls.
        let pattern = #"(?s)class="am__article-body-container"(.*?)<div class="am__share-buttons""#
        return extractFirstString(in: html, pattern: pattern, decodeAsText: false) ?? ""
    }

    private static func extractMetaContent(
        in html: String,
        property: String,
        decodeAsText: Bool = true
    ) -> String? {
        let escaped = NSRegularExpression.escapedPattern(for: property)
        let pattern = #"<meta[^>]*property="\#(escaped)"[^>]*content="([^"]+)""#
        return extractFirstString(in: html, pattern: pattern, decodeAsText: decodeAsText)
    }

    private static func extractFirstString(
        in html: String,
        pattern: String,
        decodeAsText: Bool = true
    ) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else {
            return nil
        }
        let nsRange = NSRange(html.startIndex..<html.endIndex, in: html)
        guard let match = regex.firstMatch(in: html, options: [], range: nsRange),
              match.numberOfRanges >= 2,
              let captureRange = Range(match.range(at: 1), in: html) else {
            return nil
        }
        let raw = String(html[captureRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        return decodeAsText ? decodeEntities(stripTags(raw)) : raw
    }

    private static func firstCapturedInt(in html: String, pattern: String) -> Int? {
        extractFirstString(in: html, pattern: pattern, decodeAsText: false)
            .flatMap(Int.init)
    }

    static func stripTags(_ input: String) -> String {
        let withoutTags = input.replacingOccurrences(
            of: "<[^>]+>",
            with: "",
            options: [.regularExpression]
        )
        return decodeEntities(withoutTags).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func decodeEntities(_ input: String) -> String {
        guard input.contains("&") else { return input }
        var output = input
        let map: [(String, String)] = [
            ("&amp;", "&"),
            ("&lt;", "<"),
            ("&gt;", ">"),
            ("&quot;", "\""),
            ("&#039;", "'"),
            ("&apos;", "'"),
            ("&nbsp;", " ")
        ]
        for (entity, replacement) in map {
            output = output.replacingOccurrences(of: entity, with: replacement)
        }
        return output
    }
}
