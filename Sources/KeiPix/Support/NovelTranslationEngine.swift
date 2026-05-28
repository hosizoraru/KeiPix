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

    /// Store translation results for a page.
    func applyResults(_ results: [Int: String], for pageIndex: Int) {
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
    func setTranslating(pageIndex: Int) {
        translatingPageIndex = pageIndex
        state = .translating
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
