import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class KeiPixStore {
    let downloads = ArtworkDownloadStore()

    var session: PixivSession?
    var storedAccounts: [PixivStoredAccount] = []
    var selectedRoute: PixivRoute = .illustrations
    var artworks: [PixivArtwork] = []
    var selectedArtwork: PixivArtwork?
    var searchPopularPreviewArtworks: [PixivArtwork] = []
    var isLoadingSearchPopularPreview = false
    var presentedUserProfile: PixivUser?
    var selectedSpotlightArticle: PixivSpotlightArticle?
    var readerWindowArtwork: PixivArtwork?
    var imageSourceSearchRequest: ImageSourceSearchRequest?
    var pendingDangerAction: AppDangerAction?
    var undoAction: AppUndoAction?
    var focusedUser: PixivUser?
    var searchText = ""
    var searchSubmissionID = 0
    var routeRefreshGeneration = 0
    var searchSuggestions: [PixivTag] = []
    var searchHistory = UserDefaults.standard.stringArray(forKey: "searchHistory") ?? []
    var savedSearches = UserDefaults.standard.stringArray(forKey: "savedSearches") ?? []
    var savedSearchPresets = KeiPixStore.loadSavedSearchPresets()
    var bookmarkTagFilter: String?
    var localBrowsingHistory = KeiPixStore.loadLocalBrowsingHistory()
    var spotlightFavoriteArticles = KeiPixStore.loadSpotlightArticles(key: "spotlightFavoriteArticles")
    var spotlightArticleHistory = KeiPixStore.loadSpotlightArticles(key: "spotlightArticleHistory")
    var errorMessage: String?
    var isLoading = false
    var isLoadingMore = false
    var isLoginPresented = false
    var appLanguage = UserDefaults.standard.string(forKey: "appLanguage")
        .flatMap(AppLanguage.init(rawValue:)) ?? .automatic
    var useOriginalImagesInDetail = UserDefaults.standard.bool(forKey: "useOriginalImagesInDetail")
    var galleryLayoutMode = KeiPixStore.loadGalleryLayoutMode()
    var showTranslatedTags = UserDefaults.standard.object(forKey: "showTranslatedTags") as? Bool ?? true
    var showContentBadges = UserDefaults.standard.object(forKey: "showContentBadges") as? Bool ?? true
    var showAccountIdentity = UserDefaults.standard.object(forKey: "showAccountIdentity") as? Bool ?? true
    var privacyModeEnabled = UserDefaults.standard.object(forKey: "privacyModeEnabled") as? Bool ?? false
    var screenCaptureProtectionEnabled = UserDefaults.standard.object(forKey: "screenCaptureProtectionEnabled") as? Bool ?? true
    var hideMutedContent = UserDefaults.standard.object(forKey: "hideMutedContent") as? Bool ?? true
    var hideAIArtworks = UserDefaults.standard.bool(forKey: "hideAIArtworks")
    var hideR18Artworks = UserDefaults.standard.bool(forKey: "hideR18Artworks")
    var hideR18GArtworks = UserDefaults.standard.bool(forKey: "hideR18GArtworks")
    var maskSensitivePreviews = UserDefaults.standard.object(forKey: "maskSensitivePreviews") as? Bool ?? false
    var restrictedModeEnabled: Bool?
    var defaultBookmarkRestrict = KeiPixStore.loadEnum("defaultBookmarkRestrict", defaultValue: BookmarkRestrict.public)
    var defaultFollowRestrict = KeiPixStore.loadEnum("defaultFollowRestrict", defaultValue: BookmarkRestrict.public)
    var followCreatorAfterBookmark = UserDefaults.standard.object(forKey: "followCreatorAfterBookmark") as? Bool ?? false
    var autoDownloadBookmarkedArtworks = UserDefaults.standard.object(forKey: "autoDownloadBookmarkedArtworks") as? Bool ?? false
    var autoTagBookmarksWithArtworkTags = UserDefaults.standard.object(forKey: "autoTagBookmarksWithArtworkTags") as? Bool ?? false
    var searchMatchType = KeiPixStore.loadEnum("searchMatchType", defaultValue: SearchMatchType.partialTags)
    var searchSort = KeiPixStore.loadEnum("searchSort", defaultValue: SearchSort.dateDescending)
    var searchAgeLimit = KeiPixStore.loadEnum("searchAgeLimit", defaultValue: SearchAgeLimit.unlimited)
    var searchDateRange = KeiPixStore.loadEnum("searchDateRange", defaultValue: SearchDateRange.anytime)
    var searchMinimumBookmarks = SearchMinimumBookmarks(
        rawValue: UserDefaults.standard.integer(forKey: "searchMinimumBookmarks")
    ) ?? .none
    var searchMaximumBookmarks = SearchMaximumBookmarks(
        rawValue: UserDefaults.standard.integer(forKey: "searchMaximumBookmarks")
    ) ?? .none
    var searchArtworkType = KeiPixStore.loadEnum("searchArtworkType", defaultValue: SearchArtworkType.all)
    var searchAIFilter = KeiPixStore.loadEnum("searchAIFilter", defaultValue: SearchAIFilter.all)
    var searchUgoiraFilter = KeiPixStore.loadEnum("searchUgoiraFilter", defaultValue: SearchUgoiraFilter.all)
    var useRankingDate = UserDefaults.standard.object(forKey: "useRankingDate") as? Bool ?? false
    var rankingDate = KeiPixStore.loadRankingDate()
    var trackpadGesturesEnabled = UserDefaults.standard.object(forKey: "trackpadGesturesEnabled") as? Bool ?? true
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
    var isMainWindowCaptureProtected: Bool {
        screenCaptureProtectionEnabled && selectedArtwork?.requiresScreenCaptureProtection == true
    }
    var isReaderWindowCaptureProtected: Bool {
        screenCaptureProtectionEnabled && readerWindowArtwork?.requiresScreenCaptureProtection == true
    }

    let api = PixivAPI()
    var allArtworks: [PixivArtwork] = []
    private var allSearchPopularPreviewArtworks: [PixivArtwork] = []
    private var nextURL: URL?
    private var activeFeedRequestID: UUID?
    private var activeSearchPopularPreviewRequestID: UUID?
    var mutedTags = Set(UserDefaults.standard.stringArray(forKey: "mutedTags") ?? [])
    var mutedUsers = KeiPixStore.loadIntStringDictionary("mutedUsers")
    var mutedArtworks = KeiPixStore.loadIntStringDictionary("mutedArtworks")
    var mutedCommentPhrases = Set(UserDefaults.standard.stringArray(forKey: "mutedCommentPhrases") ?? [])
    var recordedBrowsingHistoryIDs = Set<Int>()

    init() {
        Task { await bootstrap() }
    }

    func bootstrap() async {
        do {
            storedAccounts = try await api.storedAccounts()
            session = try await api.loadSession()
            storedAccounts = try await api.storedAccounts()
            if session != nil {
                await refreshRestrictedModeSetting()
                await reloadCurrentFeed()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loginURL() async -> URL {
        await api.makeLoginURL()
    }

    func completeLogin(code: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            session = try await api.login(code: code)
            storedAccounts = try await api.storedAccounts()
            isLoginPresented = false
            selectedRoute = .illustrations
            await refreshRestrictedModeSetting()
            await reloadCurrentFeed()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func logout() async {
        do {
            session = try await api.clearSession()
            storedAccounts = try await api.storedAccounts()
            resetLoadedSessionContent()
            if session != nil {
                await refreshRestrictedModeSetting()
                await reloadCurrentFeed()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func switchAccount(userID: String) async {
        guard session?.user.id != userID else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            session = try await api.selectAccount(userID: userID)
            storedAccounts = try await api.storedAccounts()
            resetLoadedSessionContent()
            selectedRoute = .illustrations
            if session != nil {
                await refreshRestrictedModeSetting()
                await reloadCurrentFeed()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func removeStoredAccount(userID: String) async {
        do {
            session = try await api.deleteAccount(userID: userID)
            storedAccounts = try await api.storedAccounts()
            resetLoadedSessionContent()
            if session != nil {
                await refreshRestrictedModeSetting()
                await reloadCurrentFeed()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func resetLoadedSessionContent() {
        restrictedModeEnabled = nil
        allArtworks = []
        artworks = []
        allSearchPopularPreviewArtworks = []
        searchPopularPreviewArtworks = []
        selectedArtwork = nil
        presentedUserProfile = nil
        selectedSpotlightArticle = nil
        readerWindowArtwork = nil
        imageSourceSearchRequest = nil
        searchSuggestions = []
        nextURL = nil
        activeFeedRequestID = nil
        activeSearchPopularPreviewRequestID = nil
        recordedBrowsingHistoryIDs.removeAll()
    }

    func select(_ route: PixivRoute) {
        focusedUser = nil
        errorMessage = nil
        if route != selectedRoute || route.isOwnBookmarkRoute == false {
            bookmarkTagFilter = nil
        }
        selectedRoute = route
        if route != .spotlight {
            selectedSpotlightArticle = nil
        }
        if route.usesArtworkFeed {
            Task { await reloadCurrentFeed() }
        } else {
            activeFeedRequestID = nil
            allArtworks = []
            artworks = []
            allSearchPopularPreviewArtworks = []
            searchPopularPreviewArtworks = []
            nextURL = nil
            isLoading = false
        }
    }

    func openUserFeed(user: PixivUser, route: PixivRoute) async {
        focusedUser = user
        bookmarkTagFilter = nil
        selectedSpotlightArticle = nil
        errorMessage = nil
        selectedRoute = route
        await reloadCurrentFeed()
    }

    func openArtworkFromWebLink(_ artworkID: Int) async {
        guard session != nil else {
            isLoginPresented = true
            return
        }

        do {
            let artwork = try await api.illustDetail(illustID: artworkID)
            focusedUser = nil
            bookmarkTagFilter = nil
            selectedSpotlightArticle = nil
            selectedRoute = .illustrations
            allArtworks = [artwork]
            artworks = [artwork]
            allSearchPopularPreviewArtworks = []
            searchPopularPreviewArtworks = []
            selectedArtwork = artwork
            await recordBrowsingHistory(for: artwork)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @discardableResult
    func openPixivLink(_ url: URL) async -> String {
        guard let destination = PixivWebLinkResolver.destination(from: url) else {
            errorMessage = L10n.unsupportedPixivLink
            return L10n.unsupportedPixivLink
        }

        guard session != nil else {
            isLoginPresented = true
            return L10n.loginRequiredForPixivLink
        }

        do {
            try await openPixivDestination(destination)
            return String(format: L10n.openedPixivLinkFormat, destination.normalizedLabel)
        } catch {
            errorMessage = error.localizedDescription
            return error.localizedDescription
        }
    }

    @discardableResult
    func openPixivLinkFromClipboard() async -> String {
        guard let rawText = NSPasteboard.general.string(forType: .string)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              rawText.isEmpty == false,
              let url = URL(string: rawText) else {
            errorMessage = L10n.noPixivLinkInClipboard
            return L10n.noPixivLinkInClipboard
        }

        return await openPixivLink(url)
    }

    @discardableResult
    func openPixivID(_ id: Int, target: PixivIDOpenTarget) async -> String {
        guard session != nil else {
            isLoginPresented = true
            return L10n.loginRequiredForPixivLink
        }

        do {
            switch target {
            case .artwork:
                try await openPixivDestination(.artwork(id))
            case .creator:
                try await openPixivDestination(.user(id))
            }
            return String(format: L10n.openedPixivIDFormat, target.title, id)
        } catch {
            errorMessage = error.localizedDescription
            return error.localizedDescription
        }
    }

    private func openPixivDestination(_ destination: PixivWebDestination) async throws {
        switch destination {
        case .artwork(let id):
            let artwork = try await api.illustDetail(illustID: id)
            focusedUser = nil
            bookmarkTagFilter = nil
            selectedSpotlightArticle = nil
            selectedRoute = .illustrations
            allArtworks = [artwork]
            artworks = [artwork]
            selectedArtwork = artwork
            nextURL = nil
            await recordBrowsingHistory(for: artwork)
        case .user(let id):
            let detail = try await api.userDetail(userID: id)
            await openUserFeed(user: detail.user, route: .userIllustrations)
        case .tag(let keyword), .search(let keyword):
            searchText = keyword
            await runSearch()
        case .creatorSearch(let keyword):
            focusedUser = nil
            bookmarkTagFilter = nil
            selectedSpotlightArticle = nil
            searchText = keyword
            selectedRoute = .searchUsers
            searchSubmissionID += 1
        case .pixivisionArticle(let id, let url):
            focusedUser = nil
            bookmarkTagFilter = nil
            selectedArtwork = nil
            allArtworks = []
            artworks = []
            allSearchPopularPreviewArtworks = []
            searchPopularPreviewArtworks = []
            nextURL = nil
            selectedRoute = .spotlight
            selectedSpotlightArticle = .linkPlaceholder(id: id, url: normalizedPixivisionURL(id: id, sourceURL: url))
        }
    }

    private func normalizedPixivisionURL(id: Int, sourceURL: URL) -> URL {
        if let host = sourceURL.host(percentEncoded: false)?.lowercased(),
           host == "pixivision.net" || host == "www.pixivision.net" {
            return sourceURL
        }
        return URL(string: "https://www.pixivision.net/a/\(id)")!
    }

    func reloadCurrentFeed() async {
        let context = currentFeedRequestContext()
        guard session != nil else {
            allArtworks = []
            artworks = []
            allSearchPopularPreviewArtworks = []
            searchPopularPreviewArtworks = []
            selectedArtwork = nil
            nextURL = nil
            return
        }
        guard context.route.usesArtworkFeed else {
            allArtworks = []
            artworks = []
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
                    errorMessage = L10n.rankingDateFallbackMessage
                } catch {
                    guard isCancellationLike(error) == false else { return }
                    guard selectedRoute == context.route else { return }
                    errorMessage = error.localizedDescription
                }
            } else {
                errorMessage = error.localizedDescription
            }
        }
    }

    func requestRouteRefresh() {
        if selectedRoute.usesArtworkFeed {
            Task { await reloadCurrentFeed() }
        } else {
            routeRefreshGeneration += 1
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
        guard let nextURL, isLoadingMore == false else { return }
        isLoadingMore = true
        errorMessage = nil
        defer { isLoadingMore = false }

        do {
            let response = try await api.nextFeed(nextURL)
            allArtworks.append(contentsOf: response.illusts)
            self.nextURL = response.nextURL
            applyContentFilters()
        } catch {
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

    func runSearch() async {
        searchSuggestions = []
        errorMessage = nil
        let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if keyword.isEmpty == false {
            recordSearch(keyword)
        }
        if let request = PixivIDQuickOpenParser.request(from: keyword) {
            _ = await openPixivID(request.id, target: request.target)
            return
        }
        if selectedRoute == .searchUsers {
            searchSubmissionID += 1
            allSearchPopularPreviewArtworks = []
            searchPopularPreviewArtworks = []
            isLoadingSearchPopularPreview = false
            return
        }
        focusedUser = nil
        bookmarkTagFilter = nil
        selectedSpotlightArticle = nil
        selectedRoute = .search
        await reloadCurrentFeed()
    }

    func refreshSearchSuggestions() async {
        guard session != nil else {
            searchSuggestions = []
            return
        }

        let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard keyword.isEmpty == false else {
            searchSuggestions = []
            return
        }

        do {
            try await Task.sleep(for: .milliseconds(260))
            let suggestions = try await api.searchAutocomplete(keyword: keyword)
            guard keyword == searchText.trimmingCharacters(in: .whitespacesAndNewlines) else { return }
            searchSuggestions = suggestions.uniquedByName().prefixArray(10)
        } catch is CancellationError {
        } catch {
            searchSuggestions = []
        }
    }

    var searchOptions: SearchOptions {
        SearchOptions(
            matchType: searchMatchType,
            sort: effectiveSearchSort,
            ageLimit: searchAgeLimit,
            dateRange: searchDateRange,
            minimumBookmarks: searchMinimumBookmarks,
            maximumBookmarks: searchMaximumBookmarks,
            artworkType: searchArtworkType,
            aiFilter: searchAIFilter,
            ugoiraFilter: searchUgoiraFilter
        )
    }

    var effectiveSearchSort: SearchSort {
        if searchSort.requiresPixivPremium, session?.user.isPremium != true {
            return .popularPreview
        }
        return searchSort
    }

    func resetSearchOptions() {
        setSearchMatchType(.partialTags)
        setSearchSort(.dateDescending)
        setSearchAgeLimit(.unlimited)
        setSearchDateRange(.anytime)
        setSearchMinimumBookmarks(.none)
        setSearchMaximumBookmarks(.none)
        setSearchArtworkType(.all)
        setSearchAIFilter(.all)
        setSearchUgoiraFilter(.all)
    }

    func refreshRestrictedModeSetting() async {
        guard session != nil else {
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

    @discardableResult
    func selectAdjacentArtwork(delta: Int) -> Bool {
        guard let selectedArtwork,
              let index = artworks.firstIndex(where: { $0.id == selectedArtwork.id }) else {
            return false
        }
        let nextIndex = index + delta
        guard artworks.indices.contains(nextIndex) else { return false }
        self.selectedArtwork = artworks[nextIndex]
        return true
    }

    private func loadFeed(for route: PixivRoute) async throws -> PixivFeedResponse {
        switch route {
        case .illustrations:
            return try await api.recommendedIllusts()
        case .mangaRecommended:
            return try await api.recommendedMangas()
        case .newIllustrations:
            return try await api.latestIllusts(contentType: "illust")
        case .newManga:
            return try await api.latestIllusts(contentType: "manga")
        case .search:
            let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            if keyword.isEmpty {
                return PixivFeedResponse(illusts: [], nextURL: nil)
            }
            return try await api.search(keyword: keyword, options: searchOptions)
        case .userIllustrations:
            guard let focusedUser else { throw PixivAPIError.invalidResponse }
            return try await api.userIllusts(userID: focusedUser.id, type: "illust")
        case .userManga:
            guard let focusedUser else { throw PixivAPIError.invalidResponse }
            return try await api.userIllusts(userID: focusedUser.id, type: "manga")
        case .userPublicBookmarks:
            guard let focusedUser else { throw PixivAPIError.invalidResponse }
            return try await api.bookmarks(restrict: "public", userID: "\(focusedUser.id)")
        case .rankingDaily:
            return try await api.ranking(mode: "day", date: rankingDateParameter)
        case .rankingWeekly:
            return try await api.ranking(mode: "week", date: rankingDateParameter)
        case .rankingMonthly:
            return try await api.ranking(mode: "month", date: rankingDateParameter)
        case .rankingDailyMale:
            return try await api.ranking(mode: "day_male", date: rankingDateParameter)
        case .rankingDailyFemale:
            return try await api.ranking(mode: "day_female", date: rankingDateParameter)
        case .rankingWeeklyOriginal:
            return try await api.ranking(mode: "week_original", date: rankingDateParameter)
        case .rankingWeeklyRookie:
            return try await api.ranking(mode: "week_rookie", date: rankingDateParameter)
        case .rankingDailyAI:
            return try await api.ranking(mode: "day_ai", date: rankingDateParameter)
        case .rankingDailyR18AI:
            return try await api.ranking(mode: "day_r18_ai", date: rankingDateParameter)
        case .rankingDailyR18:
            return try await api.ranking(mode: "day_r18", date: rankingDateParameter)
        case .rankingWeeklyR18:
            return try await api.ranking(mode: "week_r18", date: rankingDateParameter)
        case .rankingWeeklyR18G:
            return try await api.ranking(mode: "week_r18g", date: rankingDateParameter)
        case .mangaRankingDaily:
            return try await api.ranking(mode: "day_manga", date: rankingDateParameter)
        case .mangaRankingWeekly:
            return try await api.ranking(mode: "week_manga", date: rankingDateParameter)
        case .mangaRankingMonthly:
            return try await api.ranking(mode: "month_manga", date: rankingDateParameter)
        case .mangaRankingDailyR18:
            return try await api.ranking(mode: "day_r18_manga", date: rankingDateParameter)
        case .publicBookmarks:
            guard let userID = session?.user.id else { throw PixivAPIError.missingSession }
            return try await api.bookmarks(restrict: "public", userID: userID, tag: bookmarkTagFilter)
        case .privateBookmarks:
            guard let userID = session?.user.id else { throw PixivAPIError.missingSession }
            return try await api.bookmarks(restrict: "private", userID: userID, tag: bookmarkTagFilter)
        case .allFollowing:
            return try await api.following(restrict: "all")
        case .following:
            return try await api.following(restrict: "public")
        case .privateFollowing:
            return try await api.following(restrict: "private")
        case .history:
            return try await api.browsingHistoryIllusts()
        case .mangaWatchlist, .downloads, .savedSearches, .trendingTags, .bookmarkTags, .mutedContent, .spotlight:
            return PixivFeedResponse(illusts: [], nextURL: nil)
        case .followingCreators, .recommendedUsers, .searchUsers:
            return PixivFeedResponse(illusts: [], nextURL: nil)
        }
    }

    func applyContentFilters() {
        let selectedID = selectedArtwork?.id
        artworks = allArtworks.filter(passesContentFilters)
        searchPopularPreviewArtworks = allSearchPopularPreviewArtworks.filter(passesContentFilters)
        if let selectedID, let selected = artworks.first(where: { $0.id == selectedID }) {
            selectedArtwork = selected
        } else {
            selectedArtwork = artworks.first
        }
    }

    func filteredFeedResponse(_ response: PixivFeedResponse) -> PixivFeedResponse {
        PixivFeedResponse(illusts: response.illusts.filter(passesContentFilters), nextURL: response.nextURL)
    }

    private var rankingDateParameter: String? {
        guard useRankingDate else { return nil }
        return Self.rankingDateFormatter.string(from: rankingDate)
    }

    private func currentFeedRequestContext() -> FeedRequestContext {
        FeedRequestContext(
            route: selectedRoute,
            focusedUserID: focusedUser?.id,
            searchText: searchText.trimmingCharacters(in: .whitespacesAndNewlines),
            searchSubmissionID: searchSubmissionID,
            bookmarkTagFilter: bookmarkTagFilter,
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
        if hideR18Artworks, artwork.isR18 {
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
            if searchMinimumBookmarks.rawValue > 0, artwork.totalBookmarks < searchMinimumBookmarks.rawValue {
                return false
            }
            if searchMaximumBookmarks.rawValue > 0, artwork.totalBookmarks > searchMaximumBookmarks.rawValue {
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

private struct FeedRequestContext: Equatable {
    let route: PixivRoute
    let focusedUserID: Int?
    let searchText: String
    let searchSubmissionID: Int
    let bookmarkTagFilter: String?
    let useRankingDate: Bool
    let rankingDate: Date
    let searchOptions: SearchOptions
}
