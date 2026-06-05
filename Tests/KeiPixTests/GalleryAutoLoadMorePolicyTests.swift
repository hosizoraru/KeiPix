import Foundation
import Testing
@testable import KeiPix

struct GalleryAutoLoadMorePolicyTests {
    @Test("Auto load triggers once for a ready next page")
    func triggersOnceForReadyNextPage() throws {
        let nextURL = try #require(URL(string: "https://app-api.pixiv.net/v1/illust/recommended?offset=30"))

        #expect(
            GalleryAutoLoadMorePolicy.shouldTrigger(
                nextURL: nextURL,
                isLoadingMore: false,
                hasRestoration: false,
                lastTriggeredURL: nil
            )
        )
        #expect(
            GalleryAutoLoadMorePolicy.shouldTrigger(
                nextURL: nextURL,
                isLoadingMore: false,
                hasRestoration: false,
                lastTriggeredURL: nextURL
            ) == false
        )
    }

    @Test("Auto load waits while loading, restoring, or out of pages")
    func waitsForLoadableState() throws {
        let nextURL = try #require(URL(string: "https://app-api.pixiv.net/v1/illust/recommended?offset=30"))

        #expect(
            GalleryAutoLoadMorePolicy.shouldTrigger(
                nextURL: nil,
                isLoadingMore: false,
                hasRestoration: false,
                lastTriggeredURL: nil
            ) == false
        )
        #expect(
            GalleryAutoLoadMorePolicy.shouldTrigger(
                nextURL: nextURL,
                isLoadingMore: true,
                hasRestoration: false,
                lastTriggeredURL: nil
            ) == false
        )
        #expect(
            GalleryAutoLoadMorePolicy.shouldTrigger(
                nextURL: nextURL,
                isLoadingMore: false,
                hasRestoration: true,
                lastTriggeredURL: nil
            ) == false
        )
    }

    @Test("Auto load can trigger again when Pixiv returns a new next URL")
    func allowsNewNextURL() throws {
        let previousURL = try #require(URL(string: "https://app-api.pixiv.net/v1/illust/recommended?offset=30"))
        let newURL = try #require(URL(string: "https://app-api.pixiv.net/v1/illust/recommended?offset=60"))

        #expect(
            GalleryAutoLoadMorePolicy.shouldTrigger(
                nextURL: newURL,
                isLoadingMore: false,
                hasRestoration: false,
                lastTriggeredURL: previousURL
            )
        )
    }

    @Test("Native scroll trigger starts before the load-more tile is the only visible content")
    func nearContentEndUsesAPrefetchWindow() {
        #expect(
            GalleryAutoLoadMorePolicy.isNearContentEnd(
                contentOffsetY: 2_560,
                viewportHeight: 800,
                contentHeight: 4_000
            )
        )
        #expect(
            GalleryAutoLoadMorePolicy.isNearContentEnd(
                contentOffsetY: 1_200,
                viewportHeight: 800,
                contentHeight: 4_000
            ) == false
        )
    }

    @Test("Native scroll trigger treats short filtered feeds as loadable")
    func shortFilteredFeedsAreNearTheEnd() {
        #expect(
            GalleryAutoLoadMorePolicy.isNearContentEnd(
                contentOffsetY: 0,
                viewportHeight: 900,
                contentHeight: 760
            )
        )
    }
}
