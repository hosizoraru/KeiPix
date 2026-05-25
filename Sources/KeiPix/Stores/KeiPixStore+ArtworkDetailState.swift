import Foundation

extension KeiPixStore {
    func artworkDetailExpansionState(for artwork: PixivArtwork) -> ArtworkDetailExpansionState {
        artworkDetailStateLibrary.expansionState(for: artwork.id)
    }

    func saveArtworkDetailExpansionState(_ state: ArtworkDetailExpansionState, for artwork: PixivArtwork) {
        artworkDetailStateLibrary.setExpansionState(state, for: artwork.id)
        persistArtworkDetailStateLibrary()
    }

    static func loadArtworkDetailStateLibrary() -> ArtworkDetailStateLibrary {
        guard let data = UserDefaults.standard.data(forKey: "artworkDetailStateLibrary") else {
            return ArtworkDetailStateLibrary()
        }
        return (try? JSONDecoder().decode(ArtworkDetailStateLibrary.self, from: data)) ?? ArtworkDetailStateLibrary()
    }

    private func persistArtworkDetailStateLibrary() {
        guard let data = try? JSONEncoder().encode(artworkDetailStateLibrary) else { return }
        UserDefaults.standard.set(data, forKey: "artworkDetailStateLibrary")
    }
}
