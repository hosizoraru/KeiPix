import Foundation
import Testing
@testable import KeiPix

/// Verifies the Pixivision HTML → structured-content parser produces
/// the right blocks against representative real-world fixtures. The
/// fixtures are kept inline so the test suite is hermetic — no network,
/// no on-disk fixture file to drift out of sync with the parser.
struct PixivisionArticleParserTests {
    @Test("Parser extracts title, hero, body blocks, and tag chips")
    func parsesEndToEnd() {
        let parsed = PixivisionArticleParser.parse(
            html: Self.sampleHTML,
            articleID: 9988,
            sourceURL: URL(string: "https://www.pixivision.net/en/a/9988")!
        )

        #expect(parsed.articleID == 9988)
        #expect(parsed.title.contains("MON"))
        #expect(parsed.category == "Interviews")
        #expect(parsed.publishDateText == "2024.07.10")
        #expect(parsed.heroImageURL?.absoluteString.contains("ogimage.jpg") == true)

        // Tag chips include the canonical Pixivision tag IDs.
        #expect(parsed.tags.map(\.tagID) == ["71", "149"])
        #expect(parsed.tags.map(\.label) == ["interview", "illustrator interviews"])

        // Document order is preserved: heading → paragraph → work
        // card → paragraph in the fixture.
        #expect(parsed.blocks.count == 4)
        if case .heading(let text) = parsed.blocks[0] {
            #expect(text.contains("Graduated from art school"))
        } else {
            Issue.record("First block was not a heading")
        }
        if case .paragraph(let text) = parsed.blocks[1] {
            #expect(text.contains("first solo exhibition"))
        } else {
            Issue.record("Second block was not a paragraph")
        }
        if case .work(let work) = parsed.blocks[2] {
            #expect(work.artworkID == 67323816)
            #expect(work.creatorID == 25915682)
            #expect(work.title == "Reaper")
            #expect(work.creatorName == "MON")
            #expect(work.creatorAvatarURL != nil)
            #expect(work.illustImageURL != nil)
        } else {
            Issue.record("Third block was not a work card")
        }
        if case .paragraph = parsed.blocks[3] {} else {
            Issue.record("Fourth block was not a paragraph")
        }
    }

    @Test("Duplicate work cards in the same article are deduplicated by artwork ID")
    func dedupesRepeatedWorkCards() {
        let html = Self.workCardHTML(artworkID: 1234, creatorID: 5678, title: "Alpha", creator: "Anon")
            + Self.workCardHTML(artworkID: 1234, creatorID: 5678, title: "Alpha", creator: "Anon")
            + Self.workCardHTML(artworkID: 9876, creatorID: 5432, title: "Beta", creator: "Other")
        let bodyWrapped = #"class="am__article-body-container">"# + html
            + #"<div class="am__share-buttons">"#
        let blocks = PixivisionArticleParser.parseBlocks(in: bodyWrapped)
        let workIDs = blocks.compactMap { block -> Int? in
            if case .work(let w) = block { return w.artworkID } else { return nil }
        }
        #expect(workIDs == [1234, 9876])
    }

    @Test("HTML entities and tags are stripped from extracted text")
    func decodesEntities() {
        let raw = "Hi &amp; <em>welcome</em> to &quot;pixivision&quot;"
        #expect(PixivisionArticleParser.stripTags(raw) == "Hi & welcome to \"pixivision\"")
        #expect(PixivisionArticleParser.decodeEntities("&#039;quoted&#039;") == "'quoted'")
    }

    @Test("Article without recognised body returns title-only content")
    func handlesEmptyBody() {
        let html = """
        <html><head>
        <meta property="og:title" content="Fallback title">
        <meta property="og:description" content="Description here.">
        </head><body><h1 class="am__title">Fallback title</h1></body></html>
        """
        let parsed = PixivisionArticleParser.parse(
            html: html,
            articleID: 1,
            sourceURL: URL(string: "https://www.pixivision.net/en/a/1")!
        )
        #expect(parsed.title == "Fallback title")
        #expect(parsed.summary == "Description here.")
        #expect(parsed.blocks.isEmpty)
        #expect(parsed.tags.isEmpty)
    }

