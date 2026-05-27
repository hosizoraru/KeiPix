import AppKit
import Foundation

/// Pure description of one row in the Dock-icon contextual menu.
/// Holding the menu structure as values (rather than building
/// `NSMenuItem`s directly) lets unit tests pin labels, ordering,
/// and enable/disable logic without spinning up AppKit. The
/// `AppDelegate` walks this snapshot when AppKit asks for a menu
/// and converts each row into a real `NSMenuItem`.
enum DockMenuRow: Equatable {
    case action(DockMenuAction)
    case separator
}

/// Concrete dock menu actions. Each case carries a localized title
/// and an `isEnabled` flag so the snapshot is fully self-contained
/// — the binding layer in `AppDelegate` doesn't have to re-derive
/// state from the store, which keeps the AppKit code declarative.
struct DockMenuAction: Equatable {
    enum Kind: Equatable {
        case openClipboardLink
        case refreshFeed
        case openDownloads
        case togglePauseDownloads
        case openDownloadsFolder
    }

    let kind: Kind
    let title: String
    let isEnabled: Bool
}

/// Snapshot of the bits of store state the dock menu needs. Keeping
/// it a plain struct means callers (production + tests) hand the
/// builder a value rather than a live actor reference, and the
/// builder stays a pure function we can exercise without spinning
/// up `KeiPixStore`.
struct DockMenuSnapshot: Equatable {
    var hasStore: Bool
    var downloadsPaused: Bool
    var hasQueuedDownloads: Bool
    var activeDownloadCount: Int
}

/// Builds the dock menu rows from a snapshot. Apple's HIG calls out
/// dock menus as "shortcuts to commonly-used commands"; we mirror
/// the items already available in the menu bar so the surface stays
/// predictable, and rely on AppKit to append the open-windows list
/// automatically below whatever we return.
enum KeiPixDockMenuBuilder {
    static func rows(from snapshot: DockMenuSnapshot) -> [DockMenuRow] {
        // When the store hasn't registered yet (very early launch,
        // or running headless in a test host), the dock menu would
        // dispatch into a nil locator — avoid that by greying every
        // action out instead of dropping the menu entirely. The
        // structure stays stable so users see what's coming once
        // the app finishes launching.
        let storeReady = snapshot.hasStore

        let pauseToggleEnabled: Bool = {
            guard storeReady else { return false }
            // Pausing only makes sense when something is in flight;
            // resuming only makes sense when there's queued work.
            // Mirrors the Downloads menu's gating in `KeiPixApp`.
            if snapshot.downloadsPaused {
                return snapshot.hasQueuedDownloads
            }
            return snapshot.activeDownloadCount > 0
        }()

        let pauseTitle = snapshot.downloadsPaused
            ? L10n.resumeDownloads
            : L10n.pauseDownloads

        return [
            .action(DockMenuAction(
                kind: .openClipboardLink,
                title: L10n.openPixivLinkFromClipboard,
                isEnabled: storeReady
            )),
            .action(DockMenuAction(
                kind: .refreshFeed,
                title: L10n.refresh,
                isEnabled: storeReady
            )),
            .separator,
            .action(DockMenuAction(
                kind: .openDownloads,
                title: L10n.openDownloads,
                isEnabled: storeReady
            )),
            .action(DockMenuAction(
                kind: .togglePauseDownloads,
                title: pauseTitle,
                isEnabled: pauseToggleEnabled
            )),
            .action(DockMenuAction(
                kind: .openDownloadsFolder,
                title: L10n.openFolder,
                isEnabled: storeReady
            ))
        ]
    }
}
