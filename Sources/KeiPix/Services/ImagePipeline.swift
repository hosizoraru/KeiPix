import AppKit
import Foundation

actor ImagePipeline {
    static let shared = ImagePipeline()

    private let session: URLSession
    private let cache = NSCache<NSURL, NSImage>()

    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        configuration.urlCache = URLCache(
            memoryCapacity: 64 * 1024 * 1024,
            diskCapacity: 512 * 1024 * 1024,
            directory: URL.cachesDirectory.appending(path: "KeiPixImages")
        )
        session = URLSession(configuration: configuration)
        cache.countLimit = 350
    }

    func image(for url: URL) async throws -> NSImage {
        let key = url as NSURL
        if let cached = cache.object(forKey: key) {
            return cached
        }

        var request = URLRequest(url: url)
        request.setValue("https://app-api.pixiv.net/", forHTTPHeaderField: "Referer")
        request.setValue("KeiPix/1.0", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode),
              let image = NSImage(data: data) else {
            throw PixivAPIError.invalidResponse
        }
        cache.setObject(image, forKey: key)
        return image
    }

    func prefetch(_ urls: [URL]) async {
        for url in urls {
            let key = url as NSURL
            guard cache.object(forKey: key) == nil else { continue }
            _ = try? await image(for: url)
        }
    }
}