    @Test("Feature article with many work cards parses every card and its caption")
    func parsesFeatureArticleWithManyCards() {
        let parsed = PixivisionArticleParser.parse(
            html: Self.featureArticleHTML,
            articleID: 10338,
            sourceURL: URL(string: "https://www.pixivision.net/zh/a/10338")!
        )

        // Each work card should land in document order, not just the
        // first one. The previous body extractor stopped at the
        // `am__share-buttons` sentinel which feature articles omit, so
        // the body came back empty and only the seed (hero + title)
        // rendered. With balanced `<article>` matching the renderer
        // gets all three cards back from this fixture.
        let workIDs = parsed.blocks.compactMap { block -> Int? in
            if case .work(let w) = block { return w.artworkID } else { return nil }
        }
        #expect(workIDs == [101, 102, 103])

        // Feature-style heading + paragraph wrappers (`article-item
        // _feature-article-body__heading|paragraph`) need to render as
        // .heading and .paragraph blocks even though the inner markup
        // uses <div> wrappers instead of bare <h3>/<p> tags.
        let headingTexts = parsed.blocks.compactMap { block -> String? in
            if case .heading(let t) = block { return t } else { return nil }
        }
        let paragraphTexts = parsed.blocks.compactMap { block -> String? in
            if case .paragraph(let t) = block { return t } else { return nil }
        }
        #expect(headingTexts.contains("Section A"))
        #expect(paragraphTexts.contains { $0.contains("Caption alpha") })
        #expect(paragraphTexts.contains { $0.contains("Caption beta") })
    }

    @Test("Related-articles shelves parse with kind, heading, cards, and view-more URL")
    func parsesRelatedArticleShelves() {
        let parsed = PixivisionArticleParser.parse(
            html: Self.featureArticleHTML,
            articleID: 10338,
            sourceURL: URL(string: "https://www.pixivision.net/zh/a/10338")!
        )

        // The fixture ships three shelves matching the live Pixivision
        // structure: tag latest, tag popular, category latest. Each
        // should land with its own kind, heading, and cards.
        #expect(parsed.relatedSections.count == 3)
        #expect(parsed.relatedSections.map(\.kind) == [.tagLatest, .tagPopular, .categoryLatest])

        let tagLatest = parsed.relatedSections[0]
        #expect(tagLatest.heading?.contains("最新") == true)
        #expect(tagLatest.articles.count == 2)
        #expect(tagLatest.articles[0].articleID == 11556)
        #expect(tagLatest.articles[0].coverURL?.absoluteString.contains("133650043") == true)
        #expect(tagLatest.viewMoreURL?.absoluteString.contains("/zh/t/255") == true)

        let tagPopular = parsed.relatedSections[1]
        #expect(tagPopular.heading?.contains("喜欢") == true)
        #expect(tagPopular.articles.map(\.articleID) == [11600])

        let categoryLatest = parsed.relatedSections[2]
        #expect(categoryLatest.kind == .categoryLatest)
        #expect(categoryLatest.articles.map(\.articleID) == [11700])
        #expect(categoryLatest.viewMoreURL?.absoluteString.contains("/zh/c/illustration") == true)

        // Empty shelves should be filtered out (a shelf with zero
        // cards isn't useful to the reader).
        let emptyShelfHTML = """
        <html><body>
        <article class="am__article-body-container"></article>
        <div class="_related-articles" data-gtm-category="Article Latest">
        <h3 class="rla__heading">Empty heading</h3>
        <ul class="_article-related-card-test-list"></ul>
        </div>
        </body></html>
        """
        let emptyParsed = PixivisionArticleParser.parse(
            html: emptyShelfHTML,
            articleID: 1,
            sourceURL: URL(string: "https://www.pixivision.net/zh/a/1")!
        )
        #expect(emptyParsed.relatedSections.isEmpty)
    }

