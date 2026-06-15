import Foundation

@MainActor
extension KeiPixStore {
    // MARK: - Search execution

    func runSearch() async {
        Task { await refreshRemoteSearchOptionsIfNeeded() }
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
        if selectedRoute == .novelSearch {
            await runNovelSearch()
            return
        }
        feedNarrowingContext = nil
        if selectedRoute == .searchUsers {
            searchSubmissionID += 1
            restoreClientFilterQueryForCurrentScope()
            allSearchPopularPreviewArtworks = []
            searchPopularPreviewArtworks = []
            isLoadingSearchPopularPreview = false
            return
        }
        activateSearchOptionsProfile(.artworkProfile(for: searchArtworkType))
        focusedUser = nil
        bookmarkTagFilter = nil
        bookmarkFeedOptions = .defaultValue
        selectedSpotlightArticle = nil
        selectedRoute = .search
        await reloadCurrentFeed()
    }

    func runArtworkSearch() async {
        activateSearchOptionsProfile(.artworkProfile(for: searchArtworkType))
        selectedRoute = .search
        await runSearch()
    }

    func runCreatorSearch() async {
        selectedRoute = .searchUsers
        await runSearch()
    }

    func runNovelSearch() async {
        Task { await refreshRemoteSearchOptionsIfNeeded() }
        searchSuggestions = []
        errorMessage = nil
        activateSearchOptionsProfile(.novel)
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
        restoreClientFilterQueryForCurrentScope()

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

    func refreshRemoteSearchOptionsIfNeeded(force: Bool = false) async {
        guard session != nil, usesLocalSampleAccount == false else {
            remoteSearchOptions = nil
            remoteSearchOptionsLoadedAt = nil
            remoteSearchOptionsErrorMessage = nil
            isLoadingRemoteSearchOptions = false
            return
        }
        guard isLoadingRemoteSearchOptions == false else { return }
        if force == false, remoteSearchOptions != nil { return }

        isLoadingRemoteSearchOptions = true
        remoteSearchOptionsErrorMessage = nil
        defer { isLoadingRemoteSearchOptions = false }

        do {
            remoteSearchOptions = try await api.remoteSearchOptions()
            remoteSearchOptionsLoadedAt = Date()
        } catch {
            remoteSearchOptionsErrorMessage = error.localizedDescription
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
            ugoiraFilter: searchUgoiraFilter,
            novelLanguageCode: searchNovelLanguageCode,
            novelGenreID: searchNovelGenreID,
            novelTextLength: searchNovelTextLength
        )
    }

    var effectiveSearchSort: SearchSort {
        if searchSort.requiresPixivPremium, session?.user.isPremium != true {
            return .popularPreview
        }
        return searchSort
    }

    func resetSearchOptions() {
        applySearchOptions(.defaultValue.normalized(for: activeSearchOptionsProfile), remember: true)
        applyContentFilters()
    }

    func applySearchOptionsPreset(_ options: SearchOptions) {
        let profile = options.preferredProfileKind
        if profile != activeSearchOptionsProfile {
            activateSearchOptionsProfile(profile)
        }
        applySearchOptions(options.normalized(for: profile), remember: true)
        applyContentFilters()
    }

    func activateSearchOptionsProfile(_ profile: SearchOptionsProfileKind) {
        guard profile != activeSearchOptionsProfile else {
            applySearchOptions(searchOptions.normalized(for: profile), remember: true)
            applyContentFilters()
            return
        }

        rememberCurrentSearchOptionsProfile()
        activeSearchOptionsProfile = profile
        UserDefaults.standard.set(profile.rawValue, forKey: SearchOptionsProfileKind.activeDefaultsKey)
        let restoredOptions = (searchOptionsProfiles[profile] ?? SearchOptions.defaultValue).normalized(for: profile)
        applySearchOptions(restoredOptions, remember: false)
        searchOptionsProfiles[profile] = restoredOptions
        persistSearchOptionsProfiles()
        applyContentFilters()
    }

    func restoreInitialSearchOptionsProfile() {
        if let storedOptions = searchOptionsProfiles[activeSearchOptionsProfile] {
            applySearchOptions(storedOptions.normalized(for: activeSearchOptionsProfile), remember: false)
        } else {
            rememberCurrentSearchOptionsProfile()
        }
    }

    func rememberCurrentSearchOptionsProfile() {
        guard isApplyingSearchOptionsProfile == false else { return }
        searchOptionsProfiles[activeSearchOptionsProfile] = searchOptions.normalized(for: activeSearchOptionsProfile)
        persistSearchOptionsProfiles()
    }

    private func applySearchOptions(_ options: SearchOptions, remember: Bool) {
        isApplyingSearchOptionsProfile = true
        defer {
            isApplyingSearchOptionsProfile = false
            if remember {
                rememberCurrentSearchOptionsProfile()
            }
        }

        let normalized = options.normalized(for: activeSearchOptionsProfile)
        searchMatchType = normalized.matchType
        searchSort = normalized.sort
        searchAgeLimit = normalized.ageLimit
        searchDateRange = normalized.dateRange
        searchMinimumBookmarks = normalized.minimumBookmarks
        searchMaximumBookmarks = normalized.maximumBookmarks
        searchArtworkType = normalized.artworkType
        searchAIFilter = normalized.aiFilter
        searchUgoiraFilter = normalized.ugoiraFilter
        searchNovelLanguageCode = normalized.novelLanguageCode
        searchNovelGenreID = normalized.novelGenreID
        searchNovelTextLength = normalized.novelTextLength
        persistCurrentSearchOptions()
    }

    private func persistCurrentSearchOptions() {
        let defaults = UserDefaults.standard
        defaults.set(searchMatchType.rawValue, forKey: "searchMatchType")
        defaults.set(searchSort.rawValue, forKey: "searchSort")
        defaults.set(searchAgeLimit.rawValue, forKey: "searchAgeLimit")
        defaults.set(searchDateRange.rawValue, forKey: "searchDateRange")
        defaults.set(searchMinimumBookmarks.value, forKey: "searchMinimumBookmarks")
        defaults.set(searchMaximumBookmarks.value, forKey: "searchMaximumBookmarks")
        defaults.set(searchArtworkType.rawValue, forKey: "searchArtworkType")
        defaults.set(searchAIFilter.rawValue, forKey: "searchAIFilter")
        defaults.set(searchUgoiraFilter.rawValue, forKey: "searchUgoiraFilter")
        if let searchNovelLanguageCode {
            defaults.set(searchNovelLanguageCode, forKey: "searchNovelLanguageCode")
        } else {
            defaults.removeObject(forKey: "searchNovelLanguageCode")
        }
        if let searchNovelGenreID {
            defaults.set(searchNovelGenreID, forKey: "searchNovelGenreID")
        } else {
            defaults.removeObject(forKey: "searchNovelGenreID")
        }
        defaults.set(searchNovelTextLength.rawValue, forKey: "searchNovelTextLength")
    }

    private func persistSearchOptionsProfiles() {
        guard let data = try? JSONEncoder().encode(searchOptionsProfiles) else { return }
        UserDefaults.standard.set(data, forKey: SearchOptionsProfileKind.defaultsKey)
    }

    static func loadSearchOptionsProfiles(_ defaults: UserDefaults = .standard) -> [SearchOptionsProfileKind: SearchOptions] {
        guard let data = defaults.data(forKey: SearchOptionsProfileKind.defaultsKey),
              let profiles = try? JSONDecoder().decode([SearchOptionsProfileKind: SearchOptions].self, from: data) else {
            return [:]
        }
        return profiles.reduce(into: [:]) { partialResult, item in
            partialResult[item.key] = item.value.normalized(for: item.key)
        }
    }
}
