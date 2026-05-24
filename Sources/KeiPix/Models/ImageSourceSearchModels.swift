import Foundation

struct ImageSourceSearchRequest: Identifiable, Equatable {
    let id = UUID()
    let artwork: PixivArtwork?
    let pageIndex: Int
    let title: String
    let detail: String
    let thumbnailURL: URL?
    let imageURL: URL?
    let localImageURL: URL?

    init(artwork: PixivArtwork, pageIndex: Int, imageURL: URL?, localImageURL: URL?) {
        self.artwork = artwork
        self.pageIndex = pageIndex
        title = artwork.title
        detail = String(format: L10n.searchingImageSourcePageFormat, pageIndex + 1)
        thumbnailURL = artwork.thumbnailURL(at: pageIndex)
        self.imageURL = imageURL
        self.localImageURL = localImageURL
    }

    init(localImageURL: URL) {
        artwork = nil
        pageIndex = 0
        title = localImageURL.deletingPathExtension().lastPathComponent
        detail = L10n.searchingLocalImageSource
        thumbnailURL = nil
        imageURL = nil
        self.localImageURL = localImageURL
    }

    var pageNumber: Int {
        pageIndex + 1
    }

    var filename: String {
        if let artwork {
            "\(artwork.id)_p\(pageIndex).jpg"
        } else {
            localImageURL?.lastPathComponent ?? "keipix-image-search.jpg"
        }
    }
}

struct SauceNAOSearchResult: Identifiable, Hashable {
    let artworkID: Int

    var id: Int {
        artworkID
    }
}
