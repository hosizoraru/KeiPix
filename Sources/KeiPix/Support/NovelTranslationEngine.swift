import Foundation

/// Translation display mode.
enum NovelTranslationMode: String, CaseIterable, Identifiable {
    /// Show original + translation together (bilingual).
    case bilingual
    /// Replace original with translation (immersive).
    case immersive

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .bilingual: return "character.bubble"
        case .immersive: return "text.book.closed"
        }
    }

    var title: String {
        switch self {
        case .bilingual: return L10n.novelTranslateBilingual
        case .immersive: return L10n.novelTranslateImmersive
        }
    }

    var helpText: String {
        switch self {
        case .bilingual: return L10n.novelTranslateBilingualHelp
        case .immersive: return L10n.novelTranslateImmersiveHelp
        }
    }
}

/// Coordinates inline translation for the novel reader.
///
/// Supports two modes:
/// - **Bilingual**: original + translated text shown together
/// - **Immersive**: translated text replaces original
///
/// Translations are cached per page so navigating between pages
/// doesn't re-translate already-seen content.
@MainActor
@Observable
final class NovelTranslationEngine {
    enum State: Equatable {
        case idle
        case translating
        case completed
        case error(String)
    }

    private(set) var state: State = .idle

    /// Current translation display mode.
    var translationMode: NovelTranslationMode = .bilingual

    /// Whether inline translation overlay is active.
    var isInlineTranslationActive: Bool = false

    /// Per-page translation cache. Key is page index, value maps
    /// token index → translated text within that page.
    private(set) var pageTranslations: [Int: [Int: String]] = [:]

    /// Per-segment translation cache keyed by `NovelTranslationSegment.clientIdentifier`.
    private(set) var segmentTranslations: [String: String] = [:]

    private struct TokenKey: Hashable {
        let pageIndex: Int
        let tokenIndex: Int
    }

    private var plannedSegmentsByToken: [TokenKey: [NovelTranslationSegment]] = [:]
    private var translatingPageIndices: Set<Int> = []
    private var activeSegmentIdentifiers: Set<String> = []

    /// Which page is currently being translated.
    private(set) var translatingPageIndex: Int?

    /// Translation progress for the current page (0.0 – 1.0).
    private(set) var translationProgress: Double = 0

    /// Total paragraphs being translated on the current page.
    private(set) var translationTotal: Int = 0

    /// How many paragraphs have been translated so far.
    private(set) var translationCompleted: Int = 0

    /// Returns translated text for a given page and token index.
    func translatedText(pageIndex: Int, tokenIndex: Int) -> String? {
        if let legacyTranslation = pageTranslations[pageIndex]?[tokenIndex] {
            return legacyTranslation
        }

        let key = TokenKey(pageIndex: pageIndex, tokenIndex: tokenIndex)
        guard let segments = plannedSegmentsByToken[key], segments.isEmpty == false else {
            return nil
        }

        var hasTranslatedSegment = false
        let pieces = segments.map { segment in
            if let translated = segmentTranslations[segment.clientIdentifier] {
                hasTranslatedSegment = true
                return translated
            }
            return segment.sourceText
        }

        guard hasTranslatedSegment else { return nil }
        return pieces.joined(separator: "\n\n")
    }

    /// Whether a specific page has cached translations.
    func hasTranslation(for pageIndex: Int) -> Bool {
        if pageTranslations[pageIndex]?.isEmpty == false {
            return true
        }

        let pageSegments = plannedSegmentsByToken
            .filter { $0.key.pageIndex == pageIndex }
            .flatMap(\.value)
        guard pageSegments.isEmpty == false else { return false }
        return pageSegments.allSatisfy { segmentTranslations[$0.clientIdentifier] != nil }
    }

    /// Whether a specific page is currently being translated.
    func isTranslating(pageIndex: Int) -> Bool {
        (translatingPageIndex == pageIndex || translatingPageIndices.contains(pageIndex)) && state == .translating
    }

    /// Update progress during translation.
    func updateProgress(completed: Int, total: Int) {
        translationCompleted = completed
        translationTotal = total
        translationProgress = total > 0 ? Double(completed) / Double(total) : 0
    }

    /// Store translation results for a page.
    func applyResults(_ results: [Int: String], for pageIndex: Int) {
        translationProgress = 0
        translationTotal = 0
        translationCompleted = 0
        if results.isEmpty {
            // Don't cache empty results — might be a transient failure.
            if translatingPageIndex == pageIndex {
                translatingPageIndex = nil
                state = .idle
            }
        } else {
            pageTranslations[pageIndex] = results
            if translatingPageIndex == pageIndex {
                translatingPageIndex = nil
                state = .completed
            }
        }
    }

