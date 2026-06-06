import Foundation

enum FeedNarrowingContext: Equatable, Hashable, Sendable {
    case directArtwork(id: Int)

    var artworkID: Int {
        switch self {
        case .directArtwork(let id):
            id
        }
    }

    var storageID: String {
        switch self {
        case .directArtwork(let id):
            "directArtwork:\(id)"
        }
    }
}
