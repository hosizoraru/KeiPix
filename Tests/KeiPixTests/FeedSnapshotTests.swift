import Foundation
import Testing
@testable import KeiPix

struct FeedSnapshotTests {
    @Test("Feed snapshot library evicts oldest snapshots")
    func feedSnapshotLibraryEvictsOldestSnapshots() {
        var library = FeedSnapshotLibrary()

        for index in 0..<4 {
            library.store(
                FeedSnapshot(
                    key: "feed-\(index)",
                    routeRawValue: "recommended",
                    title: "Feed \(index)",
                    savedAt: Date(timeIntervalSince1970: TimeInterval(index)),
                    artworks: [],
                    nextURL: nil
                ),
                maxCount: 3
            )
        }

        #expect(library.snapshot(for: "feed-0") == nil)
        #expect(library.snapshot(for: "feed-1")?.title == "Feed 1")
        #expect(library.snapshots.count == 3)
    }

    @Test("Feed snapshot library round-trips through JSON")
    func feedSnapshotLibraryRoundTripsThroughJSON() throws {
        var library = FeedSnapshotLibrary()
        library.store(
            FeedSnapshot(
                key: "ranking|day",
                routeRawValue: "ranking",
                title: "Daily Ranking",
                savedAt: Date(timeIntervalSince1970: 1_771_820_800),
                artworks: [],
                nextURL: URL(string: "https://app-api.pixiv.net/v1/illust/ranking?offset=30")
            )
        )

        let data = try JSONEncoder().encode(library)
        let decoded = try JSONDecoder().decode(FeedSnapshotLibrary.self, from: data)

        #expect(decoded.snapshot(for: "ranking|day")?.title == "Daily Ranking")
        #expect(decoded.snapshot(for: "ranking|day")?.nextURL?.absoluteString.contains("offset=30") == true)
    }

    @Test("Feed snapshot restoration records visible read-only state")
    func feedSnapshotRestorationRecordsVisibleState() {
        let snapshot = FeedSnapshot(
            key: "search|blue",
            routeRawValue: "search",
            title: "Search · blue",
            savedAt: Date(timeIntervalSince1970: 1_771_820_800),
            artworks: [],
            nextURL: URL(string: "https://app-api.pixiv.net/v1/search/illust?offset=30")
        )
        let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut)
        let restoredAt = Date(timeIntervalSince1970: 1_771_824_400)

        let restoration = FeedSnapshotRestoration(
            snapshot: snapshot,
            error: error,
            restoredAt: restoredAt
        )

        #expect(restoration.snapshotKey == "search|blue")
        #expect(restoration.routeRawValue == "search")
        #expect(restoration.title == "Search · blue")
        #expect(restoration.savedAt == snapshot.savedAt)
        #expect(restoration.restoredAt == restoredAt)
        #expect(restoration.artworkCount == 0)
        #expect(restoration.hasNextPage)
        #expect(restoration.errorDescription.isEmpty == false)
    }
}
