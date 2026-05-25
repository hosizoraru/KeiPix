import Foundation

struct FeedSnapshotLibrary: Codable, Sendable {
    var snapshots: [String: FeedSnapshot] = [:]

    mutating func store(_ snapshot: FeedSnapshot, maxCount: Int = 24) {
        snapshots[snapshot.key] = snapshot
        guard snapshots.count > maxCount else { return }

        let removableKeys = snapshots.values
            .sorted { $0.savedAt < $1.savedAt }
            .prefix(snapshots.count - maxCount)
            .map(\.key)
        for key in removableKeys {
            snapshots[key] = nil
        }
    }

    func snapshot(for key: String) -> FeedSnapshot? {
        snapshots[key]
    }
}

struct FeedSnapshot: Codable, Sendable {
    let key: String
    let routeRawValue: String
    let title: String
    let savedAt: Date
    let artworks: [PixivArtwork]
    let nextURL: URL?
}