    @Test("Related-shelves nested inside the article body don't double-render their headings")
    func stripsRelatedShelvesFromBodyBlocks() {
        // Pixivision occasionally renders the first one or two
        // related-articles shelves *inside* the
        // `am__article-body-container` wrapper instead of below it.
        // Their `<h3 class="rla__heading">` looks identical to a body
        // heading to the prose scanner, so without the strip step the
        // shelf headings ("XX相关最新文章" / "喜欢XX的人也喜欢这些")
        // render twice — once as bare text in the prose flow, then
        // again as the headers of `RelatedArticlesShelf`.
        var html = """
        <html><body>
        <article class="am__article-body-container">
        <p>Body paragraph.</p>
        <div class="_related-articles" data-gtm-category="Related Article Latest">
        <h3 class="rla__heading yellow"><a href="/zh/t/255">腿部相关最新文章</a></h3>
        <ul class="_article-related-card-test-list">
        <li class="arrctl__list-item"><article>
        <a href="/zh/a/12345" class="arrct__thumbnail-container">
        <div class="_thumbnail"><img class="thm__image" src="https://example.com/cover.jpg" alt="cover"></div>
        </a>
        <div class="arrct__title-container">
        <h4 class="arrct__title"><a href="/zh/a/12345">A nested shelf article</a></h4>
        </div></article></li>
        </ul></div>
        </article>
        </body></html>
        """
        let parsed = PixivisionArticleParser.parse(
            html: html,
            articleID: 1,
            sourceURL: URL(string: "https://www.pixivision.net/zh/a/1")!
        )

        // The body should yield exactly one paragraph block — the
        // shelf heading must not bleed into prose.
        let headingTexts = parsed.blocks.compactMap { block -> String? in
            if case .heading(let t) = block { return t } else { return nil }
        }
        let paragraphTexts = parsed.blocks.compactMap { block -> String? in
            if case .paragraph(let t) = block { return t } else { return nil }
        }
        #expect(paragraphTexts == ["Body paragraph."])
        #expect(headingTexts.contains("腿部相关最新文章") == false)
        #expect(headingTexts.contains("A nested shelf article") == false)

        // The shelf still surfaces in `relatedSections` exactly once.
        #expect(parsed.relatedSections.count == 1)
        #expect(parsed.relatedSections.first?.heading == "腿部相关最新文章")
        #expect(parsed.relatedSections.first?.articles.first?.articleID == 12345)
    }

    // MARK: - Fixtures

