import Foundation

enum GalleryImagePrefetchPolicy: Sendable {
    static let callbackURLLimit = 12
    static let pendingURLLimit = 36
    static let batchURLLimit = 18
    static let delayMilliseconds = 120
    static let concurrency = 2

    static func previewURLs(
        for artworks: [PixivArtwork],
        tier: ArtworkImageQualityTier,
        limit: Int = callbackURLLimit
    ) -> [URL] {
        guard limit > 0 else { return [] }

        var seen = Set<URL>()
        var urls: [URL] = []
        urls.reserveCapacity(min(artworks.count, limit))

        for artwork in artworks {
            guard urls.count < limit else { break }
            guard let url = artwork.feedPreviewURL(tier: tier) ?? artwork.thumbnailURL else {
                continue
            }
            guard seen.insert(url).inserted else { continue }
            urls.append(url)
        }

        return urls
    }
}
