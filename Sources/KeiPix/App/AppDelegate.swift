#if os(macOS)
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

    /// AppKit calls this when the user right-clicks (or long-presses)
    /// the dock tile. Returning a menu adds rows above the system's
    /// default open-windows list. Apple's HIG asks for "a few useful
    /// shortcuts" rather than a full duplicate of the menu bar, so we
    /// surface the same affordances users hit Cmd+R / Cmd+Shift+V for
    /// from the menu bar — backgrounded users can drive a refresh or
    /// paste a link without bringing the window forward first.
    @MainActor
    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        let snapshot = currentDockMenuSnapshot()
        let rows = KeiPixDockMenuBuilder.rows(from: snapshot)
        let menu = NSMenu()
        menu.autoenablesItems = false
        for row in rows {
            switch row {
            case .separator:
                menu.addItem(.separator())
            case .action(let action):
                let item = NSMenuItem(
                    title: action.title,
                    action: #selector(handleDockMenuAction(_:)),
                    keyEquivalent: ""
                )
                item.target = self
                item.representedObject = action.kind
                item.isEnabled = action.isEnabled
                menu.addItem(item)
            }
        }
        return menu
    }

    /// Sample the live store on the main actor so the dock menu's
    /// labels (Pause vs. Resume) and enable flags reflect what the
    /// user would see in the menu bar. Returns a "store not ready"
    /// snapshot when the locator hasn't been registered yet — the
    /// builder greys every row out in that case.
    @MainActor
    private func currentDockMenuSnapshot() -> DockMenuSnapshot {
        guard let store = KeiPixStoreLocator.shared.store else {
            return DockMenuSnapshot(
                hasStore: false,
                downloadsPaused: false,
                hasQueuedDownloads: false,
                activeDownloadCount: 0
            )
        }
        return DockMenuSnapshot(
            hasStore: true,
            downloadsPaused: store.downloads.isPaused,
            hasQueuedDownloads: store.downloads.hasQueuedItems,
            activeDownloadCount: store.downloads.activeCount
        )
    }

    @MainActor
    @objc private func handleDockMenuAction(_ sender: NSMenuItem) {
        guard let kind = sender.representedObject as? DockMenuAction.Kind else { return }
        guard let store = KeiPixStoreLocator.shared.store else { return }

        // Bring the app forward first. Dock-menu invocations almost
        // always come from a backgrounded state; without this the
        // refresh / clipboard handlers would run silently and the
        // user would have no visible feedback.
        NSApp.activate(ignoringOtherApps: true)

        switch kind {
        case .openClipboardLink:
            Task { await store.openPixivLinkFromClipboard() }
        case .refreshFeed:
            Task { await store.reloadCurrentFeed() }
        case .openDownloads:
            store.select(.downloads)
        case .togglePauseDownloads:
            if store.downloads.isPaused {
                _ = store.downloads.resumeQueue()
            } else {
                _ = store.downloads.pauseQueue()
            }
        case .openDownloadsFolder:
            _ = store.downloads.openDownloadDirectory()
        }
    }
}
#endif
