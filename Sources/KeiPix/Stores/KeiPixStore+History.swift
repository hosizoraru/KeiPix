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
        localBrowsingHistory.filter { item in
            passesLocalHistoryFilters(item) && item.matches(query)
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

    func selectLocalHistoryItem(_ item: LocalArtworkHistoryItem) async {
        if let artwork = allKnownArtwork(id: item.id) {
            selectedArtwork = artwork
            await recordBrowsingHistory(for: artwork)
            return
        }

        do {
            let artwork = try await api.illustDetail(illustID: item.id)
            selectedArtwork = artwork
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

    private func allKnownArtwork(id: Int) -> PixivArtwork? {
        if let selectedArtwork, selectedArtwork.id == id {
            return selectedArtwork
        }
        if let artwork = artworks.first(where: { $0.id == id }) {
            return artwork
        }
        return allArtworks.first { $0.id == id }
    }

    private func passesLocalHistoryFilters(_ item: LocalArtworkHistoryItem) -> Bool {
        if hideAIArtworks, item.isAI {
            return false
        }
        if hideR18GArtworks, item.isR18G {
            return false
        }
        if hideR18Artworks, item.isR18 {
            return false
        }
        return true
    }
}
