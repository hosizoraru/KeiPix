import CoreSpotlight
import SwiftUI

@main
struct KeiPixApp: App {
    #if os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    #endif
    @Environment(\.openWindow) private var openWindow
    #if os(macOS)
    @Environment(\.openSettings) private var openSettings
    #endif
    @FocusedValue(\.gallerySelectionCommandActions) private var gallerySelectionCommandActions
    @State private var store = KeiPixStore()

    var body: some Scene {
        WindowGroup("KeiPix", id: "main") {
            ContentView(store: store)
                #if os(macOS)
                .frame(
                    minWidth: MainWindowSizing.minimumWidth(sidebarVisible: true),
                    minHeight: MainWindowSizing.minimumHeight
                )
                .background(WindowCaptureProtectionBridge(isProtected: store.isMainWindowCaptureProtected))
                #endif
                .environment(\.locale, store.appLanguage.locale ?? .current)
                .preferredColorScheme(store.appColorScheme.preferredColorScheme)
                .onAppear {
                    KeiPixStoreLocator.shared.register(store: store)
                    KeiPixStoreLocator.shared.registerOpenWindowHandler { artworkID in
                        openWindow(id: "artwork-reader", value: artworkID)
                    }
                }
                .onOpenURL { url in
                    Task { await store.openPixivLink(url) }
                }
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
                .onContinueUserActivity(HandoffManager.activityType) { activity in
                    if let state = HandoffManager.restoreState(from: activity) {
                        if let artworkID = state.artworkID {
                            openWindow(id: "artwork-reader", value: artworkID)
                        }
                    }
                }
                #if os(macOS)
                .task {
                    if VisualQALaunchArgument.contains(.settingsWindow)
                        || VisualQALaunchArgument.contains(.runtimeReadiness)
                        || VisualQALaunchArgument.contains(.sharingTemplates) {
                        openSettings()
                    }
                }
                #endif
                .task {
                    if VisualQALaunchArgument.isActive == false {
                        await store.checkForReleaseUpdateIfDue()
                        store.presentPendingReleaseUpdateIfNeeded()
                    }
                }
                .task {
                    // Check for pending links from Share Extension
                    if let url = ShareExtensionHandler.consumePendingLink() {
                        await store.openPixivLink(url)
                    }
                }
                #if os(iOS)
                .task {
                    BackgroundFetchScheduler.register()
                    BackgroundFetchScheduler.scheduleNextRefresh()
                }
                #endif
        }
        #if os(macOS)
        .defaultSize(width: MainWindowSizing.defaultSize.width, height: MainWindowSizing.defaultSize.height)
        .commands {
            macCommands
        }
        #endif

        #if os(macOS)
        Window(L10n.aboutKeiPix, id: "about") {
            AboutView(presentation: .window)
                .environment(\.locale, store.appLanguage.locale ?? .current)
                .preferredColorScheme(store.appColorScheme.preferredColorScheme)
        }
        .windowResizability(.contentSize)
        .restorationBehavior(.disabled)

        Window(L10n.logs, id: "logs") {
            LogViewerView()
                .environment(\.locale, store.appLanguage.locale ?? .current)
                .preferredColorScheme(store.appColorScheme.preferredColorScheme)
        }
        .defaultSize(width: 880, height: 560)
        .restorationBehavior(.disabled)

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
        .defaultSize(width: 1400, height: 900)

        Settings {
            SettingsView(store: store)
                .environment(\.locale, store.appLanguage.locale ?? .current)
                .preferredColorScheme(store.appColorScheme.preferredColorScheme)
        }

        MenuBarExtra {
            MenuBarExtraView(store: store)
                .environment(\.locale, store.appLanguage.locale ?? .current)
        } label: {
            Image(systemName: "photo.on.rectangle.angled")
        }
        #endif
    }

    #if os(macOS)
    @CommandsBuilder
    private var macCommands: some Commands {
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
            Button(L10n.goBack) {
                store.navigateBack()
            }
            .shortcut(.navigateBack)
            .disabled(store.canNavigateBack == false)

            Button(L10n.goForward) {
                store.navigateForward()
            }
            .shortcut(.navigateForward)
            .disabled(store.canNavigateForward == false)

            Divider()

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

        CommandGroup(replacing: .appInfo) {
            Button(L10n.aboutKeiPix) {
                openWindow(id: "about")
            }

            Button(store.isCheckingForUpdates ? L10n.checkingForUpdates : L10n.checkForUpdates) {
                Task { await store.checkForReleaseUpdateNow() }
            }
            .disabled(store.isCheckingForUpdates)
        }
    }
    #endif
}