    /// Trimmed, real-world Pixivision article HTML with one heading,
    /// one paragraph, one work card, and one trailing paragraph,
    /// followed by the share-buttons sentinel that closes the body.
    private static let sampleHTML = """
    <html><head>
    <meta property="og:title" content="Illustrator MON straddles the line between eeriness and beauty with their art">
    <meta property="og:description" content="Illustrator MON's first solo exhibition.">
    <meta property="og:image" content="https://embed.pixiv.net/pixivision/en/a/9988/ogimage.jpg">
    </head><body>
    <a class="_category type-bg-color" href="/en/c/interview">Interviews</a>
    <time class="_date am__sub-info__date large light-gray">2024.07.10</time>
    <h1 class="am__title">Illustrator MON straddles the line</h1>
    <div class="am__eyecatch-container"><div class="_article-illust-eyecatch">
    <img class="aie__image" src="https://embed.pixiv.net/pixivision/en/a/9988/ogimage.jpg" alt="MON"></div></div>
    <ul class="am__header-tags _tag-list">
    <li><a href="/en/t/71" class="_tag">interview</a></li>
    <li><a href="/en/t/149" class="_tag">illustrator interviews</a></li>
    </ul>
    <section class="am__body"><article class="am__article-body-container">
    <h3 class="am__article-headline">Graduated from art school this spring, now a freelance illustrator</h3>
    <p>Illustrator MON's first solo exhibition, SIGNAL 414, is happening now until Wednesday, July 24th, 2024.</p>
    <div class="am__work"><div class="am__work__info">
    <a href="https://www.pixiv.net/users/25915682?utm_source=pixivision" class="am__work__user-icon-container inner-link" target="_blank">
    <div class="_clickable-image-container">
    <img src="https://i.pximg.net/user-profile/img/2020/01/19/21/49/01/16876892_avatar.jpg" class="am__work__uesr-icon">
    </div></a>
    <div class="am__work__title-container">
    <h3 class="am__work__title"><a href="https://www.pixiv.net/artworks/67323816?utm_source=pixivision" class="inner-link" target="_blank">Reaper</a></h3>
    <p class="am__work__user-name">by <a href="https://www.pixiv.net/users/25915682?utm_source=pixivision" class="author-img-container inner-link" target="_blank">MON</a></p>
    </div></div>
    <div class="am__work__main">
    <a href="https://www.pixiv.net/artworks/67323816?utm_source=pixivision" class="inner-link" target="_blank">
    <div class="_clickable-image-container fit-inner">
    <img src="https://i.pximg.net/c/768x1200_80/img-master/img/2018/02/17/19/40/29/67323816_p0_master1200.jpg" class="am__work__illust ">
    </div></a></div></div>
    <p>Final closing paragraph that wraps up the interview.</p>
    </article></section>
    <div class="am__share-buttons"></div>
    </body></html>
    """

    private static func workCardHTML(artworkID: Int, creatorID: Int, title: String, creator: String) -> String {
        """
        <div class="am__work"><div class="am__work__info">
        <a href="https://www.pixiv.net/users/\(creatorID)" class="am__work__user-icon-container inner-link" target="_blank">
        <img src="https://example.com/avatar.jpg" class="am__work__uesr-icon"></a>
        <div class="am__work__title-container">
        <h3 class="am__work__title"><a href="https://www.pixiv.net/artworks/\(artworkID)" class="inner-link" target="_blank">\(title)</a></h3>
        <p class="am__work__user-name">by <a href="https://www.pixiv.net/users/\(creatorID)" class="inner-link" target="_blank">\(creator)</a></p>
        </div></div>
        <div class="am__work__main">
        <a href="https://www.pixiv.net/artworks/\(artworkID)" class="inner-link" target="_blank">
        <img src="https://example.com/illust.jpg" class="am__work__illust ">
        </a></div></div>
        """
    }

