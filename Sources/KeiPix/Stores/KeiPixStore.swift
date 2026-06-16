#if os(macOS)
import AppKit
#else
import UIKit
#endif
import Foundation
import Observation

@MainActor
@Observable
final class KeiPixStore {
    let api: PixivAPI
    let downloads: ArtworkDownloadStore
    let novels: NovelFeatureStore

    var session: PixivSession?
    var pixivWebSession: PixivWebSession?
    var storedAccounts: [PixivStoredAccount] = []
    var selectedRoute: PixivRoute = AppLaunchRouteResolver.initialRoute() {
        didSet {
            guard oldValue != selectedRoute else { return }
            restoreClientFilterQueryForCurrentScope()
        }
    }
    var artworks: [PixivArtwork] = [] {
        didSet { recomputeFilteredArtworks() }
    }
    var clientFilterQuery = "" {
        didSet {
            storeClientFilterQueryForCurrentScopeIfNeeded()
            recomputeFilteredArtworks()
        }
    }
    private(set) var clientFilteredArtworks: [PixivArtwork] = []
    private var clientFilterQueriesByScope: [String: String] = [:]
    private var isRestoringClientFilterQuery = false

    private func recomputeFilteredArtworks() {
        clientFilteredArtworks = ClientFilterDSL.filter(artworks, query: clientFilterQuery)
    }

    func restoreClientFilterQueryForCurrentScope() {
        let restoredQuery = clientFilterQueriesByScope[currentClientFilterScopeID] ?? ""
        guard clientFilterQuery != restoredQuery else { return }
        isRestoringClientFilterQuery = true
        clientFilterQuery = restoredQuery
        isRestoringClientFilterQuery = false
    }

