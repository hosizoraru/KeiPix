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
}
