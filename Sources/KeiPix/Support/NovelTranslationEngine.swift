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

    /// Monotonic counter bumped on page change and toggle-off.
    /// The `.translationTask` closure captures this at start and
    /// checks it before calling `applyResults` to avoid stale
    /// results overwriting fresh ones.
    private(set) var generation: Int = 0

    func setTranslating() {
        state = .translating
    }

    /// Applies batch translation results if the generation is still
    /// current. Returns `true` if results were applied.
    @discardableResult
    func applyResults(_ results: [Int: String], generation: Int) -> Bool {
        guard generation == self.generation else { return false }
        translatedParagraphs = results
        state = results.isEmpty ? .error("No translations") : .completed
        return true
    }

    /// Returns translated text for a given token index, or nil.
    func translatedText(for tokenIndex: Int) -> String? {
        translatedParagraphs[tokenIndex]
    }

    /// Clears translations when navigating to a new page. Bumps
    /// generation so in-flight tasks abandon their results.
    func clearTranslations() {
        generation += 1
        translatedParagraphs = [:]
        state = .idle
    }

    /// Fully resets including the toggle.
    func reset() {
        generation += 1
        translatedParagraphs = [:]
        state = .idle
        isInlineTranslationActive = false
    }

    /// Bumps generation when the user toggles translation off,
    /// cancelling any in-flight work.
    func cancelInFlight() {
        generation += 1
    }
}
