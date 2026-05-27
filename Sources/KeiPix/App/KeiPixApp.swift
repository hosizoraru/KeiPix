import CoreSpotlight
import SwiftUI

@main
struct KeiPixApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings
    @FocusedValue(\.gallerySelectionCommandActions) private var gallerySelectionCommandActions
    @State private var store = KeiPixStore()

    var body: some Scene {
        WindowGroup("KeiPix", id: "main") {
            ContentView(store: store)
                .frame(minWidth: 840, minHeight: 700)
                .background(WindowCaptureProtectionBridge(isProtected: store.isMainWindowCaptureProtected))
                .environment(\.locale, store.appLanguage.locale ?? .current)
                .preferredColorScheme(store.appColorScheme.preferredColorScheme)
                .onOpenURL { url in
                    Task { await store.openPixivLink(url) }
                }
                // Spotlight click handoff. CoreSpotlight posts an
                // activity carrying the entry's unique identifier; we
                // decode the artwork id off it and route into the
                // reader window so the user lands on the artwork they
                // searched for, not just the main app surface.
                .onContinueUserActivity(CSSearchableItemActionType) { activity in
                    if let id = store.artworkIDForSpotlightActivity(activity) {
                        openWindow(id: "artwork-reader", value: id)
                    }
                }
                .onContinueUserActivity(DownloadSpotlightAttributes.activityType) { activity in
                    if let id = store.artworkIDForSpotlightActivity(activity) {
                        openWindow(id: "artwork-reader", value: id)
                    }
                }
                .task {
                    if VisualQALaunchArgument.contains(.settingsWindow)
                        || VisualQALaunchArgument.contains(.runtimeReadiness)
                        || VisualQALaunchArgument.contains(.sharingTemplates) {
                        openSettings()
                    }
                }
                .task {
                    // Run the GitHub release check once per launch — the
                    // store's 24-hour throttle keeps repeat opens from
                    // pummelling the GitHub API. The QA launch arguments
                    // never need a network round-trip, so skip the
                    // check when any visual-QA flag is set.
                    if VisualQALaunchArgument.isActive == false {
                        await store.checkForReleaseUpdateIfDue()
                        store.presentPendingReleaseUpdateIfNeeded()
                    }
                }
        }
        .defaultSize(width: 1280, height: 800)
        .commands {
            CommandGroup(after: .newItem) {
                Button(L10n.refresh) {
                    Task { await store.reloadCurrentFeed() }
                }
                .shortcut(.refreshFeed)

                Divider()

                Button(store.privacyModeEnabled ? L10n.disablePrivacyMode : L10n.enablePrivacyMode) {
                    store.setPrivacyModeEnabled(!store.privacyModeEnabled)
                }
                .shortcut(.togglePrivacyMode)

                Button(L10n.openPixivLinkFromClipboard) {
                    Task { await store.openPixivLinkFromClipboard() }
                }
                .shortcut(.openPixivLinkFromClipboard)

                Button(L10n.searchLocalImageSource) {
                    store.presentLocalImageSourceSearch()
                }
                .shortcut(.searchLocalImageSource)

                Button(L10n.copyDiagnostics) {
                    store.copyRuntimeReadinessDiagnostics()
                }
                .shortcut(.copyDiagnostics)
            }

            CommandMenu(L10n.artwork) {
                Button(L10n.previousArtwork) {
                    store.selectPreviousArtwork()
                }
                .shortcut(.previousArtwork)
                .disabled(store.selectedArtwork == nil)

                Button(L10n.nextArtwork) {
                    store.selectNextArtwork()
                }
                .shortcut(.nextArtwork)
                .disabled(store.selectedArtwork == nil)

                Divider()

                Button(store.selectedArtwork?.isBookmarked == true ? L10n.removeBookmark : L10n.bookmark) {
                    Task { await store.toggleSelectedBookmark() }
                }
                .shortcut(.toggleBookmark)
                .disabled(store.selectedArtwork == nil)

                Button(L10n.download) {
                    store.downloadSelectedArtwork()
                }
                .shortcut(.downloadArtwork)
                .disabled(store.selectedArtwork == nil)

                Button(L10n.searchImageSource) {
                    if let artwork = store.selectedArtwork {
                        store.presentImageSourceSearch(for: artwork)
                    }
                }
                .shortcut(.searchImageSource)
                .disabled(store.selectedArtwork == nil)

                Divider()

                Button(L10n.openCreatorProfile) {
                    store.presentSelectedArtworkCreatorProfile()
                }
                .shortcut(.openCreatorProfile)
                .disabled(store.selectedArtwork == nil)

                Button(L10n.creatorIllustrations) {
                    Task { await store.openSelectedArtworkCreatorFeed(.userIllustrations) }
                }
                .shortcut(.creatorIllustrations)
                .disabled(store.selectedArtwork == nil)

                Button(L10n.creatorManga) {
                    Task { await store.openSelectedArtworkCreatorFeed(.userManga) }
                }
                .shortcut(.creatorManga)
                .disabled(store.selectedArtwork == nil)

                Divider()

                Button(L10n.openReaderWindow) {
                    if let artwork = store.selectedArtwork {
                        store.prepareReaderWindow(for: artwork)
                        openWindow(id: "artwork-reader", value: artwork.id)
                    }
                }
                .shortcut(.openReaderWindow)
                .disabled(store.selectedArtwork == nil)

                Divider()

                Button(L10n.openInPixiv) {
                    store.openSelectedArtworkInPixiv()
                }
                .shortcut(.openInPixiv)
                .disabled(store.selectedArtwork?.pixivURL == nil)

                Button(L10n.copyLink) {
                    store.copySelectedArtworkLink()
                }
                .shortcut(.copyArtworkLink)
                .disabled(store.selectedArtwork?.pixivURL == nil)

                Divider()

                Button(L10n.selectAll) {
                    gallerySelectionCommandActions?.selectAllVisible()
                }
                .shortcut(.selectAll)
                .disabled(gallerySelectionCommandActions?.canSelectAll != true)

                Button(L10n.clearSelection) {
                    gallerySelectionCommandActions?.clearSelection()
                }
                .shortcut(.clearSelection)
                .disabled(gallerySelectionCommandActions?.canClear != true)

                Button(L10n.copySelectedArtworkLinks) {
                    gallerySelectionCommandActions?.copySelectedLinks()
                }
                .shortcut(.copySelectedLinks)
                .disabled(gallerySelectionCommandActions?.canCopyLinks != true)

                Button(L10n.batchDownload) {
                    gallerySelectionCommandActions?.downloadSelected()
                }
                .disabled(gallerySelectionCommandActions?.canDownload != true)

                Button(L10n.batchBookmarkSelected) {
                    gallerySelectionCommandActions?.batchBookmarkSelected()
                }
                .disabled(gallerySelectionCommandActions?.canBatchBookmark != true)
            }

            CommandMenu(L10n.downloads) {
                Button(L10n.openDownloads) {
                    openWindow(id: "main")
                    store.select(.downloads)
                }
                .shortcut(.openDownloads)

                Button(L10n.batchDownloadLoadedArtworks) {
                    let queuedCount = store.enqueueDownloads(
                        store.artworks,
                        limit: min(max(store.artworks.count, 1), 100),
                        preferOriginal: true
                    )
                    if queuedCount > 0 {
                        openWindow(id: "main")
                        store.select(.downloads)
                    }
                }
                .shortcut(.batchDownloadLoadedArtworks)
                .disabled(store.selectedRoute.usesArtworkFeed == false || store.artworks.isEmpty)

                Divider()

                Button(store.downloads.isPaused ? L10n.resumeDownloads : L10n.pauseDownloads) {
                    if store.downloads.isPaused {
                        _ = store.downloads.resumeQueue()
                    } else {
                        _ = store.downloads.pauseQueue()
                    }
                }
                .shortcut(.togglePauseDownloads)
                .disabled(store.downloads.isPaused ? store.downloads.hasQueuedItems == false : store.downloads.activeCount == 0)

                Button(L10n.openFolder) {
                    _ = store.downloads.openDownloadDirectory()
                }
                .shortcut(.openDownloadFolder)
            }

            // Replace macOS' default "About KeiPix" menu item — the bare
            // `orderFrontStandardAboutPanel` only shows the bundle's short
            // version string, so we route to the custom AboutView scene
            // that surfaces version/build, the repo link, reference-project
            // attribution, locale list, and license context users expect
            // from a Mac app.
            CommandGroup(replacing: .appInfo) {
                Button(L10n.aboutKeiPix) {
                    openWindow(id: "about")
                }

                // Manual entry mirrors macOS App Store / Sparkle's
                // "Check for Updates…" — bypasses the 24-hour throttle
                // so a user who just hit "Skip This Version" can still
                // re-trigger the prompt without waiting a day.
                Button(store.isCheckingForUpdates ? L10n.checkingForUpdates : L10n.checkForUpdates) {
                    Task { await store.checkForReleaseUpdateNow() }
                }
                .disabled(store.isCheckingForUpdates)
            }
        }

        Window(L10n.aboutKeiPix, id: "about") {
            AboutView()
                .environment(\.locale, store.appLanguage.locale ?? .current)
                .preferredColorScheme(store.appColorScheme.preferredColorScheme)
        }
        .windowResizability(.contentSize)
        .restorationBehavior(.disabled)

        // In-app log tail backed by `OSLogStore`. Surfaced as a dedicated
        // window scene so users can keep it visible alongside the main
        // window while reproducing an issue, and so the menu command can
        // route to it via `openWindow`. Restoration is disabled — the
        // viewer reads from the current process scope and isn't useful
        // after a relaunch.
        Window(L10n.logs, id: "logs") {
            LogViewerView()
                .environment(\.locale, store.appLanguage.locale ?? .current)
                .preferredColorScheme(store.appColorScheme.preferredColorScheme)
        }
        .defaultSize(width: 880, height: 560)
        .restorationBehavior(.disabled)

        // Reader windows are scene-per-artwork, keyed by the artwork
        // ID. Using a value-typed WindowGroup gives Stage Manager and
        // Mission Control independent surfaces to arrange, lets users
        // open multiple artworks side-by-side without one closing the
        // other, and lets SwiftUI restore the open set after relaunch
        // automatically — the IDs round-trip through the system's
        // scene restoration store. Inside the window the view falls
        // back to a network fetch when the in-memory registry doesn't
        // have a hit (the path post-restoration windows take).
        WindowGroup(L10n.readerWindow, id: "artwork-reader", for: Int.self) { $artworkID in
            if let artworkID {
                ArtworkReaderWindowView(store: store, artworkID: artworkID)
                    .frame(minWidth: 900, minHeight: 680)
                    .background(WindowCaptureProtectionBridge(isProtected: store.isReaderWindowCaptureProtected))
                    .environment(\.locale, store.appLanguage.locale ?? .current)
                    .preferredColorScheme(store.appColorScheme.preferredColorScheme)
            } else {
                EmptyStateView(
                    title: L10n.noArtworkTitle,
                    subtitle: L10n.noArtworkSubtitle,
                    systemImage: "rectangle.inset.filled"
                )
                .frame(minWidth: 900, minHeight: 680)
                .environment(\.locale, store.appLanguage.locale ?? .current)
                .preferredColorScheme(store.appColorScheme.preferredColorScheme)
            }
        }
        .defaultSize(width: 1180, height: 860)

        Settings {
            SettingsView(store: store)
                .environment(\.locale, store.appLanguage.locale ?? .current)
                .preferredColorScheme(store.appColorScheme.preferredColorScheme)
        }
    }
}
