import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class KeiPixStore {
    var session: PixivSession?
    var selectedRoute: PixivRoute = .illustrations
    var artworks: [PixivArtwork] = []
    var selectedArtwork: PixivArtwork?
    var focusedUser: PixivUser?
    var searchText = ""
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
    var hideMutedContent = UserDefaults.standard.object(forKey: "hideMutedContent") as? Bool ?? true
    var hideAIArtworks = UserDefaults.standard.bool(forKey: "hideAIArtworks")
    var hideR18Artworks = UserDefaults.standard.bool(forKey: "hideR18Artworks")
    var hideR18GArtworks = UserDefaults.standard.bool(forKey: "hideR18GArtworks")
    var searchMatchType = KeiPixStore.loadEnum("searchMatchType", defaultValue: SearchMatchType.partialTags)
    var searchSort = KeiPixStore.loadEnum("searchSort", defaultValue: SearchSort.dateDescending)
    var searchAgeLimit = KeiPixStore.loadEnum("searchAgeLimit", defaultValue: SearchAgeLimit.unlimited)
    var searchDateRange = KeiPixStore.loadEnum("searchDateRange", defaultValue: SearchDateRange.anytime)
    var searchMinimumBookmarks = SearchMinimumBookmarks(
        rawValue: UserDefaults.standard.integer(forKey: "searchMinimumBookmarks")
    ) ?? .none
    var searchArtworkType = KeiPixStore.loadEnum("searchArtworkType", defaultValue: SearchArtworkType.all)
    var searchUgoiraFilter = KeiPixStore.loadEnum("searchUgoiraFilter", defaultValue: SearchUgoiraFilter.all)
    var trackpadGesturesEnabled = UserDefaults.standard.object(forKey: "trackpadGesturesEnabled") as? Bool ?? true
    var horizontalSwipeBehavior = UserDefaults.standard.string(forKey: "horizontalSwipeBehavior")
        .flatMap(TrackpadHorizontalSwipeBehavior.init(rawValue:)) ?? .pageOnly
    var hasNextPage: Bool { nextURL != nil }
    var compactArtworkCards: Bool { galleryLayoutMode.usesCompactGrid }

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
            await reloadCurrentFeed()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func logout() async {
        do {
            try await api.clearSession()
            session = nil
            allArtworks = []
            artworks = []
            selectedArtwork = nil
            nextURL = nil
            recordedBrowsingHistoryIDs.removeAll()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func select(_ route: PixivRoute) {
        focusedUser = nil
        selectedRoute = route
        Task { await reloadCurrentFeed() }
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
        selectedRoute = .search
        await reloadCurrentFeed()
    }

    func toggleBookmark(_ artwork: PixivArtwork) async {
        let nextValue = !artwork.isBookmarked
        do {
            if nextValue {
                try await api.addBookmark(illustID: artwork.id, restrict: .public, tags: [])
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

    func removeBookmark(_ artwork: PixivArtwork) async throws {
        try await api.deleteBookmark(illustID: artwork.id)
        updateArtwork(artwork.id) { $0.isBookmarked = false }
    }

    func toggleFollow(_ user: PixivUser) async {
        let nextValue = !user.isFollowed
        do {
            try await api.setFollow(userID: user.id, isFollowed: nextValue)
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

    func setUseOriginalImagesInDetail(_ value: Bool) {
        useOriginalImagesInDetail = value
        UserDefaults.standard.set(value, forKey: "useOriginalImagesInDetail")
    }

    func setShowContentBadges(_ value: Bool) {
        showContentBadges = value
        UserDefaults.standard.set(value, forKey: "showContentBadges")
    }

    func setShowAccountIdentity(_ value: Bool) {
        showAccountIdentity = value
        UserDefaults.standard.set(value, forKey: "showAccountIdentity")
    }

    func setHideMutedContent(_ value: Bool) {
        hideMutedContent = value
        UserDefaults.standard.set(value, forKey: "hideMutedContent")
        applyContentFilters()
    }

    func setHideAIArtworks(_ value: Bool) {
        hideAIArtworks = value
        UserDefaults.standard.set(value, forKey: "hideAIArtworks")
        applyContentFilters()
    }

    func setHideR18Artworks(_ value: Bool) {
        hideR18Artworks = value
        UserDefaults.standard.set(value, forKey: "hideR18Artworks")
        applyContentFilters()
    }

    func setHideR18GArtworks(_ value: Bool) {
        hideR18GArtworks = value
        UserDefaults.standard.set(value, forKey: "hideR18GArtworks")
        applyContentFilters()
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

    func setSearchMatchType(_ value: SearchMatchType) {
        searchMatchType = value
        UserDefaults.standard.set(value.rawValue, forKey: "searchMatchType")
    }

    func setSearchSort(_ value: SearchSort) {
        searchSort = value
        UserDefaults.standard.set(value.rawValue, forKey: "searchSort")
    }

    func setSearchAgeLimit(_ value: SearchAgeLimit) {
        searchAgeLimit = value
        UserDefaults.standard.set(value.rawValue, forKey: "searchAgeLimit")
    }

    func setSearchDateRange(_ value: SearchDateRange) {
        searchDateRange = value
        UserDefaults.standard.set(value.rawValue, forKey: "searchDateRange")
    }

    func setSearchMinimumBookmarks(_ value: SearchMinimumBookmarks) {
        searchMinimumBookmarks = value
        UserDefaults.standard.set(value.rawValue, forKey: "searchMinimumBookmarks")
    }

    func setSearchArtworkType(_ value: SearchArtworkType) {
        searchArtworkType = value
        UserDefaults.standard.set(value.rawValue, forKey: "searchArtworkType")
        applyContentFilters()
    }

    func setSearchUgoiraFilter(_ value: SearchUgoiraFilter) {
        searchUgoiraFilter = value
        UserDefaults.standard.set(value.rawValue, forKey: "searchUgoiraFilter")
        applyContentFilters()
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

    func setAppLanguage(_ language: AppLanguage) {
        appLanguage = language
        UserDefaults.standard.set(language.rawValue, forKey: "appLanguage")
    }

    func setCompactArtworkCards(_ value: Bool) {
        setGalleryLayoutMode(value ? .compactGrid : .autoMasonry)
    }

    func setGalleryLayoutMode(_ mode: GalleryLayoutMode) {
        galleryLayoutMode = mode
        UserDefaults.standard.set(mode.rawValue, forKey: "galleryLayoutMode")
        UserDefaults.standard.set(mode.usesCompactGrid, forKey: "compactArtworkCards")
    }

    func setTrackpadGesturesEnabled(_ value: Bool) {
        trackpadGesturesEnabled = value
        UserDefaults.standard.set(value, forKey: "trackpadGesturesEnabled")
    }

    func setHorizontalSwipeBehavior(_ behavior: TrackpadHorizontalSwipeBehavior) {
        horizontalSwipeBehavior = behavior
        UserDefaults.standard.set(behavior.rawValue, forKey: "horizontalSwipeBehavior")
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
            return try await api.ranking(mode: "day")
        case .rankingWeekly:
            return try await api.ranking(mode: "week")
        case .rankingMonthly:
            return try await api.ranking(mode: "month")
        case .mangaRankingDaily:
            return try await api.ranking(mode: "day_manga")
        case .mangaRankingWeekly:
            return try await api.ranking(mode: "week_manga")
        case .mangaRankingMonthly:
            return try await api.ranking(mode: "month_manga")
        case .publicBookmarks:
            guard let userID = session?.user.id else { throw PixivAPIError.missingSession }
            return try await api.bookmarks(restrict: "public", userID: userID)
        case .privateBookmarks:
            guard let userID = session?.user.id else { throw PixivAPIError.missingSession }
            return try await api.bookmarks(restrict: "private", userID: userID)
        case .following:
            return try await api.following()
        case .history:
            return try await api.browsingHistoryIllusts()
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

    private func applyContentFilters() {
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
}
