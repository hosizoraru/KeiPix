import CoreSpotlight
import Foundation

@MainActor
extension KeiPixStore {
    var spotlightGating: SpotlightIndexingGating {
        SpotlightIndexingGating(
            indexingEnabled: spotlightIndexingEnabled,
            hideAI: hideAIArtworks,
            hideR18: hideR18Artworks,
            hideR18G: hideR18GArtworks
        )
    }

    /// Toggle persisted to UserDefaults plus side effects:
    /// - turning indexing on triggers a full rebuild from the
    ///   download store's completed list, mirroring how Mail builds
    ///   its index after the user flips the corresponding toggle
    /// - turning it off wipes the KeiPix domain so a stale index
    ///   doesn't outlive the user's intent
    func setSpotlightIndexingEnabled(_ enabled: Bool) {
        guard spotlightIndexingEnabled != enabled else { return }
        spotlightIndexingEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "spotlightIndexingEnabled")
        if enabled {
            rebuildSpotlightIndex()
        } else {
            clearSpotlightIndex()
        }
    }

    /// Sweeps every completed download into the index. Called when
    /// the toggle flips on, when the user hits "Rebuild Spotlight
    /// Index" in Privacy settings, and when one of the hide-toggles
    /// changes — flipping `Hide AI` should drop AI items from the
    /// system index without waiting for the next download to land.
    func rebuildSpotlightIndex() {
        let gating = spotlightGating
        guard gating.indexingEnabled else { return }
        let attributes = downloads.completedItems.compactMap { item in
            DownloadSpotlightAttributes.make(item: item, gating: gating)
        }
        Task.detached {
            await SpotlightIndexer.shared.indexAttributes(attributes)
        }
    }

    /// Wipes our domain in the system Spotlight index. Cheap — one
    /// call to CoreSpotlight rather than enumerating every entry.
    func clearSpotlightIndex() {
        Task.detached {
            await SpotlightIndexer.shared.clearAll()
        }
    }

    /// Hook called by the download store when an item finishes. Adds
    /// or refreshes a single Spotlight entry. No-op when indexing is
    /// disabled or the item is gated out.
    func registerDownloadInSpotlight(_ item: ArtworkDownloadItem) {
        let gating = spotlightGating
        guard let attributes = DownloadSpotlightAttributes.make(item: item, gating: gating) else {
            return
        }
        Task.detached {
            await SpotlightIndexer.shared.indexAttributes([attributes])
        }
    }

    /// Hook called when a download is removed from the queue (delete,
    /// clear-completed, clear-invalid, etc.). Drops the matching
    /// Spotlight entry so the user doesn't click a result that no
    /// longer points to a real download.
    func unregisterDownloadsFromSpotlight(artworkIDs: [Int]) {
        guard artworkIDs.isEmpty == false else { return }
        let identifiers = artworkIDs.map(DownloadSpotlightAttributes.identifier(for:))
        Task.detached {
            await SpotlightIndexer.shared.deleteIdentifiers(identifiers)
        }
    }

    /// Decodes the artwork id round-tripped through Spotlight's
    /// `NSUserActivity` and returns it so the scene can route the
    /// click into the reader window. Returns nil for activities the
    /// app didn't post — e.g. Handoff payloads from a future feature
    /// that lands a different activity type.
    func artworkIDForSpotlightActivity(_ activity: NSUserActivity) -> Int? {
        if activity.activityType == DownloadSpotlightAttributes.activityType,
           let raw = activity.userInfo?["artworkID"],
           let id = raw as? Int {
            return id
        }
        // CoreSpotlight's default activity type carries the unique
        // identifier we registered, prefixed with "artwork.". Parse
        // that back out so a click from the system Spotlight panel
        // (which posts the default activity type, not ours) still
        // routes into the reader.
        if activity.activityType == CSSearchableItemActionType,
           let raw = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String,
           raw.hasPrefix("artwork."),
           let id = Int(raw.dropFirst("artwork.".count)) {
            return id
        }
        return nil
    }
}
