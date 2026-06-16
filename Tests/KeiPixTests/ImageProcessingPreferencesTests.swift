import Foundation
import Testing
@testable import KeiPix

@MainActor
@Suite("Image processing preferences", .serialized)
struct ImageProcessingPreferencesTests {
    @Test("Enabling image processing seeds a conservative local default")
    func enablingImageProcessingSeedsConservativeLocalDefault() {
        Self.withIsolatedImageProcessingPreferences {
            let store = Self.store()

            #expect(store.imageProcessorsEnabled == false)
            #expect(store.activeImageProcessors == ImageProcessorRegistry.defaultActiveProcessorIdentifiers)

            store.setActiveImageProcessors([])
            store.setImageProcessorsEnabled(true)

            #expect(store.imageProcessorsEnabled == true)
            #expect(store.activeImageProcessors == ImageProcessorRegistry.defaultActiveProcessorIdentifiers)
            #expect(store.activeImageProcessors.contains("smartCrop") == false)
        }
    }

    private static func withIsolatedImageProcessingPreferences(_ body: () -> Void) {
        let defaults = UserDefaults.standard
        let keys = [
            "imageProcessorsEnabled",
            "activeImageProcessors"
        ]
        let previousValues = Dictionary(uniqueKeysWithValues: keys.map { ($0, defaults.object(forKey: $0)) })
        keys.forEach { defaults.removeObject(forKey: $0) }
        defer {
            keys.forEach { key in
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
}
