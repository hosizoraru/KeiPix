import Testing
@testable import KeiPix

@Suite("Novel translation planner")
struct NovelTranslationPlannerTests {
    @Test("Planner captures simple page text as stable translation segments")
    func simplePagesBecomeSegments() {
        let pages: [[NovelToken]] = [
            [.text("最初の段落。\n\nSecond paragraph.")],
            [.text("Third page paragraph.")]
        ]

        let segments = NovelTranslationPlanner.segments(
            novelID: 42,
            targetLanguageID: "zh-Hans",
            pages: pages
        )

        #expect(segments.map(\.sourceText) == [
            "最初の段落。",
            "Second paragraph.",
            "Third page paragraph."
        ])
        #expect(segments.map(\.pageIndex) == [0, 0, 1])
        #expect(segments.map(\.tokenIndex) == [0, 0, 0])
        #expect(segments.map(\.paragraphIndex) == [0, 1, 0])
        #expect(Set(segments.map(\.clientIdentifier)).count == 3)
        #expect(segments.allSatisfy { $0.clientIdentifier.contains("novel-42") })
        #expect(segments.allSatisfy { $0.clientIdentifier.contains("target-zh-Hans") })
        #expect(segments.allSatisfy { $0.sourceHash.isEmpty == false })
    }

    @Test("Planner skips non-text tokens and noisy paragraphs")
    func skipsNonTextAndNoisyParagraphs() {
        let pages: [[NovelToken]] = [
            [
                .chapter("Opening"),
                .text(" \n\n🐱🐱🐱\n\nok\n\n—\n\n本文として翻訳する。"),
                .pixivImage(illustID: 123, page: nil),
                .ruby(base: "漢字", reading: "かんじ"),
                .jumpPage(2)
            ]
        ]

        let segments = NovelTranslationPlanner.segments(
            novelID: 7,
            targetLanguageID: "system",
            pages: pages
        )

        #expect(segments.map(\.sourceText) == [
            "ok",
            "本文として翻訳する。"
        ])
        #expect(segments.map(\.paragraphIndex) == [2, 4])
        #expect(segments.allSatisfy { $0.pageIndex == 0 && $0.tokenIndex == 1 })
    }

    @Test("Client identifiers are stable and include source identity")
    func clientIdentifiersAreStableAndSourceAware() {
        let pages: [[NovelToken]] = [
            [.text("同じ本文。"), .text("同じ本文。")]
        ]

        let first = NovelTranslationPlanner.segments(
            novelID: 99,
            targetLanguageID: "en",
            pages: pages
        )
        let second = NovelTranslationPlanner.segments(
            novelID: 99,
            targetLanguageID: "en",
            pages: pages
        )

        #expect(first.map(\.clientIdentifier) == second.map(\.clientIdentifier))
        #expect(first.map(\.sourceHash) == second.map(\.sourceHash))
        #expect(first[0].sourceHash == first[1].sourceHash)
        #expect(first[0].clientIdentifier != first[1].clientIdentifier)
    }
}
