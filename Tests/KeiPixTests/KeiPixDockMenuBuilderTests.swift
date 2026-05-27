import Foundation
import Testing
@testable import KeiPix

/// Pin the dock menu structure and its dynamic labels. The
/// `applicationDockMenu` binding lives in `AppDelegate` and isn't
/// reachable without an `NSApplication` host, but the builder is
/// a pure function — fixing it here keeps the dock affordances
/// aligned with the menu bar's Pause / Resume Downloads gating
/// without requiring an end-to-end UI run.
@Suite("Dock menu builder")
struct KeiPixDockMenuBuilderTests {

    @Test("Snapshot without a registered store produces a fully disabled menu")
    func storeNotReadyDisablesEverything() {
        let snapshot = DockMenuSnapshot(
            hasStore: false,
            downloadsPaused: false,
            hasQueuedDownloads: true,
            activeDownloadCount: 3
        )
        let rows = KeiPixDockMenuBuilder.rows(from: snapshot)
        let actions = rows.compactMap { row -> DockMenuAction? in
            if case let .action(action) = row { return action }
            return nil
        }
        #expect(actions.isEmpty == false)
        #expect(actions.allSatisfy { $0.isEnabled == false })
    }

    @Test("Live store with queued work toggles to a Pause label")
    func runningQueueShowsPauseLabel() {
        let snapshot = DockMenuSnapshot(
            hasStore: true,
            downloadsPaused: false,
            hasQueuedDownloads: true,
            activeDownloadCount: 2
        )
        let rows = KeiPixDockMenuBuilder.rows(from: snapshot)
        let toggle = rows.firstAction(of: .togglePauseDownloads)
        #expect(toggle?.title == L10n.pauseDownloads)
        #expect(toggle?.isEnabled == true)
    }

    @Test("Paused queue with backlog toggles to a Resume label and stays enabled")
    func pausedWithBacklogShowsResume() {
        let snapshot = DockMenuSnapshot(
            hasStore: true,
            downloadsPaused: true,
            hasQueuedDownloads: true,
            activeDownloadCount: 0
        )
        let rows = KeiPixDockMenuBuilder.rows(from: snapshot)
        let toggle = rows.firstAction(of: .togglePauseDownloads)
        #expect(toggle?.title == L10n.resumeDownloads)
        #expect(toggle?.isEnabled == true)
    }

    @Test("Idle queue greys the toggle out so users don't tap a no-op")
    func idleQueueDisablesToggle() {
        let snapshot = DockMenuSnapshot(
            hasStore: true,
            downloadsPaused: false,
            hasQueuedDownloads: false,
            activeDownloadCount: 0
        )
        let rows = KeiPixDockMenuBuilder.rows(from: snapshot)
        let toggle = rows.firstAction(of: .togglePauseDownloads)
        #expect(toggle?.isEnabled == false)
    }

    @Test("Order matches the menu bar: clipboard, refresh, downloads cluster")
    func rowOrderMatchesMenuBar() {
        let snapshot = DockMenuSnapshot(
            hasStore: true,
            downloadsPaused: false,
            hasQueuedDownloads: false,
            activeDownloadCount: 0
        )
        let rows = KeiPixDockMenuBuilder.rows(from: snapshot)
        let kinds = rows.compactMap { row -> DockMenuAction.Kind? in
            if case let .action(action) = row { return action.kind }
            return nil
        }
        #expect(kinds == [
            .openClipboardLink,
            .refreshFeed,
            .openDownloads,
            .togglePauseDownloads,
            .openDownloadsFolder
        ])
    }

    @Test("A separator divides the open-link cluster from the downloads cluster")
    func separatorBetweenClusters() {
        let snapshot = DockMenuSnapshot(
            hasStore: true,
            downloadsPaused: false,
            hasQueuedDownloads: false,
            activeDownloadCount: 0
        )
        let rows = KeiPixDockMenuBuilder.rows(from: snapshot)
        let separatorIndex = rows.firstIndex { row in
            if case .separator = row { return true }
            return false
        }
        #expect(separatorIndex == 2)
    }

    @Test("Action titles round-trip through L10n so localized builds stay in sync")
    func titlesUseL10n() {
        let snapshot = DockMenuSnapshot(
            hasStore: true,
            downloadsPaused: false,
            hasQueuedDownloads: false,
            activeDownloadCount: 0
        )
        let rows = KeiPixDockMenuBuilder.rows(from: snapshot)
        #expect(rows.firstAction(of: .openClipboardLink)?.title == L10n.openPixivLinkFromClipboard)
        #expect(rows.firstAction(of: .refreshFeed)?.title == L10n.refresh)
        #expect(rows.firstAction(of: .openDownloads)?.title == L10n.openDownloads)
        #expect(rows.firstAction(of: .openDownloadsFolder)?.title == L10n.openFolder)
    }
}

private extension Array where Element == DockMenuRow {
    func firstAction(of kind: DockMenuAction.Kind) -> DockMenuAction? {
        for row in self {
            if case let .action(action) = row, action.kind == kind {
                return action
            }
        }
        return nil
    }
}
