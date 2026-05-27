import AppKit
import CoreGraphics
import Foundation
import ImageIO
import os

/// Concurrency-friendly image loader with URLCache-backed disk caching,
/// in-memory `NSCache` rasterized-bitmap caching, in-flight request
/// de-duplication, off-main-thread CGImageSource decoding, and a
/// configurable `URLSession` tuned for Pixiv's CDN.
///
/// **Why not an actor.**
/// The previous implementation was a single global actor. Every call
/// — including reads of an already-cached image — serialized through
/// the actor's mailbox, which made a 30-cell scrolling viewport
/// dispatch its image lookups one at a time even though `NSCache` and
/// `URLSession` are already thread-safe and re-entrant. We drop the
/// actor and lock only the one mutable thing: the in-flight Task map.
///
/// **Why we force-decode on a background queue.**
/// `NSImage(data:)` defers actual bitmap decoding until the image is
/// drawn for the first time, and that draw lands on the main thread
/// — every cell's first paint stalls the run loop for the duration
/// of the JPEG decode. We use `CGImageSource` with
/// `kCGImageSourceShouldCacheImmediately = true` to rasterize the
/// pixels once, on a background queue, before the `NSImage` ever
/// reaches SwiftUI. The same trick is what Apple recommends in WWDC
/// 2018 "Image and Graphics Best Practices" and what Nuke and SDWebImage
/// land on too.
final class ImagePipeline: @unchecked Sendable {
    static let shared = ImagePipeline()

    /// Priority hint for a fetch. `userInitiated` is for cells the
    /// user is actively scrolling toward (`RemoteImageView` task);
    /// `utility` is for opportunistic prefetch around the focused
    /// page so the next swipe is instant. The hint feeds both
    /// `Task.priority` (cooperative-thread scheduler) and the iOS-
    /// equivalent dispatch QoS used during decode.
    enum Priority: Sendable {
        case userInitiated
        case utility

        fileprivate var taskPriority: TaskPriority {
            switch self {
            case .userInitiated: return .userInitiated
            case .utility: return .utility
            }
        }

        fileprivate var dispatchQoS: DispatchQoS.QoSClass {
            switch self {
            case .userInitiated: return .userInitiated
            case .utility: return .utility
            }
        }
    }

    // MARK: - Storage

    private let session: URLSession
    private let urlCache: URLCache
    private let memoryCache = NSCache<NSURL, NSImage>()

    /// Decode queue separate from the URLSession delegate queue so
    /// CPU-heavy bitmap decoding doesn't starve the network's
    /// completion handlers.
    private let decodeQueue = DispatchQueue(
        label: "com.keipix.image-decode",
        qos: .userInitiated,
        attributes: .concurrent,
        autoreleaseFrequency: .workItem
    )

    /// In-flight fetch map. Multiple concurrent callers asking for
    /// the same URL share a single network + decode task. Guarded by
    /// `inFlightLock` because we mutate it from arbitrary callers.
    private var inFlight: [URL: Task<NSImage, Error>] = [:]
    private let inFlightLock = OSAllocatedUnfairLock()

