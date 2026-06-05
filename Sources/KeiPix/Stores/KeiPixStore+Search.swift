import Foundation

@MainActor
extension KeiPixStore {
    // MARK: - Search execution

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
        bookmarkFeedOptions = .defaultValue
        selectedSpotlightArticle = nil
        selectedRoute = .search
        await reloadCurrentFeed()
    }

    func runArtworkSearch() async {
        selectedRoute = .search
        await runSearch()
    }

    func runCreatorSearch() async {
        selectedRoute = .searchUsers
        await runSearch()
    }

    func runNovelSearch() async {
        searchSuggestions = []
        errorMessage = nil
        let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard keyword.isEmpty == false else { return }
        recordSearch(keyword)
        select(.novelSearch)
    }

    func clearSearchText() {
        searchText = ""
        searchSuggestions = []
        errorMessage = nil
        allSearchPopularPreviewArtworks = []
        searchPopularPreviewArtworks = []
        isLoadingSearchPopularPreview = false

        guard selectedRoute == .search || selectedRoute == .searchUsers else { return }
        searchSubmissionID += 1

        if selectedRoute == .search {
            activeFeedSnapshotRestoration = nil
            allArtworks = []
            artworks = []
            nextURL = nil
            selectedArtwork = nil
            isLoading = false
            clearNavigationHistory()
        }
    }

    func refreshSearchSuggestions() async {
        guard session != nil, usesLocalSampleAccount == false else {
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

    // MARK: - Search options

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
        setSearchMinimumBookmarks(.unlimited)
        setSearchMaximumBookmarks(.unlimited)
        setSearchArtworkType(.all)
        setSearchAIFilter(.all)
        setSearchUgoiraFilter(.all)
    }
}
