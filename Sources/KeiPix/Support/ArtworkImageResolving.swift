import Foundation

extension PixivArtwork {
    var displayPageCount: Int {
        max(images.count, pageCount, 1)
    }

    func imageURL(at index: Int, preferOriginal: Bool) -> URL? {
        guard images.indices.contains(index) else {
            return preferOriginal ? originalURL : detailURL
        }

        let image = images[index]
        return preferOriginal
            ? image.original ?? image.large ?? image.medium ?? image.squareMedium
            : image.large ?? image.medium ?? image.squareMedium ?? image.original
    }

    func thumbnailURL(at index: Int) -> URL? {
        guard images.indices.contains(index) else { return thumbnailURL }
        let image = images[index]
        return image.squareMedium ?? image.medium ?? image.large ?? image.original
    }

    func prefetchURLs(around index: Int, preferOriginal: Bool) -> [URL] {
        let pageCount = displayPageCount
        let candidates = [index, index + 1, index + 2, index - 1]
            .filter { (0..<pageCount).contains($0) }

        return candidates.compactMap {
            imageURL(at: $0, preferOriginal: preferOriginal)
        }
    }
}
