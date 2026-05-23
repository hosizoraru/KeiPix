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
    static var language: String { text("Language") }
    static var automatic: String { text("Automatic") }
    static var simplifiedChinese: String { text("Simplified Chinese") }
    static var english: String { text("English") }
    static var appearance: String { text("Appearance") }
    static var useOriginalImages: String { text("Use original images in detail") }
    static var layout: String { text("Layout") }
    static var galleryLayout: String { text("Gallery Layout") }
    static var auto: String { text("Auto") }
    static var twoColumns: String { text("Two Columns") }
    static var threeColumns: String { text("Three Columns") }
    static var compact: String { text("Compact") }
    static var compactCards: String { text("Compact artwork cards") }
    static var windowSize: String { text("Window Size") }
    static var smallWindow: String { text("Small") }
    static var balancedWindow: String { text("Balanced") }
    static var wideWindow: String { text("Wide") }
    static var readingWindow: String { text("Reading") }
    static var trackpad: String { text("Trackpad") }
    static var enableTrackpadGestures: String { text("Enable trackpad gestures") }
    static var twoFingerSwipeBehavior: String { text("Two-finger swipe behavior") }
    static var pageOnlySwipe: String { text("Page within artwork") }
    static var pageThenArtworkSwipe: String { text("Switch artwork at edges") }
    static var account: String { text("Account") }
    static var profile: String { text("Profile") }
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
    static var description: String { text("Description") }
    static var artworkInformation: String { text("Artwork Information") }
    static var views: String { text("Views") }
    static var saves: String { text("Saves") }
    static var pages: String { text("Pages") }
    static var page: String { text("Page") }
    static var previousPage: String { text("Previous Page") }
    static var nextPage: String { text("Next Page") }
    static var thumbnails: String { text("Thumbnails") }
    static var readingMode: String { text("Reading Mode") }
    static var singlePage: String { text("Single Page") }
    static var continuousReading: String { text("Continuous Reading") }
    static var pageIndex: String { text("Page Index") }
    static var jumpToPage: String { text("Jump to Page") }
    static var resetZoom: String { text("Reset Zoom") }
    static var toggleZoom: String { text("Toggle Zoom") }
    static var aiGenerated: String { text("AI generated") }
    static var created: String { text("Created") }
    static var artworkID: String { text("Artwork ID") }
    static var creatorID: String { text("Creator ID") }
    static var results: String { text("Results") }
    static var nextPageAvailable: String { text("More available") }
    static var noMorePages: String { text("End of feed") }

    static func pageStatus(_ page: Int, _ count: Int) -> String {
        String(format: text("Page %d of %d"), locale: Locale.current, page, count)
    }

    static func text(_ key: String) -> String {
        let selected = UserDefaults.standard.string(forKey: "appLanguage")
            .flatMap(AppLanguage.init(rawValue:)) ?? .automatic
        if let lprojName = selected.lprojName,
           let path = Bundle.module.path(forResource: lprojName.lowercased(), ofType: "lproj") ?? Bundle.module.path(forResource: lprojName, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle.localizedString(forKey: key, value: key, table: nil)
        }
        return Bundle.module.localizedString(forKey: key, value: key, table: nil)
    }
}
