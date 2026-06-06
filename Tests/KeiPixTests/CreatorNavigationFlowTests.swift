import Testing
@testable import KeiPix

@MainActor
@Suite("Creator navigation flow")
struct CreatorNavigationFlowTests {
    @Test("Creator profile routes can move between illustrations, manga, novels, tags, clear, back, and forward")
    func creatorProfileRouteFlow() async {
        let store = KeiPixStore(
            downloads: ArtworkDownloadStore(completionNotifier: DownloadCompletionNotifier(
                center: FakeUserNotificationCenter(isAuthorized: false),
                authorizationStore: InMemoryAuthorizationCacheStore(hasRequested: true),
                coalesceWindowSeconds: 0.05
            )),
            bootstrapsAutomatically: false
        )
        store.accountSessionMode = .real
        store.session = nil
        let creator = PixivUser(id: 7391, name: "Flow Artist", account: "flow_artist")
        let tag = CreatorArtworkTag(name: "blue", translatedName: "Blue", yomigana: nil, count: 6)

        store.presentedUserProfile = creator
        #expect(store.presentedUserProfile == creator)

        await store.openUserFeed(user: creator, route: .userIllustrations)
        #expect(store.selectedRoute == .userIllustrations)
        #expect(store.focusedUser == creator)
        #expect(store.creatorArtworkTagFilter == nil)
        #expect(store.canNavigateBack == false)

        await store.openUserFeed(user: creator, route: .userManga)
        #expect(store.selectedRoute == .userManga)
        #expect(store.canNavigateBack)

        await store.openUserFeed(user: creator, route: .userNovels)
        #expect(store.selectedRoute == .userNovels)
        #expect(store.focusedUser == creator)
        #expect(store.creatorArtworkTagFilter == nil)
        #expect(store.canNavigateBack)

        await store.openCreatorTagFeed(user: creator, tag: tag)
        #expect(store.selectedRoute == .userIllustrations)
        #expect(store.creatorArtworkTagFilter == CreatorArtworkTagFilter(userID: creator.id, tag: tag.name, expectedCount: tag.count))

        store.navigateBack()
        #expect(store.selectedRoute == .userNovels)
        #expect(store.focusedUser == creator)
        #expect(store.creatorArtworkTagFilter == nil)
        #expect(store.canNavigateForward)

        store.navigateBack()
        #expect(store.selectedRoute == .userManga)
        #expect(store.focusedUser == creator)
        #expect(store.creatorArtworkTagFilter == nil)
        #expect(store.canNavigateForward)

        store.navigateForward()
        #expect(store.selectedRoute == .userNovels)
        #expect(store.focusedUser == creator)
        #expect(store.creatorArtworkTagFilter == nil)

        store.navigateForward()
        #expect(store.selectedRoute == .userIllustrations)
        #expect(store.creatorArtworkTagFilter == CreatorArtworkTagFilter(userID: creator.id, tag: tag.name, expectedCount: tag.count))

        await store.clearCreatorFeedContext()
        #expect(store.focusedUser == creator)
        #expect(store.creatorArtworkTagFilter == nil)
        #expect(store.selectedRoute == .userIllustrations)
        #expect(store.canNavigateBack)

        store.navigateBack()
        #expect(store.selectedRoute == .userIllustrations)
        #expect(store.creatorArtworkTagFilter == CreatorArtworkTagFilter(userID: creator.id, tag: tag.name, expectedCount: tag.count))
        #expect(store.canNavigateForward)

        store.navigateForward()
        #expect(store.selectedRoute == .userIllustrations)
        #expect(store.focusedUser == creator)
        #expect(store.creatorArtworkTagFilter == nil)

        await store.clearCreatorFeedContext()
        #expect(store.focusedUser == nil)
        #expect(store.creatorArtworkTagFilter == nil)
        #expect(store.selectedRoute == .illustrations)
        #expect(store.canNavigateBack)

        store.navigateBack()
        #expect(store.selectedRoute == .userIllustrations)
        #expect(store.focusedUser == creator)
        #expect(store.creatorArtworkTagFilter == nil)

        store.navigateForward()
        #expect(store.selectedRoute == .illustrations)
        #expect(store.focusedUser == nil)
    }

    @Test("Clearing a creator novel route exits to the novel recommendation route and stays navigable")
    func clearingCreatorNovelRouteKeepsHistoryCoherent() async {
        let store = KeiPixStore(
            downloads: ArtworkDownloadStore(completionNotifier: DownloadCompletionNotifier(
                center: FakeUserNotificationCenter(isAuthorized: false),
                authorizationStore: InMemoryAuthorizationCacheStore(hasRequested: true),
                coalesceWindowSeconds: 0.05
            )),
            bootstrapsAutomatically: false
        )
        store.accountSessionMode = .real
        store.session = nil
        let creator = PixivUser(id: 8801, name: "Novel Artist", account: "novel_artist")

        await store.openUserFeed(user: creator, route: .userIllustrations)
        await store.openUserFeed(user: creator, route: .userNovels)
        await store.clearCreatorFeedContext()

        #expect(store.selectedRoute == .novelRecommended)
        #expect(store.focusedUser == nil)
        #expect(store.creatorArtworkTagFilter == nil)
        #expect(store.canNavigateBack)

        store.navigateBack()
        #expect(store.selectedRoute == .userNovels)
        #expect(store.focusedUser == creator)

        store.navigateForward()
        #expect(store.selectedRoute == .novelRecommended)
        #expect(store.focusedUser == nil)
    }
}