    private init() {
        // 256 MB of decoded bitmaps in memory is enough to keep the
        // current viewport plus a couple of screens of prefetch hot
        // without bloating the resident set. We cost-bound by pixel
        // area (4 bytes per RGBA pixel) instead of count-bound so a
        // wall of 5 MB master1200 illustrations and a wall of 20 KB
        // square thumbnails both behave reasonably.
        memoryCache.totalCostLimit = 256 * 1024 * 1024
        // Keep `countLimit` generous; cost limit is the real ceiling.
        memoryCache.countLimit = 1024

        let configuration = URLSessionConfiguration.default
        // 8 sockets per host fits Pixiv's CDN behaviour (HTTP/2
        // multiplexes anyway, but the limit also bounds HTTP/1.1
        // fallback). The default is 6.
        configuration.httpMaximumConnectionsPerHost = 8
        // Disk-backed HTTPCache lets repeat launches start with warm
        // thumbnails and skips re-downloading paginated feeds.
        let urlCache = URLCache(
            memoryCapacity: 64 * 1024 * 1024,
            diskCapacity: 512 * 1024 * 1024,
            directory: URL.cachesDirectory.appending(path: "KeiPixImages")
        )
        self.urlCache = urlCache
        configuration.urlCache = urlCache
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        // When wifi flaps mid-prefetch, queue the request instead of
        // surfacing an error. Visible-cell fetches still have a 30 s
        // ceiling so a permanent outage doesn't leave a spinner up.
        configuration.waitsForConnectivity = true
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        // Pixiv's i.pximg.net CDN demands a `Referer` from the app
        // domain. Hoist it onto the session config so it's set on
        // every redirect chain too, not just the first request.
        configuration.httpAdditionalHeaders = [
            "Referer": "https://app-api.pixiv.net/",
            "User-Agent": "KeiPix/1.0"
        ]
        // Honor the user's app-level proxy preference at session init.
        // `nil` means "follow macOS network settings" — that's how
        // ProxyConfiguration.system stays in sync with the system pane
        // without us re-reading SystemConfiguration. Manual / direct
        // overrides require an app restart to take effect, mirroring
        // how Pixez ships the same setting.
        if let proxy = ProxyConfiguration.loadFromUserDefaults().connectionProxyDictionary {
            configuration.connectionProxyDictionary = proxy
        }

        session = URLSession(configuration: configuration)
    }

    // MARK: - Public API

    /// Fetches a decoded `NSImage` for the URL, hitting the in-memory
    /// cache when possible and de-duplicating concurrent requests for
    /// the same URL.
    func image(for url: URL, priority: Priority = .userInitiated) async throws -> NSImage {
        let key = url as NSURL
        if let cached = memoryCache.object(forKey: key) {
            return cached
        }

        // De-dup: if another caller is already fetching this URL we
        // await their Task instead of kicking off a parallel one.
        // Mutating the map needs the unfair lock; awaiting the Task
        // happens outside the critical section.
        let task: Task<NSImage, Error> = inFlightLock.withLock {
            if let existing = inFlight[url] {
                return existing
            }
            let new = Task<NSImage, Error>(priority: priority.taskPriority) { [weak self] in
                guard let self else { throw CancellationError() }
                defer { self.removeInFlight(url) }
                return try await self.fetchAndDecode(url: url, priority: priority)
            }
            inFlight[url] = new
            return new
        }
        return try await task.value
    }

    /// Raw bytes for the URL. Used by the download queue and the
    /// reverse-image-search sheet — both consumers want the file
    /// payload, not a decoded bitmap.
    func data(for url: URL) async throws -> Data {
        let (data, response) = try await session.data(for: authenticatedRequest(for: url))
        try validate(response: response)
        return data
    }

