import Foundation

/// Decides whether KeiPix should surface a "Translate" affordance for a
/// given piece of user-visible text. The actual translation work is
/// handled by Apple's `Translation` framework — this helper just gates
/// the button so we don't show a translate action that has nothing to
/// do (empty caption, single emoji, etc.).
///
/// Pulled out of the SwiftUI views so the rule is regression-testable
/// without spinning up the Translation framework itself, which is the
/// hard-to-mock part.
enum CaptionTranslationAvailability {
    /// Minimum number of "letter-like" characters before Translate is
    /// offered. Short (< 2 letters) blurbs are usually emoji or
    /// punctuation — running them through Translate produces noise.
    static let minimumLetterCount = 2

    /// Returns the cleaned-up text that should be handed to the
    /// Translation framework, or `nil` when the caller should hide the
    /// Translate button entirely.
    static func translatableText(from raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return nil }

        // Pixiv occasionally hands back captions where every "char" is an
        // emoji or punctuation glyph. Counting just letters keeps the
        // gate aligned with what Apple Translate can usefully process.
        let letterCount = trimmed.unicodeScalars.lazy.filter { scalar in
            CharacterSet.letters.contains(scalar)
        }.count
        guard letterCount >= minimumLetterCount else { return nil }

        return trimmed
    }

    /// Convenience predicate. Cheaper to read at the SwiftUI call site.
    static func canTranslate(_ raw: String) -> Bool {
        translatableText(from: raw) != nil
    }
}
