import Foundation

@MainActor
extension KeiPixStore {
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

    func saveCurrentSearchPreset() {
        saveSearchPreset(searchText, options: searchOptions)
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

    func restoreSavedSearches(_ keywords: [String]) {
        guard keywords.isEmpty == false else { return }
        let restored = keywords.filter { keyword in
            savedSearches.contains { $0.localizedCaseInsensitiveCompare(keyword) == .orderedSame } == false
        }
        savedSearches.insert(contentsOf: restored, at: 0)
        savedSearches = Array(savedSearches.prefix(50))
        UserDefaults.standard.set(savedSearches, forKey: "savedSearches")
    }

    func saveSearchPreset(_ keyword: String, options: SearchOptions) {
        let normalized = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.isEmpty == false else { return }

        let now = Date()
        if let index = savedSearchPresets.firstIndex(where: {
            $0.keyword.localizedCaseInsensitiveCompare(normalized) == .orderedSame
        }) {
            savedSearchPresets[index].keyword = normalized
            savedSearchPresets[index].options = options
            savedSearchPresets[index].updatedAt = now
        } else {
            savedSearchPresets.insert(SavedSearchPreset(keyword: normalized, options: options), at: 0)
        }
        savedSearchPresets = Array(savedSearchPresets.prefix(50))
        persistSavedSearchPresets()
        saveSearch(normalized)
    }

    func removeSavedSearchPreset(_ preset: SavedSearchPreset) {
        savedSearchPresets.removeAll { $0.id == preset.id }
        persistSavedSearchPresets()
    }

    func restoreSavedSearchPresets(_ presets: [SavedSearchPreset]) {
        guard presets.isEmpty == false else { return }
        let restoredIDs = Set(presets.map(\.id))
        savedSearchPresets.removeAll { restoredIDs.contains($0.id) }
        savedSearchPresets.insert(contentsOf: presets, at: 0)
        savedSearchPresets = Array(savedSearchPresets.prefix(50))
        persistSavedSearchPresets()
    }

    func clearSearchHistory() {
        searchHistory = []
        UserDefaults.standard.set(searchHistory, forKey: "searchHistory")
    }

    func restoreSearchHistory(_ keywords: [String]) {
        guard keywords.isEmpty == false else { return }
        let restored = keywords.filter { keyword in
            searchHistory.contains { $0.localizedCaseInsensitiveCompare(keyword) == .orderedSame } == false
        }
        searchHistory.insert(contentsOf: restored, at: 0)
        searchHistory = Array(searchHistory.prefix(50))
        UserDefaults.standard.set(searchHistory, forKey: "searchHistory")
    }

    func savedSearchLibraryExport() -> SavedSearchLibraryExport {
        SavedSearchLibraryExport(
            presets: savedSearchPresets,
            savedSearches: savedSearches,
            searchHistory: searchHistory
        )
    }

    @discardableResult
    func importSavedSearchLibrary(_ library: SavedSearchLibraryExport) -> SavedSearchLibraryImportSummary {
        let presets = library.presets.filter { $0.keyword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false }
        let saved = library.savedSearches
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
        let history = library.searchHistory
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }

        restoreSavedSearchPresets(presets)
        restoreSavedSearches(saved)
        restoreSearchHistory(history)

        return SavedSearchLibraryImportSummary(
            presetCount: presets.count,
            savedSearchCount: saved.count,
            historyCount: history.count
        )
    }

    func runSavedSearch(_ keyword: String) async {
        searchText = keyword
        selectedRoute = .search
        await runSearch()
    }

    func runSavedSearchPreset(_ preset: SavedSearchPreset) async {
        searchText = preset.keyword
        applySearchOptions(preset.options)
        selectedRoute = activeSearchOptionsProfile == .novel ? .novelSearch : .search
        await runSearch()
    }

    func recordSearch(_ keyword: String) {
        let normalized = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.isEmpty == false else { return }
        searchHistory.removeAll { $0.localizedCaseInsensitiveCompare(normalized) == .orderedSame }
        searchHistory.insert(normalized, at: 0)
        searchHistory = Array(searchHistory.prefix(50))
        UserDefaults.standard.set(searchHistory, forKey: "searchHistory")
    }

    private func applySearchOptions(_ options: SearchOptions) {
        applySearchOptionsPreset(options)
    }
}
