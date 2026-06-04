import Foundation
import Testing

struct NativeBoundaryTests {
    @Test("Package stays on the native macOS SwiftPM route")
    func packageStaysNativeMacOSSwiftPM() throws {
        let root = try packageRoot()
        let package = try String(contentsOf: root.appending(path: "Package.swift"), encoding: .utf8)

        #expect(package.contains("swift-tools-version: 6.2"))
        #expect(package.contains(".macOS(.v26)"))
        #expect(package.contains(".executableTarget("))
        #expect(package.contains("name: \"KeiPix\""))
        #expect(package.contains(".package(") == false)
    }

    @Test("KeiPix sources do not vendor reference-client implementation paths")
    func sourcesDoNotVendorReferenceClientImplementationPaths() throws {
        let root = try packageRoot()
        let sourceRoot = root.appending(path: "Sources/KeiPix", directoryHint: .isDirectory)
        let files = try sourceFiles(in: sourceRoot)
        let forbiddenExtensions: Set<String> = [
            "dart",
            "gradle",
            "java",
            "kt",
            "kts"
        ]
        let forbiddenTerms = [
            "import Flutter",
            "package:flutter",
            "flutter_bloc",
            "Widget build(",
            "@Composable",
            "Jetpack Compose",
            "kotlinx.coroutines"
        ]

        let forbiddenFiles = files.filter { forbiddenExtensions.contains($0.pathExtension.lowercased()) }
        #expect(forbiddenFiles.isEmpty)

        let textFiles = files.filter { ["swift", "strings"].contains($0.pathExtension.lowercased()) }
        for file in textFiles {
            let text = try String(contentsOf: file, encoding: .utf8)
            let matches = forbiddenTerms.filter { text.contains($0) }
            #expect(matches.isEmpty, "\(file.path(percentEncoded: false)) contains \(matches.joined(separator: ", "))")
        }
    }

    @Test("Native bridge boundaries stay explicit")
    func nativeBridgeBoundariesStayExplicit() throws {
        let root = try packageRoot()
        let viewRoot = root.appending(path: "Sources/KeiPix/Views", directoryHint: .isDirectory)
        let supportRoot = root.appending(path: "Sources/KeiPix/Support", directoryHint: .isDirectory)
        let viewFiles = try sourceFiles(in: viewRoot).filter { $0.pathExtension == "swift" }
        let appKitBridgeFiles = try sourceFiles(in: supportRoot).filter {
            $0.lastPathComponent.contains("Bridge") && $0.pathExtension == "swift"
        }

        #expect(viewFiles.isEmpty == false)
        for file in viewFiles {
            let text = try String(contentsOf: file, encoding: .utf8)
            let declaresSwiftUIView = text.contains(": View")
                || text.contains("some View")
                || text.contains("@ViewBuilder")
            if declaresSwiftUIView {
                #expect(text.contains("import SwiftUI"), "\(file.lastPathComponent) should import SwiftUI")
            }
        }

        #expect(appKitBridgeFiles.contains { $0.lastPathComponent == "TrackpadEventBridge.swift" })
        #expect(appKitBridgeFiles.contains { $0.lastPathComponent == "WindowCaptureProtectionBridge.swift" })
    }

    @Test("iPad root content does not inherit macOS window sizing")
    func iPadRootContentDoesNotInheritMacOSWindowSizing() throws {
        let root = try packageRoot()
        let app = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/App/KeiPixApp.swift"),
            encoding: .utf8
        )

