#if os(macOS)
import AppKit
import SwiftUI

/// Touch Bar provider for KeiPix.
///
/// Provides contextual Touch Bar items for the main window,
/// reader windows, and novel reader. Uses NSTouchBar with
/// sliders, progress indicators, and button groups.
@MainActor
final class TouchBarProvider: NSObject, NSTouchBarDelegate {
    private weak var store: KeiPixStore?

    init(store: KeiPixStore) {
        self.store = store
        super.init()
    }

    // MARK: - Touch Bar creators

    func createMainTouchBar() -> NSTouchBar {
        let bar = NSTouchBar()
        bar.delegate = self
        bar.defaultItemIdentifiers = [
            .flexibleSpace,
            .init("com.keipix.navigation"),
            .init("com.keipix.bookmark"),
            .init("com.keipix.download"),
            .init("com.keipix.downloadProgress"),
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

    func createNovelReaderTouchBar() -> NSTouchBar {
        let bar = NSTouchBar()
        bar.delegate = self
        bar.defaultItemIdentifiers = [
            .fixedSpaceLarge,
            .init("com.keipix.novel.textSize"),
            .init("com.keipix.novel.lineSpacing"),
            .flexibleSpace,
            .init("com.keipix.novel.theme"),
            .fixedSpaceLarge
        ]
        return bar
    }

    // MARK: - NSTouchBarDelegate

    func touchBar(_ touchBar: NSTouchBar, makeItemForIdentifier identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        switch identifier.rawValue {
        // Navigation
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

        // Bookmark
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

        // Download
        case "com.keipix.download":
            let item = NSButtonTouchBarItem(
                identifier: identifier,
                image: NSImage(systemSymbolName: "arrow.down.circle", accessibilityDescription: L10n.download)!,
                target: self,
                action: #selector(downloadArtwork)
            )
            return item

        // Download progress
        case "com.keipix.downloadProgress":
            return createDownloadProgressItem()

        // Novel reader controls
        case "com.keipix.novel.textSize":
            return createTextSizeSlider()

        case "com.keipix.novel.lineSpacing":
            return createLineSpacingSlider()

        case "com.keipix.novel.theme":
            return createThemePicker()

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

    // MARK: - Download progress

    private func createDownloadProgressItem() -> NSTouchBarItem? {
        guard let store else { return nil }
        let activeCount = store.downloads.activeCount
        guard activeCount > 0 else { return nil }

        let item = NSCustomTouchBarItem(identifier: .init("com.keipix.downloadProgress"))
        let label = NSTextField(labelWithString: "↓ \(activeCount)")
        label.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        item.view = label
        return item
    }

    // MARK: - Novel reader controls

    private func createTextSizeSlider() -> NSSliderTouchBarItem {
        let item = NSSliderTouchBarItem(identifier: .init("com.keipix.novel.textSize"))
        item.label = L10n.novelReaderTextSize
        item.slider.minValue = 12
        item.slider.maxValue = 28
        item.slider.doubleValue = 17
        item.target = self
        item.action = #selector(textSizeChanged(_:))
        return item
    }

    private func createLineSpacingSlider() -> NSSliderTouchBarItem {
        let item = NSSliderTouchBarItem(identifier: .init("com.keipix.novel.lineSpacing"))
        item.label = L10n.novelReaderLineSpacing
        item.slider.minValue = 0
        item.slider.maxValue = 16
        item.slider.doubleValue = 6
        item.target = self
        item.action = #selector(lineSpacingChanged(_:))
        return item
    }

    private func createThemePicker() -> NSTouchBarItem {
        let item = NSCustomTouchBarItem(identifier: .init("com.keipix.novel.theme"))
        let button = NSButton(title: "Theme", target: self, action: #selector(themeChanged(_:)))
        button.bezelStyle = .recessed
        item.view = button
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

    @objc private func textSizeChanged(_ sender: NSSliderTouchBarItem) {
        UserDefaults.standard.set(sender.slider.doubleValue, forKey: "novelReader.textSize")
    }

    @objc private func lineSpacingChanged(_ sender: NSSliderTouchBarItem) {
        UserDefaults.standard.set(sender.slider.doubleValue, forKey: "novelReader.lineSpacing")
    }

    @objc private func themeChanged(_ sender: NSButton) {
        // Cycle through themes
        let themes = NovelReaderTheme.allCases
        let current = UserDefaults.standard.string(forKey: "novelReader.theme").flatMap(NovelReaderTheme.init) ?? .light
        let nextIndex = (themes.firstIndex(of: current) ?? 0) + 1
        let next = themes[nextIndex % themes.count]
        UserDefaults.standard.set(next.rawValue, forKey: "novelReader.theme")
    }
}
#endif
