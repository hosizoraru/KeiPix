import Foundation

enum BatchDownloadScope: String, Hashable, Sendable {
    case loadedFeed
    case selectedWorks
}

struct BatchDownloadPlan: Equatable, Sendable {
    static let maximumLoadedFeedLimit = 100
    static let maximumRemotePageLimit = 5

    let scope: BatchDownloadScope
    let loadedArtworkCount: Int
    let hasNextPage: Bool
    let limit: Int
    let maxLimit: Int
    let remotePageLimit: Int

    var allowsRemotePages: Bool {
        scope == .loadedFeed && hasNextPage
    }

    var estimatedRemotePageRequests: Int {
        allowsRemotePages ? remotePageLimit : 0
    }

    static func make(
        scope: BatchDownloadScope,
        loadedArtworkCount: Int,
        hasNextPage: Bool,
        requestedLimit: Int,
        requestedRemotePageLimit: Int
    ) -> BatchDownloadPlan {
        let loadedCount = max(loadedArtworkCount, 0)
        let canFetchNextPages = scope == .loadedFeed && hasNextPage
        let maxLimit = canFetchNextPages
            ? maximumLoadedFeedLimit
            : min(max(loadedCount, 1), maximumLoadedFeedLimit)
        let limit = min(max(requestedLimit, 1), maxLimit)
        let remotePageLimit = canFetchNextPages
            ? min(max(requestedRemotePageLimit, 0), maximumRemotePageLimit)
            : 0

        return BatchDownloadPlan(
            scope: scope,
            loadedArtworkCount: loadedCount,
            hasNextPage: hasNextPage,
            limit: limit,
            maxLimit: maxLimit,
            remotePageLimit: remotePageLimit
        )
    }
}

struct BatchDownloadResult: Equatable, Sendable {
    let queuedCount: Int
    let candidateCount: Int
    let fetchedPageCount: Int
    let reachedEnd: Bool
}
