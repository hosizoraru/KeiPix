import Foundation

@MainActor
extension KeiPixStore {
    static func loadLocalBrowsingHistory() -> [LocalArtworkHistoryItem] {
        guard let data = UserDefaults.standard.data(forKey: "localBrowsingHistory") else { return [] }
        return (try? JSONDecoder().decode([LocalArtworkHistoryItem].self, from: data)) ?? []
    }

    func recordBrowsingHistory(for artwork: PixivArtwork) async {
        recordLocalBrowsingHistory(artwork)

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

    func localHistoryItems(matching query: String) -> [LocalArtworkHistoryItem] {
        presentedLocalBrowsingHistoryItems.filter { item in
            passesLocalHistoryFilters(item) && item.matches(query)
        }
    }

    var presentedLocalBrowsingHistoryItems: [LocalArtworkHistoryItem] {
        localBrowsingHistory.map { item in
            item.mergingLatestStatus(from: allKnownArtwork(id: item.id))
        }
    }

    func deleteLocalHistoryItem(_ item: LocalArtworkHistoryItem) {
        localBrowsingHistory.removeAll { $0.id == item.id }
        persistLocalBrowsingHistory()
    }

    func clearLocalBrowsingHistory() {
        localBrowsingHistory = []
        persistLocalBrowsingHistory()
    }

    func restoreLocalBrowsingHistory(_ items: [LocalArtworkHistoryItem]) {
        guard items.isEmpty == false else { return }
        let restoredIDs = Set(items.map(\.id))
        localBrowsingHistory.removeAll { restoredIDs.contains($0.id) }
        localBrowsingHistory.insert(contentsOf: items, at: 0)
        localBrowsingHistory = Array(localBrowsingHistory.prefix(1000))
        persistLocalBrowsingHistory()
    }

    func refreshLocalBrowsingHistoryStatus(for artwork: PixivArtwork) {
        guard let index = localBrowsingHistory.firstIndex(where: { $0.id == artwork.id }) else { return }
        localBrowsingHistory[index].isBookmarked = artwork.isBookmarked
        localBrowsingHistory[index].isCreatorFollowed = artwork.user.isFollowed
        persistLocalBrowsingHistory()
    }

    func updateLocalBrowsingHistoryBookmarkState(artworkID: Int, isBookmarked: Bool) {
        guard let index = localBrowsingHistory.firstIndex(where: { $0.id == artworkID }),
              localBrowsingHistory[index].isBookmarked != isBookmarked else {
            return
        }
        localBrowsingHistory[index].isBookmarked = isBookmarked
        persistLocalBrowsingHistory()
    }

    func updateLocalBrowsingHistoryFollowState(userID: Int, isFollowed: Bool) {
        var didUpdate = false
        for index in localBrowsingHistory.indices where localBrowsingHistory[index].creatorID == userID {
            localBrowsingHistory[index].isCreatorFollowed = isFollowed
            didUpdate = true
        }
        if didUpdate {
            persistLocalBrowsingHistory()
        }
    }

    /// Pulls the signed-in account's server-side browsing history and merges it
    /// into the local list, mirroring Pixiv Web's "閲覧履歴" sync behaviour.
    ///
    /// Skipped when the user is signed out or running in guest/Visual-QA mode,
    /// since those modes never push history to the server in the first place.
    func syncBrowsingHistoryFromPixiv() async {
        guard session != nil,
              accountSessionMode == .real else {
            return
        }

        do {
            let response = try await api.browsingHistoryIllusts()
            let now = Date()
            let items = response.illusts.enumerated().map { index, artwork in
                // Preserve the server's order (most-recent first) by stamping
                // each entry with a viewedAt that decreases by the index.
                LocalArtworkHistoryItem(
                    artwork: artwork,
                    viewedAt: now.addingTimeInterval(-Double(index))
                )
            }
            restoreLocalBrowsingHistory(items)
            // The server already knows about every ID we just pulled, so keep
            // them out of the addBrowsingHistory POST queue.
            recordedBrowsingHistoryIDs.formUnion(items.map(\.id))
        } catch {
            // Silent fall-back to local-only history; surfacing this would be
            // noisy on flaky networks and the next view will retry on demand.
        }
    }

    func selectLocalHistoryItem(_ item: LocalArtworkHistoryItem) async {
        if let artwork = allKnownArtwork(id: item.id) {
            navigateToArtwork(artwork)
            await recordBrowsingHistory(for: artwork)
            return
        }

        do {
            let artwork = try await api.illustDetail(illustID: item.id)
            navigateToArtwork(artwork)
            await recordBrowsingHistory(for: artwork)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func recordLocalBrowsingHistory(_ artwork: PixivArtwork) {
        localBrowsingHistory.removeAll { $0.id == artwork.id }
        localBrowsingHistory.insert(LocalArtworkHistoryItem(artwork: artwork), at: 0)
        localBrowsingHistory = Array(localBrowsingHistory.prefix(1000))
        persistLocalBrowsingHistory()
    }

    private func persistLocalBrowsingHistory() {
        guard let data = try? JSONEncoder().encode(localBrowsingHistory) else { return }
        UserDefaults.standard.set(data, forKey: "localBrowsingHistory")
    }

    func allKnownArtwork(id: Int) -> PixivArtwork? {
        if let selectedArtwork, selectedArtwork.id == id {
            return selectedArtwork
        }
        if let artwork = artworks.first(where: { $0.id == id }) {
            return artwork
        }
        return allArtworks.first { $0.id == id }
    }

    func passesLocalHistoryFilters(_ item: LocalArtworkHistoryItem) -> Bool {
        if hideAIArtworks, item.isAI {
            return false
        }
        if hideR18GArtworks, item.isR18G {
            return false
        }
        if hideR18Artworks, item.isR18 && item.isR18G == false {
            return false
        }
        return true
    }
}
