import SwiftUI

@main
struct KeiPixApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.openWindow) private var openWindow
    @State private var store = KeiPixStore()

    var body: some Scene {
        WindowGroup("KeiPix", id: "main") {
            ContentView(store: store)
                .frame(minWidth: 840, minHeight: 700)
                .background(WindowCaptureProtectionBridge(isProtected: store.isMainWindowCaptureProtected))
                .environment(\.locale, store.appLanguage.locale ?? .current)
                .onOpenURL { url in
                    Task { await store.openPixivLink(url) }
                }
        }
        .defaultSize(width: 1180, height: 800)
        .commands {
            CommandGroup(after: .newItem) {
                Button(L10n.refresh) {
                    Task { await store.reloadCurrentFeed() }
                }
                .keyboardShortcut("r", modifiers: .command)

                Divider()

                Button(store.privacyModeEnabled ? L10n.disablePrivacyMode : L10n.enablePrivacyMode) {
                    store.setPrivacyModeEnabled(!store.privacyModeEnabled)
                }
                .keyboardShortcut("p", modifiers: [.command, .shift])

                Button(L10n.openPixivLinkFromClipboard) {
                    Task { await store.openPixivLinkFromClipboard() }
                }
                .keyboardShortcut("l", modifiers: [.command, .shift])
            }

            CommandMenu(L10n.artwork) {
                Button(L10n.previousArtwork) {
                    store.selectPreviousArtwork()
                }
                .keyboardShortcut(.leftArrow, modifiers: [.command])
                .disabled(store.selectedArtwork == nil)

                Button(L10n.nextArtwork) {
                    store.selectNextArtwork()
                }
                .keyboardShortcut(.rightArrow, modifiers: [.command])
                .disabled(store.selectedArtwork == nil)

                Divider()

                Button(store.selectedArtwork?.isBookmarked == true ? L10n.removeBookmark : L10n.bookmark) {
                    Task { await store.toggleSelectedBookmark() }
                }
                .keyboardShortcut("b", modifiers: [.command])
                .disabled(store.selectedArtwork == nil)

                Button(L10n.download) {
                    store.downloadSelectedArtwork()
                }
                .keyboardShortcut("d", modifiers: [.command, .shift])
                .disabled(store.selectedArtwork == nil)

                Button(L10n.searchImageSource) {
                    if let artwork = store.selectedArtwork {
                        store.presentImageSourceSearch(for: artwork)
                    }
                }
                .keyboardShortcut("s", modifiers: [.command, .option])
                .disabled(store.selectedArtwork == nil)

                Divider()

                Button(L10n.openReaderWindow) {
                    store.prepareSelectedReaderWindow()
                    openWindow(id: "artwork-reader")
                }
                .keyboardShortcut(.return, modifiers: [.command])
                .disabled(store.selectedArtwork == nil)

                Divider()

                Button(L10n.openInPixiv) {
                    store.openSelectedArtworkInPixiv()
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])
                .disabled(store.selectedArtwork?.pixivURL == nil)

                Button(L10n.copyLink) {
                    store.copySelectedArtworkLink()
                }
                .keyboardShortcut("c", modifiers: [.command, .shift])
                .disabled(store.selectedArtwork?.pixivURL == nil)
            }
        }

        Window(L10n.readerWindow, id: "artwork-reader") {
            ArtworkReaderWindowView(store: store)
                .frame(minWidth: 900, minHeight: 680)
                .background(WindowCaptureProtectionBridge(isProtected: store.isReaderWindowCaptureProtected))
                .environment(\.locale, store.appLanguage.locale ?? .current)
        }
        .defaultSize(width: 1180, height: 860)
        .restorationBehavior(.disabled)

        Settings {
            SettingsView(store: store)
                .environment(\.locale, store.appLanguage.locale ?? .current)
        }
    }
}
