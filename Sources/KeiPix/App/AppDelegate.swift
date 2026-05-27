import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Held for the lifetime of the app so AppKit can keep dispatching
    /// service messages to it. `NSApp.servicesProvider` is a weak-ish
    /// reference in practice — losing the strong handle here means the
    /// Services menu item silently stops working.
    private let servicesProvider = KeiPixServicesProvider()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        // Register the Services menu handler. The Info.plist `NSServices`
        // declaration tells the system which selector to call; this line
        // hands it the live object that implements that selector.
        // `NSUpdateDynamicServices()` re-scans plist-declared services
        // so a change to Info.plist (e.g. during development) is picked
        // up without a logout.
        NSApp.servicesProvider = servicesProvider
        NSUpdateDynamicServices()
    }
}
