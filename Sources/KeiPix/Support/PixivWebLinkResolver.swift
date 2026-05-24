import Foundation

enum PixivWebLinkResolver {
    static func artworkID(from url: URL) -> Int? {
        guard let host = url.host(percentEncoded: false)?.lowercased(),
              host == "pixiv.net" || host == "www.pixiv.net" else {
            return nil
        }

        let components = url.pathComponents.filter { $0 != "/" }
        guard let artworkComponentIndex = components.firstIndex(of: "artworks"),
              components.indices.contains(artworkComponentIndex + 1) else {
            return nil
        }

        return Int(components[artworkComponentIndex + 1])
    }

    static func userID(from url: URL) -> Int? {
        guard let host = url.host(percentEncoded: false)?.lowercased(),
              host == "pixiv.net" || host == "www.pixiv.net" else {
            return nil
        }

        let components = url.pathComponents.filter { $0 != "/" }
        guard let userComponentIndex = components.firstIndex(of: "users"),
              components.indices.contains(userComponentIndex + 1) else {
            return nil
        }

        return Int(components[userComponentIndex + 1])
    }
}
