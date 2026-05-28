import SwiftUI

/// Hosts a single artwork in its own reader window. Driven by an
/// artwork ID so the scene can be a value-typed
/// `WindowGroup(for: Int.self)` — every reader is its own window,
/// Stage Manager and Mission Control treat them as independent
/// surfaces, and SwiftUI restores the open set of windows on
/// relaunch automatically (the IDs round-trip through the system
/// state restoration store).
///
/// We resolve the artwork from the in-memory registry first and
/// fall back to a network fetch when the registry doesn't have an
/// entry — that's the path windows restored after relaunch hit,
/// since the registry is in-memory only. The actual reader chrome
/// lives in `StandaloneArtworkReader` so this wrapper stays focused
/// on the resolve-by-ID concern.
struct ArtworkReaderWindowView: View {
    @Bindable var store: KeiPixStore
    let artworkID: Int

    @State private var resolvedArtwork: PixivArtwork?
    @State private var isResolving = false
    @State private var resolutionFailed = false

    var body: some View {
        Group {
            if let artwork = resolvedArtwork ?? store.readerWindowArtwork(id: artworkID) {
                StandaloneArtworkReader(artwork: artwork, store: store)
                    .id(artwork.id)
            } else if isResolving {
                ProgressView()
                    .controlSize(.large)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if resolutionFailed {
                EmptyStateView(
                    title: L10n.noArtworkTitle,
                    subtitle: L10n.noArtworkSubtitle,
                    systemImage: "rectangle.inset.filled"
                )
            } else {
                Color.clear
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle(L10n.readerWindow)
        .task(id: artworkID) {
            await resolveArtworkIfNeeded()
        }
    }

    private func resolveArtworkIfNeeded() async {
        if store.readerWindowArtwork(id: artworkID) != nil {
            return
        }
        isResolving = true
        defer { isResolving = false }
        let resolved = await store.resolveReaderWindowArtwork(id: artworkID)
        resolvedArtwork = resolved
        resolutionFailed = resolved == nil
    }
}