    /// Mirror of a Pixivision feature article (`球体关节插画特辑`-style)
    /// where the body contains many work cards, each preceded by a
    /// feature-style heading + paragraph wrapper, and the body ends
    /// without an `am__share-buttons` block. We use synthetic IDs
    /// (101/102/103) so the assertions are stable regardless of which
    /// real article the parser was prototyped against.
    private static let featureArticleHTML: String = {
        var html = """
        <html><head>
        <meta property="og:title" content="球体关节插画特辑">
        <meta property="og:description" content="精彩特辑摘要。">
        <meta property="og:image" content="https://embed.pixiv.net/cover.jpg">
        </head><body>
        <a class="_category type-bg-color" href="/zh/c/illustration">插画</a>
        <time class="_date am__sub-info__date">2024.10.01</time>
        <h1 class="am__title">球体关节插画特辑</h1>
        <article class="am__article-body-container" data-gtm-category="Article">
        <header class="am__header">
        <ul class="am__header-tags _tag-list">
        <li><a href="/zh/t/100" class="_tag">人偶</a></li>
        <li><a href="/zh/t/101" class="_tag">球形关节</a></li>
        </ul>
        </header>
        <div class="article-item _feature-article-body__heading"><h3>Section A</h3></div>
        <div class="article-item _feature-article-body__paragraph">
        <div class="fab__paragraph _medium-editor-text"><div>Caption alpha — describes the next work.</div></div>
        </div>
        """
        html += workCardHTML(artworkID: 101, creatorID: 1001, title: "Alpha", creator: "Anon1")
        html += """

        <div class="article-item _feature-article-body__heading"><h3>Section B</h3></div>
        <div class="article-item _feature-article-body__paragraph">
        <div class="fab__paragraph _medium-editor-text"><div>Caption beta sits between two illustrations.</div></div>
        </div>
        """
        html += workCardHTML(artworkID: 102, creatorID: 1002, title: "Beta", creator: "Anon2")
        html += workCardHTML(artworkID: 103, creatorID: 1003, title: "Gamma", creator: "Anon3")
        html += """

        </article>
        <div class="_related-articles" data-gtm-category="Related Article Latest">
        <h3 class="rla__heading yellow"><a href="/zh/t/255" class="rla__heading-link"><span class="_article-heading-tag-name">腿部</span>相关最新文章</a></h3>
        <ul class="_article-related-card-test-list">
        <li class="arrctl__list-item"><article class="_article-related-card-test">
        <a href="/zh/a/11556" class="arrct__thumbnail-container">
        <div class="_thumbnail"><img class="thm__image" src="https://i.pximg.net/c/1200x630/img-original/img/2025/08/09/01/36/52/133650043_p0.jpg" alt="柔美的曲线 - 大腿插画特辑 -" loading="lazy"></div>
        </a>
        <div class="arrct__title-container">
        <h4 class="arrct__title"><a href="/zh/a/11556">柔美的曲线 - 大腿插画特辑 -</a></h4>
        </div></article></li>
        <li class="arrctl__list-item"><article class="_article-related-card-test">
        <a href="/zh/a/11600" class="arrct__thumbnail-container">
        <div class="_thumbnail"><img class="thm__image" src="https://i.pximg.net/cover2.jpg" alt="cover2"></div>
        </a>
        <div class="arrct__title-container">
        <h4 class="arrct__title"><a href="/zh/a/11600">第二个相关文章</a></h4>
        </div></article></li>
        </ul>
        <div class="rla__more-container"><span class="rla__more"><a href="/zh/t/255" class="rla__more__link">查看更多▶︎</a></span></div>
        </div>

        <div class="_related-articles" data-gtm-category="Related Article Popular">
        <h3 class="rla__heading yellow"><a href="/zh/t/255" class="rla__heading-link">喜欢<span class="_article-heading-tag-name">腿部</span>的人也喜欢这些</a></h3>
        <ul class="_article-related-card-test-list">
        <li class="arrctl__list-item"><article class="_article-related-card-test">
        <a href="/zh/a/11600" class="arrct__thumbnail-container">
        <div class="_thumbnail"><img class="thm__image" src="https://i.pximg.net/cover3.jpg" alt="cover3"></div>
        </a>
        <div class="arrct__title-container">
        <h4 class="arrct__title"><a href="/zh/a/11600">人气文章</a></h4>
        </div></article></li>
        </ul>
        </div>

        <div class="_related-articles" data-gtm-category="Article Latest">
        <h3 class="rla__heading spotlight"><a href="/zh/c/illustration">插画相关最新文章</a></h3>
        <ul class="_article-related-card-test-list">
        <li class="arrctl__list-item"><article class="_article-related-card-test">
        <a href="/zh/a/11700" class="arrct__thumbnail-container">
        <div class="_thumbnail"><img class="thm__image" src="https://i.pximg.net/cover4.jpg" alt="cover4"></div>
        </a>
        <div class="arrct__title-container">
        <h4 class="arrct__title"><a href="/zh/a/11700">分类最新</a></h4>
        </div></article></li>
        </ul>
        <div class="rla__more-container"><span class="rla__more"><a href="/zh/c/illustration" class="rla__more__link">查看更多▶︎</a></span></div>
        </div>

        <div class="am__footer"></div>
        </body></html>
        """
        return html
    }()
}

