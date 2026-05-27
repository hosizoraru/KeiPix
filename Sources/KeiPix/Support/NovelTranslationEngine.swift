import Foundation

/// Coordinates inline translation for the novel reader.
///
/// Uses Apple's `TranslationSession` (macOS 14+) to translate
/// paragraphs on the current page. The system handles language
/// detection and remembers the user's target language.
///
/// The engine is `@Observable` so SwiftUI can bind directly to
/// `state` and `translatedParagraphs` for reactive re-rendering.
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
    /// Maps token index to translated text.
    private(set) var translatedParagraphs: [Int: String] = [:]

    /// Whether inline translation overlay is active. Toggling this
    /// triggers the `.translationTask` modifier on the reader view.
    var isInlineTranslationActive: Bool = false

    func setTranslating() {
        state = .translating
    }

    /// Applies batch translation results from the view's
    /// `.translationTask` closure.
    func applyResults(_ results: [Int: String]) {
        translatedParagraphs = results
        state = results.isEmpty ? .error("No translations") : .completed
    }

    /// Returns translated text for a given token index, or nil.
    func translatedText(for tokenIndex: Int) -> String? {
        translatedParagraphs[tokenIndex]
    }

    /// Clears translations when navigating to a new page.
    func clearTranslations() {
        translatedParagraphs = [:]
        state = .idle
    }

    /// Fully resets including the toggle.
    func reset() {
        translatedParagraphs = [:]
        state = .idle
        isInlineTranslationActive = false
    }
}
