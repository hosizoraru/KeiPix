import Foundation

private enum L10nTable {
    static let navigation = "Navigation"
}

enum L10n {
    static var discover: String { text("Discovery") }
    static var discoveryHighlights: String { text("Discovery Highlights") }
    static var discoveryForYou: String { text("For You") }
    static var discoveryMetrics: String { text("Discovery Metrics") }
    static var customizeDashboard: String { text("Customize Dashboard") }
    static var bottomTabs: String { text("Bottom Tabs", table: L10nTable.navigation) }
    static var bottomTabBehavior: String { text("Bottom Tab Behavior", table: L10nTable.navigation) }
    static var mobileBookmarkTab: String { text("Bookmark Tab", table: L10nTable.navigation) }
    static var customizeBottomTabs: String { text("Customize Bottom Tabs", table: L10nTable.navigation) }
    static var bottomTabsHint: String { text("Choose the default page for each iPhone and iPad portrait tab.", table: L10nTable.navigation) }
    static var mobileBottomTabLaunchTarget: String { text("Launch Tab", table: L10nTable.navigation) }
    static var mobileBottomTabLaunchHint: String { text("Choose which tab iPhone and iPad portrait should open after a cold start.", table: L10nTable.navigation) }
    static var mobileBottomTabLaunchLastUsed: String { text("Last Used Tab", table: L10nTable.navigation) }
    static var rememberMobileBottomTabPages: String { text("Remember Each Tab's Last Page", table: L10nTable.navigation) }
    static var rememberMobileBottomTabPagesHint: String { text("When switching tabs, return to the last page used in that tab. Turn this off to always open the default page.", table: L10nTable.navigation) }
    static var fixedTabs: String { text("Fixed Tabs", table: L10nTable.navigation) }
    static var defaultTabPages: String { text("Default Tab Pages", table: L10nTable.navigation) }
    static var selectedDestinations: String { text("Selected Destinations", table: L10nTable.navigation) }
    static var bottomTabSlotFormat: String { text("Slot %d", table: L10nTable.navigation) }
    static var resetBottomTabs: String { text("Reset Bottom Tabs", table: L10nTable.navigation) }
    static var dashboardCards: String { text("Dashboard Cards") }
    static var dashboardSections: String { text("Dashboard Sections") }
    static var resetDashboardSections: String { text("Reset to Default") }
    static var moveUp: String { text("Move Up") }
    static var moveDown: String { text("Move Down") }
    static var reorder: String { text("Reorder") }
    static var discoverDetailHint: String { text("Pick a Discover card to open a feed, creator list, ranking, or library view.") }
    static var explore: String { text("Explore") }
    static var works: String { text("Works") }
    static var illustrations: String { text("Illustrations") }
    static var defaultLabel: String { text("Default") }
    static var manga: String { text("Manga") }
    static var newIllustrations: String { text("New Illustrations") }
    static var newManga: String { text("New Manga") }
    static var trendingTags: String { text("Trending Tags") }
    static var spotlight: String { text("Spotlight") }
    static var noSpotlightArticles: String { text("No spotlight articles") }
    static var loadMoreSpotlightArticles: String { text("Load More Spotlight Articles") }
    static var loadedSpotlightArticlesFormat: String { text("Loaded %d Spotlight articles") }
    static var openArticle: String { text("Open Article") }
    static var selectArticle: String { text("Select an article") }
    static var copiedArticleLink: String { text("Copied article link") }
    static var spotlightCollection: String { text("Spotlight Collection") }
    static var latestArticles: String { text("Latest Articles") }
    static var monthlyRankingArticles: String { text("Monthly Ranking") }
    static var recommendedArticles: String { text("Recommended") }
    static var noMonthlyRankingArticles: String { text("No ranking articles") }
    static var noRecommendedArticles: String { text("No recommended articles") }
    static var monthlyRankingHint: String { text("Pixivision's most-read articles this month.") }
    static var recommendedHint: String { text("Editorial picks Pixivision is highlighting right now.") }
    static var savedArticles: String { text("Saved Articles") }
    static var articleHistory: String { text("Article History") }
    static var readArticle: String { text("Read Article") }
    static var saveArticle: String { text("Save Article") }
    static var removeSavedArticle: String { text("Remove Saved Article") }
    static var markArticleRead: String { text("Mark Article as Read") }
    static var markArticleUnread: String { text("Mark Article as Unread") }
    static var markedArticleRead: String { text("Marked article read") }
    static var markedArticleUnread: String { text("Marked article unread") }
    static var savedArticle: String { text("Saved article") }
    static var removedSavedArticle: String { text("Removed saved article") }
    static var noSavedArticles: String { text("No saved articles") }
    static var saveArticlesHint: String { text("Save Pixivision articles here for later reading.") }
    static var noArticleHistory: String { text("No article history") }
    static var articleHistoryHint: String { text("Open Pixivision articles to build a local reading history.") }
    static var clearArticleHistory: String { text("Clear Article History") }
    static var clearedArticleHistory: String { text("Cleared article history") }
    static var removeFromArticleHistory: String { text("Remove from Article History") }
    static var removedArticleHistory: String { text("Removed article history item") }
    static var savedArticleCountFormat: String { text("%d saved articles") }
    static var articleHistoryCountFormat: String { text("%d history articles") }
    static var search: String { text("Search") }
    static var searchSuggestions: String { text("Search Suggestions") }
    static var searchCreators: String { text("Search Creators") }
    static var savedSearches: String { text("Saved Searches") }
    static var savedSearchPresets: String { text("Saved Search Presets") }
    static var saveSearch: String { text("Save Search") }
    static var saveSearchWithFilters: String { text("Save Search with Filters") }
    static var searchSummary: String { text("Search Summary") }
    static var searchActions: String { text("Search Actions") }
    static var copySearchSummary: String { text("Copy Search Summary") }
    static var copiedSearchSummary: String { text("Copied Search Summary") }
    static var resetSearchFilters: String { text("Reset Search Filters") }
    static var openPixivWebSearch: String { text("Open Pixiv Web Search") }
    static var copyPixivWebSearchLink: String { text("Copy Pixiv Web Search Link") }
    static var copiedPixivWebSearchLink: String { text("Copied Pixiv Web Search Link") }
    static var routeSwitchRefreshExpiration: String { text("Refresh After Switching Sections") }
    static var routeSwitchRefreshExpirationHint: String { text("When returning to a section, reuse recently loaded content until this interval expires. Manual refresh always reloads immediately.") }
    static var routeSwitchRefreshTenMinutes: String { text("10 Minutes") }
    static var routeSwitchRefreshTwentyMinutes: String { text("20 Minutes") }
    static var routeSwitchRefreshThirtyMinutes: String { text("30 Minutes") }
    static var routeSwitchRefreshAppSession: String { text("This App Session") }
    static var routeSwitchRefreshManualOnly: String { text("Manual Refresh Only") }
    static var openPixivLinkFromClipboard: String { text("Open Pixiv Link from Clipboard") }
    static var quickOpenLink: String { text("Open Link") }
    static var quickPixivID: String { text("Pixiv ID") }
    static var quickImageSearch: String { text("Image Search") }
    static var openPixivID: String { text("Open Pixiv ID") }
    static var openPixivIDTarget: String { text("Pixiv ID Type") }
    static var openPixivIDHint: String { text("Open an artwork or creator directly by numeric Pixiv ID.") }
    static var pixivIDQuickOpenHint: String { text("Search also accepts illust:123 and user:123.") }
    static var pixivIDResultFormat: String { text("Pixiv ID #%d") }
    static var pixivisionDisplay: String { text("Pixivision Display") }
    static var artworkIDPlaceholder: String { text("Enter artwork ID") }
    static var creatorIDPlaceholder: String { text("Enter creator ID") }
    static var openedPixivIDFormat: String { text("Opened %@ %d") }
    static var openedPixivLinkFormat: String { text("Opened Pixiv link %@") }
    static var noPixivLinkInClipboard: String { text("No Pixiv link in clipboard") }
    static var unsupportedPixivLink: String { text("Unsupported Pixiv link") }
    static var loginRequiredForPixivLink: String { text("Login to open Pixiv links") }
    static var dropPixivLinkToOpen: String { text("Drop Pixiv link to open in KeiPix") }
    static var pixivisionArticleFormat: String { text("Pixivision Article #%d") }
    static var pixivisionRelatedArticles: String { text("Related Articles") }
    static var pixivisionRelatedTagLatest: String { text("Latest in this tag") }
    static var pixivisionRelatedTagPopular: String { text("People also liked") }
    static var pixivisionRelatedCategoryLatest: String { text("Latest in this category") }
    static var viewMore: String { text("View More") }
    static var recentSearches: String { text("Recent Searches") }
    static var noSavedSearches: String { text("No saved searches") }
    static var noSavedSearchPresets: String { text("No saved search presets") }
    static var noRecentSearches: String { text("No recent searches") }
    static var noMatchingSearches: String { text("No matching searches") }
    static var removeSavedSearch: String { text("Remove Saved Search") }
    static var removeSearchPreset: String { text("Remove Search Preset") }
    static var clearSearchHistory: String { text("Clear Search History") }
    static var removeSavedSearchConfirmationFormat: String { text("Remove saved search %@?") }
    static var removeSearchPresetConfirmationFormat: String { text("Remove search preset %@?") }
    static var clearSearchHistoryConfirmationFormat: String { text("Clear %d recent searches?") }
    static var removedSavedSearchesFormat: String { text("Removed %d saved searches") }
    static var removedSearchPresetsFormat: String { text("Removed %d search presets") }
    static var clearedSearchHistoryItemsFormat: String { text("Cleared %d recent searches") }
    static var searchSavedSearches: String { text("Search saved searches") }
    static var copyKeyword: String { text("Copy Keyword") }
    static var copiedKeywordFormat: String { text("Copied %@") }
    static var savedSearchFormat: String { text("Saved %@") }
    static var savedSearchPresetFormat: String { text("Saved %@ with filters") }
    static var runningSearchFormat: String { text("Running search for %@") }
    static var appliedSearchPresetFormat: String { text("Applied search preset %@") }
    static var importSearchLibrary: String { text("Import Search Library") }
    static var exportSearchLibrary: String { text("Export Search Library") }
    static var importedSearchLibraryFormat: String { text("Imported %d presets · %d saved · %d history") }
    static var exportedSearchLibrary: String { text("Exported search library") }
    static var unableToImportSearchLibrary: String { text("Unable to import search library") }
    static var unableToExportSearchLibrary: String { text("Unable to export search library") }
    static var noPixivWebSearchLink: String { text("No Pixiv Web search link") }
    static var ranking: String { text("Ranking") }
    static var mangaRanking: String { text("Manga Ranking") }
    static var bookmarks: String { text("Bookmarks") }
    static var library: String { text("Library") }
    static var following: String { text("Following") }
    static var followingCreators: String { text("Following Creators") }
    static var pinnedCreators: String { text("Pinned Creators") }
    static var history: String { text("History") }
    static var historySource: String { text("History Source") }
    static var localHistory: String { text("Local") }
    static var pixivHistory: String { text("Pixiv") }
    static var searchHistory: String { text("Search history") }
    static var historyFilters: String { text("History Filters") }
    static var watchLater: String { text("Watch Later") }
    static var addToWatchLater: String { text("Add to Watch Later") }
    static var removeFromWatchLater: String { text("Remove from Watch Later") }
    static var inWatchLater: String { text("In Watch Later") }
    static var workSubscriptions: String { text("Subscriptions") }
    static var workSubscriptionsEmpty: String { text("No subscriptions yet") }
    static var workSubscriptionsEmptyHint: String { text("Subscribe to creators from their profile to track new works.") }
    static var workSubscriptionsSubscribed: String { text("Subscribed") }
    static var workSubscriptionsUnsubscribed: String { text("Unsubscribed") }
    static var workSubscriptionsCheckNow: String { text("Check for Updates") }
    static var workSubscriptionsNewWorks: String { text("new works") }
    static var workSubscriptionsLastChecked: String { text("Last checked") }
    static var workSubscriptionsTracking: String { text("Tracked Work Types") }
    static var workSubscriptionsRequiresOneKind: String { text("Keep at least one work type tracked.") }
    static var workSubscriptionsTrackingEnabledFormat: String { text("Tracking %@") }
    static var workSubscriptionsTrackingDisabledFormat: String { text("Stopped tracking %@") }
    static var watchLaterEmpty: String { text("No items in watch later queue") }
    static var watchLaterEmptyHint: String { text("Add artworks from the detail view to watch later.") }
    static var watchLaterAdded: String { text("Added to Watch Later") }
    static var watchLaterRemoved: String { text("Removed from Watch Later") }
    static var watchLaterRemoveConfirm: String { text("Remove from Watch Later?") }
    static var watchLaterRemovedFormat: String { text("Removed %@ from Watch Later") }
    static var clearedWatchLaterFormat: String { text("Cleared %d watch later items") }
    static var watchLaterClear: String { text("Clear Watch Later") }
    static var clearSearch: String { text("Clear Search") }
    static var clearFeedFilter: String { text("Clear Feed Filter") }
    static var feedFilterCleared: String { text("Feed filter cleared") }
    static var feedFilter: String { text("Filter") }
    static var filtering: String { text("Filtering") }
    static var activeArtworkFilterFormat: String { text("Filter: %@") }
    static var activeFeedFiltersFormat: String { text("%d active filters") }
    static var advancedFilter: String { text("Advanced Filter") }
    static var editAdvancedFilter: String { text("Edit Advanced Filter") }
    static var textFilters: String { text("Text Filters") }
    static var numberRanges: String { text("Number Ranges") }
    static var otherTerms: String { text("Other Terms") }
    static var minimum: String { text("Minimum") }
    static var maximum: String { text("Maximum") }
    static var any: String { text("Any") }
    static var include: String { text("Include") }
    static var exclude: String { text("Exclude") }
    static var contentFlags: String { text("Content Flags") }
    static var aspectRatio: String { text("Aspect Ratio") }
    static var excludeR18: String { text("Exclude R-18") }
    static var excludeR18G: String { text("Exclude R-18G") }
    static var landscape: String { text("Landscape") }
    static var portrait: String { text("Portrait") }
    static var square: String { text("Square") }
    static var creatorTagFilterFormat: String { text("Creator tag #%@") }
    static var clearHistory: String { text("Clear History") }
    static var clearHistoryConfirmation: String { text("Clear all local browsing history?") }
    static var deleteHistoryItemConfirmationFormat: String { text("Delete %@ from local history?") }
    static var deletedHistoryItemFormat: String { text("Deleted %@ from local history") }
    static var clearedHistoryItemsFormat: String { text("Cleared %d history items") }
    static var exportHistory: String { text("Export History") }
    static var exportedHistory: String { text("Exported history") }
    static var deleteFromHistory: String { text("Delete from History") }
    static var noLocalHistoryTitle: String { text("No local history") }
    static var noLocalHistorySubtitle: String { text("Open artworks to build a private local history on this Mac.") }
    static var noMatchingHistoryTitle: String { text("No matching history") }
    static var noMatchingHistorySubtitle: String { text("Change the history search to see other items.") }
    static var noPixivHistoryTitle: String { text("No Pixiv history") }
    static var noPixivHistorySubtitle: String { text("Refresh Pixiv history after opening artworks from this account.") }
    static var historyItemCountFormat: String { text("%d history items") }
    static var refreshedPixivHistoryFormat: String { text("Refreshed %d Pixiv history items") }
    static var loadedPixivHistoryItemsFormat: String { text("Loaded %d Pixiv history items") }
    static var mangaWatchlist: String { text("Manga Watchlist") }
    static var recommendedCreators: String { text("Recommended Creators") }
    static var relatedCreators: String { text("Related Creators") }
    static var noRelatedCreators: String { text("No related creators") }
    static var viewAllRelatedCreators: String { text("View All Related Creators") }
    static var noTrendingTags: String { text("No trending tags") }
    static var creatorNetwork: String { text("Creator Network") }
    static var enterSearchKeyword: String { text("Enter a search keyword") }
    static var login: String { text("Login") }
    static var logout: String { text("Logout") }
    static var logoutConfirmation: String { text("Logout from this Pixiv account?") }
    static var refresh: String { text("Refresh") }
    static var viewOptions: String { text("View Options") }
    static var loading: String { text("Loading") }
    static var cancel: String { text("Cancel") }
    static var open: String { text("Open") }
    static var openInPixiv: String { text("Open in Pixiv") }
    static var share: String { text("Share") }
    static var shareCurrentPage: String { text("Share Current Page") }
    static var feedbackAndMute: String { text("Feedback / Mute") }
    static var feedbackAndMuteHint: String { text("Copy a report summary, open Pixiv Web, or apply a local mute without submitting remote reports from KeiPix.") }
    static var feedbackTarget: String { text("Feedback Target") }
    static var reportReason: String { text("Report Reason") }
    static var reportReasonSexualContent: String { text("Sexual Content and Profanity") }
    static var reportReasonHateSpeech: String { text("Hate Speech") }
    static var reportReasonTerroristContent: String { text("Terrorist Content") }
    static var reportReasonDangerousOrganizations: String { text("Dangerous Organizations and Movements") }
    static var reportReasonSensitiveEvents: String { text("Sensitive Events") }
    static var reportReasonBullyingHarassment: String { text("Bullying and Harassment") }
    static var reportReasonDangerousProducts: String { text("Dangerous Products") }
    static var reportReasonMarijuana: String { text("Marijuana") }
    static var reportReasonTobaccoAlcohol: String { text("Tobacco and Alcohol") }
    static var reportReasonOther: String { text("Other") }
    static var copyReportSummary: String { text("Copy Report Summary") }
    static var copiedReportSummary: String { text("Copied Report Summary") }
    static var openPixivWebReportPage: String { text("Open Pixiv Web") }
    static var localMuteRequestedFormat: String { text("%@ requested locally") }
    static var title: String { text("Title") }
    static var note: String { text("Note") }
    static var commentIDFormat: String { text("Comment #%d") }
    static var imageSourceSearch: String { text("Image Source Search") }
    static var searchImageSource: String { text("Search Image Source") }
    static var searchLocalImageSource: String { text("Search Local Image") }
    static var chooseImage: String { text("Choose Image") }
    static var searchingImageSource: String { text("Searching image source") }
    static var searchingImageSourcePageFormat: String { text("Searching page %d with SauceNAO") }
    static var searchingLocalImageSource: String { text("Searching local image with SauceNAO") }
    static var imageSourceSearchUnavailable: String { text("No searchable image is available for this page") }
    static var imageSourceSearchFailed: String { text("Image source search failed") }
    static var noImageSourceResults: String { text("No image source results") }
    static var noImageSourceResultsHint: String { text("SauceNAO did not return Pixiv artwork matches for this page.") }
    static var imageSourceResultsFormat: String { text("%d Pixiv matches") }
    static var openInSauceNAO: String { text("Open in SauceNAO") }
    static var copySauceNAOLink: String { text("Copy SauceNAO Link") }
    static var copyCurrentPageLink: String { text("Copy Current Page Link") }
    static var downloadCurrentPage: String { text("Download Current Page") }
    static var queuedCurrentPage: String { text("Queued Current Page") }
    static var downloadPageRange: String { text("Download Page Range") }
    static var startPage: String { text("Start Page") }
    static var endPage: String { text("End Page") }
    static var currentPageToEnd: String { text("Current Page to End") }
    static var allPages: String { text("All Pages") }
    static var downloadPageRangeSummaryFormat: String { text("Pages %d-%d · %d selected · %d total") }
    static var queuedPageRangeFormat: String { text("Queued pages %d-%d (%d pages)") }
    static var sourcePagesRangeFormat: String { text("Source pages %d-%d") }
    static var sourcePagesListFormat: String { text("Source pages %@") }
    static var reloadPage: String { text("Reload Page") }
    static var webContentReloaded: String { text("Web content reloaded") }
    static var copyLink: String { text("Copy Link") }
    static var copyArtworkSummary: String { text("Copy Artwork Summary") }
    static var copiedArtworkSummary: String { text("Copied Artwork Summary") }
    static var sharing: String { text("Sharing") }
    static var artworkCopyTemplate: String { text("Artwork Copy Template") }
    static var creatorCopyTemplate: String { text("Creator Copy Template") }
    static var copyTemplateHint: String { text("Use placeholders like ${id}, ${title}, ${creator}, ${account}, ${userId}, ${pages}, ${views}, ${bookmarks}, ${comments}, ${badges}, ${tags}, ${url}, ${AI}, ${R18}, and ${R18G}.") }
    static var resetArtworkCopyTemplate: String { text("Reset Artwork Copy Template") }
    static var resetCreatorCopyTemplate: String { text("Reset Creator Copy Template") }
    static var copyTemplateReset: String { text("Copy template reset") }
    static var copyTemplateAlreadyDefault: String { text("Copy template is already default") }
    static var moreActions: String { text("More Actions") }
    static var download: String { text("Download") }
    static var downloads: String { text("Downloads") }
    static var downloading: String { text("Downloading") }
    static var downloaded: String { text("Downloaded") }
    static var openDownloads: String { text("Open Downloads") }
    static var queued: String { text("Queued") }
    static var failed: String { text("Failed") }
    static var imagePages: String { text("Image Pages") }
    static var ugoiraZip: String { text("Ugoira ZIP") }
    static var ugoiraFrameCountFormat: String { text("%d frames") }
    static var exportGIF: String { text("Export GIF") }
    static var exportCurrentFrame: String { text("Export Current Frame") }
    static var exportedFrameFormat: String { text("Exported frame %@") }
    static var unableToExportFrame: String { text("Unable to export frame") }
    static var exportUgoiraZip: String { text("Export Ugoira ZIP") }
    static var ugoiraExportActions: String { text("Ugoira Export Actions") }
    static var shareUgoiraZip: String { text("Share Ugoira ZIP") }
    static var shareExportedGIF: String { text("Share Exported GIF") }
    static var revealExportedGIF: String { text("Reveal Exported GIF") }
    static var exportedGIFFormat: String { text("Exported GIF %@") }
    static var exportedZipFormat: String { text("Exported ZIP %@") }
    static var previewUgoira: String { text("Preview Ugoira") }
    static var ugoiraMetadataMissing: String { text("Ugoira metadata is missing. Re-download this item to enable in-app preview and GIF export.") }
    static var exportAsPDF: String { text("Export as PDF") }
    static var exportAsCollage: String { text("Export as Collage") }
    static var exportFailed: String { text("Export failed") }
    static func exportedTo(_ name: String) -> String { String(format: text("Exported %@"), locale: Locale.current, name) }
    static var playbackSpeed: String { text("Playback Speed") }
    static var ugoiraSeek: String { text("Seek Frame") }
    static var ugoiraTimeline: String { text("Ugoira Timeline") }
    static var ugoiraFailedToLoad: String { text("Couldn't load this ugoira.") }
    static var export: String { text("Export") }
    static var `import`: String { text("Import") }
    static var downloadFolder: String { text("Download Folder") }
    static var copyDownloadFolderPath: String { text("Copy Download Folder Path") }
    static var copiedDownloadFolderPath: String { text("Copied download folder path") }
    static var chooseFolder: String { text("Choose Folder") }
    static var openFolder: String { text("Open Folder") }
    static var saveDestination: String { text("Save Destination") }
    static var systemPhotosLibrary: String { text("System Photos Library") }
    static var photosLibraryDestinationDetail: String { text("Downloads save to Photos. KeiPix keeps a private local cache for reading, retries, and queue history.") }
    static var photosLibraryDestinationHint: String { text("On iPhone and iPad, artwork downloads are added to the system Photos library with KeiPix as the saving app. The local cache stays private to KeiPix.") }
    static var photosLibraryDownloadSettingsSubtitle: String { text("Downloads save to the system Photos library on iPhone and iPad. KeiPix keeps a private cache for reading and retrying.") }
    static var localDownloadCache: String { text("Local Download Cache") }
    static var privateAppCache: String { text("Private App Cache") }
    static var downloadNamingTemplate: String { text("Download Naming Template") }
    static var downloadNamingTemplateHint: String { text("Use placeholders like ${id}, ${title}, ${user}, ${userId}, ${series}, ${seriesId}, ${page}, ${page1}, ${pages}, ${ext}, ${AI}, ${R18}, ${R18G}, ${tag1}, ${tag2}, ${tag(name)}. Paths stay inside the download folder.") }
    static var downloadNamingTemplatePhotosHint: String { text("Use placeholders like ${id}, ${title}, ${user}, ${userId}, ${series}, ${seriesId}, ${page}, ${page1}, ${pages}, ${ext}, ${AI}, ${R18}, ${R18G}, ${tag1}, ${tag2}, ${tag(name)}. The rendered filename is used when KeiPix adds the artwork to Photos.") }
    static var photosLibraryPreviewPathFormat: String { text("Photos / %@") }
    static var templatePreview: String { text("Template Preview") }
    static var livePreview: String { text("Live Preview") }
    static var templatePreviewStandalone: String { text("Standalone Illust") }
    static var templatePreviewMultiPage: String { text("Multi-Page Artwork") }
    static var templatePreviewSeries: String { text("Series Chapter") }
    static var applyTemplatePreset: String { text("Apply Preset") }
    static var templatePresetAppliedFormat: String { text("Applied template preset %@") }
    static var insertTemplateToken: String { text("Insert Token") }
    static func insertedTemplateToken(_ value: String) -> String {
        String(format: text("Inserted %@"), locale: Locale.current, value)
    }
    static var templateTokenFlags: String { text("Flags") }
    static var seriesID: String { text("Series ID") }
    static var fileExtension: String { text("File Extension") }
    static var firstTag: String { text("First Tag") }
    static var secondTag: String { text("Second Tag") }
    static var namedTag: String { text("Named Tag") }
    static func unknownPlaceholdersFormat(_ value: String) -> String {
        String(format: text("Unknown placeholders: %@"), locale: Locale.current, value)
    }
    static var unknownPlaceholdersHint: String {
        text("Template references placeholders that won't expand at download time. They'll collapse to empty strings.")
    }
    static var resetTemplate: String { text("Reset Template") }
    static var choose: String { text("Choose") }
    static var clearCompleted: String { text("Clear Completed") }
    static var clearInvalidDownloads: String { text("Clear Invalid") }
    static var clearFailedDownloads: String { text("Clear Failed") }
    static var retryFailedDownloads: String { text("Retry Failed") }
    static var downloadActions: String { text("Download Actions") }
    static var copyVisibleDownloadLinks: String { text("Copy Visible Links") }
    static var revealFirstVisibleDownload: String { text("Reveal First Visible") }
    static var deleteVisibleDownloads: String { text("Remove Visible Download Records") }
    static var cancelDownload: String { text("Cancel Download") }
    static var cancelVisibleDownloads: String { text("Cancel Visible Active Downloads") }
    static var deleteVisibleDownloadsConfirmationFormat: String { text("Remove %d visible download records? Saved files stay in place.") }
    static var deleteDownloadConfirmationFormat: String { text("Remove %@ from the download queue? Saved files stay in place.") }
    static var cancelDownloadConfirmationFormat: String { text("Cancel %@ and remove it from the queue? Saved files stay in place.") }
    static var cancelVisibleDownloadsConfirmationFormat: String { text("Cancel %d visible active downloads and remove them from the queue? Saved files stay in place.") }
    static var clearFailedDownloadsConfirmationFormat: String { text("Clear %d failed download records? Saved files stay in place.") }
    static var clearInvalidDownloadsConfirmationFormat: String { text("Clear %d invalid download records?") }
    static var clearCompletedDownloadsConfirmationFormat: String { text("Clear %d completed download records?") }
    static var downloadQueueDetailedSummaryFormat: String { text("%d shown, %d active, %d completed, %@ stored") }
    static var clearedDownloadsFormat: String { text("Cleared %d downloads") }
    static var copiedLinksFormat: String { text("Copied %d links") }
    static var copiedArtworkLinksFormat: String { text("Copied %d artwork links") }
    static var noArtworkLinksToCopy: String { text("No artwork links to copy") }
    static var deletedDownloadsFormat: String { text("Removed %d download records") }
    static var cancelledDownloadsFormat: String { text("Cancelled %d downloads") }
    static var retriedDownloadsFormat: String { text("Retried %d downloads") }
    static var retriedDownloadsWithBackoffFormat: String { text("Scheduled %d downloads for retry") }
    static var retryScheduledFormat: String { text("Retry at %@") }
    static var noRetryableDownloads: String { text("No retryable downloads") }
    static var noDownloadRecordsChanged: String { text("No download records changed") }
    static var revealedDownloadInFinder: String { text("Revealed download in Finder") }
    static var openedDownloadFolder: String { text("Opened download folder") }
    static var unableToOpenDownloadFolder: String { text("Unable to open download folder") }
    static var downloadFolderChanged: String { text("Download folder changed") }
    static var downloadTemplateReset: String { text("Download template reset") }
    static var downloadTemplateAlreadyDefault: String { text("Download template is already default") }
    static var unableToOpenDownloadedArtwork: String { text("Unable to open downloaded artwork") }
    static var noDownloadLinksToCopy: String { text("No download links to copy") }
    static var revealInFinder: String { text("Reveal in Finder") }
    static var openDownloadedArtwork: String { text("Open Downloaded Artwork") }
    static var revealDownloadedArtwork: String { text("Reveal Downloaded Artwork") }
    static var saveToPhotos: String { text("Save to Photos") }
    static var savedToPhotos: String { text("Saved to Photos") }
    static var saveToPhotosFailed: String { text("Save to Photos failed") }
    static var deleteDownload: String { text("Remove Download Record") }
    static var noDownloadsTitle: String { text("No downloads yet") }
    static var noDownloadsSubtitle: String { text("Download artworks from the detail view or artwork context menus.") }
    static var noMatchingDownloadsTitle: String { text("No matching downloads") }
    static var noMatchingDownloadsSubtitle: String { text("Change the download filter to see other queue items.") }
    static var downloadInterrupted: String { text("Download interrupted") }
    static var batchActions: String { text("Batch Actions") }
    static var batchDownload: String { text("Batch Download") }
    static var includeFollowingPages: String { text("Include Following Pages") }
    static var followingPageRequests: String { text("Following page requests") }
    static var batchDownloadFollowingPagesHintFormat: String { text("May request up to %d more Pixiv feed pages before queueing.") }
    static var selectedWorks: String { text("Selected Works") }
    static var selectedWorksFormat: String { text("%d selected works") }
    static var noSelectedWorks: String { text("No selected works") }
    static var selectionMode: String { text("Selection Mode") }
    static var deselectArtwork: String { text("Deselect Artwork") }
    static var copySelectedArtworkLinks: String { text("Copy Selected Artwork Links") }
    static var batchBookmark: String { text("Batch Bookmark") }
    static var batchBookmarkSelected: String { text("Batch Bookmark Selected") }
    static var applyBookmarks: String { text("Apply Bookmarks") }
    static var loadedFeed: String { text("Loaded Feed") }
    static var noBatchBookmarkCandidates: String { text("No unbookmarked works in the loaded feed") }
    static var noSelectedBatchBookmarkCandidates: String { text("No unbookmarked works in the selection") }
    static var batchBookmarkScopeFormat: String { text("%@ · %d works checked") }
    static var batchBookmarkPreviewFormat: String { text("%d will be bookmarked · %d already bookmarked · %@") }
    static var batchBookmarkSkippedFormat: String { text("%d already bookmarked works will be skipped to avoid remote tag conflicts.") }
    static var batchBookmarkedResultFormat: String { text("Bookmarked %d works · %d failed") }
    static var moreBatchBookmarkItemsFormat: String { text("%d more works will be bookmarked") }
    static var moreSkippedBatchBookmarkItemsFormat: String { text("%d more already-bookmarked works skipped") }
    static var maximumDownloads: String { text("Maximum downloads") }
    static var addToDownloadQueue: String { text("Add to Download Queue") }
    static var queuedDownloadsFormat: String { text("Queued %d downloads") }
    static var pauseDownloads: String { text("Pause Downloads") }
    static var resumeDownloads: String { text("Resume Downloads") }
    static var downloadsPaused: String { text("Downloads Paused") }
    static var downloadsResumed: String { text("Downloads Resumed") }
    static var downloadThroughputPerSecondFormat: String { text("%@/s") }
    static var downloadThroughputTotalFormat: String { text("Total %@") }
    static var downloadFinishedNotificationTitle: String { text("Download finished") }
    static var downloadFinishedNotificationBodyFormat: String { text("downloadFinishedNotificationBodyFormat") }
    static var downloadsFinishedNotificationTitle: String { text("Downloads finished") }
    static var downloadsFinishedNotificationBodyFormat: String { text("%d artworks finished downloading.") }
    static var notifyOnDownloadFinish: String { text("Notify when downloads finish") }
    static var notifyOnDownloadFinishHint: String { text("Posts a Notification Center banner once a download wraps up — coalesced for batches so a 50-image queue still surfaces a single banner.") }
    static var notifyOnDownloadFinishAuthDenied: String { text("Notification Center declined permission. Re-enable banners for KeiPix in System Settings → Notifications.") }
    static var downloadedLocally: String { text("Downloaded Locally") }
    static var inDownloadQueue: String { text("In Download Queue") }
    static var downloadFailed: String { text("Download Failed") }
    static var concurrentDownloads: String { text("Concurrent Downloads") }
    static var concurrentDownloadsHint: String { text("Use fewer concurrent downloads for unstable proxies; use more when the connection is healthy.") }
    static var downloadFilter: String { text("Download Filter") }
    static var filterDownloads: String { text("Filter downloads...") }
    static var searchDownloads: String { text("Search downloads") }
    static var sortDownloads: String { text("Sort Downloads") }
    static var recentlyUpdated: String { text("Recently Updated") }
    static var downloadSortTitle: String { text("Title") }
    static var creator: String { text("Creator") }
    static var downloadSortCreator: String { text("Creator") }
    static var statusAndType: String { text("Status and Type") }
    static var allDownloads: String { text("All Downloads") }
    static var activeDownloads: String { text("Active") }
    static var completedDownloads: String { text("Completed") }
    static var failedDownloads: String { text("Failed Downloads") }
    static var downloadQueueSummaryFormat: String { text("%d shown · %d active · %d completed") }
    static var downloadStorageSummaryFormat: String { text("Storage %@") }
    static var bookmark: String { text("Bookmark") }
    static var bookmarked: String { text("Bookmarked") }
    static var unbookmarked: String { text("Unbookmarked") }
    static var removeBookmark: String { text("Remove Bookmark") }
    static var editBookmark: String { text("Edit Bookmark") }
    static var saveBookmark: String { text("Save Bookmark") }
    static var savedBookmarkFormat: String { text("Saved bookmark for %@") }
    static var bookmarkTags: String { text("Bookmark Tags") }
    static var bookmarkTagActions: String { text("Bookmark Tag Actions") }
    static var bookmarkFilters: String { text("Bookmark Filters") }
    static var bookmarkVisibility: String { text("Bookmark Visibility") }
    static var defaultRestrictFormat: String { text("Default (%@)") }
    static var bookmarkSort: String { text("Bookmark Sort") }
    static var newestBookmarked: String { text("Newest Bookmarked") }
    static var oldestBookmarked: String { text("Oldest Bookmarked") }
    static var newestArtwork: String { text("Newest Artwork") }
    static var oldestArtwork: String { text("Oldest Artwork") }
    static var bookmarkAgeLimit: String { text("Bookmark Age Limit") }
    static var bookmarkArtworkTag: String { text("Artwork Tag") }
    static var bookmarkArtworkTagPrompt: String { text("Filter loaded bookmarks by artwork tag") }
    static var bookmarkDate: String { text("Bookmark Date") }
    static var bookmarkFilterSummaryFormat: String { text("%d active filters") }
    static var bookmarkFiltersReset: String { text("Bookmark filters reset") }
    static var openPixivWebBookmarks: String { text("Open Pixiv Web Bookmarks") }
    static var copyPixivWebBookmarksLink: String { text("Copy Pixiv Web Bookmarks Link") }
    static var copiedPixivWebBookmarksLink: String { text("Copied Pixiv Web bookmarks link") }
    static var openPixivWebCollections: String { text("Open Pixiv Web Collections") }
    static var openPixivWebMyCollections: String { text("Open My Pixiv Collections") }
    static var openPixivWebSavedCollections: String { text("Open Saved Pixiv Collections") }
    static var pixivCollections: String { text("Pixiv Collections") }
    static var pixivActivity: String { text("Pixiv Activity") }
    static var pixivActivityDisplay: String { text("Activity Display") }
    static var pixivActivityFeedScope: String { text("Activity Feed") }
    static var pixivActivityKindFilter: String { text("Activity Type") }
    static var pixivActivityLayout: String { text("Activity Layout") }
    static var pixivActivityScopeAll: String { text("All Activity") }
    static var pixivActivityScopeEveryone: String { text("Everyone Activity") }
    static var pixivActivityScopeFollowingUsers: String { text("Following Users Activity") }
    static var pixivActivityScopeMyPixiv: String { text("MyPixiv Activity") }
    static var pixivActivityScopeMine: String { text("Mine Activity") }
    static var pixivActivityKindAll: String { text("All Activity Types") }
    static var pixivActivityNewBadge: String { text("New Activity Badge") }
    static var pixivActivityNewItemsFormat: String { text("%d new activity items") }
    static var pixivActivityNoNewItems: String { text("No new activity") }
    static var pixivActivityEmptyTitle: String { text("No Pixiv activity") }
    static var pixivActivityEmptyHint: String { text("Follow creators or refresh after connecting Pixiv Web to see social activity.") }
    static var pixivActivityFilteredEmptyTitle: String { text("No matching activity") }
    static var pixivActivityFilteredEmptyHint: String { text("Try another activity source or type.") }
    static var pixivActivityWebSessionRequiredTitle: String { text("Connect Web session") }
    static var pixivActivityWebSessionRequiredHint: String { text("Pixiv activity is a Web-only feed. Connect a Pixiv Web session to load it in KeiPix.") }
    static var pixivActivityLoadingMore: String { text("Loading more activity") }
    static var pixivActivityLoadedCountFormat: String { text("Loaded %d activity items") }
    static var pixivActivityRefreshedFormat: String { text("Refreshed %d activity items") }
    static var pixivActivityPostedArtwork: String { text("Posted artwork") }
    static var pixivActivityBookmarkedArtwork: String { text("Bookmarked artwork") }
    static var pixivActivityFollowedUser: String { text("Followed user") }
    static var pixivActivityUnknown: String { text("Pixiv activity") }
    static var pixivActivityOpenHint: String { text("Open this activity in KeiPix") }
    static var justNow: String { text("Just now") }
    static var minutesAgoFormat: String { text("%d min ago") }
    static var hoursAgoFormat: String { text("%d hr ago") }
    static var yesterdayTimeFormat: String { text("Yesterday %@") }
    static var daysAgoFormat: String { text("%d days ago") }
    static var savedPixivisionArticles: String { text("Saved Pixivision") }
    static var myPixivCollections: String { text("My Pixiv Collections") }
    static var myPixivUsers: String { text("MyPixiv") }
    static var myPixivIllustrations: String { text("MyPixiv Illustrations") }
    static var myPixivNovels: String { text("MyPixiv Novels") }
    static var savedPixivCollections: String { text("Saved Pixiv Collections") }
    static var pixivCollection: String { text("Pixiv Collection") }
    static var noPixivCollections: String { text("No Pixiv collections") }
    static var pixivCollectionSource: String { text("Collection Source") }
    static var recommendedPixivCollections: String { text("Recommended Collections") }
    static var everyonePixivCollections: String { text("Everyone's Collections") }
    static var popularPixivCollections: String { text("Popular Collections") }
    static var pixivCollectionTags: String { text("Collection Tags") }
    static var pixivCollectionsEmptyHint: String { text("Discover user-created Pixiv collections here. You can also paste a collection link to open it natively.") }
    static var myPixivCollectionsEmptyHint: String { text("Collections you publish on Pixiv Web appear here. Paste a collection link to open it natively.") }
    static var savedPixivCollectionsEmptyHint: String { text("Bookmarked Pixiv collections appear here. Use Pixiv Collections discovery or Pixiv Web to save collections.") }
    static var savedPixivCollectionsWebSessionRequiredHint: String { text("Pixiv keeps bookmarked collections behind the Web session. KeiPix can open collection links now, but syncing this list needs an explicit Pixiv Web session connection.") }
    static var refreshedPixivCollectionsFormat: String { text("Refreshed %d Pixiv collections") }
    static var collectionWorksCountFormat: String { text("%d works") }
    static var relatedPixivCollections: String { text("Related Collections") }
    static var pixivWeb: String { text("Pixiv Web") }
    static var pixivWebOnly: String { text("Pixiv Web only") }
    static var pixivWebBookmarkFiltersHint: String { text("Bookmark-date filters use Pixiv Web / Premium. Artwork tags are filtered locally from loaded works.") }
    static var pixivWebCollectionsHint: String { text("Collections are currently exposed by Pixiv Web. Open the web tab to browse or manage them.") }
    static var allBookmarkTags: String { text("All Bookmark Tags") }
    static var searchBookmarkTags: String { text("Search bookmark tags") }
    static var unclassified: String { text("Unclassified") }
    static var defaultBookmarkVisibility: String { text("Default Bookmark Visibility") }
    static var addTag: String { text("Add Tag") }
    static var tagName: String { text("Tag Name") }
    static var noBookmarkTags: String { text("No bookmark tags") }
    static var noMatchingBookmarkTags: String { text("No matching bookmark tags") }
    static var noBookmarkTagsToCopy: String { text("No bookmark tags to copy") }
    static var copyVisibleBookmarkTags: String { text("Copy Visible Bookmark Tags") }
    static var copiedBookmarkTagsFormat: String { text("Copied %d bookmark tags") }
    static var refreshedBookmarkTagsFormat: String { text("Refreshed %d bookmark tags") }
    static var loadedBookmarkTagsFormat: String { text("Loaded %d bookmark tags") }
    static var resetBookmarkTagOptions: String { text("Reset Bookmark Tag Options") }
    static var selectAll: String { text("Select All") }
    static var clearSelection: String { text("Clear Selection") }
    static var selectedBookmarkTagsFormat: String { text("Selected %d bookmark tags") }
    static var clearedBookmarkTagSelection: String { text("Cleared bookmark tag selection") }
    static var addedBookmarkTagFormat: String { text("Added bookmark tag #%@") }
    static var bookmarkTagAlreadySelectedFormat: String { text("Bookmark tag #%@ is already selected") }
    static var resetBookmarkEdits: String { text("Reset Bookmark Edits") }
    static var resetBookmarkEditsConfirmation: String { text("Reset unsaved bookmark edits?") }
    static var resetBookmarkEditsDone: String { text("Reset bookmark edits") }
    static var noBookmarkChanges: String { text("No bookmark changes") }
    static var follow: String { text("Follow") }
    static var followPublicly: String { text("Follow Publicly") }
    static var followPrivately: String { text("Follow Privately") }
    static var followUsingDefault: String { text("Follow Using Default") }
    static var followVisibility: String { text("Follow Visibility") }
    static var defaultFollowVisibility: String { text("Default Follow Visibility") }
    static var autoTagBookmarksWithArtworkTags: String { text("Use artwork tags for new bookmarks") }
    static var autoTagBookmarksWithArtworkTagsHint: String { text("Quick bookmarks use the artwork tags, and the bookmark editor preselects them for new bookmarks.") }
    static var premium: String { text("Premium") }
    static var showMore: String { text("Show More") }
    static var showLess: String { text("Show Less") }
    static var pasteFromClipboard: String { text("Paste from Clipboard") }
    static var followCreatorAfterBookmark: String { text("Follow creator after bookmarking") }
    static var followCreatorAfterBookmarkHint: String { text("New bookmarks also follow the creator using your default follow visibility.") }
    static var autoDownloadBookmarkedArtworks: String { text("Download new bookmarks automatically") }
    static var autoDownloadBookmarkedArtworksHint: String { text("New bookmarks are added to the download queue using original images when available.") }
    static var autoBookmarkDownloadedArtworks: String { text("Bookmark new downloads automatically") }
    static var autoBookmarkDownloadedArtworksHint: String { text("Downloads add the artwork to your Pixiv bookmarks using the default bookmark visibility.") }
    static var followingPublicly: String { text("Following Publicly") }
    static var followingPrivately: String { text("Following Privately") }
    static var unfollow: String { text("Unfollow") }
    static var close: String { text("Close") }
    static var creatorProfile: String { text("Creator Profile") }
    static var creatorIllustrations: String { text("Creator Illustrations") }
    static var creatorManga: String { text("Creator Manga") }
    static var creatorPublicBookmarks: String { text("Creator Public Bookmarks") }
    static var openCreatorProfile: String { text("Open Creator Profile") }
    static var creatorTags: String { text("Creator Tags") }
    static var searchCreatorTags: String { text("Search creator tags") }
    static var noCreatorTags: String { text("No creator tags") }
    static var noMatchingCreatorTags: String { text("No matching creator tags") }
    static var recentCreatorWorks: String { text("Recent Creator Works") }
    static var noRecentCreatorWorks: String { text("No recent creator works") }
    static var viewAllWorks: String { text("View All Works") }
    static var viewAll: String { text("View All") }
    static var creatorFilter: String { text("Creator Filter") }
    static var creatorSort: String { text("Creator Sort") }
    static var resetCreatorFilters: String { text("Reset Creator Filters") }
    static var resetCreatorFiltersDone: String { text("Reset creator filters") }
    static var refreshedCreatorsFormat: String { text("Refreshed %d creators") }
    static var allCreators: String { text("All Creators") }
    static var unfollowed: String { text("Unfollowed") }
    static var defaultOrder: String { text("Default Order") }
    static var previewWorks: String { text("Preview Works") }
    static var searchCreatorsInList: String { text("Search creators in this list") }
    static var creatorActions: String { text("Creator Actions") }
    static var creatorSelection: String { text("Creator Selection") }
    static var selectedCreatorsFormat: String { text("%d selected creators") }
    static var noSelectedCreators: String { text("No selected creators") }
    static var selectCreator: String { text("Select Creator") }
    static var deselectCreator: String { text("Deselect Creator") }
    static var checkFollowVisibility: String { text("Check Follow Visibility") }
    static var checkingFollowVisibility: String { text("Checking follow visibility") }
    static var followSelectedPublicly: String { text("Follow Selected Publicly") }
    static var followSelectedPrivately: String { text("Follow Selected Privately") }
    static var muteSelectedCreators: String { text("Mute Selected Creators") }
    static var unfollowSelectedCreators: String { text("Unfollow Selected Creators") }
    static var copySelectedCreatorLinks: String { text("Copy Selected Creator Links") }
    static var copySelectedCreatorSummary: String { text("Copy Selected Creator Summary") }
    static var runningCreatorAction: String { text("Updating creators") }
    static var noCreatorLinksToCopy: String { text("No creator links to copy") }
    static var noCreatorSummariesToCopy: String { text("No creator summaries to copy") }
    static var noFollowedCreatorsToCheck: String { text("No followed creators to check") }
    static var noMatchingCreatorsForAction: String { text("No matching creators for this action") }
    static var publicFollow: String { text("Public Follow") }
    static var privateFollow: String { text("Private Follow") }
    static var followSelectedPubliclyConfirmationFormat: String { text("Follow %d selected creators publicly?") }
    static var followSelectedPrivatelyConfirmationFormat: String { text("Follow %d selected creators privately?") }
    static var muteSelectedCreatorsConfirmationFormat: String { text("Mute %d selected creators?") }
    static var unfollowSelectedCreatorsConfirmationFormat: String { text("Unfollow %d selected creators?") }
    static var creatorActionCompletedFormat: String { text("Updated %d creators") }
    static var copiedCreatorLinksFormat: String { text("Copied %d creator links") }
    static var copiedCreatorSummaryFormat: String { text("Copied %d creator summaries") }
    static var pinCreator: String { text("Pin Creator") }
    static var unpinCreator: String { text("Unpin Creator") }
    static var pinnedCreatorFormat: String { text("Pinned %@") }
    static var unpinnedCreatorFormat: String { text("Unpinned %@") }
    static var noPinnedCreators: String { text("No pinned creators") }
    static var noPinnedCreatorsHint: String { text("Pin creators from recommended, search, following, or profile views to build a local creator collection.") }
    static var creatorListDetailHint: String { text("Use the creator cards to open profiles, illustrations, manga, or Pixiv links without leaving this list.") }
    static var followVisibilityUpdatedFormat: String { text("Checked follow visibility for %d creators") }
    static var followVisibilityPartiallyUpdatedFormat: String { text("Checked follow visibility for %d creators, %d failed") }
    static var followedCreatorFormat: String { text("Followed %@") }
    static var followedCreatorsFormat: String { text("Followed %d creators") }
    static var updatedCreatorFollowVisibilityFormat: String { text("Updated follow visibility for %@") }
    static var restoredCreatorActionsFormat: String { text("Restored %d creator actions") }
    static var unfollowCreatorConfirmationFormat: String { text("Unfollow %@?") }
    static var muteCreatorConfirmationFormat: String { text("Mute %@?") }
    static var unfollowedCreatorFormat: String { text("Unfollowed %@") }
    static var unfollowedCreatorsFormat: String { text("Unfollowed %d creators") }
    static var mutedCreatorFormat: String { text("Muted %@") }
    static var mutedCreatorsFormat: String { text("Muted %d creators") }
    static var removeBookmarkConfirmationFormat: String { text("Remove bookmark from %@?") }
    static var muteArtworkConfirmationFormat: String { text("Mute artwork %@?") }
    static var muteTagConfirmationFormat: String { text("Mute tag #%@?") }
    static var removedBookmarkFormat: String { text("Removed bookmark from %@") }
    static var mutedArtworkFormat: String { text("Muted artwork %@") }
    static var mutedTagFormat: String { text("Muted tag #%@") }
    static var rankingDateFallbackMessage: String { text("Selected ranking date was unavailable. Showing the latest ranking.") }
    static var undo: String { text("Undo") }
    static var worksCount: String { text("Works Count") }
    static var publicSaves: String { text("Public Saves") }
    static var followers: String { text("Followers") }
    static var region: String { text("Region") }
    static var job: String { text("Job") }
    static var links: String { text("Links") }
    static var workspace: String { text("Workspace") }
    static var tool: String { text("Tool") }
    static var tablet: String { text("Tablet") }
    static var mouse: String { text("Mouse") }
    static var workspaceComment: String { text("Workspace Comment") }
    static var settings: String { text("Settings") }
    static var searchSettings: String { text("Search settings") }
    static var settingsGeneral: String { text("General") }
    static var settingsDiscovery: String { text("Discovery") }
    static var settingsSafety: String { text("Safety") }
    static var settingsPrivacy: String { text("Privacy") }
    static var settingsAdvancedQA: String { text("Advanced QA") }
    static var noMatchingSettings: String { text("No matching settings") }
    static var noMatchingSettingsHint: String { text("Change the settings search to show other controls.") }
    static var showSidebar: String { text("Show Sidebar") }
    static var hideSidebar: String { text("Hide Sidebar") }
    static var language: String { text("Language") }
    static var automatic: String { text("Automatic") }
    static var simplifiedChinese: String { text("Simplified Chinese") }
    static var traditionalChinese: String { text("Traditional Chinese") }
    static var japanese: String { text("Japanese") }
    static var english: String { text("English") }
    static var appearance: String { text("Appearance") }
    static var theme: String { text("Theme") }
    static var themeSystem: String { text("System") }
    static var themeLight: String { text("Light") }
    static var themeDark: String { text("Dark") }
    static var themeHint: String { text("Apply a fixed light or dark mode inside KeiPix while leaving the system appearance unchanged.") }
    static var useOriginalImages: String { text("Use original images in detail") }
    static var useOriginalImagesForManga: String { text("Use original images for manga") }
    static var imageQualityHint: String { text("Pick a default per content type — illust details and multi-page manga can use different quality presets.") }
    static var imageQualityOriginal: String { text("Original Quality") }
    static var imageQualityStandard: String { text("Standard Quality") }
    static var imageQualityToggleHint: String { text("Toggle between Pixiv's original image and the standard preview while reading.") }
    static var imageQualityTierMedium: String { text("Medium") }
    static var imageQualityTierLarge: String { text("Large") }
    static var imageQualityTierOriginal: String { text("Original") }
    static var imageQualityTierSection: String { text("Image Quality") }
    static var feedPreviewQuality: String { text("Feed preview quality") }
    static var illustDetailQuality: String { text("Illust detail quality") }
    static var mangaDetailQuality: String { text("Manga detail quality") }
    static var imageQualityTierHint: String { text("Pixiv ships every illust at three sizes. Pick the rung that matches your bandwidth — Medium loads fastest, Original is the source asset.") }
    static var imageProcessing: String { text("Image Processing") }
    static var imageProcessorsEnabled: String { text("Enable image processing") }
    static var imageProcessorsHint: String { text("Apply visual enhancements to decoded images using Core Image and Vision filters. Changes take effect on newly loaded images.") }
    static var smartCrop: String { text("Smart Crop") }
    static var imageSharpen: String { text("Sharpen") }
    static var imageDenoise: String { text("Noise Reduction") }
    static var novelInlineTranslate: String { text("Inline Translate") }
    static var novelInlineTranslateHelp: String { text("Show translated text above each paragraph") }
    static var novelTranslateBilingual: String { text("Bilingual") }
    static var novelTranslateBilingualHelp: String { text("Show original and translated text together") }
    static var novelTranslateImmersive: String { text("Immersive") }
    static var novelTranslateImmersiveHelp: String { text("Replace original text with translation") }
    static var novelTranslating: String { text("Translating…") }
    static var imageTransform: String { text("Image Transform") }
    static var rotateLeft: String { text("Rotate Left") }
    static var rotateRight: String { text("Rotate Right") }
    static var flipHorizontal: String { text("Flip Horizontal") }
    static var flipVertical: String { text("Flip Vertical") }
    static var resetTransform: String { text("Reset Transform") }
    static var translate: String { text("Translate") }
    static var translating: String { text("Translating…") }
    static var translationFailed: String { text("Translation unavailable") }
    static var novelTranslationUnsupportedSourceLanguage: String { text("Apple Translation does not support this source language.") }
    static var novelTranslationUnsupportedTargetLanguage: String { text("Apple Translation does not support this target language.") }
    static var novelTranslationUnsupportedLanguagePair: String { text("Apple Translation does not support this language pair.") }
    static var novelTranslationCannotIdentifyLanguage: String { text("Apple Translation could not identify this text language.") }
    static var novelTranslationNothingToTranslate: String { text("No translatable novel text was found.") }
    static var novelTranslationModelNotInstalled: String { text("Apple Translation needs a language model. Approve the system download, then try again.") }
    static var novelTranslationCancelled: String { text("Translation was cancelled.") }
    static var translationTargetLanguage: String { text("Translation Language") }
    static var translationTargetLanguageHint: String { text("Translation Language Hint") }
    static var translationTargetSystem: String { text("System") }
    static var clearNovelTranslationCache: String { text("Clear Novel Translation Cache") }
    static var novelTranslationCacheCleared: String { text("Novel translation cache cleared") }
    static var translationProgressFormat: String { text("translationProgressFormat") }
    static var downloadSelectedPages: String { text("Save Selected Pages…") }
    static var selectPagesToSave: String { text("Select Pages to Save") }
    static var selectAllPages: String { text("Select All") }
    static var clearPageSelection: String { text("Clear Selection") }
    static var pagesSelectedFormat: String { text("%d of %d pages selected") }
    static var blockFromArtwork: String { text("Block From This Artwork…") }
    static var blockSelected: String { text("Block Selected") }
    static var blockSelectedHint: String { text("Mute the artwork, its creator, or any of its tags in one step. Each entry stays in your local mute list until you remove it.") }
    static var blockArtworkOption: String { text("Block this artwork") }
    static var blockCreatorOption: String { text("Block creator") }
    static var blockTagsHeader: String { text("Block Tags") }
    static var bulkBlockNothingSelected: String { text("Pick at least one item to block.") }
    static var bulkBlockSummaryFormat: String { text("Blocked %d item(s).") }
    static var commentRegexHint: String { text("Wrap a phrase in /slashes/ to match as a regular expression — e.g. /^spam.*/i.") }
    static var showTranslatedTags: String { text("Show translated tag names") }
    static var contentFilters: String { text("Content Filters") }
    static var showContentBadges: String { text("Show content badges") }
    static var hideMutedContent: String { text("Hide muted content") }
    static var hideAIArtworks: String { text("Hide AI-generated artworks") }
    static var pixivAIDisplay: String { text("Pixiv AI Display") }
    static var pixivAIDisplayHint: String { text("Toggles the account-wide AI display on Pixiv. When off, Pixiv hides AI-generated artworks across every client signed into the account.") }
    static var pixivAIDisplayUnknownHint: String { text("Sign in with a real Pixiv account to manage account-wide AI visibility.") }
    static var aiVisibilityLocalHidden: String { text("Local AI artworks hidden") }
    static var aiVisibilityLocalVisible: String { text("Local AI artworks visible") }
    static var hideR18Artworks: String { text("Hide R-18 artworks") }
    static var hideR18GArtworks: String { text("Hide R-18G artworks") }
    static var maskSensitivePreviews: String { text("Mask R-18 previews") }
    static var maskSensitivePreviewsHint: String { text("Blur R-18 and R-18G thumbnails while keeping metadata and actions visible.") }
    static var r18PreviewHidden: String { text("R-18 preview hidden") }
    static var r18gPreviewHidden: String { text("R-18G preview hidden") }
    static var pixivRestrictedMode: String { text("Pixiv Restricted Mode") }
    static var pixivRestrictedModeHint: String { text("Syncs Pixiv account restricted mode for adult content visibility across clients.") }
    static var searchFilters: String { text("Search Filters") }
    static var activeSearchFilters: String { text("Active Search Filters") }
    static var filterSummary: String { text("Filter Summary") }
    static var searchFiltersReset: String { text("Search filters reset") }
    static var searchFiltersApplied: String { text("Search filters applied") }
    static var matchType: String { text("Match Type") }
    static var partialTagMatch: String { text("Partial tag match") }
    static var exactTagMatch: String { text("Exact tag match") }
    static var titleAndCaption: String { text("Title and caption") }
    static var sort: String { text("Sort") }
    static var newest: String { text("Newest") }
    static var oldest: String { text("Oldest") }
    static var popular: String { text("Popular") }
    static var popularMale: String { text("Popular (Male)") }
    static var popularFemale: String { text("Popular (Female)") }
    static var popularLimitedPreview: String { text("Popular (limited preview)") }
    static var popularPreview: String { text("Popular Preview") }
    static var popularPreviewHint: String { text("Top works for this search") }
    static var popularLimitedPreviewHint: String { text("Popular uses Pixiv's limited preview without Premium. Full gender popular sorting requires Pixiv Premium.") }
    static var showPopularResults: String { text("Show Popular Results") }
    static var ageLimit: String { text("Age Limit") }
    static var unlimited: String { text("Unlimited") }
    static var dateRange: String { text("Date Range") }
    static var anytime: String { text("Anytime") }
    static var pastDay: String { text("Past Day") }
    static var pastWeek: String { text("Past Week") }
    static var pastMonth: String { text("Past Month") }
    static var pastYear: String { text("Past Year") }
    static var minimumBookmarks: String { text("Minimum Bookmarks") }
    static var maximumBookmarks: String { text("Maximum Bookmarks") }
    static var noMinimum: String { text("No minimum") }
    static var noMaximum: String { text("No maximum") }
    static var noBookmarkLimit: String { text("No bookmark limit") }
    static var bookmarkAtLeastFormat: String { text("≥ %@ bookmarks") }
    static var bookmarkAtMostFormat: String { text("≤ %@ bookmarks") }
    static var bookmarkBetweenFormat: String { text("%@ – %@ bookmarks") }
    static var bookmarkPresetUnlimited: String { text("No limit") }
    static var bookmarkCustomValue: String { text("Custom value") }
    static var bookmarkInvalidRange: String { text("Maximum must be greater than minimum.") }
    static var engineSauceNAO: String { text("SauceNAO") }
    static var engineAscii2D: String { text("Ascii2D") }
    static var imageSourceSearchEngine: String { text("Image Source Engine") }
    static var openInAscii2D: String { text("Open Ascii2D") }
    static var copyAscii2DLink: String { text("Copy Ascii2D Link") }
    static var workType: String { text("Work Type") }
    static var allWorks: String { text("All Works") }
    static var aiFilter: String { text("AI Filter") }
    static var excludeAI: String { text("Exclude AI") }
    static var onlyAI: String { text("Only AI") }
    static var ugoiraFilter: String { text("Ugoira Filter") }
    static var all: String { text("All") }
    static var onlyUgoira: String { text("Only Ugoira") }
    static var noUgoira: String { text("No Ugoira") }
    static var reset: String { text("Reset") }
    static var apply: String { text("Apply") }
    static var artwork: String { text("Artwork") }
    static var selectArtwork: String { text("Select Artwork") }
    static var navigation: String { text("Navigation") }
    static var goBack: String { text("Go Back") }
    static var goForward: String { text("Go Forward") }
    static var previousArtwork: String { text("Previous Artwork") }
    static var nextArtwork: String { text("Next Artwork") }
    static var readerWindow: String { text("Reader Window") }
    static var openReaderWindow: String { text("Open Reader Window") }
    static var layout: String { text("Layout") }
    static var galleryLayout: String { text("Gallery Layout") }
    static var emphasizeFollowingArtists: String { text("Emphasize artworks from following artists") }
    static var emphasizeFollowingArtistsHint: String {
        text("Adds an accent border and a Following badge so artists you follow stand out in mixed feeds.")
    }
    static var followingArtistBadge: String { text("Following Artist Badge") }
    static var followingArtistEmphasizedHelp: String { text("You follow this artist") }
    static var auto: String { text("Auto") }
    static var twoColumns: String { text("Two Columns") }
    static var threeColumns: String { text("Three Columns") }
    static var creatorListLayout: String { text("Creator Layout") }
    static var creatorLayoutAuto: String { text("Auto Fit") }
    static var creatorLayoutSingle: String { text("Single Card") }
    static var creatorLayoutTwoUp: String { text("Two Cards") }
    static var spotlightListLayout: String { text("Article Layout") }
    static var compact: String { text("Compact") }
    static var compactCards: String { text("Compact artwork cards") }
    static var waterfall: String { text("Waterfall") }
    static var listRow: String { text("List") }
    static var windowSize: String { text("Window Size") }
    static var smallWindow: String { text("Small") }
    static var balancedWindow: String { text("Balanced") }
    static var wideWindow: String { text("Wide") }
    static var readingWindow: String { text("Reading") }
    static var defaultArtworkReadingMode: String { text("Default Artwork Reading Mode") }
    static var defaultMangaReadingMode: String { text("Default Manga Reading Mode") }
    static var defaultReadingModeHint: String { text("Changing the reader mode in an artwork updates the matching default for future works.") }
    static var restoreLastReadPage: String { text("Restore Last Read Page") }
    static var restoreLastReadPageHint: String { text("Reopen multi-page artworks on the last page read on this Mac.") }
    static var trackpad: String { text("Trackpad") }
    static var enableTrackpadGestures: String { text("Enable trackpad gestures") }
    static var twoFingerSwipeBehavior: String { text("Two-finger swipe behavior") }
    static var pageOnlySwipe: String { text("Page within artwork") }
    static var pageThenArtworkSwipe: String { text("Switch artwork at edges") }
    static var privacy: String { text("Privacy") }
    static var privacyHint: String { text("Manage how KeiPix handles your account identity, screen capture, and Pixiv visibility on this Mac.") }
    static var openPrivacySettings: String { text("Open Privacy Settings") }
    static var privacyAndIdentity: String { text("Privacy & Identity") }
    static var relatedSettings: String { text("Related Settings") }
    static var account: String { text("Account") }
    static var accountMode: String { text("Account Mode") }
    static var realAccount: String { text("Real Account") }
    static var realAccountSubtitle: String { text("Use Pixiv sessions saved in this app's secure storage.") }
    static var guestAccount: String { text("Guest Account") }
    static var guestAccountSubtitle: String { text("Preview KeiPix with local sample artworks.") }
    static var testModeAccount: String { text("Test Mode Account") }
    static var testModeAccountSubtitle: String { text("Run repeatable QA surfaces with local fixtures.") }
    static var addAccount: String { text("Add Account") }
    static var importToken: String { text("Import Token") }
    static var importTokenHint: String { text("Paste a Pixiv refresh token exported from another client. KeiPix refreshes it once, saves the new session in secure local storage, and switches to the imported account.") }
    static var copyRefreshToken: String { text("Copy Refresh Token") }
    static var copyRefreshTokenHint: String { text("Copy the current Pixiv refresh token so you can paste it into KeiPix on your iPad. Treat it like a password and clear the clipboard after transferring it.") }
    static var copyRefreshTokenConfirmationMessage: String { text("This copies a long-lived Pixiv credential. Only paste it into KeiPix on a device you control.") }
    static var copiedRefreshToken: String { text("Copied Refresh Token") }
    static var pixivWebSession: String { text("Pixiv Web Session") }
    static var connectPixivWebSession: String { text("Connect Pixiv Web Session") }
    static var disconnectPixivWebSession: String { text("Disconnect Pixiv Web Session") }
    static var savePixivWebSession: String { text("Save Pixiv Web Session") }
    static var connectPixivWebSessionHint: String { text("Sign in on Pixiv Web, then save this session so KeiPix can sync Web-only activity and collection lists.") }
    static var pixivWebSessionSettingsHint: String { text("Required only for Pixiv Web-only features such as saved collections. KeiPix stores this separately from the app API token and never imports browser cookies automatically.") }
    static var pixivWebSessionConnected: String { text("Connected") }
    static var pixivWebSessionNotConnected: String { text("Not connected") }
    static var pixivWebSessionNoCookies: String { text("No Pixiv Web cookies were found yet. Sign in on the page first, then save again.") }
    static var pixivWebSessionConnectionFailed: String { text("Pixiv Web session connection failed.") }
    static var pixivWebSessionMissingLoginCookie: String { text("Pixiv Web login cookie was not found. Sign in on Pixiv Web first.") }
    static var pixivWebSessionNotSignedIn: String { text("Pixiv Web did not open the signed-in activity page. Sign in on the page first, then save again.") }
    static var editProfileOnPixiv: String { text("Edit Profile on Pixiv") }
    static var enable: String { text("Enable") }
    static var disable: String { text("Disable") }
    static var manageAccountOnPixiv: String { text("Manage Account on Pixiv") }
    static var accountWebSettingsHint: String { text("Profile, password, and email changes happen on the Pixiv website. KeiPix opens the relevant page in your browser.") }
    static var spotlightCategoryAll: String { text("All") }
    static var spotlightCategoryIllust: String { text("Illust") }
    static var spotlightCategoryManga: String { text("Manga") }
    static var spotlightCategoryCosplay: String { text("Cosplay") }
    static var shareSummary: String { text("Share Summary") }
    static var shareSummaryHint: String { text("Share a formatted title, author, and link using your Sharing copy template.") }
    static var openAtLaunch: String { text("Open at Launch") }
    static var openAtLaunchHint: String { text("KeiPix opens to this destination after launch. Sign-in flows still send you home until a session is restored.") }
    static var pinTag: String { text("Pin Tag") }
    static var unpinTag: String { text("Unpin Tag") }
    static var pinnedTags: String { text("Pinned Tags") }
    static var pinnedTagFormat: String { text("Pinned %@") }
    static var unpinnedTagFormat: String { text("Unpinned %@") }

