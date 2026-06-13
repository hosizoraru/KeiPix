import Foundation

enum WorkSubscriptionContentKind: String, CaseIterable, Codable, Identifiable, Hashable, Sendable {
    case illustrations
    case manga
    case novels

    var id: String { rawValue }
}

struct WorkSubscription: Codable, Identifiable, Hashable, Sendable {
    var id: Int { creatorID }
    let creatorID: Int
    var creatorName: String
    var creatorAccount: String
    var creatorThumbnailURL: URL?
    var subscribedAt: Date
    var lastCheckedAt: Date?
    private var lastSeenWorkIDsByKind: [WorkSubscriptionContentKind: [Int]]
    private var newWorkCountsByKind: [WorkSubscriptionContentKind: Int]

    var lastSeenArtworkIDs: [Int] {
        get { lastSeenWorkIDs(for: .illustrations) }
        set { lastSeenWorkIDsByKind[.illustrations] = newValue }
    }

    var newArtworkCount: Int {
        get { newWorkCount(for: .illustrations) }
        set { newWorkCountsByKind[.illustrations] = max(0, newValue) }
    }

    var totalNewWorkCount: Int {
        WorkSubscriptionContentKind.allCases.reduce(0) { total, kind in
            total + newWorkCount(for: kind)
        }
    }

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
        self.lastSeenWorkIDsByKind = [:]
        self.newWorkCountsByKind = [:]
    }

    func lastSeenWorkIDs(for kind: WorkSubscriptionContentKind) -> [Int] {
        lastSeenWorkIDsByKind[kind] ?? []
    }

    func newWorkCount(for kind: WorkSubscriptionContentKind) -> Int {
        newWorkCountsByKind[kind] ?? 0
    }

    mutating func recordSeenWorkIDs(_ workIDs: [Int], for kind: WorkSubscriptionContentKind) -> Int {
        let previousIDs = lastSeenWorkIDs(for: kind)
        lastSeenWorkIDsByKind[kind] = workIDs

        guard previousIDs.isEmpty == false else {
            return 0
        }

        let previousSet = Set(previousIDs)
        let newCount = workIDs.filter { previousSet.contains($0) == false }.count
        guard newCount > 0 else { return 0 }

        newWorkCountsByKind[kind, default: 0] += newCount
        return newCount
    }

    mutating func clearNewWorkCounts() {
        newWorkCountsByKind = [:]
    }

    private enum CodingKeys: String, CodingKey {
        case creatorID
        case creatorName
        case creatorAccount
        case creatorThumbnailURL
        case subscribedAt
        case lastCheckedAt
        case lastSeenArtworkIDs
        case newArtworkCount
        case lastSeenWorkIDsByKind
        case newWorkCountsByKind
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        creatorID = try container.decode(Int.self, forKey: .creatorID)
        creatorName = try container.decode(String.self, forKey: .creatorName)
        creatorAccount = try container.decode(String.self, forKey: .creatorAccount)
        creatorThumbnailURL = try container.decodeIfPresent(URL.self, forKey: .creatorThumbnailURL)
        subscribedAt = try container.decode(Date.self, forKey: .subscribedAt)
        lastCheckedAt = try container.decodeIfPresent(Date.self, forKey: .lastCheckedAt)

        let decodedSeenBuckets = try container.decodeIfPresent(
            [String: [Int]].self,
            forKey: .lastSeenWorkIDsByKind
        ) ?? [:]
        let decodedCountBuckets = try container.decodeIfPresent(
            [String: Int].self,
            forKey: .newWorkCountsByKind
        ) ?? [:]

        lastSeenWorkIDsByKind = Self.bucketedWorkIDs(
            decodedSeenBuckets,
            legacyIllustrations: try container.decodeIfPresent([Int].self, forKey: .lastSeenArtworkIDs)
        )
        newWorkCountsByKind = Self.bucketedCounts(
            decodedCountBuckets,
            legacyIllustrations: try container.decodeIfPresent(Int.self, forKey: .newArtworkCount)
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(creatorID, forKey: .creatorID)
        try container.encode(creatorName, forKey: .creatorName)
        try container.encode(creatorAccount, forKey: .creatorAccount)
        try container.encodeIfPresent(creatorThumbnailURL, forKey: .creatorThumbnailURL)
        try container.encode(subscribedAt, forKey: .subscribedAt)
        try container.encodeIfPresent(lastCheckedAt, forKey: .lastCheckedAt)
        try container.encode(Self.rawWorkIDBuckets(lastSeenWorkIDsByKind), forKey: .lastSeenWorkIDsByKind)
        try container.encode(Self.rawCountBuckets(newWorkCountsByKind), forKey: .newWorkCountsByKind)
        try container.encode(lastSeenArtworkIDs, forKey: .lastSeenArtworkIDs)
        try container.encode(newArtworkCount, forKey: .newArtworkCount)
    }

    private static func bucketedWorkIDs(
        _ rawBuckets: [String: [Int]],
        legacyIllustrations: [Int]?
    ) -> [WorkSubscriptionContentKind: [Int]] {
        var buckets = rawBuckets.reduce(into: [WorkSubscriptionContentKind: [Int]]()) { partial, pair in
            guard let kind = WorkSubscriptionContentKind(rawValue: pair.key) else { return }
            partial[kind] = pair.value
        }
        if buckets[.illustrations] == nil, let legacyIllustrations {
            buckets[.illustrations] = legacyIllustrations
        }
        return buckets
    }

    private static func bucketedCounts(
        _ rawBuckets: [String: Int],
        legacyIllustrations: Int?
    ) -> [WorkSubscriptionContentKind: Int] {
        var buckets = rawBuckets.reduce(into: [WorkSubscriptionContentKind: Int]()) { partial, pair in
            guard let kind = WorkSubscriptionContentKind(rawValue: pair.key) else { return }
            partial[kind] = max(0, pair.value)
        }
        if buckets[.illustrations] == nil, let legacyIllustrations {
            buckets[.illustrations] = max(0, legacyIllustrations)
        }
        return buckets
    }

    private static func rawWorkIDBuckets(
        _ buckets: [WorkSubscriptionContentKind: [Int]]
    ) -> [String: [Int]] {
        buckets.reduce(into: [String: [Int]]()) { partial, pair in
            partial[pair.key.rawValue] = pair.value
        }
    }

    private static func rawCountBuckets(
        _ buckets: [WorkSubscriptionContentKind: Int]
    ) -> [String: Int] {
        buckets.reduce(into: [String: Int]()) { partial, pair in
            partial[pair.key.rawValue] = max(0, pair.value)
        }
    }
}
