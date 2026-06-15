import Foundation
import Testing
@testable import KeiPix

@MainActor
struct ClientFilterScopeTests {
    @Test("Client feed filters restore per route and search context")
    func filtersRestorePerRouteAndSearchContext() {
        let store = KeiPixStore(
            downloads: ArtworkDownloadStore(completionNotifier: DownloadCompletionNotifier(
                center: FakeUserNotificationCenter(isAuthorized: false),
                authorizationStore: InMemoryAuthorizationCacheStore(hasRequested: true),
                coalesceWindowSeconds: 0.05
            )),
            bootstrapsAutomatically: false
        )

        store.selectedRoute = .illustrations
        store.clientFilterQuery = "tag:landscape"

        store.selectedRoute = .mangaRecommended
        #expect(store.clientFilterQuery == "")
        store.clientFilterQuery = "title:manga"

        store.selectedRoute = .novelLatest
        #expect(store.clientFilterQuery == "")
        store.clientFilterQuery = "length:>5000"

        store.selectedRoute = .illustrations
        #expect(store.clientFilterQuery == "tag:landscape")

        store.searchText = "wide"
        store.selectedRoute = .search
        #expect(store.clientFilterQuery == "")
        store.clientFilterQuery = "ratio:landscape"

        store.searchText = "portrait"
        store.restoreClientFilterQueryForCurrentScope()
        #expect(store.clientFilterQuery == "")

        store.searchText = "wide"
        store.restoreClientFilterQueryForCurrentScope()
        #expect(store.clientFilterQuery == "ratio:landscape")

        store.searchText = "alice"
        store.selectedRoute = .searchUsers
        #expect(store.clientFilterQuery == "")
        store.clientFilterQuery = "followed"

        store.searchText = "bob"
        store.restoreClientFilterQueryForCurrentScope()
        #expect(store.clientFilterQuery == "")

        store.searchText = "alice"
        store.restoreClientFilterQueryForCurrentScope()
        #expect(store.clientFilterQuery == "followed")

        store.searchText = "novel wide"
        store.selectedRoute = .novelSearch
        #expect(store.clientFilterQuery == "")
        store.clientFilterQuery = "word:>1000"

        store.searchText = "novel portrait"
        store.restoreClientFilterQueryForCurrentScope()
        #expect(store.clientFilterQuery == "")

        store.searchText = "novel wide"
        store.restoreClientFilterQueryForCurrentScope()
        #expect(store.clientFilterQuery == "word:>1000")

        store.selectedRoute = .novelLatest
        #expect(store.clientFilterQuery == "length:>5000")

        store.selectedRoute = .mangaRecommended
        #expect(store.clientFilterQuery == "title:manga")
    }

    @Test("Pixiv activity uses the route-scoped feed filter")
    func pixivActivityUsesRouteScopedFeedFilter() {
        let store = KeiPixStore(
            downloads: ArtworkDownloadStore(completionNotifier: DownloadCompletionNotifier(
                center: FakeUserNotificationCenter(isAuthorized: false),
                authorizationStore: InMemoryAuthorizationCacheStore(hasRequested: true),
                coalesceWindowSeconds: 0.05
            )),
            bootstrapsAutomatically: false
        )

        store.selectedRoute = .pixivActivity
        store.pixivActivityItems = [
            Self.activityItem(id: "posted", kind: .postedArtwork, targetTitle: "Blue Morning"),
            Self.activityItem(id: "bookmark", kind: .bookmarkedArtwork, targetTitle: "Blue Archive"),
            Self.activityItem(id: "follow", kind: .followedUser, targetTitle: "Followed Bob")
        ]

        store.pixivActivityKindFilter = .bookmarkedArtwork
        store.clientFilterQuery = "Blue"
        #expect(store.pixivActivityVisibleItems.map(\.id) == ["bookmark"])

        store.selectedRoute = .illustrations
        #expect(store.clientFilterQuery == "")
        store.clientFilterQuery = "tag:landscape"

        store.selectedRoute = .pixivActivity
        #expect(store.clientFilterQuery == "Blue")
        #expect(store.pixivActivityVisibleItems.map(\.id) == ["bookmark"])
    }

    private static func activityItem(
        id: String,
        kind: PixivActivityKind,
        targetTitle: String
    ) -> PixivActivityItem {
        PixivActivityItem(
            id: id,
            kind: kind,
            actor: PixivActivityActor(userID: 42, name: "Alice", avatarURL: nil),
            target: PixivActivityTarget(
                kind: kind == .followedUser ? .user : .artwork,
                id: "100",
                title: targetTitle,
                url: nil,
                thumbnailURL: nil,
                author: PixivActivityActor(userID: 88, name: "Bob", avatarURL: nil)
            ),
            occurredAt: Date(timeIntervalSince1970: 1_800_000_000),
            summary: targetTitle
        )
    }
}