    // Bookmark editor tag-source sections
    static var bookmarkTagSectionRecommended: String { text("Recommended") }
    static var bookmarkTagSectionRecommendedHint: String { text("Tags this artwork shares with your bookmark library — usually the safest picks.") }
    static var bookmarkTagSectionArtwork: String { text("From This Artwork") }
    static var bookmarkTagSectionArtworkHint: String { text("Tags Pixiv attached to the artwork that you have not used in your bookmarks before.") }
    static var bookmarkTagSectionLibrary: String { text("From Your Library") }
    static var bookmarkTagSectionLibraryHint: String { text("Tags you've used elsewhere — pick one to file this artwork under an existing category.") }
    static var bookmarkTagSectionCustom: String { text("Custom Tags") }
    static var bookmarkTagSectionCustomHint: String { text("Free-form tags you typed in this session.") }
    static var bookmarkTagAddAll: String { text("Add All") }
    static var bookmarkTagRemoveAll: String { text("Remove All") }
    static var bookmarkTagSelectionSummaryFormat: String { text("%d selected") }
    static var bookmarkTagNoCandidates: String { text("No tags from this source. Type your own below.") }
    static var bookmarkTagFilterPlaceholder: String { text("Filter tags") }
    static var refreshToken: String { text("Refresh Token") }
    static var currentAccount: String { text("Current Account") }
    static var switchAccount: String { text("Switch Account") }
    static var removeAccount: String { text("Remove Account") }
    static var switchedAccountFormat: String { text("Switched to %@") }
    static var removedAccountFormat: String { text("Removed account %@") }
    static var removeAccountConfirmationFormat: String { text("Remove account %@ from this Mac?") }
    static var privacyMode: String { text("Privacy Mode") }
    static var appControls: String { text("App Controls") }
    static var enablePrivacyMode: String { text("Enable Privacy Mode") }
    static var disablePrivacyMode: String { text("Disable Privacy Mode") }
    static var privacyModeHint: String { text("Quickly hides sidebar account identity for screenshots and screen sharing.") }
    static var protectSensitiveContent: String { text("Protect sensitive content from screen capture") }
    static var screenCaptureProtectionHint: String { text("R-18 and R-18G artwork windows are hidden from screenshots and screen sharing when possible.") }
    static var showAccountIdentity: String { text("Show account identity") }
    static var accountIdentityPrivacyHint: String { text("Hide your Pixiv name and ID in the sidebar for screenshots.") }
    static var runtimeReadiness: String { text("Runtime Readiness") }
    static var runtimeReadinessHint: String { text("Quick diagnostics for signed-in QA and screenshot-safe support reports.") }
    static var copyDiagnostics: String { text("Copy Diagnostics") }
    static var copiedDiagnostics: String { text("Copied Diagnostics") }
    static var saveDiagnostics: String { text("Save Diagnostics") }
    static var savedDiagnostics: String { text("Saved Diagnostics") }
    static var unableToSaveDiagnostics: String { text("Unable to save diagnostics") }
    static var runNetworkDiagnostics: String { text("Run Network Diagnostics") }
    static var runningDiagnostics: String { text("Running diagnostics") }
    static var runAccountHealthDiagnostics: String { text("Run Account Health Check") }
    static var runningAccountHealthDiagnostics: String { text("Running account health check") }
    static var accountTokenRefresh: String { text("Account Token Refresh") }
    static var savedSession: String { text("Saved session") }
    static var runReadOnlyQA: String { text("Run Read-only QA") }
    static var runningReadOnlyQA: String { text("Running read-only QA") }
    static var runNonNovelQAMatrix: String { text("Run Non-Novel QA Matrix") }
    static var runningNonNovelQAMatrix: String { text("Running non-novel QA matrix") }
    static var nonNovelQAMatrix: String { text("Non-Novel QA Matrix") }
    static var nonNovelQAMatrixHint: String { text("Tracks the P0/P1/P2 non-novel gaps from the Pixez and Pixes comparison with current evidence.") }
    static var copyQAMatrix: String { text("Copy QA Matrix") }
    static var copiedQAMatrix: String { text("Copied QA Matrix") }
    static var needsEvidence: String { text("Needs Evidence") }
    static var actionRequired: String { text("Action Required") }
    static var priority: String { text("Priority") }
    static var area: String { text("Area") }
    static var status: String { text("Status") }
    static var evidence: String { text("Evidence") }
    static var nextAction: String { text("Next Action") }
    static var notRun: String { text("Not run") }
    static var signInAndRunQA: String { text("Sign in and run QA") }
    static var reviewImplementation: String { text("Review implementation") }
    static var keepRegressionCoverage: String { text("Keep regression coverage") }
    static var qaLoadedCountFormat: String { text("%d loaded") }
    static var visualQAEvidenceFormat: String { text("Visual QA %d/%d · latest %@") }
    static var visualQAMissing: String { text("Visual QA missing") }
    static var runSearchDiagnostics: String { text("Run Search Diagnostics") }
    static var runningSearchDiagnostics: String { text("Running search diagnostics") }
    static var pixivPremiumRequired: String { text("Pixiv Premium required") }
    static var pixivPremiumSortsRequirePremium: String { text("Full popular sorting requires Pixiv Premium") }
    static var searchDiagnosticResultFormat: String { text("%d results for %@") }
    static var runMutableActionQA: String { text("Run Reversible Mutable QA") }
    static var runningMutableActionQA: String { text("Running reversible mutable QA") }
    static var mutableActionQAAuthorization: String { text("Authorize Mutable QA") }
    static var mutableActionQAAuthorizationHint: String { text("Runs private bookmark add/remove and private follow/unfollow on the selected artwork and creator. Use a disposable Pixiv test account.") }
    static var mutableActionQAAuthorizationPrompt: String { text("Type TEST ACCOUNT to continue") }
    static var selectUnbookmarkedArtworkForQA: String { text("Select an unbookmarked artwork for reversible QA") }
    static var selectUnfollowedCreatorForQA: String { text("Select an artwork by an unfollowed creator for reversible QA") }
    static var privateBookmarkRoundTripCompleted: String { text("Private bookmark add/remove completed") }
    static var privateFollowRoundTripCompleted: String { text("Private follow/unfollow completed") }
    static var runIDNavigationDiagnostics: String { text("Run ID Navigation Diagnostics") }
    static var runningIDNavigationDiagnostics: String { text("Running ID navigation diagnostics") }
    static var runCommentFeedbackDiagnostics: String { text("Run Comment Feedback Diagnostics") }
    static var runningCommentFeedbackDiagnostics: String { text("Running comment feedback diagnostics") }
    static var previewCommentFeedback: String { text("Preview Comment Feedback") }
    static var loadingCommentFeedbackPreview: String { text("Loading comment feedback preview") }
    static var commentFeedbackDiagnostic: String { text("Comment feedback") }
    static var commentFeedbackReadyFormat: String { text("Comment #%d feedback ready") }
    static var invalidResponse: String { text("Invalid response") }
    static var refreshCacheStatus: String { text("Refresh Cache Status") }
    static var clearImageCache: String { text("Clear Image Cache") }
    static var imageCacheCleared: String { text("Image cache cleared") }
    static var imageCache: String { text("Image Cache") }
    static var cacheUsageFormat: String { text("%@ used of %@") }
    static var availableInDiagnostics: String { text("Available in diagnostics") }
    static var mutableActionReadiness: String { text("Mutable Action Readiness") }
    static var mutableActionReadinessHint: String { text("Remote or destructive actions stay visible in QA until a test account or explicit approval covers them.") }
    static var copyQAReviewChecklist: String { text("Copy QA Checklist") }
    static var copiedQAReviewChecklist: String { text("Copied QA Checklist") }
    static var verified: String { text("Verified") }
    static var needsTestAccount: String { text("Needs Test Account") }
    static var needsExplicitApproval: String { text("Needs Explicit Approval") }
    static var qaDownloadQueue: String { text("Download queue") }
    static var qaDownloadQueueDetail: String { text("Queueing downloads is covered by read-only runtime QA.") }
    static var qaFollowToggle: String { text("Follow and unfollow") }
    static var qaFollowToggleDetail: String { text("Requires a disposable Pixiv test account.") }
    static var qaBookmarkToggle: String { text("Bookmark add and remove") }
    static var qaBookmarkToggleDetail: String { text("Requires a disposable Pixiv test account.") }
    static var qaCommentPost: String { text("Comment posting") }
    static var qaCommentPostDetail: String { text("Requires explicit approval for remote write verification.") }
    static var qaDownloadDelete: String { text("Download deletion") }
    static var qaDownloadDeleteDetail: String { text("Requires explicit approval before deleting local files.") }
    static var qaMuteSync: String { text("Mute sync") }
    static var qaMuteSyncDetail: String { text("Read-only remote diagnostics are available. Import and upload still require explicit approval.") }
    static var qaNativeAppleRoute: String { text("Native Apple route") }
    static var qaNativeAppleRouteRequirement: String { text("KeiPix stays a SwiftPM macOS app built with Swift, SwiftUI, and narrow AppKit/WebKit bridges.") }
    static var qaNativeAppleRouteNext: String { text("Keep source-boundary tests current when referencing Pixez or Pixes behavior.") }
    static var qaNativeAppleRouteEvidence: String { text("SwiftPM macOS 26 · Swift + SwiftUI · no Flutter/Dart source in KeiPix") }
    static var qaGalleryVisual: String { text("Gallery visual surfaces") }
    static var qaGalleryVisualRequirement: String { text("Masonry, hot tags, Pixivision, and wide/tall mixed cards render without overlap, gray gutters, or clipped text.") }
    static var qaGalleryVisualNext: String { text("Capture visual QA screenshots for hot tags and wide feeds.") }
    static var qaTrendingTags: String { text("Trending tags") }
    static var qaTrendingTagsRequirement: String { text("Hot tag cards load preview artwork and route searches in-app.") }
    static var qaTrendingTagsNext: String { text("Run hot tag route and visual QA.") }
    static var qaPixivision: String { text("Pixivision") }
    static var qaPixivisionRequirement: String { text("Articles open in-app and Pixiv artwork/user/tag links route natively.") }
    static var qaPixivisionNext: String { text("Open an article and verify native link routing.") }
    static var pixivisionNativeLinkAuditFormat: String { text("Native article links: %@") }
    static var noNativeArticleLinks: String { text("No native article links found") }
    static var qaPixivURLRouting: String { text("Pixiv URL routing") }
    static var qaPixivURLRoutingRequirement: String { text("Artwork, creator, tag, search, and Pixivision URLs resolve to native destinations.") }
    static var qaPixivURLRoutingNext: String { text("Keep resolver tests and in-app link checks current.") }
    static var qaAccountHealth: String { text("Account health") }
    static var qaAccountHealthRequirement: String { text("Stored session can refresh account data without repeated authorization prompts.") }
    static var qaAccountHealthNext: String { text("Run account health QA after sign-in.") }
    static var qaMangaFeeds: String { text("Manga feeds and watchlist") }
    static var qaMangaFeedsRequirement: String { text("Recommended manga, manga rankings, series, and watchlist remain reachable.") }
    static var qaMangaFeedsNext: String { text("Keep watchlist update badges in regression coverage.") }
    static var qaReader: String { text("Reader") }
    static var qaReaderRequirement: String { text("Multi-page reader supports per-page aspect ratio, continuous reading, keyboard, and trackpad gestures.") }
    static var qaReaderNext: String { text("Keep reader window visual evidence and resume in regression coverage.") }
    static var qaSearch: String { text("Search") }
    static var qaSearchRequirement: String { text("Artwork search covers match mode, sort, AI/R18, bookmark counts, saved searches, and autocomplete.") }
    static var qaSearchNext: String { text("Add saved preset import and export.") }
    static var qaBookmarks: String { text("Bookmarks") }
    static var qaBookmarksRequirement: String { text("Public/private bookmarks, bookmark tags, and bookmark automation remain reachable.") }
    static var qaBookmarksNext: String { text("Keep bookmark and download automation in regression coverage.") }
    static var qaFollowingCreators: String { text("Following creators") }
    static var qaFollowingCreatorsRequirement: String { text("Follow lists, recommended creators, creator search, and follow visibility stay usable.") }
    static var qaFollowingCreatorsNext: String { text("Keep pinned creator collections in regression coverage.") }
    static var qaDownloads: String { text("Downloads") }
    static var qaDownloadsRequirement: String { text("Queue, local library, naming templates, ugoira downloads, and batch actions stay usable.") }
    static var qaDownloadsNext: String { text("Keep download queue visual evidence in regression coverage.") }
    static var qaUgoiraRequirement: String { text("Ugoira playback, speed controls, ZIP/GIF export, and frame export stay reachable.") }
    static var qaUgoiraNext: String { text("Keep Ugoira player visual evidence in regression coverage.") }
    static var qaSafetyFiltering: String { text("Safety and filtering") }
    static var qaSafetyFilteringRequirement: String { text("AI/R18/R18G badges, filters, mute sync, and privacy controls remain visible.") }
    static var qaSafetyFilteringNext: String { text("Add bulk mute previews.") }
    static var qaIllustFeeds: String { text("Illustration feeds") }
    static var qaIllustFeedsRequirement: String { text("Recommended illustrations and latest illustrations load through native feeds.") }
    static var qaIllustFeedsNext: String { text("Keep feed QA evidence current.") }
    static var qaRanking: String { text("Ranking") }
    static var qaRankingRequirement: String { text("Illustration and manga ranking routes load and support date/mode switching.") }
    static var qaRankingNext: String { text("Keep ranking route QA evidence current.") }
    static var qaFollowingFeed: String { text("Following feed") }
    static var qaFollowingFeedRequirement: String { text("Public/private/all following artwork feeds remain reachable.") }
    static var qaFollowingFeedNext: String { text("Run following-feed QA with a signed-in account.") }
    static var qaCreatorDiscovery: String { text("Creator discovery") }
    static var qaCreatorDiscoveryRequirement: String { text("Recommended creators, search creators, related creators, and creator previews remain reachable.") }
    static var qaCreatorDiscoveryNext: String { text("Keep creator route QA evidence current.") }
    static var qaArtworkDetailSocial: String { text("Artwork detail and social") }
    static var qaArtworkDetailSocialRequirement: String { text("Detail inspector, tags, creator actions, comments, related works, feedback, and local mute actions remain reachable.") }
    static var qaArtworkDetailSocialNext: String { text("Run detail QA on the selected artwork.") }
    static var qaCommentsFeedback: String { text("Comments and feedback") }
    static var qaCommentsFeedbackRequirement: String { text("Comments, replies, feedback summaries, and local comment mute flows remain reachable.") }
    static var qaCommentsFeedbackNext: String { text("Keep comment emoji, stamp, feedback, and local mute coverage current.") }
    static var qaLocalCacheOffline: String { text("Local cache and offline") }
    static var qaLocalCacheOfflineRequirement: String { text("Image cache, history, downloads, and last successful surfaces support offline-friendly review.") }
    static var qaLocalCacheOfflineNext: String { text("Keep feed snapshot cache in regression coverage.") }
    static var qaSettingsOrganization: String { text("Settings organization") }
    static var qaSettingsOrganizationRequirement: String { text("Reading, discovery, safety, downloads, privacy, and QA controls stay grouped in native Settings.") }
    static var qaSettingsOrganizationNext: String { text("Keep Settings search and grouping in regression coverage.") }
    static var qaImageQualityTier: String { text("Image quality tiers") }
    static var qaImageQualityTierRequirement: String { text("Feed preview, illust detail, and manga detail each persist a Medium / Large / Original tier and stay aligned with the legacy HD/Standard toggle.") }
    static var qaImageQualityTierNext: String { text("Keep the lock-step between the tier picker and the legacy preferOriginal flag in regression coverage.") }
    static var qaCaptionTranslation: String { text("Caption translation") }
    static var qaCaptionTranslationRequirement: String { text("Apple's system translation sheet stays reachable on artwork captions and comments, gated to skip empty / emoji-only text.") }
    static var qaCaptionTranslationNext: String { text("Keep the translatable-text gate in regression coverage so we never surface a no-op Translate button.") }
    static var qaCaptionTranslationEvidence: String { text("CaptionTranslationAvailability accepts Pixiv caption shapes and rejects emoji-only blurbs.") }
    static var qaFollowingEmphasis: String { text("Following-artist emphasis") }
    static var qaFollowingEmphasisRequirement: String {
        text("Cards from artists the user follows pick up an accent border and a Following badge in mixed feeds, and the toggle round-trips through UserDefaults.")
    }
    static var qaFollowingEmphasisNext: String {
        text("Keep emphasizeFollowingArtists in lock-step with its persisted value so a profile sync never loses the visual treatment.")
    }
    static var qaTransferableDragDrop: String { text("Transferable drag and drop") }
    static var qaTransferableDragDropRequirement: String {
        text("Pixiv-link drops resolve through Transferable on every drop surface, and completed downloads + artwork cards drag out as native file or URL payloads.")
    }
    static var qaTransferableDragDropNext: String {
        text("Keep PixivLinkDropPayload and the artwork drag URL covered so a future ProxyRepresentation refactor doesn't silently break Finder drops.")
    }
    static var qaTransferableDragDropEvidence: String {
        text("PixivLinkDropPayload resolves URL and text shapes; download rows and artwork cards expose Transferable drag sources.")
    }
    static var quickLook: String { text("Quick Look") }
    static var quickLookHint: String { text("Press Space to peek the file with Quick Look, just like Finder.") }
    static var qaQuickLook: String { text("Quick Look preview") }
    static var qaQuickLookRequirement: String {
        text("Completed downloads expose file preview through Quick Look in the More menu, context menu, and Space-bar handler, opening Apple's system preview panel.")
    }
    static var qaQuickLookNext: String {
        text("Keep DownloadQueueView's quickLookURL binding and focus-driven Space handler covered so Apple's preview panel never falls back to a third-party fallback.")
    }
    static var qaQuickLookEvidence: String {
        text("Each completed row resolves a Quick Look URL and surfaces the More-menu preview entry, context-menu entry, and Space-bar handler.")
    }
    static var qaDownloadThroughput: String { text("Live download throughput") }
    static var qaDownloadThroughputRequirement: String {
        text("Active downloads display a sliding-window byte-per-second readout per row and an aggregate rate in the queue subtitle, just like Finder.")
    }
    static var qaDownloadThroughputNext: String {
        text("Keep DownloadThroughputSampler wired through ArtworkDownloadStore.download(_:sourceURLs:) and reset on pause / cancel / complete so the speedometer never lies.")
    }
    static var qaDownloadThroughputEvidence: String {
        text("Throughput sampler records per-page bytes and exposes per-item plus aggregate rates that the queue surfaces.")
    }
    static var qaDownloadFinishNotification: String { text("Notification Center banner on download finish") }
    static var qaDownloadFinishNotificationRequirement: String {
        text("DownloadCompletionNotifier coalesces completed-download titles into a single banner per quiescent burst, gated on the user's opt-in toggle and Apple's authorization state.")
    }
    static var qaDownloadFinishNotificationNext: String {
        text("Keep ArtworkDownloadStore.markCompleted wired through DownloadCompletionNotifier so a finished download still hands off to UNUserNotificationCenter.")
    }
    static var qaDownloadFinishNotificationEvidence: String {
        text("Notifier records every markCompleted call and posts one Notification Center request per debounce window.")
    }
    static var network: String { text("Network") }
    static var proxyConfiguration: String { text("Proxy") }
    static var proxyConfigurationModeSystem: String { text("Follow System") }
    static var proxyConfigurationModeDirect: String { text("Direct (No Proxy)") }
    static var proxyConfigurationModeManual: String { text("Manual") }
    static var proxyHost: String { text("Host") }
    static var proxyPort: String { text("Port") }
    static var proxyScheme: String { text("Scheme") }
    static var proxySchemeHTTP: String { text("HTTP") }
    static var proxySchemeHTTPS: String { text("HTTPS") }
    static var proxySchemeSOCKS5: String { text("SOCKS5") }
    static var proxyConfigurationHint: String {
        text("Routes Pixiv API and image traffic through the chosen proxy. \"Follow System\" honours macOS network settings; manual mode and direct mode take effect after relaunching KeiPix.")
    }
    static var proxyConfigurationRestartHint: String {
        text("Quit and reopen KeiPix to apply proxy changes.")
    }
    static var proxyHostPlaceholder: String { text("127.0.0.1") }
    static var proxyPortPlaceholder: String { text("7890") }
    static var qaProxyConfiguration: String { text("App-level proxy override") }
    static var qaProxyConfigurationRequirement: String {
        text("Pixiv API and image-host URLSessions read the persisted proxy snapshot at init so manual / direct overrides apply on the next app launch.")
    }
    static var qaProxyConfigurationNext: String {
        text("Keep ProxyConfiguration.loadFromUserDefaults wired through PixivAPI.init and ImagePipeline.init so the proxy mode never silently regresses to system on launch.")
    }
    static var qaProxyConfigurationEvidence: String {
        text("Persisted proxy mode round-trips through KeiPixStore and produces the expected connectionProxyDictionary shape per scheme.")
    }
    static var checkForUpdates: String { text("Check for Updates…") }
    static var checkingForUpdates: String { text("Checking for updates…") }
    static var checkForUpdatesOnLaunch: String { text("Check for updates on launch") }
    static var checkForUpdatesOnLaunchHint: String {
        text("Once a day, KeiPix asks GitHub whether a newer release has been published. " +
             "Disable this to skip the check entirely.")
    }
    static var updateAvailableTitle: String { text("A new KeiPix release is available") }
    static var updateAvailableMessageFormat: String {
        text("Version %@ is now available. You're running %@.")
    }
    static var openReleaseNotes: String { text("Open Release Notes") }
    static var skipThisVersion: String { text("Skip This Version") }
    static var remindLater: String { text("Later") }
    static var noUpdatesAvailableTitle: String { text("KeiPix is up to date") }
    static var noUpdatesAvailableMessageFormat: String {
        text("You're running the latest released version (%@).")
    }
    static var updateCheckFailedTitle: String { text("Couldn't check for updates") }
    static var updateCheckFailedMessage: String {
        text("KeiPix couldn't reach GitHub. Check your network or proxy settings and try again.")
    }
    static var releasePublishedAtFormat: String { text("Published %@") }
    static var qaReleaseUpdateCheck: String { text("GitHub release update check") }
    static var qaReleaseUpdateCheckRequirement: String {
        text("On launch, KeiPix asks GitHub for the latest release once per 24-hour window, " +
             "compares it to the running CFBundleShortVersionString, and surfaces a banner " +
             "with Open Release Notes / Skip / Later actions when a newer tag is published.")
    }
    static var qaReleaseUpdateCheckNext: String {
        text("Keep ReleaseUpdateChecker wired through KeiPixApp.task and respect the " +
             "checkForUpdatesOnLaunch toggle plus the skipped-version memory so users can opt out.")
    }
    static var qaReleaseUpdateCheckEvidence: String {
        text("SemanticVersion comparator, JSON decoder, and 24-hour throttle round-trip in the unit suite.")
    }