    func registerSegments(_ segments: [NovelTranslationSegment]) {
        for segment in segments {
            let key = TokenKey(pageIndex: segment.pageIndex, tokenIndex: segment.tokenIndex)
            var tokenSegments = plannedSegmentsByToken[key, default: []]
            if tokenSegments.contains(where: { $0.clientIdentifier == segment.clientIdentifier }) == false {
                tokenSegments.append(segment)
                tokenSegments.sort { lhs, rhs in
                    if lhs.paragraphIndex == rhs.paragraphIndex {
                        return lhs.clientIdentifier < rhs.clientIdentifier
                    }
                    return lhs.paragraphIndex < rhs.paragraphIndex
                }
                plannedSegmentsByToken[key] = tokenSegments
            }
        }
    }

    func pendingSegments(from segments: [NovelTranslationSegment]) -> [NovelTranslationSegment] {
        segments.filter { segmentTranslations[$0.clientIdentifier] == nil }
    }

    func applySegmentResult(_ result: NovelTranslationBatchResult) {
        registerSegments([result.segment])
        segmentTranslations[result.segment.clientIdentifier] = result.translatedText
        updateActiveSegmentProgress()
    }

    func finishTranslating(segments: [NovelTranslationSegment]) {
        registerSegments(segments)
        for pageIndex in Set(segments.map(\.pageIndex)) {
            translatingPageIndices.remove(pageIndex)
        }
        if translatingPageIndices.isEmpty {
            translatingPageIndex = nil
        } else {
            translatingPageIndex = translatingPageIndices.min()
        }
        activeSegmentIdentifiers.subtract(segments.map(\.clientIdentifier))
        translationProgress = 0
        translationTotal = 0
        translationCompleted = 0
        state = pendingSegments(from: segments).isEmpty ? .completed : .idle
    }

    func failTranslating(_ message: String, segments: [NovelTranslationSegment]) {
        for pageIndex in Set(segments.map(\.pageIndex)) {
            translatingPageIndices.remove(pageIndex)
        }
        translatingPageIndex = translatingPageIndices.min()
        activeSegmentIdentifiers.subtract(segments.map(\.clientIdentifier))
        translationProgress = 0
        translationTotal = 0
        translationCompleted = 0
        state = .error(message)
    }

    /// Mark a page as currently being translated.
    func setTranslating(pageIndex: Int, total: Int) {
        translatingPageIndex = pageIndex
        translatingPageIndices = [pageIndex]
        activeSegmentIdentifiers = []
        state = .translating
        translationTotal = total
        translationCompleted = 0
        translationProgress = 0
    }

    func setTranslating(segments: [NovelTranslationSegment]) {
        registerSegments(segments)
        let pending = pendingSegments(from: segments)
        translatingPageIndices.formUnion(pending.map(\.pageIndex))
        translatingPageIndex = translatingPageIndices.min()
        activeSegmentIdentifiers.formUnion(pending.map(\.clientIdentifier))
        state = pending.isEmpty ? .completed : .translating
        translationTotal = pending.count
        translationCompleted = 0
        translationProgress = 0
    }

    /// Clear translations for a specific page (e.g., on re-translate).
    func clearPage(_ pageIndex: Int) {
        pageTranslations.removeValue(forKey: pageIndex)
        let keys = plannedSegmentsByToken.keys.filter { $0.pageIndex == pageIndex }
        let identifiers = keys.flatMap { plannedSegmentsByToken[$0, default: []].map(\.clientIdentifier) }
        for key in keys {
            plannedSegmentsByToken.removeValue(forKey: key)
        }
        for identifier in identifiers {
            segmentTranslations.removeValue(forKey: identifier)
            activeSegmentIdentifiers.remove(identifier)
        }
        translatingPageIndices.remove(pageIndex)
    }

    /// Clear all cached translations (e.g., on novel change).
    func clearAll() {
        pageTranslations = [:]
        segmentTranslations = [:]
        plannedSegmentsByToken = [:]
        translatingPageIndices = []
        activeSegmentIdentifiers = []
        translatingPageIndex = nil
        state = .idle
    }

    /// Fully resets including the toggle.
    func reset() {
        pageTranslations = [:]
        segmentTranslations = [:]
        plannedSegmentsByToken = [:]
        translatingPageIndices = []
        activeSegmentIdentifiers = []
        translatingPageIndex = nil
        state = .idle
        isInlineTranslationActive = false
    }

    private func updateActiveSegmentProgress() {
        guard activeSegmentIdentifiers.isEmpty == false else { return }
        let completed = activeSegmentIdentifiers.filter { segmentTranslations[$0] != nil }.count
        updateProgress(completed: completed, total: activeSegmentIdentifiers.count)
    }
}
