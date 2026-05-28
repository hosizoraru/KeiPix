import Foundation

/// Handles incoming Pixiv links from the Share Extension.
///
/// The Share Extension target (created separately in Xcode) receives
/// URLs from other apps and passes them to the main app via a shared
/// App Group container. This handler processes the incoming links.
enum ShareExtensionHandler {
    static let appGroupIdentifier = "group.com.keipix"
    static let pendingLinkKey = "shareExtension.pendingLink"
    static let processedLinkKey = "shareExtension.processedLink"

    /// Shared UserDefaults for the app group.
    private static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupIdentifier)
    }

    /// Save a Pixiv link from the Share Extension for the main app to process.
    static func savePendingLink(_ url: URL) {
        guard let defaults = sharedDefaults else { return }
        defaults.set(url.absoluteString, forKey: pendingLinkKey)
    }

    /// Check for and consume a pending link from the Share Extension.
    /// Returns the URL if one was pending, nil otherwise.
    @MainActor
    static func consumePendingLink() -> URL? {
        guard let defaults = sharedDefaults,
              let urlString = defaults.string(forKey: pendingLinkKey),
              let url = URL(string: urlString) else {
            return nil
        }

        // Mark as processed
        defaults.set(urlString, forKey: processedLinkKey)
        defaults.removeObject(forKey: pendingLinkKey)

        return url
    }

    /// Check if a URL is a valid Pixiv link that the app can handle.
    static func isPixivLink(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return host.contains("pixiv.net") || host.contains("pixivision.net")
    }

    /// Extract the Pixiv link from a shared text (may contain other text).
    static func extractPixivLink(from text: String) -> URL? {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let range = NSRange(text.startIndex..., in: text)
        let matches = detector?.matches(in: text, options: [], range: range) ?? []

        for match in matches {
            guard let range = Range(match.range, in: text),
                  let url = URL(string: String(text[range])),
                  isPixivLink(url) else {
                continue
            }
            return url
        }

        return nil
    }
}
