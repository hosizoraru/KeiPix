import Foundation
import Testing
@testable import KeiPix

@MainActor
@Suite("Artwork image quality quick access")
struct ArtworkImageQualityQuickAccessTests {
    @Test("Unified image quality quick access applies one tier to all surfaces")
    func unifiedImageQualityQuickAccessAppliesOneTierToAllSurfaces() {
        let store = KeiPixStore(
            downloads: ArtworkDownloadStore(completionNotifier: DownloadCompletionNotifier(
                center: FakeUserNotificationCenter(isAuthorized: false),
                authorizationStore: InMemoryAuthorizationCacheStore(hasRequested: true),
                coalesceWindowSeconds: 0.05
            )),
            bootstrapsAutomatically: false
        )

        store.setArtworkImageQualityTier(.original)

        #expect(store.feedPreviewImageQualityTier == .original)
        #expect(store.illustDetailImageQualityTier == .original)
        #expect(store.mangaDetailImageQualityTier == .original)
        #expect(store.useOriginalImagesInDetail == true)
        #expect(store.useOriginalImagesForManga == true)

        store.setArtworkImageQualityTier(.medium)

        #expect(store.feedPreviewImageQualityTier == .medium)
        #expect(store.illustDetailImageQualityTier == .medium)
        #expect(store.mangaDetailImageQualityTier == .medium)
        #expect(store.useOriginalImagesInDetail == false)
        #expect(store.useOriginalImagesForManga == false)
    }
}
