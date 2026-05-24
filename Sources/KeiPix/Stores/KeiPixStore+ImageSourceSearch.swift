import Foundation

@MainActor
extension KeiPixStore {
    func presentImageSourceSearch(for artwork: PixivArtwork, pageIndex: Int = 0) {
        let clampedPageIndex = min(max(pageIndex, 0), artwork.displayPageCount - 1)
        let imageURL = artwork.imageURL(at: clampedPageIndex, preferOriginal: useOriginalImagesInDetail)
        let localImageURL = downloads.downloadedImageURL(artworkID: artwork.id, pageIndex: clampedPageIndex)

        guard imageURL != nil || localImageURL != nil else {
            errorMessage = L10n.imageSourceSearchUnavailable
            return
        }

        imageSourceSearchRequest = ImageSourceSearchRequest(
            artwork: artwork,
            pageIndex: clampedPageIndex,
            imageURL: imageURL,
            localImageURL: localImageURL
        )
    }
}