    // MARK: - Keyboard shortcuts

    static var settingsKeyboard: String { text("Keyboard") }
    static var keyboardCustomization: String { text("Keyboard Shortcuts") }
    static var keyboardCustomizationHint: String {
        text("Every menu shortcut below can be re-bound from System Settings → Keyboard → Keyboard Shortcuts → " +
             "App Shortcuts. Pick KeiPix from the application list and enter the menu item title exactly as " +
             "shown to assign a new key combination.")
    }
    static var openKeyboardSystemSettings: String { text("Open Keyboard Shortcut Settings…") }
    static var keyboardReaderInlineHint: String {
        text("Inline reader keys aren't menu items, so macOS can't rebind them. They're listed for reference only.")
    }
    static var shortcutSurfaceMain: String { text("App Commands") }
    static var shortcutSurfaceReaderInline: String { text("Reader Inline Keys") }
    static var shortcutTogglePrivacyMode: String { text("Toggle Privacy Mode") }
    static var shortcutTogglePauseDownloads: String { text("Toggle Pause Downloads") }
    static var readerJumpToPage: String { text("Jump to Page…") }
    static var readerToggleFullscreen: String { text("Toggle Fullscreen Reading") }
    static var qaShortcutCatalog: String { text("Keyboard shortcut catalog") }
    static var qaShortcutCatalogRequirement: String {
        text("Every menu and reader keyboard shortcut routes through KeyboardShortcutCatalog so the Settings → " +
             "Keyboard page never drifts from the bindings the menu bar actually fires.")
    }
    static var qaShortcutCatalogNext: String {
        text("Keep new menu items registered in KeyboardShortcutCatalog and surface them through .shortcut(_:) " +
             "instead of inline .keyboardShortcut(_:modifiers:) calls.")
    }
    static var qaShortcutCatalogEvidence: String {
        text("Catalog covers every ShortcutAction case, surfaces are well-formed, and System Settings deep-link " +
             "URL parses in the unit suite.")
    }

