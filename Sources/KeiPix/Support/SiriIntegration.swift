import Foundation

/// Siri integration via AppIntents.
///
/// Provides voice-activated actions for KeiPix:
/// - "Open latest artwork"
/// - "Search for [keyword]"
/// - "Download current artwork"
/// - "Show my bookmarks"

// Note: Full Siri integration requires AppIntents framework
// and proper intent definitions. This file provides the
// infrastructure for future implementation.

/// Intent types for Siri integration.
enum SiriIntentType: String, CaseIterable {
    case openLatestArtwork
    case searchKeyword
    case downloadCurrent
    case showBookmarks

    var localizedDescription: String {
        switch self {
        case .openLatestArtwork: return L10n.openPixivLinkFromClipboard
        case .searchKeyword: return L10n.search
        case .downloadCurrent: return L10n.download
        case .showBookmarks: return L10n.bookmark
        }
    }
}

/// Configuration for Siri integration.
struct SiriConfiguration {
    /// Enable/disable Siri integration.
    static var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "siriIntegrationEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "siriIntegrationEnabled") }
    }

    /// Supported intent types.
    static var supportedIntents: [SiriIntentType] {
        [.openLatestArtwork, .searchKeyword, .downloadCurrent, .showBookmarks]
    }
}
