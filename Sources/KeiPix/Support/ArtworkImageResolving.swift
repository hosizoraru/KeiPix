import Foundation

extension PixivArtwork {
    var displayPageCount: Int {
        max(images.count, pageCount, 1)
    }

    /// Tier-aware URL resolver. Pixiv ships every illust at three
    /// download sizes (`medium` / `large` / `original`); the picker in
    /// settings lets users land on whichever matches their bandwidth /
    /// quality trade-off. The fallback ladder is **deterministic per
    /// tier** so a missing rung never silently downgrades to a smaller
    /// asset than requested.
    func imageURL(at index: Int, tier: ArtworkImageQualityTier) -> URL? {
        guard images.indices.contains(index) else {
            switch tier {
            case .medium: return images.first?.medium ?? detailURL
            case .large: return detailURL
            case .original: return originalURL
            }
        }

        let image = images[index]
        switch tier {
        case .medium:
            return image.medium ?? image.large ?? image.squareMedium ?? image.original
        case .large:
            return image.large ?? image.medium ?? image.squareMedium ?? image.original
        case .original:
            return image.original ?? image.large ?? image.medium ?? image.squareMedium
        }
    }

    /// Legacy boolean entry point preserved so older call sites keep
    /// compiling while we migrate to `tier:`. Internally promotes the
    /// flag to a tier and forwards to the canonical resolver.
    func imageURL(at index: Int, preferOriginal: Bool) -> URL? {
        imageURL(at: index, tier: .legacy(preferOriginal: preferOriginal))
    }

    func thumbnailURL(at index: Int) -> URL? {
        guard images.indices.contains(index) else { return thumbnailURL }
        let image = images[index]
        return image.squareMedium ?? image.medium ?? image.large ?? image.original
    }

    /// Tier-aware feed preview URL. Pixez's "feed preview quality" knob
    /// picks the asset shown in card thumbnails — `medium` covers the
    /// default 540 px, `large` upgrades to 600x1200, `original` reaches
    /// for the source. Falls back through the ladder so feed cards
    /// never go blank when a rung is missing.
    func feedPreviewURL(tier: ArtworkImageQualityTier) -> URL? {
        guard let first = images.first else { return thumbnailURL }
        switch tier {
        case .medium:
            return first.medium ?? first.squareMedium ?? first.large ?? first.original
        case .large:
            return first.large ?? first.medium ?? first.squareMedium ?? first.original
        case .original:
            return first.original ?? first.large ?? first.medium ?? first.squareMedium
        }
    }

    func prefetchURLs(around index: Int, tier: ArtworkImageQualityTier) -> [URL] {
        let pageCount = displayPageCount
        let candidates = [index, index + 1, index + 2, index - 1]
            .filter { (0..<pageCount).contains($0) }

        return candidates.compactMap {
            imageURL(at: $0, tier: tier)
        }
    }

    func prefetchURLs(around index: Int, preferOriginal: Bool) -> [URL] {
        prefetchURLs(around: index, tier: .legacy(preferOriginal: preferOriginal))
    }
}
