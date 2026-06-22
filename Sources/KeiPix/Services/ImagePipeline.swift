import CoreGraphics
import Foundation
import ImageIO
import os
import SwiftUI
#if os(iOS)
import UIKit
#endif
#if os(macOS)
import AppKit
#endif

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

    private static let decodedMemoryCacheCostLimit: Int = {
        #if os(iOS)
        return 96 * 1024 * 1024
        #else
        return 256 * 1024 * 1024
        #endif
    }()

    private static let decodedMemoryCacheCountLimit: Int = {
        #if os(iOS)
        return 384
        #else
        return 1024
        #endif
    }()

    private static let maximumDecodedCacheInsertionCost: Int = {
        #if os(iOS)
        return 48 * 1024 * 1024
        #else
        return 192 * 1024 * 1024
        #endif
    }()

    private static let recentDecodedImageCostLimit: Int = {
        #if os(iOS)
        return 48 * 1024 * 1024
        #else
        return 128 * 1024 * 1024
        #endif
    }()

    private static let recentDecodedImageCountLimit: Int = {
        #if os(iOS)
        return 64
        #else
        return 128
        #endif
    }()

    private static let maximumRecentImagePinCost: Int = {
        #if os(iOS)
        return 12 * 1024 * 1024
        #else
        return 64 * 1024 * 1024
        #endif
    }()

    private static let urlCacheMemoryCapacity: Int = {
        #if os(iOS)
        return 32 * 1024 * 1024
        #else
        return 64 * 1024 * 1024
        #endif
    }()

    private static let maximumPrefetchConcurrency: Int = {
        #if os(iOS)
        return 2
        #else
        return 4
        #endif
    }()

    private let session: URLSession
    private let urlCache: URLCache
    private let memoryCache = NSCache<NSURL, PlatformImage>()
    private let recentImageCostLimit = ImagePipeline.recentDecodedImageCostLimit
    private let recentImageCountLimit = ImagePipeline.recentDecodedImageCountLimit
    private var recentImages: [URL: PlatformImage] = [:]
    private var recentImageCosts: [URL: Int] = [:]
    private var recentImageOrder: [URL] = []
    private var recentImageTotalCost = 0
    private let recentImageLock = OSAllocatedUnfairLock()

    /// Decode queue separate from the URLSession delegate queue so
    /// CPU-heavy bitmap decoding doesn't starve the network's
    /// completion handlers.
    private let decodeQueue = DispatchQueue(
        label: "com.keipix.image-decode",
        qos: .userInitiated,
        attributes: .concurrent,
        autoreleaseFrequency: .workItem
    )

    /// Lower-priority decode lane for prefetch. Visible original loads stay on
    /// the user-initiated queue while scroll-ahead warming yields sooner under
    /// CPU pressure.
    private let utilityDecodeQueue = DispatchQueue(
        label: "com.keipix.image-decode.utility",
        qos: .utility,
        attributes: .concurrent,
        autoreleaseFrequency: .workItem
    )

    /// In-flight fetch map. Multiple concurrent callers asking for
    /// the same URL share a single network + decode task. Guarded by
    /// `inFlightLock` because we mutate it from arbitrary callers.
    private var inFlight: [URL: Task<PlatformImage, Error>] = [:]
    private let inFlightLock = OSAllocatedUnfairLock()

    #if os(iOS)
    private var memoryWarningObserver: NSObjectProtocol?
    #endif

    init() {
        // Cost-bound decoded bitmaps by platform. iOS/iPadOS need a tighter
        // ceiling because a handful of source originals can otherwise keep
        // hundreds of MB resident while the waterfall continues loading.
        memoryCache.totalCostLimit = Self.decodedMemoryCacheCostLimit
        // Keep `countLimit` generous; cost limit is the real ceiling.
        memoryCache.countLimit = Self.decodedMemoryCacheCountLimit

        let configuration = URLSessionConfiguration.default
        // 8 sockets per host fits Pixiv's CDN behaviour (HTTP/2
        // multiplexes anyway, but the limit also bounds HTTP/1.1
        // fallback). The default is 6.
        configuration.httpMaximumConnectionsPerHost = 8
        // Disk-backed HTTPCache lets repeat launches start with warm
        // thumbnails and skips re-downloading paginated feeds.
        let urlCache = URLCache(
            memoryCapacity: Self.urlCacheMemoryCapacity,
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
        configuration.httpAdditionalHeaders = Self.requestHeaders(for: EndpointHint.pixivImageURL)
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

        #if os(iOS)
        memoryWarningObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            _ = self?.clearDecodedMemoryCaches()
        }
        #endif
    }

    deinit {
        #if os(iOS)
        if let memoryWarningObserver {
            NotificationCenter.default.removeObserver(memoryWarningObserver)
        }
        #endif
    }

    // MARK: - Public API

    /// Fetches a decoded `NSImage` for the URL, hitting the in-memory
    /// cache when possible and de-duplicating concurrent requests for
    /// the same URL.
    func image(for url: URL, priority: Priority = .userInitiated) async throws -> PlatformImage {
        let key = url as NSURL
        if let cached = memoryCache.object(forKey: key) {
            return cached
        }

        // De-dup: if another caller is already fetching this URL we
        // await their Task instead of kicking off a parallel one.
        // Mutating the map needs the unfair lock; awaiting the Task
        // happens outside the critical section.
        let task: Task<PlatformImage, Error> = inFlightLock.withLock {
            if let existing = inFlight[url] {
                return existing
            }
            let new = Task<PlatformImage, Error>(priority: priority.taskPriority) { [weak self] in
                guard let self else { throw CancellationError() }
                defer { self.removeInFlight(url) }
                return try await self.fetchAndDecode(url: url, priority: priority)
            }
            inFlight[url] = new
            return new
        }
        return try await task.value
    }

    /// Synchronous decoded-bitmap cache lookup for reused scroll cells.
    ///
    /// `RemoteImageView` state disappears when native collection cells
    /// leave the reuse window, but the decoded bitmap can still be hot in
    /// `NSCache`. Let the next cell paint that cached image on its first
    /// body pass instead of showing a spinner while an async task discovers
    /// the same cache hit.
    func cachedImage(for url: URL?) -> PlatformImage? {
        guard let url else { return nil }
        if let image = memoryCache.object(forKey: url as NSURL) {
            promoteRecentImage(for: url)
            return image
        }

        return recentImageLock.withLock {
            guard let image = recentImages[url] else { return nil }
            promoteRecentImageLocked(for: url)
            if let cost = recentImageCosts[url] {
                memoryCache.setObject(image, forKey: url as NSURL, cost: cost)
            }
            return image
        }
    }

    /// Raw bytes for the URL. Used by the download queue and the
    /// reverse-image-search sheet — both consumers want the file
    /// payload, not a decoded bitmap.
    func data(for url: URL) async throws -> Data {
        let (data, response) = try await session.data(for: authenticatedRequest(for: url))
        try validate(response: response)
        return data
    }

    /// Downloads a remote resource to a file without materializing the payload
    /// as `Data`, keeping original-size saves and ZIP artifacts out of heap
    /// memory. The URLSession temporary file is first moved to a staging file
    /// beside the destination, then promoted into place so partially-completed
    /// downloads do not appear as finished files.
    @discardableResult
    func downloadFile(for url: URL, to destinationURL: URL) async throws -> Int {
        let (temporaryURL, response) = try await session.download(for: authenticatedRequest(for: url))
        try validate(response: response)

        let destinationFolder = destinationURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: destinationFolder, withIntermediateDirectories: true)

        let stagingURL = destinationFolder.appending(
            path: ".\(destinationURL.lastPathComponent).\(UUID().uuidString).download",
            directoryHint: .notDirectory
        )
        defer {
            try? FileManager.default.removeItem(at: temporaryURL)
            try? FileManager.default.removeItem(at: stagingURL)
        }

        if FileManager.default.fileExists(atPath: stagingURL.path(percentEncoded: false)) {
            try FileManager.default.removeItem(at: stagingURL)
        }
        try FileManager.default.moveItem(at: temporaryURL, to: stagingURL)

        if FileManager.default.fileExists(atPath: destinationURL.path(percentEncoded: false)) {
            try FileManager.default.removeItem(at: destinationURL)
        }
        try FileManager.default.moveItem(at: stagingURL, to: destinationURL)

        let values = try? destinationURL.resourceValues(forKeys: [.fileSizeKey, .totalFileAllocatedSizeKey])
        return values?.fileSize ?? values?.totalFileAllocatedSize ?? 0
    }

    /// Loads and force-decodes a local image file off the main thread.
    ///
    /// Reader and downloaded-artwork surfaces frequently hand us file URLs.
    /// Creating `NSImage(contentsOf:)` / `UIImage(contentsOfFile:)` from those
    /// hot paths can synchronously read and lazily decode on the UI thread.
    /// Keep local files on the same decoded-bitmap path as remote images so
    /// first paint stays smooth.
    func image(contentsOf localURL: URL, priority: Priority = .userInitiated) async throws -> PlatformImage {
        let key = localURL as NSURL
        if let cached = memoryCache.object(forKey: key) {
            return cached
        }

        let task: Task<PlatformImage, Error> = inFlightLock.withLock {
            if let existing = inFlight[localURL] {
                return existing
            }
            let new = Task<PlatformImage, Error>(priority: priority.taskPriority) { [weak self] in
                guard let self else { throw CancellationError() }
                defer { self.removeInFlight(localURL) }
                let data = try await self.readLocalImageData(from: localURL, qos: priority.dispatchQoS)
                let image = try await self.decode(data: data, qos: priority.dispatchQoS)
                let cost = self.approximateCost(of: image, fallback: data.count)
                self.storeDecodedImage(image, for: localURL, cost: cost)
                return image
            }
            inFlight[localURL] = new
            return new
        }
        return try await task.value
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
        let effectiveConcurrency = min(
            max(concurrency, 1),
            Self.maximumPrefetchConcurrency,
            cold.count
        )

        await withTaskGroup(of: Void.self) { group in
            var iterator = cold.makeIterator()
            // Seed the group up to the concurrency cap, then refill
            // one slot every time a child completes. This is the
            // structured-concurrency equivalent of a semaphore.
            for _ in 0..<effectiveConcurrency {
                guard let url = iterator.next() else { break }
                group.addTask(priority: Priority.utility.taskPriority) { [weak self] in
                    guard Task.isCancelled == false else { return }
                    _ = try? await self?.image(for: url, priority: .utility)
                }
            }
            for await _ in group {
                guard Task.isCancelled == false else {
                    group.cancelAll()
                    return
                }
                guard let url = iterator.next() else { continue }
                group.addTask(priority: Priority.utility.taskPriority) { [weak self] in
                    guard Task.isCancelled == false else { return }
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
        _ = clearDecodedMemoryCaches()
        urlCache.removeAllCachedResponses()
        return cacheStatus()
    }

    @discardableResult
    func clearDecodedMemoryCaches() -> ImageCacheStatus {
        memoryCache.removeAllObjects()
        recentImageLock.withLock {
            recentImages.removeAll(keepingCapacity: true)
            recentImageCosts.removeAll(keepingCapacity: true)
            recentImageOrder.removeAll(keepingCapacity: true)
            recentImageTotalCost = 0
        }
        return cacheStatus()
    }

    // MARK: - Private

    private func fetchAndDecode(url: URL, priority: Priority) async throws -> PlatformImage {
        let (data, response) = try await session.data(for: authenticatedRequest(for: url))
        try validate(response: response)
        let image = try await decode(data: data, qos: priority.dispatchQoS)
        let cost = approximateCost(of: image, fallback: data.count)
        storeDecodedImage(image, for: url, cost: cost)
        return image
    }

    private func storeDecodedImage(_ image: PlatformImage, for url: URL, cost: Int) {
        guard cost <= Self.maximumDecodedCacheInsertionCost else {
            memoryCache.removeObject(forKey: url as NSURL)
            forgetRecentImage(for: url)
            return
        }
        memoryCache.setObject(image, forKey: url as NSURL, cost: cost)
        rememberRecentImage(image, for: url, cost: cost)
    }

    private func promoteRecentImage(for url: URL) {
        recentImageLock.withLock {
            promoteRecentImageLocked(for: url)
        }
    }

    private func promoteRecentImageLocked(for url: URL) {
        guard recentImages[url] != nil else { return }
        recentImageOrder.removeAll { $0 == url }
        recentImageOrder.append(url)
    }

    private func rememberRecentImage(_ image: PlatformImage, for url: URL, cost: Int) {
        // Do not pin monster original images in the deterministic MRU layer.
        // They still live in NSCache and URLCache, but the strong cache is for
        // the recent scrolling window where thumbnails should feel instant.
        guard cost <= min(recentImageCostLimit / 2, Self.maximumRecentImagePinCost) else { return }

        recentImageLock.withLock {
            if let previousCost = recentImageCosts[url] {
                recentImageTotalCost -= previousCost
            }
            recentImages[url] = image
            recentImageCosts[url] = cost
            recentImageTotalCost += cost
            promoteRecentImageLocked(for: url)
            trimRecentImagesLocked()
        }
    }

    private func trimRecentImagesLocked() {
        while recentImageTotalCost > recentImageCostLimit
            || recentImageOrder.count > recentImageCountLimit {
            guard let oldest = recentImageOrder.first else { return }
            forgetRecentImageLocked(for: oldest)
        }
    }

    private func forgetRecentImage(for url: URL) {
        recentImageLock.withLock {
            forgetRecentImageLocked(for: url)
        }
    }

    private func forgetRecentImageLocked(for url: URL) {
        recentImageOrder.removeAll { $0 == url }
        recentImages.removeValue(forKey: url)
        if let cost = recentImageCosts.removeValue(forKey: url) {
            recentImageTotalCost -= cost
        }
    }

    private func readLocalImageData(from url: URL, qos: DispatchQoS.QoSClass) async throws -> Data {
        try Task.checkCancellation()
        return try await withCheckedThrowingContinuation { continuation in
            decodeDispatchQueue(for: qos).async(qos: DispatchQoS(qosClass: qos, relativePriority: 0)) {
                do {
                    try Task.checkCancellation()
                    let data = try Data(contentsOf: url, options: [.mappedIfSafe])
                    try Task.checkCancellation()
                    continuation.resume(returning: data)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Active image processors, loaded from UserDefaults.
    /// Empty array means no processing (pass-through).
    private static var activeProcessors: [any ImageProcessor] {
        guard UserDefaults.standard.bool(forKey: "imageProcessorsEnabled") else { return [] }
        let identifiers = UserDefaults.standard.stringArray(forKey: "activeImageProcessors")
            ?? ImageProcessorRegistry.defaultActiveProcessorIdentifiers
        return identifiers.compactMap { ImageProcessorRegistry.processor(for: $0) }
    }

    /// Decodes JPEG/PNG bytes on a background queue using
    /// `CGImageSource` with `kCGImageSourceShouldCacheImmediately`
    /// set so the bitmap is fully rasterized before SwiftUI ever
    /// touches it. Without this, the first time a cell draws on the
    /// main thread it pays the JPEG decode cost (~10-30 ms per
    /// master1200 frame) — which lands as a scroll stutter.
    private func decode(data: Data, qos: DispatchQoS.QoSClass) async throws -> PlatformImage {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<PlatformImage, Error>) in
            decodeDispatchQueue(for: qos).async(qos: DispatchQoS(qosClass: qos, relativePriority: 0)) {
                let options: [CFString: Any] = [
                    kCGImageSourceShouldCache: true,
                    kCGImageSourceShouldCacheImmediately: true
                ]
                guard let source = CGImageSourceCreateWithData(data as CFData, options as CFDictionary) else {
                    // Fall back to PlatformImage(data:) so we still serve
                    // formats CGImageSource doesn't recognise (rare
                    // legacy GIF / webp variants).
                    if let image = PlatformImage(data: data) {
                        continuation.resume(returning: image)
                    } else {
                        continuation.resume(throwing: PixivAPIError.invalidResponse)
                    }
                    return
                }

                guard let cgImage = CGImageSourceCreateImageAtIndex(source, 0, options as CFDictionary) else {
                    if let image = PlatformImage(data: data) {
                        continuation.resume(returning: image)
                    } else {
                        continuation.resume(throwing: PixivAPIError.invalidResponse)
                    }
                    return
                }

                // Apply image processors if any are active.
                // Reads from UserDefaults each time so toggles
                // take effect on the next image load.
                let finalImage: CGImage
                let processors = Self.activeProcessors
                if processors.isEmpty {
                    finalImage = cgImage
                } else {
                    var processed = cgImage
                    for processor in processors {
                        if let result = processor.process(processed) {
                            processed = result
                        }
                    }
                    finalImage = processed
                }

                // Use the CGImage's pixel dimensions for the image
                // size so callers receive a 1× representation that
                // SwiftUI can lay out without a second decode pass.
                #if os(macOS)
                let pixelSize = NSSize(width: finalImage.width, height: finalImage.height)
                let image = NSImage(cgImage: finalImage, size: pixelSize)
                #else
                let image = UIImage(cgImage: finalImage)
                #endif
                continuation.resume(returning: image)
            }
        }
    }

    private func decodeDispatchQueue(for qos: DispatchQoS.QoSClass) -> DispatchQueue {
        switch qos {
        case .background, .utility:
            return utilityDecodeQueue
        default:
            return decodeQueue
        }
    }

    /// Approximate cost in bytes for `NSCache.totalCostLimit`. We
    /// use 4 bytes per pixel (RGBA8) which slightly overestimates
    /// for opaque JPEGs but keeps the math cheap and safe; falls
    /// back to the raw payload size if pixel dimensions aren't
    /// reachable.
    private func approximateCost(of image: PlatformImage, fallback: Int) -> Int {
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
        for (name, value) in Self.requestHeaders(for: url) {
            request.setValue(value, forHTTPHeaderField: name)
        }
        return request
    }

    static func requestHeaders(for url: URL) -> [String: String] {
        if url.host?.lowercased() == "embed.pixiv.net" {
            return [
                "Referer": "https://www.pixiv.net/",
                "User-Agent": AppVersion.current.desktopSafariUserAgent()
            ]
        }

        return [
            "Referer": "https://app-api.pixiv.net/",
            "User-Agent": AppVersion.current.userAgentProduct
        ]
    }

    private func removeInFlight(_ url: URL) {
        inFlightLock.withLock { _ = inFlight.removeValue(forKey: url) }
    }
}

private enum EndpointHint {
    static let pixivImageURL = URL(string: "https://i.pximg.net/")!
}