    // MARK: - About window

    static var aboutKeiPix: String { text("About KeiPix") }
    static var openMainWindow: String { text("Open Main Window") }
    static var quitKeiPix: String { text("Quit KeiPix") }
    static func versionLabel(_ value: String) -> String {
        String(format: text("Version %@"), locale: Locale.current, value)
    }
    static func buildLabel(_ value: String) -> String {
        String(format: text("Build %@"), locale: Locale.current, value)
    }
    static func revisionLabel(_ value: String) -> String {
        String(format: text("Revision %@"), locale: Locale.current, value)
    }
    static var aboutSummary: String {
        text("KeiPix is a native Pixiv client for macOS, iPadOS, and iOS.")
    }
    static var aboutPlatformMacOS: String { text("macOS 26") }
    static var aboutPlatformiPadOS: String { text("iPadOS 26") }
    static var aboutPlatformiOS: String { text("iOS 26") }
    static var aboutSourceRepository: String { text("Source Repository") }
    static var aboutOpenOnGitHub: String { text("Open on GitHub") }
    static var aboutCopyRepositoryURL: String { text("Copy Repository URL") }
    static var aboutRepositoryCopied: String { text("Repository URL copied") }
    static var aboutRepositoryBody: String {
        text("The project is developed in the open on GitHub. File issues, inspect commits, or review the Apache-2.0 source from the repository.")
    }
    static var aboutAcknowledgments: String { text("Acknowledgments") }
    static var aboutReferenceProjects: String { text("Reference Projects") }
    static var aboutReferenceProjectsBody: String {
        text("Pixez is GPL-3.0 and Pixes is MIT-licensed; both are behavior references only. " +
             "KeiPix's source is original Swift; reference-client implementation paths are blocked " +
             "by NativeBoundaryTests.")
    }
    static var aboutLocalization: String { text("Localization") }
    static var aboutLocalizationBody: String {
        text("English, Simplified Chinese, Traditional Chinese, Japanese.")
    }
    static var aboutLicense: String { text("License") }
    static var aboutApacheLicenseTitle: String { text("Apache License 2.0") }
    static var aboutLicenseBody: String {
        text("KeiPix is licensed under the Apache License, Version 2.0. You may use, modify, and distribute it under the license terms.")
    }
    static var aboutOpenLicense: String { text("Open License") }
    static var aboutCopyLicenseSummary: String { text("Copy License Summary") }
    static var aboutLicenseCopied: String { text("License summary copied") }
    static var aboutPlatformSupport: String { text("Platform Support") }
    static var aboutPlatformSupportBody: String {
        text("The interface is tuned separately for Mac windows, iPad multitasking, and iPhone-size layouts while sharing one codebase.")
    }
    static var aboutDesignPrinciples: String { text("Design Principles") }
    static var aboutDesignPrinciplesBody: String {
        text("High-frequency browsing and reading paths prefer AppKit/UIKit-backed native behavior, with SwiftUI composing the app chrome and settings surfaces.")
    }
    static var aboutCopyVersionInfo: String { text("Copy Version Info") }
    static var aboutVersionInfoCopied: String { text("Version info copied") }
    static var aboutCopyDiagnostics: String { text("Copy Diagnostics Bundle") }
    static var aboutDiagnosticsCopied: String { text("Diagnostics copied") }
    static var aboutDiagnosticsOS: String { text("OS") }
    static var aboutDiagnosticsLocale: String { text("Locale") }
    static var aboutDiagnosticsRepository: String { text("Repository") }
    static var aboutDiagnosticsLicense: String { text("License") }
    static var aboutDiagnosticsBuildCode: String { text("Build Code") }
    static var aboutDiagnosticsBuildSource: String { text("Build Source") }
    static var aboutDiagnosticsCommit: String { text("Commit") }

