import Foundation

enum L10n {
    static var explore: String { text("Explore") }
    static var works: String { text("Works") }
    static var illustrations: String { text("Illustrations") }
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
    static var savedArticles: String { text("Saved Articles") }
    static var articleHistory: String { text("Article History") }
    static var saveArticle: String { text("Save Article") }
    static var removeSavedArticle: String { text("Remove Saved Article") }
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
    static var openPixivLinkFromClipboard: String { text("Open Pixiv Link from Clipboard") }
    static var openPixivID: String { text("Open Pixiv ID") }
    static var openPixivIDTarget: String { text("Pixiv ID Type") }
    static var openPixivIDHint: String { text("Open an artwork or creator directly by numeric Pixiv ID.") }
    static var pixivIDQuickOpenHint: String { text("Search also accepts illust:123 and user:123.") }
    static var artworkIDPlaceholder: String { text("Enter artwork ID") }
    static var creatorIDPlaceholder: String { text("Enter creator ID") }
    static var openedPixivIDFormat: String { text("Opened %@ %d") }
    static var openedPixivLinkFormat: String { text("Opened Pixiv link %@") }
    static var noPixivLinkInClipboard: String { text("No Pixiv link in clipboard") }
    static var unsupportedPixivLink: String { text("Unsupported Pixiv link") }
    static var loginRequiredForPixivLink: String { text("Login to open Pixiv links") }
    static var dropPixivLinkToOpen: String { text("Drop Pixiv link to open in KeiPix") }
    static var pixivisionArticleFormat: String { text("Pixivision Article #%d") }
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
    static var clearSearch: String { text("Clear Search") }
    static var clearHistory: String { text("Clear History") }
    static var clearHistoryConfirmation: String { text("Clear all local browsing history?") }
    static var deleteHistoryItemConfirmationFormat: String { text("Delete %@ from local history?") }
    static var deletedHistoryItemFormat: String { text("Deleted %@ from local history") }
    static var clearedHistoryItemsFormat: String { text("Cleared %d history items") }
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
    static var playbackSpeed: String { text("Playback Speed") }
    static var export: String { text("Export") }
    static var `import`: String { text("Import") }
    static var downloadFolder: String { text("Download Folder") }
    static var copyDownloadFolderPath: String { text("Copy Download Folder Path") }
    static var copiedDownloadFolderPath: String { text("Copied download folder path") }
    static var chooseFolder: String { text("Choose Folder") }
    static var openFolder: String { text("Open Folder") }
    static var downloadNamingTemplate: String { text("Download Naming Template") }
    static var downloadNamingTemplateHint: String { text("Use placeholders like ${id}, ${title}, ${user}, ${userId}, ${page}, ${page1}, ${pages}, ${ext}, ${AI}, ${R18}, ${R18G}, ${tag1}, ${tag2}, ${tag(name)}. Paths stay inside the download folder.") }
    static var templatePreview: String { text("Template Preview") }
    static var resetTemplate: String { text("Reset Template") }
    static var choose: String { text("Choose") }
    static var clearCompleted: String { text("Clear Completed") }
    static var clearInvalidDownloads: String { text("Clear Invalid") }
    static var clearFailedDownloads: String { text("Clear Failed") }
    static var retryFailedDownloads: String { text("Retry Failed") }
    static var downloadActions: String { text("Download Actions") }
    static var copyVisibleDownloadLinks: String { text("Copy Visible Links") }
    static var copyLoadedArtworkLinks: String { text("Copy Loaded Artwork Links") }
    static var revealFirstVisibleDownload: String { text("Reveal First Visible") }
    static var deleteVisibleDownloads: String { text("Remove Visible Download Records") }
    static var cancelDownload: String { text("Cancel Download") }
    static var cancelVisibleDownloads: String { text("Cancel Visible Active Downloads") }
    static var deleteVisibleDownloadsConfirmationFormat: String { text("Remove %d visible download records? Local files stay in the download folder.") }
    static var deleteDownloadConfirmationFormat: String { text("Remove %@ from the download queue? Local files stay in the download folder.") }
    static var cancelDownloadConfirmationFormat: String { text("Cancel %@ and remove it from the queue? Local files stay in the download folder.") }
    static var cancelVisibleDownloadsConfirmationFormat: String { text("Cancel %d visible active downloads and remove them from the queue? Local files stay in the download folder.") }
    static var clearFailedDownloadsConfirmationFormat: String { text("Clear %d failed download records? Local files stay in the download folder.") }
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
    static var deleteDownload: String { text("Remove Download Record") }
    static var noDownloadsTitle: String { text("No downloads yet") }
    static var noDownloadsSubtitle: String { text("Download artworks from the detail view or artwork context menus.") }
    static var noMatchingDownloadsTitle: String { text("No matching downloads") }
    static var noMatchingDownloadsSubtitle: String { text("Change the download filter to see other queue items.") }
    static var downloadInterrupted: String { text("Download interrupted") }
    static var batchDownload: String { text("Batch Download") }
    static var batchDownloadLoadedArtworks: String { text("Batch Download Loaded Artworks") }
    static var maximumDownloads: String { text("Maximum downloads") }
    static var addToDownloadQueue: String { text("Add to Download Queue") }
    static var queuedDownloadsFormat: String { text("Queued %d downloads") }
    static var pauseDownloads: String { text("Pause Downloads") }
    static var resumeDownloads: String { text("Resume Downloads") }
    static var downloadsPaused: String { text("Downloads Paused") }
    static var downloadsResumed: String { text("Downloads Resumed") }
    static var downloadedLocally: String { text("Downloaded Locally") }
    static var inDownloadQueue: String { text("In Download Queue") }
    static var downloadFailed: String { text("Download Failed") }
    static var concurrentDownloads: String { text("Concurrent Downloads") }
    static var concurrentDownloadsHint: String { text("Use fewer concurrent downloads for unstable proxies; use more when the connection is healthy.") }
    static var downloadFilter: String { text("Download Filter") }
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
    static var removeBookmark: String { text("Remove Bookmark") }
    static var editBookmark: String { text("Edit Bookmark") }
    static var saveBookmark: String { text("Save Bookmark") }
    static var savedBookmarkFormat: String { text("Saved bookmark for %@") }
    static var bookmarkTags: String { text("Bookmark Tags") }
    static var allBookmarkTags: String { text("All Bookmark Tags") }
    static var searchBookmarkTags: String { text("Search bookmark tags") }
    static var unclassified: String { text("Unclassified") }
    static var defaultBookmarkVisibility: String { text("Default Bookmark Visibility") }
    static var addTag: String { text("Add Tag") }
    static var tagName: String { text("Tag Name") }
    static var noBookmarkTags: String { text("No bookmark tags") }
    static var noMatchingBookmarkTags: String { text("No matching bookmark tags") }
    static var noBookmarkTagsToCopy: String { text("No bookmark tags to copy") }
    static var copiedBookmarkTagsFormat: String { text("Copied %d bookmark tags") }
    static var refreshedBookmarkTagsFormat: String { text("Refreshed %d bookmark tags") }
    static var loadedBookmarkTagsFormat: String { text("Loaded %d bookmark tags") }
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
    static var creatorCollections: String { text("Creator Collections") }
    static var openCreatorCollection: String { text("Open creator collection") }
    static var openCreatorNetwork: String { text("Open creator network") }
    static var recentCreatorWorks: String { text("Recent Creator Works") }
    static var noRecentCreatorWorks: String { text("No recent creator works") }
    static var viewAllWorks: String { text("View All Works") }
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
    static var checkFollowVisibility: String { text("Check Follow Visibility") }
    static var checkingFollowVisibility: String { text("Checking follow visibility") }
    static var followVisiblePublicly: String { text("Follow Visible Publicly") }
    static var followVisiblePrivately: String { text("Follow Visible Privately") }
    static var muteVisibleCreators: String { text("Mute Visible Creators") }
    static var unfollowVisibleCreators: String { text("Unfollow Visible Creators") }
    static var copyVisibleCreatorLinks: String { text("Copy Visible Creator Links") }
    static var copyVisibleCreatorSummary: String { text("Copy Visible Creator Summary") }
    static var runningCreatorAction: String { text("Updating creators") }
    static var noCreatorLinksToCopy: String { text("No creator links to copy") }
    static var noCreatorSummariesToCopy: String { text("No creator summaries to copy") }
    static var noFollowedCreatorsToCheck: String { text("No followed creators to check") }
    static var noMatchingCreatorsForAction: String { text("No matching creators for this action") }
    static var publicFollow: String { text("Public Follow") }
    static var privateFollow: String { text("Private Follow") }
    static var followVisiblePubliclyConfirmationFormat: String { text("Follow %d visible creators publicly?") }
    static var followVisiblePrivatelyConfirmationFormat: String { text("Follow %d visible creators privately?") }
    static var muteVisibleCreatorsConfirmationFormat: String { text("Mute %d visible creators?") }
    static var unfollowVisibleCreatorsConfirmationFormat: String { text("Unfollow %d visible creators?") }
    static var creatorActionCompletedFormat: String { text("Updated %d creators") }
    static var copiedCreatorLinksFormat: String { text("Copied %d creator links") }
    static var copiedCreatorSummaryFormat: String { text("Copied %d creator summaries") }
    static var pinCreator: String { text("Pin Creator") }
    static var unpinCreator: String { text("Unpin Creator") }
    static var pinnedCreatorFormat: String { text("Pinned %@") }
    static var unpinnedCreatorFormat: String { text("Unpinned %@") }
    static var noPinnedCreators: String { text("No pinned creators") }
    static var noPinnedCreatorsHint: String { text("Pin creators from recommended, search, following, or profile views to build a local creator collection.") }
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
    static var settingsAdvancedQA: String { text("Advanced QA") }
    static var noMatchingSettings: String { text("No matching settings") }
    static var noMatchingSettingsHint: String { text("Change the settings search to show other controls.") }
    static var showSidebar: String { text("Show Sidebar") }
    static var hideSidebar: String { text("Hide Sidebar") }
    static var language: String { text("Language") }
    static var automatic: String { text("Automatic") }
    static var simplifiedChinese: String { text("Simplified Chinese") }
    static var english: String { text("English") }
    static var appearance: String { text("Appearance") }
    static var useOriginalImages: String { text("Use original images in detail") }
    static var showTranslatedTags: String { text("Show translated tag names") }
    static var contentFilters: String { text("Content Filters") }
    static var showContentBadges: String { text("Show content badges") }
    static var hideMutedContent: String { text("Hide muted content") }
    static var hideAIArtworks: String { text("Hide AI-generated artworks") }
    static var pixivAIDisplay: String { text("Pixiv AI Display") }
    static var pixivAIDisplayHint: String { text("KeiPix applies AI visibility locally and through search filters. Pixiv account-wide AI display has no verified App API endpoint in this build.") }
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
    static var popularPreview: String { text("Popular Preview") }
    static var popularPreviewHint: String { text("Top works for this search") }
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
    static var previousArtwork: String { text("Previous Artwork") }
    static var nextArtwork: String { text("Next Artwork") }
    static var readerWindow: String { text("Reader Window") }
    static var openReaderWindow: String { text("Open Reader Window") }
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
    static var account: String { text("Account") }
    static var addAccount: String { text("Add Account") }
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
    static var keychainSession: String { text("Keychain session") }
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
    static var qaMuteSyncDetail: String { text("Requires explicit approval before syncing mute changes.") }
    static var qaGalleryVisual: String { text("Gallery visual surfaces") }
    static var qaGalleryVisualRequirement: String { text("Masonry, hot tags, Pixivision, and wide/tall mixed cards render without overlap, gray gutters, or clipped text.") }
    static var qaGalleryVisualNext: String { text("Capture visual QA screenshots for hot tags and wide feeds.") }
    static var qaTrendingTags: String { text("Trending tags") }
    static var qaTrendingTagsRequirement: String { text("Hot tag cards load preview artwork and route searches in-app.") }
    static var qaTrendingTagsNext: String { text("Run hot tag route and visual QA.") }
    static var qaPixivision: String { text("Pixivision") }
    static var qaPixivisionRequirement: String { text("Articles open in-app and Pixiv artwork/user/tag links route natively.") }
    static var qaPixivisionNext: String { text("Open an article and verify native link routing.") }
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
    static var qaCommentsFeedbackNext: String { text("Add stamp support only after endpoint verification.") }
    static var qaLocalCacheOffline: String { text("Local cache and offline") }
    static var qaLocalCacheOfflineRequirement: String { text("Image cache, history, downloads, and last successful surfaces support offline-friendly review.") }
    static var qaLocalCacheOfflineNext: String { text("Add feed snapshot cache.") }
    static var qaSettingsOrganization: String { text("Settings organization") }
    static var qaSettingsOrganizationRequirement: String { text("Reading, discovery, safety, downloads, privacy, and QA controls stay grouped in native Settings.") }
    static var qaSettingsOrganizationNext: String { text("Keep Settings search and grouping in regression coverage.") }
    static var systemProxy: String { text("System Proxy") }
    static var directConnection: String { text("Direct connection") }
    static var pixivAPI: String { text("Pixiv API") }
    static var imageHost: String { text("Image Host") }
    static var reachable: String { text("Reachable") }
    static var skipped: String { text("Skipped") }
    static var passed: String { text("Passed") }
    static var unknown: String { text("Unknown") }
    static var noArtworkForImageProbe: String { text("Open an artwork to test the image host") }
    static var session: String { text("Session") }
    static var signedIn: String { text("Signed In") }
    static var signedOut: String { text("Signed Out") }
    static var currentRoute: String { text("Current Route") }
    static var feed: String { text("Feed") }
    static var feedReadinessFormat: String { text("%d shown · %d loaded · %@") }
    static var selectedArtwork: String { text("Selected Artwork") }
    static var noSelection: String { text("No Selection") }
    static var pageCountFormat: String { text("%d pages") }
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
    static var signedOutSubtitle: String { text("KeiPix stores tokens in the macOS Keychain and uses Pixiv app API requests from the native client.") }
    static var searchPlaceholder: String { text("Search artworks, tags, creators, or illust:123") }
    static var noArtworkTitle: String { text("No artworks loaded") }
    static var noArtworkSubtitle: String { text("Refresh the current section or start a search.") }
    static var errorTitle: String { text("Request failed") }
    static var copyError: String { text("Copy Error") }
    static var copiedError: String { text("Copied Error") }
    static var copied: String { text("Copied") }
    static var loadMore: String { text("Load More") }
    static var publicBookmarks: String { text("Public bookmarks") }
    static var privateBookmarks: String { text("Private bookmarks") }
    static var allFollowing: String { text("All Following") }
    static var privateFollowing: String { text("Private Following") }
    static var rankingDate: String { text("Ranking Date") }
    static var useRankingDate: String { text("Use Ranking Date") }
    static var latestRanking: String { text("Latest Ranking") }
    static var latestRankingApplied: String { text("Showing latest ranking") }
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
    static var details: String { text("Details") }
    static var tags: String { text("Tags") }
    static var searchTag: String { text("Search Tag") }
    static var openTagInPixiv: String { text("Open Tag in Pixiv") }
    static var copyTagLink: String { text("Copy Tag Link") }
    static var copyTag: String { text("Copy Tag") }
    static var copyTranslatedTag: String { text("Copy Translated Tag") }
    static var description: String { text("Description") }
    static var artworkInformation: String { text("Artwork Information") }
    static var comments: String { text("Comments") }
    static var writeComment: String { text("Write a comment") }
    static var postComment: String { text("Post Comment") }
    static var postedComment: String { text("Posted comment") }
    static var noComments: String { text("No comments") }
    static var loadMoreComments: String { text("Load More Comments") }
    static var reply: String { text("Reply") }
    static var replyToFormat: String { text("Reply to %@") }
    static var cancelReply: String { text("Cancel Reply") }
    static var viewReplies: String { text("View Replies") }
    static var hideReplies: String { text("Hide Replies") }
    static var noReplies: String { text("No replies") }
    static var copyComment: String { text("Copy Comment") }
    static var copiedComment: String { text("Copied comment") }
    static var replies: String { text("Replies") }
    static var showComment: String { text("Show Comment") }
    static var muteCommentPhrase: String { text("Mute Comment Phrase") }
    static var hiddenCommentReasonFormat: String { text("Hidden comment: %@") }
    static var mutedCommentUserReasonFormat: String { text("muted creator %@") }
    static var mutedCommentPhraseReasonFormat: String { text("muted phrase %@") }
    static var relatedArtworks: String { text("Related Artworks") }
    static var noRelatedArtworks: String { text("No related artworks") }
    static var loadMoreRelatedArtworks: String { text("Load More Related Artworks") }
    static var artworkSeries: String { text("Artwork Series") }
    static var noSeriesArtworks: String { text("No series artworks") }
    static var loadMoreSeriesArtworks: String { text("Load More Series Artworks") }
    static var addToWatchlist: String { text("Add to Watchlist") }
    static var watchlistAdded: String { text("Watchlist Added") }
    static var addedToWatchlistFormat: String { text("Added %@ to watchlist") }
    static var openSeriesInPixiv: String { text("Open Series in Pixiv") }
    static var openLatestArtwork: String { text("Open Latest Artwork") }
    static var updatedSeries: String { text("Updated") }
    static var unreadUpdatesFormat: String { text("%d unread") }
    static var markWatchlistRead: String { text("Mark as Read") }
    static var noWatchlistSeries: String { text("No watchlist series") }
    static var noMatchingWatchlistSeries: String { text("No matching watchlist series") }
    static var noMatchingWatchlistSeriesSubtitle: String { text("Change the watchlist search to see other series.") }
    static var searchWatchlistSeries: String { text("Search watchlist series") }
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
    static var continuousReading: String { text("Continuous Reading") }
    static var pageIndex: String { text("Page Index") }
    static var jumpToPage: String { text("Jump to Page") }
    static var pageJump: String { text("Page Jump") }
    static var goToPage: String { text("Go to Page") }
    static var fullScreenReading: String { text("Full Screen Reading") }
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
