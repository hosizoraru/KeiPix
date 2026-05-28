#if os(macOS)
import AppKit
import SwiftUI

/// Touch Bar provider for KeiPix.
///
/// Provides contextual Touch Bar items for the main window and
/// reader windows. Uses NSTouchBar with SwiftUI-compatible items.
@MainActor
final class TouchBarProvider: NSObject, NSTouchBarDelegate {
    private weak var store: KeiPixStore?

    init(store: KeiPixStore) {
        self.store = store
        super.init()
    }

    func createMainTouchBar() -> NSTouchBar {
        let bar = NSTouchBar()
        bar.delegate = self
        bar.defaultItemIdentifiers = [
            .flexibleSpace,
            .init("com.keipix.navigation"),
            .init("com.keipix.bookmark"),
            .init("com.keipix.download"),
            .flexibleSpace
        ]
        return bar
    }

    func createReaderTouchBar() -> NSTouchBar {
        let bar = NSTouchBar()
        bar.delegate = self
        bar.defaultItemIdentifiers = [
            .fixedSpaceLarge,
            .init("com.keipix.navigation"),
            .flexibleSpace,
            .init("com.keipix.bookmark"),
            .init("com.keipix.download"),
            .fixedSpaceLarge
        ]
        return bar
    }

    // MARK: - NSTouchBarDelegate

    func touchBar(_ touchBar: NSTouchBar, makeItemForIdentifier identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        switch identifier.rawValue {
        case "com.keipix.navigation":
            return createNavigationGroup()

        case "com.keipix.nav.back":
            let item = NSButtonTouchBarItem(
                identifier: identifier,
                image: NSImage(systemSymbolName: "chevron.left", accessibilityDescription: L10n.goBack)!,
                target: self,
                action: #selector(navigateBack)
            )
            item.isEnabled = store?.canNavigateBack ?? false
            return item

        case "com.keipix.nav.forward":
            let item = NSButtonTouchBarItem(
                identifier: identifier,
                image: NSImage(systemSymbolName: "chevron.right", accessibilityDescription: L10n.goForward)!,
                target: self,
                action: #selector(navigateForward)
            )
            item.isEnabled = store?.canNavigateForward ?? false
            return item

        case "com.keipix.nav.prev":
            let item = NSButtonTouchBarItem(
                identifier: identifier,
                image: NSImage(systemSymbolName: "arrow.left", accessibilityDescription: L10n.previousArtwork)!,
                target: self,
                action: #selector(previousArtwork)
            )
            return item

        case "com.keipix.nav.next":
            let item = NSButtonTouchBarItem(
                identifier: identifier,
                image: NSImage(systemSymbolName: "arrow.right", accessibilityDescription: L10n.nextArtwork)!,
                target: self,
                action: #selector(nextArtwork)
            )
            return item

        case "com.keipix.bookmark":
            let isBookmarked = store?.selectedArtwork?.isBookmarked ?? false
            let imageName = isBookmarked ? "bookmark.fill" : "bookmark"
            let item = NSButtonTouchBarItem(
                identifier: identifier,
                image: NSImage(systemSymbolName: imageName, accessibilityDescription: L10n.bookmark)!,
                target: self,
                action: #selector(toggleBookmark)
            )
            return item

        case "com.keipix.download":
            let item = NSButtonTouchBarItem(
                identifier: identifier,
                image: NSImage(systemSymbolName: "arrow.down.circle", accessibilityDescription: L10n.download)!,
                target: self,
                action: #selector(downloadArtwork)
            )
            return item

        default:
            return nil
        }
    }

    // MARK: - Navigation group

    private func createNavigationGroup() -> NSGroupTouchBarItem {
        let item = NSGroupTouchBarItem(identifier: .init("com.keipix.navigation"))
        let groupBar = NSTouchBar()
        groupBar.delegate = self
        groupBar.defaultItemIdentifiers = [
            .init("com.keipix.nav.back"),
            .init("com.keipix.nav.forward"),
            .init("com.keipix.nav.prev"),
            .init("com.keipix.nav.next")
        ]
        item.groupTouchBar = groupBar
        return item
    }

    // MARK: - Actions

    @objc private func navigateBack() {
        store?.navigateBack()
    }

    @objc private func navigateForward() {
        store?.navigateForward()
    }

    @objc private func previousArtwork() {
        _ = store?.selectPreviousArtwork()
    }

    @objc private func nextArtwork() {
        _ = store?.selectNextArtwork()
    }

    @objc private func toggleBookmark() {
        guard let store, let artwork = store.selectedArtwork else { return }
        Task { await store.toggleBookmark(artwork) }
    }

    @objc private func downloadArtwork() {
        store?.downloadSelectedArtwork()
    }
}
#endif