    // MARK: - Log viewer

    static var logs: String { text("Logs") }
    static var openLogViewer: String { text("Open Log Viewer") }
    static var refreshLogs: String { text("Refresh Logs") }
    static var filterLogs: String { text("Filter logs") }
    static var allCategories: String { text("All Categories") }
    static var minLevel: String { text("Min Level") }
    static var logLevelDebug: String { text("Debug") }
    static var logLevelInfo: String { text("Info") }
    static var logLevelNotice: String { text("Notice") }
    static var logLevelDefault: String { text("Default") }
    static var logLevelError: String { text("Error") }
    static var logLevelFault: String { text("Fault") }
    static var noLogEntries: String { text("No log entries") }
    static var noLogEntriesHint: String {
        text("KeiPix hasn't emitted any matching log entries since launch.")
    }
    static var logAccessUnavailable: String { text("Log access unavailable") }
    static var logAccessUnavailableHint: String {
        text("OSLogStore couldn't be opened. This usually means the app needs to be relaunched after install or that the system log database is sealed.")
    }
    static var copyVisibleLogs: String { text("Copy Visible Logs") }
    static var revealInConsole: String { text("Reveal in Console") }
    static var logsCopied: String { text("Logs copied") }
    static var diagnostics: String { text("Diagnostics") }
    static var logViewerSummary: String {
        text("View runtime diagnostics emitted by KeiPix's subsystem (com.keipix.client). Useful for filing bug reports without leaving the app.")
    }
    static var systemProxy: String { text("System Proxy") }
    static var directConnection: String { text("Direct connection") }
    static var pixivAPI: String { text("Pixiv API") }
    static var imageHost: String { text("Image Host") }
    static var pixivAppAPIHost: String { text("Pixiv App API Host") }
    static var pixivOAuthHost: String { text("Pixiv OAuth Host") }
    static var pixivWebHost: String { text("Pixiv Web Host") }
    static var pixivImageCDNHost: String { text("Pixiv Image CDN Host") }
    static var pixivHostDiagnosticHTTPStatusFormat: String { text("%@ · HTTP %d · Proxy: %@") }
    static var pixivHostDiagnosticTransportErrorFormat: String { text("%@ · %@ · Proxy: %@") }
    static var reachable: String { text("Reachable") }
    static var skipped: String { text("Skipped") }
    static var passed: String { text("Passed") }
    static var unknown: String { text("Unknown") }
    static var noArtworkForImageProbe: String { text("Open an artwork to test the image host") }
    static var session: String { text("Session") }
    static var signedIn: String { text("Signed In") }
    static var signedOut: String { text("Signed Out") }
    static var currentRoute: String { text("Current Route") }
    static var currentArtwork: String { text("Current Artwork") }
    static var feed: String { text("Feed") }
    static var feedReadinessFormat: String { text("%d shown · %d loaded · %@") }
    static var loadedCachedFeedFormat: String { text("Loaded cached feed %@ · %d works · %@") }
    static var cachedFeed: String { text("Cached Feed") }
    static var showingCachedFeedFormat: String { text("Showing cached feed %@ · %d works · saved %@") }
    static var cachedFeedReadOnlyHint: String { text("This feed is restored from the last successful load and stays read-only until refresh succeeds.") }
    static var refreshLiveFeed: String { text("Refresh Live Feed") }
    static var selectedArtwork: String { text("Selected Artwork") }
    static var noSelection: String { text("No Selection") }
    static var pageCountFormat: String { text("%d pages") }
    static var pageCountShortFormat: String { text("%dP") }
    static func pageCountShort(_ n: Int) -> String { String(format: text("%dP"), n) }
    static var pageTotalFormat: String { text("/ %d") }
    static func pageTotal(_ count: Int) -> String { String(format: text("/ %d"), count) }
    static var pageOfTotalFormat: String { text("%d / %d") }
    static func pageOfTotal(_ page: Int, _ total: Int) -> String { String(format: text("%d / %d"), page, total) }
    static var commentDraftCountFormat: String { text("%d / 140") }
    static func commentDraftCount(_ current: Int) -> String { String(format: text("%d / 140"), current) }
    static var creatorPageHeaderFormat: String { text("%@ · %dP") }
    static func creatorPageHeader(_ name: String, _ pages: Int) -> String { String(format: text("%@ · %dP"), name, pages) }
    static var aiBadge: String { text("AI") }
    static var pixivSection: String { text("Pixiv") }
    static var pixivIllustRefFormat: String { text("illust/%d") }
    static func pixivIllustRef(_ id: Int) -> String { String(format: text("illust/%d"), id) }
    static var downloadReadinessFormat: String { text("%d total · %d active · %d completed") }
    static var accountIdentityHidden: String { text("Account identity hidden") }
    static var screenProtection: String { text("Screen protection") }
    static var enabled: String { text("Enabled") }
    static var disabled: String { text("Disabled") }
    static var profile: String { text("Profile") }
    static var hidden: String { text("Hidden") }
    static var loginTitle: String { text("Login to Pixiv") }
    static var loginHint: String { text("Complete login in the embedded Pixiv page. KeiPix captures only the authorization code.") }
    static var signedOutTitle: String { text("Sign in to load Pixiv feeds") }
    static var signedOutSubtitle: String { text("KeiPix saves Pixiv tokens inside the sandboxed app container and uses native Pixiv app API requests.") }
    static var searchPlaceholder: String { text("Search artworks, tags, creators, or illust:123") }
    static var noArtworkTitle: String { text("No artworks loaded") }
    static var noArtworkSubtitle: String { text("Refresh the current section or start a search.") }
    static var errorTitle: String { text("Request failed") }
    static var errorRateLimited: String { text("Too many requests. Please try again later.") }
    static var errorSessionExpired: String { text("Session expired. Please log in again.") }
    static var copyError: String { text("Copy Error") }
    static var copiedError: String { text("Copied Error") }
    static var copied: String { text("Copied") }
    static var loadMore: String { text("Load More") }
    static var publicBookmarks: String { text("Public bookmarks") }
    static var privateBookmarks: String { text("Private bookmarks") }
    static var allFollowing: String { text("All Following") }
    static var publicFollowing: String { text("Public Following") }
    static var privateFollowing: String { text("Private Following") }
    static var rankingDate: String { text("Ranking Date") }
    static var rankingMode: String { text("Ranking Mode") }
    static var useRankingDate: String { text("Use Ranking Date") }
    static var latestRanking: String { text("Latest Ranking") }
    static var latestRankingApplied: String { text("Showing latest ranking") }
    static var rankingModeAppliedFormat: String { text("Showing ranking: %@") }
    static var rankingDateAppliedFormat: String { text("Showing ranking for %@") }
    static var rankingDateRangeFormat: String { text("Available from %@ to %@") }
    static var previousDay: String { text("Previous Day") }
    static var nextDay: String { text("Next Day") }
    static var daily: String { text("Daily") }
    static var weekly: String { text("Weekly") }
    static var monthly: String { text("Monthly") }
    static var forMale: String { text("For Male") }
    static var forFemale: String { text("For Female") }
    static var originals: String { text("Originals") }
    static var rookies: String { text("Rookies") }
    static var dailyAI: String { text("Daily AI") }
    static var dailyR18AI: String { text("Daily R-18 AI") }
    static var dailyR18: String { text("Daily R-18") }
    static var weeklyR18: String { text("Weekly R-18") }
    static var weeklyR18G: String { text("Weekly R-18G") }
    static var dailyManga: String { text("Daily Manga") }
    static var weeklyManga: String { text("Weekly Manga") }
    static var monthlyManga: String { text("Monthly Manga") }
    static var dailyR18Manga: String { text("Daily R-18 Manga") }
    static var weeklyAI: String { text("Weekly AI") }
    static var weeklyR18AI: String { text("Weekly R-18 AI") }

