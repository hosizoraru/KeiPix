import Foundation

/// Sliding-window byte/sec sampler for the active download workers.
///
/// `ArtworkDownloadStore.download(_:sourceURLs:)` records one sample per
/// finished page (we only get bytes after `URLSession.data(for:)`
/// returns, so the granularity is per-page rather than per-chunk). The
/// sampler keeps two buckets:
///
/// - **per-item samples** drive the in-row "1.2 MB/s" badge, so each
///   download row reflects its own pipe.
/// - **aggregate samples** drive the queue-level "Total 4.6 MB/s" line
///   in the navigation subtitle, so users can sanity-check whether the
///   pipe is saturated when several workers are running.
///
/// Samples older than `windowSeconds` get pruned on every mutation so
/// the rate decays naturally once a worker stops, instead of pinning
/// stale numbers on screen. We also cap each bucket to a fixed sample
/// count so the dictionaries stay bounded if the user runs hundreds of
/// completed pages through a single item before pausing.
///
/// **Why a struct, not an actor.**
/// `ArtworkDownloadStore` is `@MainActor` and `@Observable`; threading
/// its sampler through an actor would force every read in a SwiftUI
/// `body` to await, which we can't do from a non-async getter. The
/// struct sits as a stored property on the store, so mutating methods
/// fire through the `@Observable` setter and SwiftUI re-renders the
/// rows that read `bytesPerSecond(for:)`.
struct DownloadThroughputSampler: Sendable {
    private struct Sample: Sendable {
        let recordedAt: Date
        let bytes: Int
        let durationSeconds: TimeInterval
    }

    /// Per-item sliding window. Keyed by `ArtworkDownloadItem.id` so
    /// the row can look up its own rate without scanning a flat list.
    private var perItem: [UUID: [Sample]] = [:]
    /// Aggregate window across every active worker. Reused for the
    /// queue-level total in the navigation subtitle.
    private var aggregate: [Sample] = []

    /// 8 seconds picks up short bursts (a Pixiv master1200 page lands
    /// in ~0.5–2 s on a fast connection) without smoothing so hard
    /// that a stalled worker's old high reading sticks around. Tuned
    /// alongside the per-page sampling cadence; see record(_:).
    private let windowSeconds: TimeInterval = 8
    private let maxSamplesPerItem = 16
    private let maxAggregateSamples = 64

    /// Record one finished page's transfer. `bytes` is the payload
    /// size we just wrote to disk, `durationSeconds` is the wall clock
    /// span between sending the request and receiving the data.
    mutating func record(
        itemID: UUID,
        bytes: Int,
        durationSeconds: TimeInterval,
        at date: Date = Date()
    ) {
        guard bytes > 0, durationSeconds > 0 else { return }
        let sample = Sample(recordedAt: date, bytes: bytes, durationSeconds: durationSeconds)
        var existing = perItem[itemID] ?? []
        existing.append(sample)
        perItem[itemID] = Self.pruned(
            existing,
            now: date,
            windowSeconds: windowSeconds,
            maxCount: maxSamplesPerItem
        )
        aggregate.append(sample)
        aggregate = Self.pruned(
            aggregate,
            now: date,
            windowSeconds: windowSeconds,
            maxCount: maxAggregateSamples
        )
    }

    /// Drop the per-item bucket. Called whenever an item leaves the
    /// `.downloading` state so the queue doesn't keep showing a rate
    /// for a row that's no longer pulling bytes.
    mutating func reset(itemID: UUID) {
        perItem.removeValue(forKey: itemID)
    }

    /// Drop every bucket. Hooked from `pauseQueue()` so pausing
    /// instantly hides the rates instead of waiting for the window to
    /// expire.
    mutating func resetAll() {
        perItem.removeAll()
        aggregate.removeAll()
    }

    /// Bytes-per-second for the row identified by `itemID`. Returns
    /// `nil` when no samples have been recorded yet or the recent
    /// samples have all aged out.
    func bytesPerSecond(for itemID: UUID, at date: Date = Date()) -> Double? {
        guard let samples = perItem[itemID] else { return nil }
        return Self.rate(of: samples, now: date, windowSeconds: windowSeconds)
    }

    /// Aggregate bytes-per-second across every recent sample. The
    /// queue-level subtitle reads this, gated on `downloadingCount > 0`
    /// upstream so the number disappears the moment workers idle.
    func aggregateBytesPerSecond(at date: Date = Date()) -> Double? {
        Self.rate(of: aggregate, now: date, windowSeconds: windowSeconds)
    }

    private static func pruned(
        _ samples: [Sample],
        now: Date,
        windowSeconds: TimeInterval,
        maxCount: Int
    ) -> [Sample] {
        let cutoff = now.addingTimeInterval(-windowSeconds)
        let recent = samples.filter { $0.recordedAt >= cutoff }
        return recent.count > maxCount ? Array(recent.suffix(maxCount)) : recent
    }

    private static func rate(
        of samples: [Sample],
        now: Date,
        windowSeconds: TimeInterval
    ) -> Double? {
        let cutoff = now.addingTimeInterval(-windowSeconds)
        let recent = samples.filter { $0.recordedAt >= cutoff }
        guard recent.isEmpty == false else { return nil }
        let totalBytes = recent.reduce(0) { $0 + $1.bytes }
        let totalDuration = recent.reduce(0) { $0 + $1.durationSeconds }
        guard totalDuration > 0 else { return nil }
        return Double(totalBytes) / totalDuration
    }
}
