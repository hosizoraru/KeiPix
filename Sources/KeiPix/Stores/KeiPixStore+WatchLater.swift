import Foundation

@MainActor
extension KeiPixStore {
    static func loadWatchLaterQueue() -> [LocalArtworkHistoryItem] {
        guard let data = UserDefaults.standard.data(forKey: "watchLaterQueue") else { return [] }
        return (try? JSONDecoder().decode([LocalArtworkHistoryItem].self, from: data)) ?? []
    }

    func addToWatchLater(_ artwork: PixivArtwork) {
        guard watchLaterQueue.contains(where: { $0.id == artwork.id }) == false else { return }
        watchLaterQueue.insert(LocalArtworkHistoryItem(artwork: artwork), at: 0)
        persistWatchLaterQueue()
    }

    func removeFromWatchLater(_ item: LocalArtworkHistoryItem) {
        watchLaterQueue.removeAll { $0.id == item.id }
        persistWatchLaterQueue()
    }

    func isInWatchLater(_ artworkID: Int) -> Bool {
        watchLaterQueue.contains { $0.id == artworkID }
    }

    func clearWatchLater() {
        watchLaterQueue = []
        persistWatchLaterQueue()
    }

    func watchLaterItems(matching query: String) -> [LocalArtworkHistoryItem] {
        watchLaterQueue.filter { item in
            passesLocalHistoryFilters(item) && item.matches(query)
        }
    }

    func selectWatchLaterItem(_ item: LocalArtworkHistoryItem) async {
        if let artwork = allKnownArtwork(id: item.id) {
            selectedArtwork = artwork
            return
        }

        do {
            let artwork = try await api.illustDetail(illustID: item.id)
            selectedArtwork = artwork
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func persistWatchLaterQueue() {
        guard let data = try? JSONEncoder().encode(watchLaterQueue) else { return }
        UserDefaults.standard.set(data, forKey: "watchLaterQueue")
    }
}