    // MARK: - Novels

    static var novels: String { text("Novels") }
    static var novel: String { text("Novel") }
    static var novelRanking: String { text("Novel Ranking") }
    static var recommendedNovels: String { text("Recommended Novels") }
    static var latestNovels: String { text("Latest Novels") }
    static var followingNovels: String { text("Following Novels") }
    static var searchNovels: String { text("Search Novels") }
    static var novelLanguage: String { text("Novel Language") }
    static var anyNovelLanguage: String { text("Any Novel Language") }
    static var novelGenre: String { text("Novel Genre") }
    static var anyNovelGenre: String { text("Any Novel Genre") }
    static var novelLanguageFormat: String { text("Novel language: %@") }
    static var novelGenreFormat: String { text("Novel genre: %@") }
    static var novelTextLength: String { text("Novel Text Length") }
    static var anyNovelTextLength: String { text("Any Novel Length") }
    static var novelTextLengthMicro: String { text("Under 5,000 Characters") }
    static var novelTextLengthShort: String { text("5,000-19,999 Characters") }
    static var novelTextLengthMedium: String { text("20,000-79,999 Characters") }
    static var novelTextLengthLong: String { text("80,000+ Characters") }
    static var novelBookmarks: String { text("Novel Bookmarks") }
    static var novelPublicBookmarks: String { text("Public Novel Bookmarks") }
    static var novelPrivateBookmarks: String { text("Private Novel Bookmarks") }
    static var novelWatchlist: String { text("Novel Watchlist") }
    static var creatorNovels: String { text("Creator Novels") }
    static var creatorNovelBookmarks: String { text("Creator Novel Bookmarks") }
    static var openNovel: String { text("Open Novel") }
    static var selectNovel: String { text("Select a novel") }
    static var openInPixivNovel: String { text("Open Novel in Pixiv") }
    static var copyNovelLink: String { text("Copy Novel Link") }
    static var copiedNovelLink: String { text("Copied novel link") }
    static var novelLength: String { text("Length") }
    static var novelTextLengthFormat: String { text("%d characters") }
    static var novelPageCountFormat: String { text("%d pages") }
    static var novelOriginalBadge: String { text("Original") }
    static var novelChapterFormat: String { text("Chapter: %@") }
    static var novelSeries: String { text("Series") }
    static var novelSeriesFormat: String { text("Series: %@") }
    static var novelSeriesChapters: String { text("Series Chapters") }
    static var novelSeriesChapterCountFormat: String { text("%d chapters") }
    static var novelSeriesCharacterCountFormat: String { text("%d characters total") }
    static var novelSeriesCompleted: String { text("Completed Series") }
    static var currentChapter: String { text("Current Chapter") }
    static var openLatestNovelChapter: String { text("Open Latest Chapter") }
    static var noSeriesChapters: String { text("No series chapters") }
    static var noSeriesChaptersHint: String { text("This series has no readable chapters yet.") }
    static var novelPreviousInSeries: String { text("Previous in Series") }
    static var novelNextInSeries: String { text("Next in Series") }
    static var novelEnd: String { text("End") }
    static var novelEnableWatchlist: String { text("Add to Watchlist") }
    static var novelDisableWatchlist: String { text("Remove from Watchlist") }
    static var novelWatchlistAddedFormat: String { text("Added %@ to watchlist") }
    static var novelWatchlistRemovedFormat: String { text("Removed %@ from watchlist") }
    static var novelBookmark: String { text("Bookmark Novel") }
    static var novelRemoveBookmark: String { text("Remove Novel Bookmark") }
    static var novelExport: String { text("Export Novel") }
    static var novelExportTXT: String { text("Export as TXT") }
    static var novelExportMarkdown: String { text("Export as Markdown") }
    static var novelExportHTML: String { text("Export as HTML") }
    static var noNovels: String { text("No novels") }
    static var noNovelsHint: String { text("Pixiv hasn't returned any novels for this view yet.") }
    static var noMatchingNovels: String { text("No matching novels") }
    static var noMatchingNovelsHint: String { text("Change the novel filter to see other works.") }
    static var loadMoreNovels: String { text("Load More Novels") }
    static var loadedNovelsFormat: String { text("Loaded %d novels") }
    static var refreshedNovelsFormat: String { text("Refreshed %d novels") }
    static var novelText: String { text("Novel Text") }
    static var openNovelReader: String { text("Open Reader") }
    static var novelReaderSettings: String { text("Reader Settings") }
    static var novelReaderTextSize: String { text("Text Size") }
    static var novelReaderLineSpacing: String { text("Line Spacing") }
    static var novelReaderTheme: String { text("Reader Theme") }
    static var novelReaderThemeLight: String { text("Light") }
    static var novelReaderThemeSepia: String { text("Sepia") }
    static var novelReaderThemeDark: String { text("Dark") }
    static var novelReaderFontFamily: String { text("Font") }
    static var novelReaderFontSystem: String { text("System") }
    static var novelReaderFontSerif: String { text("Serif") }
    static var novelReaderFontMonospaced: String { text("Monospaced") }
    static var novelReaderUseVerticalLayout: String { text("Vertical layout") }
    static var novelReaderShowChapterMarkers: String { text("Show chapter markers") }
    static var novelReaderParagraphSpacing: String { text("Paragraph Spacing") }
    static var novelReaderMaxWidth: String { text("Max Width") }
    static var novelLoadingText: String { text("Loading novel text") }
    static var novelTextUnavailable: String { text("Novel text unavailable") }
    static var novelTextUnavailableHint: String { text("Pixiv didn't return body text for this novel.") }
    static var novelEmbeddedImage: String { text("Embedded image") }
    static var novelEmbeddedUploadedImage: String { text("Uploaded image") }
    static var novelJumpPageFormat: String { text("Jump to page %d") }
    static var novelPageProgressFormat: String { text("Page %d of %d") }
    static var relatedNovels: String { text("Related Novels") }
    static var noRelatedNovels: String { text("No related novels") }
    static var loadMoreRelatedNovels: String { text("Load More Related Novels") }
    static var workSubscriptionsUnsubscribe: String { text("Unsubscribe") }
    static var details: String { text("Details") }
    static var showDetails: String { text("Show Details") }
    static var hideDetails: String { text("Hide Details") }
    static var tags: String { text("Tags") }
    static var tagCountFormat: String { text("%d tags") }
    static var searchTag: String { text("Search Tag") }
    static var openTagInPixiv: String { text("Open Tag in Pixiv") }
    static var copyTagLink: String { text("Copy Tag Link") }
    static var copyTag: String { text("Copy Tag") }
    static var copyTranslatedTag: String { text("Copy Translated Tag") }
    static var description: String { text("Description") }
    static var artworkInformation: String { text("Artwork Information") }
    static var artworkCardHint: String { text("Tap to select artwork") }
    static var comments: String { text("Comments") }
    static var writeComment: String { text("Write a comment") }
    static var postComment: String { text("Post Comment") }
    static var postedComment: String { text("Posted comment") }
    static var noComments: String { text("No comments") }
    static var loadMoreComments: String { text("Load More Comments") }
    static var reply: String { text("Reply") }
    static var replyToFormat: String { text("Reply to %@") }
    static var cancelReply: String { text("Cancel Reply") }
    static var commentEmoji: String { text("Comment Emoji") }
    static var commentStamp: String { text("Comment Stamp") }
    static var viewReplies: String { text("View Replies") }
    static var hideReplies: String { text("Hide Replies") }
    static var noReplies: String { text("No replies") }
    static var copyComment: String { text("Copy Comment") }
    static var copiedComment: String { text("Copied comment") }
    static var deleteComment: String { text("Delete Comment") }
    static var deletedComment: String { text("Deleted comment") }
    static var postedStampComment: String { text("Posted stamp comment") }
    static var replies: String { text("Replies") }
    static var showComment: String { text("Show Comment") }
    static var muteCommentPhrase: String { text("Mute Comment Phrase") }
    static var hiddenCommentReasonFormat: String { text("Hidden comment: %@") }
    static var mutedCommentUserReasonFormat: String { text("muted creator %@") }
    static var mutedCommentPhraseReasonFormat: String { text("muted phrase %@") }
    static var relatedArtworks: String { text("Related Artworks") }
    static var noRelatedArtworks: String { text("No related artworks") }
    static var loadMoreRelatedArtworks: String { text("Load More Related Artworks") }
    static var series: String { text("Series") }
    static var artworkSeries: String { text("Artwork Series") }
    static var noSeriesArtworks: String { text("No series artworks") }
    static var noMatchingSeriesArtworks: String { text("No matching series artworks") }
    static var seriesSort: String { text("Series Sort") }
    static var seriesFilter: String { text("Series Filter") }
    static var seriesOrder: String { text("Series Order") }
    static var newestFirst: String { text("Newest First") }
    static var oldestFirst: String { text("Oldest First") }
    static var unreadWorks: String { text("Unread Works") }
    static var viewedWorks: String { text("Viewed Works") }
    static var seriesVisibleCountFormat: String { text("%d of %d shown") }
    static var loadMoreSeriesArtworks: String { text("Load More Series Artworks") }
    static var showSeries: String { text("Show Series") }
    static var addToWatchlist: String { text("Add to Watchlist") }
    static var addSeriesToWatchlist: String { text("Add Series to Watchlist") }
    static var watchlistAdded: String { text("Watchlist Added") }
    static var addedToWatchlistFormat: String { text("Added %@ to watchlist") }
    static var openSeriesInPixiv: String { text("Open Series in Pixiv") }
    static var copySeriesLink: String { text("Copy Series Link") }
    static var openLatestArtwork: String { text("Open Latest Artwork") }
    static var selectSeries: String { text("Select Series") }
    static var deselectSeries: String { text("Deselect Series") }
    static var updatedSeries: String { text("Updated") }
    static var noUpdates: String { text("No Updates") }
    static var unreadUpdates: String { text("Unread Updates") }
    static var seriesCount: String { text("Series Count") }
    static var unreadUpdatesFormat: String { text("%d unread") }
    static var markWatchlistRead: String { text("Mark as Read") }
    static var noWatchlistSeries: String { text("No watchlist series") }
    static var noMatchingWatchlistSeries: String { text("No matching watchlist series") }
    static var noMatchingWatchlistSeriesSubtitle: String { text("Change the watchlist search to see other series.") }
    static var searchWatchlistSeries: String { text("Search watchlist series") }
    static var resetWatchlistFilters: String { text("Reset Watchlist Filters") }
    static var resetWatchlistFiltersDone: String { text("Reset watchlist filters") }
    static var mangaWatchlistActions: String { text("Manga Watchlist Actions") }
    static var watchlistSelection: String { text("Watchlist Selection") }
    static var selectedSeriesFormat: String { text("%d selected series") }
    static var noSelectedSeries: String { text("No selected series") }
    static var shareSelectedSeries: String { text("Share Selected Series") }
    static var copySelectedSeriesLinks: String { text("Copy Selected Series Links") }
    static var noSeriesLinksToCopy: String { text("No series links to copy") }
    static var copiedSeriesLinksFormat: String { text("Copied %d series links") }
    static var removeSelectedWatchlistSeries: String { text("Remove Selected Series") }
    static var removeSelectedWatchlistSeriesConfirmationFormat: String { text("Remove %d selected series from watchlist?") }
    static var removedWatchlistSeriesFormat: String { text("Removed %d selected series from watchlist") }
    static var loadMoreWatchlist: String { text("Load More Watchlist") }
    static var loadedWatchlistSeriesFormat: String { text("Loaded %d watchlist series") }
    static var refreshedWatchlistSeriesFormat: String { text("Refreshed %d watchlist series") }
    static var removeFromWatchlist: String { text("Remove from Watchlist") }
    static var removeFromWatchlistConfirmationFormat: String { text("Remove %@ from watchlist?") }
    static var removedFromWatchlistFormat: String { text("Removed %@ from watchlist") }
    static var noCreators: String { text("No creators") }
    static var noMatchingCreators: String { text("No matching creators") }
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
    static var doublePage: String { text("Double Page") }
    static var continuousReading: String { text("Continuous Reading") }
    static var pageIndex: String { text("Page Index") }
    static var jumpToPage: String { text("Jump to Page") }
    static var pageJump: String { text("Page Jump") }
    static var goToPage: String { text("Go to Page") }
    static var fullScreenReading: String { text("Full Screen Reading") }
    static var snapToPages: String { text("Snap to Pages") }
    static var filterArtworks: String { text("Filter artworks...") }
    static var filterNovels: String { text("Filter novels...") }
    static var filterResults: String { text("Filter results...") }
    static var filterActivity: String { text("Filter activity...") }
    static var surpriseMe: String { text("Surprise Me") }
    static var randomFromFeed: String { text("Random") }
    static var exitFocusReading: String { text("Exit Focus Reading") }
    static var resetZoom: String { text("Reset Zoom") }
    static var toggleZoom: String { text("Toggle Zoom") }
    static var toggleReadingMode: String { text("Toggle Reading Mode") }
    static var revealCurrentPage: String { text("Reveal Current Page") }
    static var aiGenerated: String { text("AI generated") }
    static var r18: String { text("R-18") }
    static var r18g: String { text("R-18G") }
    static var ugoira: String { text("Ugoira") }
    static var muted: String { text("Muted") }
    static var mute: String { text("Mute") }
    static var muteArtwork: String { text("Mute Artwork") }
    static var muteCreator: String { text("Mute Creator") }
    static var unmuteCreator: String { text("Unmute Creator") }
    static var muteTag: String { text("Mute Tag") }
    static var bulkMutePreview: String { text("Bulk Mute Preview") }
    static var visibleArtworks: String { text("Visible Artworks") }
    static var visibleCreators: String { text("Visible Creators") }
    static var visibleTags: String { text("Visible Tags") }
    static var visibleArtworkCountFormat: String { text("%d visible works") }
    static var bulkMuteAffectedArtworkFormat: String { text("%d visible works will be affected") }
    static var noBulkMuteCandidates: String { text("No new mute candidates") }
    static var moreBulkMuteItemsFormat: String { text("+%d more candidates") }
    static var applyBulkMute: String { text("Apply Bulk Mute") }
    static var bulkMutedItemsFormat: String { text("Muted %d items") }
    static var mutedContent: String { text("Muted Content") }
    static var mutedTags: String { text("Muted Tags") }
    static var mutedCreators: String { text("Muted Creators") }
    static var mutedArtworks: String { text("Muted Artworks") }
    static var mutedCommentPhrases: String { text("Muted Comment Phrases") }
    static var openMutedContentManager: String { text("Open Muted Content Manager") }
    static var searchMutedContent: String { text("Search muted content") }
    static var pixivMuteSync: String { text("Pixiv mute sync") }
    static var addMutedTag: String { text("Add muted tag") }
    static var addMutedCommentPhrase: String { text("Add muted comment phrase") }
    static var addPhrase: String { text("Add Phrase") }
    static var alreadyMutedTagFormat: String { text("#%@ is already muted") }
    static var alreadyMutedCommentPhraseFormat: String { text("%@ is already muted") }
    static var deleteFromMutedContent: String { text("Delete from Muted Content") }
    static var syncFromPixiv: String { text("Sync from Pixiv") }
    static var uploadToPixiv: String { text("Upload to Pixiv") }
    static var syncMutedContentConfirmation: String { text("Sync muted content from Pixiv?") }
    static var syncMutedContentConfirmationMessage: String { text("This imports muted tags and creators from your Pixiv account into this Mac. You can undo the local changes after syncing.") }
    static var uploadMutedContentConfirmation: String { text("Upload local muted tags and creators to Pixiv?") }
    static var uploadMutedContentConfirmationMessage: String { text("This adds the local muted tags and creators to your Pixiv account.") }
    static var exportMutedContent: String { text("Export Muted Content") }
    static var importMutedContent: String { text("Import Muted Content") }
    static var importMutedContentConfirmation: String { text("Import muted content from file?") }
    static var importMutedContentConfirmationMessage: String { text("This replaces local muted content with the selected file. You can undo the local changes after importing.") }
    static var synced: String { text("Synced") }
    static var uploaded: String { text("Uploaded") }
    static var exported: String { text("Exported") }
    static var imported: String { text("Imported") }
    static var muteSyncHint: String { text("Pixiv sync covers muted tags and creators. Local muted artworks stay on this Mac.") }
    static var clearMutedContent: String { text("Clear Muted Content") }
    static var clearMutedContentConfirmation: String { text("Clear all muted content?") }
    static var clearedMutedContentItemsFormat: String { text("Cleared %d muted items") }
    static var removeMutedTagConfirmationFormat: String { text("Remove muted tag #%@?") }
    static var removeMutedCreatorConfirmationFormat: String { text("Remove muted creator %@?") }
    static var removeMutedArtworkConfirmationFormat: String { text("Remove muted artwork %@?") }
    static var removeMutedCommentPhraseConfirmationFormat: String { text("Remove muted comment phrase %@?") }
    static var removedMutedTagFormat: String { text("Removed muted tag #%@") }
    static var removedMutedCreatorFormat: String { text("Removed muted creator %@") }
    static var removedMutedArtworkFormat: String { text("Removed muted artwork %@") }
    static var removedMutedCommentPhraseFormat: String { text("Removed muted comment phrase %@") }
    static var mutedCommentPhraseFormat: String { text("Muted comment phrase %@") }
    static var mutedContentSnapshotChangedFormat: String { text("Changed muted content; previous snapshot had %d items") }
    static var noMutedContent: String { text("No muted content") }
    static var noMutedContentHint: String { text("Mute artworks, creators, or tags from artwork menus, or add tags here.") }
    static var mutedContentCountFormat: String { text("%d muted items") }
    static var contentRating: String { text("Content Rating") }
    static var imageSize: String { text("Image Size") }
    static var allAges: String { text("All Ages") }
    static var yes: String { text("Yes") }
    static var no: String { text("No") }
    static var done: String { text("Done") }
    static var playUgoira: String { text("Play Ugoira") }
    static var pauseUgoira: String { text("Pause Ugoira") }
    static var reloadUgoira: String { text("Reload Ugoira") }
    static var loadingUgoira: String { text("Loading Ugoira") }
    static var retry: String { text("Retry") }
    static var ok: String { text("OK") }
    static var created: String { text("Created") }
    static var artworkID: String { text("Artwork ID") }
    static var creatorID: String { text("Creator ID") }
    static var results: String { text("Results") }
    static var nextPageAvailable: String { text("More available") }
    static var noMorePages: String { text("End of feed") }

