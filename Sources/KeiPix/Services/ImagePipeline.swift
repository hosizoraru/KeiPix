import AppKit
import Foundation

actor ImagePipeline {
    static let shared = ImagePipeline()

    private let session: URLSession
    private let urlCache: URLCache
    private let cache = NSCache<NSURL, NSImage>()

    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        let urlCache = URLCache(
            memoryCapacity: 64 * 1024 * 1024,
            diskCapacity: 512 * 1024 * 1024,
            directory: URL.cachesDirectory.appending(path: "KeiPixImages")
        )
        self.urlCache = urlCache
        configuration.urlCache = urlCache
        session = URLSession(configuration: configuration)
        cache.countLimit = 350
    }

    func image(for url: URL) async throws -> NSImage {
        let key = url as NSURL
        if let cached = cache.object(forKey: key) {
            return cached
        }

        let (data, response) = try await session.data(for: authenticatedRequest(for: url))
        guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode),
              let image = NSImage(data: data) else {
            throw PixivAPIError.invalidResponse
        }
        cache.setObject(image, forKey: key)
        return image
    }

    func data(for url: URL) async throws -> Data {
        let (data, response) = try await session.data(for: authenticatedRequest(for: url))
        guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
            throw PixivAPIError.invalidResponse
        }
        return data
    }

    func prefetch(_ urls: [URL]) async {
        for url in urls {
            let key = url as NSURL
            guard cache.object(forKey: key) == nil else { continue }
            _ = try? await image(for: url)
        }
    }

    func cacheStatus() -> ImageCacheStatus {
        ImageCacheStatus(
            memoryCapacity: urlCache.memoryCapacity,
            memoryUsage: urlCache.currentMemoryUsage,
            diskCapacity: urlCache.diskCapacity,
            diskUsage: urlCache.currentDiskUsage
        )
    }

    func clearCaches() -> ImageCacheStatus {
        cache.removeAllObjects()
        urlCache.removeAllCachedResponses()
        return cacheStatus()
    }

    private func authenticatedRequest(for url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue("https://app-api.pixiv.net/", forHTTPHeaderField: "Referer")
        request.setValue("KeiPix/1.0", forHTTPHeaderField: "User-Agent")
        return request
    }
}
