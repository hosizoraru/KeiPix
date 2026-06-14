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

        store.selectedRoute = .mangaRecommended
        #expect(store.clientFilterQuery == "title:manga")
    }
}
