import Testing
@testable import KeiPix

@Suite("Novel export formatter")
struct NovelExportFormatterTests {
    @Test("HTML export escapes metadata and preserves novel inline tags")
    func htmlExportEscapesMetadataAndPreservesInlineTags() {
        let text = PixivNovelText(
            novelMarker: nil,
            novelText: "[chapter: Opening <Act>]\nHello <world>\n[[rb:漢字 > かんじ]]\n[[jumpuri:Pixiv > https://www.pixiv.net]]\n[pixivimage:12345]\n[newpage]\nAfter",
            seriesPrev: nil,
            seriesNext: nil
        )

        let html = NovelExportFormatter.build(
            format: .html,
            text: text,
            title: "Title <One>",
            authorName: "Author & Co.",
            novelID: 42
        )

        #expect(html.contains("<!doctype html>"))
        #expect(html.contains("<title>Title &lt;One&gt;</title>"))
        #expect(html.contains("<h1>Title &lt;One&gt;</h1>"))
        #expect(html.contains("<p class=\"novel-author\">Author &amp; Co.</p>"))
        #expect(html.contains("<h2 id=\"chapter-1\">Opening &lt;Act&gt;</h2>"))
        #expect(html.contains("<p>Hello &lt;world&gt;</p>"))
        #expect(html.contains("<ruby>漢字<rt>かんじ</rt></ruby>"))
        #expect(html.contains("<a href=\"https://www.pixiv.net\">Pixiv</a>"))
        #expect(html.contains("<a href=\"https://www.pixiv.net/artworks/12345\">illust:12345</a>"))
        #expect(html.contains("<hr class=\"page-break\">"))
    }

    @Test("TXT and Markdown exports keep their existing surface formats")
    func textAndMarkdownExportsKeepExistingFormats() {
        let text = PixivNovelText(
            novelMarker: nil,
            novelText: "[chapter:Start]Body\n[[jumpuri:Pixiv > https://www.pixiv.net]]",
            seriesPrev: nil,
            seriesNext: nil
        )

        let txt = NovelExportFormatter.build(
            format: .txt,
            text: text,
            title: "Title",
            authorName: "Author",
            novelID: 42
        )
        let markdown = NovelExportFormatter.build(
            format: .markdown,
            text: text,
            title: "Title",
            authorName: "Author",
            novelID: 42
        )

        #expect(txt.contains("Title\nAuthor\n----------------------------------------"))
        #expect(txt.contains("## Start"))
        #expect(txt.contains("[Pixiv](https://www.pixiv.net)"))
        #expect(markdown.contains("# Title"))
        #expect(markdown.contains("**Author**"))
        #expect(markdown.contains("## Start"))
        #expect(markdown.contains("[Pixiv](https://www.pixiv.net)"))
    }
}