        #expect(app.contains("MainWindowSizing.minimumWidth("))
        #expect(app.contains("MainWindowSizing.minimumHeight"))
        #expect(app.contains(".defaultSize(width: MainWindowSizing.defaultSize.width, height: MainWindowSizing.defaultSize.height)"))
        #expect(app.contains("ContentView(store: store)\n                .frame(minWidth: MainWindowSizing") == false)
    }

    @Test("XcodeGen declares a first-class iPadOS app target")
    func xcodeGenDeclaresFirstClassiPadOSTarget() throws {
        let root = try packageRoot()
        let project = try String(
            contentsOf: root.appending(path: "project.yml"),
            encoding: .utf8
        )
        let plist = try String(
            contentsOf: root.appending(path: "App/Info-iPadOS.plist"),
            encoding: .utf8
        )
        let shortcuts = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Intents/KeiPixShortcuts.swift"),
            encoding: .utf8
        )

        #expect(project.contains("iOS: \"26.0\""))
        #expect(project.contains("KeiPixiPad:"))
        #expect(project.contains("platform: iOS"))
        #expect(project.contains("INFOPLIST_FILE: App/Info-iPadOS.plist"))
        #expect(project.contains("TARGETED_DEVICE_FAMILY: \"2\""))
        #expect(project.contains("KeiPix iPadOS:"))
        #expect(plist.contains("<key>LSRequiresIPhoneOS</key>"))
        #expect(plist.contains("<key>UIDeviceFamily</key>") == false)
        #expect(plist.contains("<key>BGTaskSchedulerPermittedIdentifiers</key>"))
        #expect(plist.contains("<string>com.keipix.feed-refresh</string>"))
        #expect(shortcuts.contains(#"\(\.$link)"#) == false)
        #expect(shortcuts.contains(#"\(\.$artwork)"#) == false)
    }

    @Test("XcodeGen declares a first-class iOS app target")
    func xcodeGenDeclaresFirstClassiOSTarget() throws {
        let root = try packageRoot()
        let project = try String(
            contentsOf: root.appending(path: "project.yml"),
            encoding: .utf8
        )
        let plist = try String(
            contentsOf: root.appending(path: "App/Info-iOS.plist"),
            encoding: .utf8
        )

        #expect(project.contains("KeiPixiOS:"))
        #expect(project.contains("PRODUCT_BUNDLE_IDENTIFIER: com.keipix.client.ios"))
        #expect(project.contains("INFOPLIST_FILE: App/Info-iOS.plist"))
        #expect(project.contains("TARGETED_DEVICE_FAMILY: \"1\""))
        #expect(project.contains("KeiPix iOS:"))
        #expect(plist.contains("<key>LSRequiresIPhoneOS</key>"))
        #expect(plist.contains("<key>UIDeviceFamily</key>") == false)
        #expect(plist.contains("<key>UISupportedInterfaceOrientations</key>"))
        #expect(plist.contains("<key>UISupportedInterfaceOrientations~ipad</key>") == false)
        #expect(plist.contains("<string>UIInterfaceOrientationPortrait</string>"))
        #expect(plist.contains("<string>UIInterfaceOrientationLandscapeLeft</string>"))
        #expect(plist.contains("<string>UIInterfaceOrientationLandscapeRight</string>"))
    }

    @Test("Simulator run scripts cover iOS and iPadOS schemes")
    func simulatorRunScriptsCoverMobileSchemes() throws {
        let root = try packageRoot()
        let runnerURL = root.appending(path: "script/build_and_run_simulator.sh")
        let iOSURL = root.appending(path: "script/build_and_run_ios.sh")
        let iPadOSURL = root.appending(path: "script/build_and_run_ipados.sh")
        let runner = try String(contentsOf: runnerURL, encoding: .utf8)
        let iOSWrapper = try String(contentsOf: iOSURL, encoding: .utf8)
        let iPadOSWrapper = try String(contentsOf: iPadOSURL, encoding: .utf8)

        #expect(FileManager.default.fileExists(atPath: runnerURL.path(percentEncoded: false)))
        #expect(FileManager.default.fileExists(atPath: iOSURL.path(percentEncoded: false)))
        #expect(FileManager.default.fileExists(atPath: iPadOSURL.path(percentEncoded: false)))
        #expect(runner.contains("KeiPix iOS"))
        #expect(runner.contains("KeiPix iPadOS"))
        #expect(runner.contains("com.keipix.client.ios"))
        #expect(runner.contains("com.keipix.client.ipad"))
        #expect(runner.contains("xcodegen generate"))
        #expect(runner.contains("-destination \"platform=iOS Simulator,id=$SIMULATOR_ID\""))
        #expect(runner.contains("xcrun simctl install \"$SIMULATOR_ID\""))
        #expect(runner.contains("xcrun simctl launch --terminate-running-process \"$SIMULATOR_ID\" \"$BUNDLE_ID\""))
        #expect(runner.contains("KEIPIX_IOS_SIMULATOR_ID"))
        #expect(runner.contains("KEIPIX_IPADOS_SIMULATOR_ID"))
        #expect(iOSWrapper.contains("build_and_run_simulator.sh\" ios"))
        #expect(iPadOSWrapper.contains("build_and_run_simulator.sh\" ipados"))
    }

    @Test("iPad feed root dispatches non artwork routes")
    func iPadFeedRootDispatchesNonArtworkRoutes() throws {
        let root = try packageRoot()
        let contentView = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/ContentView_iPadOS.swift"),
            encoding: .utf8
        )
        let dashboardView = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/DiscoveryDashboardView.swift"),
            encoding: .utf8
        )
        let trendingStrip = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/DiscoveryTrendingTagsStrip.swift"),
            encoding: .utf8
        )
        let nativeToolbarMenu = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Support/NativeToolbarMenuButton.swift"),
            encoding: .utf8
        )
        let spotlightView = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/SpotlightView.swift"),
            encoding: .utf8
        )
        let spotlightDetailView = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/SpotlightArticleDetailView.swift"),
            encoding: .utf8
        )

        #expect(contentView.contains("private func feedContent(\n        discoveryPresentation: DiscoveryDashboardPresentation,\n        showsSidebarToggle: Bool\n    ) -> some View"))
        #expect(contentView.contains("DiscoveryDashboardView(store: store, presentation: discoveryPresentation)"))
        #expect(contentView.contains("private func discoveryPresentation(showsSidebarToggle: Bool) -> DiscoveryDashboardPresentation"))
        #expect(contentView.contains("splitColumnVisibility != .detailOnly ? .sidebarCompanion : .full"))
        #expect(contentView.contains("@State private var isArtworkDetailPresented = false"))
        #expect(contentView.contains("@State private var isSpotlightDetailPresented = false"))
        #expect(contentView.contains("@State private var creatorProfileVisualQAUser: PixivUser?"))
        #expect(contentView.contains("VisualQALaunchArgument.contains(.creatorProfile)"))
        #expect(contentView.contains("visualQADetail: VisualQASampleData.creatorProfileDetail"))
        #expect(contentView.contains("@State private var isSpotlightDetailPanelUserEnabled = false"))
        #expect(contentView.contains("@State private var isSpotlightArticlePushPresented = false"))
        #expect(contentView.contains(".navigationDestination(isPresented: $isSpotlightArticlePushPresented)"))
        #expect(contentView.contains("iPadFeedBrowserLayout(showsSidebarToggle: showsSidebarToggle)"))
        #expect(contentView.contains("private func iPadFeedBrowserLayout(showsSidebarToggle: Bool) -> some View"))
        #expect(contentView.contains("HStack(spacing: 0)"))
        #expect(contentView.contains("iPadArtworkDetailPanel"))
        #expect(contentView.contains("iPadSpotlightDetailPanel"))
        #expect(contentView.contains("private func iPadArtworkDetailHeader(close: @escaping () -> Void) -> some View"))
        #expect(contentView.contains("private func iPadSpotlightDetailHeader(close: @escaping () -> Void) -> some View"))
        #expect(contentView.contains("private func iPadReaderWindowButton(for artwork: PixivArtwork, showsTitle: Bool) -> some View"))
        #expect(contentView.contains("Label(L10n.openReaderWindow, systemImage: \"rectangle.inset.filled\")"))
        #expect(contentView.contains(".buttonStyle(.glassProminent)"))
        #expect(contentView.contains("ArtworkDetailView(store: store, showsNavigationChrome: false)"))
        #expect(contentView.contains("SpotlightArticleDetailView(store: store, showsNavigationChrome: false)"))
        #expect(contentView.contains("@State private var isArtworkDetailPanelUserEnabled = false"))
        #expect(contentView.contains("toggleArtworkDetailPanel(hidesSidebar: showsSidebarToggle)"))
        #expect(contentView.contains("toggleSpotlightDetailPanel(hidesSidebar: showsSidebarToggle)"))
        #expect(contentView.contains("isArtworkDetailPanelUserEnabled ? L10n.hideDetails : L10n.showDetails"))
        #expect(contentView.contains("isSpotlightDetailPanelUserEnabled ? L10n.hideDetails : L10n.showDetails"))
        #expect(contentView.contains("if isArtworkDetailPanelUserEnabled {\n                        presentArtworkDetail(for: artwork, hidesSidebar: showsSidebarToggle)"))
        #expect(contentView.contains("private var isArtworkDetailPanelVisible: Bool"))
        #expect(contentView.contains("private var isSpotlightDetailPanelVisible: Bool"))
        #expect(contentView.contains("dismissArtworkDetail(clearSelection: false)"))
        #expect(contentView.contains("dismissSpotlightDetail(clearSelection: false)"))
        #expect(contentView.contains(".onChange(of: store.artworkNavigationIntentSerial)"))
        #expect(contentView.contains("selectRoute(route, clearsArtworkDetail: false)"))
        #expect(contentView.contains("private func selectRoute(_ route: PixivRoute, clearsArtworkDetail: Bool = true)"))
        #expect(contentView.contains("private func toggleArtworkDetailPanel(hidesSidebar: Bool)"))
        #expect(contentView.contains("private func presentArtworkDetail(for artwork: PixivArtwork, hidesSidebar: Bool)"))
        #expect(contentView.contains("private func toggleSpotlightDetailPanel(hidesSidebar: Bool)"))
        #expect(contentView.contains("private func presentSpotlightArticle(_ article: PixivSpotlightArticle, usesPanel: Bool)"))
        #expect(contentView.contains("guard store.selectedRoute.usesArtworkFeed else { return }"))
        #expect(contentView.contains("splitColumnVisibility = .detailOnly"))
        #expect(contentView.contains("dismissArtworkDetail(clearSelection: true)"))
        #expect(contentView.contains("dismissSpotlightDetail(clearSelection: true)"))
        #expect(contentView.contains("store.prepareReaderWindow(for: artwork)"))
        #expect(contentView.contains("NativeToolbarMenuButton("))
        #expect(contentView.contains(".navigationSplitViewColumnWidth(min: 190, ideal: 218, max: 252)"))
        #expect(contentView.contains("ToolbarItemGroup(placement: .topBarLeading)"))
        #expect(contentView.contains("private var showsArtworkNavigationControls: Bool"))
        #expect(contentView.contains("private var artworkDetailToggleSystemImage: String"))
        #expect(contentView.contains("private var spotlightDetailToggleSystemImage: String"))
        #expect(contentView.contains("GeometryReader { proxy in"))
        #expect(contentView.contains("iPadArtworkDetailPanelWidth(for: proxy.size.width)"))
        #expect(contentView.contains("iPadSpotlightDetailPanelWidth(for: proxy.size.width)"))
        #expect(contentView.contains("private func iPadArtworkDetailPanelWidth(for availableWidth: CGFloat) -> CGFloat"))
        #expect(contentView.contains("private func iPadSpotlightDetailPanelWidth(for availableWidth: CGFloat) -> CGFloat"))
        #expect(contentView.contains("SpotlightView(store: store) { article in"))
        #expect(contentView.contains("presentSpotlightArticle(article, usesPanel: showsSidebarToggle)"))
        #expect(contentView.contains("systemImage: store.galleryLayoutMode.systemImage,\n                                accessibilityLabel: L10n.galleryLayout"))
        #expect(contentView.contains("systemImage: \"ellipsis.circle\",\n                            accessibilityLabel: L10n.appControls"))
        #expect(contentView.contains("title: L10n.galleryLayout"))
        #expect(contentView.contains("title: L10n.appControls"))
        #expect(contentView.contains("private var galleryLayoutMenu: NativeToolbarMenu"))
        #expect(contentView.contains("private var artworkActionsMenu: NativeToolbarMenu"))
        #expect(contentView.contains("presentation: .palette"))
        #expect(contentView.contains("private var showsArtworkActionsMenu: Bool"))
        #expect(contentView.contains("accessibilityLabel: L10n.currentArtwork"))
        #expect(contentView.contains("selectedArtworkMenuSystemImage"))
        #expect(contentView.contains("IPadToolbarMenuAction.toggleBookmark"))
        #expect(contentView.contains("IPadToolbarMenuAction.downloadSelectedArtwork"))
        #expect(contentView.contains("IPadToolbarMenuAction.searchImageSource"))
        #expect(contentView.contains("IPadToolbarMenuAction.openCreatorProfile"))
        #expect(contentView.contains("IPadToolbarMenuAction.openReaderWindow"))
        #expect(contentView.contains("IPadToolbarMenuAction.openSelectedArtworkInPixiv"))
        #expect(contentView.contains("IPadToolbarMenuAction.copySelectedArtworkLink"))
        #expect(contentView.contains("store.prepareSelectedReaderWindow()"))
        #expect(contentView.contains("store.copySelectedArtworkLink()"))
        #expect(contentView.contains("private func canSelectAdjacentArtwork(delta: Int) -> Bool"))
        #expect(contentView.contains("private var appControlsMenu: NativeToolbarMenu"))
        #expect(contentView.contains("handleNativeToolbarMenuAction"))
        #expect(contentView.contains("L10n.showContentBadges"))
        #expect(contentView.contains("L10n.hideMutedContent"))
        #expect(contentView.contains("L10n.hideAIArtworks"))
        #expect(contentView.contains("L10n.hideR18Artworks"))
        #expect(contentView.contains("L10n.hideR18GArtworks"))
        #expect(contentView.contains("L10n.maskSensitivePreviews"))
        #expect(contentView.contains("store.setPrivacyModeEnabled"))
        #expect(contentView.contains("store.setGalleryLayoutMode(mode)"))
        #expect(contentView.contains("NavigationSplitView(columnVisibility: $splitColumnVisibility)"))
        #expect(contentView.contains("List {"))
        #expect(contentView.contains("private func iPadSidebarRow("))
        #expect(contentView.contains("systemName: \"checkmark\"") == false)
        #expect(contentView.contains("private var sidebarToggleButton: some View") == false)
        #expect(contentView.contains("usesLandscapeSidebar(for size: CGSize)"))
        #expect(contentView.contains("case settings"))
        #expect(contentView.contains("ToolbarItem(placement: .topBarLeading)"))
        #expect(contentView.contains("private var routeMenu: some View"))
        #expect(contentView.contains("ForEach(PixivRoute.sidebarSections)"))
        #expect(contentView.contains("store.select(route)"))
        #expect(contentView.contains("if store.selectedRoute == .home"))
        #expect(contentView.contains("NovelGalleryView(store: store)"))
        #expect(contentView.contains("SpotlightView(store: store)"))
        #expect(contentView.contains("BookmarkTagsView(store: store)"))
        #expect(contentView.contains("BrowsingHistoryView(store: store)"))
        #expect(contentView.contains("store.selectedRoute.isCreatorRoute"))
        #expect(contentView.contains("UserPreviewListView(store: store, mode: userPreviewMode)"))
        #expect(contentView.contains("store.requestRouteRefresh()"))
        #expect(contentView.contains("Task { await store.reloadCurrentFeed() }") == false)
        #expect(contentView.contains("ToolbarItem(placement: .topBarTrailing)") == false)
        #expect(dashboardView.contains("enum DiscoveryDashboardPresentation"))
        #expect(dashboardView.contains("case sidebarCompanion"))
        #expect(dashboardView.contains("sidebarCompanionContent"))
        #expect(dashboardView.contains("companionOverview"))
        #expect(dashboardView.contains("private enum DiscoveryDashboardHeroStyle: Equatable"))
        #expect(dashboardView.contains("private struct DiscoveryDashboardHeroCard: View"))
        #expect(dashboardView.contains("private struct DiscoveryDashboardSectionHeader: View"))
        #expect(dashboardView.contains("DashboardMetricGroupCard"))
        #expect(dashboardView.contains("DashboardMetricTile"))
        #expect(dashboardView.contains("ViewThatFits(in: .horizontal)"))
        #expect(dashboardView.contains("ForEach(store.visibleDashboardSections)"))
        #expect(dashboardView.contains(".keiGlass(22)"))
        #expect(dashboardView.contains(".keiInteractiveGlass(18)"))
        #expect(dashboardView.contains(".background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10") == false)
        #expect(dashboardView.contains(".background(Color.secondary.opacity(0.07)") == false)
        #expect(dashboardView.contains("backgroundStyle") == false)
        #expect(trendingStrip.contains("@State private var hasAttemptedLoad = false"))
        #expect(trendingStrip.contains("hasAttemptedLoad && isLoading == false && tags.isEmpty"))
        #expect(trendingStrip.contains("GlassEffectContainer(spacing: 12)"))
        #expect(trendingStrip.contains(".keiGlass(22)"))
        #expect(trendingStrip.contains(".buttonStyle(.bordered)"))
        #expect(trendingStrip.contains(".clipShape(RoundedRectangle(cornerRadius: 18"))
        #expect(trendingStrip.contains(".buttonStyle(.borderless)") == false)
        #expect(trendingStrip.contains("Color.black") == false)
        #expect(trendingStrip.contains("cornerRadius: 8") == false)
        #expect(nativeToolbarMenu.contains("struct NativeToolbarMenuButton: UIViewRepresentable"))
        #expect(nativeToolbarMenu.contains("UIButton(type: .system)"))
        #expect(nativeToolbarMenu.contains("button.showsMenuAsPrimaryAction = true"))
        #expect(nativeToolbarMenu.contains("configuration.title = title"))
        #expect(nativeToolbarMenu.contains("configuration.imagePlacement = .leading"))
        #expect(nativeToolbarMenu.contains("case palette"))
        #expect(nativeToolbarMenu.contains(".displayAsPalette"))
        #expect(nativeToolbarMenu.contains("UIMenu("))
        #expect(nativeToolbarMenu.contains("UIAction("))

        #expect(spotlightView.contains("var openArticle: ((PixivSpotlightArticle) -> Void)?"))
        #expect(spotlightView.contains("private var paginationFooter: some View"))
        #expect(spotlightView.contains("openArticle?(article)"))
        #expect(spotlightView.contains(".accessibilityLabel(isLoadingMore ? L10n.loading : L10n.loadMoreSpotlightArticles)"))
        #expect(spotlightView.contains(".help(L10n.loadMoreSpotlightArticles)"))
        #expect(spotlightView.contains(".gridCellColumns(loadMoreSpan)") == false)
        #expect(spotlightView.contains("private var loadMoreSpan") == false)
        #expect(spotlightDetailView.contains("var showsNavigationChrome = true"))
        #expect(spotlightDetailView.contains("showsNavigationChrome ? (article.pureTitle.isEmpty ? L10n.spotlight : article.pureTitle) : \"\""))
    }

    @Test("Pixiv signed-out surfaces share one native login state")
    func pixivSignedOutSurfacesShareOneNativeLoginState() throws {
        let root = try packageRoot()
        let emptyState = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/EmptyStateView.swift"),
            encoding: .utf8
        )
        let signedOutConsumers = [
            "Sources/KeiPix/Views/GalleryView.swift",
            "Sources/KeiPix/Views/DiscoveryDashboardView.swift",
            "Sources/KeiPix/Views/TrendingTagsView.swift",
            "Sources/KeiPix/Views/BookmarkTagsView.swift",
            "Sources/KeiPix/Views/MangaWatchlistView.swift",
            "Sources/KeiPix/Views/NovelGalleryView.swift",
            "Sources/KeiPix/Views/NovelWatchlistView.swift",
            "Sources/KeiPix/Views/SpotlightView.swift",
            "Sources/KeiPix/Views/UserPreviewListView.swift",
            "Sources/KeiPix/Views/WorkSubscriptionsView.swift"
        ]

        #expect(emptyState.contains("struct PixivSignedOutStateView: View"))
        #expect(emptyState.contains("GlassEffectContainer(spacing: 18)"))
        #expect(emptyState.contains(".keiGlass(30)"))
        #expect(emptyState.contains("private var signedOutHero: some View"))
        #expect(emptyState.contains("private var signedOutActions: some View"))
        #expect(emptyState.contains("ViewThatFits(in: .horizontal)"))
        #expect(emptyState.contains("store.activateGuestMode()"))
        #expect(emptyState.contains("store.isLoginPresented = true"))
        #expect(emptyState.contains("store.isTokenLoginPresented = true"))
        #expect(emptyState.contains(".buttonStyle(.glassProminent)"))
        #expect(emptyState.contains(".keiInteractiveGlass(20)"))
        #expect(emptyState.contains("systemImage: \"key\""))

        for path in signedOutConsumers {
            let source = try String(contentsOf: root.appending(path: path), encoding: .utf8)
            #expect(source.contains("PixivSignedOutStateView(store: store)"), "\(path) should reuse the shared Pixiv signed-out surface")
            #expect(source.contains("EmptyStateView(title: L10n.signedOutTitle") == false, "\(path) should not hand-roll a signed-out empty state")
        }

        let gallery = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/GalleryView.swift"),
            encoding: .utf8
        )
        let discovery = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/DiscoveryDashboardView.swift"),
            encoding: .utf8
        )
        let novelGallery = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/NovelGalleryView.swift"),
            encoding: .utf8
        )
        let novelWatchlist = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/NovelWatchlistView.swift"),
            encoding: .utf8
        )
        let workSubscriptions = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/WorkSubscriptionsView.swift"),
            encoding: .utf8
        )

        #expect(gallery.contains("private struct SignedOutView") == false)
        #expect(discovery.contains("private var signedOutContent") == false)
        #expect(novelGallery.contains("if store.session != nil, novelStore.novels.isEmpty && novelStore.isLoading == false"))
        #expect(novelWatchlist.contains("if store.session != nil {\n                await novelStore.refreshWatchlist()"))
        #expect(workSubscriptions.contains("guard store.session != nil else { return \"\" }"))
    }

    @Test("iPad page status uses inline title chrome")
    func iPadPageStatusUsesInlineTitleChrome() throws {
        let root = try packageRoot()
        let emptyState = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/EmptyStateView.swift"),
            encoding: .utf8
        )
        let discovery = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/DiscoveryDashboardView.swift"),
            encoding: .utf8
        )
        let inlineStatusPages = [
            "Sources/KeiPix/Views/TrendingTagsView.swift",
            "Sources/KeiPix/Views/BookmarkTagsView.swift",
            "Sources/KeiPix/Views/MangaWatchlistView.swift",
            "Sources/KeiPix/Views/UserPreviewListView.swift",
            "Sources/KeiPix/Views/SpotlightView.swift",
            "Sources/KeiPix/Views/WorkSubscriptionsView.swift",
            "Sources/KeiPix/Views/WatchLaterView.swift",
            "Sources/KeiPix/Views/BrowsingHistoryView.swift",
            "Sources/KeiPix/Views/SavedSearchesView.swift",
            "Sources/KeiPix/Views/MutedContentView.swift",
            "Sources/KeiPix/Views/DownloadQueueView.swift"
        ]

        #expect(emptyState.contains("struct PlatformPageTitleHeader: View"))
        #expect(emptyState.contains("func platformPageHeader(title: String, status: String, statusSystemImage: String? = nil)"))
        #expect(emptyState.contains("ViewThatFits(in: .horizontal)"))
        #expect(emptyState.contains(".navigationBarTitleDisplayMode(.inline)"))
        #expect(emptyState.contains(".glassEffect(.regular, in: Capsule(style: .continuous))"))

        for path in inlineStatusPages {
            let source = try String(contentsOf: root.appending(path: path), encoding: .utf8)
            #expect(source.contains(".platformPageHeader("), "\(path) should render iPadOS page status beside the title")
            #expect(source.contains(".platformPageNavigationChrome("), "\(path) should keep macOS navigation subtitle behavior centralized")
            #expect(source.contains(".navigationSubtitle(") == false, "\(path) should not force iPadOS status into the system subtitle row")
        }

        #expect(discovery.contains(".platformPageNavigationChrome(title: L10n.discover, status: navigationSubtitle)"))
        #expect(discovery.contains(".navigationSubtitle(") == false)
    }

    @Test("OS 26 chrome avoids legacy bar and capsule materials")
    func os26ChromeAvoidsLegacyBarAndCapsuleMaterials() throws {
        let root = try packageRoot()
        let sourceRoot = root.appending(path: "Sources/KeiPix", directoryHint: .isDirectory)
        let swiftFiles = try sourceFiles(in: sourceRoot).filter { $0.pathExtension == "swift" }
        let glassSupport = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Support/Glass.swift"),
            encoding: .utf8
        )
        let gallery = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/GalleryView.swift"),
            encoding: .utf8
        )
        let sheetHeader = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Support/SheetHeaderRail.swift"),
            encoding: .utf8
        )
        let sheetChrome = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Support/SheetCloseButton.swift"),
            encoding: .utf8
        )
        let userProfileHeader = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/UserProfileSheetHeader.swift"),
            encoding: .utf8
        )
        let userProfileSheet = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/UserProfileSheet.swift"),
            encoding: .utf8
        )
        let userProfileInfoSections = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/UserProfileInfoSections.swift"),
            encoding: .utf8
        )
        let userProfileCreatorTags = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/UserProfileCreatorTagsSection.swift"),
            encoding: .utf8
        )

        #expect(glassSupport.contains("func platformGlassControlBar("))
        #expect(glassSupport.contains(".keiGlass(20)"))
        #expect(gallery.contains(".platformGlassControlBar(verticalPadding: 6"))
        #expect(gallery.contains(".glassEffect(.regular, in: Capsule(style: .continuous))"))
        #expect(sheetHeader.contains(".platformGlassControlBar(verticalPadding: 12"))
        #expect(sheetHeader.contains(".buttonStyle(.glass)"))
        #expect(sheetHeader.contains(".buttonBorderShape(.capsule)"))
        #expect(sheetChrome.contains("func os26SheetChrome(_ style: OS26SheetPresentationStyle = .standard)"))
        #expect(sheetChrome.contains(".presentationBackground(.regularMaterial)"))
        #expect(sheetChrome.contains(".presentationCornerRadius(style.cornerRadius)"))
        #expect(userProfileHeader.contains("GlassEffectContainer(spacing: 8)"))
        #expect(userProfileHeader.contains("ViewThatFits(in: .horizontal)"))
        #expect(userProfileHeader.contains("ProfileSheetHeaderButtonDisplayStyle"))
        #expect(userProfileHeader.contains("profileLinkButtons"))
        #expect(userProfileHeader.contains("ProfileHeaderLinkEntry"))
        #expect(userProfileHeader.contains("detail?.profile.webpage"))
        #expect(userProfileSheet.contains("UserProfileLinksSection") == false)
        #expect(userProfileInfoSections.contains("struct UserProfileLinksSection") == false)
        #expect(userProfileCreatorTags.contains("private var tagCloud: some View"))
        #expect(userProfileCreatorTags.contains("FlowLayout(spacing: 8)"))
        #expect(userProfileCreatorTags.contains("CreatorArtworkTagChip"))
        #expect(userProfileCreatorTags.contains(".glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 18"))
        #expect(userProfileCreatorTags.contains("Divider()") == false)

        for file in swiftFiles {
            let source = try String(contentsOf: file, encoding: .utf8)
            #expect(source.contains(".background(.bar)") == false, "\(file.lastPathComponent) should not use legacy bar fills for OS 26 chrome")
            #expect(source.contains(".background(.thinMaterial, in: Capsule())") == false, "\(file.lastPathComponent) should use glassEffect for status capsules")
            if file.lastPathComponent != "SheetCloseButton.swift" {
                #expect(source.contains(".iPadFriendlySheet()") == false, "\(file.lastPathComponent) should declare OS 26 sheet intent with os26SheetChrome")
            }
        }
    }

    @Test("macOS feed keeps sidebar manual and lifts artwork navigation")
    func macOSFeedKeepsSidebarManualAndLiftsArtworkNavigation() throws {
        let root = try packageRoot()
        let contentView = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/ContentView.swift"),
            encoding: .utf8
        )

        #expect(contentView.contains("NavigationSplitView(columnVisibility: $columnVisibility)"))
        #expect(contentView.contains("ArtworkDetailView(store: store, showsNavigationChrome: false)"))
        #expect(contentView.contains("contentColumnMinWidth"))
        #expect(contentView.contains("store.selectedRoute.isCreatorRoute ? 720 : 560"))
        #expect(contentView.contains("CreatorListDetailPlaceholder(route: store.selectedRoute)"))
        #expect(contentView.contains(".navigationSplitViewColumnWidth(min: 360, ideal: 440)"))
        #expect(contentView.contains(".navigationSplitViewColumnWidth(min: 420, ideal: 560)"))
        #expect(contentView.contains(".frame(minWidth: minimumWindowWidth, minHeight: MainWindowSizing.minimumHeight)"))
        #expect(contentView.contains(".mainWindowSizing("))
        #expect(contentView.contains("preferredDefaultSize: WindowSizePreset.balanced.size("))
        #expect(contentView.contains("ToolbarItemGroup(placement: .navigation)"))
        #expect(contentView.contains("private var showsArtworkNavigationControls: Bool"))
        #expect(contentView.contains("private func toggleSidebar()"))
        #expect(contentView.contains("columnVisibility = isSidebarPresented ? .all : .doubleColumn"))
        #expect(contentView.contains("MainWindowSizing.minimumWidth(\n            sidebarVisible: sidebarVisible"))
        #expect(contentView.contains("detailOnly") == false)
    }

    @Test("macOS toolbar uses grouped AppKit chrome")
    func macOSToolbarUsesGroupedAppKitChrome() throws {
        let root = try packageRoot()
        let contentView = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/ContentView.swift"),
            encoding: .utf8
        )

        #expect(contentView.contains("ToolbarItemGroup(placement: .primaryAction)"))
        #expect(contentView.contains("ToolbarSpacer(.fixed, placement: .primaryAction)"))
        #expect(contentView.contains(".windowStyler(unifiedToolbar: true)"))
        #expect(contentView.contains("Section(L10n.links)"))
        #expect(contentView.contains("Section(L10n.windowSize)"))
        #expect(contentView.contains("Section(L10n.viewOptions)"))
        #expect(contentView.contains("Section(L10n.contentFilters)"))
        #expect(contentView.contains("Toggle(L10n.hideMutedContent, isOn: hideMutedContentBinding)"))
    }

    @Test("macOS launch sizing clamps restored narrow windows")
    func macOSLaunchSizingClampsRestoredNarrowWindows() throws {
        let root = try packageRoot()
        let sidebarView = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/SidebarView.swift"),
            encoding: .utf8
        )
        let windowSizePreset = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Models/WindowSizePreset.swift"),
            encoding: .utf8
        )
        let windowStyler = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Support/WindowStyler.swift"),
            encoding: .utf8
        )

        #expect(windowSizePreset.contains("enum MainWindowSizing"))
        #expect(windowSizePreset.contains("static let minimumHeight: CGFloat = 760"))
        #expect(windowSizePreset.contains("static let defaultSize = CGSize(width: 1440, height: 860)"))
        #expect(windowSizePreset.contains("accountIdentityVisible ? 1240 : 1200"))
        #expect(windowSizePreset.contains("CGSize(width: MainWindowSizing.minimumWidth(sidebarVisible: true"))
        #expect(windowSizePreset.contains("CGSize(width: MainWindowSizing.minimumWidth(sidebarVisible: false), height: 720)"))
        #expect(sidebarView.contains("min: store.showsSidebarAccountIdentity ? 238 : 218"))
        #expect(sidebarView.contains("ideal: store.showsSidebarAccountIdentity ? 258 : 232"))
        #expect(sidebarView.contains("max: store.showsSidebarAccountIdentity ? 300 : 270"))
        #expect(windowStyler.contains("struct MainWindowSizingModifier: ViewModifier"))
        #expect(windowStyler.contains("private final class MainWindowSizingHostView: NSView"))
        #expect(windowStyler.contains("override func viewDidMoveToWindow()"))
        #expect(windowStyler.contains("private var didApplyInitialComfortSize = false"))
        #expect(windowStyler.contains("window.contentMinSize = NSSize(width: effectiveMinimum.width, height: effectiveMinimum.height)"))
        #expect(windowStyler.contains("window.contentRect(forFrameRect: visibleFrame).size"))
        #expect(windowStyler.contains("didApplyInitialComfortSize ? effectiveMinimum"))
        #expect(windowStyler.contains("window.contentLayoutRect"))
        #expect(windowStyler.contains("window.setFrame(nextFrame, display: true, animate: false)"))
        #expect(windowStyler.contains("func mainWindowSizing("))
    }

    @Test("macOS feed header uses glass action chrome")
    func macOSFeedHeaderUsesGlassActionChrome() throws {
        let root = try packageRoot()
        let feedHeader = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/GalleryFeedHeaderView.swift"),
            encoding: .utf8
        )
        let galleryView = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/GalleryView.swift"),
            encoding: .utf8
        )
        let feedHeaderActionChromeTail = feedHeader
            .components(separatedBy: "func feedHeaderActionChrome() -> some View")
            .dropFirst()
            .first ?? ""
        let feedHeaderActionChrome = feedHeaderActionChromeTail
            .components(separatedBy: "func iPadFeedHeaderActionChrome() -> some View")
            .first ?? ""

        #expect(feedHeader.contains("GlassEffectContainer"))
        #expect(feedHeader.contains("HStack(spacing: 8) {\n                        headerActions"))
        #expect(feedHeader.contains("private var macOSFilterField: some View"))
        #expect(feedHeader.contains(".textFieldStyle(.plain)"))
        #expect(feedHeader.contains(".layoutPriority(1)"))
        #expect(feedHeader.contains(".feedHeaderActionChrome()"))
        #expect(feedHeader.contains(".keiInteractiveGlass(16)"))
        #expect(feedHeader.contains("private var bookmarkFiltersMenu: some View"))
        #expect(feedHeader.contains("private var bookmarkVisibilityMenu: some View"))
        #expect(feedHeader.contains("private var bookmarkSortMenu: some View"))
        #expect(feedHeader.contains("private var bookmarkAgeLimitMenu: some View"))
        #expect(feedHeader.contains("private var bookmarkSupportMenu: some View"))
        #expect(feedHeader.contains("bookmarkArtworkTagMenu"))
        #expect(feedHeaderActionChrome.contains(".buttonStyle(.plain)"))
        #expect(feedHeaderActionChrome.contains(".buttonStyle(.bordered)") == false)

        #expect(galleryView.contains(".padding(.horizontal, 18)\n            .padding(.top, 9)\n            .padding(.bottom, 7)"))
        #expect(galleryView.contains(".padding(.horizontal, 18)\n            .padding(.vertical, 5)\n            .background(.bar)") == false)
    }

    @Test("Bookmark filters stay reachable in regular and iPad compact feed headers")
    func bookmarkFiltersStayReachableInFeedHeaders() throws {
        let root = try packageRoot()
        let feedHeader = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/GalleryFeedHeaderView.swift"),
            encoding: .utf8
        )
        let compactHeader = feedHeader
            .components(separatedBy: "private var iPadCompactHeaderActions: some View")
            .dropFirst()
            .first?
            .components(separatedBy: "private var headerActions: some View")
            .first ?? ""
        let regularHeader = feedHeader
            .components(separatedBy: "private var headerActions: some View")
            .dropFirst()
            .first?
            .components(separatedBy: "private var macOSFilterField: some View")
            .first ?? ""
        let localizable = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Resources/Localizable.xcstrings"),
            encoding: .utf8
        )

        #expect(feedHeader.contains("private var bookmarkFiltersMenu: some View"))
        #expect(compactHeader.contains("if store.selectedRoute.isOwnBookmarkRoute {\n                bookmarkFiltersMenu"))
        #expect(regularHeader.contains("if store.selectedRoute.isOwnBookmarkRoute {\n            bookmarkFiltersMenu"))
        #expect(localizable.contains("\"Bookmark Filters\""))
        #expect(localizable.contains("\"value\": \"收藏筛选\""))
        #expect(localizable.contains("\"Pixiv Web only\""))
        #expect(localizable.contains("\"value\": \"Pixiv Web 专属\""))
    }

    @Test("Refresh token export is explicit and confirmation gated")
    func refreshTokenExportIsExplicitAndConfirmationGated() throws {
        let root = try packageRoot()
        let accountSettings = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/Settings/AccountSettingsPage.swift"),
            encoding: .utf8
        )
        let settingsView = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/SettingsView.swift"),
            encoding: .utf8
        )
        let coordinator = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/Settings/SettingsCoordinator.swift"),
            encoding: .utf8
        )

        #expect(accountSettings.contains("L10n.copyRefreshToken"))
        #expect(accountSettings.contains("isRefreshTokenCopyConfirmationPresented = true"))
        #expect(accountSettings.contains("PasteboardWriter.copy") == false)
        #expect(settingsView.contains("confirmationDialog(\n            L10n.copyRefreshToken"))
        #expect(settingsView.contains("copyCurrentRefreshToken()"))
        #expect(settingsView.contains("PasteboardWriter.copy(refreshToken)"))
        #expect(settingsView.contains("L10n.copyRefreshTokenConfirmationMessage"))
        #expect(coordinator.contains("isRefreshTokenCopyConfirmationPresented"))
    }

    @Test("Gallery feed layouts use a native collection bridge")
    func galleryFeedLayoutsUseNativeCollectionBridge() throws {
        let root = try packageRoot()
        let galleryView = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/GalleryView.swift"),
            encoding: .utf8
        )
        let artworkCard = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/ArtworkCardView.swift"),
            encoding: .utf8
        )
        let masonryPresentation = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Models/ArtworkMasonryPresentation.swift"),
            encoding: .utf8
        )
        let l10n = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Support/L10n.swift"),
            encoding: .utf8
        )
        let store = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Stores/KeiPixStore.swift"),
            encoding: .utf8
        )
        let navigationHistory = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Stores/KeiPixStore+NavigationHistory.swift"),
            encoding: .utf8
        )
        let nativeCollection = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Support/NativeGalleryCollectionView.swift"),
            encoding: .utf8
        )
        let hoverEffect = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Support/KeiPixHoverEffect.swift"),
            encoding: .utf8
        )
        let nativeInlineFilter = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Support/NativeInlineFilterField.swift"),
            encoding: .utf8
        )
        let feedHeader = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/GalleryFeedHeaderView.swift"),
            encoding: .utf8
        )

        #expect(galleryView.contains("usesNativeGalleryCollection"))
        #expect(galleryView.contains("usesArtworkMasonry"))
        #expect(galleryView.contains("NativeGalleryCollectionView("))
        #expect(galleryView.contains("iPadNativeFeedHeader"))
        #expect(galleryView.contains("navigationBarTitleDisplayMode(.inline)"))
        #expect(galleryView.contains("presentation: .iPadCompact"))
        #expect(galleryView.contains("nativeHighlightedArtworkIDs"))
        #expect(galleryView.contains("nativeGalleryContentReloadToken"))
        #expect(feedHeader.contains("enum FeedHeaderPresentation"))
        #expect(feedHeader.contains("case iPadCompact"))
        #expect(feedHeader.contains("NativeInlineFilterField("))
        #expect(feedHeader.contains("iPadFeedHeaderActionChrome()"))
        #expect(store.contains("var artworkNavigationIntentSerial = 0"))
        #expect(navigationHistory.contains("artworkNavigationIntentSerial += 1"))
        #expect(artworkCard.contains(".minimumScaleFactor(0.82)"))
        #expect(masonryPresentation.contains("case .wide:\n            2"))
        #expect(l10n.contains("static var showDetails: String"))
        #expect(l10n.contains("static var hideDetails: String"))
        #expect(l10n.contains("Tap to select artwork"))
        #expect(nativeCollection.contains("NativeGalleryMasonryNSCollectionViewLayout"))
        #expect(nativeCollection.contains("NativeGalleryMasonryUICollectionViewLayout"))
        #expect(nativeCollection.contains("ArtworkMasonryPlacement.resolve"))
        #expect(nativeCollection.contains("NSCollectionViewDiffableDataSource"))
        #expect(nativeCollection.contains("UICollectionViewDiffableDataSource"))
        #expect(nativeCollection.contains("NSHostingView"))
        #expect(nativeCollection.contains("UIHostingController"))
        #expect(nativeCollection.contains("UIRefreshControl"))
        #expect(nativeCollection.contains("EdgeInsets(top: 10"))
        #expect(nativeCollection.contains("lastSnapshotItemIDs"))
        #expect(nativeCollection.contains("lastLayoutFingerprint"))
        #expect(nativeCollection.contains("reloadHighlightDeltaIfNeeded"))
        #expect(nativeCollection.contains("reconfigureVisibleItems"))
        #expect(nativeCollection.contains("symmetricDifference"))
        #expect(nativeCollection.contains("applySnapshotUsingReloadData"))
        #expect(nativeCollection.contains("previousCachedAttributes"))
        #expect(nativeCollection.contains("initialLayoutAttributesForAppearingItem"))
        #expect(nativeCollection.contains("finalLayoutAttributesForDisappearingItem"))
        #expect(nativeCollection.contains("UIPointerInteractionDelegate"))
        #expect(nativeCollection.contains("UIPointerStyle(effect: .lift"))
        #expect(nativeCollection.contains("showsLargeContentViewer = true"))
        #expect(nativeCollection.contains("largeContentTitle = item.pointerTitle"))
        #expect(hoverEffect.contains(".hoverEffect(.lift)"))
        #expect(nativeCollection.contains("reloadItems(at: collectionView.indexPathsForVisibleItems())") == false)
        #expect(nativeCollection.contains("reloadItems(at: collectionView.indexPathsForVisibleItems)") == false)
        #expect(nativeInlineFilter.contains("struct NativeInlineFilterField: UIViewRepresentable"))
        #expect(nativeInlineFilter.contains("UISearchTextField"))
        #expect(nativeInlineFilter.contains("UITextFieldDelegate"))
    }

    @Test("Search popular preview uses a native artwork shelf")
    func searchPopularPreviewUsesNativeArtworkShelf() throws {
        let root = try packageRoot()
        let popularPreview = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/GalleryPopularPreviewStrip.swift"),
            encoding: .utf8
        )
        let nativeShelf = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Support/NativeArtworkShelfCollectionView.swift"),
            encoding: .utf8
        )

        #expect(popularPreview.contains("NativeArtworkShelfCollectionView("))
        #expect(popularPreview.contains("popularPreviewCard(_ artwork: PixivArtwork)"))
        #expect(popularPreview.contains("ScrollView(.horizontal)") == false)
        #expect(popularPreview.contains("LazyHStack") == false)
        #expect(nativeShelf.contains("NativeCreatorPreviewCollectionView("))
        #expect(nativeShelf.contains(".horizontalShelf(itemWidth: itemWidth, itemHeight: itemHeight)"))
        #expect(nativeShelf.contains("NativeCreatorPreviewCollectionItem.artwork"))
    }

    @Test("Novel reader text pages use native TextKit bridges")
    func novelReaderTextPagesUseNativeTextKitBridges() throws {
        let root = try packageRoot()
        let readerView = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/NovelReaderView.swift"),
            encoding: .utf8
        )
        let nativeText = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Support/NativeNovelTextPageView.swift"),
            encoding: .utf8
        )

        #expect(readerView.contains("usesNativeNovelTextPage"))
        #expect(readerView.contains("NativeNovelTextPageView("))
        #expect(nativeText.contains("NSTextView.scrollableTextView"))
        #expect(nativeText.contains("UITextView"))
        #expect(nativeText.contains("NSAttributedString"))
        #expect(nativeText.contains("NativeNovelTextAttributedStringBuilder"))
    }

    @Test("Artwork reader native scroll viewports keep SwiftUI height stable")
    func artworkReaderNativeScrollViewportsKeepHeightStable() throws {
        let root = try packageRoot()
        let readerView = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/ArtworkReaderView.swift"),
            encoding: .utf8
        )
        let imageScrollView = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Support/ImageScrollView.swift"),
            encoding: .utf8
        )
        let iPadImageScrollView = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Support/iPadImageScrollView.swift"),
            encoding: .utf8
        )
        let readerGestureBridge = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Support/ReaderGestureBridge.swift"),
            encoding: .utf8
        )
        let artworkSummary = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/ArtworkSummaryView.swift"),
            encoding: .utf8
        )
        let interactionModels = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Models/ReaderInteractionModels.swift"),
            encoding: .utf8
        )
        let viewportLayout = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Support/ReaderPageViewportLayout.swift"),
            encoding: .utf8
        )

        #expect(readerView.contains("SinglePageReaderViewportLayout(presentation: presentation)"))
        #expect(readerView.contains("DoublePageReaderViewportLayout("))
        #expect(readerView.contains("GeometryReader { _ in") == false)
        #expect(viewportLayout.contains("struct SinglePageReaderViewportLayout: Layout"))
        #expect(viewportLayout.contains("struct DoublePageReaderViewportLayout: Layout"))
        #expect(viewportLayout.contains("singlePageHeight(for: width)"))
        #expect(viewportLayout.contains("doublePageHeight(for: width, pairedWith: rightPresentation)"))
        #expect(readerView.contains(".readerCanvasChrome()"))
        #expect(readerView.contains(".readerControlChrome()"))
        #expect(readerView.contains("GlassEffectContainer(spacing: 10)"))
        #expect(readerView.contains("private var readingModeMenu: some View"))
        #expect(readerView.contains("Menu {\n            Section(L10n.readingMode)"))
        #expect(readerView.contains("ControlGroup {"))
        #expect(readerView.contains(".buttonStyle(.bordered)"))
        #expect(readerView.contains("private var pageIndicator: some View"))
        #expect(readerView.contains(".pickerStyle(.segmented)") == false)
        #expect(imageScrollView.contains("func handleMagnificationChanged(_ magnification: CGFloat)"))
        #expect(imageScrollView.contains("private func centerDocument()"))
        #expect(imageScrollView.contains("scrollView.contentInsets = NSEdgeInsets("))
        #expect(imageScrollView.contains("completionHandler: { [weak self] in"))
        #expect(iPadImageScrollView.contains("scrollView.isDirectionalLockEnabled = true"))
        #expect(iPadImageScrollView.contains("scrollView.panGestureRecognizer.allowedScrollTypesMask = [.continuous, .discrete]"))
        #expect(iPadImageScrollView.contains("let velocity = gesture.velocity(in: gesture.view)"))
        #expect(iPadImageScrollView.contains("gesture.setTranslation(.zero, in: gesture.view)"))
        #expect(readerGestureBridge.contains("@State private var lastDragTranslation"))
        #expect(readerGestureBridge.contains("private static func projectedVelocity"))
        #expect(interactionModels.contains("swipeVelocityThreshold"))
        #expect(interactionModels.contains("velocityX: CGFloat? = nil"))
        #expect(artworkSummary.contains("private var metricsRail: some View"))
        #expect(artworkSummary.contains("FlowLayout(spacing: 8)"))
        #expect(artworkSummary.contains(".frame(maxWidth: .infinity, alignment: .leading)"))
    }

    @Test("Artwork detail inspector uses adaptive actions and merged information cards")
    func artworkDetailInspectorUsesAdaptiveActionsAndMergedInformationCards() throws {
        let root = try packageRoot()
        let artworkSummary = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/ArtworkSummaryView.swift"),
            encoding: .utf8
        )
        let artworkInformation = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/ArtworkInformationSections.swift"),
            encoding: .utf8
        )
        let artworkTags = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/ArtworkTagChipsView.swift"),
            encoding: .utf8
        )
        let artworkDetail = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/ArtworkDetailView.swift"),
            encoding: .utf8
        )
        let artworkComments = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/ArtworkCommentsView.swift"),
            encoding: .utf8
        )
        let artworkRelated = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/ArtworkRelatedView.swift"),
            encoding: .utf8
        )

        #expect(artworkSummary.contains("AdaptiveArtworkActionLayout.resolve"))
        #expect(artworkSummary.contains("showsWatchLaterInline"))
        #expect(artworkSummary.contains("watchLaterButton(showsTitle: true)"))
        #expect(artworkSummary.contains("UIDevice.current.userInterfaceIdiom == .phone"))
        #expect(artworkSummary.contains("L10n.addToWatchLater"))
        #expect(artworkSummary.contains("L10n.inWatchLater"))
        #expect(artworkInformation.contains("ArtworkContextCard("))
        #expect(artworkInformation.contains("contextExpansionBinding"))
        #expect(artworkInformation.contains("TagCloudInspectorSection("))
        #expect(artworkInformation.contains("struct ArtworkInspectorSectionHeader: View"))
        #expect(artworkInformation.contains("ArtworkInspectorSectionHeader("))
        #expect(artworkInformation.contains("ArtworkMetadataRail"))
        #expect(artworkInformation.contains("ArtworkMetadataPill"))
        #expect(artworkInformation.contains("L10n.imageSize"))
        #expect(artworkInformation.contains("CollapsibleInspectorSection") == false)
        #expect(artworkTags.contains("ViewThatFits(in: .horizontal)"))
        #expect(artworkTags.contains("RoundedRectangle(cornerRadius: 13"))
        #expect(artworkDetail.contains("private static let topAnchorID = \"artwork-detail-top\""))
        #expect(artworkDetail.contains("scrollToRestoredPosition(proxy: proxy)"))
        #expect(artworkDetail.contains("proxy.scrollTo(Self.topAnchorID, anchor: .top)"))
        #expect(artworkComments.contains("ArtworkInspectorSectionHeader("))
        #expect(artworkComments.contains(".keiGlass(18)"))
        #expect(artworkComments.contains(".textFieldStyle(.plain)"))
        #expect(artworkComments.contains(".textFieldStyle(.roundedBorder)") == false)
        #expect(artworkComments.contains(".keiPanel(16)") == false)
        #expect(artworkComments.contains(".background(.quinary") == false)
        #expect(artworkRelated.contains("ArtworkInspectorSectionHeader("))
        #expect(artworkRelated.contains(".keiGlass(18)"))
        #expect(artworkRelated.contains(".keiPanel(16)") == false)
    }

    @Test("Download queue uses a native list container")
    func downloadQueueUsesNativeListContainer() throws {
        let root = try packageRoot()
        let queueView = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/DownloadQueueView.swift"),
            encoding: .utf8
        )
        let nativeList = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Support/NativeDownloadQueueListView.swift"),
            encoding: .utf8
        )

        #expect(queueView.contains("NativeDownloadQueueListView("))
        #expect(nativeList.contains("NSTableView"))
        #expect(nativeList.contains("UICollectionView"))
        #expect(nativeList.contains("NSHostingView"))
        #expect(nativeList.contains("UIHostingConfiguration"))
        #expect(nativeList.contains("keyDown(with event: NSEvent)"))
        #expect(nativeList.contains("UIKeyCommand"))
        #expect(nativeList.contains("lastItemIDs"))
        #expect(nativeList.contains("refreshVisibleRows(in: tableView)"))
        #expect(nativeList.contains("refreshVisibleItems(in: collectionView)"))
        #expect(nativeList.contains("reloadItems(at: [indexPath])") == false)
    }

    @Test("Browsing history uses a native collection container")
    func browsingHistoryUsesNativeCollectionContainer() throws {
        let root = try packageRoot()
        let historyView = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/BrowsingHistoryView.swift"),
            encoding: .utf8
        )
        let nativeCollection = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Support/NativeBrowsingHistoryCollectionView.swift"),
            encoding: .utf8
        )

        #expect(historyView.contains("NativeBrowsingHistoryCollectionView("))
        #expect(historyView.contains("nativeLocalHistoryContent"))
        #expect(historyView.contains("nativePixivHistoryContent"))
        #expect(nativeCollection.contains("NSCollectionView"))
        #expect(nativeCollection.contains("UICollectionView"))
        #expect(nativeCollection.contains("NSCollectionViewDiffableDataSource"))
        #expect(nativeCollection.contains("UICollectionViewDiffableDataSource"))
        #expect(nativeCollection.contains("NSHostingView"))
        #expect(nativeCollection.contains("UIHostingController"))
        #expect(nativeCollection.contains("NativeBrowsingHistoryCollectionLayout"))
        #expect(nativeCollection.contains("refreshVisibleHostedContent(in: collectionView)"))
        #expect(nativeCollection.contains("reloadItems(at: collectionView.indexPathsForVisibleItems)") == false)
        #expect(nativeCollection.contains("reloadItems(at: collectionView?.indexPathsForVisibleItems()") == false)
    }

    @Test("Bookmark tags use a native collection container")
    func bookmarkTagsUseNativeCollectionContainer() throws {
        let root = try packageRoot()
        let bookmarkTagsView = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/BookmarkTagsView.swift"),
            encoding: .utf8
        )
        let nativeCollection = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Support/NativeBookmarkTagCollectionView.swift"),
            encoding: .utf8
        )

        #expect(bookmarkTagsView.contains("NativeBookmarkTagCollectionView("))
        #expect(bookmarkTagsView.contains("bookmarkTagCollectionItems"))
        #expect(bookmarkTagsView.contains("nativeBookmarkTagContent(for: item)"))
        #expect(bookmarkTagsView.contains("LazyVGrid") == false)
        #expect(nativeCollection.contains("NSCollectionView"))
        #expect(nativeCollection.contains("UICollectionView"))
        #expect(nativeCollection.contains("NSCollectionViewDiffableDataSource"))
        #expect(nativeCollection.contains("UICollectionViewDiffableDataSource"))
        #expect(nativeCollection.contains("NativeBookmarkTagCollectionLayout"))
        #expect(nativeCollection.contains("refreshVisibleHostedContent(in: collectionView)"))
        #expect(nativeCollection.contains("reloadItems(at:") == false)
    }

    @Test("Log viewer uses a native list container")
    func logViewerUsesNativeListContainer() throws {
        let root = try packageRoot()
        let logViewer = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/LogViewerView.swift"),
            encoding: .utf8
        )
        let nativeList = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Support/NativeLogEntryListView.swift"),
            encoding: .utf8
        )

        #expect(logViewer.contains("NativeLogEntryListView(entries: filteredEntries)"))
        #expect(logViewer.contains("LogEntryRow(entry: entry)"))
        #expect(logViewer.contains("List(filteredEntries)") == false)
        #expect(nativeList.contains("NSTableView"))
        #expect(nativeList.contains("UICollectionView"))
        #expect(nativeList.contains("NSHostingView"))
        #expect(nativeList.contains("UIHostingConfiguration"))
        #expect(nativeList.contains("lastEntryIDs"))
        #expect(nativeList.contains("refreshVisibleRows(in: tableView)"))
        #expect(nativeList.contains("refreshVisibleItems(in: collectionView)"))
    }

    @Test("Manga watchlist uses a native adaptive grid")
    func mangaWatchlistUsesNativeAdaptiveGrid() throws {
        let root = try packageRoot()
        let watchlist = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/MangaWatchlistView.swift"),
            encoding: .utf8
        )
        let nativeGrid = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Support/NativeAdaptiveGridCollectionView.swift"),
            encoding: .utf8
        )

        #expect(watchlist.contains("NativeAdaptiveGridCollectionView("))
        #expect(watchlist.contains("mangaWatchlistGridItems"))
        #expect(watchlist.contains("mangaWatchlistGridContent(for: item)"))
        #expect(watchlist.contains("LazyVGrid") == false)
        #expect(nativeGrid.contains("NSCollectionView"))
        #expect(nativeGrid.contains("UICollectionView"))
        #expect(nativeGrid.contains("NSCollectionViewDiffableDataSource"))
        #expect(nativeGrid.contains("UICollectionViewDiffableDataSource"))
        #expect(nativeGrid.contains("NativeAdaptiveGridCollectionView<Item: Hashable & Sendable>"))
        #expect(nativeGrid.contains("refreshVisibleHostedContent(in: collectionView)"))
    }

    @Test("Novel watchlist uses a native adaptive grid")
    func novelWatchlistUsesNativeAdaptiveGrid() throws {
        let root = try packageRoot()
        let watchlist = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/NovelWatchlistView.swift"),
            encoding: .utf8
        )

        #expect(watchlist.contains("NativeAdaptiveGridCollectionView("))
        #expect(watchlist.contains("novelWatchlistGridItems"))
        #expect(watchlist.contains("novelWatchlistGridContent(for: item)"))
        #expect(watchlist.contains("LazyVGrid") == false)
    }

    @Test("Work subscriptions use a native adaptive grid")
    func workSubscriptionsUseNativeAdaptiveGrid() throws {
        let root = try packageRoot()
        let subscriptions = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/WorkSubscriptionsView.swift"),
            encoding: .utf8
        )

        #expect(subscriptions.contains("NativeAdaptiveGridCollectionView("))
        #expect(subscriptions.contains("gridLayout"))
        #expect(subscriptions.contains("SubscriptionCard("))
        #expect(subscriptions.contains("LazyVGrid") == false)
        #expect(subscriptions.contains("ScrollView {") == false)
    }

    @Test("Watch later uses a native adaptive grid")
    func watchLaterUsesNativeAdaptiveGrid() throws {
        let root = try packageRoot()
        let watchLater = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/WatchLaterView.swift"),
            encoding: .utf8
        )

        #expect(watchLater.contains("NativeAdaptiveGridCollectionView("))
        #expect(watchLater.contains("gridLayout"))
        #expect(watchLater.contains("WatchLaterCard(item: item)"))
        #expect(watchLater.contains("LazyVGrid") == false)
        #expect(watchLater.contains("ScrollView {") == false)
    }

    @Test("Creator list, search, menu, and drop use native P2 bridges")
    func creatorListSearchMenuAndDropUseNativeP2Bridges() throws {
        let root = try packageRoot()
        let creatorComponents = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/UserPreviewListComponents.swift"),
            encoding: .utf8
        )
        let quickOpenSheet = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/PixivIDOpenSheet.swift"),
            encoding: .utf8
        )
        let pixivDropTarget = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/PixivLinkDropTarget.swift"),
            encoding: .utf8
        )
        let nativeCollection = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Support/NativeCreatorPreviewCollectionView.swift"),
            encoding: .utf8
        )
        let nativeSearch = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Support/SearchFieldNSView.swift"),
            encoding: .utf8
        )
        let enhancedMenu = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Support/EnhancedMenuNSView.swift"),
            encoding: .utf8
        )
        let nativeDrop = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Support/DragDropNSView.swift"),
            encoding: .utf8
        )

        #expect(creatorComponents.contains("NativeCreatorPreviewCollectionView("))
        #expect(creatorComponents.contains("NativeSearchField("))
        #expect(creatorComponents.contains(".frame(maxWidth: 560)"))
        #expect(creatorComponents.contains("EnhancedMenu("))
        #expect(creatorComponents.contains("nativeCreatorPreviewContent"))
        #expect(quickOpenSheet.contains("CustomDropTarget("))
        #expect(quickOpenSheet.contains("handleNativeDrop"))
        #expect(pixivDropTarget.contains("firstSupportedURL(from rawTexts: [String])"))
        #expect(nativeCollection.contains("NSCollectionView"))
        #expect(nativeCollection.contains("UICollectionView"))
        #expect(nativeCollection.contains("NSCollectionViewDiffableDataSource"))
        #expect(nativeCollection.contains("UICollectionViewDiffableDataSource"))
        #expect(nativeCollection.contains("NSHostingView"))
        #expect(nativeCollection.contains("UIHostingController"))
        #expect(nativeSearch.contains("NSSearchField"))
        #expect(nativeSearch.contains("UISearchTextField"))
        #expect(enhancedMenu.contains("NSMenu"))
        #expect(enhancedMenu.contains("menuItem.target = target"))
        #expect(enhancedMenu.contains("case checkFollowVisibility"))
        #expect(nativeDrop.contains("NSDraggingInfo"))
        #expect(nativeDrop.contains("NativeDropPayload"))
        #expect(nativeDrop.contains("UTType.utf8PlainText"))
    }

    @Test("Search surfaces use native fields and OS 26 glass chrome")
    func searchSurfacesUseNativeFieldsAndOS26GlassChrome() throws {
        let root = try packageRoot()
        let savedSearches = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/SavedSearchesView.swift"),
            encoding: .utf8
        )
        let searchFilters = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/SearchFiltersView.swift"),
            encoding: .utf8
        )
        let quickOpenSheet = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/PixivIDOpenSheet.swift"),
            encoding: .utf8
        )
        let imageSourceSearch = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/ImageSourceSearchSheet.swift"),
            encoding: .utf8
        )
        let creatorComponents = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/UserPreviewListComponents.swift"),
            encoding: .utf8
        )

        #expect(savedSearches.contains("NativeSearchField("))
        #expect(savedSearches.contains("savedSearchLibraryField"))
        #expect(savedSearches.contains("libraryActionRail"))
        #expect(savedSearches.contains("GlassEffectContainer(spacing: 8)"))
        #expect(savedSearches.contains(".keiInteractiveGlass(16)"))
        #expect(savedSearches.contains(".textFieldStyle(.roundedBorder)") == false)
        #expect(savedSearches.contains(".buttonStyle(.bordered)") == false)

        #expect(searchFilters.contains(".keiGlass(18)"))
        #expect(searchFilters.contains("GlassEffectContainer(spacing: 8)"))
        #expect(searchFilters.contains(".buttonStyle(.glassProminent)"))
        #expect(searchFilters.contains(".textFieldStyle(.roundedBorder)") == false)

        #expect(quickOpenSheet.contains("NativeSearchField("))
        #expect(quickOpenSheet.contains(".keiInteractiveGlass(14)"))
        #expect(quickOpenSheet.contains(".background(.quaternary") == false)

        #expect(imageSourceSearch.contains("private func resultRow"))
        #expect(imageSourceSearch.contains("LazyVStack(spacing: 8)"))
        #expect(imageSourceSearch.contains(".keiInteractiveGlass(16)"))
        #expect(imageSourceSearch.contains("List(results)") == false)

        #expect(creatorComponents.contains(".buttonStyle(.borderless)") == false)
        #expect(creatorComponents.contains(".buttonStyle(.borderedProminent)") == false)
        #expect(creatorComponents.contains(".buttonStyle(.glassProminent)"))
    }

    @Test("Creator cards use adaptive OS 26 glass actions")
    func creatorCardsUseAdaptiveOS26GlassActions() throws {
        let root = try packageRoot()
        let creatorCard = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/UserPreviewCard.swift"),
            encoding: .utf8
        )
        let nativeCollection = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Support/NativeCreatorPreviewCollectionView.swift"),
            encoding: .utf8
        )

        #expect(creatorCard.contains("GlassEffectContainer(spacing: 8)"))
        #expect(creatorCard.contains("ViewThatFits(in: .horizontal)"))
        #expect(creatorCard.contains("CreatorCardButtonDisplayStyle"))
        #expect(creatorCard.contains(".buttonStyle(.glass)"))
        #expect(creatorCard.contains(".buttonBorderShape(.capsule)"))
        #expect(creatorCard.contains(".truncationMode(.middle)"))
        #expect(nativeCollection.contains("let minimumWidth: CGFloat = 300"))
    }

    @Test("Creator profile shelves use native horizontal collection bridges")
    func creatorProfileShelvesUseNativeHorizontalCollectionBridges() throws {
        let root = try packageRoot()
        let recentWorks = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/UserProfileRecentWorksSection.swift"),
            encoding: .utf8
        )
        let relatedCreators = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/UserProfileRelatedCreatorsSection.swift"),
            encoding: .utf8
        )
        let nativeCollection = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Support/NativeCreatorPreviewCollectionView.swift"),
            encoding: .utf8
        )

        #expect(recentWorks.contains("NativeCreatorPreviewCollectionView("))
        #expect(recentWorks.contains("private var artworkShelfLayout: NativeCreatorPreviewCollectionLayout"))
        #expect(recentWorks.contains(".horizontalShelf(itemWidth: cardWidth, itemHeight: cardHeight)"))
        #expect(recentWorks.contains("artworkShelfLayout.viewportHeight ?? cardHeight"))
        #expect(recentWorks.contains(".frame(height: artworkShelfHeight)"))
        #expect(recentWorks.contains("artworkShelfItems"))
        #expect(recentWorks.contains("ScrollView(.horizontal)") == false)
        #expect(recentWorks.contains("LazyHStack") == false)

        #expect(relatedCreators.contains("NativeCreatorPreviewCollectionView("))
        #expect(relatedCreators.contains("private var relatedCreatorShelfLayout: NativeCreatorPreviewCollectionLayout"))
        #expect(relatedCreators.contains(".horizontalShelf(itemWidth: relatedCreatorShelfItemWidth, itemHeight: cardHeight)"))
        #expect(relatedCreators.contains("relatedCreatorShelfLayout.viewportHeight ?? cardHeight"))
        #expect(relatedCreators.contains(".frame(height: relatedCreatorShelfHeight)"))
        #expect(relatedCreators.contains("relatedCreatorShelfItems"))
        #expect(relatedCreators.contains("ScrollView(.horizontal)") == false)
        #expect(relatedCreators.contains("LazyHStack") == false)

        #expect(nativeCollection.contains("case artwork(PixivArtwork)"))
        #expect(nativeCollection.contains("case horizontalShelf(itemWidth: CGFloat, itemHeight: CGFloat)"))
        #expect(nativeCollection.contains("var viewportHeight: CGFloat?"))
        #expect(nativeCollection.contains("flowLayout.scrollDirection = parent.layout.nsScrollDirection"))
        #expect(nativeCollection.contains("flowLayout.scrollDirection = parent.layout.uiScrollDirection"))
        #expect(nativeCollection.contains("refreshVisibleHostedContent(in: collectionView)"))
        #expect(nativeCollection.contains("reloadItems(at:") == false)
    }

    private func packageRoot() throws -> URL {
        var candidate = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        for _ in 0..<8 {
            if FileManager.default.fileExists(atPath: candidate.appending(path: "Package.swift").path(percentEncoded: false)) {
                return candidate
            }
            candidate.deleteLastPathComponent()
        }
        // Fallback: walk up from this test file's on-disk location so the suite
        // works under both SwiftPM (`swift test`) and Xcode (`xcodebuild test`),
        // since the latter sets the current directory inside DerivedData.
        var fileBased = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        for _ in 0..<10 {
            if FileManager.default.fileExists(atPath: fileBased.appending(path: "Package.swift").path(percentEncoded: false)) {
                return fileBased
            }
            fileBased.deleteLastPathComponent()
        }
        throw NativeBoundaryError.packageRootNotFound
    }

    private func sourceFiles(in root: URL) throws -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return try enumerator.compactMap { item in
            guard let url = item as? URL else { return nil }
            let values = try url.resourceValues(forKeys: [.isRegularFileKey])
            return values.isRegularFile == true ? url : nil
        }
    }
}

private enum NativeBoundaryError: Error {
    case packageRootNotFound
}
