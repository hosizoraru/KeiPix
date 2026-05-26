import Foundation

extension KeiPixStore {
    /// Resolved expansion state for an artwork. The user's
    /// cross-artwork preference (`artworkDetailDefaultExpansion`)
    /// seeds artworks the user hasn't visited yet; once they flip a
    /// section the per-artwork override in
    /// `artworkDetailStateLibrary` wins.
    func artworkDetailExpansionState(for artwork: PixivArtwork) -> ArtworkDetailExpansionState {
        artworkDetailStateLibrary.expansionState(
            for: artwork.id,
            default: artworkDetailDefaultExpansion
        )
    }

    /// Records a section flip. We persist *both* the per-artwork
    /// override (so coming back to the same artwork looks the same)
    /// *and* the cross-artwork default (so the next first-time visit
    /// inherits the user's preference). Apple Mail / Notes use the
    /// same dual-write pattern for the sidebar's collapse memory.
    func saveArtworkDetailExpansionState(_ state: ArtworkDetailExpansionState, for artwork: PixivArtwork) {
        artworkDetailStateLibrary.setExpansionState(state, for: artwork.id)
        persistArtworkDetailStateLibrary()
        artworkDetailDefaultExpansion = state
        persistArtworkDetailDefaultExpansion()
    }

    static func loadArtworkDetailStateLibrary() -> ArtworkDetailStateLibrary {
        guard let data = UserDefaults.standard.data(forKey: "artworkDetailStateLibrary") else {
            return ArtworkDetailStateLibrary()
        }
        return (try? JSONDecoder().decode(ArtworkDetailStateLibrary.self, from: data)) ?? ArtworkDetailStateLibrary()
    }

    static func loadArtworkDetailDefaultExpansion() -> ArtworkDetailExpansionState {
        guard let data = UserDefaults.standard.data(forKey: "artworkDetailDefaultExpansion") else {
            return .designDefault
        }
        return (try? JSONDecoder().decode(ArtworkDetailExpansionState.self, from: data)) ?? .designDefault
    }

    private func persistArtworkDetailStateLibrary() {
        guard let data = try? JSONEncoder().encode(artworkDetailStateLibrary) else { return }
        UserDefaults.standard.set(data, forKey: "artworkDetailStateLibrary")
    }

    private func persistArtworkDetailDefaultExpansion() {
        guard let data = try? JSONEncoder().encode(artworkDetailDefaultExpansion) else { return }
        UserDefaults.standard.set(data, forKey: "artworkDetailDefaultExpansion")
    }
}

