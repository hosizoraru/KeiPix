import Foundation

/// Pure helpers shared by the AppIntents surface so the intent
/// implementations stay thin and the parsing logic stays testable
/// without spinning up the AppIntents runtime. Apple's Shortcuts
/// app validates parameter strings only loosely — anything that
/// matches the parameter type passes — so these helpers re-parse
/// input the same way `KeiPixApp.onOpenURL` does, keeping the
/// affordance in sync with the user-facing pasteboard handler.
enum IntentInputNormalizer {
    /// Resolves a free-form input string to a routable Pixiv URL.
    /// Accepts:
    /// - `https://www.pixiv.net/...` (full web URL)
    /// - `pixiv://...` (mobile scheme)
    /// - `keipix://open?url=...` (custom scheme — same shape the
    ///   web fallback hands off through)
    /// - bare numeric strings, treated as artwork ids
    /// Returns nil when nothing in the input matches a Pixiv route.
    static func pixivURL(from rawInput: String) -> URL? {
        let trimmed = rawInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return nil }

        // Bare-id shortcut — the shortcuts UI is friendlier to
        // numeric input than a full URL, so let the intent take
        // either form.
        if let id = Int(trimmed) {
            return URL(string: "https://www.pixiv.net/artworks/\(id)")
        }

        if let url = URL(string: trimmed),
           PixivWebLinkResolver.destination(from: url) != nil {
            return url
        }

        // Fall through to the same string-scanning path the
        // clipboard handler uses, in case the user pasted a URL
        // surrounded by Markdown link syntax or extra prose.
        return PixivWebLinkResolver.firstSupportedURL(in: trimmed)
    }

    /// Resolves a free-form input string to a Pixiv artwork id.
    /// Useful for the `OpenArtworkIntent` parameter — accepts
    /// both bare ids and full pixiv.net URLs.
    static func artworkID(from rawInput: String) -> Int? {
        let trimmed = rawInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if let id = Int(trimmed) {
            return id
        }
        guard let url = URL(string: trimmed) ?? PixivWebLinkResolver.firstSupportedURL(in: trimmed),
              let destination = PixivWebLinkResolver.destination(from: url),
              case .artwork(let id) = destination else {
            return nil
        }
        return id
    }
}
