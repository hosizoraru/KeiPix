import Foundation

enum L10n {
    static var explore: String { text("Explore") }
    static var search: String { text("Search") }
    static var ranking: String { text("Ranking") }
    static var bookmarks: String { text("Bookmarks") }
    static var following: String { text("Following") }
    static var login: String { text("Login") }
    static var logout: String { text("Logout") }
    static var refresh: String { text("Refresh") }
    static var loading: String { text("Loading") }
    static var openInPixiv: String { text("Open in Pixiv") }
    static var bookmark: String { text("Bookmark") }
    static var removeBookmark: String { text("Remove Bookmark") }
    static var follow: String { text("Follow") }
    static var unfollow: String { text("Unfollow") }
    static var settings: String { text("Settings") }
    static var appearance: String { text("Appearance") }
    static var useOriginalImages: String { text("Use original images in detail") }
    static var loginTitle: String { text("Login to Pixiv") }
    static var loginHint: String { text("Complete login in the embedded Pixiv page. KeiPix captures only the authorization code.") }
    static var signedOutTitle: String { text("Sign in to load Pixiv feeds") }
    static var signedOutSubtitle: String { text("KeiPix stores tokens in the macOS Keychain and uses Pixiv app API requests from the native client.") }
    static var searchPlaceholder: String { text("Search artworks, tags, creators") }
    static var noArtworkTitle: String { text("No artworks loaded") }
    static var noArtworkSubtitle: String { text("Refresh the current section or start a search.") }
    static var errorTitle: String { text("Request failed") }
    static var copied: String { text("Copied") }
    static var loadMore: String { text("Load More") }
    static var publicBookmarks: String { text("Public bookmarks") }
    static var privateBookmarks: String { text("Private bookmarks") }
    static var daily: String { text("Daily") }
    static var weekly: String { text("Weekly") }
    static var monthly: String { text("Monthly") }
    static var details: String { text("Details") }
    static var tags: String { text("Tags") }
    static var views: String { text("Views") }
    static var saves: String { text("Saves") }
    static var pages: String { text("Pages") }
    static var aiGenerated: String { text("AI generated") }

    static func text(_ key: String) -> String {
        String(localized: String.LocalizationValue(key), bundle: .module)
    }
}
