import Foundation
import Testing
@testable import KeiPix

@MainActor
@Suite("Chrome material mode", .serialized)
struct ChromeMaterialModeTests {
    @Test("Chrome material defaults to full Liquid Glass")
    func chromeMaterialDefaultsToLiquidGlass() {
        Self.withIsolatedChromeMaterialPreference {
            let store = Self.store()

            #expect(store.chromeMaterialMode == .liquidGlass)
        }
    }

    @Test("Chrome material binding persists the selected performance tier")
    func chromeMaterialBindingPersistsSelectedTier() {
        Self.withIsolatedChromeMaterialPreference {
            let store = Self.store()
            let binding = store.settings_chromeMaterialModeBinding

            #expect(binding.wrappedValue == .liquidGlass)

            binding.wrappedValue = .translucentBlur

            #expect(store.chromeMaterialMode == .translucentBlur)
            #expect(UserDefaults.standard.string(forKey: "chromeMaterialMode") == ChromeMaterialMode.translucentBlur.rawValue)
        }
    }

    private static func withIsolatedChromeMaterialPreference(_ body: () -> Void) {
        let defaults = UserDefaults.standard
        let previousValue = defaults.object(forKey: "chromeMaterialMode")
        defaults.removeObject(forKey: "chromeMaterialMode")
        defer {
            if let previousValue {
                defaults.set(previousValue, forKey: "chromeMaterialMode")
            } else {
                defaults.removeObject(forKey: "chromeMaterialMode")
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