    static var settingsStorage: String { text("Storage") }
    static var storageOverview: String { text("Storage Overview") }
    static var totalCacheSize: String { text("Total Cache Size") }
    static var storageHint: String { text("KeiPix can rebuild every cache below from Pixiv on demand. Clearing one frees space; clearing all reverts the app to a clean install state without touching your bookmarks, downloads, or muted lists.") }
    static var clearCategory: String { text("Clear") }
    static var clearAllCaches: String { text("Clear All Caches") }
    static var clearedCacheCategoryFormat: String { text("Cleared %@") }
    static var clearedAllCaches: String { text("Cleared all caches") }
    static var nothingToClear: String { text("Nothing to clear") }

    static var cacheImageTitle: String { text("Image cache") }
    static var cacheImageDetail: String { text("Decoded thumbnails kept in memory and the on-disk URLCache used by the image pipeline. Re-downloads transparently next time an artwork is viewed.") }
    static var cacheFeedSnapshotsTitle: String { text("Offline feed snapshots") }
    static var cacheFeedSnapshotsDetail: String { text("Recent feed pages saved locally so the app can keep working when the network drops. Cleared snapshots reload the next time the feed comes back online.") }
    static var cacheBrowsingHistoryTitle: String { text("Browsing history") }
    static var cacheBrowsingHistoryDetail: String { text("Local list of artworks you've opened. Used by the History sidebar entry; clearing wipes that list without affecting Pixiv's server-side history.") }
    static var cacheSearchHistoryTitle: String { text("Search history") }
    static var cacheSearchHistoryDetail: String { text("Recent search queries that surface as suggestions in the search field. Clearing removes the suggestion list; saved searches stay put.") }
    static var cacheArtworkDetailStateTitle: String { text("Artwork detail UI state") }
    static var cacheArtworkDetailStateDetail: String { text("Per-artwork remembered section expansion (tags, comments, related). Clearing returns every artwork's detail page to its default layout.") }
    static var cacheNovelTextTitle: String { text("Novel Text Cache") }
    static var cacheNovelTextDetail: String { text("Cached novel body text for offline reading. Clearing requires re-downloading novels from Pixiv.") }
    static var itemCountFormat: String { text("%d items") }
    static var noStoredItems: String { text("No stored items") }

