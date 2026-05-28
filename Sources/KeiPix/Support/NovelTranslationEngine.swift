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
        pageTranslations[pageIndex]?[tokenIndex]
    }

    /// Whether a specific page has cached translations.
    func hasTranslation(for pageIndex: Int) -> Bool {
        pageTranslations[pageIndex]?.isEmpty == false
    }

    /// Whether a specific page is currently being translated.
    func isTranslating(pageIndex: Int) -> Bool {
        translatingPageIndex == pageIndex && state == .translating
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

    /// Mark a page as currently being translated.
    func setTranslating(pageIndex: Int, total: Int) {
        translatingPageIndex = pageIndex
        state = .translating
        translationTotal = total
        translationCompleted = 0
        translationProgress = 0
    }

    /// Clear translations for a specific page (e.g., on re-translate).
    func clearPage(_ pageIndex: Int) {
        pageTranslations.removeValue(forKey: pageIndex)
    }

    /// Clear all cached translations (e.g., on novel change).
    func clearAll() {
        pageTranslations = [:]
        translatingPageIndex = nil
        state = .idle
    }

    /// Fully resets including the toggle.
    func reset() {
        pageTranslations = [:]
        translatingPageIndex = nil
        state = .idle
        isInlineTranslationActive = false
    }
}
