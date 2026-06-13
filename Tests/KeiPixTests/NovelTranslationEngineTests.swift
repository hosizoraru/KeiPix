import Testing
@testable import KeiPix

@Suite("Novel translation engine")
struct NovelTranslationEngineTests {
    @Test("Segment results apply incrementally with readable fallback text")
    @MainActor
    func segmentResultsApplyIncrementally() {
        let segments = NovelTranslationPlanner.segments(
            novelID: 11,
            targetLanguageID: "en",
            pages: [[.text("一段落目。\n\n二段落目。")]]
        )
        let engine = NovelTranslationEngine()

        engine.registerSegments(segments)
        engine.setTranslating(segments: segments)
        engine.applySegmentResult(
            NovelTranslationBatchResult(
                segment: segments[0],
                translatedText: "First paragraph."
            )
        )

        #expect(engine.translationCompleted == 1)
        #expect(engine.translationTotal == 2)
        #expect(engine.translationProgress == 0.5)
        #expect(engine.translatedText(pageIndex: 0, tokenIndex: 0) == "First paragraph.\n\n二段落目。")

        engine.applySegmentResult(
            NovelTranslationBatchResult(
                segment: segments[1],
                translatedText: "Second paragraph."
            )
        )
        engine.finishTranslating(segments: segments)

        #expect(engine.translationCompleted == 0)
        #expect(engine.translationTotal == 0)
        #expect(engine.translationProgress == 0)
        #expect(engine.translatedText(pageIndex: 0, tokenIndex: 0) == "First paragraph.\n\nSecond paragraph.")
        #expect(engine.hasTranslation(for: 0))
    }

    @Test("Missing segment responses stay pending so a later pass can retry them")
    @MainActor
    func missingSegmentResponsesStayPending() {
        let segments = NovelTranslationPlanner.segments(
            novelID: 11,
            targetLanguageID: "en",
            pages: [[.text("一段落目。\n\n二段落目。")]]
        )
        let engine = NovelTranslationEngine()

        engine.registerSegments(segments)
        engine.applySegmentResult(
            NovelTranslationBatchResult(
                segment: segments[0],
                translatedText: "First paragraph."
            )
        )

        #expect(engine.pendingSegments(from: segments) == [segments[1]])
        #expect(engine.hasTranslation(for: 0) == false)
    }

    @Test("Mode switching keeps partial segment fallbacks readable")
    @MainActor
    func modeSwitchingKeepsPartialFallbacksReadable() {
        let segments = NovelTranslationPlanner.segments(
            novelID: 11,
            targetLanguageID: "en",
            pages: [[.text("一段落目。\n\n二段落目。")]]
        )
        let engine = NovelTranslationEngine()

        engine.translationMode = .bilingual
        engine.registerSegments(segments)
        engine.setTranslating(segments: segments)
        engine.applySegmentResult(
            NovelTranslationBatchResult(
                segment: segments[0],
                translatedText: "First paragraph."
            )
        )
        #expect(engine.translatedText(pageIndex: 0, tokenIndex: 0) == "First paragraph.\n\n二段落目。")

        engine.translationMode = .immersive

        #expect(engine.translatedText(pageIndex: 0, tokenIndex: 0) == "First paragraph.\n\n二段落目。")
        #expect(engine.pendingSegments(from: segments) == [segments[1]])
    }
}
