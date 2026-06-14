import Testing
#if canImport(Translation)
@preconcurrency import Translation
#endif
@testable import KeiPix

@Suite("Novel translation readiness")
struct NovelTranslationReadinessTests {
    #if canImport(Translation)
    @Test("Language availability status maps to reader preparation decisions")
    func availabilityStatusMapsToPreparationDecision() {
        #expect(NovelTranslationReadinessMapper.readiness(for: .installed) == .ready)
        #expect(NovelTranslationReadinessMapper.readiness(for: .supported) == .requiresPreparation)
        #expect(NovelTranslationReadinessMapper.readiness(for: .unsupported) == .unavailable(.unsupportedLanguagePair))
    }

    @Test("Translation errors map to user visible reader issues")
    func translationErrorsMapToReaderIssues() {
        #expect(NovelTranslationReadinessMapper.issue(for: TranslationError.unsupportedSourceLanguage) == .unsupportedSourceLanguage)
        #expect(NovelTranslationReadinessMapper.issue(for: TranslationError.unsupportedTargetLanguage) == .unsupportedTargetLanguage)
        #expect(NovelTranslationReadinessMapper.issue(for: TranslationError.unsupportedLanguagePairing) == .unsupportedLanguagePair)
        #expect(NovelTranslationReadinessMapper.issue(for: TranslationError.unableToIdentifyLanguage) == .unableToIdentifyLanguage)
        #expect(NovelTranslationReadinessMapper.issue(for: TranslationError.nothingToTranslate) == .nothingToTranslate)
        #expect(NovelTranslationReadinessMapper.issue(for: CancellationError()) == .cancelled)

        if #available(macOS 26.0, iOS 26.0, *) {
            #expect(NovelTranslationReadinessMapper.issue(for: TranslationError.notInstalled) == .modelNotInstalled)
            #expect(NovelTranslationReadinessMapper.issue(for: TranslationError.alreadyCancelled) == .cancelled)
        }
    }
    #endif

    @Test("Reader issues expose localized user messages")
    func readerIssuesExposeLocalizedMessages() {
        #expect(NovelTranslationIssue.unsupportedLanguagePair.localizedMessage == L10n.novelTranslationUnsupportedLanguagePair)
        #expect(NovelTranslationIssue.unableToIdentifyLanguage.localizedMessage == L10n.novelTranslationCannotIdentifyLanguage)
        #expect(NovelTranslationIssue.modelNotInstalled.localizedMessage == L10n.novelTranslationModelNotInstalled)
        #expect(NovelTranslationIssue.cancelled.localizedMessage == L10n.novelTranslationCancelled)
        #expect(NovelTranslationIssue.unavailable.localizedMessage == L10n.translationFailed)
    }

    @Test("Readiness sampling skips terse headings when body text is available")
    func readinessSamplingSkipsTerseHeadings() {
        let segments = [
            segment(page: 0, token: 0, paragraph: 0, text: "雨の図書室"),
            segment(page: 0, token: 1, paragraph: 0, text: "雨の日の図書室は、ページをめくる音だけがやさしく響いていた。")
        ]

        #expect(NovelTranslationReadinessSampler.sampleSegment(from: segments)?.sourceText == segments[1].sourceText)
    }

    @Test("Readiness sampling falls back when every pending segment is short")
    func readinessSamplingFallsBackForShortSegments() {
        let segments = [
            segment(page: 0, token: 0, paragraph: 0, text: "序"),
            segment(page: 0, token: 1, paragraph: 0, text: "ok")
        ]

        #expect(NovelTranslationReadinessSampler.sampleSegment(from: segments)?.sourceText == "序")
    }

    @Test("Request policy falls back terse segments without blocking body translation")
    func requestPolicyFallsBackTerseSegments() {
        let heading = segment(page: 0, token: 0, paragraph: 0, text: "雨の図書室")
        let body = segment(page: 0, token: 1, paragraph: 0, text: "雨の日の図書室は、ページをめくる音だけがやさしく響いていた。")
        let segments = [heading, body]

        #expect(NovelTranslationRequestPolicy.requestableSegments(from: segments) == [body])
        #expect(NovelTranslationRequestPolicy.localFallbackResults(from: segments) == [
            NovelTranslationBatchResult(segment: heading, translatedText: heading.sourceText)
        ])
    }

    private func segment(page: Int, token: Int, paragraph: Int, text: String) -> NovelTranslationSegment {
        NovelTranslationSegment(
            novelID: 1,
            targetLanguageID: "en",
            pageIndex: page,
            tokenIndex: token,
            paragraphIndex: paragraph,
            sourceText: text,
            sourceHash: "\(page)-\(token)-\(paragraph)",
            clientIdentifier: "\(page)-\(token)-\(paragraph)"
        )
    }
}
