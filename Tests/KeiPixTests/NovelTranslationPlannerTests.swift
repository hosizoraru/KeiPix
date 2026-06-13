import Testing
#if canImport(Translation)
@preconcurrency import Translation
#endif
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

    #if canImport(Translation)
    @Test("Batch requests carry source text and stable client identifiers")
    func batchRequestsCarrySegmentIdentity() {
        let segments = NovelTranslationPlanner.segments(
            novelID: 5,
            targetLanguageID: "en",
            pages: [[.text("一段落目。\n\n二段落目。")]]
        )

        let requests = NovelTranslationBatchMapper.requests(from: segments)

        #expect(requests.map(\.sourceText) == ["一段落目。", "二段落目。"])
        #expect(requests.map(\.clientIdentifier) == segments.map(\.clientIdentifier))
    }

    @Test("Translation configuration prefers low latency when the OS supports strategies")
    func translationConfigurationPrefersLowLatency() {
        if #available(macOS 26.4, iOS 26.4, *) {
            let configuration = TranslationLanguageResolver.configuration(for: .english)

            #expect(configuration.target == TranslationTargetLanguage.english.localeLanguage)
            #expect(configuration.preferredStrategy == .lowLatency)
        }
    }

    @Test("Batch requests mark Pixiv inline markers and URLs to skip translation")
    func batchRequestsMarkPixivMarkersAndURLsToSkipTranslation() throws {
        guard #available(macOS 26.4, iOS 26.4, *) else { return }
        let source = "本文 https://www.pixiv.net/novel/show.php?id=42 [pixivimage:123-1] [[rb:漢字 > かんじ]]"
        let segment = NovelTranslationSegment(
            novelID: 5,
            targetLanguageID: "en",
            pageIndex: 0,
            tokenIndex: 0,
            paragraphIndex: 0,
            sourceText: source,
            sourceHash: "hash",
            clientIdentifier: "segment-1"
        )

        let request = try #require(NovelTranslationBatchMapper.requests(from: [segment]).first)
        let attributed = try #require(request.attributedSourceText)
        let skippedTexts = attributed.runs.compactMap { run -> String? in
            guard run.translation.skipsTranslation == true else { return nil }
            return String(attributed.characters[run.range])
        }

        #expect(request.clientIdentifier == segment.clientIdentifier)
        #expect(request.sourceText == source)
        #expect(skippedTexts.contains("https://www.pixiv.net/novel/show.php?id=42"))
        #expect(skippedTexts.contains("[pixivimage:123-1]"))
        #expect(skippedTexts.contains("[[rb:漢字 > かんじ]]"))
    }
    #endif

    @Test("Batch response mapping ignores missing and unknown client identifiers")
    func batchResponseMappingIgnoresUnknownIdentifiers() {
        let segments = NovelTranslationPlanner.segments(
            novelID: 5,
            targetLanguageID: "en",
            pages: [[.text("本文。")]]
        )
        let index = NovelTranslationBatchMapper.segmentIndex(segments)

        let missing = NovelTranslationBatchMapper.result(
            clientIdentifier: nil,
            translatedText: "ignored",
            segmentsByClientIdentifier: index
        )
        let unknown = NovelTranslationBatchMapper.result(
            clientIdentifier: "not-from-this-batch",
            translatedText: "ignored",
            segmentsByClientIdentifier: index
        )
        let mapped = NovelTranslationBatchMapper.result(
            clientIdentifier: segments[0].clientIdentifier,
            translatedText: "Translated.",
            segmentsByClientIdentifier: index
        )

        #expect(missing == nil)
        #expect(unknown == nil)
        #expect(mapped?.segment == segments[0])
        #expect(mapped?.translatedText == "Translated.")
    }

    @Test("Batch client closure streams mapped results without prescribing response order")
    func batchClientClosureStreamsMappedResults() async throws {
        let segments = NovelTranslationPlanner.segments(
            novelID: 5,
            targetLanguageID: "en",
            pages: [[.text("一段落目。\n\n二段落目。")]]
        )
        let client = NovelTranslationBatchClient { segments, yield in
            for segment in segments.reversed() {
                yield(
                    NovelTranslationBatchResult(
                        segment: segment,
                        translatedText: "translated-\(segment.paragraphIndex)"
                    )
                )
            }
        }

        var results: [NovelTranslationBatchResult] = []
        try await client.translate(segments) { result in
            results.append(result)
        }

        #expect(results.map(\.segment.paragraphIndex) == [1, 0])
        #expect(Set(results.map(\.segment.clientIdentifier)) == Set(segments.map(\.clientIdentifier)))
    }
}
