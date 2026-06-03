import Foundation

/// Structured representation of a Pixivision article body.
///
/// Replaces the previous "render the whole HTML in a `WKWebView`"
/// approach with native data the SwiftUI reader can lay out the same
/// way Apple News / Reader Mode does. Each article has a hero, an
/// optional category + date overline, a title, and a sequential block
/// list — interleaved paragraphs, section headings, and pixiv work
/// cards exactly as Pixivision arranges them. Trailing metadata
/// (related-article shelves Pixivision shows under the prose) ride
/// alongside `blocks` so the reader can render Apple-Music-style
/// horizontal carousels at the bottom of the page.
struct PixivisionArticleContent: Sendable, Equatable {
    let articleID: Int
    let title: String
    let summary: String?
    let category: String?
    let publishDateText: String?
    let heroImageURL: URL?
    let blocks: [PixivisionArticleBlock]
    let tags: [PixivisionArticleTag]
    let relatedSections: [PixivisionRelatedArticlesSection]
}

/// Body block discovered in document order. The reader renders each
/// case with its own native treatment (paragraph text, section header,
/// or full artwork card with the pixiv navigation hooks already wired).
enum PixivisionArticleBlock: Sendable, Equatable, Identifiable {
    case heading(text: String)
    case paragraph(text: String)
    case work(PixivisionArticleWork)
    case article(PixivisionInlineArticle)

