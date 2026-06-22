import Foundation

enum ArtworkFeedDeduplication {
    static func unique(_ artworks: [PixivArtwork]) -> [PixivArtwork] {
        artworks.uniqued(by: \.id)
    }

    static func appending(_ incoming: [PixivArtwork], to existing: [PixivArtwork]) -> [PixivArtwork] {
        var seen = Set(existing.map(\.id))
        var merged = existing
        merged.reserveCapacity(existing.count + incoming.count)
        for artwork in incoming where seen.insert(artwork.id).inserted {
            merged.append(artwork)
        }
        return merged
    }
}
