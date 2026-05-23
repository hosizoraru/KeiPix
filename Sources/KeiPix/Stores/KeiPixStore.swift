import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class KeiPixStore {
    let downloads = ArtworkDownloadStore()

    var session: PixivSession?
    var selectedRoute: PixivRoute = .illustrations
    var artworks: [PixivArtwork] = []
    var selectedArtwork: PixivArtwork?
    var readerWindowArtwork: PixivArtwork?
    var focusedUser: PixivUser?
    var searchText = ""
    var searchSubmissionID = 0
    var searchSuggestions: [PixivTag] = []
    var searchHistory = UserDefaults.standard.stringArray(forKey: "searchHistory") ?? []
    var savedSearches = UserDefaults.standard.stringArray(forKey: "savedSearches") ?? []
    var bookmarkTagFilter: String?
    var errorMessage: String?
    var isLoading = false
    var isLoadingMore = false
    var isLoginPresented = false
    var appLanguage = UserDefaults.standard.string(forKey: "appLanguage")
        .flatMap(AppLanguage.init(rawValue:)) ?? .automatic
    var useOriginalImagesInDetail = UserDefaults.standard.bool(forKey: "useOriginalImagesInDetail")
    var galleryLayoutMode = KeiPixStore.loadGalleryLayoutMode()
    var showContentBadges = UserDefaults.standard.object(forKey: "showContentBadges") as? Bool ?? true
    var showAccountIdentity = UserDefaults.standard.object(forKey: "showAccountIdentity") as? Bool ?? true
    var privacyModeEnabled = UserDefaults.standard.object(forKey: "privacyModeEnabled") as? Bool ?? false
    var screenCaptureProtectionEnabled = UserDefaults.standard.object(forKey: "screenCaptureProtectionEnabled") as? Bool ?? true
    var hideMutedContent = UserDefaults.standard.object(forKey: "hideMutedContent") as? Bool ?? true
    var hideAIArtworks = UserDefaults.standard.bool(forKey: "hideAIArtworks")
    var hideR18Artworks = UserDefaults.standard.bool(forKey: "hideR18Artworks")
    var hideR18GArtworks = UserDefaults.standard.bool(forKey: "hideR18GArtworks")
    var restrictedModeEnabled: Bool?
    var defaultBookmarkRestrict = KeiPixStore.loadEnum("defaultBookmarkRestrict", defaultValue: BookmarkRestrict.public)
    var defaultFollowRestrict = KeiPixStore.loadEnum("defaultFollowRestrict", defaultValue: BookmarkRestrict.public)
    var searchMatchType = KeiPixStore.loadEnum("searchMatchType", defaultValue: SearchMatchType.partialTags)
    var searchSort = KeiPixStore.loadEnum("searchSort", defaultValue: SearchSort.dateDescending)
    var searchAgeLimit = KeiPixStore.loadEnum("searchAgeLimit", defaultValue: SearchAgeLimit.unlimited)
    var searchDateRange = KeiPixStore.loadEnum("searchDateRange", defaultValue: SearchDateRange.anytime)
    var searchMinimumBookmarks = SearchMinimumBookmarks(
        rawValue: UserDefaults.standard.integer(forKey: "searchMinimumBookmarks")
    ) ?? .none
    var searchArtworkType = KeiPixStore.loadEnum("searchArtworkType", defaultValue: SearchArtworkType.all)
    var searchUgoiraFilter = KeiPixStore.loadEnum("searchUgoiraFilter", defaultValue: SearchUgoiraFilter.all)
    var useRankingDate = UserDefaults.standard.object(forKey: "useRankingDate") as? Bool ?? false
    var rankingDate = UserDefaults.standard.object(forKey: "rankingDate") as? Date ?? KeiPixStore.defaultRankingDate()
    var trackpadGesturesEnabled = UserDefaults.standard.object(forKey: "trackpadGesturesEnabled") as? Bool ?? true
    var horizontalSwipeBehavior = UserDefaults.standard.string(forKey: "horizontalSwipeBehavior")
        .flatMap(TrackpadHorizontalSwipeBehavior.init(rawValue:)) ?? .pageOnly
    var hasNextPage: Bool { nextURL != nil }
    var compactArtworkCards: Bool { galleryLayoutMode.usesCompactGrid }
    var showsSidebarAccountIdentity: Bool { showAccountIdentity && privacyModeEnabled == false }
    var isMainWindowCaptureProtected: Bool {
        screenCaptureProtectionEnabled && selectedArtwork?.requiresScreenCaptureProtection == true
    }
    var isReaderWindowCaptureProtected: Bool {
        screenCaptureProtectionEnabled && readerWindowArtwork?.requiresScreenCaptureProtection == true
    }

    private let api = PixivAPI()
    private var allArtworks: [PixivArtwork] = []
    private var nextURL: URL?
    private var mutedTags = Set(UserDefaults.standard.stringArray(forKey: "mutedTags") ?? [])
    private var mutedUsers = KeiPixStore.loadIntStringDictionary("mutedUsers")
    private var mutedArtworks = KeiPixStore.loadIntStringDictionary("mutedArtworks")
    private var recordedBrowsingHistoryIDs = Set<Int>()

    init() {
        Task { await bootstrap() }
    }

    func bootstrap() async {
        do {
            session = try await api.loadSession()
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
            try await api.clearSession()
            session = nil
            restrictedModeEnabled = nil
            allArtworks = []
            artworks = []
            selectedArtwork = nil
            readerWindowArtwork = nil
            searchSuggestions = []
            nextURL = nil
            recordedBrowsingHistoryIDs.removeAll()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func select(_ route: PixivRoute) {
        focusedUser = nil
        if route != selectedRoute || route.isOwnBookmarkRoute == false {
            bookmarkTagFilter = nil
        }
        selectedRoute = route
        if route.usesArtworkFeed {
            Task { await reloadCurrentFeed() }
        } else {
            allArtworks = []
            artworks = []
            nextURL = nil
        }
    }

    func openUserFeed(user: PixivUser, route: PixivRoute) async {
        focusedUser = user
        selectedRoute = route
        await reloadCurrentFeed()
    }

    func reloadCurrentFeed() async {
        guard session != nil else {
            allArtworks = []
            artworks = []
            selectedArtwork = nil
            nextURL = nil
            return
        }
        guard selectedRoute.usesArtworkFeed else {
            allArtworks = []
            artworks = []
            nextURL = nil
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let response = try await loadFeed(for: selectedRoute)
            allArtworks = response.illusts
            nextURL = response.nextURL
            applyContentFilters()
        } catch {
            errorMessage = error.localizedDescription
        }
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

    func runSearch() async {
        searchSuggestions = []
        let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if keyword.isEmpty == false {
            recordSearch(keyword)
        }
        if selectedRoute == .searchUsers {
            searchSubmissionID += 1
            return
        }
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

    func matchingLocalSearchTerms(limit: Int = 8) -> [String] {
        let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let source = (savedSearches + searchHistory).uniquedCaseInsensitive()
        let matches = keyword.isEmpty
            ? source
            : source.filter { $0.localizedCaseInsensitiveContains(keyword) }
        return Array(matches.prefix(limit))
    }

    func saveCurrentSearch() {
        saveSearch(searchText)
    }

    func saveSearch(_ keyword: String) {
        let normalized = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.isEmpty == false else { return }
        savedSearches.removeAll { $0.localizedCaseInsensitiveCompare(normalized) == .orderedSame }
        savedSearches.insert(normalized, at: 0)
        savedSearches = Array(savedSearches.prefix(50))
        UserDefaults.standard.set(savedSearches, forKey: "savedSearches")
    }

    func removeSavedSearch(_ keyword: String) {
        savedSearches.removeAll { $0.localizedCaseInsensitiveCompare(keyword) == .orderedSame }
        UserDefaults.standard.set(savedSearches, forKey: "savedSearches")
    }

    func clearSearchHistory() {
        searchHistory = []
        UserDefaults.standard.set(searchHistory, forKey: "searchHistory")
    }

    func runSavedSearch(_ keyword: String) async {
        searchText = keyword
        selectedRoute = .search
        await runSearch()
    }

    private func recordSearch(_ keyword: String) {
        let normalized = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.isEmpty == false else { return }
        searchHistory.removeAll { $0.localizedCaseInsensitiveCompare(normalized) == .orderedSame }
        searchHistory.insert(normalized, at: 0)
        searchHistory = Array(searchHistory.prefix(50))
        UserDefaults.standard.set(searchHistory, forKey: "searchHistory")
    }

    func toggleBookmark(_ artwork: PixivArtwork) async {
        let nextValue = !artwork.isBookmarked
        do {
            if nextValue {
                try await api.addBookmark(illustID: artwork.id, restrict: defaultBookmarkRestrict, tags: [])
            } else {
                try await api.deleteBookmark(illustID: artwork.id)
            }
            updateArtwork(artwork.id) { $0.isBookmarked = nextValue }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func bookmarkDetail(for artwork: PixivArtwork) async throws -> PixivBookmarkDetail {
        try await api.bookmarkDetail(illustID: artwork.id)
    }

    func bookmarkTagSuggestions(restrict: BookmarkRestrict) async throws -> [PixivBookmarkTag] {
        guard let userID = session?.user.id else { throw PixivAPIError.missingSession }
        return try await api.bookmarkTags(userID: userID, restrict: restrict)
    }

    func saveBookmark(_ artwork: PixivArtwork, restrict: BookmarkRestrict, tags: [String]) async throws {
        try await api.addBookmark(illustID: artwork.id, restrict: restrict, tags: tags)
        updateArtwork(artwork.id) { $0.isBookmarked = true }
    }

    func setBookmarkTagFilter(_ tag: String?) {
        bookmarkTagFilter = tag
        Task { await reloadCurrentFeed() }
    }

    func removeBookmark(_ artwork: PixivArtwork) async throws {
        try await api.deleteBookmark(illustID: artwork.id)
        updateArtwork(artwork.id) { $0.isBookmarked = false }
    }

    func toggleSelectedBookmark() async {
        guard let selectedArtwork else { return }
        await toggleBookmark(selectedArtwork)
    }

    func downloadSelectedArtwork() {
        guard let selectedArtwork else { return }
        downloads.enqueue(selectedArtwork, preferOriginal: true)
    }

    func openSelectedArtworkInPixiv() {
        guard let url = selectedArtwork?.pixivURL else { return }
        NSWorkspace.shared.open(url)
    }

    func copySelectedArtworkLink() {
        guard let url = selectedArtwork?.pixivURL else { return }
        PasteboardWriter.copy(url.absoluteString)
    }

    func prepareReaderWindow(for artwork: PixivArtwork) {
        readerWindowArtwork = artwork
    }

    func prepareSelectedReaderWindow() {
        guard let selectedArtwork else { return }
        prepareReaderWindow(for: selectedArtwork)
    }

    func selectPreviousArtwork() {
        selectAdjacentArtwork(delta: -1)
    }

    func selectNextArtwork() {
        selectAdjacentArtwork(delta: 1)
    }

    func toggleFollow(_ user: PixivUser, restrict: BookmarkRestrict? = nil) async {
        let nextValue = !user.isFollowed
        let followRestrict = restrict ?? defaultFollowRestrict
        do {
            try await api.setFollow(userID: user.id, isFollowed: nextValue, restrict: followRestrict)
            for index in allArtworks.indices where allArtworks[index].user.id == user.id {
                allArtworks[index].user.isFollowed = nextValue
            }
            for index in artworks.indices where artworks[index].user.id == user.id {
                artworks[index].user.isFollowed = nextValue
            }
            if selectedArtwork?.user.id == user.id {
                selectedArtwork?.user.isFollowed = nextValue
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadUgoiraAnimation(for artwork: PixivArtwork) async throws -> UgoiraAnimation {
        let metadata = try await api.ugoiraMetadata(illustID: artwork.id)
        let zipData = try await api.ugoiraZipData(url: metadata.zipURLs.medium)
        return try UgoiraFrameDecoder.decode(zipData: zipData, metadata: metadata)
    }

    func userDetail(for user: PixivUser) async throws -> PixivUserDetail {
        try await api.userDetail(userID: user.id)
    }

    func followDetail(for user: PixivUser) async throws -> PixivFollowDetail {
        try await api.followDetail(userID: user.id)
    }

    func recommendedUsers() async throws -> PixivUserPreviewResponse {
        let response = try await api.recommendedUsers()
        return filteredUserPreviewResponse(response)
    }

    func relatedUsers(for user: PixivUser) async throws -> PixivUserPreviewResponse {
        let response = try await api.relatedUsers(userID: user.id)
        return filteredUserPreviewResponse(response)
    }

    func searchUsers(keyword: String) async throws -> PixivUserPreviewResponse {
        let response = try await api.searchUsers(keyword: keyword)
        return filteredUserPreviewResponse(response)
    }

    func followingUsers(restrict: BookmarkRestrict) async throws -> PixivUserPreviewResponse {
        guard let userID = session?.user.id else { throw PixivAPIError.missingSession }
        let response = try await api.followingUsers(userID: userID, restrict: restrict.rawValue)
        return filteredUserPreviewResponse(response)
    }

    func followingUsers(for user: PixivUser, restrict: BookmarkRestrict) async throws -> PixivUserPreviewResponse {
        let response = try await api.followingUsers(userID: "\(user.id)", restrict: restrict.rawValue)
        return filteredUserPreviewResponse(response)
    }

    func followerUsers(for user: PixivUser, restrict: BookmarkRestrict) async throws -> PixivUserPreviewResponse {
        let response = try await api.followerUsers(userID: "\(user.id)", restrict: restrict.rawValue)
        return filteredUserPreviewResponse(response)
    }

    func nextUserPreviews(_ url: URL) async throws -> PixivUserPreviewResponse {
        let response = try await api.nextUserPreviews(url)
        return filteredUserPreviewResponse(response)
    }

    func comments(for artwork: PixivArtwork) async throws -> PixivCommentResponse {
        try await api.illustComments(illustID: artwork.id)
    }

    func nextComments(_ url: URL) async throws -> PixivCommentResponse {
        try await api.nextComments(url)
    }

    func postComment(_ comment: String, for artwork: PixivArtwork) async throws {
        try await api.addIllustComment(illustID: artwork.id, comment: comment)
    }

    func relatedArtworks(for artwork: PixivArtwork) async throws -> PixivFeedResponse {
        let response = try await api.relatedIllusts(illustID: artwork.id)
        return filteredFeedResponse(response)
    }

    func nextRelatedArtworks(_ url: URL) async throws -> PixivFeedResponse {
        let response = try await api.nextFeed(url)
        return filteredFeedResponse(response)
    }

    func artworkSeries(for artwork: PixivArtwork) async throws -> PixivArtworkSeriesResponse? {
        guard let series = artwork.series else { return nil }
        let response = try await api.illustSeries(seriesID: series.id)
        return filteredArtworkSeriesResponse(response)
    }

    func nextArtworkSeries(_ url: URL) async throws -> PixivArtworkSeriesResponse {
        let response = try await api.nextIllustSeries(url)
        return filteredArtworkSeriesResponse(response)
    }

    func setMangaWatchlist(seriesID: Int, isAdded: Bool) async throws {
        try await api.setMangaWatchlist(seriesID: seriesID, isAdded: isAdded)
    }

    func mangaWatchlist() async throws -> PixivMangaWatchlistResponse {
        try await api.mangaWatchlist()
    }

    func nextMangaWatchlist(_ url: URL) async throws -> PixivMangaWatchlistResponse {
        try await api.nextMangaWatchlist(url)
    }

    func openLatestArtwork(in series: PixivMangaSeriesPreview) async {
        do {
            let response = try await api.illustSeries(seriesID: series.id)
            let filtered = filteredArtworkSeriesResponse(response)
            selectedArtwork = filtered.illusts.first(where: { $0.id == series.latestContentID }) ?? filtered.illusts.first
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func recordBrowsingHistory(for artwork: PixivArtwork) async {
        guard session != nil,
              recordedBrowsingHistoryIDs.insert(artwork.id).inserted else {
            return
        }

        do {
            try await api.addBrowsingHistory(illustIDs: [artwork.id])
        } catch {
            recordedBrowsingHistoryIDs.remove(artwork.id)
        }
    }

    var searchOptions: SearchOptions {
        SearchOptions(
            matchType: searchMatchType,
            sort: searchSort,
            ageLimit: searchAgeLimit,
            dateRange: searchDateRange,
            minimumBookmarks: searchMinimumBookmarks,
            artworkType: searchArtworkType,
            ugoiraFilter: searchUgoiraFilter
        )
    }

    func resetSearchOptions() {
        setSearchMatchType(.partialTags)
        setSearchSort(.dateDescending)
        setSearchAgeLimit(.unlimited)
        setSearchDateRange(.anytime)
        setSearchMinimumBookmarks(.none)
        setSearchArtworkType(.all)
        setSearchUgoiraFilter(.all)
    }

    var mutedTagList: [String] {
        mutedTags.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    var mutedUserList: [MutedUserEntry] {
        mutedUsers
            .map { MutedUserEntry(id: $0.key, name: $0.value) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    var mutedArtworkList: [MutedArtworkEntry] {
        mutedArtworks
            .map { MutedArtworkEntry(id: $0.key, title: $0.value) }
            .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    func muteArtwork(_ artwork: PixivArtwork) {
        mutedArtworks[artwork.id] = artwork.title
        persistMutedArtworks()
        applyContentFilters()
    }

    func unmuteArtwork(id: Int) {
        mutedArtworks[id] = nil
        persistMutedArtworks()
        applyContentFilters()
    }

    func muteUser(_ user: PixivUser) {
        mutedUsers[user.id] = user.name
        persistMutedUsers()
        applyContentFilters()
    }

    func unmuteUser(id: Int) {
        mutedUsers[id] = nil
        persistMutedUsers()
        applyContentFilters()
    }

    func muteTag(_ tag: PixivTag) {
        mutedTags.insert(tag.name)
        persistMutedTags()
        applyContentFilters()
    }

    func unmuteTag(_ tag: String) {
        mutedTags.remove(tag)
        persistMutedTags()
        applyContentFilters()
    }

    func clearMutedContent() {
        mutedTags.removeAll()
        mutedUsers.removeAll()
        mutedArtworks.removeAll()
        persistMutedTags()
        persistMutedUsers()
        persistMutedArtworks()
        applyContentFilters()
    }

    func importAccountMutedContent() async throws {
        let accountMuteList = try await api.muteList()
        for tag in accountMuteList.mutedTags {
            mutedTags.insert(tag.tag)
        }
        for user in accountMuteList.mutedUsers {
            mutedUsers[user.id] = user.name
        }
        persistMutedTags()
        persistMutedUsers()
        applyContentFilters()
    }

    func uploadLocalMutedContentToAccount() async throws {
        try await api.editMute(
            addTags: mutedTagList,
            addUserIDs: mutedUserList.map(\.id),
            deleteTags: [],
            deleteUserIDs: []
        )
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
        case .rankingDailyR18:
            return try await api.ranking(mode: "day_r18", date: rankingDateParameter)
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
        case .mangaWatchlist, .downloads, .savedSearches:
            return PixivFeedResponse(illusts: [], nextURL: nil)
        case .followingCreators, .recommendedUsers, .searchUsers:
            return PixivFeedResponse(illusts: [], nextURL: nil)
        }
    }

    private func updateArtwork(_ id: Int, mutate: (inout PixivArtwork) -> Void) {
        if let index = allArtworks.firstIndex(where: { $0.id == id }) {
            mutate(&allArtworks[index])
        }
        if let index = artworks.firstIndex(where: { $0.id == id }) {
            mutate(&artworks[index])
            if selectedArtwork?.id == id {
                selectedArtwork = artworks[index]
            }
        }
    }

    func applyContentFilters() {
        let selectedID = selectedArtwork?.id
        artworks = allArtworks.filter(passesContentFilters)
        if let selectedID, let selected = artworks.first(where: { $0.id == selectedID }) {
            selectedArtwork = selected
        } else {
            selectedArtwork = artworks.first
        }
    }

    private func filteredFeedResponse(_ response: PixivFeedResponse) -> PixivFeedResponse {
        PixivFeedResponse(illusts: response.illusts.filter(passesContentFilters), nextURL: response.nextURL)
    }

    private var rankingDateParameter: String? {
        guard useRankingDate else { return nil }
        return Self.rankingDateFormatter.string(from: rankingDate)
    }

    private func filteredArtworkSeriesResponse(_ response: PixivArtworkSeriesResponse) -> PixivArtworkSeriesResponse {
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

    private func filteredUserPreviewResponse(_ response: PixivUserPreviewResponse) -> PixivUserPreviewResponse {
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

    private func passesContentFilters(_ artwork: PixivArtwork) -> Bool {
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

    private func isMutedLocally(_ artwork: PixivArtwork) -> Bool {
        if artwork.isMuted {
            return true
        }
        if mutedArtworks[artwork.id] != nil {
            return true
        }
        if mutedUsers[artwork.user.id] != nil {
            return true
        }
        return artwork.tags.contains { mutedTags.contains($0.name) }
    }

    private func persistMutedTags() {
        UserDefaults.standard.set(mutedTagList, forKey: "mutedTags")
    }

    private func persistMutedUsers() {
        UserDefaults.standard.set(Self.stringKeyedDictionary(mutedUsers), forKey: "mutedUsers")
    }

    private func persistMutedArtworks() {
        UserDefaults.standard.set(Self.stringKeyedDictionary(mutedArtworks), forKey: "mutedArtworks")
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

    private static func defaultRankingDate() -> Date {
        Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
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

    private static func stringKeyedDictionary(_ dictionary: [Int: String]) -> [String: String] {
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
