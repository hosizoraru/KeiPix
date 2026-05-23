import Foundation

struct PixivSearchAutocompleteResponse: Decodable, Sendable {
    let tags: [PixivTag]
}