    private func storeClientFilterQueryForCurrentScopeIfNeeded() {
        guard isRestoringClientFilterQuery == false else { return }
        let scopeID = currentClientFilterScopeID
        if clientFilterQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            clientFilterQueriesByScope.removeValue(forKey: scopeID)
        } else {
            clientFilterQueriesByScope[scopeID] = clientFilterQuery
        }
    }

    private var currentClientFilterScopeID: String {
        var components = [selectedRoute.rawValue]
        if selectedRoute == .search || selectedRoute == .searchUsers || selectedRoute == .novelSearch {
            components.append("keyword:\(searchText.trimmingCharacters(in: .whitespacesAndNewlines))")
        }
        if let focusedUser {
            components.append("user:\(focusedUser.id)")
        }
        if let creatorArtworkTagFilter {
            components.append("creator-tag:\(creatorArtworkTagFilter.snapshotKey)")
        }
        if let bookmarkTagFilter {
            components.append("bookmark-tag:\(bookmarkTagFilter)")
        }
        if let feedNarrowingContext {
            components.append(feedNarrowingContext.storageID)
        }
        if let selectedPixivCollection {
            components.append("collection:\(selectedPixivCollection.id)")
        }
        return components.joined(separator: "|")
    }
    var selectedArtwork: PixivArtwork?
    /// Advances only when the user explicitly navigates to an artwork.
    /// Feed loading and filter restoration may update `selectedArtwork`
    /// directly; iPadOS uses this serial to distinguish those passive
    /// selection updates from a real request to open the detail reader.
    var artworkNavigationIntentSerial = 0

    // MARK: - Navigation history (in-memory, per-session)
    var navigationHistory = NavigationHistory()

    var searchPopularPreviewArtworks: [PixivArtwork] = []
    var isLoadingSearchPopularPreview = false
    var presentedUserProfile: PixivUser?
    var selectedSpotlightArticle: PixivSpotlightArticle?
    var pixivCollections: [PixivCollectionDetail] = []
    var selectedPixivCollection: PixivCollectionDetail? {
        didSet {
            guard oldValue?.id != selectedPixivCollection?.id else { return }
            restoreClientFilterQueryForCurrentScope()
        }
    }
    var selectedPixivCollectionSourceRoute: PixivRoute?
    var isLoadingPixivCollections = false
    var isLoadingMorePixivCollections = false
    var pixivCollectionNextOffset: Int?
    var pixivCollectionTotalCount = 0
    var pixivCollectionListMode: PixivCollectionListMode = .discovery
    var pixivCollectionDiscoveryScope: PixivCollectionDiscoveryScope = .discover
    var pixivCollectionDiscoverySelectedTag: String?
    var pixivCollectionRecommendedTags: [PixivCollectionDiscoveryTag] = []
    var pixivCollectionPersonalizedTags: [PixivCollectionDiscoveryTag] = []
    var pixivCollectionErrorMessage: String?
    var pixivActivityFeedScope: PixivActivityFeedScope = .all
    var pixivActivityKindFilter: PixivActivityKindFilter = .all
    var pixivActivityItems: [PixivActivityItem] = []
    var pixivActivityNewItemIDs: Set<String> = []
    var pixivActivityLastRefreshNewCount = 0
    var pixivActivityLastRefreshNewItemIDs: Set<String> = []
    var isLoadingPixivActivityFeed = false
    var isLoadingMorePixivActivityFeed = false
    var pixivActivityNextPage: URL?
    var pixivActivityLoadedAt: Date?
    var pixivActivityLoadedInCurrentSession = false
    var pixivActivityErrorMessage: String?
    var pixivActivityItemsByScope: [PixivActivityFeedScope: [PixivActivityItem]] = [:]
    var pixivActivityNextPageByScope: [PixivActivityFeedScope: URL] = [:]
    var pixivActivityLoadedAtByScope: [PixivActivityFeedScope: Date] = [:]
    var pixivActivityLoadedInCurrentSessionScopes: Set<PixivActivityFeedScope> = []
    var pixivActivityNewMarkerDatesByScope: [PixivActivityFeedScope: [String: Date]] = [:]
    var isPixivWebSessionPresented = false
    var readerWindowArtwork: PixivArtwork?
    /// Bounded registry mapping artwork ID → `PixivArtwork` for
    /// windows opened via the multi-window reader scene. Lets a
    /// value-typed `WindowGroup(for: Int.self)` hand off ID-only
    /// restoration data while still resolving the full payload on
    /// appear. See `KeiPixStore+ReaderWindows.swift` for the registry
    /// type and helpers.
    var readerWindowRegistry = ReaderWindowArtworkRegistry()
    var imageSourceSearchRequest: ImageSourceSearchRequest?
    var pendingDangerAction: AppDangerAction?
    var undoAction: AppUndoAction?
    var focusedUser: PixivUser? {
        didSet {
            guard oldValue?.id != focusedUser?.id else { return }
            restoreClientFilterQueryForCurrentScope()
        }
    }
    var searchText = "" {
        didSet {
            guard oldValue != searchText,
                  selectedRoute == .search || selectedRoute == .novelSearch else { return }
            restoreClientFilterQueryForCurrentScope()
        }
    }
    var searchSubmissionID = 0
    var routeRefreshGeneration = 0
    /// Advances when shared content visibility filters change. Non-feed
    /// surfaces such as creator lists use this targeted token to re-fetch
    /// source responses without conflating content filtering with route
    /// refresh actions.
    var contentFilterGeneration = 0
    var searchSuggestions: [PixivTag] = []
    var remoteSearchOptions: PixivRemoteSearchOptions?
    var remoteSearchOptionsLoadedAt: Date?
    var remoteSearchOptionsErrorMessage: String?
    var isLoadingRemoteSearchOptions = false
    var searchHistory = UserDefaults.standard.stringArray(forKey: "searchHistory") ?? []
    var savedSearches = UserDefaults.standard.stringArray(forKey: "savedSearches") ?? []
    var savedSearchPresets = KeiPixStore.loadSavedSearchPresets()
    var bookmarkTagFilter: String? {
        didSet {
            guard oldValue != bookmarkTagFilter else { return }
            restoreClientFilterQueryForCurrentScope()
        }
    }
    var bookmarkFeedOptions = BookmarkFeedOptions.defaultValue
    var creatorArtworkTagFilter: CreatorArtworkTagFilter? {
        didSet {
            guard oldValue?.snapshotKey != creatorArtworkTagFilter?.snapshotKey else { return }
            restoreClientFilterQueryForCurrentScope()
        }
    }
    var feedNarrowingContext: FeedNarrowingContext? {
        didSet {
            guard oldValue?.storageID != feedNarrowingContext?.storageID else { return }
            restoreClientFilterQueryForCurrentScope()
        }
    }
    var localBrowsingHistory = KeiPixStore.loadLocalBrowsingHistory()
    var watchLaterQueue = KeiPixStore.loadWatchLaterQueue()
    var spotlightFavoriteArticles = KeiPixStore.loadSpotlightArticles(key: "spotlightFavoriteArticles")
    var spotlightArticleHistory = KeiPixStore.loadSpotlightArticles(key: "spotlightArticleHistory")
    var spotlightArticleReadStateLibrary = KeiPixStore.loadSpotlightArticleReadStateLibrary()
    var readerProgressLibrary = KeiPixStore.loadReaderProgressLibrary()
    var downloadedReaderProgressLibrary = KeiPixStore.loadDownloadedReaderProgressLibrary()
    var mangaWatchlistReadStateLibrary = KeiPixStore.loadMangaWatchlistReadStateLibrary()
    var pinnedCreatorLibrary = KeiPixStore.loadPinnedCreatorLibrary()
    var feedSnapshotLibrary = KeiPixStore.loadFeedSnapshotLibrary()
    var activeFeedSnapshotRestoration: FeedSnapshotRestoration?
    var routeActivationFreshSnapshotKeys: Set<String> = []
    var artworkDetailStateLibrary = KeiPixStore.loadArtworkDetailStateLibrary()
    var artworkDetailDefaultExpansion = KeiPixStore.loadArtworkDetailDefaultExpansion()
    #if DEBUG
    var lastNonNovelQAMatrixSnapshot = KeiPixStore.loadLastNonNovelQAMatrixSnapshot()
    #else
    var lastNonNovelQAMatrixSnapshot: NonNovelQAMatrixSnapshot? = nil
    #endif
    var errorMessage: String?
    var isLoading = false
    var isLoadingMore = false
    var isLoginPresented = false
    var isTokenLoginPresented = false
    var accountSessionMode = KeiPixStore.loadAccountSessionMode()
    var appLanguage = UserDefaults.standard.string(forKey: "appLanguage")
        .flatMap(AppLanguage.init(rawValue:)) ?? .automatic
    var translationTargetLanguage = UserDefaults.standard.string(forKey: "translationTargetLanguage")
        .flatMap(TranslationTargetLanguage.init(rawValue:)) ?? .system
    var appColorScheme = UserDefaults.standard.string(forKey: "appColorScheme")
        .flatMap(AppColorScheme.init(rawValue:)) ?? .system
    /// User-chosen destination to land on at launch. Mirrors the "open at
    /// launch" preference Mail / Notes / Music ship and Pixes exposes
    /// under its initial-page setting.
    var launchDestination = UserDefaults.standard.string(forKey: "launchDestination")
        .flatMap(LaunchDestination.init(rawValue:)) ?? .home
    var routeSwitchRefreshExpiration = UserDefaults.standard.string(forKey: RouteSwitchRefreshExpiration.defaultsKey)
        .flatMap(RouteSwitchRefreshExpiration.init(rawValue:)) ?? .defaultValue
    var useOriginalImagesInDetail = UserDefaults.standard.bool(forKey: "useOriginalImagesInDetail")
    /// Per-content quality default for manga / multi-page reads.
    ///
    /// Pixez exposes `pictureQuality` and `mangaQuality` separately so users
    /// can keep illust details on original quality while paging through a
    /// long manga at the lighter standard preview. Defaults to the same
    /// value as the illust knob so existing users see no behaviour change
    /// until they explicitly diverge the two presets.
    var useOriginalImagesForManga = UserDefaults.standard.object(forKey: "useOriginalImagesForManga") as? Bool
        ?? UserDefaults.standard.bool(forKey: "useOriginalImagesInDetail")
    /// Three-step image quality tier (medium / large / original) for
    /// illust detail. Mirrors Pixez's `pictureQuality` picker. The
    /// legacy `useOriginalImagesInDetail` Bool seeds the initial tier so
    /// existing installs upgrade in place — `true` lands on `.original`,
    /// `false` lands on `.large` (the previous resolver default).
    var illustDetailImageQualityTier = KeiPixStore.loadEnum(
        "illustDetailImageQualityTier",
        defaultValue: ArtworkImageQualityTier.legacy(
            preferOriginal: UserDefaults.standard.bool(forKey: "useOriginalImagesInDetail")
        )
    )
    /// Manga detail counterpart. Seeded from `useOriginalImagesForManga`
    /// when no tier preference exists yet so the upgrade is invisible.
    var mangaDetailImageQualityTier = KeiPixStore.loadEnum(
        "mangaDetailImageQualityTier",
        defaultValue: ArtworkImageQualityTier.legacy(
            preferOriginal: UserDefaults.standard.object(forKey: "useOriginalImagesForManga") as? Bool
                ?? UserDefaults.standard.bool(forKey: "useOriginalImagesInDetail")
        )
    )
    /// Feed preview tier — controls what `ArtworkCardView` /
    /// `RemoteImageView` request when rendering thumbnails. Defaults to
    /// `.large` so the unified image quality control has a visible default
    /// that matches the legacy detail resolver.
    var feedPreviewImageQualityTier = KeiPixStore.loadEnum(
        "feedPreviewImageQualityTier",
        defaultValue: ArtworkImageQualityTier.large
    )
    var galleryLayoutMode = KeiPixStore.loadGalleryLayoutMode()
    var creatorListLayoutMode = KeiPixStore.loadCreatorListLayoutMode()
    var spotlightListLayoutMode = KeiPixStore.loadSpotlightListLayoutMode()
    var novelGalleryLayoutMode = KeiPixStore.loadEnum("novelGalleryLayoutMode", defaultValue: NovelGalleryLayoutMode.grid)
    var pixivActivityLayoutMode = KeiPixStore.loadEnum(
        "pixivActivityLayoutMode",
        defaultValue: PixivActivityFeedPresentation.defaultLayoutMode
    )
    var showTranslatedTags = UserDefaults.standard.object(forKey: "showTranslatedTags") as? Bool ?? true
    var showContentBadges = UserDefaults.standard.object(forKey: "showContentBadges") as? Bool ?? true
    var showAccountIdentity = UserDefaults.standard.object(forKey: "showAccountIdentity") as? Bool ?? true
    /// Whether artworks from artists the user follows get a stronger card
    /// treatment in mixed feeds (search, recommendation, ranking, etc.).
    /// Mirrors Pixes' `emphasizeArtworksFromFollowingArtists` — defaulting on
    /// because the affordance only shows up when `user.is_followed` is true,
    /// so it never adds noise on first launch.
    var emphasizeFollowingArtists = UserDefaults.standard.object(forKey: "emphasizeFollowingArtists") as? Bool ?? true
    var privacyModeEnabled = UserDefaults.standard.object(forKey: "privacyModeEnabled") as? Bool ?? false
    var screenCaptureProtectionEnabled = UserDefaults.standard.object(forKey: "screenCaptureProtectionEnabled") as? Bool ?? true
    var hideMutedContent = UserDefaults.standard.object(forKey: "hideMutedContent") as? Bool ?? true
    var hideAIArtworks = UserDefaults.standard.bool(forKey: "hideAIArtworks")
    var hideR18Artworks = UserDefaults.standard.bool(forKey: "hideR18Artworks")
    var hideR18GArtworks = UserDefaults.standard.bool(forKey: "hideR18GArtworks")
    var maskSensitivePreviews = UserDefaults.standard.object(forKey: "maskSensitivePreviews") as? Bool ?? false
    /// Whether completed downloads are mirrored into CoreSpotlight so
    /// `Cmd+Space` can find them. Off by default — same as Mail's
    /// "Index every message" preference — so a user has to opt in
    /// before any artwork metadata leaves the app's sandbox into the
    /// system-wide search index.
    var spotlightIndexingEnabled = UserDefaults.standard.bool(forKey: "spotlightIndexingEnabled")
    var restrictedModeEnabled: Bool?
    /// Account-wide AI display preference (Pixiv `show_ai`). `nil` until the
    /// store has either no session, a guest/test session, or a successful
    /// fetch — same lifecycle as `restrictedModeEnabled`.
    var aiShowEnabled: Bool?
    private static var legacyDefaultBookmarkRestrict: BookmarkRestrict {
        loadEnum("defaultBookmarkRestrict", defaultValue: BookmarkRestrict.public)
    }

    var defaultBookmarkRestrict = KeiPixStore.legacyDefaultBookmarkRestrict
    var defaultIllustrationBookmarkRestrict = KeiPixStore.loadEnum(
        "defaultIllustrationBookmarkRestrict",
        defaultValue: KeiPixStore.legacyDefaultBookmarkRestrict
    )
    var defaultMangaBookmarkRestrict = KeiPixStore.loadEnum(
        "defaultMangaBookmarkRestrict",
        defaultValue: KeiPixStore.legacyDefaultBookmarkRestrict
    )
    var defaultNovelBookmarkRestrict = KeiPixStore.loadEnum(
        "defaultNovelBookmarkRestrict",
        defaultValue: KeiPixStore.legacyDefaultBookmarkRestrict
    )
    var defaultFollowRestrict = KeiPixStore.loadEnum("defaultFollowRestrict", defaultValue: BookmarkRestrict.public)
    /// Tags the user has pinned in `BookmarkTagsView` so the tags they jump
    /// to most often surface at the top of the list. Stored as a single set
    /// instead of per-restrict because Pixiv's tag namespace is shared across
    /// public/private bookmarks — a pinned `風景` should follow the user
    /// regardless of which restrict they're browsing.
    var pinnedBookmarkTags = Set(UserDefaults.standard.stringArray(forKey: "pinnedBookmarkTags") ?? [])
    var followCreatorAfterBookmark = UserDefaults.standard.object(forKey: "followCreatorAfterBookmark") as? Bool ?? false
    var autoDownloadBookmarkedArtworks = UserDefaults.standard.object(forKey: "autoDownloadBookmarkedArtworks") as? Bool ?? false
    var autoBookmarkDownloadedArtworks = UserDefaults.standard.object(forKey: "autoBookmarkDownloadedArtworks") as? Bool ?? false
    var autoTagBookmarksWithArtworkTags = UserDefaults.standard.object(forKey: "autoTagBookmarksWithArtworkTags") as? Bool ?? false
    var artworkCopyTemplate = UserDefaults.standard.string(forKey: "artworkCopyTemplate")
        ?? ArtworkCopyTemplate.defaultTemplate
    var creatorCopyTemplate = UserDefaults.standard.string(forKey: "creatorCopyTemplate")
        ?? CreatorCopyTemplate.defaultTemplate
    var restoreArtworkReaderProgress = UserDefaults.standard.object(forKey: "restoreArtworkReaderProgress") as? Bool ?? true
    /// App-level proxy mode. `URLSession` owners (PixivAPI,
    /// ImagePipeline) read the same persisted snapshot at init, so
    /// the four storage keys (mode/host/port/scheme) are the source
    /// of truth — `setProxyConfiguration` keeps these observable
    /// properties in sync with what the next launch will use.
    var proxyConfigurationMode = UserDefaults.standard.string(forKey: ProxyConfiguration.DefaultsKey.mode)
        .flatMap(ProxyConfigurationMode.init(rawValue:)) ?? .system
    var proxyConfigurationHost = UserDefaults.standard.string(forKey: ProxyConfiguration.DefaultsKey.host) ?? ""
    var proxyConfigurationPort = UserDefaults.standard.integer(forKey: ProxyConfiguration.DefaultsKey.port)
    var proxyConfigurationScheme = UserDefaults.standard.string(forKey: ProxyConfiguration.DefaultsKey.scheme)
        .flatMap(ProxyScheme.init(rawValue:)) ?? .http
    /// Opt-in toggle for the GitHub release update check that runs on
    /// launch. Defaults to `true` because it's a single low-volume API
    /// call per day and macOS users expect this kind of self-update
    /// affordance from a freestanding app — Pixez and Pixes both ship
    /// the same setting on by default.
    var checkForUpdatesOnLaunch = UserDefaults.standard.object(forKey: "checkForUpdatesOnLaunch") as? Bool ?? true
    /// The newest release the app saw on its last successful check.
    /// Surfaces in Settings as the "current latest" anchor and powers
    /// the manual `Help → Check for Updates…` "you're up to date" alert
    /// without having to re-fetch.
    var latestReleaseUpdate: ReleaseUpdate? = KeiPixStore.loadLatestReleaseUpdate()
    /// Newest release tag the user explicitly skipped. The launch-time
    /// banner stays silent for this exact tag so a noisy "we just shipped
    /// 0.2.0" prompt can be dismissed once and stay dismissed; future
    /// releases past it (0.2.1, 0.3.0) still surface a fresh banner.
    var skippedReleaseTagName = UserDefaults.standard.string(forKey: "skippedReleaseTagName") ?? ""
    /// When the launch-time check last ran. Used as a 24-hour throttle so
    /// a user who quits / reopens KeiPix repeatedly during the day doesn't
    /// pummel GitHub. The manual menu entry bypasses this throttle.
    var lastUpdateCheckAt: Date? = UserDefaults.standard.object(forKey: "lastUpdateCheckAt") as? Date
    /// In-flight progress flag for the manual `Help → Check for Updates…`
    /// command — flipping it lets the menu item disable while a request
    /// is in flight, mirroring App Store's "Checking…" state.
    var isCheckingForUpdates = false
    /// Result of the most recent **manual** update check. Wraps either a
    /// fresh `ReleaseUpdate` (newer than current) or an `upToDate` result
    /// so the manual entry point can show the right alert. The
    /// launch-time check writes only into `latestReleaseUpdate` because
    /// it's silent when there's nothing new.
    var manualUpdateCheckResult: ReleaseUpdateCheckResult?
    /// Last error from a manual update check, surfaced in the
    /// "Couldn't check for updates" alert. Cleared on the next attempt.
    var manualUpdateCheckError: String?
    /// Release that's currently driving the "update available" prompt.
    /// Both the launch-time check and the manual menu entry funnel into
    /// this single binding so ContentView only has to handle one alert
    /// for the "newer version" case.
    var pendingReleaseUpdatePrompt: ReleaseUpdate?
    /// Bound to the "KeiPix is up to date" alert that the manual menu
    /// entry surfaces. Lives on the store (not local @State) so the
    /// menu command can fire it from outside the view tree.
    var presentingNoUpdatesAvailable = false
    /// Bound to the "Couldn't check for updates" alert. Same rationale
    /// as `presentingNoUpdatesAvailable` — the menu command sets it,
    /// ContentView reads it.
    var presentingUpdateCheckFailed = false
    var searchMatchType = KeiPixStore.loadEnum("searchMatchType", defaultValue: SearchMatchType.partialTags)
    var searchSort = KeiPixStore.loadEnum("searchSort", defaultValue: SearchSort.dateDescending)
    var searchAgeLimit = KeiPixStore.loadEnum("searchAgeLimit", defaultValue: SearchAgeLimit.unlimited)
    var searchDateRange = KeiPixStore.loadEnum("searchDateRange", defaultValue: SearchDateRange.anytime)
    var searchMinimumBookmarks = SearchBookmarkThreshold(
        value: UserDefaults.standard.integer(forKey: "searchMinimumBookmarks")
    )
    var searchMaximumBookmarks = SearchBookmarkThreshold(
        value: UserDefaults.standard.integer(forKey: "searchMaximumBookmarks")
    )
    var searchArtworkType = KeiPixStore.loadEnum("searchArtworkType", defaultValue: SearchArtworkType.all)
    var searchAIFilter = KeiPixStore.loadEnum("searchAIFilter", defaultValue: SearchAIFilter.all)
    var searchUgoiraFilter = KeiPixStore.loadEnum("searchUgoiraFilter", defaultValue: SearchUgoiraFilter.all)
    var searchNovelLanguageCode = UserDefaults.standard.string(forKey: "searchNovelLanguageCode")
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .flatMap { $0.isEmpty ? nil : $0 }
    var searchNovelGenreID = UserDefaults.standard.object(forKey: "searchNovelGenreID") as? Int
    var searchNovelTextLength = KeiPixStore.loadEnum("searchNovelTextLength", defaultValue: SearchNovelTextLength.all)
    var activeSearchOptionsProfile = KeiPixStore.loadEnum(
        SearchOptionsProfileKind.activeDefaultsKey,
        defaultValue: SearchOptionsProfileKind.allArtworks
    )
    var searchOptionsProfiles = KeiPixStore.loadSearchOptionsProfiles()
    var imageSourceSearchEngine = KeiPixStore.loadEnum("imageSourceSearchEngine", defaultValue: ImageSourceSearchEngineKind.sauceNAO)
    var useRankingDate = UserDefaults.standard.object(forKey: "useRankingDate") as? Bool ?? false
    var rankingDate = KeiPixStore.loadRankingDate()
    var trackpadGesturesEnabled = UserDefaults.standard.object(forKey: "trackpadGesturesEnabled") as? Bool ?? true

    // MARK: - Image Processing

    var imageProcessorsEnabled = UserDefaults.standard.bool(forKey: "imageProcessorsEnabled")
    var activeImageProcessors: [String] = UserDefaults.standard.stringArray(forKey: "activeImageProcessors")
        ?? ImageProcessorRegistry.defaultActiveProcessorIdentifiers
    var horizontalSwipeBehavior = UserDefaults.standard.string(forKey: "horizontalSwipeBehavior")
        .flatMap(TrackpadHorizontalSwipeBehavior.init(rawValue:)) ?? .pageOnly
    var defaultArtworkReadingMode = KeiPixStore.loadEnum(
        ArtworkReadingModePreferenceKind.artwork.storageKey,
        defaultValue: ArtworkReadingModePreferenceKind.artwork.fallbackMode
    )
    var defaultMangaReadingMode = KeiPixStore.loadEnum(
        ArtworkReadingModePreferenceKind.manga.storageKey,
        defaultValue: ArtworkReadingModePreferenceKind.manga.fallbackMode
    )
    var hasNextPage: Bool { nextURL != nil }
    var compactArtworkCards: Bool { galleryLayoutMode.usesCompactGrid }
    var showsSidebarAccountIdentity: Bool { showAccountIdentity && privacyModeEnabled == false }
    var usesLocalSampleAccount: Bool { accountSessionMode.usesLocalSampleData }
    var isMainWindowCaptureProtected: Bool {
        screenCaptureProtectionEnabled && selectedArtwork?.requiresScreenCaptureProtection == true
    }
    var isReaderWindowCaptureProtected: Bool {
        screenCaptureProtectionEnabled && readerWindowArtwork?.requiresScreenCaptureProtection == true
    }

    var allArtworks: [PixivArtwork] = []
    var allSearchPopularPreviewArtworks: [PixivArtwork] = []
    var nextURL: URL?
    /// Advances when the shared creator-preview artwork cache changes.
    /// Creator cards consume this lightweight token so native hosted
    /// cells can refresh when profile sheets or card shelves fill the
    /// same author's recent-work cache.
    var creatorPreviewArtworkCacheGeneration = 0
    private var activeFeedRequestID: UUID?
    private var activeSearchPopularPreviewRequestID: UUID?
    @ObservationIgnored private var hydratingCreatorTagArtworkIDs: Set<Int> = []
    @ObservationIgnored private var hydratedCreatorTagArtworkIDs: Set<Int> = []
    @ObservationIgnored private var failedCreatorTagArtworkIDs: Set<Int> = []
    @ObservationIgnored var isApplyingSearchOptionsProfile = false
    @ObservationIgnored var creatorPreviewArtworkCache: [Int: [PixivArtwork]] = [:]
    @ObservationIgnored var creatorPreviewArtworkRequests: [Int: Task<[PixivArtwork], Error>] = [:]
    var mutedTags = Set(UserDefaults.standard.stringArray(forKey: "mutedTags") ?? [])
    var mutedUsers = KeiPixStore.loadIntStringDictionary("mutedUsers")
    var mutedArtworks = KeiPixStore.loadIntStringDictionary("mutedArtworks")
    var mutedCommentPhrases = Set(UserDefaults.standard.stringArray(forKey: "mutedCommentPhrases") ?? [])
    var dashboardCardOrderID = UserDefaults.standard.string(forKey: "dashboardCardOrderID")
        ?? DiscoveryDashboardCardKind.storageID(for: DiscoveryDashboardCardKind.defaultOrder)
    var hiddenDashboardCardIDs = Set(UserDefaults.standard.stringArray(forKey: "hiddenDashboardCardIDs") ?? [])
    var hiddenDashboardSectionIDs = Set(UserDefaults.standard.stringArray(forKey: "hiddenDashboardSectionIDs") ?? [])
    var expandedDashboardRouteSectionIDs = Set(UserDefaults.standard.stringArray(forKey: "expandedDashboardRouteSectionIDs") ?? [])
    var workSubscriptions = KeiPixStore.loadSubscriptions()
    var recordedBrowsingHistoryIDs = Set<Int>()

    init(
        api: PixivAPI = PixivAPI(),
        downloads: ArtworkDownloadStore? = nil,
        bootstrapsAutomatically: Bool = true
    ) {
        self.api = api
        self.downloads = downloads ?? ArtworkDownloadStore()
        self.novels = NovelFeatureStore(api: api)

        // Wire CoreSpotlight side effects so finishing or removing a
        // download keeps the system index in sync. The sink stays
        // optional on the download store side, which lets that store
        // stay testable without dragging in the indexer.
        self.downloads.spotlightSink = ArtworkDownloadStore.SpotlightSink(
            didComplete: { [weak self] item in
                self?.registerDownloadInSpotlight(item)
            },
            didRemoveArtworkIDs: { [weak self] ids in
                self?.unregisterDownloadsFromSpotlight(artworkIDs: ids)
            }
        )

        restoreInitialSearchOptionsProfile()

        // Hand the novel store the slices of state it needs to drive
        // its feed dispatcher. Closures keep the dependency one-way —
        // `NovelFeatureStore` never imports `KeiPixStore`, which keeps
        // the surface area small and the cycle-of-references clean.
        novels.passesContentFilter = { [weak self] novel in
            self?.passesNovelContentFilter(novel) ?? true
        }
        novels.rankingDateProvider = { [weak self] in
            self?.rankingDateParameter
        }
        novels.followingRestrictProvider = { [weak self] in
            self?.defaultFollowRestrict.rawValue ?? "public"
        }
        novels.searchKeywordProvider = { [weak self] in
            self?.searchText.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        }
        novels.searchOptionsProvider = { [weak self] in
            self?.searchOptions ?? .defaultValue
        }
        novels.currentUserID = { [weak self] in
            guard let raw = self?.session?.user.id else { return nil }
            return Int(raw)
        }
        novels.focusedUserID = { [weak self] in
            self?.focusedUser?.id
        }

        if bootstrapsAutomatically {
            if VisualQALaunchArgument.isActive {
                activateVisualQASampleSession()
            } else if accountSessionMode == .guest {
                Task { @MainActor in
                    storedAccounts = (try? await api.storedAccounts()) ?? []
                    activateGuestMode()
                }
            } else if accountSessionMode == .visualQA {
                Task { @MainActor in
                    storedAccounts = (try? await api.storedAccounts()) ?? []
                    activateVisualQATestMode()
                }
            }

            if let visualQAGalleryLayoutMode = VisualQALaunchArgument.activeGalleryLayoutMode {
                presentGalleryLayoutVisualQA(mode: visualQAGalleryLayoutMode)
            } else if VisualQALaunchArgument.contains(.cachedFeed) {
                presentCachedFeedVisualQA()
            } else if VisualQALaunchArgument.isActive == false, accountSessionMode == .real {
                Task { await bootstrap() }
            }
        }
    }

    func resetLoadedSessionContent() {
        restrictedModeEnabled = nil
        clearNavigationHistory()
        allArtworks = []
        artworks = []
        activeFeedSnapshotRestoration = nil
        allSearchPopularPreviewArtworks = []
        searchPopularPreviewArtworks = []
        selectedArtwork = nil
        presentedUserProfile = nil
        selectedSpotlightArticle = nil
        pixivCollections = []
        selectedPixivCollection = nil
        selectedPixivCollectionSourceRoute = nil
        pixivCollectionErrorMessage = nil
        pixivActivityFeedScope = .all
        pixivActivityKindFilter = .all
        pixivActivityItems = []
        pixivActivityNewItemIDs = []
        pixivActivityLastRefreshNewCount = 0
        pixivActivityLastRefreshNewItemIDs = []
        pixivActivityNextPage = nil
        pixivActivityLoadedAt = nil
        pixivActivityLoadedInCurrentSession = false
        pixivActivityErrorMessage = nil
        pixivActivityItemsByScope = [:]
        pixivActivityNextPageByScope = [:]
        pixivActivityLoadedAtByScope = [:]
        pixivActivityLoadedInCurrentSessionScopes = []
        pixivActivityNewMarkerDatesByScope = [:]
        isLoadingPixivActivityFeed = false
        isLoadingMorePixivActivityFeed = false
        readerWindowArtwork = nil
        imageSourceSearchRequest = nil
        searchSuggestions = []
        nextURL = nil
        creatorArtworkTagFilter = nil
        resetCreatorTagHydrationState()
        feedNarrowingContext = nil
        activeFeedRequestID = nil
        activeSearchPopularPreviewRequestID = nil
        recordedBrowsingHistoryIDs.removeAll()
    }

    func select(_ route: PixivRoute) {
        focusedUser = nil
        creatorArtworkTagFilter = nil
        resetCreatorTagHydrationState()
        feedNarrowingContext = nil
        if route != .pixivCollectionWorks {
            selectedPixivCollection = nil
            selectedPixivCollectionSourceRoute = nil
        }
        errorMessage = nil
        clearNavigationHistory()
        if route != selectedRoute || route.isOwnBookmarkRoute == false {
            bookmarkTagFilter = nil
        }
        if route.isOwnBookmarkRoute == false {
            bookmarkFeedOptions = .defaultValue
        }
        selectedRoute = route
        HandoffManager.shared.updateActivity(route: route.rawValue)
        if route != .spotlight {
            selectedSpotlightArticle = nil
        }
        if route.usesArtworkFeed {
            if usesLocalSampleAccount {
                presentLocalSampleFeed(for: route)
                return
            }
            Task { await refreshSelectedRouteContentForRouteActivation() }
        } else if route.usesNovelFeed {
            // Novels live on `NovelFeatureStore`. The artwork pipeline
            // is intentionally cleared so the gallery column doesn't
            // show stale illusts behind a novel route.
            activeFeedRequestID = nil
            allArtworks = []
            artworks = []
            activeFeedSnapshotRestoration = nil
            allSearchPopularPreviewArtworks = []
            searchPopularPreviewArtworks = []
            nextURL = nil
            isLoading = false
            Task { await refreshSelectedRouteContentForRouteActivation() }
        } else {
            activeFeedRequestID = nil
            allArtworks = []
            artworks = []
            activeFeedSnapshotRestoration = nil
            allSearchPopularPreviewArtworks = []
            searchPopularPreviewArtworks = []
            nextURL = nil
            isLoading = false
        }
    }

    func openUserFeed(user: PixivUser, route: PixivRoute, recordsNavigation: Bool = true) async {
        focusedUser = user
        bookmarkTagFilter = nil
        bookmarkFeedOptions = .defaultValue
        creatorArtworkTagFilter = nil
        resetCreatorTagHydrationState()
        feedNarrowingContext = nil
        selectedPixivCollection = nil
        selectedSpotlightArticle = nil
        errorMessage = nil
        selectedRoute = route
        if recordsNavigation {
            navigationHistory.push(.creatorFeed(CreatorFeedNavigationTarget(user: user, route: route)))
        }
        await refreshSelectedRouteContent()
    }

    func openCreatorTagFeed(user: PixivUser, tag: CreatorArtworkTag, recordsNavigation: Bool = true) async {
        focusedUser = user
        bookmarkTagFilter = nil
        bookmarkFeedOptions = .defaultValue
        feedNarrowingContext = nil
        selectedPixivCollection = nil
        resetCreatorTagHydrationState()
        let tagFilter = CreatorArtworkTagFilter(
            userID: user.id,
            tag: tag.name,
            expectedCount: tag.count
        )
        creatorArtworkTagFilter = tagFilter
        selectedSpotlightArticle = nil
        errorMessage = nil
        selectedRoute = .userIllustrations
        if recordsNavigation {
            navigationHistory.push(.creatorFeed(CreatorFeedNavigationTarget(
                user: user,
                route: .userIllustrations,
                tagFilter: tagFilter
            )))
        }
        await refreshSelectedRouteContent()
    }

    func clearCreatorFeedContext() async {
        if creatorArtworkTagFilter != nil, let focusedUser {
            await openUserFeed(user: focusedUser, route: .userIllustrations, recordsNavigation: true)
            return
        }

        guard focusedUser != nil else { return }
        focusedUser = nil
        creatorArtworkTagFilter = nil
        resetCreatorTagHydrationState()
        feedNarrowingContext = nil
        selectedSpotlightArticle = nil
        errorMessage = nil
        selectedRoute = routeAfterClearingCreatorContext(from: selectedRoute)
        navigationHistory.push(.route(selectedRoute))
        await refreshSelectedRouteContent()
    }

    func openArtworkFromWebLink(_ artworkID: Int) async {
        guard session != nil, usesLocalSampleAccount == false else {
            isLoginPresented = true
            return
        }

        do {
            let artwork = try await api.illustDetail(illustID: artworkID)
            focusedUser = nil
            bookmarkTagFilter = nil
            bookmarkFeedOptions = .defaultValue
            creatorArtworkTagFilter = nil
            resetCreatorTagHydrationState()
            feedNarrowingContext = .directArtwork(id: artworkID)
            selectedPixivCollection = nil
            selectedSpotlightArticle = nil
            selectedRoute = .illustrations
            allArtworks = [artwork]
            artworks = [artwork]
            activeFeedSnapshotRestoration = nil
            allSearchPopularPreviewArtworks = []
            searchPopularPreviewArtworks = []
            nextURL = nil
            navigateToArtwork(artwork)
            await recordBrowsingHistory(for: artwork)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func reloadCurrentFeed() async {
        let context = currentFeedRequestContext()
        feedNarrowingContext = nil
        if usesLocalSampleAccount {
            presentLocalSampleFeed(for: context.route)
            return
        }
        guard session != nil else {
            allArtworks = []
            artworks = []
            activeFeedSnapshotRestoration = nil
            allSearchPopularPreviewArtworks = []
            searchPopularPreviewArtworks = []
            selectedArtwork = nil
            nextURL = nil
            return
        }
        guard context.route.usesArtworkFeed else {
            allArtworks = []
            artworks = []
            activeFeedSnapshotRestoration = nil
            allSearchPopularPreviewArtworks = []
            searchPopularPreviewArtworks = []
            nextURL = nil
            return
        }

        refreshSearchPopularPreviewIfNeeded(for: context)

        let requestID = UUID()
        activeFeedRequestID = requestID
        isLoading = true
        errorMessage = nil
        activeFeedSnapshotRestoration = nil
        defer {
            if activeFeedRequestID == requestID {
                isLoading = false
                activeFeedRequestID = nil
            }
        }

        do {
            let response = try await loadFeed(for: context.route)
            guard currentFeedRequestContext() == context else { return }
            allArtworks = response.illusts
            nextURL = response.nextURL
            applyContentFilters()
            activeFeedSnapshotRestoration = nil
            storeFeedSnapshot(response, for: context)
            hydrateCreatorTagSummariesIfNeeded(for: artworks, limit: 12)
        } catch {
            guard isCancellationLike(error) == false else { return }
            guard currentFeedRequestContext() == context else { return }
            if context.route.isRankingRoute, useRankingDate {
                setUseRankingDate(false)
                setRankingDate(Self.latestSelectableRankingDate())
                do {
                    let response = try await loadFeed(for: context.route)
                    guard selectedRoute == context.route else { return }
                    allArtworks = response.illusts
                    nextURL = response.nextURL
                    applyContentFilters()
                    activeFeedSnapshotRestoration = nil
                    storeFeedSnapshot(response, for: currentFeedRequestContext())
                    hydrateCreatorTagSummariesIfNeeded(for: artworks, limit: 12)
                    errorMessage = L10n.rankingDateFallbackMessage
                } catch {
                    guard isCancellationLike(error) == false else { return }
                    guard selectedRoute == context.route else { return }
                    if restoreFeedSnapshot(for: currentFeedRequestContext(), error: error) { return }
                    let appError = AppError.from(error)
                    errorMessage = appError.displayMessage
                }
            } else {
                if restoreFeedSnapshot(for: context, error: error) { return }
                let appError = AppError.from(error)
                errorMessage = appError.displayMessage
            }
        }
    }

    func clearFeedNarrowingContext() async {
        guard feedNarrowingContext != nil else { return }
        let preservedArtwork = selectedArtwork
        feedNarrowingContext = nil
        if selectedRoute.usesArtworkFeed {
            await reloadCurrentFeed()
            if let preservedArtwork {
                selectedArtwork = artworks.first(where: { $0.id == preservedArtwork.id }) ?? preservedArtwork
            }
        } else {
            routeRefreshGeneration += 1
        }
    }

    func requestRouteRefresh() {
        if selectedRoute.usesArtworkFeed {
            Task { await reloadCurrentFeed() }
        } else if selectedRoute.usesNovelFeed {
            Task { await novels.refresh(route: selectedRoute) }
        } else if selectedRoute == .pixivActivity {
            Task { await refreshPixivActivityFeed(force: true) }
        } else {
            routeRefreshGeneration += 1
        }
    }

    func refreshSelectedRouteContent() async {
        if selectedRoute.usesArtworkFeed {
            await reloadCurrentFeed()
        } else if selectedRoute.usesNovelFeed {
            clearArtworkPipelineForNonArtworkRoute()
            guard session != nil else { return }
            await novels.refresh(route: selectedRoute)
        } else {
            clearArtworkPipelineForNonArtworkRoute()
            routeRefreshGeneration += 1
        }
    }

    func refreshSelectedRouteContentForRouteActivation() async {
        if selectedRoute.usesArtworkFeed {
            await refreshArtworkFeedForRouteActivation()
        } else if selectedRoute.usesNovelFeed {
            clearArtworkPipelineForNonArtworkRoute()
            guard session != nil else { return }
            let hasReusableContent = novels.hasReusableFeed(for: selectedRoute)
            let shouldRefresh = routeSwitchRefreshExpiration.shouldRefresh(
                hasReusableContent: hasReusableContent,
                cachedAt: novels.feedLoadedAt,
                loadedInCurrentSession: hasReusableContent,
                now: Date()
            )
            if shouldRefresh {
                await novels.refresh(route: selectedRoute)
            }
        } else {
            clearArtworkPipelineForNonArtworkRoute()
            routeRefreshGeneration += 1
        }
    }

    private func refreshArtworkFeedForRouteActivation() async {
        let context = currentFeedRequestContext()
        if let snapshot = feedSnapshotLibrary.snapshot(for: context.snapshotKey),
           snapshot.artworks.isEmpty == false {
            restoreFeedSnapshotForRouteActivation(snapshot)
            let shouldRefresh = routeSwitchRefreshExpiration.shouldRefresh(
                hasReusableContent: true,
                cachedAt: snapshot.savedAt,
                loadedInCurrentSession: routeActivationFreshSnapshotKeys.contains(context.snapshotKey),
                now: Date()
            )
            if shouldRefresh == false { return }
        }
        await reloadCurrentFeed()
    }

    private func clearArtworkPipelineForNonArtworkRoute() {
        activeFeedRequestID = nil
        allArtworks = []
        artworks = []
        activeFeedSnapshotRestoration = nil
        allSearchPopularPreviewArtworks = []
        searchPopularPreviewArtworks = []
        nextURL = nil
        isLoading = false
        isLoadingMore = false
    }

    private func routeAfterClearingCreatorContext(from route: PixivRoute) -> PixivRoute {
        switch route {
        case .userManga:
            .mangaRecommended
        case .userPublicBookmarks:
            .publicBookmarks
        case .userNovels, .userMyPixivNovels, .userNovelBookmarks:
            .novelRecommended
        default:
            .illustrations
        }
    }

    private func isCancellationLike(_ error: Error) -> Bool {
        if error is CancellationError {
            return true
        }
        let nsError = error as NSError
        return nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled
    }

    func loadMore() async {
        guard let nextURL, isLoadingMore == false, activeFeedSnapshotRestoration == nil else { return }
        let context = currentFeedRequestContext()
        isLoadingMore = true
        errorMessage = nil
        defer { isLoadingMore = false }

        do {
            let response = try await api.nextFeed(nextURL)
            guard currentFeedRequestContext() == context else { return }
            allArtworks.append(contentsOf: response.illusts)
            self.nextURL = response.nextURL
            applyContentFilters()
            activeFeedSnapshotRestoration = nil
            storeFeedSnapshot(PixivFeedResponse(illusts: allArtworks, nextURL: response.nextURL), for: context)
            hydrateCreatorTagSummariesIfNeeded(for: artworks, limit: 8)
        } catch {
            guard isCancellationLike(error) == false else { return }
            errorMessage = error.localizedDescription
        }
    }

    private func refreshSearchPopularPreviewIfNeeded(for context: FeedRequestContext) {
        guard context.route == .search,
              context.searchText.isEmpty == false,
              context.searchOptions.sort != .popularPreview else {
            activeSearchPopularPreviewRequestID = nil
            isLoadingSearchPopularPreview = false
            allSearchPopularPreviewArtworks = []
            searchPopularPreviewArtworks = []
            return
        }

        let requestID = UUID()
        activeSearchPopularPreviewRequestID = requestID
        isLoadingSearchPopularPreview = true

        Task {
            do {
                let response = try await api.searchPopularPreview(keyword: context.searchText, options: context.searchOptions)
                guard activeSearchPopularPreviewRequestID == requestID,
                      currentFeedRequestContext() == context else { return }
                allSearchPopularPreviewArtworks = response.illusts
                searchPopularPreviewArtworks = response.illusts.filter(passesContentFilters)
            } catch {
                guard isCancellationLike(error) == false,
                      activeSearchPopularPreviewRequestID == requestID,
                      currentFeedRequestContext() == context else { return }
                allSearchPopularPreviewArtworks = []
                searchPopularPreviewArtworks = []
            }

            if activeSearchPopularPreviewRequestID == requestID {
                isLoadingSearchPopularPreview = false
                activeSearchPopularPreviewRequestID = nil
            }
        }
    }

    func refreshRestrictedModeSetting() async {
        guard session != nil, usesLocalSampleAccount == false else {
            restrictedModeEnabled = nil
            return
        }

        do {
            restrictedModeEnabled = try await api.restrictedModeSettings().isRestrictedModeEnabled
        } catch {
            restrictedModeEnabled = nil
        }
    }

    func setRestrictedModeEnabled(_ value: Bool) async throws {
        let previous = restrictedModeEnabled
        restrictedModeEnabled = value
        do {
            try await api.setRestrictedModeEnabled(value)
        } catch {
            restrictedModeEnabled = previous
            throw error
        }
    }

    /// Pulls the account-wide AI display setting (Pixiv `show_ai`) into the
    /// store. Mirrors `refreshRestrictedModeSetting()` — keeps the value `nil`
    /// when no live session is available so the Settings UI knows to show
    /// "unknown" rather than a stale boolean.
    func refreshAIShowSetting() async {
        guard session != nil, usesLocalSampleAccount == false else {
            aiShowEnabled = nil
            return
        }

        do {
            aiShowEnabled = try await api.aiShowSettings().showAI
        } catch {
            aiShowEnabled = nil
        }
    }

    func setAIShowEnabled(_ value: Bool) async throws {
        let previous = aiShowEnabled
        aiShowEnabled = value
        do {
            let response = try await api.setAIShowEnabled(value)
            aiShowEnabled = response.showAI
        } catch {
            aiShowEnabled = previous
            throw error
        }
    }

    @discardableResult
    func selectAdjacentArtwork(delta: Int) -> Bool {
        guard let selectedArtwork,
              let index = artworks.firstIndex(where: { $0.id == selectedArtwork.id }) else {
            return false
        }
        let nextIndex = index + delta
        guard artworks.indices.contains(nextIndex) else { return false }
        navigateToArtwork(artworks[nextIndex])
        return true
    }

    func randomFromCurrentFeed(opensDetail: Bool = true) -> Bool {
        guard let artwork = artworks.randomElement() else { return false }
        if opensDetail {
            navigateToArtwork(artwork)
        } else {
            selectedArtwork = artwork
        }
        return true
    }

    func surpriseMe() async {
        do {
            let response = try await api.recommendedIllusts()
            guard let artwork = response.illusts.randomElement() else { return }
            navigateToArtwork(artwork)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadFeed(for route: PixivRoute) async throws -> PixivFeedResponse {
        // Ranking routes — use the mode mapping from PixivRoute
        if let mode = route.rankingMode, route.usesNovelFeed == false {
            return try await api.ranking(mode: mode, date: rankingDateParameter)
        }

        switch route {
        // Discovery
        case .illustrations:
            return try await api.recommendedIllusts()
        case .mangaRecommended:
            return try await api.recommendedMangas()
        case .newIllustrations:
            return try await api.latestIllusts(contentType: "illust")
        case .newManga:
            return try await api.latestIllusts(contentType: "manga")

        // Search
        case .search:
            let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard keyword.isEmpty == false else { return .empty }
            return try await api.search(keyword: keyword, options: searchOptions)

        // User content
        case .userIllustrations:
            guard let focusedUser else { throw PixivAPIError.invalidResponse }
            if let creatorArtworkTagFilter, creatorArtworkTagFilter.userID == focusedUser.id {
                return try await api.creatorTaggedIllusts(
                    user: focusedUser,
                    tagName: creatorArtworkTagFilter.tag,
                    expectedCount: creatorArtworkTagFilter.expectedCount
                )
            }
            return try await api.userIllusts(userID: focusedUser.id, type: "illust")
        case .userManga:
            guard let focusedUser else { throw PixivAPIError.invalidResponse }
            return try await api.userIllusts(userID: focusedUser.id, type: "manga")
        case .userMyPixivIllusts:
            guard let focusedUser else { throw PixivAPIError.invalidResponse }
            return try await api.myPixivIllusts(userID: focusedUser.id)
        case .userPublicBookmarks:
            guard let focusedUser else { throw PixivAPIError.invalidResponse }
            return try await api.bookmarks(restrict: "public", userID: "\(focusedUser.id)")

        // Pixiv Web collections
        case .pixivCollectionWorks:
            guard let selectedPixivCollection else { return .empty }
            let detail = try await api.pixivCollectionDetail(id: selectedPixivCollection.id)
            self.selectedPixivCollection = detail
            return PixivFeedResponse(illusts: detail.artworks, nextURL: nil)

        // Own bookmarks
        case .publicBookmarks:
            guard let userID = session?.user.id else { throw PixivAPIError.missingSession }
            return try await api.bookmarks(restrict: "public", userID: userID, tag: bookmarkTagFilter)
        case .privateBookmarks:
            guard let userID = session?.user.id else { throw PixivAPIError.missingSession }
            return try await api.bookmarks(restrict: "private", userID: userID, tag: bookmarkTagFilter)

        // Following
        case .allFollowing:
            return try await api.following(restrict: "all")
        case .following:
            return try await api.following(restrict: "public")
        case .privateFollowing:
            return try await api.following(restrict: "private")

        // History
        case .history:
            return try await api.browsingHistoryIllusts()

        // Non-artwork routes (handled by other systems)
        default:
            return .empty
        }
    }

    func applyContentFilters() {
        let selectedID = selectedArtwork?.id
        let visibleArtworks = allArtworks.filter(passesContentFilters)
        artworks = selectedRoute.isOwnBookmarkRoute
            ? bookmarkFeedOptions.applying(to: visibleArtworks)
            : visibleArtworks
        searchPopularPreviewArtworks = allSearchPopularPreviewArtworks.filter(passesContentFilters)
        if let selectedID, let selected = artworks.first(where: { $0.id == selectedID }) {
            selectedArtwork = selected
        } else {
            selectedArtwork = artworks.first
        }
    }

    func hydrateCreatorTagSummariesIfNeeded(
        for candidates: some Sequence<PixivArtwork>,
        limit: Int = 8,
        reportsSelectionErrors: Bool = false
    ) {
        guard let filter = creatorArtworkTagFilter else { return }
        let ids = candidates
            .lazy
            .filter(\.isPixivWebProfileSummary)
            .map(\.id)
            .filter { id in
                self.hydratingCreatorTagArtworkIDs.contains(id) == false
                    && self.hydratedCreatorTagArtworkIDs.contains(id) == false
                    && self.failedCreatorTagArtworkIDs.contains(id) == false
            }
            .prefix(limit)
        let idArray = Array(ids)
        guard idArray.isEmpty == false else { return }

        hydratingCreatorTagArtworkIDs.formUnion(idArray)
        Task { [filter, idArray, reportsSelectionErrors] in
            for artworkID in idArray {
                do {
                    let detailedArtwork = try await api.illustDetail(illustID: artworkID)
                    guard creatorArtworkTagFilter == filter else { return }
                    replaceLoadedArtwork(detailedArtwork)
                    hydratedCreatorTagArtworkIDs.insert(artworkID)
                    if selectedArtwork?.id == artworkID {
                        selectedArtwork = detailedArtwork
                        WidgetDataProvider.saveArtwork(detailedArtwork)
                    }
                } catch {
                    failedCreatorTagArtworkIDs.insert(artworkID)
                    if reportsSelectionErrors, selectedArtwork?.id == artworkID {
                        self.errorMessage = error.localizedDescription
                    }
                }
                hydratingCreatorTagArtworkIDs.remove(artworkID)
            }
        }
    }

    private func replaceLoadedArtwork(_ artwork: PixivArtwork) {
        if let index = allArtworks.firstIndex(where: { $0.id == artwork.id }) {
            allArtworks[index] = artwork
        }
        if let index = artworks.firstIndex(where: { $0.id == artwork.id }) {
            artworks[index] = artwork
        }
    }

    func resetCreatorTagHydrationState() {
        hydratingCreatorTagArtworkIDs.removeAll()
        hydratedCreatorTagArtworkIDs.removeAll()
        failedCreatorTagArtworkIDs.removeAll()
    }

    func filteredFeedResponse(_ response: PixivFeedResponse) -> PixivFeedResponse {
        PixivFeedResponse(illusts: response.illusts.filter(passesContentFilters), nextURL: response.nextURL)
    }

    private var rankingDateParameter: String? {
        guard useRankingDate else { return nil }
        return Self.rankingDateFormatter.string(from: rankingDate)
    }

    func currentFeedRequestContext() -> FeedRequestContext {
        FeedRequestContext(
            route: selectedRoute,
            focusedUserID: focusedUser?.id,
            searchText: searchText.trimmingCharacters(in: .whitespacesAndNewlines),
            searchSubmissionID: searchSubmissionID,
            bookmarkTagFilter: bookmarkTagFilter,
            bookmarkFeedOptions: bookmarkFeedOptions,
            creatorArtworkTagFilter: creatorArtworkTagFilter,
            pixivCollectionID: selectedPixivCollection?.id,
            useRankingDate: useRankingDate,
            rankingDate: rankingDate,
            searchOptions: searchOptions
        )
    }

    func filteredArtworkSeriesResponse(_ response: PixivArtworkSeriesResponse) -> PixivArtworkSeriesResponse {
        let firstArtwork = response.firstArtwork.flatMap { passesContentFilters($0) ? $0 : nil }
        var illusts = response.illusts.filter(passesContentFilters)
        if let firstArtwork, illusts.contains(where: { $0.id == firstArtwork.id }) == false {
            illusts.insert(firstArtwork, at: 0)
        }

        return PixivArtworkSeriesResponse(
            detail: response.detail,
            firstArtwork: firstArtwork,
            illusts: illusts,
            nextURL: response.nextURL
        )
    }

    func filteredUserPreviewResponse(_ response: PixivUserPreviewResponse) -> PixivUserPreviewResponse {
        PixivUserPreviewResponse(
            userPreviews: response.userPreviews.map { preview in
                PixivUserPreview(
                    user: preview.user,
                    illusts: preview.illusts.filter(passesContentFilters),
                    isMuted: preview.isMuted
                )
            },
            nextURL: response.nextURL
        )
    }

    /// Mirrors `passesContentFilters(_:)` but for novels. Work type and
    /// ugoira filters remain artwork-only, while novel search honors the
    /// shared age, AI, and bookmark thresholds that Pixiv's novel
    /// endpoint can express or KeiPix can safely apply locally.
    func passesNovelContentFilter(_ novel: PixivNovel) -> Bool {
        if hideMutedContent, isMutedLocally(novel: novel) {
            return false
        }
        if hideAIArtworks, novel.isAI {
            return false
        }
        if hideR18GArtworks, novel.isR18G {
            return false
        }
        if hideR18Artworks, novel.isR18Only {
            return false
        }
        if selectedRoute == .novelSearch {
            switch searchAgeLimit {
            case .unlimited:
                break
            case .allAges:
                if novel.isR18 {
                    return false
                }
            case .r18:
                if novel.isR18 == false {
                    return false
                }
            }
            if searchMinimumBookmarks.value > 0, novel.totalBookmarks < searchMinimumBookmarks.value {
                return false
            }
            if searchMaximumBookmarks.value > 0, novel.totalBookmarks > searchMaximumBookmarks.value {
                return false
            }
            if let minimum = searchNovelTextLength.minimum, novel.textLength < minimum {
                return false
            }
            if let maximum = searchNovelTextLength.maximum, novel.textLength > maximum {
                return false
            }
            switch searchAIFilter {
            case .all:
                break
            case .excludeAI:
                if novel.isAI {
                    return false
                }
            case .onlyAI:
                if novel.isAI == false {
                    return false
                }
            }
        }
        return true
    }

    /// Local mute check tailored to a novel. Reuses the same mute lists
    /// as the artwork pipeline so a creator muted from an illust hides
    /// their novels too.
    func isMutedLocally(novel: PixivNovel) -> Bool {
        if novel.isMuted {
            return true
        }
        if mutedUsers[novel.user.id] != nil {
            return true
        }
        return novel.tags.contains { mutedTags.contains($0.name) }
    }

    func passesContentFilters(_ artwork: PixivArtwork) -> Bool {
        if hideMutedContent, isMutedLocally(artwork) {
            return false
        }
        if hideAIArtworks, artwork.isAI {
            return false
        }
        if hideR18GArtworks, artwork.isR18G {
            return false
        }
        if hideR18Artworks, artwork.isR18Only {
            return false
        }
        if selectedRoute == .search {
            switch searchArtworkType {
            case .all:
                break
            case .illustrations:
                if artwork.type != "illust" {
                    return false
                }
            case .manga:
                if artwork.type != "manga" {
                    return false
                }
            }
            if searchMinimumBookmarks.value > 0, artwork.totalBookmarks < searchMinimumBookmarks.value {
                return false
            }
            if searchMaximumBookmarks.value > 0, artwork.totalBookmarks > searchMaximumBookmarks.value {
                return false
            }
            switch searchAIFilter {
            case .all:
                break
            case .excludeAI:
                if artwork.isAI {
                    return false
                }
            case .onlyAI:
                if artwork.isAI == false {
                    return false
                }
            }
            switch searchUgoiraFilter {
            case .all:
                break
            case .onlyUgoira:
                if artwork.isUgoira == false {
                    return false
                }
            case .noUgoira:
                if artwork.isUgoira {
                    return false
                }
            }
        }
        return true
    }

    private static func loadGalleryLayoutMode() -> GalleryLayoutMode {
        let defaults = UserDefaults.standard
        if let rawValue = defaults.string(forKey: "galleryLayoutMode"),
           let mode = GalleryLayoutMode(rawValue: rawValue) {
            return mode
        }

        let mode: GalleryLayoutMode = defaults.bool(forKey: "compactArtworkCards")
            ? .compactGrid
            : .autoMasonry
        defaults.set(mode.rawValue, forKey: "galleryLayoutMode")
        return mode
    }

    private static func loadCreatorListLayoutMode() -> CreatorListLayoutMode {
        let defaults = UserDefaults.standard
        if let rawValue = defaults.string(forKey: "creatorListLayoutMode"),
           let mode = CreatorListLayoutMode(rawValue: rawValue) {
            return mode
        }
        return .auto
    }

    private static func loadSpotlightListLayoutMode() -> SpotlightListLayoutMode {
        let defaults = UserDefaults.standard
        if let rawValue = defaults.string(forKey: "spotlightListLayoutMode"),
           let mode = SpotlightListLayoutMode(rawValue: rawValue) {
            return mode
        }
        return .auto
    }

    private static func loadSavedSearchPresets() -> [SavedSearchPreset] {
        guard let data = UserDefaults.standard.data(forKey: "savedSearchPresets") else {
            return []
        }
        return (try? JSONDecoder().decode([SavedSearchPreset].self, from: data)) ?? []
    }

    static func loadSpotlightArticles(key: String) -> [PixivSpotlightArticle] {
        guard let data = UserDefaults.standard.data(forKey: key) else {
            return []
        }
        return (try? JSONDecoder().decode([PixivSpotlightArticle].self, from: data)) ?? []
    }

    private static func loadSpotlightArticleReadStateLibrary() -> SpotlightArticleReadStateLibrary {
        guard let data = UserDefaults.standard.data(forKey: "spotlightArticleReadStateLibrary") else {
            return SpotlightArticleReadStateLibrary()
        }
        return (try? JSONDecoder().decode(SpotlightArticleReadStateLibrary.self, from: data))
            ?? SpotlightArticleReadStateLibrary()
    }

    private static func loadReaderProgressLibrary() -> ArtworkReaderProgressLibrary {
        guard let data = UserDefaults.standard.data(forKey: "readerProgressLibrary") else {
            return ArtworkReaderProgressLibrary()
        }
        return (try? JSONDecoder().decode(ArtworkReaderProgressLibrary.self, from: data)) ?? ArtworkReaderProgressLibrary()
    }

    private static func loadDownloadedReaderProgressLibrary() -> DownloadedArtworkReaderProgressLibrary {
        guard let data = UserDefaults.standard.data(forKey: "downloadedReaderProgressLibrary") else {
            return DownloadedArtworkReaderProgressLibrary()
        }
        return (try? JSONDecoder().decode(DownloadedArtworkReaderProgressLibrary.self, from: data)) ?? DownloadedArtworkReaderProgressLibrary()
    }

    private static func loadMangaWatchlistReadStateLibrary() -> MangaWatchlistReadStateLibrary {
        guard let data = UserDefaults.standard.data(forKey: "mangaWatchlistReadStateLibrary") else {
            return MangaWatchlistReadStateLibrary()
        }
        return (try? JSONDecoder().decode(MangaWatchlistReadStateLibrary.self, from: data)) ?? MangaWatchlistReadStateLibrary()
    }

    /// Restores the most recent `ReleaseUpdate` we surfaced. Stored as
    /// JSON under a single UserDefaults key (vs. four scalar keys like
    /// the proxy config) because the GitHub fields ride together — we
    /// never want a half-restored release with a tag but no URL.
    private static func loadLatestReleaseUpdate() -> ReleaseUpdate? {
        guard let data = UserDefaults.standard.data(forKey: "latestReleaseUpdate") else {
            return nil
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(ReleaseUpdate.self, from: data)
    }

    func persistSavedSearchPresets() {
        guard let data = try? JSONEncoder().encode(savedSearchPresets) else { return }
        UserDefaults.standard.set(data, forKey: "savedSearchPresets")
    }

    private static func defaultRankingDate() -> Date {
        latestSelectableRankingDate()
    }

    static func rankingDateRange() -> ClosedRange<Date> {
        let earliest = earliestSelectableRankingDate()
        let latest = latestSelectableRankingDate()
        if latest < earliest {
            return earliest...earliest
        }
        return earliest...latest
    }

    static func earliestSelectableRankingDate() -> Date {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = .current
        components.year = 2007
        components.month = 9
        components.day = 10
        return components.date.map { Calendar.current.startOfDay(for: $0) } ?? .distantPast
    }

    static func latestSelectableRankingDate() -> Date {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return calendar.date(byAdding: .day, value: -1, to: today) ?? today
    }

    static func clampedRankingDate(_ date: Date) -> Date {
        let calendar = Calendar.current
        let normalizedDate = calendar.startOfDay(for: date)
        return min(max(normalizedDate, earliestSelectableRankingDate()), latestSelectableRankingDate())
    }

    private static func loadRankingDate() -> Date {
        let stored = UserDefaults.standard.object(forKey: "rankingDate") as? Date ?? defaultRankingDate()
        let clamped = clampedRankingDate(stored)
        if clamped != stored {
            UserDefaults.standard.set(clamped, forKey: "rankingDate")
        }
        return clamped
    }

    private static func loadEnum<T: RawRepresentable>(_ key: String, defaultValue: T) -> T where T.RawValue == String {
        guard let rawValue = UserDefaults.standard.string(forKey: key),
              let value = T(rawValue: rawValue) else {
            return defaultValue
        }
        return value
    }

    private static func loadIntStringDictionary(_ key: String) -> [Int: String] {
        guard let stored = UserDefaults.standard.dictionary(forKey: key) as? [String: String] else {
            return [:]
        }
        return stored.reduce(into: [:]) { result, pair in
            guard let id = Int(pair.key) else { return }
            result[id] = pair.value
        }
    }

    static func stringKeyedDictionary(_ dictionary: [Int: String]) -> [String: String] {
        dictionary.reduce(into: [:]) { result, pair in
            result[String(pair.key)] = pair.value
        }
    }

    private static let rankingDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

struct FeedRequestContext: Equatable {
    let route: PixivRoute
    let focusedUserID: Int?
    let searchText: String
    let searchSubmissionID: Int
    let bookmarkTagFilter: String?
    let bookmarkFeedOptions: BookmarkFeedOptions
    let creatorArtworkTagFilter: CreatorArtworkTagFilter?
    let pixivCollectionID: String?
    let useRankingDate: Bool
    let rankingDate: Date
    let searchOptions: SearchOptions
}
