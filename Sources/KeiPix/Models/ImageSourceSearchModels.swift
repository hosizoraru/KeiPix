import Foundation

struct ImageSourceSearchRequest: Identifiable, Equatable {
    let id = UUID()
    let artwork: PixivArtwork
    let pageIndex: Int
    let imageURL: URL?
    let localImageURL: URL?

    var pageNumber: Int {
        pageIndex + 1
    }
}

struct SauceNAOSearchResult: Identifiable, Hashable {
    let artworkID: Int

    var id: Int {
        artworkID
    }
}