    /// Fire-and-forget concurrent prefetch. Downloads the URLs we
    /// don't already have hot, capped at `concurrency` in-flight at
    /// once so we don't crowd visible-cell loads off the wire.
    /// Caller doesn't need to await; this returns once every prefetch
    /// has finished or failed silently.
    func prefetch(_ urls: [URL], concurrency: Int = 4) async {
        // Filter the obvious cache hits up front so the TaskGroup
        // doesn't waste a slot on a no-op.
        let cold = urls.filter { memoryCache.object(forKey: $0 as NSURL) == nil }
        guard cold.isEmpty == false else { return }

        await withTaskGroup(of: Void.self) { group in
            var iterator = cold.makeIterator()
            // Seed the group up to the concurrency cap, then refill
            // one slot every time a child completes. This is the
            // structured-concurrency equivalent of a semaphore.
            for _ in 0..<min(concurrency, cold.count) {
                guard let url = iterator.next() else { break }
                group.addTask(priority: Priority.utility.taskPriority) { [weak self] in
                    _ = try? await self?.image(for: url, priority: .utility)
                }
            }
            for await _ in group {
                guard let url = iterator.next() else { continue }
                group.addTask(priority: Priority.utility.taskPriority) { [weak self] in
                    _ = try? await self?.image(for: url, priority: .utility)
                }
            }
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
        memoryCache.removeAllObjects()
        urlCache.removeAllCachedResponses()
        return cacheStatus()
    }

    // MARK: - Private

    private func fetchAndDecode(url: URL, priority: Priority) async throws -> NSImage {
        let (data, response) = try await session.data(for: authenticatedRequest(for: url))
        try validate(response: response)
        let image = try await decode(data: data, qos: priority.dispatchQoS)
        let cost = approximateCost(of: image, fallback: data.count)
        memoryCache.setObject(image, forKey: url as NSURL, cost: cost)
        return image
    }

    /// Decodes JPEG/PNG bytes on a background queue using
    /// `CGImageSource` with `kCGImageSourceShouldCacheImmediately`
    /// set so the bitmap is fully rasterized before SwiftUI ever
    /// touches it. Without this, the first time a cell draws on the
    /// main thread it pays the JPEG decode cost (~10-30 ms per
    /// master1200 frame) — which lands as a scroll stutter.
    private func decode(data: Data, qos: DispatchQoS.QoSClass) async throws -> NSImage {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<NSImage, Error>) in
            decodeQueue.async(qos: DispatchQoS(qosClass: qos, relativePriority: 0)) {
                let options: [CFString: Any] = [
                    kCGImageSourceShouldCache: true,
                    kCGImageSourceShouldCacheImmediately: true
                ]
                guard let source = CGImageSourceCreateWithData(data as CFData, options as CFDictionary) else {
                    // Fall back to NSImage(data:) so we still serve
                    // formats CGImageSource doesn't recognise (rare
                    // legacy GIF / webp variants).
                    if let image = NSImage(data: data) {
                        continuation.resume(returning: image)
                    } else {
                        continuation.resume(throwing: PixivAPIError.invalidResponse)
                    }
                    return
                }

                guard let cgImage = CGImageSourceCreateImageAtIndex(source, 0, options as CFDictionary) else {
                    if let image = NSImage(data: data) {
                        continuation.resume(returning: image)
                    } else {
                        continuation.resume(throwing: PixivAPIError.invalidResponse)
                    }
                    return
                }

                // Use the CGImage's pixel dimensions for the NSImage
                // size so callers receive a 1× representation that
                // SwiftUI can lay out without a second decode pass.
                let pixelSize = NSSize(width: cgImage.width, height: cgImage.height)
                let image = NSImage(cgImage: cgImage, size: pixelSize)
                continuation.resume(returning: image)
            }
        }
    }

    /// Approximate cost in bytes for `NSCache.totalCostLimit`. We
    /// use 4 bytes per pixel (RGBA8) which slightly overestimates
    /// for opaque JPEGs but keeps the math cheap and safe; falls
    /// back to the raw payload size if pixel dimensions aren't
    /// reachable.
    private func approximateCost(of image: NSImage, fallback: Int) -> Int {
        let size = image.size
        guard size.width > 0, size.height > 0 else { return fallback }
        return Int(size.width * size.height) * 4
    }

    private func validate(response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw PixivAPIError.invalidResponse
        }
    }

    private func authenticatedRequest(for url: URL) -> URLRequest {
        // Headers also live on the session config; the per-request
        // copy here is for the rare path where a caller hands us a
        // URL that hits a different host than `app-api.pixiv.net`
        // and needs the Referer to follow.
        var request = URLRequest(url: url)
        request.setValue("https://app-api.pixiv.net/", forHTTPHeaderField: "Referer")
        request.setValue("KeiPix/1.0", forHTTPHeaderField: "User-Agent")
        return request
    }

    private func removeInFlight(_ url: URL) {
        inFlightLock.withLock { _ = inFlight.removeValue(forKey: url) }
    }
}
