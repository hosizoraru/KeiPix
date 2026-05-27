import Foundation
import Testing
@testable import KeiPix

@Suite("Download throughput sampler")
struct DownloadThroughputSamplerTests {
    @Test("Per-item rate averages bytes over the recorded duration")
    func perItemRate() {
        var sampler = DownloadThroughputSampler()
        let itemID = UUID()
        let now = Date(timeIntervalSince1970: 1_000)

        sampler.record(itemID: itemID, bytes: 1_000_000, durationSeconds: 1.0, at: now)
        sampler.record(itemID: itemID, bytes: 2_000_000, durationSeconds: 1.0, at: now)

        let rate = sampler.bytesPerSecond(for: itemID, at: now)
        #expect(rate == 1_500_000)
    }

    @Test("Aggregate rate sums every active worker")
    func aggregateRate() {
        var sampler = DownloadThroughputSampler()
        let itemA = UUID()
        let itemB = UUID()
        let now = Date(timeIntervalSince1970: 2_000)

        sampler.record(itemID: itemA, bytes: 500_000, durationSeconds: 1.0, at: now)
        sampler.record(itemID: itemB, bytes: 1_500_000, durationSeconds: 1.0, at: now)

        let aggregate = sampler.aggregateBytesPerSecond(at: now)
        #expect(aggregate == 1_000_000)
    }

    @Test("Samples older than the window are pruned out")
    func slidingWindowPruning() {
        var sampler = DownloadThroughputSampler()
        let itemID = UUID()
        let stale = Date(timeIntervalSince1970: 1_000)
        let fresh = stale.addingTimeInterval(20)

        sampler.record(itemID: itemID, bytes: 9_999_999, durationSeconds: 1.0, at: stale)
        sampler.record(itemID: itemID, bytes: 1_000_000, durationSeconds: 1.0, at: fresh)

        let rate = sampler.bytesPerSecond(for: itemID, at: fresh)
        #expect(rate == 1_000_000)
    }

    @Test("Reset drops a single item without disturbing others")
    func resetItem() {
        var sampler = DownloadThroughputSampler()
        let itemA = UUID()
        let itemB = UUID()
        let now = Date(timeIntervalSince1970: 3_000)

        sampler.record(itemID: itemA, bytes: 1_000_000, durationSeconds: 1.0, at: now)
        sampler.record(itemID: itemB, bytes: 2_000_000, durationSeconds: 1.0, at: now)
        sampler.reset(itemID: itemA)

        #expect(sampler.bytesPerSecond(for: itemA, at: now) == nil)
        #expect(sampler.bytesPerSecond(for: itemB, at: now) == 2_000_000)
    }

    @Test("Reset all clears every bucket immediately")
    func resetAll() {
        var sampler = DownloadThroughputSampler()
        let itemID = UUID()
        let now = Date(timeIntervalSince1970: 4_000)

        sampler.record(itemID: itemID, bytes: 1_000_000, durationSeconds: 1.0, at: now)
        sampler.resetAll()

        #expect(sampler.bytesPerSecond(for: itemID, at: now) == nil)
        #expect(sampler.aggregateBytesPerSecond(at: now) == nil)
    }

    @Test("Zero or negative samples are ignored so the speedometer never lies")
    func ignoresInvalidSamples() {
        var sampler = DownloadThroughputSampler()
        let itemID = UUID()
        let now = Date(timeIntervalSince1970: 5_000)

        sampler.record(itemID: itemID, bytes: 0, durationSeconds: 1.0, at: now)
        sampler.record(itemID: itemID, bytes: 1_000_000, durationSeconds: 0, at: now)

        #expect(sampler.bytesPerSecond(for: itemID, at: now) == nil)
    }
}
