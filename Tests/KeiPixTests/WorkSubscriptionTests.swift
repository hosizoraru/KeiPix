import Foundation
import Testing
@testable import KeiPix

@Suite("Work subscriptions")
struct WorkSubscriptionTests {
    @Test("Legacy artwork-only subscription state migrates into the illustration bucket")
    func legacyArtworkStateMigratesIntoIllustrationBucket() throws {
        let data = Data("""
        {
          "creatorID": 42,
          "creatorName": "Series QA Creator",
          "creatorAccount": "series_qa",
          "subscribedAt": "2026-06-01T00:00:00Z",
          "lastCheckedAt": "2026-06-02T00:00:00Z",
          "lastSeenArtworkIDs": [10, 9],
          "newArtworkCount": 2
        }
        """.utf8)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let subscription = try decoder.decode(WorkSubscription.self, from: data)

        #expect(subscription.lastSeenWorkIDs(for: .illustrations) == [10, 9])
        #expect(subscription.newWorkCount(for: .illustrations) == 2)
        #expect(subscription.lastSeenWorkIDs(for: .manga).isEmpty)
        #expect(subscription.lastSeenWorkIDs(for: .novels).isEmpty)
        #expect(subscription.totalNewWorkCount == 2)
    }

    @Test("Subscription update buckets track illustrations manga and novels independently")
    func updateBucketsTrackKindsIndependently() {
        var subscription = WorkSubscription(
            creatorID: 42,
            creatorName: "Series QA Creator",
            creatorAccount: "series_qa"
        )

        #expect(subscription.recordSeenWorkIDs([100, 99], for: .illustrations) == 0)
        #expect(subscription.recordSeenWorkIDs([300], for: .manga) == 0)
        #expect(subscription.recordSeenWorkIDs([900], for: .novels) == 0)

        #expect(subscription.recordSeenWorkIDs([101, 100, 99], for: .illustrations) == 1)
        #expect(subscription.recordSeenWorkIDs([301, 300], for: .manga) == 1)
        #expect(subscription.recordSeenWorkIDs([902, 901, 900], for: .novels) == 2)

        #expect(subscription.newWorkCount(for: .illustrations) == 1)
        #expect(subscription.newWorkCount(for: .manga) == 1)
        #expect(subscription.newWorkCount(for: .novels) == 2)
        #expect(subscription.totalNewWorkCount == 4)

        subscription.clearNewWorkCounts()
        #expect(subscription.totalNewWorkCount == 0)
    }

    @Test("Bucketed subscription state survives JSON round trip")
    func bucketedStateSurvivesJSONRoundTrip() throws {
        var subscription = WorkSubscription(
            creatorID: 42,
            creatorName: "Series QA Creator",
            creatorAccount: "series_qa"
        )

        _ = subscription.recordSeenWorkIDs([100], for: .illustrations)
        _ = subscription.recordSeenWorkIDs([300], for: .manga)
        _ = subscription.recordSeenWorkIDs([900], for: .novels)
        _ = subscription.recordSeenWorkIDs([101, 100], for: .illustrations)
        _ = subscription.recordSeenWorkIDs([901, 900], for: .novels)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(subscription)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(WorkSubscription.self, from: data)

        #expect(decoded.lastSeenWorkIDs(for: .illustrations) == [101, 100])
        #expect(decoded.lastSeenWorkIDs(for: .manga) == [300])
        #expect(decoded.lastSeenWorkIDs(for: .novels) == [901, 900])
        #expect(decoded.newWorkCount(for: .illustrations) == 1)
        #expect(decoded.newWorkCount(for: .manga) == 0)
        #expect(decoded.newWorkCount(for: .novels) == 1)
        #expect(decoded.totalNewWorkCount == 2)
    }
}
