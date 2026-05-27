import Foundation

/// Pure mapping from a completed `ArtworkDownloadItem` to the
/// CoreSpotlight searchable-attributes payload, plus the privacy
/// gating that decides whether an item is allowed into the index in
/// the first place. Kept out of `SpotlightIndexer` so the eligibility
/// + content-shape logic is exercisable without spinning up
/// CoreSpotlight in tests.
///
/// The shape mirrors what Apple's own apps surface: title, byline
/// (creator), display path-style description, and a content URL the
/// system uses to resolve a thumbnail. We deliberately do not put
/// the artwork's full caption here — Spotlight is a search index, not
/// a content cache, and Apple's HIG asks apps to keep entries lean.
struct DownloadSpotlightAttributes: Equatable, Sendable {
    /// Stable Spotlight identifier. Stays the same across re-indexes
    /// so we don't end up with duplicate hits, mirroring how Mail
    /// keys messages by their Message-ID.
    let identifier: String

    /// Domain identifier — the system uses this for bulk
    /// `deleteSearchableItems(withDomainIdentifiers:)` calls when the
    /// user disables indexing or clicks Clear in Settings.
    let domainIdentifier: String

    /// Display title shown in Spotlight results. Falls back to the
    /// Pixiv id when the title is empty (rare, but Apple's own apps
    /// don't ship empty titles).
    let title: String

    /// Byline shown beneath the title — pixiv creator name plus the
    /// human page-count summary so a user scrolling Spotlight can
    /// tell a 1-page illust from a 30-page manga at a glance.
    let contentDescription: String

    /// Searchable keywords. We explicitly drop tags here when the
    /// user hides AI/R18/R18-G content via the global settings — the
    /// item itself is filtered upstream, but this guard means a
    /// stale index from before a settings flip never leaks them.
    let keywords: [String]

    /// File URL the system uses to resolve a thumbnail. Set to the
    /// first downloaded page when present so Spotlight shows the
    /// cover image.
    let thumbnailFileURL: URL?

    /// Pixiv URL, surfaced as the contentURL so a Spotlight click
    /// can route through KeiPix's existing `onOpenURL` handler.
    let contentURL: URL?

    /// Routing payload that round-trips through the
    /// `NSUserActivity` Spotlight hands back when the user clicks a
    /// result. We open the reader window for this artwork id.
    let userActivityArtworkID: Int

    static func identifier(for artworkID: Int) -> String {
        "artwork.\(artworkID)"
    }

    /// Domain identifier shared by every artwork entry. Spotlight
    /// allows wholesale clears via this domain — much faster than
    /// enumerating every entry when the user disables indexing.
    static let domainIdentifier = "com.keipix.client.downloads"

    /// `NSUserActivity.activityType` we tag Spotlight hits with so
    /// the app's `.onContinueUserActivity` can route the click.
    static let activityType = "com.keipix.client.spotlight.openArtwork"

    /// Builds Spotlight attributes for a download or returns nil when
    /// privacy gating disqualifies it (item not completed, content
    /// flagged but the user has the matching hide-toggle on, etc.).
    /// Keeping this pure means tests pin the eligibility rules to
    /// the privacy toggles without hitting CoreSpotlight.
    static func make(
        item: ArtworkDownloadItem,
        gating: SpotlightIndexingGating
    ) -> DownloadSpotlightAttributes? {
        guard item.status == .completed else { return nil }
        guard gating.indexingEnabled else { return nil }

        if item.isAI == true, gating.hideAI { return nil }
        if item.isR18 == true, gating.hideR18 { return nil }
        if item.isR18G == true, gating.hideR18G { return nil }

        let displayTitle = item.title.isEmpty ? "Pixiv #\(item.artworkID)" : item.title
        let pageSummary = "\(item.creatorName) · \(item.pageCount)P"

        // Drop tags entirely when any hide toggle is on, even if
        // this specific item isn't flagged — a download persisted
        // before the user enabled the toggle could still carry the
        // tag literal, and Spotlight's job isn't to leak those.
        let keywords: [String]
        if gating.hideAI || gating.hideR18 || gating.hideR18G {
            keywords = [item.creatorName, "\(item.artworkID)"]
        } else {
            let baseKeywords = [item.creatorName, "\(item.artworkID)"]
            keywords = baseKeywords + (item.tags ?? [])
        }

        let thumbnailURL = firstReadableImageURL(in: item)

        return DownloadSpotlightAttributes(
            identifier: identifier(for: item.artworkID),
            domainIdentifier: domainIdentifier,
            title: displayTitle,
            contentDescription: pageSummary,
            keywords: keywords,
            thumbnailFileURL: thumbnailURL,
            contentURL: item.pixivURL,
            userActivityArtworkID: item.artworkID
        )
    }

    private static func firstReadableImageURL(in item: ArtworkDownloadItem) -> URL? {
        guard let paths = item.downloadedFilePaths, paths.isEmpty == false else { return nil }
        // Prefer image files for the thumbnail — ugoira archives
        // and JSON sidecars exist in the same folder but Spotlight
        // can't render those.
        let imageExtensions: Set<String> = ["jpg", "jpeg", "png", "gif", "webp", "heic"]
        for path in paths {
            let url = URL(fileURLWithPath: path)
            if imageExtensions.contains(url.pathExtension.lowercased()) {
                return url
            }
        }
        return URL(fileURLWithPath: paths[0])
    }
}

/// Privacy gating snapshot the mapping consults. A value type so we
/// can synthesize one in tests without instantiating `KeiPixStore`.
struct SpotlightIndexingGating: Equatable, Sendable {
    var indexingEnabled: Bool
    var hideAI: Bool
    var hideR18: Bool
    var hideR18G: Bool
}
