#if os(macOS)
import AppKit
#else
import UIKit
#endif
import Foundation
import UniformTypeIdentifiers

@MainActor
extension KeiPixStore {
    func presentImageSourceSearch(for artwork: PixivArtwork, pageIndex: Int = 0) {
        let clampedPageIndex = min(max(pageIndex, 0), artwork.displayPageCount - 1)
        let imageURL = artwork.imageURL(at: clampedPageIndex, tier: imageQualityTier(for: artwork))
        let localImageURL = downloads.downloadedImageURL(artworkID: artwork.id, pageIndex: clampedPageIndex)

        guard imageURL != nil || localImageURL != nil else {
            errorMessage = L10n.imageSourceSearchUnavailable
            return
        }

        imageSourceSearchRequest = ImageSourceSearchRequest(artwork: artwork, pageIndex: clampedPageIndex, imageURL: imageURL, localImageURL: localImageURL)
    }

    func presentLocalImageSourceSearch() {
        #if os(macOS)
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.title = L10n.searchLocalImageSource
        panel.prompt = L10n.chooseImage

        guard panel.runModal() == .OK,
              let url = panel.url else {
            return
        }

        imageSourceSearchRequest = ImageSourceSearchRequest(localImageURL: url)
        #else
        // iPadOS: image source search via Photos picker or document picker
        // TODO: Implement with PHPickerViewController or .fileImporter
        #endif
    }
}
