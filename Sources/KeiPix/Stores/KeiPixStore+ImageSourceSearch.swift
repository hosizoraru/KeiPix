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
        isImageSourceSearchImporterPresented = true
        #endif
    }

    #if os(iOS)
    func completeLocalImageSourceSearchImport(_ result: Result<[URL], Error>) {
        isImageSourceSearchImporterPresented = false

        do {
            let urls = try result.get()
            guard let url = urls.first else { return }
            let importedURL = try Self.copyImageSourceSearchFile(from: url)
            imageSourceSearchRequest = ImageSourceSearchRequest(localImageURL: importedURL)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private static func copyImageSourceSearchFile(from url: URL) throws -> URL {
        let didStartAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let folder = URL.temporaryDirectory.appending(path: "KeiPix/ImageSourceSearch", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        let fileExtension = url.pathExtension.isEmpty ? "image" : url.pathExtension
        let importedURL = folder.appending(path: "\(UUID().uuidString).\(fileExtension)", directoryHint: .notDirectory)
        if FileManager.default.fileExists(atPath: importedURL.path(percentEncoded: false)) {
            try FileManager.default.removeItem(at: importedURL)
        }
        try FileManager.default.copyItem(at: url, to: importedURL)
        return importedURL
    }
    #endif
}
