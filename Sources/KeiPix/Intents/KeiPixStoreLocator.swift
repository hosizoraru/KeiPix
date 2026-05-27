import Foundation

/// Bridges AppIntents (which run outside the main `App` hierarchy)
/// to the running `KeiPixStore`. The intent surface needs to call
/// store methods like `openPixivLink(_:)` and `reloadCurrentFeed()`,
/// but `KeiPixStore` is `@MainActor @Observable` and held inside
/// `KeiPixApp` as `@State`. The locator gives intents a stable
/// hand-off point that the app registers on launch.
///
/// We keep this deliberately small — store reference plus a window
/// opener — so the intents stay declarative and the cross-actor
/// hops live in one place.
@MainActor
final class KeiPixStoreLocator {
    static let shared = KeiPixStoreLocator()

    private(set) weak var store: KeiPixStore?
    private var openWindowHandler: ((Int) -> Void)?

    private init() {}

    func register(store: KeiPixStore) {
        self.store = store
    }

    /// Wires the SwiftUI `openWindow` environment value through to
    /// the locator so intents that need to bring up the reader can
    /// trigger it without a direct dependency on the SwiftUI scene
    /// graph. Stored as a closure rather than the `OpenWindowAction`
    /// type so the locator stays usable in tests that don't have a
    /// live SwiftUI environment.
    func registerOpenWindowHandler(_ handler: @escaping (Int) -> Void) {
        self.openWindowHandler = handler
    }

    func openReaderWindow(artworkID: Int) {
        openWindowHandler?(artworkID)
    }
}
