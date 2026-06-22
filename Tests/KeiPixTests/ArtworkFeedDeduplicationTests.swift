import Foundation
import Testing
@testable import KeiPix

@Suite("Artwork feed deduplication")
struct ArtworkFeedDeduplicationTests {
    @Test("Content filtering repairs duplicate artwork ids before native gallery")
    @MainActor
    func contentFilteringRepairsDuplicateArtworkIDs() {
        let store = makeStore()
        store.allArtworks = [
            artwork(id: 101, title: "First"),
            artwork(id: 202, title: "Second"),
            artwork(id: 101, title: "First duplicate"),
            artwork(id: 303, title: "Third"),
            artwork(id: 202, title: "Second duplicate")
        ]

        store.applyContentFilters()

        #expect(store.allArtworks.map(\.id) == [101, 202, 303])
        #expect(store.artworks.map(\.id) == [101, 202, 303])
        #expect(store.clientFilteredArtworks.map(\.id) == [101, 202, 303])
        #expect(store.selectedArtwork?.id == 101)
    }

    @Test("Feed snapshots persist repaired artwork ids")
    @MainActor
    func feedSnapshotsPersistRepairedArtworkIDs() {
        let store = makeStore()
        let context = FeedRequestContext(
            route: .following,
            focusedUserID: nil,
            searchText: "",
            searchSubmissionID: 0,
            bookmarkTagFilter: nil,
            bookmarkFeedOptions: .defaultValue,
            creatorArtworkTagFilter: nil,
            pixivCollectionID: nil,
            useRankingDate: false,
            rankingDate: Date(timeIntervalSince1970: 0),
            searchOptions: .defaultValue
        )

        store.storeFeedSnapshot(
            PixivFeedResponse(
                illusts: [
                    artwork(id: 101, title: "First"),
                    artwork(id: 101, title: "First duplicate"),
                    artwork(id: 202, title: "Second")
                ],
                nextURL: nil
            ),
            for: context
        )

        let snapshot = store.feedSnapshotLibrary.snapshot(for: context.snapshotKey)
        #expect(snapshot?.artworks.map(\.id) == [101, 202])
    }

    @Test("Feed pagination preserves first occurrence and ignores repeated page boundary items")
    func paginationDeduplicatesIncomingArtworkIDs() {
        let existing = [
            artwork(id: 101, title: "First"),
            artwork(id: 202, title: "Second")
        ]
        let incoming = [
            artwork(id: 202, title: "Second repeated"),
            artwork(id: 303, title: "Third"),
            artwork(id: 303, title: "Third repeated"),
            artwork(id: 404, title: "Fourth")
        ]

        let merged = ArtworkFeedDeduplication.appending(incoming, to: existing)

        #expect(merged.map(\.id) == [101, 202, 303, 404])
        #expect(merged.first(where: { $0.id == 202 })?.title == "Second")
        #expect(merged.first(where: { $0.id == 303 })?.title == "Third")
    }

    @Test("Native gallery diffable items drop repeated identifiers")
    func nativeGalleryDiffableItemsDropRepeatedIdentifiers() {
        let items: [NativeGalleryCollectionItem] = [
            .cachedStatus,
            .artwork(artwork(id: 101, title: "First")),
            .artwork(artwork(id: 101, title: "First duplicate")),
            .loadMore,
            .loadMore
        ]

        let diffableItems = NativeGalleryCollectionItems.diffableItems(items)

        #expect(diffableItems.map(\.id) == [
            "cached-status",
            "artwork-101",
            "load-more"
        ])
    }

    private func artwork(id: Int, title: String) -> PixivArtwork {
        PixivArtwork(
            id: id,
            title: title,
            type: "illust",
            caption: "",
            user: PixivUser(id: 42, name: "Creator", account: "creator", isFollowed: true),
            tags: [],
            createDate: Date(timeIntervalSince1970: TimeInterval(id)),
            pageCount: 1,
            width: 1000,
            height: 1000,
            totalView: 0,
            totalBookmarks: 0,
            totalComments: 0,
            isBookmarked: false,
            isMuted: false,
            isAI: false,
            sanityLevel: 0,
            xRestrict: 0,
            series: nil,
            images: []
        )
    }

    @MainActor
    private func makeStore() -> KeiPixStore {
        KeiPixStore(
            downloads: ArtworkDownloadStore(completionNotifier: DownloadCompletionNotifier(
                center: FakeUserNotificationCenter(isAuthorized: false),
                authorizationStore: InMemoryAuthorizationCacheStore(hasRequested: true),
                coalesceWindowSeconds: 0.05
            )),
            bootstrapsAutomatically: false
        )
    }
}