    static var spotlightIndexing: String { text("Spotlight Indexing") }
    static var spotlightIndexingDownloads: String { text("Index downloaded artworks in Spotlight") }
    static var spotlightIndexingHint: String { text("When on, completed downloads appear as Spotlight results so Cmd+Space can find them by title, creator, or tag. KeiPix never indexes hidden categories — flipping a Hide AI / R-18 / R-18G toggle automatically removes that content from the system index. Clearing wipes every KeiPix entry from Spotlight without touching the downloads themselves.") }
    static var spotlightRebuildIndex: String { text("Rebuild Spotlight Index") }
    static var spotlightClearIndex: String { text("Clear Spotlight Index") }

    static var backupAndRestore: String { text("Backup & Restore") }
    static var backupHint: String { text("Export every locally-stored library — saved searches, browsing history, pinned creators, reader progress, manga read state, muted content, and the bookmark/follow defaults you've tuned — into one JSON file. Importing merges back into the running session without overwriting bits that already exist.") }
    static var exportBackup: String { text("Export Backup…") }
    static var importBackup: String { text("Import Backup…") }
    static var exportedBackupFormat: String { text("Exported backup with %d entries") }
    static var importedBackupFormat: String { text("Imported %d entries from backup") }
    static var unableToExportBackup: String { text("Unable to export backup") }
    static var unableToImportBackup: String { text("Unable to import backup") }
    static var backupUnsupportedSchemaFormat: String { text("Backup uses schema v%d but this build only supports v%d. Update KeiPix and try again.") }
    static var backupDecodingFailedFormat: String { text("Couldn't read the backup file: %@") }

    // MARK: - Intent / Shortcuts

    static var intentOpenPixivLink: String { text("Open Pixiv Link") }
    static var intentOpenPixivLinkDescription: String { text("Open a Pixiv URL or artwork ID in KeiPix.") }
    static var intentLinkParamTitle: String { text("Link") }
    static var intentLinkParamDescription: String { text("A Pixiv URL or artwork ID.") }
    static var intentOpenArtwork: String { text("Open Artwork in Reader") }
    static var intentOpenArtworkDescription: String { text("Open a Pixiv artwork in its own reader window.") }
    static var intentArtworkParamTitle: String { text("Artwork") }
    static var intentArtworkParamDescription: String { text("A Pixiv artwork ID or URL.") }
    static var intentRefreshFeed: String { text("Refresh Current Feed") }
    static var intentRefreshFeedDescription: String { text("Reload the feed currently shown in KeiPix's main window.") }
    static var intentNotPixivLink: String { text("intentNotPixivLink") }
    static var intentNotReady: String { text("intentNotReady") }
    static var intentNoArtworkIDFormat: String { text("intentNoArtworkIDFormat") }
    static var intentOpenedArtworkFormat: String { text("intentOpenedArtworkFormat") }
    static var intentNotRunning: String { text("intentNotRunning") }
    static var intentRefreshed: String { text("intentRefreshed") }

    // MARK: - Error descriptions

    static var errorGitHubNonHTTP: String { text("errorGitHubNonHTTP") }
    static var errorGitHubHTTPFormat: String { text("errorGitHubHTTPFormat") }
    static var errorGitHubJSONShape: String { text("errorGitHubJSONShape") }
    static var errorGitHubMalformedTagFormat: String { text("errorGitHubMalformedTagFormat") }
    static var errorLoginRequired: String { text("errorLoginRequired") }
    static var errorLoginVerifierMissing: String { text("errorLoginVerifierMissing") }
    static var errorInvalidPixivResponse: String { text("errorInvalidPixivResponse") }
    static var errorHTTPFormat: String { text("errorHTTPFormat") }
    static var errorEncodeSession: String { text("errorEncodeSession") }
    static var errorDecodeSession: String { text("errorDecodeSession") }

    // MARK: - Keyboard key names

    static var keyLeftArrow: String { text("keyLeftArrow") }
    static var keyRightArrow: String { text("keyRightArrow") }
    static var keyUpArrow: String { text("keyUpArrow") }
    static var keyDownArrow: String { text("keyDownArrow") }
    static var keyEscape: String { text("keyEscape") }
    static var keySpace: String { text("keySpace") }
    static var keyReturn: String { text("keyReturn") }

    // MARK: - Web link labels

    static var linkUserPrefixFormat: String { text("linkUserPrefixFormat") }
    static var linkCollectionPrefixFormat: String { text("Collection %@") }
    static var linkPixivisionPrefixFormat: String { text("linkPixivisionPrefixFormat") }

    // MARK: - Format / unit strings

    static func downloadProgressFormat(_ completed: Int, _ total: Int) -> String {
        String(format: text("downloadProgressFormat"), locale: Locale.current, completed, total)
    }
    static var ugoiraNoFrames: String { text("ugoiraNoFrames") }
    static func ugoiraPositionFormat(_ current: Int, _ total: Int, _ duration: String) -> String {
        String(format: text("ugoiraPositionFormat"), locale: Locale.current, current, total, duration)
    }
    static var millisecondsUnit: String { text("millisecondsUnit") }

    static func pageStatus(_ page: Int, _ count: Int) -> String {
        String(format: text("Page %d of %d"), locale: Locale.current, page, count)
    }

    static func text(_ key: String, table: String? = nil) -> String {
        let selected = UserDefaults.standard.string(forKey: "appLanguage")
            .flatMap(AppLanguage.init(rawValue:)) ?? .automatic
        let resourceBundle = Bundle.keipixResources
        if let lprojName = selected.lprojName,
           let path = resourceBundle.path(forResource: lprojName.lowercased(), ofType: "lproj") ?? resourceBundle.path(forResource: lprojName, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle.localizedString(forKey: key, value: key, table: table)
        }
        return resourceBundle.localizedString(forKey: key, value: key, table: table)
    }
}

extension Bundle {
    /// Resource bundle that holds localized `.lproj/<table>.strings` files
    /// compiled out of the string catalogs by the `XCStringsBuilder` SwiftPM
    /// plugin, regardless of whether the app is built via Swift Package
    /// Manager (where `Bundle.module` is generated) or Xcode (where resources
    /// live in the main app bundle).
    static var keipixResources: Bundle {
        #if SWIFT_PACKAGE
        return .module
        #else
        return .main
        #endif
    }
}
