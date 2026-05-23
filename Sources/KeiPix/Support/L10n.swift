import Foundation

enum L10n {
    static var explore: String { text("Explore") }
    static var works: String { text("Works") }
    static var illustrations: String { text("Illustrations") }
    static var manga: String { text("Manga") }
    static var search: String { text("Search") }
    static var ranking: String { text("Ranking") }
    static var mangaRanking: String { text("Manga Ranking") }
    static var bookmarks: String { text("Bookmarks") }
    static var library: String { text("Library") }
    static var following: String { text("Following") }
    static var followingCreators: String { text("Following Creators") }
    static var history: String { text("History") }
    static var mangaWatchlist: String { text("Manga Watchlist") }
    static var recommendedCreators: String { text("Recommended Creators") }
    static var login: String { text("Login") }
    static var logout: String { text("Logout") }
    static var refresh: String { text("Refresh") }
    static var loading: String { text("Loading") }
    static var openInPixiv: String { text("Open in Pixiv") }
    static var bookmark: String { text("Bookmark") }
    static var removeBookmark: String { text("Remove Bookmark") }
    static var editBookmark: String { text("Edit Bookmark") }
    static var saveBookmark: String { text("Save Bookmark") }
    static var bookmarkTags: String { text("Bookmark Tags") }
    static var addTag: String { text("Add Tag") }
    static var tagName: String { text("Tag Name") }
    static var noBookmarkTags: String { text("No bookmark tags") }
    static var selectAll: String { text("Select All") }
    static var clearSelection: String { text("Clear Selection") }
    static var follow: String { text("Follow") }
    static var unfollow: String { text("Unfollow") }
    static var creatorProfile: String { text("Creator Profile") }
    static var creatorIllustrations: String { text("Creator Illustrations") }
    static var creatorManga: String { text("Creator Manga") }
    static var creatorPublicBookmarks: String { text("Creator Public Bookmarks") }
    static var openCreatorProfile: String { text("Open Creator Profile") }
    static var worksCount: String { text("Works Count") }
    static var publicSaves: String { text("Public Saves") }
    static var followers: String { text("Followers") }
    static var region: String { text("Region") }
    static var job: String { text("Job") }
    static var links: String { text("Links") }
    static var settings: String { text("Settings") }
    static var language: String { text("Language") }
    static var automatic: String { text("Automatic") }
    static var simplifiedChinese: String { text("Simplified Chinese") }
    static var english: String { text("English") }
    static var appearance: String { text("Appearance") }
    static var useOriginalImages: String { text("Use original images in detail") }
    static var contentFilters: String { text("Content Filters") }
    static var showContentBadges: String { text("Show content badges") }
    static var hideMutedContent: String { text("Hide muted content") }
    static var hideAIArtworks: String { text("Hide AI-generated artworks") }
    static var hideR18Artworks: String { text("Hide R-18 artworks") }
    static var hideR18GArtworks: String { text("Hide R-18G artworks") }
    static var searchFilters: String { text("Search Filters") }
    static var matchType: String { text("Match Type") }
    static var partialTagMatch: String { text("Partial tag match") }
    static var exactTagMatch: String { text("Exact tag match") }
    static var titleAndCaption: String { text("Title and caption") }
    static var sort: String { text("Sort") }
    static var newest: String { text("Newest") }
    static var oldest: String { text("Oldest") }
    static var popular: String { text("Popular") }
    static var ageLimit: String { text("Age Limit") }
    static var unlimited: String { text("Unlimited") }
    static var dateRange: String { text("Date Range") }
    static var anytime: String { text("Anytime") }
    static var pastDay: String { text("Past Day") }
    static var pastWeek: String { text("Past Week") }
    static var pastMonth: String { text("Past Month") }
    static var pastYear: String { text("Past Year") }
    static var minimumBookmarks: String { text("Minimum Bookmarks") }
    static var noMinimum: String { text("No minimum") }
    static var workType: String { text("Work Type") }
    static var allWorks: String { text("All Works") }
    static var ugoiraFilter: String { text("Ugoira Filter") }
    static var all: String { text("All") }
    static var onlyUgoira: String { text("Only Ugoira") }
    static var noUgoira: String { text("No Ugoira") }
    static var reset: String { text("Reset") }
    static var apply: String { text("Apply") }
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
    static var showAccountIdentity: String { text("Show account identity") }
    static var profile: String { text("Profile") }
    static var hidden: String { text("Hidden") }
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
    static var dailyManga: String { text("Daily Manga") }
    static var weeklyManga: String { text("Weekly Manga") }
    static var monthlyManga: String { text("Monthly Manga") }
    static var details: String { text("Details") }
    static var tags: String { text("Tags") }
    static var description: String { text("Description") }
    static var artworkInformation: String { text("Artwork Information") }
    static var comments: String { text("Comments") }
    static var writeComment: String { text("Write a comment") }
    static var postComment: String { text("Post Comment") }
    static var noComments: String { text("No comments") }
    static var loadMoreComments: String { text("Load More Comments") }
    static var replies: String { text("Replies") }
    static var relatedArtworks: String { text("Related Artworks") }
    static var noRelatedArtworks: String { text("No related artworks") }
    static var loadMoreRelatedArtworks: String { text("Load More Related Artworks") }
    static var artworkSeries: String { text("Artwork Series") }
    static var noSeriesArtworks: String { text("No series artworks") }
    static var loadMoreSeriesArtworks: String { text("Load More Series Artworks") }
    static var addToWatchlist: String { text("Add to Watchlist") }
    static var watchlistAdded: String { text("Watchlist Added") }
    static var openSeriesInPixiv: String { text("Open Series in Pixiv") }
    static var openLatestArtwork: String { text("Open Latest Artwork") }
    static var noWatchlistSeries: String { text("No watchlist series") }
    static var loadMoreWatchlist: String { text("Load More Watchlist") }
    static var removeFromWatchlist: String { text("Remove from Watchlist") }
    static var noCreators: String { text("No creators") }
    static var loadMoreCreators: String { text("Load More Creators") }
    static var publicRestrict: String { text("Public") }
    static var privateRestrict: String { text("Private") }
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
    static var r18: String { text("R-18") }
    static var r18g: String { text("R-18G") }
    static var ugoira: String { text("Ugoira") }
    static var muted: String { text("Muted") }
    static var mute: String { text("Mute") }
    static var muteArtwork: String { text("Mute Artwork") }
    static var muteCreator: String { text("Mute Creator") }
    static var muteTag: String { text("Mute Tag") }
    static var mutedContent: String { text("Muted Content") }
    static var mutedTags: String { text("Muted Tags") }
    static var mutedCreators: String { text("Muted Creators") }
    static var mutedArtworks: String { text("Muted Artworks") }
    static var syncFromPixiv: String { text("Sync from Pixiv") }
    static var uploadToPixiv: String { text("Upload to Pixiv") }
    static var synced: String { text("Synced") }
    static var uploaded: String { text("Uploaded") }
    static var muteSyncHint: String { text("Pixiv sync covers muted tags and creators. Local muted artworks stay on this Mac.") }
    static var clearMutedContent: String { text("Clear Muted Content") }
    static var noMutedContent: String { text("No muted content") }
    static var contentRating: String { text("Content Rating") }
    static var allAges: String { text("All Ages") }
    static var yes: String { text("Yes") }
    static var no: String { text("No") }
    static var playUgoira: String { text("Play Ugoira") }
    static var pauseUgoira: String { text("Pause Ugoira") }
    static var reloadUgoira: String { text("Reload Ugoira") }
    static var loadingUgoira: String { text("Loading Ugoira") }
    static var retry: String { text("Retry") }
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