    var id: String {
        switch self {
        case .heading(let text):
            return "h:" + text.prefix(60)
        case .paragraph(let text):
            return "p:" + text.prefix(60)
        case .work(let work):
            return "w:\(work.artworkID)"
        case .article(let article):
            return "a:\(article.articleID)"
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

/// Pixivision article card embedded inside a feature article body.
/// Monthly / curated roundup pages use this for "all articles" blocks:
/// a heading per language or topic, followed by one or more article
/// cards linking to other Pixivision pages.
struct PixivisionInlineArticle: Sendable, Equatable, Identifiable {
    let articleID: Int
    let title: String
    let category: String?
    let publishDateText: String?
    let coverURL: URL?
    let articleURL: URL
    let tags: [String]

    var id: Int { articleID }
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

/// One of the related-article shelves Pixivision renders below the
/// article body — "Latest articles tagged X", "People who liked X also
/// liked", "Latest in category". Each shelf has a heading and an
/// ordered list of cards routing back to other Pixivision articles.
struct PixivisionRelatedArticlesSection: Sendable, Equatable, Identifiable {
    /// The categories Pixivision groups its related shelves into. We
    /// surface them in the reader so users can tell why each carousel
    /// was suggested.
    enum Kind: String, Sendable, Equatable {
        case tagLatest
        case tagPopular
        case categoryLatest
        case other

        var localizedTitle: String {
            switch self {
            case .tagLatest: L10n.pixivisionRelatedTagLatest
            case .tagPopular: L10n.pixivisionRelatedTagPopular
            case .categoryLatest: L10n.pixivisionRelatedCategoryLatest
            case .other: L10n.pixivisionRelatedArticles
            }
        }

        var systemImage: String {
            switch self {
            case .tagLatest: "tag"
            case .tagPopular: "heart.fill"
            case .categoryLatest: "newspaper"
            case .other: "doc.text"
            }
        }
    }

    let kind: Kind
    /// Human-readable shelf heading scraped from Pixivision (e.g.
    /// "腿部相关最新文章"). May be `nil` if the heading couldn't be
    /// parsed; the reader falls back to `kind.localizedTitle`.
    let heading: String?
    let articles: [PixivisionRelatedArticle]
    /// Pixivision exposes a "查看更多 ▶︎" link below each shelf that
    /// points to the tag landing page or category index. We expose
    /// that here so the reader can render a "View More" affordance
    /// without re-deriving the URL from the heading.
    let viewMoreURL: URL?

    var id: String { "\(kind.rawValue)|\(heading ?? "")" }

    var resolvedHeading: String {
        let trimmed = heading?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmed, trimmed.isEmpty == false {
            return trimmed
        }
        return kind.localizedTitle
    }
}

/// One card inside a related-articles shelf. The reader uses
/// `articleID` to route back into the native spotlight surface — the
/// click ends up calling `store.selectedSpotlightArticle = ...` so the
/// detail view re-renders with parsed content for the new article.
struct PixivisionRelatedArticle: Sendable, Equatable, Identifiable {
    let articleID: Int
    let title: String
    let coverURL: URL?
    /// The full Pixivision URL (e.g. `https://www.pixivision.net/zh/a/11556`)
    /// so users can fall back to the web view via "Open in Pixiv".
    let articleURL: URL

    var id: Int { articleID }
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
        // Pixivision occasionally nests one or more `_related-articles`
        // shelves *inside* the article body container instead of below
        // it. Their `<h3 class="rla__heading">` matches the prose
        // heading regex, so without this strip step the shelf headings
        // ("XXX相关最新文章" / "喜欢XXX的人也喜欢这些") render twice —
        // once as bare prose blocks at the bottom of the article body
        // and again as the headers of `RelatedArticlesShelf`. We
        // already extract those shelves separately via
        // `parseRelatedSections`, so removing them from the body
        // before block parsing keeps each heading rendered once.
        let prunedBody = removeRelatedShelves(from: bodyHTML)
        let blocks = parseBlocks(in: prunedBody, sourceURL: sourceURL)
        let tags = parseTags(in: html, sourceURL: sourceURL)
        let relatedSections = parseRelatedSections(in: html, sourceURL: sourceURL)

        return PixivisionArticleContent(
            articleID: articleID,
            title: title,
            summary: summary,
            category: category,
            publishDateText: publishDate,
            heroImageURL: heroImage,
            blocks: blocks,
            tags: tags,
            relatedSections: relatedSections
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
    static func parseBlocks(
        in bodyHTML: String,
        sourceURL: URL = URL(string: "https://www.pixivision.net/")!
    ) -> [PixivisionArticleBlock] {
        guard bodyHTML.isEmpty == false else { return [] }

        let contentRanges = (
            findWorkCardRanges(in: bodyHTML).map { BodyBlockRange(range: $0, kind: .work) }
                + findInlineArticleCardRanges(in: bodyHTML).map { BodyBlockRange(range: $0, kind: .article) }
        )
        .sorted { $0.range.lowerBound < $1.range.lowerBound }

        var blocks: [PixivisionArticleBlock] = []
        var seenWorkIDs = Set<Int>()
        var seenArticleIDs = Set<Int>()
        var cursor = bodyHTML.startIndex

        for contentRange in contentRanges {
            // Prose chunk that appeared between the last cursor and
            // the start of this card — scan it for paragraphs +
            // headings so they keep their original document order.
            if cursor < contentRange.range.lowerBound {
                appendProseBlocks(
                    from: String(bodyHTML[cursor..<contentRange.range.lowerBound]),
                    into: &blocks
                )
            }

            let cardHTML = String(bodyHTML[contentRange.range])
            switch contentRange.kind {
            case .work:
                if let work = parseWork(in: cardHTML),
                   seenWorkIDs.insert(work.artworkID).inserted {
                    blocks.append(.work(work))
                }
            case .article:
                if let article = parseInlineArticle(in: cardHTML, sourceURL: sourceURL),
                   seenArticleIDs.insert(article.articleID).inserted {
                    blocks.append(.article(article))
                }
            }
            cursor = contentRange.range.upperBound
        }

        // Trailing prose after the last recognised card.
        if cursor < bodyHTML.endIndex {
            appendProseBlocks(
                from: String(bodyHTML[cursor..<bodyHTML.endIndex]),
                into: &blocks
            )
        }

        return blocks
    }

    private struct BodyBlockRange {
        let range: Range<String.Index>
        let kind: Kind

        enum Kind {
            case work
            case article
        }
    }

    /// Finds every `<div class="am__work">…</div>` block in the body,
    /// counting balanced `<div>` opens/closes so the matched range
    /// always wraps the *whole* card — even when the inner markup
    /// nests divs at different depths.
    private static func findWorkCardRanges(in bodyHTML: String) -> [Range<String.Index>] {
        findBalancedDivRanges(
            in: bodyHTML,
            openerPattern: #"<div\b[^>]*class="[^"]*\bam__work\b[^"]*"[^>]*>"#
        )
    }

    /// Finds Pixivision article cards embedded in curated feature
    /// articles, e.g. the monthly roundup pages where each language
    /// section is a list of `_article-card` blocks.
    private static func findInlineArticleCardRanges(in bodyHTML: String) -> [Range<String.Index>] {
        findBalancedDivRanges(
            in: bodyHTML,
            openerPattern: #"<div\b[^>]*class="[^"]*_feature-article-body__article_card[^"]*"[^>]*>"#
        )
    }

    private static func findBalancedDivRanges(
        in bodyHTML: String,
        openerPattern: String
    ) -> [Range<String.Index>] {
        let openTag = "<div"
        let closeTag = "</div>"
        guard let regex = try? NSRegularExpression(pattern: openerPattern, options: []) else {
            return []
        }

        var results: [Range<String.Index>] = []
        var searchStart = bodyHTML.startIndex

        while searchStart < bodyHTML.endIndex {
            let searchRange = NSRange(searchStart..<bodyHTML.endIndex, in: bodyHTML)
            guard let match = regex.firstMatch(in: bodyHTML, options: [], range: searchRange),
                  let openRange = Range(match.range, in: bodyHTML) else {
                break
            }

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

    /// Scans a prose-only chunk (no work cards inside) for the prose
    /// blocks Pixivision uses across both article styles:
    ///
    ///   * Interview / spotlight pages: bare `<h2>` / `<h3>` headings
    ///     and `<p>` paragraphs.
    ///   * Feature pages: `<div class="article-item
    ///     _feature-article-body__heading">…</div>` and
    ///     `<div class="article-item _feature-article-body__paragraph">…</div>`
    ///     wrappers whose inner markup is a plain heading or
    ///     `<div class="fab__paragraph _medium-editor-text">…</div>`
    ///     wrapper rather than a top-level `<p>`.
    ///
    /// We try the feature-style wrapper first (regex anchored on the
    /// `_feature-article-body__` class fragment) so a paragraph that
    /// uses a `<div>` wrapper still becomes a `.paragraph` block in
    /// document order. Anything left over falls through to the
    /// interview-style scan.
    private static func appendProseBlocks(from chunk: String, into blocks: inout [PixivisionArticleBlock]) {
        guard chunk.isEmpty == false else { return }
        let pattern = #"(?s)(<div\b[^>]*class="[^"]*_feature-article-body__heading[^"]*"[^>]*>.*?</div>)|(<div\b[^>]*class="[^"]*_feature-article-body__paragraph[^"]*"[^>]*>.*?</div>\s*</div>)|(<h[23][^>]*>.*?</h[23]>)|(<p[^>]*>.*?</p>)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return }

        let nsRange = NSRange(chunk.startIndex..<chunk.endIndex, in: chunk)
        regex.enumerateMatches(in: chunk, options: [], range: nsRange) { match, _, _ in
            guard let match else { return }

            // Feature-style heading wrapper.
            if let r = Range(match.range(at: 1), in: chunk) {
                let text = stripTags(String(chunk[r]))
                if text.isEmpty == false {
                    blocks.append(.heading(text: text))
                }
                return
            }
            // Feature-style paragraph wrapper.
            if let r = Range(match.range(at: 2), in: chunk) {
                let text = stripTags(String(chunk[r]))
                if text.isEmpty == false {
                    blocks.append(.paragraph(text: text))
                }
                return
            }
            // Interview-style heading.
            if let r = Range(match.range(at: 3), in: chunk) {
                let text = stripTags(String(chunk[r]))
                if text.isEmpty == false {
                    blocks.append(.heading(text: text))
                }
                return
            }
            // Interview-style paragraph.
            if let r = Range(match.range(at: 4), in: chunk) {
                let text = stripTags(String(chunk[r]))
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

    private static func parseInlineArticle(in html: String, sourceURL: URL) -> PixivisionInlineArticle? {
        guard let articleID = firstCapturedInt(in: html, pattern: #"href="[^"]*/a/(\d+)""#) else {
            return nil
        }
        let title = extractFirstString(
            in: html,
            pattern: #"<h2[^>]*class="[^"]*arc__title[^"]*"[^>]*>[\s\S]*?<a[^>]*>([\s\S]*?)</a>"#
        ) ?? extractFirstString(
            in: html,
            pattern: #"<a[^>]*data-gtm-action="ClickTitle"[^>]*>([\s\S]*?)</a>"#
        ) ?? ""
        let category = extractFirstString(
            in: html,
            pattern: #"<span[^>]*class="[^"]*arc__thumbnail-label[^"]*"[^>]*>([\s\S]*?)</span>"#
        )
        let publishDate = extractFirstString(
            in: html,
            pattern: #"<time[^>]*class="[^"]*_date[^"]*"[^>]*>([\s\S]*?)</time>"#
        )
        let coverURL = extractBackgroundImageURL(in: html).flatMap(URL.init(string:))
        let articleHref = extractFirstString(
            in: html,
            pattern: #"<a[^>]*href="([^"]*/a/\d+)""#,
            decodeAsText: false
        )
        let articleURL = articleHref.flatMap { absoluteURL(from: $0, sourceURL: sourceURL) }
            ?? fallbackArticleURL(articleID: articleID, sourceURL: sourceURL)
        let tags = parseInlineArticleTagLabels(in: html)

        return PixivisionInlineArticle(
            articleID: articleID,
            title: title,
            category: category,
            publishDateText: publishDate,
            coverURL: coverURL,
            articleURL: articleURL,
            tags: tags
        )
    }

    private static func parseInlineArticleTagLabels(in html: String) -> [String] {
        let pattern = #"<(?:div|span)[^>]*class="[^"]*tls__list-item[^"]*"[^>]*>([\s\S]*?)</(?:div|span)>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return []
        }

        var labels: [String] = []
        var seen = Set<String>()
        let nsRange = NSRange(html.startIndex..<html.endIndex, in: html)
        regex.enumerateMatches(in: html, options: [], range: nsRange) { match, _, _ in
            guard let match,
                  let range = Range(match.range(at: 1), in: html) else {
                return
            }
            let label = stripTags(String(html[range]))
            guard label.isEmpty == false, seen.insert(label).inserted else { return }
            labels.append(label)
        }
        return labels
    }

    private static func fallbackArticleURL(articleID: Int, sourceURL: URL) -> URL {
        let pathComponents = sourceURL.pathComponents.filter { $0 != "/" }
        let localePrefix: String
        if pathComponents.count >= 2, pathComponents[1] == "a", pathComponents[0] != "a" {
            localePrefix = "/\(pathComponents[0])"
        } else {
            localePrefix = ""
        }
        let fallbackPath = "\(localePrefix)/a/\(articleID)"
        return absoluteURL(from: fallbackPath, sourceURL: sourceURL)
            ?? URL(string: "https://www.pixivision.net/a/\(articleID)")!
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

    private static func extractBackgroundImageURL(in html: String) -> String? {
        extractFirstString(
            in: html,
            pattern: #"<div[^>]*class="[^"]*_thumbnail[^"]*"[^>]*style="[^"]*url\(([^)]+)\)[^"]*"[^>]*>"#,
            decodeAsText: false
        )
        .map {
            $0.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
        }
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

    // MARK: - Related-articles parsing

    /// Walks every `<div class="_related-articles" ...>` shelf below
    /// the article body and returns one section per shelf. Pixivision
    /// renders three of these on most articles:
    ///
    ///   * Tag-based latest — "腿部相关最新文章" / "Latest in <tag>"
    ///   * Tag-based popular — "喜欢腿部的人也喜欢这些"
    ///   * Category-based latest — "插画相关最新文章" / "Latest in <category>"
    ///
    /// We use the `data-gtm-category` attribute to decide which `Kind`
    /// the shelf belongs to so the reader can decorate it with the
    /// right localized label and SF symbol.
    /// Removes every `<div class="_related-articles" ...>...</div>`
    /// block from the body HTML. Used by `parse(...)` so the prose
    /// scanner doesn't mistake a related-shelf `<h3 class="rla__heading">`
    /// for an article-body heading. Walks balanced `<div>` open/close
    /// counts the same way `extractBodyHTML` walks `<article>`, so the
    /// trailing `<div class="rla__more-container">` and any nested
    /// `<article>` cards inside the shelf get removed in one go.
    private static func removeRelatedShelves(from html: String) -> String {
        guard html.isEmpty == false else { return html }
        let opener = #"<div\b[^>]*class="_related-articles"[^>]*>"#
        guard let regex = try? NSRegularExpression(pattern: opener, options: []) else {
            return html
        }

        var result = html
        let openTag = "<div"
        let closeTag = "</div>"

        while true {
            let range = NSRange(result.startIndex..<result.endIndex, in: result)
            guard let match = regex.firstMatch(in: result, options: [], range: range),
                  let openTagRange = Range(match.range, in: result) else {
                break
            }

            var depth = 1
            var cursor = openTagRange.upperBound

            while depth > 0, cursor < result.endIndex {
                let nextOpen = result.range(of: openTag, range: cursor..<result.endIndex)
                let nextClose = result.range(of: closeTag, range: cursor..<result.endIndex)
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
                result.replaceSubrange(openTagRange.lowerBound..<cursor, with: "")
            } else {
                // Unbalanced — bail to avoid an infinite loop. The
                // body still renders correctly without this strip.
                break
            }
        }

        return result
    }

    private static func parseRelatedSections(in html: String, sourceURL: URL) -> [PixivisionRelatedArticlesSection] {
        let pattern = #"<div\b[^>]*class="_related-articles"[^>]*data-gtm-category="([^"]+)"[^>]*>([\s\S]*?)</ul>\s*(?:<div[^>]*class="rla__more-container"[^>]*>([\s\S]*?)</div>\s*)?</div>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return []
        }

        var sections: [PixivisionRelatedArticlesSection] = []
        let nsRange = NSRange(html.startIndex..<html.endIndex, in: html)

        regex.enumerateMatches(in: html, options: [], range: nsRange) { match, _, _ in
            guard let match,
                  let kindRange = Range(match.range(at: 1), in: html),
                  let bodyRange = Range(match.range(at: 2), in: html) else {
                return
            }
            let kind = relatedSectionKind(from: String(html[kindRange]))
            let body = String(html[bodyRange])
            let heading = extractFirstString(
                in: body,
                pattern: #"<h3[^>]*class="rla__heading[^"]*"[^>]*>([\s\S]*?)</h3>"#
            )
            let articles = parseRelatedArticleCards(in: body, sourceURL: sourceURL)

            // The optional `rla__more-container` group sits *outside*
            // the closing `</ul>` and may not be present on every
            // shelf — pull it lazily.
            var viewMoreURL: URL?
            if match.numberOfRanges > 3, let moreRange = Range(match.range(at: 3), in: html) {
                let moreSnippet = String(html[moreRange])
                if let href = extractFirstString(
                    in: moreSnippet,
                    pattern: #"<a[^>]*class="rla__more__link"[^>]*href="([^"]+)""#,
                    decodeAsText: false
                ) ?? extractFirstString(
                    in: moreSnippet,
                    pattern: #"<a[^>]*href="([^"]+)"[^>]*class="rla__more__link""#,
                    decodeAsText: false
                ) {
                    viewMoreURL = absoluteURL(from: href, sourceURL: sourceURL)
                }
            }

            // Skip empty shelves so the reader doesn't render a
            // header for a section the network filtered down to zero
            // cards (rare but possible).
            guard articles.isEmpty == false else { return }
            sections.append(
                PixivisionRelatedArticlesSection(
                    kind: kind,
                    heading: heading,
                    articles: articles,
                    viewMoreURL: viewMoreURL
                )
            )
        }

        return sections
    }

    private static func relatedSectionKind(from gtmCategory: String) -> PixivisionRelatedArticlesSection.Kind {
        switch gtmCategory.lowercased() {
        case "related article latest": return .tagLatest
        case "related article popular": return .tagPopular
        case "article latest": return .categoryLatest
        default: return .other
        }
    }

    private static func parseRelatedArticleCards(in shelfHTML: String, sourceURL: URL) -> [PixivisionRelatedArticle] {
        let pattern = #"<li\b[^>]*class="arrctl__list-item"[^>]*>([\s\S]*?)</li>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return []
        }

        var cards: [PixivisionRelatedArticle] = []
        var seenIDs = Set<Int>()
        let nsRange = NSRange(shelfHTML.startIndex..<shelfHTML.endIndex, in: shelfHTML)

        regex.enumerateMatches(in: shelfHTML, options: [], range: nsRange) { match, _, _ in
            guard let match,
                  let itemRange = Range(match.range(at: 1), in: shelfHTML) else {
                return
            }
            let item = String(shelfHTML[itemRange])

            // The card shows up twice — once as the thumbnail anchor
            // and once as the title anchor. Either anchor carries the
            // canonical `/zh/a/{id}` (or `/en/a/{id}`, etc.) path, so
            // grab the first match.
            guard let articleID = firstCapturedInt(in: item, pattern: #"href="[^"]*/a/(\d+)"#) else {
                return
            }
            guard seenIDs.insert(articleID).inserted else { return }

            let title = extractFirstString(
                in: item,
                pattern: #"<h4[^>]*class="arrct__title"[^>]*>[\s\S]*?<a[^>]*>([\s\S]*?)</a>"#
            ) ?? extractFirstString(
                in: item,
                pattern: #"<img[^>]*class="thm__image"[^>]*alt="([^"]+)""#
            ) ?? ""

            let coverURL = extractImageSource(in: item, classAnchor: "thm__image")
                .flatMap(URL.init(string:))
            let articleHref = extractFirstString(
                in: item,
                pattern: #"<a[^>]*href="([^"]*/a/\d+)"#,
                decodeAsText: false
            )
            let articleURL = articleHref.flatMap { absoluteURL(from: $0, sourceURL: sourceURL) }
                ?? URL(string: "https://www.pixivision.net/a/\(articleID)")!

            cards.append(
                PixivisionRelatedArticle(
                    articleID: articleID,
                    title: title,
                    coverURL: coverURL,
                    articleURL: articleURL
                )
            )
        }

        return cards
    }

    /// Resolve a possibly relative href against the article's source
    /// URL so callers always have an absolute URL to navigate to.
    private static func absoluteURL(from href: String, sourceURL: URL) -> URL? {
        let trimmed = href.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return nil }
        if trimmed.hasPrefix("//") {
            return URL(string: "https:" + trimmed)
        }
        return URL(string: trimmed, relativeTo: sourceURL)?.absoluteURL
    }

    // MARK: - HTML helpers

    private static func extractBodyHTML(in html: String) -> String {
        // Pixivision wraps the prose in an `<article ...
        // class="am__article-body-container">…</article>` regardless of
        // article style (interview, spotlight, feature). We walk the
        // markup with balanced `<article>` open/close counts so we get
        // the entire body even when the document nests further article
        // tags inside (related-article cards, schema fragments, etc.).
        //
        // The previous implementation looked for a trailing
        // `<div class="am__share-buttons">` sentinel — which only ships
        // on interview-style pages. Feature articles like
        // `球体关节插画特辑` omit the share block entirely, so the regex
        // never matched and the body came back empty. That made the
        // reader collapse to title + hero only, hiding the 14+ work
        // cards the article actually contains.
        let opener = "<article"
        guard let openTagRange = html.range(of: #"<article[^>]*class="[^"]*am__article-body-container[^"]*"[^>]*>"#,
                                           options: .regularExpression) else {
            return ""
        }

        var depth = 1
        var cursor = openTagRange.upperBound
        let closeTag = "</article>"

        while depth > 0, cursor < html.endIndex {
            let nextOpen = html.range(of: opener, range: cursor..<html.endIndex)
            let nextClose = html.range(of: closeTag, range: cursor..<html.endIndex)
            guard let close = nextClose else { break }

            if let open = nextOpen, open.lowerBound < close.lowerBound {
                depth += 1
                cursor = open.upperBound
            } else {
                depth -= 1
                if depth == 0 {
                    return String(html[openTagRange.upperBound..<close.lowerBound])
                }
                cursor = close.upperBound
            }
        }

        return ""
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
