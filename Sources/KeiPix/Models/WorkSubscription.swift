import Foundation

struct WorkSubscription: Codable, Identifiable, Hashable, Sendable {
    var id: Int { creatorID }
    let creatorID: Int
    var creatorName: String
    var creatorAccount: String
    var creatorThumbnailURL: URL?
    var subscribedAt: Date
    var lastCheckedAt: Date?
    var lastSeenArtworkIDs: [Int]
    var newArtworkCount: Int

    init(
        creatorID: Int,
        creatorName: String,
        creatorAccount: String,
        creatorThumbnailURL: URL? = nil
    ) {
        self.creatorID = creatorID
        self.creatorName = creatorName
        self.creatorAccount = creatorAccount
        self.creatorThumbnailURL = creatorThumbnailURL
        self.subscribedAt = Date()
        self.lastCheckedAt = nil
        self.lastSeenArtworkIDs = []
        self.newArtworkCount = 0
    }
}
