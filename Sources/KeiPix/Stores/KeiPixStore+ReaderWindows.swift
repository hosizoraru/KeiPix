import Foundation

/// Bounded registry of artworks the user has opened in a standalone
/// reader window, keyed by artwork ID. Backs the multi-window reader
/// scene — `WindowGroup(for: Int.self)` only hands the value (the
/// artwork ID) to the window's content, so the scene needs a
/// separate way to resolve the matching `PixivArtwork`.
///
/// The registry is intentionally bounded: a user who opens 100
/// reader windows in a session shouldn't keep all 100 detail
/// payloads resident forever. We evict on insertion past the cap,
/// dropping the lowest IDs first, mirroring how Apple Mail caches
/// the most recent N open messages without trying to keep every
/// read message live.
struct ReaderWindowArtworkRegistry: Sendable {
    /// Maximum artworks the registry holds at once. 32 covers the
    /// realistic ceiling — Stage Manager surfaces 4 windows per
    /// stack and a power user might cycle through a couple of
    /// stacks in a session — without paying for unbounded growth.
    static let cap = 32

    private(set) var entries: [Int: PixivArtwork] = [:]

    var count: Int { entries.count }

    func artwork(id: Int) -> PixivArtwork? {
        entries[id]
    }

    /// Inserts or refreshes an artwork in the registry and trims
    /// down to `cap` if needed. Returns the artwork's id so call
    /// sites can chain into `openWindow(id:value:)` without an
    /// extra local.
    @discardableResult
    mutating func register(_ artwork: PixivArtwork) -> Int {
        entries[artwork.id] = artwork
        evictIfNeeded()
        return artwork.id
    }

    private mutating func evictIfNeeded() {
        guard entries.count > Self.cap else { return }
        // Drop the oldest entries by ID order. We don't track
        // last-access timestamps because the registry is small
        // enough that occasional re-fetch on overflow is cheaper
        // than the bookkeeping. The user-visible behavior — open
        // 33 windows, the very first one's metadata refreshes from
        // the API on next focus — is exactly what Mail does.
        let overflow = entries.count - Self.cap
        let evictableKeys = entries.keys.sorted().prefix(overflow)
        for key in evictableKeys {
            entries[key] = nil
        }
    }
}

@MainActor
extension KeiPixStore {
    /// Stashes an artwork in the registry so a freshly opened
    /// reader window can resolve it from its `Int` value. Returns
    /// the same artwork ID so call sites can chain into
    /// `openWindow(id:value:)` without an extra local.
    @discardableResult
    func registerReaderWindowArtwork(_ artwork: PixivArtwork) -> Int {
        readerWindowRegistry.register(artwork)
        // Mirror into the legacy single-window slot so existing
        // capture-protection bindings keep reading the most recently
        // opened reader's flags. The slot also feeds the focused
        // artwork for menu commands that don't take an explicit ID.
        readerWindowArtwork = artwork
        return artwork.id
    }

    /// Looks up an artwork by ID from the registry. Returns nil
    /// when the window was restored after a relaunch (the registry
    /// is in-memory only) and the caller should fall through to a
    /// network fetch.
    func readerWindowArtwork(id: Int) -> PixivArtwork? {
        readerWindowRegistry.artwork(id: id)
    }

    /// Network-backed resolver. Used by the reader window scene on
    /// first appearance so a window restored after a relaunch can
    /// rehydrate its artwork from the API. Caches the result in
    /// the registry on success so subsequent menu commands and
    /// capture-protection reads don't re-fetch.
    func resolveReaderWindowArtwork(id: Int) async -> PixivArtwork? {
        if let cached = readerWindowRegistry.artwork(id: id) {
            return cached
        }
        do {
            let artwork = try await api.illustDetail(illustID: id)
            registerReaderWindowArtwork(artwork)
            return artwork
        } catch {
            let message = error.localizedDescription
            KeiPixLog.network.error(
                "Reader window failed to resolve artwork id=\(id, privacy: .public): \(message, privacy: .public)"
            )
            return nil
        }
    }
}
