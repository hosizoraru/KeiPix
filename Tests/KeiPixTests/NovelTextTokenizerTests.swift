import Testing
@testable import KeiPix

@Suite("Novel text tokenizer")
struct NovelTextTokenizerTests {
    @Test("Plain text without tags emits a single text token")
    func plainTextSingleToken() {
        let tokens = NovelTextTokenizer.tokenize("Hello world\nNext line")
        #expect(tokens == [.text("Hello world\nNext line")])
    }

    @Test("[newpage] splits surrounding text into two text tokens")
    func newPageSplit() {
        let tokens = NovelTextTokenizer.tokenize("intro[newpage]rest")
        #expect(tokens == [
            .text("intro"),
            .newPage,
            .text("rest")
        ])
    }

    @Test("Chapter tag captures trimmed title")
    func chapterTagTrimmed() {
        let tokens = NovelTextTokenizer.tokenize("[chapter:  First Chapter ]body")
        #expect(tokens == [
            .chapter("First Chapter"),
            .text("body")
        ])
    }

    @Test("[pixivimage:id] without page leaves page nil")
    func pixivImageWithoutPage() {
        let tokens = NovelTextTokenizer.tokenize("[pixivimage:12345]")
        #expect(tokens == [.pixivImage(illustID: 12345, page: nil)])
    }

    @Test("[pixivimage:id-page] parses 1-based page suffix")
    func pixivImageWithPage() {
        let tokens = NovelTextTokenizer.tokenize("[pixivimage:42-3]")
        #expect(tokens == [.pixivImage(illustID: 42, page: 3)])
    }

    @Test("[uploadedimage:key] captures key verbatim")
    func uploadedImageCapturesKey() {
        let tokens = NovelTextTokenizer.tokenize("[uploadedimage:abc-123_xyz]")
        #expect(tokens == [.uploadedImage(key: "abc-123_xyz")])
    }

    @Test("[[jumpuri:label > url]] captures label and parsed URL")
    func jumpUriParsesLabelAndURL() {
        let tokens = NovelTextTokenizer.tokenize("[[jumpuri:Pixiv > https://www.pixiv.net]]")
        guard let only = tokens.first, tokens.count == 1 else {
            Issue.record("Expected single token, got \(tokens)")
            return
        }
        if case let .jumpURL(label, url) = only {
            #expect(label == "Pixiv")
            #expect(url.absoluteString == "https://www.pixiv.net")
        } else {
            Issue.record("Expected .jumpURL, got \(only)")
        }
    }

    @Test("[[rb:base > reading]] yields a ruby token")
    func rubyAnnotation() {
        let tokens = NovelTextTokenizer.tokenize("[[rb:漢字 > かんじ]]")
        #expect(tokens == [.ruby(base: "漢字", reading: "かんじ")])
    }

    @Test("[jump:N] yields a jumpPage token")
    func jumpPage() {
        let tokens = NovelTextTokenizer.tokenize("[jump:5]")
        #expect(tokens == [.jumpPage(5)])
    }

    @Test("Unknown bracket payloads survive as literal text")
    func unknownTagFallsThrough() {
        let tokens = NovelTextTokenizer.tokenize("[notatag:1]rest")
        #expect(tokens == [.text("[notatag:1]rest")])
    }

    @Test("Stray opening bracket without close survives as literal text")
    func unbalancedBracket() {
        let tokens = NovelTextTokenizer.tokenize("[oops")
        #expect(tokens == [.text("[oops")])
    }

    @Test("Mixed text + ruby + chapter retains order")
    func mixedTokensRetainOrder() {
        let source = "Prologue[chapter:1][[rb:漢 > かん]]end"
        let tokens = NovelTextTokenizer.tokenize(source)
        #expect(tokens == [
            .text("Prologue"),
            .chapter("1"),
            .ruby(base: "漢", reading: "かん"),
            .text("end")
        ])
    }

    @Test("Reader page splitter collapses empty pages from adjacent newpage markers")
    func readerSplitPagesCollapsesEmpty() {
        let tokens: [NovelToken] = [
            .text("a"),
            .newPage,
            .newPage,
            .text("b")
        ]
        let pages = NovelReaderView.splitPages(tokens)
        #expect(pages.count == 2)
        #expect(pages[0] == [.text("a")])
        #expect(pages[1] == [.text("b")])
    }

    @Test("Reader page splitter on token-less input returns empty")
    func readerSplitPagesEmpty() {
        let pages = NovelReaderView.splitPages([])
        #expect(pages.isEmpty)
    }

    @Test("Reader page splitter with no newpage returns single page")
    func readerSplitPagesSinglePage() {
        let tokens: [NovelToken] = [.text("only")]
        let pages = NovelReaderView.splitPages(tokens)
        #expect(pages == [[.text("only")]])
    }
}
