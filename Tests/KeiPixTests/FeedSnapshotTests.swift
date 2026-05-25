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
}
