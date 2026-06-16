import Foundation
import SwiftUI
import Testing
@testable import KeiPix

@MainActor
@Suite("Artwork image quality quick access", .serialized)
struct ArtworkImageQualityQuickAccessTests {
    @Test("Unified image quality quick access has an initial tier")
    func unifiedImageQualityQuickAccessHasInitialTier() {
        Self.withIsolatedQualityPreferences {
            let store = Self.store()

            #expect(store.sharedArtworkImageQualityTier == .large)
        }
    }

    @Test("Unified image quality quick access applies one tier to all surfaces")
    func unifiedImageQualityQuickAccessAppliesOneTierToAllSurfaces() {
        Self.withIsolatedQualityPreferences {
            let store = Self.store()

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

    @Test("Settings image quality binding has a default and applies one tier")
    func settingsImageQualityBindingHasDefaultAndAppliesOneTier() {
        Self.withIsolatedQualityPreferences {
            let store = Self.store()
            let binding = store.settings_artworkImageQualityTierBinding

            #expect(binding.wrappedValue == .large)

            binding.wrappedValue = .original

            #expect(store.feedPreviewImageQualityTier == .original)
            #expect(store.illustDetailImageQualityTier == .original)
            #expect(store.mangaDetailImageQualityTier == .original)
        }
    }

    private static func withIsolatedQualityPreferences(_ body: () -> Void) {
        let defaults = UserDefaults.standard
        let previousValues = Dictionary(uniqueKeysWithValues: qualityPreferenceKeys.map { ($0, defaults.object(forKey: $0)) })
        qualityPreferenceKeys.forEach { defaults.removeObject(forKey: $0) }
        defer {
            qualityPreferenceKeys.forEach { key in
                if let value = previousValues[key] ?? nil {
                    defaults.set(value, forKey: key)
                } else {
                    defaults.removeObject(forKey: key)
                }
            }
        }
        body()
    }

    private static func store() -> KeiPixStore {
        KeiPixStore(
            downloads: ArtworkDownloadStore(completionNotifier: DownloadCompletionNotifier(
                center: FakeUserNotificationCenter(isAuthorized: false),
                authorizationStore: InMemoryAuthorizationCacheStore(hasRequested: true),
                coalesceWindowSeconds: 0.05
            )),
            bootstrapsAutomatically: false
        )
    }

    private static let qualityPreferenceKeys = [
        "feedPreviewImageQualityTier",
        "illustDetailImageQualityTier",
        "mangaDetailImageQualityTier",
        "useOriginalImagesInDetail",
        "useOriginalImagesForManga"
    ]
}
