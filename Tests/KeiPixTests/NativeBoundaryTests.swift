import CoreGraphics
import Foundation
import Testing
@testable import KeiPix

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
        #expect(app.contains(".automaticKeyViewLoop()"))
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

    @Test("App targets use the Icon Composer app icon package")
    func appTargetsUseIconComposerAppIconPackage() throws {
        let root = try packageRoot()
        let project = try String(
            contentsOf: root.appending(path: "project.yml"),
            encoding: .utf8
        )
        let iconPackage = root.appending(path: "Sources/KeiPix/Resources/keipixiv.icon", directoryHint: .isDirectory)
        let iconJSONURL = iconPackage.appending(path: "icon.json")
        let iconData = try Data(contentsOf: iconJSONURL)
        let iconJSON = try #require(JSONSerialization.jsonObject(with: iconData) as? [String: Any])
        let supportedPlatforms = try #require(iconJSON["supported-platforms"] as? [String: Any])
        let circlePlatforms = try #require(supportedPlatforms["circles"] as? [String])

        #expect(project.components(separatedBy: "ASSETCATALOG_COMPILER_APPICON_NAME: keipixiv").count == 4)
        #expect(project.contains("ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon") == false)
        #expect(FileManager.default.fileExists(atPath: iconPackage.path(percentEncoded: false)))
        #expect(FileManager.default.fileExists(atPath: iconJSONURL.path(percentEncoded: false)))
        #expect(FileManager.default.fileExists(atPath: iconPackage.appending(path: "Assets/1.png").path(percentEncoded: false)))
        #expect(FileManager.default.fileExists(atPath: iconPackage.appending(path: "Assets/2.png").path(percentEncoded: false)))
        #expect(FileManager.default.fileExists(atPath: iconPackage.appending(path: "Assets/new-logo-2025-0122-en.svg").path(percentEncoded: false)))
        #expect(supportedPlatforms["squares"] as? String == "shared")
        #expect(circlePlatforms.contains("watchOS"))
    }

    @Test("Simulator run scripts cover iOS and iPadOS schemes")
    func simulatorRunScriptsCoverMobileSchemes() throws {
        let root = try packageRoot()
        let runnerURL = root.appending(path: "script/build_and_run_simulator.sh")
        let iOSURL = root.appending(path: "script/build_and_run_ios.sh")
        let iPadOSURL = root.appending(path: "script/build_and_run_ipados.sh")
        let os26OpenerURL = root.appending(path: "script/os26/open_simulator_window.sh")
        let os27OpenerURL = root.appending(path: "script/os27/open_device_hub_window.sh")
        let os27IOSURL = root.appending(path: "script/os27/build_and_run_ios.sh")
        let os27IPadOSURL = root.appending(path: "script/os27/build_and_run_ipados.sh")
        let os27DocumentationURL = root.appending(path: "script/os27/developer_documentation_status.sh")
        let runner = try String(contentsOf: runnerURL, encoding: .utf8)
        let iOSWrapper = try String(contentsOf: iOSURL, encoding: .utf8)
        let iPadOSWrapper = try String(contentsOf: iPadOSURL, encoding: .utf8)
        let os26Opener = try String(contentsOf: os26OpenerURL, encoding: .utf8)
        let os27Opener = try String(contentsOf: os27OpenerURL, encoding: .utf8)
        let os27IOSWrapper = try String(contentsOf: os27IOSURL, encoding: .utf8)
        let os27IPadOSWrapper = try String(contentsOf: os27IPadOSURL, encoding: .utf8)
        let os27Documentation = try String(contentsOf: os27DocumentationURL, encoding: .utf8)

        #expect(FileManager.default.fileExists(atPath: runnerURL.path(percentEncoded: false)))
        #expect(FileManager.default.fileExists(atPath: iOSURL.path(percentEncoded: false)))
        #expect(FileManager.default.fileExists(atPath: iPadOSURL.path(percentEncoded: false)))
        #expect(FileManager.default.fileExists(atPath: os26OpenerURL.path(percentEncoded: false)))
        #expect(FileManager.default.fileExists(atPath: os27OpenerURL.path(percentEncoded: false)))
        #expect(FileManager.default.fileExists(atPath: os27IOSURL.path(percentEncoded: false)))
        #expect(FileManager.default.fileExists(atPath: os27IPadOSURL.path(percentEncoded: false)))
        #expect(FileManager.default.fileExists(atPath: os27DocumentationURL.path(percentEncoded: false)))
        #expect(runner.contains("KeiPix iOS"))
        #expect(runner.contains("KeiPix iPadOS"))
        #expect(runner.contains("com.keipix.client.ios"))
        #expect(runner.contains("com.keipix.client.ipad"))
        #expect(runner.contains("xcodegen generate"))
        #expect(runner.contains("-destination \"platform=iOS Simulator,id=$SIMULATOR_ID\""))
        #expect(runner.contains("xcrun simctl install \"$SIMULATOR_ID\""))
        #expect(runner.contains("xcrun simctl launch --terminate-running-process \"$SIMULATOR_ID\" \"$BUNDLE_ID\""))
        #expect(runner.contains("open_developer_device_window"))
        #expect(runner.contains("script/os27/open_device_hub_window.sh"))
        #expect(runner.contains("script/os26/open_simulator_window.sh"))
        #expect(runner.contains("open -a Simulator") == false)
        #expect(runner.contains("KEIPIX_OPEN_DEVICE_WINDOW"))
        #expect(runner.contains("KEIPIX_DEVICE_HUB_APP"))
        #expect(runner.contains("KEIPIX_SIMULATOR_APP"))
        #expect(runner.contains("KEIPIX_IOS_SIMULATOR_RUNTIME"))
        #expect(runner.contains("KEIPIX_IPADOS_SIMULATOR_RUNTIME"))
        #expect(runner.contains("runtime_device_list_name"))
        #expect(runner.contains("KEIPIX_LAUNCH_TIMEOUT_SECONDS"))
        #expect(runner.contains("KEIPIX_SCREENSHOT_TIMEOUT_SECONDS"))
        #expect(os27Opener.contains("DeviceHub.app"))
        #expect(os27Opener.contains("com.apple.dt.Devices"))
        #expect(os27IOSWrapper.contains("KeiPix-iOS-OS27"))
        #expect(os27IOSWrapper.contains("com.apple.CoreSimulator.SimRuntime.iOS-27-0"))
        #expect(os27IOSWrapper.contains("KEIPIX_VERIFY_SETTLE_SECONDS"))
        #expect(os27IPadOSWrapper.contains("KeiPix-iPadOS-OS27"))
        #expect(os27IPadOSWrapper.contains("com.apple.CoreSimulator.SimRuntime.iOS-27-0"))
        #expect(os27IPadOSWrapper.contains("KEIPIX_VERIFY_SETTLE_SECONDS"))
        #expect(os27Documentation.contains("IDEDeveloperDocumentationSelectedDuringFirstLaunch"))
        #expect(os27Documentation.contains("CoreDocumentation.framework"))
        #expect(os27Documentation.contains("DNTDocumentationModel.framework"))
        #expect(os27Documentation.contains("IDEDocumentation.framework"))
        #expect(os27Documentation.contains("DeveloperDocumentation is not exposed yet"))
        #expect(os26Opener.contains("com.apple.iphonesimulator"))
        #expect(os26Opener.contains("CurrentDeviceUDID"))
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
        let mobileBottomTabCustomization = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/MobileBottomTabCustomizationView.swift"),
            encoding: .utf8
        )
        let mobileBottomTabConfiguration = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Models/MobileBottomTabConfiguration.swift"),
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
        let storePixivLinks = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Stores/KeiPixStore+PixivLinks.swift"),
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
        #expect(contentView.contains("@State private var isCompactArtworkDetailPresented = false"))
        #expect(contentView.contains("@State private var compactArtworkDetailPresentationToken = 0"))
        #expect(contentView.contains("@State private var isArtworkDetailPanelUserEnabled = false"))
        #expect(contentView.contains("toggleArtworkDetailPanel(hidesSidebar: showsSidebarToggle)"))
        #expect(contentView.contains("toggleSpotlightDetailPanel(hidesSidebar: showsSidebarToggle)"))
        #expect(contentView.contains("isArtworkDetailPanelUserEnabled ? L10n.hideDetails : L10n.showDetails"))
        #expect(contentView.contains("isSpotlightDetailPanelUserEnabled ? L10n.hideDetails : L10n.showDetails"))
        #expect(contentView.contains("presentArtworkDetail(for: artwork, usesCompactSheet: true)"))
        #expect(contentView.contains("deferCompactArtworkDetailPresentation(for: artwork)"))
        #expect(contentView.contains("await Task.yield()"))
        #expect(contentView.contains("guard compactArtworkDetailPresentationToken == requestID"))
        #expect(contentView.contains("compactArtworkDetailPresentationToken += 1"))
        #expect(contentView.contains(".sheet(isPresented: compactArtworkDetailBinding)"))
        #expect(contentView.contains("private func iPadArtworkDetailSheet(close: @escaping () -> Void) -> some View"))
        #expect(contentView.contains("private var compactArtworkDetailBinding: Binding<Bool>"))
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
        #expect(contentView.contains("guard usesCompactSheet || store.selectedRoute.usesArtworkFeed else { return }"))
        #expect(contentView.contains("splitColumnVisibility = .detailOnly"))
        #expect(contentView.contains("dismissArtworkDetail(clearSelection: true)"))
        #expect(contentView.contains("dismissSpotlightDetail(clearSelection: true)"))
        #expect(contentView.contains("store.prepareReaderWindow(for: artwork)"))
        #expect(contentView.contains(".sheet(isPresented: readerBinding)"))
        #expect(contentView.contains(".fullScreenCover(isPresented: readerBinding)") == false)
        #expect(contentView.contains(".os26SheetChrome(.reader)"))
        #expect(contentView.contains("NativeToolbarMenuButton("))
        #expect(contentView.contains("columnWidth: .iPadOS"))
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
        #expect(contentView.contains("if showsGalleryLayoutPicker(showsSidebarToggle: showsSidebarToggle)"))
        #expect(contentView.contains("private func showsGalleryLayoutPicker(showsSidebarToggle: Bool) -> Bool"))
        #expect(contentView.contains("showsSidebarToggle && store.selectedRoute.usesArtworkFeed"))
        #expect(contentView.contains("galleryLayoutAdaptation: galleryLayoutAdaptation(showsSidebarToggle: showsSidebarToggle)"))
        #expect(contentView.contains("private func galleryLayoutAdaptation(showsSidebarToggle: Bool) -> GalleryLayoutAdaptation"))
        #expect(contentView.contains("return currentMobilePlatform == .pad ? .portraitTabletMasonry : .phoneTwoColumnMasonry"))
        #expect(contentView.contains("systemImage: \"ellipsis.circle\",\n                            accessibilityLabel: L10n.appControls"))
        #expect(contentView.contains("title: L10n.galleryLayout"))
        #expect(contentView.contains("title: L10n.appControls"))
        #expect(contentView.contains("private var galleryLayoutMenu: NativeToolbarMenu"))
        #expect(contentView.contains("private func artworkActionsMenu(showsSidebarToggle: Bool) -> NativeToolbarMenu"))
        #expect(contentView.contains("menu: artworkActionsMenu(showsSidebarToggle: showsSidebarToggle)"))
        #expect(contentView.contains("if showsSidebarToggle {\n            primaryItems.insert("))
        #expect(contentView.contains("presentation: .palette"))
        #expect(contentView.contains("private var showsArtworkActionsMenu: Bool"))
        #expect(contentView.contains("accessibilityLabel: L10n.currentArtwork"))
        #expect(contentView.contains("selectedArtworkMenuSystemImage"))
        #expect(contentView.contains("IPadToolbarMenuAction.toggleBookmark"))
        #expect(contentView.contains("IPadToolbarMenuAction.downloadSelectedArtwork"))
        #expect(contentView.contains("IPadToolbarMenuAction.searchImageSource"))
        #expect(contentView.contains("IPadToolbarMenuAction.openCreatorProfile"))
        #expect(contentView.contains("IPadToolbarMenuAction.openArtworkDetails"))
        #expect(contentView.contains("IPadToolbarMenuAction.openReaderWindow"))
        #expect(contentView.contains("IPadToolbarMenuAction.openSelectedArtworkInPixiv"))
        #expect(contentView.contains("IPadToolbarMenuAction.copySelectedArtworkLink"))
        #expect(contentView.contains("store.prepareSelectedReaderWindow()"))
        #expect(contentView.contains("store.copySelectedArtworkLink()"))
        #expect(contentView.contains("private func canSelectAdjacentArtwork(delta: Int) -> Bool"))
        #expect(contentView.contains("private var appControlsMenu: NativeToolbarMenu"))
        #expect(contentView.contains("presentationStyle: .popover") == false)
        #expect(contentView.contains("handleNativeToolbarMenuAction"))
        #expect(contentView.contains("subtitle: store.galleryLayoutMode.title") == false)
        #expect(contentView.contains("paletteTitle: L10n.quickOpenLink"))
        #expect(contentView.contains("paletteTitle: L10n.quickPixivID"))
        #expect(contentView.contains("paletteTitle: L10n.quickImageSearch") == false)
        #expect(contentView.contains("PixivIDOpenSheet("))
        #expect(contentView.contains("showStatus: showStatus"))
        #expect(contentView.contains("prepareForOpen: dismissTransientArtworkPresentationBeforeGlobalOpen"))
        #expect(contentView.contains("private func dismissTransientArtworkPresentationBeforeGlobalOpen()"))
        #expect(contentView.contains("pendingCompactArtworkDetailAfterPixivIDOpen"))
        #expect(contentView.contains(".onChange(of: isPixivIDOpenPresented)"))
        #expect(contentView.contains("includesOuterPadding: false"))
        #expect(contentView.contains("feedbackOverlayBottomPadding"))
        #expect(contentView.contains("if store.errorMessage == nil {\n            showStatus(message)\n        }"))
        #expect(storePixivLinks.contains("errorMessage = L10n.noPixivLinkInClipboard") == false)
        #expect(contentView.contains("L10n.showContentBadges"))
        #expect(contentView.contains("L10n.hideMutedContent"))
        #expect(contentView.contains("L10n.hideAIArtworks"))
        #expect(contentView.contains("L10n.hideR18Artworks"))
        #expect(contentView.contains("L10n.hideR18GArtworks"))
        #expect(contentView.contains("L10n.maskSensitivePreviews"))
        #expect(contentView.contains("IPadToolbarMenuAction.privacyMode") == false)
        #expect(contentView.contains("store.setPrivacyModeEnabled") == false)
        #expect(contentView.contains("store.setGalleryLayoutMode(mode)"))
        #expect(contentView.contains("NavigationSplitView(columnVisibility: $splitColumnVisibility)"))
        #expect(contentView.contains("SidebarView(\n                store: store,\n                selection: $selectedSidebarItem,\n                columnWidth: .iPadOS,\n                includesSettingsDestination: true"))
        #expect(contentView.contains("private func iPadSidebarRow(") == false)
        #expect(contentView.contains("private func toggleIPadSidebar()"))
        #expect(contentView.contains("Label(sidebarVisibilityTitle, systemImage: \"sidebar.leading\")"))
        #expect(contentView.contains("systemName: \"checkmark\"") == false)
        #expect(contentView.contains("private var sidebarToggleButton: some View") == false)
        #expect(contentView.contains("usesLandscapeSidebar(for size: CGSize)") == false)
        #expect(contentView.contains("let layout = MobileWorkspaceLayout(size: geometry.size, platform: currentMobilePlatform)"))
        #expect(contentView.contains("if layout.usesLandscapeSidebar"))
        #expect(contentView.contains("layout.usesCustomNavigationTabs"))
        #expect(contentView.contains("layout.usesDedicatedSearchTab"))
        #expect(contentView.contains("@AppStorage(\"mobilePortraitShortcutRouteIDs\")") == false)
        #expect(contentView.contains("@AppStorage(\"mobileBottomTabItemIDs\")"))
        #expect(contentView.contains("mobileBottomTabDefaultRouteIDs"))
        #expect(contentView.contains("@AppStorage(\"mobileBottomTabLaunchTarget\")"))
        #expect(contentView.contains("@AppStorage(\"mobileBottomTabRemembersLastRoute\")"))
        #expect(contentView.contains("@AppStorage(\"mobileBottomTabLastKind\")"))
        #expect(contentView.contains("@AppStorage(\"mobileBottomTabRememberedRouteIDs\")"))
        #expect(contentView.contains("private var portraitShortcutsTab: some View") == false)
        #expect(mobileBottomTabCustomization.contains("struct MobileBottomTabCustomizationView: View"))
        #expect(mobileBottomTabCustomization.contains("@Binding var defaultRoutes: [MobileBottomTabKind: PixivRoute]"))
        #expect(mobileBottomTabCustomization.contains("@Binding var launchTarget: MobileBottomTabLaunchTarget"))
        #expect(mobileBottomTabCustomization.contains("@Binding var remembersLastRoute: Bool"))
        #expect(mobileBottomTabCustomization.contains("MobileBottomTabConfiguration.replacingDefaultRoute("))
        #expect(mobileBottomTabCustomization.contains(".keiGlass(24)"))
        #expect(mobileBottomTabCustomization.contains("L10n.mobileBottomTabLaunchTarget"))
        #expect(mobileBottomTabCustomization.contains("L10n.rememberMobileBottomTabPages"))
        #expect(mobileBottomTabCustomization.contains("L10n.defaultTabPages"))
        #expect(mobileBottomTabCustomization.contains("L10n.bottomTabsHint"))
        #expect(mobileBottomTabCustomization.contains("ForEach(MobileBottomTabLaunchTarget.allCases)"))
        #expect(mobileBottomTabCustomization.contains("ForEach(MobileBottomTabKind.allCases)"))
        #expect(contentView.contains("private static let portraitShortcutContentMaxWidth: CGFloat = 860") == false)
        #expect(contentView.contains("if layout.usesCustomNavigationTabs {\n                ForEach(MobileBottomTabKind.allCases)"))
        #expect(contentView.contains("value: iPadTab.mobile(kind)"))
        #expect(contentView.contains("mobileSectionTab(kind)"))
        #expect(contentView.contains("guard selectedTab == .mobile(kind) else { return }"))
        #expect(contentView.contains("Tab(L10n.search, systemImage: \"magnifyingglass\", value: .search, role: .search)"))
        #expect(contentView.contains("compactSearchTab"))
        #expect(contentView.contains(".navigationBarTitleDisplayMode(.inline)"))
        #expect(contentView.contains("Tab(L10n.shortcuts") == false)
        #expect(contentView.contains("case .shortcuts") == false)
        #expect(contentView.contains("selectedTab = .feed"))
        #expect(contentView.contains("L10n.customizeBottomTabs"))
        #expect(contentView.contains("case settings"))
        #expect(contentView.contains("ToolbarItem(placement: .topBarLeading)"))
        #expect(contentView.contains("private var routeMenu: some View"))
        #expect(contentView.contains("ForEach(routeMenuSections)"))
        #expect(contentView.contains("private var routeMenuSections: [MobileRouteMenuSection]"))
        #expect(contentView.contains("return activeMobileTabKind.menuSections"))
        #expect(contentView.contains("pinnedItems: isCompactCustomTabRootActive ? mobileBottomTabItems : []") == false)
        #expect(contentView.contains("includesDedicatedSearch: isCompactCustomTabRootActive") == false)
        #expect(contentView.contains("private func showsRouteMenu(showsSidebarToggle: Bool) -> Bool"))
        #expect(contentView.contains("showsSidebarToggle || (isCompactCustomTabRootActive && selectedTab != .search)"))
        #expect(contentView.contains("private var activeMobileTabKind: MobileBottomTabKind"))
        #expect(contentView.contains("private func mobileDefaultRoute(for kind: MobileBottomTabKind) -> PixivRoute"))
        #expect(contentView.contains("private func mobileRoute(for kind: MobileBottomTabKind) -> PixivRoute"))
        #expect(contentView.contains("private func applyMobileBottomTabLaunchTargetIfNeeded()"))
        #expect(contentView.contains("private func recordMobileBottomTabRouteIfNeeded(_ route: PixivRoute)"))
        #expect(contentView.contains("skipsNextCompactTabSelectionHandler"))
        #expect(contentView.contains("private func selectCompactSearchTab()"))
        #expect(contentView.contains("MobileBottomTabConfiguration.storageID(for: routeMap)"))
        #expect(mobileBottomTabConfiguration.contains("struct MobileRouteMenuSection: Identifiable"))
        #expect(mobileBottomTabConfiguration.contains("enum MobileRouteMenuConfiguration"))
        #expect(mobileBottomTabConfiguration.contains("enum MobileBottomTabKind"))
        #expect(mobileBottomTabConfiguration.contains("enum MobileBottomTabLaunchTarget"))
        #expect(mobileBottomTabConfiguration.contains("static let defaultLaunchTarget = MobileBottomTabLaunchTarget.lastUsed"))
        #expect(mobileBottomTabConfiguration.contains("static let defaultRemembersLastRoute = true"))
        #expect(mobileBottomTabConfiguration.contains("static func recordingRememberedRoute("))
        #expect(mobileBottomTabConfiguration.contains("enum MobileSearchTabConfiguration"))
        #expect(mobileBottomTabConfiguration.contains("static let routes: [PixivRoute] = ["))
        #expect(mobileBottomTabConfiguration.contains(".searchUsers"))
        #expect(mobileBottomTabConfiguration.contains(".novelSearch"))
        #expect(mobileBottomTabConfiguration.contains(".trendingTags"))
        #expect(mobileBottomTabConfiguration.contains(".savedSearches"))
        #expect(mobileBottomTabConfiguration.contains("case .bookmarks: L10n.mobileBookmarkTab"))
        #expect(mobileBottomTabConfiguration.contains("static let fixedKinds = MobileBottomTabKind.allCases"))
        #expect(mobileBottomTabConfiguration.contains("MobileRouteMenuConfiguration.sections(for: self)"))
        #expect(mobileBottomTabConfiguration.contains("id: \"illustration-search\"") == false)
        #expect(mobileBottomTabConfiguration.contains("id: \"manga-ranking\""))
        #expect(mobileBottomTabConfiguration.contains("id: \"novel-ranking\""))
        #expect(mobileBottomTabConfiguration.contains("id: \"bookmarks-library\""))
        #expect(mobileBottomTabConfiguration.contains("let pinnedRoutes = Set(pinnedItems.compactMap(\\.route))") == false)
        #expect(mobileBottomTabConfiguration.contains("let excludedRoutes = includesDedicatedSearch ? pinnedRoutes.union([.search]) : pinnedRoutes") == false)
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
        #expect(dashboardView.contains("private enum DiscoveryDashboardRouteSectionLayout: Equatable"))
        #expect(dashboardView.contains("case compactPreview"))
        #expect(dashboardView.contains(".keiGlass(layout.cornerRadius)"))
        #expect(dashboardView.contains(".keiInteractiveGlass(layout == .compactPreview ? 16 : 18)"))
        #expect(dashboardView.contains(".background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10") == false)
        #expect(dashboardView.contains(".background(Color.secondary.opacity(0.07)") == false)
        #expect(dashboardView.contains("backgroundStyle") == false)
        #expect(trendingStrip.contains("@State private var hasAttemptedLoad = false"))
        #expect(trendingStrip.contains("hasAttemptedLoad && isLoading == false && tags.isEmpty"))
        #expect(trendingStrip.contains("GlassEffectContainer(spacing: 12)"))
        #expect(trendingStrip.contains(".keiGlass(22)"))
        #expect(trendingStrip.contains(".buttonStyle(.glass)"))
        #expect(trendingStrip.contains(".buttonStyle(.bordered)") == false)
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
        #expect(nativeToolbarMenu.contains("preferredElementSize: presentation == .palette ? .medium : .automatic"))
        #expect(nativeToolbarMenu.contains("UIMenuDisplayPreferences()"))
        #expect(nativeToolbarMenu.contains("preferences.maximumNumberOfTitleLines = 2"))
        #expect(nativeToolbarMenu.contains("paletteTitle: String? = nil"))
        #expect(nativeToolbarMenu.contains("prefersPaletteTitle: presentation == .palette"))
        #expect(nativeToolbarMenu.contains("prefersPaletteTitle ? (paletteTitle ?? title) : title"))
        #expect(nativeToolbarMenu.contains("enum PresentationStyle") == false)
        #expect(nativeToolbarMenu.contains("case popover") == false)
        #expect(nativeToolbarMenu.contains("button.showsMenuAsPrimaryAction = false") == false)
        #expect(nativeToolbarMenu.contains("button.menu = nil") == false)
        #expect(nativeToolbarMenu.contains("UIPopoverPresentationControllerDelegate") == false)
        #expect(nativeToolbarMenu.contains("NativeToolbarMenuPopoverController") == false)
        #expect(nativeToolbarMenu.contains("NativeToolbarMenuQuickActionControl") == false)
        #expect(nativeToolbarMenu.contains("NativeToolbarMenuRowControl") == false)
        #expect(nativeToolbarMenu.contains("subtitle: String? = nil"))
        #expect(nativeToolbarMenu.contains("menu.subtitle = subtitle"))
        #expect(nativeToolbarMenu.contains("UIMenu("))
        #expect(nativeToolbarMenu.contains("UIAction("))

        #expect(spotlightView.contains("var openArticle: ((PixivSpotlightArticle) -> Void)?"))
        #expect(spotlightView.contains("private var paginationFooter: some View"))
        #expect(spotlightView.contains("OS26PaginationFooter("))
        #expect(spotlightView.contains("loadMoreFromPaginationFooter()"))
        #expect(spotlightView.contains(".onAppear {\n                                    loadMoreIfNeeded(after: article)\n                                }"))
        #expect(spotlightView.contains("private func loadMoreIfNeeded(after article: PixivSpotlightArticle)"))
        #expect(spotlightView.contains("openArticle?(article)"))
        #expect(spotlightView.contains("Task { await loadMore(showFeedback: true) }") == false)
        #expect(spotlightView.contains(".help(L10n.loadMoreSpotlightArticles)") == false)
        #expect(spotlightView.contains(".gridCellColumns(loadMoreSpan)") == false)
        #expect(spotlightView.contains("private var loadMoreSpan") == false)
        #expect(spotlightView.contains("@Environment(\\.horizontalSizeClass) private var horizontalSizeClass"))
        #expect(spotlightView.contains("private var usesCompactSpotlightChrome: Bool"))
        #expect(spotlightView.contains("private var collectionModePicker: some View"))
        #expect(spotlightView.contains("compactCollectionMenu"))
        #expect(spotlightView.contains("fixedCollectionMode: SpotlightArticleCollectionMode? = nil"))
        #expect(spotlightView.contains("if usesCompactSpotlightChrome == false, fixedCollectionMode == nil"))
        #expect(spotlightView.contains("if usesCompactSpotlightChrome, store.session != nil, fixedCollectionMode == nil"))
        #expect(spotlightView.contains("if collectionMode.supportsCategoryFilter, usesCompactSpotlightChrome == false"))
        #expect(spotlightView.contains(".accessibilityLabel(\"\\(L10n.spotlightCollection): \\(collectionMode.title)\""))
        #expect(spotlightView.contains("title: title,\n            status: spotlightNavigationStatus\n        )"))
        #expect(spotlightView.contains("displayedArticles.count.formatted()"))
        #expect(spotlightView.contains("L10n.savedArticleCountFormat") == false)
        #expect(spotlightView.contains("L10n.articleHistoryCountFormat") == false)
        #expect(spotlightView.contains("statusSystemImage: \"newspaper\"") == false)
        #expect(spotlightDetailView.contains("var showsNavigationChrome = true"))
        #expect(spotlightDetailView.contains("showsNavigationChrome ? (article.pureTitle.isEmpty ? L10n.spotlight : article.pureTitle) : \"\""))
    }

    @Test("Mobile customizable tabs ship localized labels")
    func mobileCustomizableTabsShipLocalizedLabels() throws {
        let root = try packageRoot()
        let navigationCatalog = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Resources/Navigation.xcstrings"),
            encoding: .utf8
        )
        let l10n = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Support/L10n.swift"),
            encoding: .utf8
        )

        for key in [
            "Bottom Tabs",
            "Bookmark Tab",
            "Customize Bottom Tabs",
            "Reset Bottom Tabs",
            "Default Tab Pages",
            "Choose the default page for each iPhone and iPad portrait tab."
        ] {
            #expect(navigationCatalog.contains("\"\(key)\""), "\(key) should be localized for the mobile navigation UI")
        }

        #expect(navigationCatalog.contains("\"value\": \"标签栏\""))
        #expect(navigationCatalog.contains("\"value\": \"书签\""))
        #expect(navigationCatalog.contains("\"value\": \"自定义标签栏\""))
        #expect(l10n.contains("static var mobileBookmarkTab: String"))
        #expect(l10n.contains("private enum L10nTable"))
        #expect(l10n.contains("static let navigation = \"Navigation\""))
        #expect(l10n.contains("static func text(_ key: String, table: String? = nil)"))
        #expect(l10n.contains("table: L10nTable.navigation"))
    }

    @Test("Mobile workspace keeps portrait and phone layouts compact")
    func mobileWorkspaceKeepsPortraitAndPhoneLayoutsCompact() {
        let iPhonePortrait = MobileWorkspaceLayout(size: CGSize(width: 393, height: 852), platform: .phone)
        let iPhoneLandscape = MobileWorkspaceLayout(size: CGSize(width: 852, height: 393), platform: .phone)
        let iPadPortrait = MobileWorkspaceLayout(size: CGSize(width: 834, height: 1194), platform: .pad)
        let iPadLandscape = MobileWorkspaceLayout(size: CGSize(width: 1194, height: 834), platform: .pad)

        #expect(iPhonePortrait.usesCompactTabs)
        #expect(iPhoneLandscape.usesCompactTabs)
        #expect(iPadPortrait.usesCompactTabs)
        #expect(iPadLandscape.usesLandscapeSidebar)
        #expect(iPhonePortrait.usesIPadPortraitTopTabs == false)
        #expect(iPadPortrait.usesIPadPortraitTopTabs)
        #expect(iPadLandscape.usesIPadPortraitTopTabs == false)
        #expect(iPhonePortrait.usesPhoneSearchTab)
        #expect(iPhoneLandscape.usesPhoneSearchTab)
        #expect(iPadPortrait.usesPhoneSearchTab == false)
        #expect(iPhonePortrait.usesCustomNavigationTabs)
        #expect(iPadPortrait.usesCustomNavigationTabs)
        #expect(iPadLandscape.usesCustomNavigationTabs == false)
        #expect(iPhonePortrait.usesDedicatedSearchTab)
        #expect(iPadPortrait.usesDedicatedSearchTab)
        #expect(iPadLandscape.usesDedicatedSearchTab == false)
        #expect(iPhonePortrait.usesCondensedChrome)
        #expect(iPadPortrait.usesCondensedChrome == false)
        #expect(iPhonePortrait.articleHorizontalPadding == 16)
        #expect(iPadPortrait.articleHorizontalPadding == 22)
        #expect(iPadLandscape.articleHorizontalPadding == 28)
        #expect(iPadLandscape.articleContentMaximumWidth == 720)
    }

    @Test("Compact search is opt-in instead of persistent in every content surface")
    func compactSearchIsOptInInsteadOfPersistentEverywhere() throws {
        let root = try packageRoot()
        let mobileLayout = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Support/MobileWorkspaceLayout.swift"),
            encoding: .utf8
        )
        let iPadContentView = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/ContentView_iPadOS.swift"),
            encoding: .utf8
        )
        let tabBarBridge = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Support/TabBarMinimizeBehaviorBridge.swift"),
            encoding: .utf8
        )
        let sharedComponents = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/LibrarySurfaceComponents.swift"),
            encoding: .utf8
        )
        let feedHeader = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/GalleryFeedHeaderView.swift"),
            encoding: .utf8
        )
        let l10n = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Support/L10n.swift"),
            encoding: .utf8
        )
        let localizable = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Resources/Localizable.xcstrings"),
            encoding: .utf8
        )
        #expect(mobileLayout.contains("var usesPhoneSearchTab: Bool"))
        #expect(mobileLayout.contains("var usesIPadPortraitTopTabs: Bool"))
        #expect(mobileLayout.contains("var usesCustomNavigationTabs: Bool"))
        #expect(mobileLayout.contains("var usesDedicatedSearchTab: Bool"))
        #expect(mobileLayout.contains("var usesDedicatedSearchTab: Bool {\n        usesCustomNavigationTabs\n    }"))
        #expect(iPadContentView.contains("Tab(L10n.search, systemImage: \"magnifyingglass\", value: .search, role: .search)"))
        #expect(iPadContentView.contains("if layout.usesCustomNavigationTabs {"))
        #expect(iPadContentView.contains("if layout.usesDedicatedSearchTab {"))
        #expect(iPadContentView.contains("@Environment(\\.accessibilityReduceMotion) private var reduceMotion"))
        #expect(iPadContentView.contains(".tabBarMinimizeBehavior(compactTabBarMinimizeBehavior)"))
        #expect(iPadContentView.contains("TabBarMinimizeBehaviorBridge("))
        #expect(iPadContentView.contains("isTabBarHidden: false"))
        #expect(iPadContentView.contains("usesTransparentBackground: layout.usesCompactTabs"))
        #expect(iPadContentView.contains("scrollsToTopOnCurrentTabReselection: true"))
        #expect(iPadContentView.contains("private var compactTabBarMinimizeBehavior: TabBarMinimizeBehavior"))
        #expect(iPadContentView.contains("private var compactUITabBarMinimizeBehavior: UITabBarController.MinimizeBehavior"))
        #expect(iPadContentView.contains("currentMobilePlatform == .phone && isCompactCustomTabRootActive ? .onScrollDown : .automatic"))
        #expect(iPadContentView.contains("currentMobilePlatform == .phone && isCompactCustomTabRootActive"))
        #expect(tabBarBridge.contains("struct TabBarMinimizeBehaviorBridge: UIViewControllerRepresentable"))
        #expect(tabBarBridge.contains("let behavior: UITabBarController.MinimizeBehavior"))
        #expect(tabBarBridge.contains("let isTabBarHidden: Bool"))
        #expect(tabBarBridge.contains("let usesTransparentBackground: Bool"))
        #expect(tabBarBridge.contains("let scrollsToTopOnCurrentTabReselection: Bool"))
        #expect(tabBarBridge.contains("private weak var appliedTabBarController: UITabBarController?"))
        #expect(tabBarBridge.contains("private weak var appliedReselectionTabBar: UITabBar?"))
        #expect(tabBarBridge.contains("private var lastAppliedBehavior: UITabBarController.MinimizeBehavior?"))
        #expect(tabBarBridge.contains("private var lastAppliedTabBarHidden: Bool?"))
        #expect(tabBarBridge.contains("private var lastAppliedTransparentBackground: Bool?"))
        #expect(tabBarBridge.contains("if controller.behavior != behavior"))
        #expect(tabBarBridge.contains("if controller.usesTransparentBackground != usesTransparentBackground"))
        #expect(tabBarBridge.contains("if controller.scrollsToTopOnCurrentTabReselection != scrollsToTopOnCurrentTabReselection"))
        #expect(tabBarBridge.contains("CurrentTabReselectionGestureRecognizer"))
        #expect(tabBarBridge.contains("recognizer.cancelsTouchesInView = false"))
        #expect(tabBarBridge.contains("recognizer.beganOnSelectedItem"))
        #expect(tabBarBridge.contains("scrollSelectedTabContentToTop()"))
        #expect(tabBarBridge.contains(".firstRegisteredContentScrollView(for: .bottom)"))
        #expect(tabBarBridge.contains("scrollView.setContentOffset(target, animated: UIAccessibility.isReduceMotionEnabled == false)"))
        #expect(tabBarBridge.contains("if lastAppliedBehavior != behavior || tabBarController.tabBarMinimizeBehavior != behavior"))
        #expect(tabBarBridge.contains("applyAppearance(to: tabBarController.tabBar)"))
        #expect(tabBarBridge.contains("appearance.configureWithTransparentBackground()"))
        #expect(tabBarBridge.contains("appearance.backgroundColor = .clear"))
        #expect(tabBarBridge.contains("appearance.shadowColor = .clear"))
        #expect(tabBarBridge.contains("tabBar.standardAppearance = appearance"))
        #expect(tabBarBridge.contains("tabBar.scrollEdgeAppearance = usesTransparentBackground ? appearance : nil"))
        #expect(tabBarBridge.contains("tabBarController.tabBarMinimizeBehavior = behavior"))
        #expect(tabBarBridge.contains("if lastAppliedTabBarHidden != isTabBarHidden || tabBarController.isTabBarHidden != isTabBarHidden"))
        #expect(tabBarBridge.contains("tabBarController.setTabBarHidden(isTabBarHidden, animated: hasAppliedTabBarState)"))
        #expect(tabBarBridge.contains("private func resolvedTabBarController() -> UITabBarController?"))
        #expect(tabBarBridge.contains("view.window?.rootViewController?.firstTabBarController()"))
        #expect(iPadContentView.contains("ForEach(MobileBottomTabKind.allCases) { kind in"))
        #expect(iPadContentView.contains("value: iPadTab.mobile(kind)"))
        #expect(iPadContentView.contains("case search"))
        #expect(iPadContentView.contains("private var compactSearchTab: some View"))
        #expect(iPadContentView.contains("private var mobileBottomTabDefaultRoutesBinding: Binding<[MobileBottomTabKind: PixivRoute]>"))
        #expect(iPadContentView.contains("private var mobileBottomTabLaunchTargetBinding: Binding<MobileBottomTabLaunchTarget>"))
        #expect(iPadContentView.contains("MobileBottomTabConfiguration.route("))
        #expect(iPadContentView.contains("MobileBottomTabConfiguration.recordingRememberedRoute("))
        #expect(iPadContentView.contains("MobileBottomTabConfiguration.storageID(for: routeMap)"))
        #expect(iPadContentView.contains("IPadToolbarMenuAction.customizeBottomTabs"))
        #expect(iPadContentView.contains("isMobileTabCustomizationPresented = true"))
        #expect(iPadContentView.contains("private var compactSearchContent: some View"))
        #expect(iPadContentView.contains("compactSearchModeSection"))
        #expect(iPadContentView.contains("private var compactSearchModeSection: some View"))
        #expect(iPadContentView.contains("private func compactSearchModeButton("))
        #expect(iPadContentView.contains("} else if store.selectedRoute == .search,"))
        #expect(iPadContentView.contains("isCompactCustomTabRootActive,"))
        #expect(iPadContentView.contains("hasActiveGlobalSearchText == false"))
        #expect(iPadContentView.contains("compactSearchContent"))
        #expect(iPadContentView.contains(".task(id: store.searchText)"))
        #expect(iPadContentView.contains("await store.refreshSearchSuggestions()"))
        #expect(iPadContentView.contains("MobileGlobalSearchModifier("))
        #expect(iPadContentView.contains("isEnabled: showsSidebarToggle"))
        #expect(iPadContentView.contains("@State private var compactContentTransitionEdge: Edge = .trailing"))
        #expect(iPadContentView.contains("private var feedContentTransitionID: String"))
        #expect(iPadContentView.contains("private var compactContentTransition: AnyTransition"))
        #expect(iPadContentView.contains("reduceMotion {\n            return .opacity"))
        #expect(iPadContentView.contains(".move(edge: compactContentTransitionEdge).combined(with: .opacity)"))
        #expect(iPadContentView.contains("private func withCompactContentTransition(to route: PixivRoute, updates: () -> Void)"))
        #expect(iPadContentView.contains("withAnimation(compactContentTransitionAnimation)"))
        #expect(iPadContentView.contains("private func compactContentTransitionIndex(for route: PixivRoute) -> Int"))
        #expect(iPadContentView.contains("MobileSearchTabConfiguration.routes.firstIndex(of: route)"))
        #expect(iPadContentView.contains(".id(feedContentTransitionID)"))
        #expect(iPadContentView.contains(".transition(compactContentTransition)"))
        #expect(iPadContentView.contains(".animation(compactContentTransitionAnimation, value: feedContentTransitionID)"))
        #expect(iPadContentView.contains("@State private var compactFeedRoute: PixivRoute = .home") == false)
        #expect(iPadContentView.contains("@State private var isCompactTabDockCollapsed = false") == false)
        #expect(iPadContentView.contains("private func restoreCompactFeedRoute()") == false)
        #expect(iPadContentView.contains("private func sanitizedCompactFeedRoute(_ route: PixivRoute) -> PixivRoute") == false)
        #expect(iPadContentView.contains("compactFeedRoute = .search") == false)
        #expect(iPadContentView.contains("private var compactCollapsedTabDock: some View") == false)
        #expect(iPadContentView.contains("private func handleCompactGalleryScrollDirection(_ direction: NativeGalleryScrollDirection)") == false)
        #expect(iPadContentView.contains("private func setCompactTabDockCollapsed(_ isCollapsed: Bool)") == false)
        #expect(iPadContentView.contains("onGalleryScrollDirectionChange: handleCompactGalleryScrollDirection") == false)
        #expect(iPadContentView.contains("case .mobile(let kind):\n            selectMobileBottomTabKind(kind)"))
        #expect(iPadContentView.contains("case .search:\n            selectCompactSearchTab()"))
        #expect(iPadContentView.contains("setCompactSelectedTab(.mobile(.illustrations), skipsHandler: true)"))
        #expect(iPadContentView.contains("setCompactSelectedTab(.search, skipsHandler: true)"))
        #expect(iPadContentView.contains("case .custom") == false)
        #expect(iPadContentView.contains("await store.runArtworkSearch()"))
        #expect(iPadContentView.contains("await store.runCreatorSearch()"))
        #expect(iPadContentView.contains("await store.runNovelSearch()"))
        #expect(iPadContentView.contains("store.presentLocalImageSourceSearch()"))
        #expect(iPadContentView.contains("selectCompactSearchRoute(.trendingTags)"))
        #expect(iPadContentView.contains("selectCompactSearchRoute(.savedSearches)"))
        #expect(sharedComponents.contains("private var usesCollapsedPhoneSearch: Bool"))
        #expect(sharedComponents.contains("UIDevice.current.userInterfaceIdiom == .phone"))
        #expect(feedHeader.contains("private var usesPhoneFilterDisclosure: Bool"))
        #expect(feedHeader.contains("@State private var isInlineFilterExpanded = false"))
        #expect(feedHeader.contains("iPadCompactFilterControl(expandedWidth: 300)"))
        #expect(feedHeader.contains("randomFromCurrentFeed(opensDetail: false)"))
        #expect(l10n.contains("static var searchSuggestions: String"))
        #expect(localizable.contains("\"Search Suggestions\""))
    }

    @Test("Native iOS gallery registers as tab bar content scroll source")
    func nativeIOSGalleryRegistersAsTabBarContentScrollSource() throws {
        let root = try packageRoot()
        let galleryBridge = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Support/NativeGalleryCollectionView.swift"),
            encoding: .utf8
        )

        #expect(galleryBridge.contains("collectionView.contentInsetAdjustmentBehavior = .automatic"))
        #expect(galleryBridge.contains("private weak var registeredContentScrollViewController: UIViewController?"))
        #expect(galleryBridge.contains("viewController?.setContentScrollView(nil, for: .bottom)"))
        #expect(galleryBridge.contains("registerContentScrollViewIfNeeded(collectionView)"))
        #expect(galleryBridge.contains("NativeGalleryUICollectionView"))
        #expect(galleryBridge.contains("override func didMoveToWindow()"))
        #expect(galleryBridge.contains("onHierarchyAvailable?(self)"))
        #expect(galleryBridge.contains("guard collectionView.window != nil else { return }"))
        #expect(galleryBridge.contains("guard viewController.contentScrollView(for: .bottom) !== collectionView else { return }"))
        #expect(galleryBridge.contains("viewController.setContentScrollView(collectionView, for: .bottom)"))
        #expect(galleryBridge.contains("private extension UIView"))
        #expect(galleryBridge.contains("var enclosingViewController: UIViewController?"))
        #expect(galleryBridge.contains("deferContentScrollRegistration") == false)
        #expect(galleryBridge.contains("Task { @MainActor [weak self, weak collectionView]") == false)
    }

    @Test("Native iOS library collections register as bottom tab content scroll sources")
    func nativeIOSLibraryCollectionsRegisterAsBottomTabContentScrollSources() throws {
        let root = try packageRoot()
        let helper = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Support/NativeContentScrollRegistration.swift"),
            encoding: .utf8
        )
        let collectionFiles = [
            "Sources/KeiPix/Support/NativeAdaptiveGridCollectionView.swift",
            "Sources/KeiPix/Support/NativeBookmarkTagCollectionView.swift",
            "Sources/KeiPix/Support/NativeBrowsingHistoryCollectionView.swift",
            "Sources/KeiPix/Support/NativeDownloadQueueListView.swift"
        ]

        #expect(helper.contains("final class NativeContentScrollRegistration"))
        #expect(helper.contains("scrollView.contentInsetAdjustmentBehavior = .automatic"))
        #expect(helper.contains("viewController.setContentScrollView(scrollView, for: edge)"))
        #expect(helper.contains("registeredContentScrollViewController?.setContentScrollView(nil, for: edge)"))
        #expect(helper.contains("final class NativeContentAwareCollectionView: UICollectionView"))
        #expect(helper.contains("onHierarchyAvailable?(self)"))

        for path in collectionFiles {
            let source = try String(contentsOf: root.appending(path: path), encoding: .utf8)
            #expect(source.contains("NativeContentScrollRegistration()"), "\(path) should keep UIKit tab-bar scroll tracking explicit")
            #expect(source.contains("configureCollectionViewForBottomTabContent(collectionView)"), "\(path) should use shared iOS bottom-tab scroll setup")
            #expect(source.contains("registerContentScrollViewIfNeeded(collectionView)"), "\(path) should register after hierarchy changes")
            #expect(source.contains("contentScrollRegistration.register(collectionView)"), "\(path) should hand UIKit its real scroll view")
        }
    }

    @Test("iOS library content extends behind compact bottom tabs")
    func iOSLibraryContentExtendsBehindCompactBottomTabs() throws {
        let root = try packageRoot()
        let helper = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Support/NativeContentScrollRegistration.swift"),
            encoding: .utf8
        )
        let hostFiles = [
            "Sources/KeiPix/Views/BookmarkTagsView.swift",
            "Sources/KeiPix/Views/BrowsingHistoryView.swift",
            "Sources/KeiPix/Views/DownloadQueueView.swift",
            "Sources/KeiPix/Views/MangaWatchlistView.swift",
            "Sources/KeiPix/Views/NovelWatchlistView.swift",
            "Sources/KeiPix/Views/PixivCollectionsView.swift",
            "Sources/KeiPix/Views/WatchLaterView.swift",
            "Sources/KeiPix/Views/WorkSubscriptionsView.swift"
        ]

        #expect(helper.contains("func nativeBottomTabContentSurface(isEnabled: Bool = true)"))
        #expect(helper.contains(".backgroundExtensionEffect(isEnabled: isEnabled)"))
        #expect(helper.contains(".nativeBottomTabContentSurface()"))

        for path in hostFiles {
            let source = try String(contentsOf: root.appending(path: path), encoding: .utf8)
            #expect(source.contains(".nativeBottomTabContentSurface()"), "\(path) should extend native content behind compact bottom tabs")
        }
    }

    @Test("Pixiv collections stay native and reachable from compact navigation")
    func pixivCollectionsStayNativeAndReachableFromCompactNavigation() throws {
        let root = try packageRoot()
        let collectionsView = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/PixivCollectionsView.swift"),
            encoding: .utf8
        )
        let galleryView = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/GalleryView.swift"),
            encoding: .utf8
        )
        let galleryFeedHeader = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/GalleryFeedHeaderView.swift"),
            encoding: .utf8
        )
        let feedContextCards = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/CreatorFeedContextCard.swift"),
            encoding: .utf8
        )
        let galleryBridge = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Support/NativeGalleryCollectionView.swift"),
            encoding: .utf8
        )
        let collectionsStore = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Stores/KeiPixStore+PixivCollections.swift"),
            encoding: .utf8
        )
        let api = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Services/PixivAPI.swift"),
            encoding: .utf8
        )
        let collectionModels = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Models/PixivCollectionModels.swift"),
            encoding: .utf8
        )
        let mobileConfiguration = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Models/MobileBottomTabConfiguration.swift"),
            encoding: .utf8
        )
        let contentView = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/ContentView.swift"),
            encoding: .utf8
        )
        let dashboardRecommendations = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/DiscoveryDashboardRecommendationSections.swift"),
            encoding: .utf8
        )
        let dashboardModels = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Models/DiscoveryDashboardModels.swift"),
            encoding: .utf8
        )
        let iPadContentView = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/ContentView_iPadOS.swift"),
            encoding: .utf8
        )

        #expect(collectionsView.contains("NativeGalleryCollectionView("))
        #expect(collectionsView.contains("NativeGalleryCollectionItem.pixivCollection"))
        #expect(collectionsView.contains("onNearContentEnd: nearContentEndAction"))
        #expect(collectionsView.contains("private var nearContentEndAction: (() -> Void)?"))
        #expect(collectionsView.contains("OS26PaginationFooter("))
        #expect(collectionsView.contains("fixedColumnCount: 2"))
        #expect(collectionsView.contains("horizontalSizeClass == .compact"))
        #expect(collectionsView.contains("onPrefetchItems: prefetchNativeItems"))
        #expect(collectionsView.contains("collection.coverImageURL"))
        #expect(collectionsView.contains("store.loadMorePixivCollections(mode: mode)"))
        #expect(collectionsView.contains("PixivCollectionDiscoveryScope.allCases"))
        #expect(collectionsView.contains(".platformPageHeader("))
        #expect(collectionsView.contains("pixivCollectionTitleActions"))
        #expect(collectionsView.contains("OS26GlassCompatibleSegmentedPicker"))
        #expect(collectionsView.contains("wideDiscoveryControls"))
        #expect(collectionsView.contains("discoveryScopeSegmentOptions"))
        #expect(collectionsView.contains("compactDiscoverySelectionMenu"))
        #expect(collectionsView.contains("PixivCollectionDropdownMenuLabel"))
        #expect(collectionsView.contains("discoveryTagMenu"))
        #expect(collectionsView.contains("discoveryTagPicker"))
        #expect(collectionsView.contains("pixivCollectionMoreMenu"))
        #expect(collectionsView.contains("usesCompactDiscoveryChrome"))
        #expect(collectionsView.contains("Label(mode.title, systemImage") == false)
        #expect(collectionsView.contains("store.currentPixivCollectionDiscoverySelection.reloadID"))
        #expect(collectionsView.contains("store.selectPixivCollectionDiscoveryScope(scope)"))
        #expect(collectionsView.contains("store.selectPixivCollectionDiscoveryTag(tag)"))
        #expect(collectionsView.contains("Label(L10n.refresh, systemImage: \"arrow.clockwise\")") == false)
        #expect(collectionsView.contains("store.isPixivWebSessionPresented = true"))
        #expect(collectionsView.contains("L10n.connectPixivWebSession"))
        #expect(collectionsView.contains("pixivCollectionTotalCount"))
        #expect(collectionsView.contains("struct PixivCollectionCard: View"))
        #expect(galleryBridge.contains("case pixivCollection(PixivCollectionDetail)"))
        #expect(galleryBridge.contains("case pixivRelatedCollectionsHeader(Int)"))
        #expect(galleryView.contains("appendRelatedPixivCollectionItems(to: &items)"))
        #expect(galleryView.contains("collection.relatedCollections.map(NativeGalleryCollectionItem.pixivCollection)"))
        #expect(galleryView.contains("RelatedPixivCollectionsHeader(count: count)"))
        #expect(galleryView.contains("PixivCollectionFeedContextCard("))
        #expect(galleryView.contains("iPadCompactFeedActions(showsFeedCountBadge: false, showsActiveFeedClearChip: false)"))
        #expect(galleryView.contains("pixivCollectionFeedHeaderContext(for: collection)"))
        #expect(galleryView.contains("copyPixivCollectionLink(urlString:"))
        #expect(galleryView.contains("copyPixivCollectionLink(collection)") == false)
        #expect(galleryFeedHeader.contains("case pixivCollection") == false)
        #expect(feedContextCards.contains("struct PixivCollectionFeedContextCard: View"))
        #expect(feedContextCards.contains("struct PixivCollectionFeedContext: Equatable, Sendable"))
        #expect(feedContextCards.contains("let collection: PixivCollectionDetail") == false)
        #expect(feedContextCards.contains("let pixivURLString: String?"))
        #expect(feedContextCards.contains("FlowLayout(spacing: 6)"))
        #expect(feedContextCards.contains("collection.caption.htmlStripped"))
        #expect(feedContextCards.contains("collection.publishedDate"))
        #expect(feedContextCards.contains("collection.bookmarkCount"))
        #expect(feedContextCards.contains("collection.viewCount"))
        #expect(feedContextCards.contains("collection.relatedCollections.count"))
        #expect(feedContextCards.contains("Link(destination: url)"))
        #expect(galleryView.contains("try await store.openPixivCollection(id: collection.id, sourceRoute: sourceRoute)"))
        #expect(galleryView.contains("collectionCoverURLs"))
        #expect(galleryView.contains("collection.coverImageURL"))
        #expect(collectionsView.contains("try await store.openPixivCollection(id: collection.id, sourceRoute: mode.route)"))
        #expect(collectionsView.contains("private var emptyStateActions"))
        #expect(collectionsView.contains("ViewThatFits"))
        #expect(collectionsStore.contains("api.userBookmarkedCollectionsPage("))
        #expect(collectionsStore.contains("pixivCollectionNextOffset"))
        #expect(collectionsStore.contains("isLoadingMorePixivCollections"))
        #expect(collectionsStore.contains("loadMorePixivCollections(mode:"))
        #expect(collectionsStore.contains("hydratePixivCollectionDiscoveryMetadataIfNeeded"))
        #expect(collectionsStore.contains("api.pixivCollectionRecommendedTags()"))
        #expect(collectionsStore.contains("api.pixivCollectionTop()"))
        #expect(collectionsStore.contains("currentPixivCollectionDiscoverySelection.searchRequest"))
        #expect(collectionsStore.contains("mode == .saved, pixivWebSession == nil"))
        #expect(collectionsStore.contains("L10n.savedPixivCollectionsWebSessionRequiredHint"))
        #expect(collectionsStore.contains(".appTransportSecurityRequiresSecureConnection"))
        #expect(collectionsStore.contains("clearSavedPixivCollectionWebSessionAfterFailure"))
        #expect(collectionsStore.contains("pixivWebSession = nil"))
        #expect(api.contains("/ajax/top/collection"))
        #expect(api.contains("/ajax/collections/search/recommended_tags"))
        #expect(api.contains("request.queryItems("))
        #expect(collectionModels.contains("enum PixivCollectionDiscoveryScope"))
        #expect(collectionModels.contains("struct PixivCollectionDiscoverySelection"))
        #expect(collectionModels.contains("struct PixivCollectionTopResponse"))
        #expect(collectionModels.contains("struct PixivCollectionRecommendedTagsResponse"))
        #expect(galleryBridge.contains("collection.masonryAspectRatio"))
        #expect(mobileConfiguration.contains(".pixivCollections"))
        #expect(mobileConfiguration.contains(".savedPixivisionArticles"))
        #expect(mobileConfiguration.contains(".myPixivCollections"))
        #expect(mobileConfiguration.contains(".savedPixivCollections"))
        #expect(mobileConfiguration.contains("route == .pixivCollectionWorks"))
        #expect(contentView.contains("PixivCollectionsView(store: store)"))
        #expect(contentView.contains("SpotlightView(\n                store: store,\n                fixedCollectionMode: .favorites,\n                title: L10n.savedPixivisionArticles"))
        #expect(contentView.contains("PixivCollectionsView(store: store, mode: .created)"))
        #expect(contentView.contains("PixivCollectionsView(store: store, mode: .saved)"))
        #expect(dashboardRecommendations.contains("route: .pixivCollections"))
        #expect(dashboardModels.contains(".pixivCollections"))
        #expect(dashboardModels.contains(".savedPixivisionArticles"))
        #expect(dashboardModels.contains(".myPixivCollections"))
        #expect(dashboardModels.contains(".savedPixivCollections"))
        #expect(iPadContentView.contains("PixivCollectionsView(store: store)"))
        #expect(iPadContentView.contains("fixedCollectionMode: .favorites"))
        #expect(iPadContentView.contains("PixivCollectionsView(store: store, mode: .created)"))
        #expect(iPadContentView.contains("PixivCollectionsView(store: store, mode: .saved)"))
    }

    @Test("Pixiv Web session connection is explicit and available on all app shells")
    func pixivWebSessionConnectionIsExplicitAndAvailableOnAllAppShells() throws {
        let root = try packageRoot()
        let api = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Services/PixivAPI.swift"),
            encoding: .utf8
        )
        let webSessionSheet = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/PixivWebSessionSheetView.swift"),
            encoding: .utf8
        )
        let accountSettings = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/Settings/AccountSettingsPage.swift"),
            encoding: .utf8
        )
        let macContentView = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/ContentView.swift"),
            encoding: .utf8
        )
        let iPadContentView = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/ContentView_iPadOS.swift"),
            encoding: .utf8
        )
        let store = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Stores/KeiPixStore+Accounts.swift"),
            encoding: .utf8
        )
        let collectionModels = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Models/PixivCollectionModels.swift"),
            encoding: .utf8
        )

        #expect(api.contains("private let webSessionStore = PixivWebSessionStore()"))
        #expect(api.contains("request.setValue(cookieHeader, forHTTPHeaderField: \"Cookie\")"))
        #expect(api.contains("validatePixivWebSession("))
        #expect(api.contains("pixivWebPageLooksSignedIn("))
        #expect(api.contains("L10n.pixivWebSessionNotSignedIn"))
        #expect(api.contains(#"href="/settings/profile""#))
        #expect(api.contains(#"href="/logout""#))
        #expect(api.contains("userBookmarkedCollectionsHTMLPage("))
        #expect(api.contains("PixivCollectionHTMLParser.parseListPage"))
        #expect(api.contains("apiPage.collections.isEmpty"))
        #expect(webSessionSheet.contains("configuration.websiteDataStore = .default()"))
        #expect(webSessionSheet.contains("PixivWebURLBuilder.userBookmarkCollectionsURL"))
        #expect(webSessionSheet.contains("PixivWebURLBuilder.collectionsURL()"))
        #expect(webSessionSheet.contains("https://www.pixiv.net/collections"))
        #expect(webSessionSheet.contains("webView.customUserAgent = AppVersion.current.desktopSafariUserAgent()"))
        #expect(webSessionSheet.contains("PixivWebSessionCookie.pixivCookies(from: cookies)"))
        #expect(webSessionSheet.contains("Chrome") == false)
        #expect(accountSettings.contains("L10n.pixivWebSession"))
        #expect(accountSettings.contains("store.isPixivWebSessionPresented = true"))
        #expect(macContentView.contains("PixivWebSessionSheetView(store: store)"))
        #expect(iPadContentView.contains("PixivWebSessionSheetView(store: store)"))
        #expect(store.contains("func connectPixivWebSession(cookies: [PixivWebSessionCookie])"))
        #expect(store.contains("disconnectPixivWebSession()"))
        #expect(collectionModels.contains("enum PixivCollectionHTMLParser"))
        #expect(collectionModels.contains("data-ga4-label=\"collection_link\""))
    }

    @Test("iOS library empty and loading states register as bottom tab content scroll sources")
    func iOSLibraryEmptyAndLoadingStatesRegisterAsBottomTabContentScrollSources() throws {
        let root = try packageRoot()
        let helper = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Support/NativeContentScrollRegistration.swift"),
            encoding: .utf8
        )
        let emptyState = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/EmptyStateView.swift"),
            encoding: .utf8
        )
        let libraryComponents = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/LibrarySurfaceComponents.swift"),
            encoding: .utf8
        )

        #expect(helper.contains("struct NativeBottomTabScrollContentHost<Content: View>: View"))
        #expect(helper.contains("NativeContentScrollRegistrationAnchor"))
        #expect(helper.contains("registerNearestScrollView(containing:"))
        #expect(helper.contains("configureScrollViewForBottomTabContent(scrollView)"))
        #expect(emptyState.contains("NativeBottomTabScrollContentHost"))
        #expect(libraryComponents.contains("NativeBottomTabScrollContentHost"))
        #expect(libraryComponents.contains("private var loadingCard"))
        #expect(libraryComponents.contains("private var unavailableCard"))
    }

    @Test("Mobile portrait reading surfaces avoid landscape-only chrome")
    func mobilePortraitReadingSurfacesAvoidLandscapeOnlyChrome() throws {
        let root = try packageRoot()
        let mobileLayout = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Support/MobileWorkspaceLayout.swift"),
            encoding: .utf8
        )
        let pixivisionReader = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/PixivisionReaderView.swift"),
            encoding: .utf8
        )
        let spotlightDetail = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/SpotlightArticleDetailView.swift"),
            encoding: .utf8
        )
        let novelReader = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/NovelReaderView.swift"),
            encoding: .utf8
        )
        let novelDetail = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/NovelDetailView.swift"),
            encoding: .utf8
        )
        let settings = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/SettingsView.swift"),
            encoding: .utf8
        )
        let profileSheet = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/UserProfileSheet.swift"),
            encoding: .utf8
        )

        #expect(mobileLayout.contains("var usesCondensedChrome: Bool"))
        #expect(mobileLayout.contains("var articleHorizontalPadding: CGFloat"))
        #expect(pixivisionReader.contains("MobileWorkspaceLayout(size: proxy.size, platform: ReaderPlatformKind.current)"))
        #expect(pixivisionReader.contains(".font(layout.usesCondensedChrome ? .title.weight(.bold) : .largeTitle.weight(.bold))"))
        #expect(spotlightDetail.contains("ViewThatFits(in: .horizontal)"))
        #expect(spotlightDetail.contains("private var compactLayout: some View"))
        #expect(novelReader.contains("private var compactHeader: some View"))
        #expect(novelReader.contains("horizontalHeader\n                .frame(minWidth: 560)"))
        #expect(novelDetail.contains("private var compactActionStack: some View"))
        #expect(novelDetail.contains("openReaderButton(expands: true)"))
        #expect(settings.contains("LoginSheetView(store: store)\n                    #if os(macOS)\n                    .frame(width: 900, height: 680)"))
        #expect(profileSheet.contains("UserPreviewListView(store: store, mode: mode, showsCloseButton: true)\n                    #if os(macOS)\n                    .frame(width: 920, height: 680)"))
    }

    @Test("Mobile utility sheets avoid fixed desktop widths")
    func mobileUtilitySheetsAvoidFixedDesktopWidths() throws {
        let root = try packageRoot()
        let expectedMacOnlyFrames = [
            (
                "Sources/KeiPix/Views/BookmarkEditorView.swift",
                "#if os(macOS)\n        .frame(width: 720)"
            ),
            (
                "Sources/KeiPix/Views/FeedbackReportSheet.swift",
                "#if os(macOS)\n        .frame(width: 480)"
            ),
            (
                "Sources/KeiPix/Views/BulkBlockSheet.swift",
                "#if os(macOS)\n        .frame(width: 460)"
            ),
            (
                "Sources/KeiPix/Views/PixivIDOpenSheet.swift",
                "#if os(macOS)\n        .frame(width: 460)"
            ),
            (
                "Sources/KeiPix/Views/MutableActionQAAuthorizationSheet.swift",
                "#if os(macOS)\n        .frame(width: 460)"
            ),
            (
                "Sources/KeiPix/Views/DownloadPageSelectionSheet.swift",
                "#if os(macOS)\n        .frame(width: 540)"
            ),
            (
                "Sources/KeiPix/Views/ArtworkSeriesView.swift",
                "#if os(macOS)\n        .frame(width: 860, height: 680)"
            )
        ]

        for (relativePath, expectedFrame) in expectedMacOnlyFrames {
            let source = try String(contentsOf: root.appending(path: relativePath), encoding: .utf8)
            #expect(source.contains(expectedFrame), "\(relativePath) should keep fixed desktop sizing macOS-only")
        }

        let pageSelection = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/DownloadPageSelectionSheet.swift"),
            encoding: .utf8
        )
        #expect(pageSelection.contains("#if os(iOS)\n        [GridItem(.adaptive(minimum: 96), spacing: 10)]"))
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
        #expect(novelGallery.contains("@State private var readerNovel: PixivNovel?"))
        #expect(novelGallery.contains(".sheet(item: $readerNovel)"))
        #expect(novelGallery.contains("NovelReaderView(store: store, novel: novel)"))
        #expect(novelGallery.contains(".os26SheetChrome(.reader)"))
        #expect(novelGallery.contains("usesDirectReaderOpening"))
        #expect(novelGallery.contains("private func presentNovelReader(_ novel: PixivNovel)"))
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

        #expect(emptyState.contains("struct PlatformPageTitleHeader<Trailing: View>: View"))
        #expect(emptyState.contains("func platformPageHeader(title: String, status: String, statusSystemImage: String? = nil)"))
        #expect(emptyState.contains("func platformPageHeader<Trailing: View>("))
        #expect(emptyState.contains("@ViewBuilder trailing: @escaping () -> Trailing"))
        #expect(emptyState.contains("ViewThatFits(in: .horizontal)"))
        #expect(emptyState.contains("statusPill\n                Spacer(minLength: 0)\n                trailing()"))
        #expect(emptyState.contains("titleText\n                    statusPill\n                    Spacer(minLength: 0)"))
        #expect(emptyState.contains("Spacer(minLength: 0)\n                    trailing()"))
        #expect(emptyState.contains("if let statusSystemImage, showsStatusPillIcon"))
        #expect(emptyState.contains("UIDevice.current.userInterfaceIdiom != .phone"))
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
        #expect(glassSupport.contains("GlassEffectContainer(spacing: 12)"))
        #expect(glassSupport.contains("private struct KeiGlassSurfaceShape: InsettableShape"))
        #expect(glassSupport.contains(".containerShape(shape)"))
        #expect(glassSupport.contains(".glassEffect(.regular, in: shape)"))
        #expect(glassSupport.contains(".glassEffect(.regular.interactive(), in: shape)"))
        #expect(glassSupport.contains(".keiGlass(20)"))
        #expect(glassSupport.contains("func keiPanel(_ radius: CGFloat = 16, clipsContent: Bool = false)"))
        #expect(glassSupport.contains(".clipShape(shape)"))
        #expect(glassSupport.contains("func macOSWindowCompanionBackground()"))
        #expect(glassSupport.contains(".background(.windowBackground)"))
        #expect(glassSupport.contains(".background(.thinMaterial") == false)
        #expect(gallery.contains(".platformGlassControlBar(verticalPadding: 6"))
        #expect(gallery.contains(".glassEffect(.regular, in: Capsule(style: .continuous))"))
        #expect(sheetHeader.contains(".platformGlassControlBar(verticalPadding: 12"))
        #expect(sheetHeader.contains(".buttonStyle(.glass)"))
        #expect(sheetHeader.contains(".buttonBorderShape(.capsule)"))
        #expect(sheetChrome.contains("func os26SheetChrome(_ style: OS26SheetPresentationStyle = .standard)"))
        #expect(sheetChrome.contains("case reader"))
        #expect(sheetChrome.contains(".presentationSizing(.page)"))
        #expect(sheetChrome.contains("[.fraction(0.88), .large]"))
        #expect(sheetChrome.contains("if #available(iOS 27.0, *)"))
        #expect(sheetChrome.contains(".presentationBackground(.regularMaterial)"))
        #expect(sheetChrome.contains(".presentationCornerRadius(style.cornerRadius)"))
        #expect(userProfileHeader.contains("GlassEffectContainer(spacing: 8)"))
        #expect(userProfileHeader.contains("ViewThatFits(in: .horizontal)"))
        #expect(userProfileHeader.contains("ProfileSheetHeaderButtonDisplayStyle"))
        #expect(userProfileHeader.contains("profileLinkButtons"))
        #expect(userProfileHeader.contains("ProfileHeaderLinkEntry"))
        #expect(userProfileHeader.contains("detail?.profile.webpage"))
        #expect(userProfileSheet.contains("private var sheetContent: some View"))
        #expect(userProfileSheet.contains(".frame(width: 820)"))
        #expect(userProfileSheet.contains(".frame(maxWidth: profileSheetMaximumWidth)"))
        #expect(userProfileSheet.contains("UserProfileLoadingSkeletonLayout"))
        #expect(userProfileSheet.contains("UserProfileOverviewSection("))
        #expect(userProfileSheet.contains("openNovels: { openFeed(.userNovels) }"))
        #expect(userProfileSheet.contains("UserProfileStatsSection(") == false)
        #expect(userProfileSheet.contains("UserProfileNetworkLinks(") == false)
        #expect(userProfileSheet.contains(".scrollEdgeEffectStyle(.soft, for: .top)"))
        #expect(userProfileInfoSections.contains("struct UserProfileOverviewSection"))
        #expect(userProfileInfoSections.contains("relatedUsersCount: Int"))
        #expect(userProfileInfoSections.contains("let openNovels: () -> Void"))
        #expect(userProfileInfoSections.contains("title: L10n.novels"))
        #expect(userProfileInfoSections.contains("action: openNovels"))
        #expect(userProfileInfoSections.contains("overviewGrid"))
        #expect(userProfileInfoSections.contains("overviewEntries"))
        #expect(userProfileInfoSections.contains("overviewColumns"))
        #expect(userProfileInfoSections.contains("GridItem(.flexible(minimum: 0, maximum: .infinity)"))
        #expect(userProfileInfoSections.contains("L10n.followers"))
        #expect(userProfileInfoSections.contains("L10n.relatedCreators"))
        #expect(userProfileInfoSections.contains(".glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 12"))
        #expect(userProfileInfoSections.contains("struct UserProfileStatsSection") == false)
        #expect(userProfileInfoSections.contains("struct UserProfileNetworkLinks") == false)
        #expect(userProfileInfoSections.contains("private struct UserProfileStatEntry"))
        #expect(userProfileSheet.contains("UserProfileLinksSection") == false)
        #expect(userProfileInfoSections.contains("struct UserProfileLinksSection") == false)
        #expect(userProfileCreatorTags.contains("private let collapsedCap = 18"))
        #expect(userProfileCreatorTags.contains("private var headerAndSearch: some View"))
        #expect(userProfileCreatorTags.contains("private var tagCloud: some View"))
        #expect(userProfileCreatorTags.contains("Image(systemName: \"magnifyingglass\")") == false)
        #expect(userProfileCreatorTags.contains("CreatorArtworkTagTwoColumnLayout(spacing: 8)"))
        #expect(userProfileCreatorTags.contains("CreatorArtworkTagFullWidthKey"))
        #expect(userProfileCreatorTags.contains("FlowLayout(spacing: 8)"))
        #expect(userProfileCreatorTags.contains("CreatorArtworkTagChip"))
        #expect(userProfileCreatorTags.contains("fillsAvailableWidth: true"))
        #expect(userProfileCreatorTags.contains("prefersFullWidthChip"))
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
        #expect(contentView.contains("} detail: {\n            macBrowserWorkspace\n        }"))
        #expect(contentView.contains("MacBrowserWorkspaceLayout("))
        #expect(contentView.contains("@SceneStorage(\"KeiPix.macOS.detailPanelUserEnabled\")"))
        #expect(contentView.contains("@State private var isMacDetailPanelCurrentlyVisible = false"))
        #expect(contentView.contains("private var macDetailPanel: some View"))
        #expect(contentView.contains("private var macDetailPanelHasSelection: Bool"))
        #expect(contentView.contains("private var macDetailPanelToggleTitle: String"))
        #expect(contentView.contains("private func toggleMacDetailPanel()"))
        #expect(contentView.contains("ArtworkDetailView(store: store, showsNavigationChrome: false)"))
        #expect(contentView.contains("SpotlightArticleDetailView(store: store, showsNavigationChrome: false)"))
        #expect(contentView.contains("private var detailColumn") == false)
        #expect(contentView.contains("contentColumnMinWidth") == false)
        #expect(contentView.contains("CreatorListDetailPlaceholder(route: store.selectedRoute)") == false)
        #expect(contentView.contains(".navigationSplitViewColumnWidth(min: 360, ideal: 440)") == false)
        #expect(contentView.contains(".navigationSplitViewColumnWidth(min: 420, ideal: 560)") == false)
        #expect(contentView.contains(".frame(minWidth: minimumWindowWidth, minHeight: MainWindowSizing.minimumHeight)"))
        #expect(contentView.contains(".mainWindowSizing("))
        #expect(contentView.contains("preferredDefaultSize: WindowSizePreset.balanced.size("))
        #expect(contentView.contains("ToolbarItemGroup(placement: .navigation)"))
        #expect(contentView.contains("private var showsArtworkNavigationControls: Bool"))
        #expect(contentView.contains("private func toggleSidebar()"))
        #expect(contentView.contains("@State private var sidebarSelection: KeiPixSidebarDestination = .route(.home)"))
        #expect(contentView.contains("SidebarView(\n                store: store,\n                selection: $sidebarSelection,\n                columnWidth: .macOS"))
        #expect(contentView.contains("columnVisibility = .detailOnly"))
        #expect(contentView.contains("columnVisibility = .all"))
        #expect(contentView.contains("private func syncSidebarSelectionFromRoute()"))
        #expect(contentView.contains("MainWindowSizing.minimumWidth(sidebarVisible: sidebarVisible)"))
        #expect(contentView.contains("store.selectedRoute.usesArtworkFeed") == true)
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
        #expect(contentView.contains(".sharedBackgroundVisibility(.hidden)"))
        #expect(contentView.contains(".windowStyler(unifiedToolbar: true)"))
        #expect(contentView.contains(".macOSWindowCompanionBackground()"))
        #expect(contentView.contains(".background(.background)") == false)
        #expect(contentView.contains("Section(L10n.links)"))
        #expect(contentView.contains("Section(L10n.windowSize)"))
        #expect(contentView.contains("Section(L10n.viewOptions)"))
        #expect(contentView.contains("Section(L10n.contentFilters)"))
        #expect(contentView.contains("Toggle(L10n.hideMutedContent, isOn: hideMutedContentBinding)"))
        #expect(contentView.contains("store.setPrivacyModeEnabled") == false)
    }

    @Test("macOS launch sizing clamps restored narrow windows")
    func macOSLaunchSizingClampsRestoredNarrowWindows() throws {
        let root = try packageRoot()
        let sidebarView = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/SidebarView.swift"),
            encoding: .utf8
        )
        let accountIdentityMenu = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/AccountIdentityMenuButton.swift"),
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
        #expect(windowSizePreset.contains("static func minimumWidth(sidebarVisible: Bool) -> CGFloat"))
        #expect(windowSizePreset.contains("accountIdentityVisible") == false)
        #expect(windowSizePreset.contains("1240"))
        #expect(windowSizePreset.contains("CGSize(width: MainWindowSizing.minimumWidth(sidebarVisible: true"))
        #expect(windowSizePreset.contains("CGSize(width: MainWindowSizing.minimumWidth(sidebarVisible: false), height: 720)"))
        #expect(sidebarView.contains("enum KeiPixSidebarDestination: Hashable"))
        #expect(sidebarView.contains("static let macOS = SidebarColumnWidth(min: 246, ideal: 266, max: 310)"))
        #expect(sidebarView.contains("static let iPadOS = SidebarColumnWidth(min: 196, ideal: 218, max: 250)"))
        #expect(sidebarView.contains("AccountHeader(store: store)"))
        #expect(sidebarView.contains("AccountIdentityMenuButton(store: store, displayStyle: .sidebar)"))
        #expect(accountIdentityMenu.contains("Toggle(L10n.showAccountIdentity, isOn: showAccountIdentityBinding)"))
        #expect(sidebarView.contains("#if DEBUG") == false)
        #expect(sidebarView.contains("navigationSplitViewColumnWidth(\n            min: columnWidth.min"))
        #expect(sidebarView.contains("private let defaults: UserDefaults"))
        #expect(sidebarView.contains("defaults.set(Array(collapsedIDs), forKey: Self.storageKey)"))
        #expect(accountIdentityMenu.contains("private var avatarDiameter: CGFloat"))
        #expect(accountIdentityMenu.contains("showIdentity ? 46 : 62"))
        #expect(accountIdentityMenu.contains("case heroAvatar(diameter: CGFloat, symbolSize: CGFloat)"))
        #expect(accountIdentityMenu.contains(".glassEffect(.regular.interactive(), in: Circle())"))
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
        #expect(windowStyler.contains("struct AutomaticKeyViewLoopModifier: ViewModifier"))
        #expect(windowStyler.contains("private final class AutomaticKeyViewLoopHostView: NSView"))
        #expect(windowStyler.contains("window.autorecalculatesKeyViewLoop = true"))
        #expect(windowStyler.contains("window.recalculateKeyViewLoop()"))
        #expect(windowStyler.contains("func automaticKeyViewLoop()"))
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
        let macOSNativeFeedHeader = galleryView
            .components(separatedBy: "private var macOSNativeFeedHeader: some View")
            .dropFirst()
            .first?
            .components(separatedBy: "#endif")
            .first ?? ""

        #expect(feedHeader.contains("GlassEffectContainer"))
        #expect(feedHeader.contains("HStack(spacing: 8) {\n                        headerActions"))
        #expect(feedHeader.contains("private var macOSFilterField: some View"))
        #expect(feedHeader.contains(".textFieldStyle(.plain)"))
        #expect(feedHeader.contains(".layoutPriority(1)"))
        #expect(feedHeader.contains(".feedHeaderActionChrome()"))
        #expect(feedHeader.contains(".keiInteractiveGlass(16)"))
        #expect(feedHeader.contains("private var bookmarkFiltersMenu: some View"))
        #expect(feedHeader.contains("private var bookmarkVisibilityMenu: some View") == false)
        #expect(feedHeader.contains("store.setBookmarkFeedRestrict(") == false)
        #expect(feedHeader.contains("private var bookmarkSortMenu: some View"))
        #expect(feedHeader.contains("private var bookmarkAgeLimitMenu: some View"))
        #expect(feedHeader.contains("private var bookmarkSupportMenu: some View"))
        #expect(feedHeader.contains("bookmarkArtworkTagMenu"))
        #expect(feedHeader.contains("bookmarkFilterSystemImage"))
        #expect(feedHeaderActionChrome.contains(".buttonStyle(.plain)"))
        #expect(feedHeaderActionChrome.contains(".buttonStyle(.bordered)") == false)

        #expect(macOSNativeFeedHeader.contains(".padding(.horizontal, 18)"))
        #expect(macOSNativeFeedHeader.contains(".padding(.top, 9)"))
        #expect(macOSNativeFeedHeader.contains(".padding(.bottom, 7)"))
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
        #expect(feedHeader.contains("bookmarkVisibilityMenu") == false)
        #expect(feedHeader.contains("bookmarkFiltersActiveCount = store.bookmarkFeedOptions.activeFilterCount") == false)
        #expect(feedHeader.contains("if bookmarkRestrict == .private") == false)
        #expect(feedHeader.contains("bookmarkFilterSystemImage"))
        #expect(feedHeader.contains("systemImage: \"arrow.up.arrow.down.circle\""))
        #expect(localizable.contains("\"Bookmark Filters\""))
        #expect(localizable.contains("\"value\": \"收藏筛选\""))
        #expect(localizable.contains("\"Pixiv Web only\""))
        #expect(localizable.contains("\"value\": \"Pixiv Web 专属\""))
    }

    @Test("Feed narrowing and filters expose a visible clear chip")
    func feedNarrowingAndFiltersExposeVisibleClearChip() throws {
        let root = try packageRoot()
        let store = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Stores/KeiPixStore.swift"),
            encoding: .utf8
        )
        let pixivLinks = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Stores/KeiPixStore+PixivLinks.swift"),
            encoding: .utf8
        )
        let feedHeader = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/GalleryFeedHeaderView.swift"),
            encoding: .utf8
        )
        let artworkDetail = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/ArtworkDetailView.swift"),
            encoding: .utf8
        )
        let clearChip = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/FeedFilterClearChip.swift"),
            encoding: .utf8
        )
        let l10n = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Support/L10n.swift"),
            encoding: .utf8
        )
        let localizable = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Resources/Localizable.xcstrings"),
            encoding: .utf8
        )

        #expect(store.contains("var feedNarrowingContext: FeedNarrowingContext?"))
        #expect(store.contains("func clearFeedNarrowingContext() async"))
        #expect(store.contains("let preservedArtwork = selectedArtwork"))
        #expect(store.contains("selectedArtwork = artworks.first(where: { $0.id == preservedArtwork.id }) ?? preservedArtwork"))
        #expect(store.contains("feedNarrowingContext = nil"))
        #expect(pixivLinks.contains("feedNarrowingContext = .directArtwork(id: id)"))
        #expect(feedHeader.contains("private var activeFeedClearChip: some View"))
        #expect(feedHeader.contains("FeedFilterClearChip("))
        #expect(feedHeader.contains("clearActiveFeedNarrowing("))
        #expect(artworkDetail.contains("private var activeDetailFeedClearChip: some View"))
        #expect(artworkDetail.contains("clearDetailFeedNarrowing("))
        #expect(clearChip.contains("struct FeedFilterClearChip: View"))
        #expect(feedHeader.contains("L10n.clearFeedFilter"))
        #expect(l10n.contains("static var clearFeedFilter"))
        #expect(l10n.contains("static var pixivIDResultFormat"))
        #expect(localizable.contains("\"Clear Feed Filter\""))
        #expect(localizable.contains("\"Pixiv ID #%d\""))
    }

    @Test("Feed and library status chrome uses compact counts")
    func feedAndLibraryStatusChromeUsesCompactCounts() throws {
        let root = try packageRoot()
        let galleryView = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/GalleryView.swift"),
            encoding: .utf8
        )
        let feedHeader = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/GalleryFeedHeaderView.swift"),
            encoding: .utf8
        )
        let bookmarkTags = try String(contentsOf: root.appending(path: "Sources/KeiPix/Views/BookmarkTagsView.swift"), encoding: .utf8)
        let browsingHistory = try String(contentsOf: root.appending(path: "Sources/KeiPix/Views/BrowsingHistoryView.swift"), encoding: .utf8)
        let mangaWatchlist = try String(contentsOf: root.appending(path: "Sources/KeiPix/Views/MangaWatchlistView.swift"), encoding: .utf8)
        let novelWatchlist = try String(contentsOf: root.appending(path: "Sources/KeiPix/Views/NovelWatchlistView.swift"), encoding: .utf8)
        let trendingTags = try String(contentsOf: root.appending(path: "Sources/KeiPix/Views/TrendingTagsView.swift"), encoding: .utf8)
        let userPreviewList = try String(contentsOf: root.appending(path: "Sources/KeiPix/Views/UserPreviewListView.swift"), encoding: .utf8)
        let workSubscriptions = try String(contentsOf: root.appending(path: "Sources/KeiPix/Views/WorkSubscriptionsView.swift"), encoding: .utf8)

        #expect(galleryView.contains("private var feedContextSummary: String"))
        #expect(galleryView.contains("private var feedDetailSummary: String") == false)
        #expect(galleryView.contains("private var feedStatusText: String") == false)
        #expect(galleryView.contains("L10n.nextPageAvailable") == false)
        #expect(galleryView.contains("L10n.noMorePages") == false)
        #expect(feedHeader.contains("private var feedCountBadge: some View"))
        #expect(feedHeader.contains("private var compactFeedCountText: String"))
        #expect(feedHeader.contains("private var compactFeedCountAccessibilityText: String"))
        #expect(feedHeader.contains("store.clientFilteredArtworks.count"))
        #expect(feedHeader.contains("L10n.nextPageAvailable") == false)
        #expect(feedHeader.contains("L10n.noMorePages") == false)
        #expect(bookmarkTags.contains("private var bookmarkTagSummary: String"))
        #expect(bookmarkTags.contains("return \"\\(filteredTags.count.formatted())/\\(tags.count.formatted())\""))
        #expect(bookmarkTags.contains("return filteredTags.count.formatted()"))
        #expect(browsingHistory.contains("let visibleCount = filteredPixivHistoryArtworks.count"))
        #expect(browsingHistory.contains("return \"\\(visibleCount.formatted())/\\(store.artworks.count.formatted())\""))
        #expect(browsingHistory.contains("return visibleCount.formatted()"))
        #expect(mangaWatchlist.contains("return visibleSeries.count.formatted()"))
        #expect(mangaWatchlist.contains("return \"\\(filteredSeries.count.formatted())/\\(visibleSeries.count.formatted())\""))
        #expect(novelWatchlist.contains("return novelStore.watchlistSeries.count.formatted()"))
        #expect(trendingTags.contains("return tags.count.formatted()"))
        #expect(userPreviewList.contains("let counts = \"\\(visiblePreviews.count.formatted())/\\(previews.count.formatted())\""))
        #expect(workSubscriptions.contains("var parts = [count.formatted()]"))
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
        #expect(settingsView.contains("confirmationDialog("))
        #expect(settingsView.contains("L10n.copyRefreshToken,\n                isPresented: $coordinator.isRefreshTokenCopyConfirmationPresented"))
        #expect(settingsView.contains("copyCurrentRefreshToken()"))
        #expect(settingsView.contains("PasteboardWriter.copy(refreshToken)"))
        #expect(settingsView.contains("L10n.copyRefreshTokenConfirmationMessage"))
        #expect(coordinator.contains("isRefreshTokenCopyConfirmationPresented"))
    }

    @Test("Settings workspace uses adaptive OS 26 layout")
    func settingsWorkspaceUsesAdaptiveOS26Layout() throws {
        let root = try packageRoot()
        let settingsView = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/SettingsView.swift"),
            encoding: .utf8
        )
        let settingsSurface = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/LibrarySurfaceComponents.swift"),
            encoding: .utf8
        )
        let migratedPages = [
            "Sources/KeiPix/Views/Settings/AccountSettingsPage.swift",
            "Sources/KeiPix/Views/Settings/DiscoverySettingsPage.swift",
            "Sources/KeiPix/Views/Settings/DownloadsSettingsPage.swift",
            "Sources/KeiPix/Views/Settings/GeneralSettingsPage.swift",
            "Sources/KeiPix/Views/Settings/KeyboardSettingsPage.swift",
            "Sources/KeiPix/Views/Settings/PrivacySettingsPage.swift",
            "Sources/KeiPix/Views/Settings/ReadingSettingsPage.swift",
            "Sources/KeiPix/Views/Settings/SafetySettingsPage.swift",
            "Sources/KeiPix/Views/Settings/SharingSettingsPage.swift",
            "Sources/KeiPix/Views/Settings/StorageSettingsPage.swift"
        ]

        #expect(settingsView.contains("private var settingsRoot: some View"))
        #expect(settingsView.contains("#if os(macOS)\n        NavigationSplitView"))
        #expect(settingsView.contains("#else\n        compactSettingsWorkspace"))
        #expect(settingsView.contains("private var compactSettingsWorkspace: some View"))
        #expect(settingsView.contains("private var categoryRail: some View"))
        #expect(settingsView.contains("private var categoryMenu: some View"))
        #expect(settingsView.contains("private var compactCategoryShortcuts: [SettingsCategory]"))
        #expect(settingsView.contains("private let compactContentMaxWidth: CGFloat = 860"))
        #expect(settingsView.contains(".frame(maxWidth: compactContentMaxWidth, alignment: .leading)"))
        #expect(settingsView.contains("OS26LibrarySearchField("))
        #expect(settingsView.contains(".environment(\\.os26SettingsPageShowsHeader, false)"))
        #expect(settingsView.contains(".environment(\\.os26SettingsPageUsesAdaptiveGrid, true)"))
        #expect(settingsView.contains(".frame(\n            minWidth: 820"))
        #expect(settingsView.contains("Text(coordinator.selection.title)") == false)

        #expect(settingsSurface.contains("struct OS26SettingsPage<Content: View>: View"))
        #expect(settingsSurface.contains("struct OS26SettingsSection<Content: View>: View"))
        #expect(settingsSurface.contains("struct OS26SettingsActionButton: View"))
        #expect(settingsSurface.contains("LazyVGrid("))
        #expect(settingsSurface.contains("private struct OS26SettingsPageMetrics"))
        #expect(settingsSurface.contains("let metrics = OS26SettingsPageMetrics("))
        #expect(settingsSurface.contains("count: columnCount"))
        #expect(settingsSurface.contains("if width >= 590 { return 2 }"))
        #expect(settingsSurface.contains(".frame(maxWidth: .infinity, alignment: metrics.pageAlignment)"))
        #expect(settingsSurface.contains("var pageAlignment: Alignment"))
        #expect(settingsSurface.contains(".navigationTitle(showsHeader ? title : \"\")"))
        #expect(settingsSurface.contains(".navigationBarTitleDisplayMode(showsHeader ? .automatic : .inline)"))
        #expect(settingsSurface.contains(".keiGlass(22)"))

        let accountSettings = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/Settings/AccountSettingsPage.swift"),
            encoding: .utf8
        )
        #expect(accountSettings.contains("OS26SettingsSection(\n                L10n.session"))
        #expect(accountSettings.contains("OS26SettingsSection(\n                L10n.account") == false)

        for relativePath in migratedPages {
            let source = try String(contentsOf: root.appending(path: relativePath), encoding: .utf8)
            #expect(source.contains("OS26SettingsPage("), "\(relativePath) should use the adaptive settings page shell")
            #expect(source.contains("OS26SettingsSection("), "\(relativePath) should use OS26 settings cards")
            #expect(source.contains("Form {") == false, "\(relativePath) should not keep the old grouped Form shell")
            #expect(source.contains(".formStyle(.grouped)") == false, "\(relativePath) should not keep the old grouped Form shell")
        }
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
        let pixivAPI = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Services/PixivAPI.swift"),
            encoding: .utf8
        )
        let creatorTagModels = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Models/CreatorTagModels.swift"),
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
        let iPadContentView = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/ContentView_iPadOS.swift"),
            encoding: .utf8
        )
        let novelGalleryView = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/NovelGalleryView.swift"),
            encoding: .utf8
        )
        let creatorFeedContextCard = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/CreatorFeedContextCard.swift"),
            encoding: .utf8
        )

        #expect(galleryView.contains("usesNativeGalleryCollection"))
        #expect(galleryView.contains("usesArtworkMasonry"))
        #expect(galleryView.contains("let galleryLayoutAdaptation: GalleryLayoutAdaptation"))
        #expect(galleryView.contains("galleryLayoutAdaptation: GalleryLayoutAdaptation = .fullMasonry"))
        #expect(galleryView.contains("private var effectiveGalleryLayoutMode: GalleryLayoutMode"))
        #expect(galleryView.contains("galleryLayoutAdaptation.effectiveMode(for: store.galleryLayoutMode)"))
        #expect(galleryView.contains("galleryLayoutAdaptation.masonryConfiguration(for: effectiveGalleryLayoutMode)"))
        #expect(galleryView.contains("effectiveGalleryLayoutMode.rawValue"))
        #expect(galleryView.contains("NativeGalleryCollectionView("))
        #expect(galleryView.contains("let onGalleryScrollDirectionChange: ((NativeGalleryScrollDirection) -> Void)?"))
        #expect(galleryView.contains("onScrollDirectionChange: onGalleryScrollDirectionChange"))
        #expect(galleryView.contains("onNearContentEnd: triggerAutomaticLoadMoreIfNeeded"))
        #expect(galleryView.contains("onPrefetchItems: prefetchNativeGalleryItems"))
        #expect(galleryView.contains("@State private var nativePrefetchScheduler = GalleryImagePrefetchScheduler()"))
        #expect(galleryView.contains("GalleryImagePrefetchPolicy.previewURLs("))
        #expect(galleryView.contains("store.hydrateCreatorTagSummariesIfNeeded(for: artworks, limit: 8)"))
        #expect(galleryView.contains("await nativePrefetchScheduler.enqueue(urls)"))
        let prefetchScheduler = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Support/GalleryImagePrefetchScheduler.swift"),
            encoding: .utf8
        )
        #expect(prefetchScheduler.contains("actor GalleryImagePrefetchScheduler"))
        #expect(prefetchScheduler.contains("pendingURLs.count < GalleryImagePrefetchPolicy.pendingURLLimit"))
        #expect(prefetchScheduler.contains("Task.sleep(for: .milliseconds(GalleryImagePrefetchPolicy.delayMilliseconds))"))
        #expect(prefetchScheduler.contains("ImagePipeline.shared.prefetch("))
        #expect(prefetchScheduler.contains("concurrency: GalleryImagePrefetchPolicy.concurrency"))
        #expect(galleryView.contains("GalleryAutoLoadMorePolicy.shouldTrigger("))
        #expect(galleryView.contains("iPadNativeFeedHeader"))
        #expect(galleryView.contains("CreatorFeedContextCard("))
        #expect(galleryView.contains("store.presentedUserProfile = focusedUser"))
        #expect(galleryView.contains("await store.clearCreatorFeedContext()"))
        #expect(novelGalleryView.contains("creatorFeedContextCard"))
        #expect(novelGalleryView.contains("CreatorFeedContextCard("))
        #expect(novelGalleryView.contains("store.presentedUserProfile = focusedUser"))
        #expect(novelGalleryView.contains("await store.clearCreatorFeedContext()"))
        #expect(creatorFeedContextCard.contains("struct CreatorFeedContextCard: View"))
        #expect(creatorFeedContextCard.contains("let contentSystemImage: String"))
        #expect(galleryView.contains("showsFeedCountBadge: false"))
        #expect(galleryView.contains("showsActiveFeedClearChip: false"))
        #expect(galleryView.contains("navigationBarTitleDisplayMode(.inline)"))
        #expect(galleryView.contains("presentation: .iPadCompact"))
        #expect(feedHeader.contains("let showsFeedCountBadge: Bool"))
        #expect(feedHeader.contains("let showsActiveFeedClearChip: Bool"))
        #expect(feedHeader.contains("if showsFeedCountBadge"))
        #expect(feedHeader.contains("if showsActiveFeedClearChip"))
        #expect(iPadContentView.contains("dismissCompactArtworkDetail(clearSelection: route.usesArtworkFeed == false)"))
        #expect(iPadContentView.contains(".onChange(of: store.focusedUser?.id)"))
        #expect(iPadContentView.contains(".onChange(of: store.creatorArtworkTagFilter)"))
        #expect(store.contains("@ObservationIgnored private var hydratingCreatorTagArtworkIDs"))
        #expect(store.contains("@ObservationIgnored private var hydratedCreatorTagArtworkIDs"))
        #expect(store.contains("@ObservationIgnored private var failedCreatorTagArtworkIDs"))
        #expect(store.contains("func hydrateCreatorTagSummariesIfNeeded("))
        #expect(store.contains(".filter(\\.isPixivWebProfileSummary)"))
        #expect(store.contains("let detailedArtwork = try await api.illustDetail(illustID: artworkID)"))
        #expect(store.contains("replaceLoadedArtwork(detailedArtwork)"))
        #expect(store.contains("resetCreatorTagHydrationState()"))
        #expect(navigationHistory.contains("hydrateCreatorTagSummariesIfNeeded("))
        #expect(navigationHistory.contains("enum NavigationHistoryTarget"))
        #expect(navigationHistory.contains("case route(PixivRoute)"))
        #expect(navigationHistory.contains("case creatorFeed(CreatorFeedNavigationTarget)"))
        #expect(pixivAPI.contains("creatorTaggedIllustsFromWebProfile("))
        #expect(pixivAPI.contains("creatorTaggedIllustsFromAppAPI("))
        #expect(pixivAPI.contains("response = try await requestFeed(url: nextURL)"))
        #expect(creatorTagModels.contains("func containsTag(_ tag: String)"))
        #expect(galleryView.contains("nativeHighlightedArtworkIDs"))
        #expect(galleryView.contains("nativeGalleryContentReloadToken(for: galleryItems)"))
        #expect(galleryView.contains("hashNativeGalleryArtworkContent(artwork, into: &hasher)"))
        #expect(galleryView.contains("hasher.combine(artwork.feedPreviewURL(tier: store.feedPreviewImageQualityTier)?.absoluteString)"))
        #expect(galleryView.contains("hasher.combine(artwork)\n") == false)
        #expect(galleryView.contains("private var usesMobileGalleryCardPerformanceMode: Bool"))
        #expect(galleryView.contains("case .phoneTwoColumnMasonry, .portraitTabletMasonry:"))
        #expect(galleryView.contains("isScrollPerformanceOptimized: usesMobileGalleryCardPerformanceMode"))
        #expect(galleryView.contains(".backgroundExtensionEffect(isEnabled: usesMobileGalleryCardPerformanceMode)"))
        #expect(artworkCard.contains("var isScrollPerformanceOptimized = false"))
        #expect(artworkCard.contains("fillsAvailableHeight && isScrollPerformanceOptimized == false"))
        #expect(artworkCard.contains("ArtworkCardMotionModifier("))
        #expect(artworkCard.contains("ArtworkCardInteractionModifier("))
        #expect(artworkCard.contains("if isScrollPerformanceOptimized"))
        #expect(artworkCard.contains("private var usesPhoneFollowBadge: Bool"))
        #expect(artworkCard.contains("UIDevice.current.userInterfaceIdiom == .phone"))
        #expect(artworkCard.contains("static let phone = ArtworkFollowBadgeStyle("))
        #expect(artworkCard.contains("horizontalPadding: 5"))
        #expect(artworkCard.contains("verticalPadding: 2"))
        #expect(galleryView.contains("GalleryFeedLoadingPlaceholder"))
        #expect(galleryView.contains("store.isLoading ? [.loading] : [.empty]"))
        #expect(feedHeader.contains("enum FeedHeaderPresentation"))
        #expect(feedHeader.contains("case iPadCompact"))
        #expect(feedHeader.contains("ViewThatFits(in: .horizontal)"))
        #expect(feedHeader.contains("iPadCompactHeaderStackedActions"))
        #expect(feedHeader.contains("NativeInlineFilterField("))
        #expect(feedHeader.contains("iPadFeedHeaderActionChrome()"))
        #expect(nativeCollection.contains("enum NativeGalleryScrollDirection: Sendable"))
        #expect(nativeCollection.contains("let onScrollDirectionChange: ((NativeGalleryScrollDirection) -> Void)?"))
        #expect(nativeCollection.contains("let onNearContentEnd: (() -> Void)?"))
        #expect(nativeCollection.contains("let onPrefetchItems: (([NativeGalleryCollectionItem]) -> Void)?"))
        #expect(nativeCollection.contains("collectionView.prefetchDataSource = context.coordinator"))
        #expect(nativeCollection.contains("UICollectionViewDataSourcePrefetching"))
        #expect(nativeCollection.contains("prefetchItemsAt indexPaths"))
        #expect(nativeCollection.contains("func update(parent newParent: NativeGalleryCollectionView, collectionView: UICollectionView)"))
        #expect(nativeCollection.contains("collectionLayoutMayNeedRefresh("))
        #expect(nativeCollection.contains("lastRefreshControlEnabled"))
        #expect(nativeCollection.contains("guard needsInitialSnapshot"))
        #expect(nativeCollection.contains("private func configureAccessibility(for item: NativeGalleryCollectionItem)"))
        #expect(nativeCollection.contains("guard case .artwork = item else"))
        #expect(nativeCollection.contains("contentView.accessibilityElementsHidden = true"))
        #expect(nativeCollection.contains("func scrollViewDidScroll(_ scrollView: UIScrollView)"))
        #expect(nativeCollection.contains("triggerNearContentEndIfNeeded(in: scrollView)"))
        #expect(nativeCollection.contains("private var isNearContentEndArmed = true"))
        #expect(nativeCollection.contains("NSView.boundsDidChangeNotification"))
        #expect(nativeCollection.contains("GalleryAutoLoadMorePolicy.isNearContentEnd("))
        #expect(nativeCollection.contains("parent.onScrollDirectionChange?(direction)"))
        #expect(store.contains("var artworkNavigationIntentSerial = 0"))
        #expect(navigationHistory.contains("artworkNavigationIntentSerial += 1"))
        #expect(artworkCard.contains(".minimumScaleFactor(0.82)"))
        #expect(masonryPresentation.contains("case .wide:\n            2"))
        #expect(l10n.contains("static var showDetails: String"))
        #expect(l10n.contains("static var hideDetails: String"))
        #expect(l10n.contains("Tap to select artwork"))
        #expect(nativeCollection.contains("NativeGalleryMasonryNSCollectionViewLayout"))
        #expect(nativeCollection.contains("NativeGalleryMasonryUICollectionViewLayout"))
        #expect(nativeCollection.contains("enum NativeGalleryBoundsInvalidation"))
        #expect(nativeCollection.contains("NativeGalleryBoundsInvalidation.shouldInvalidate("))
        #expect(nativeCollection.contains("override func shouldInvalidateLayout(forBoundsChange newBounds: NSRect) -> Bool"))
        #expect(nativeCollection.contains("override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool"))
        #expect(nativeCollection.contains("oldSize: collectionView.bounds.size"))
        #expect(nativeCollection.contains("newSize: newBounds.size"))
        #expect(nativeCollection.contains("case loading"))
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
        #expect(nativeCollection.contains("showsLargeContentViewer = false"))
        #expect(nativeCollection.contains("largeContentTitle = nil"))
        #expect(nativeCollection.contains("accessibilityLabel = item.pointerTitle"))
        #expect(masonryPresentation.contains("fallbackAspectRatio"))
        #expect(hoverEffect.contains(".hoverEffect(.lift)"))
        #expect(nativeCollection.contains("reloadItems(at: collectionView.indexPathsForVisibleItems())") == false)
        #expect(nativeCollection.contains("reloadItems(at: collectionView.indexPathsForVisibleItems)") == false)
        #expect(nativeInlineFilter.contains("struct NativeInlineFilterField: UIViewRepresentable"))
        #expect(nativeInlineFilter.contains("UISearchTextField"))
        #expect(nativeInlineFilter.contains("UITextFieldDelegate"))
    }

    @Test("Artwork detail author menu exposes pinning without leaving the sheet")
    func artworkDetailAuthorMenuExposesPinning() throws {
        let root = try packageRoot()
        let summary = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/ArtworkSummaryView.swift"),
            encoding: .utf8
        )

        #expect(summary.contains("private func togglePinnedCreator(_ user: PixivUser)"))
        #expect(summary.contains("store.isPinnedCreator(artwork.user)"))
        #expect(summary.contains("store.togglePinnedCreator(user)"))
        #expect(summary.contains("L10n.pinCreator"))
        #expect(summary.contains("L10n.unpinCreator"))
        #expect(summary.contains("L10n.pinnedCreatorFormat"))
        #expect(summary.contains("L10n.unpinnedCreatorFormat"))
    }

    @Test("Artwork cards surface bookmarked state alongside followed authors")
    func artworkCardsSurfaceBookmarkedStateAlongsideFollowedAuthors() throws {
        let root = try packageRoot()
        let card = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/ArtworkCardView.swift"),
            encoding: .utf8
        )
        let gallery = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/GalleryView.swift"),
            encoding: .utf8
        )

        #expect(card.contains("private var statusBadges: some View"))
        #expect(card.contains("if artwork.user.isFollowed"))
        #expect(card.contains("var showsBookmarkedStatusBadge = true"))
        #expect(card.contains("if showsBookmarkedStatusBadge && artwork.isBookmarked"))
        #expect(card.contains("title: L10n.bookmark"))
        #expect(card.contains("title: L10n.bookmarked") == false)
        #expect(card.contains("systemImage: \"bookmark.fill\""))
        #expect(card.contains("emphasizeFollowing = false"))
        #expect(gallery.contains("showsBookmarkedStatusBadge: store.selectedRoute.isOwnBookmarkRoute == false"))
        #expect(gallery.contains("store.emphasizeFollowingArtists"))
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
        #expect(readerView.contains("usesContinuousNovelReader"))
        #expect(readerView.contains("ReaderAdaptiveLayout.usesContinuousNovelReader(platform: readerPlatform)"))
        #expect(readerView.contains("private func resolvedPagedReadingMode(for availableSize: CGSize) -> NovelReadingMode"))
        #expect(readerView.contains("ReaderAdaptiveLayout.effectiveNovelMode("))
        #expect(readerView.contains("continuousReaderLayout"))
        #expect(readerView.contains("NativeNovelContinuousTextView("))
        #expect(readerView.contains("translateContinuousReaderPages(session: session)"))
        #expect(readerView.contains("if usesContinuousNovelReader == false {\n                readingModeButton"))
        #expect(readerView.contains("continuousReaderFooter"))
        #expect(nativeText.contains("NSTextView.scrollableTextView"))
        #expect(nativeText.contains("UITextView"))
        #expect(nativeText.contains("NSAttributedString"))
        #expect(nativeText.contains("NativeNovelTextAttributedStringBuilder"))
        #expect(nativeText.contains("struct NativeNovelContinuousTextView"))
        #expect(nativeText.contains("NativeNovelContinuousTextRepresentable"))
        #expect(nativeText.contains("alwaysBounceVertical = true"))
        #expect(nativeText.contains("showsVerticalScrollIndicator = true"))
        #expect(nativeText.contains("keyboardDismissMode = .interactive"))
        #expect(nativeText.contains("contentInsetAdjustmentBehavior = .never"))
        #expect(nativeText.contains("UIFontMetrics(forTextStyle: .body).scaledFont"))

        guard let continuousLayoutStart = readerView.range(of: "private var continuousReaderLayout"),
              let pagedLayoutStart = readerView.range(of: "// MARK: - Single page layout") else {
            Issue.record("Expected continuous and paged reader layout sections")
            return
        }
        let continuousLayout = String(readerView[continuousLayoutStart.lowerBound..<pagedLayoutStart.lowerBound])
        #expect(continuousLayout.contains(".readerGestures(") == false)
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
        let standaloneReader = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/StandaloneArtworkReader.swift"),
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
        #expect(readerView.contains(".keiPanel(cornerRadius, clipsContent: true)"))
        #expect(readerView.contains(".keiGlass(20)"))
        #expect(readerView.contains(".background(.thinMaterial") == false)
        #expect(readerView.contains("GlassEffectContainer(spacing: 10)"))
        #expect(readerView.contains("@State private var readerAvailableSize: CGSize = .zero"))
        #expect(readerView.contains("ReaderAdaptiveLayout.effectiveArtworkMode("))
        #expect(readerView.contains("readingMode.effectiveMode(forPageCount: pageCount, platform: .current)"))
        #expect(readerView.contains("private var navigationPageStep: Int"))
        #expect(readerView.contains("private var availableReadingModes: [ArtworkReadingMode]"))
        #expect(readerView.contains("ReaderPlatformKind.current == .phone"))
        #expect(readerView.contains("private var readingModeMenu: some View"))
        #expect(readerView.contains("Menu {\n            Section(L10n.readingMode)"))
        #expect(readerView.contains("ControlGroup {"))
        #expect(readerView.contains(".buttonStyle(.bordered)"))
        #expect(readerView.contains("private var pageIndicator: some View"))
        #expect(readerView.contains(".pickerStyle(.segmented)") == false)
        #expect(standaloneReader.contains("if ReaderPlatformKind.current == .phone"))
        #expect(standaloneReader.contains("private func compactHeader(proxy: ScrollViewProxy) -> some View"))
        #expect(standaloneReader.contains("ScrollView(.horizontal)"))
        #expect(standaloneReader.contains("readerActionRail(proxy: proxy)"))
        #expect(standaloneReader.contains(".layoutPriority(1)"))
        #expect(imageScrollView.contains("func handleMagnificationChanged(_ magnification: CGFloat)"))
        #expect(imageScrollView.contains("private func centerDocument()"))
        #expect(imageScrollView.contains("scrollView.contentInsets = NSEdgeInsets("))
        #expect(imageScrollView.contains("completionHandler: { [weak self] in"))
        #expect(iPadImageScrollView.contains("scrollView.isDirectionalLockEnabled = true"))
        #expect(iPadImageScrollView.contains("scrollView.panGestureRecognizer.allowedScrollTypesMask = [.continuous, .discrete]"))
        #expect(iPadImageScrollView.contains("doubleTap.cancelsTouchesInView = false"))
        #expect(iPadImageScrollView.contains("doubleTap.delegate = context.coordinator"))
        #expect(iPadImageScrollView.contains("UIGestureRecognizerDelegate"))
        #expect(iPadImageScrollView.contains("gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch)"))
        #expect(iPadImageScrollView.contains("view is UIControl"))
        #expect(iPadImageScrollView.contains("private var isImageReloadInProgress = false"))
        #expect(iPadImageScrollView.contains("beginImageReload()"))
        #expect(iPadImageScrollView.contains("finishImageReloadWithoutImage()"))
        #expect(iPadImageScrollView.contains("guard isImageReloadInProgress == false else { return }"))
        #expect(iPadImageScrollView.contains("reportZoom(zoomScale: scrollView.zoomScale, force: preservingLogicalZoom == false)"))
        #expect(iPadImageScrollView.contains("scrollView.setContentOffset(.zero, animated: false)"))
        #expect(iPadImageScrollView.contains("let velocity = gesture.velocity(in: gesture.view)"))
        #expect(iPadImageScrollView.contains("gesture.setTranslation(.zero, in: gesture.view)"))
        #expect(readerView.contains(".zIndex(3)"))
        #expect(readerView.contains(".frame(width: 44, height: 56)"))
        #expect(readerView.contains(".contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))"))
        #expect(readerView.contains("Label(L10n.resetZoom, systemImage: \"arrow.down.right.and.arrow.up.left\")\n                            }\n                            .labelStyle(.iconOnly)"))
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
        #expect(artworkSummary.contains("copyLinkButton(showsTitle: false)"))
        #expect(artworkSummary.contains("watchLaterButton(showsTitle: false)"))
        #expect(artworkSummary.contains("let showStatusMessage: (String) -> Void"))
        #expect(artworkSummary.contains("showStatusMessage(message)"))
        #expect(artworkSummary.contains("@State private var actionMessage") == false)
        #expect(artworkSummary.contains("if let actionMessage") == false)
        #expect(artworkSummary.contains("Text(actionMessage)") == false)
        #expect(artworkSummary.contains("\"clock.badge.plus\"") == false)
        #expect(artworkSummary.contains("\"clock\""))
        #expect(artworkSummary.contains("private func openReaderButton") == false)
        #expect(artworkSummary.contains("showsReader") == false)
        #expect(artworkSummary.contains("showsCopyLink") == false)
        #expect(artworkSummary.contains("showsWatchLaterInline") == false)
        #expect(artworkSummary.contains("UIDevice.current.userInterfaceIdiom == .phone"))
        #expect(artworkSummary.contains("L10n.copyLink"))
        #expect(artworkSummary.contains("L10n.addToWatchLater"))
        #expect(artworkSummary.contains("L10n.inWatchLater"))
        #expect(artworkSummary.contains("Text(\"#\\(artwork.id)\")") == false)
        let moreMenu = artworkSummary
            .components(separatedBy: "private func moreMenu")
            .dropFirst()
            .first?
            .components(separatedBy: "private struct AdaptiveArtworkActionLayout")
            .first ?? ""
        #expect(moreMenu.contains("L10n.openReaderWindow") == false)
        #expect(moreMenu.contains("L10n.copyLink") == false)
        #expect(moreMenu.contains("L10n.addToWatchLater") == false)
        #expect(moreMenu.contains("L10n.removeFromWatchLater") == false)
        let metricsRail = artworkSummary
            .components(separatedBy: "private var metricsRail: some View")
            .dropFirst()
            .first?
            .components(separatedBy: "private func copyArtworkSummary")
            .first ?? ""
        #expect(metricsRail.contains("MetricView(title: L10n.views"))
        #expect(metricsRail.contains("MetricView(title: L10n.saves"))
        #expect(metricsRail.contains("L10n.comments") == false)
        #expect(metricsRail.contains("L10n.pages") == false)
        #expect(artworkInformation.contains("ArtworkContextCard("))
        #expect(artworkInformation.contains("contextExpansionBinding"))
        #expect(artworkInformation.contains("TagCloudInspectorSection("))
        #expect(artworkInformation.contains("struct ArtworkInspectorSectionHeader: View"))
        #expect(artworkInformation.contains("ArtworkInspectorSectionHeader("))
        #expect(artworkInformation.contains("ArtworkMetadataRail"))
        #expect(artworkInformation.contains("ArtworkMetadataPill"))
        #expect(artworkInformation.contains("L10n.imageSize"))
        #expect(artworkInformation.contains("\"#\\(artwork.id)\""))
        #expect(artworkInformation.contains("id: \"artwork-id\""))
        #expect(artworkInformation.contains("title: L10n.artworkID"))
        #expect(artworkInformation.contains("CollapsibleInspectorSection") == false)
        #expect(artworkTags.contains("ViewThatFits(in: .horizontal)"))
        #expect(artworkTags.contains("RoundedRectangle(cornerRadius: 13"))
        #expect(artworkDetail.contains("private static let topAnchorID = \"artwork-detail-top\""))
        #expect(artworkDetail.contains("scrollToRestoredPosition(proxy: proxy)"))
        #expect(artworkDetail.contains("proxy.scrollTo(Self.topAnchorID, anchor: .top)"))
        #expect(artworkDetail.contains("@State private var detailActionMessage: String?"))
        #expect(artworkDetail.contains("showStatusMessage: showDetailActionMessage"))
        #expect(artworkDetail.contains("FloatingStatusBanner(maxWidth: 420)"))
        #expect(artworkDetail.contains(".statusMessageAutoDismiss($detailActionMessage, duration: .seconds(2.5))"))
        #expect(artworkComments.contains("ArtworkInspectorSectionHeader("))
        #expect(artworkComments.contains("subtitle: headerSubtitle"))
        #expect(artworkComments.contains("return count.formatted()"))
        #expect(artworkComments.contains("return count > 0 ? count.formatted() : nil") == false)
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
        let downloadedViewer = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/DownloadedArtworkViewer.swift"),
            encoding: .utf8
        )

        #expect(queueView.contains("NativeDownloadQueueListView("))
        #expect(queueView.contains(".os26SheetChrome(.reader)"))
        #expect(downloadedViewer.contains("@State private var readingMode: ArtworkReadingMode = .continuous"))
        #expect(downloadedViewer.contains("ReaderAdaptiveLayout.effectiveArtworkMode("))
        #expect(downloadedViewer.contains("private var doublePageReader: some View"))
        #expect(downloadedViewer.contains("private var navigationPageStep: Int"))
        #expect(downloadedViewer.contains(".pickerStyle(.segmented)") == false)
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
        #expect(historyView.contains("@State private var statusFilter = BrowsingHistoryStatusFilter.all"))
        #expect(historyView.contains("BrowsingHistoryStatusFilter.allCases"))
        #expect(historyView.contains("BrowsingHistoryTimestampLabel.shortLabel("))
        #expect(historyView.contains("item.isBookmarked"))
        #expect(historyView.contains("item.isCreatorFollowed"))
        let historyStatusBadges = historyView
            .components(separatedBy: "private var statusBadges: some View")
            .dropFirst()
            .first?
            .components(separatedBy: "private var pageCountBadge")
            .first ?? ""
        #expect(historyStatusBadges.contains("title: L10n.following"))
        #expect(historyStatusBadges.contains("title: L10n.bookmark"))
        #expect(historyStatusBadges.contains("title: L10n.bookmarked") == false)
        #expect(historyView.contains("pageCountBadge"))
        #expect(historyView.contains("ArtworkCoverCardChrome("))
        #expect(historyView.contains("maskSensitivePreview: store.maskSensitivePreviews"))
        #expect(historyView.contains("historySourceMenu"))
        #expect(historyView.contains("Label(\"\\(item.pageCount) \\(L10n.pages)\", systemImage: \"square.stack\")") == false)
        #expect(nativeCollection.contains("NSCollectionView"))
        #expect(nativeCollection.contains("UICollectionView"))
        #expect(nativeCollection.contains("NSCollectionViewDiffableDataSource"))
        #expect(nativeCollection.contains("UICollectionViewDiffableDataSource"))
        #expect(nativeCollection.contains("NSHostingView"))
        #expect(nativeCollection.contains("UIHostingController"))
        #expect(nativeCollection.contains("NativeBrowsingHistoryCollectionLayout"))
        #expect(nativeCollection.contains("NativeBrowsingHistoryMasonryNSCollectionViewLayout"))
        #expect(nativeCollection.contains("NativeBrowsingHistoryMasonryUICollectionViewLayout"))
        #expect(nativeCollection.contains("ArtworkMasonryPlacement.resolve"))
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
        #expect(bookmarkTagsView.contains("BookmarkTagIndexPresentation.visibleTags("))
        #expect(bookmarkTagsView.contains("bookmarkRestrictScopeMenu"))
        #expect(bookmarkTagsView.contains("Label(L10n.refresh") == false)
        #expect(bookmarkTagsView.contains("@State private var sortMode: BookmarkTagIndexSort"))
        #expect(bookmarkTagsView.contains("LazyVGrid") == false)
        #expect(nativeCollection.contains("NSCollectionView"))
        #expect(nativeCollection.contains("UICollectionView"))
        #expect(nativeCollection.contains("NSCollectionViewDiffableDataSource"))
        #expect(nativeCollection.contains("UICollectionViewDiffableDataSource"))
        #expect(nativeCollection.contains("NativeBookmarkTagCollectionLayout"))
        #expect(nativeCollection.contains("minimumTagItemWidth"))
        #expect(nativeCollection.contains("shortcutItemHeight"))
        #expect(nativeCollection.contains("itemMetrics(for: item)"))
        #expect(nativeCollection.contains("usesFullWidthTagItem(for item:"))
        #expect(nativeCollection.contains("displayWidthScore"))
        #expect(nativeCollection.contains("NativeBookmarkTagLeftAlignedFlowLayout"))
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
        #expect(watchlist.contains("mangaWatchlistTitleActions"))
        #expect(watchlist.contains("showsWatchlistSearchBar"))
        #expect(watchlist.contains(".platformPageHeader(\n            title: L10n.mangaWatchlist") && watchlist.contains("mangaWatchlistTitleActions"))
        #expect(watchlist.contains("onNearContentEnd: showsLoadMoreEntry"))
        #expect(watchlist.contains("LazyVGrid") == false)
        #expect(nativeGrid.contains("NSCollectionView"))
        #expect(nativeGrid.contains("UICollectionView"))
        #expect(nativeGrid.contains("NSCollectionViewDiffableDataSource"))
        #expect(nativeGrid.contains("UICollectionViewDiffableDataSource"))
        #expect(nativeGrid.contains("NativeAdaptiveGridCollectionView<Item: Hashable & Sendable>"))
        #expect(nativeGrid.contains("let onNearContentEnd: (() -> Void)?"))
        #expect(nativeGrid.contains("func scrollViewDidScroll(_ scrollView: UIScrollView)"))
        #expect(nativeGrid.contains("GalleryAutoLoadMorePolicy.isNearContentEnd("))
        #expect(nativeGrid.contains("refreshVisibleHostedContent(in: collectionView)"))
    }

    @Test("Manga watchlist keeps content primary and actions compact")
    func mangaWatchlistKeepsContentPrimaryAndActionsCompact() throws {
        let root = try packageRoot()
        let watchlist = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/MangaWatchlistView.swift"),
            encoding: .utf8
        )
        let socialStore = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Stores/KeiPixStore+Social.swift"),
            encoding: .utf8
        )

        #expect(watchlist.contains("mangaWatchlistCoverAction"))
        #expect(watchlist.contains("mangaWatchlistAuxiliaryActions"))
        #expect(watchlist.contains("mangaWatchlistPrimaryActions") == false)
        #expect(watchlist.contains("mangaWatchlistSeriesLink"))
        #expect(watchlist.contains("Link(destination: url)"))
        #expect(watchlist.contains("Label(L10n.openLatestArtwork, systemImage: \"arrow.right.circle\")"))
        #expect(watchlist.contains("Label(L10n.openSeriesInPixiv, systemImage: \"safari\")"))
        #expect(watchlist.contains(".os26GlassButton(prominent: updateStatus.hasUpdate)") == false)
        #expect(watchlist.contains("Label(L10n.refresh, systemImage: \"arrow.clockwise\")") == false)
        #expect(socialStore.contains("let artwork = try await api.illustDetail(illustID: series.latestContentID)"))
        #expect(socialStore.contains("navigateToArtwork(artwork)"))
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
        #expect(subscriptions.contains("subscriptionTitleActions"))
        #expect(subscriptions.contains(".platformPageHeader(\n            title: L10n.workSubscriptions") && subscriptions.contains("subscriptionTitleActions"))
        #expect(subscriptions.contains(".task(id: store.routeRefreshGeneration)"))
        #expect(subscriptions.contains("await checkForUpdates(showFeedback: false)"))
        #expect(subscriptions.contains("L10n.workSubscriptionsCheckNow") == false)
        #expect(subscriptions.contains("systemImage: isChecking ? \"arrow.triangle.2.circlepath\" : \"arrow.clockwise\"") == false)
        #expect(subscriptions.contains("LazyVGrid") == false)
        #expect(subscriptions.contains("ScrollView {") == false)
    }

    @Test("Route refresh owns compact page refresh chrome")
    func routeRefreshOwnsCompactPageRefreshChrome() throws {
        let root = try packageRoot()
        let browsingHistory = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/BrowsingHistoryView.swift"),
            encoding: .utf8
        )
        let trendingTags = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/TrendingTagsView.swift"),
            encoding: .utf8
        )
        let spotlight = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/SpotlightView.swift"),
            encoding: .utf8
        )
        let mangaWatchlist = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/MangaWatchlistView.swift"),
            encoding: .utf8
        )
        let creatorList = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/UserPreviewListView.swift"),
            encoding: .utf8
        )
        let subscriptions = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/WorkSubscriptionsView.swift"),
            encoding: .utf8
        )

        #expect(browsingHistory.contains(".task(id: store.routeRefreshGeneration)"))
        #expect(browsingHistory.contains("Label(L10n.refresh, systemImage: \"arrow.clockwise\")") == false)
        #expect(trendingTags.contains(".task(id: store.routeRefreshGeneration)"))
        #expect(trendingTags.contains("Label(L10n.refresh, systemImage: \"arrow.clockwise\")") == false)
        #expect(spotlight.contains(".task(id: store.routeRefreshGeneration)"))
        #expect(spotlight.contains("Label(L10n.refresh, systemImage: \"arrow.clockwise\")") == false)
        #expect(mangaWatchlist.contains(".task(id: store.routeRefreshGeneration)"))
        #expect(mangaWatchlist.contains("Label(L10n.refresh, systemImage: \"arrow.clockwise\")") == false)
        #expect(creatorList.contains("if showsCloseButton {\n                ToolbarItem(placement: .secondaryAction)"))
        #expect(subscriptions.contains(".task(id: store.routeRefreshGeneration)"))
        #expect(subscriptions.contains("L10n.workSubscriptionsCheckNow") == false)
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
        #expect(watchLater.contains("watchLaterTitleActions"))
        #expect(watchLater.contains("showsWatchLaterSearchBar"))
        #expect(watchLater.contains(".platformPageHeader(\n            title: L10n.watchLater") && watchLater.contains("watchLaterTitleActions"))
        #expect(watchLater.contains("LazyVGrid") == false)
        #expect(watchLater.contains("ScrollView {") == false)
    }

    @Test("Library management surfaces use OS 26 native search and glass actions")
    func libraryManagementSurfacesUseOS26NativeSearchAndGlassActions() throws {
        let root = try packageRoot()
        let sharedComponents = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/LibrarySurfaceComponents.swift"),
            encoding: .utf8
        )
        let pagePaths = [
            "Sources/KeiPix/Views/BookmarkTagsView.swift",
            "Sources/KeiPix/Views/BrowsingHistoryView.swift",
            "Sources/KeiPix/Views/WatchLaterView.swift",
            "Sources/KeiPix/Views/WorkSubscriptionsView.swift",
            "Sources/KeiPix/Views/MutedContentView.swift",
            "Sources/KeiPix/Views/MangaWatchlistView.swift",
            "Sources/KeiPix/Views/DownloadQueueView.swift",
            "Sources/KeiPix/Views/DownloadQueueRow.swift"
        ]

        #expect(sharedComponents.contains("struct OS26LibrarySearchField: View"))
        #expect(sharedComponents.contains("NativeSearchField("))
        #expect(sharedComponents.contains("usesCollapsedPhoneSearch"))
        #expect(sharedComponents.contains("isPhone && text.isEmpty && isExpanded == false"))
        #expect(sharedComponents.contains("struct OS26LibraryTextEntryField: View"))
        #expect(sharedComponents.contains("struct OS26LibraryLoadingView: View"))
        #expect(sharedComponents.contains("struct OS26LibraryUnavailableView<Actions: View>: View"))
        #expect(sharedComponents.contains("struct OS26PaginationFooter: View"))
        #expect(sharedComponents.contains("struct OS26LoadMoreButton: View") == false)
        #expect(sharedComponents.contains("GlassEffectContainer(spacing: 8)"))
        #expect(sharedComponents.contains("ViewThatFits(in: .horizontal)"))

        for path in pagePaths {
            let source = try String(contentsOf: root.appending(path: path), encoding: .utf8)
            #expect(source.contains(".textFieldStyle(.roundedBorder)") == false, "\(path) should not use legacy rounded fields")
            #expect(source.contains(".buttonStyle(.bordered)") == false, "\(path) should not use legacy bordered buttons")
            #expect(source.contains(".buttonStyle(.borderedProminent)") == false, "\(path) should not use legacy prominent bordered buttons")
            #expect(source.contains("ProgressView(L10n.loading)") == false, "\(path) should not use full-page spinner loading")
            #expect(source.contains("ContentUnavailableView") == false, "\(path) should not use old unavailable chrome")
            #expect(source.contains("OS26LoadMoreButton(") == false, "\(path) should use scroll-triggered pagination, not a manual load-more button")
        }

        for path in pagePaths.dropLast() {
            let source = try String(contentsOf: root.appending(path: path), encoding: .utf8)
            #expect(source.contains("OS26LibrarySearchField("), "\(path) should use native search field chrome")
            #expect(source.contains(".platformGlassControlBar("), "\(path) should keep shared page toolbar chrome")
        }

        let row = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/DownloadQueueRow.swift"),
            encoding: .utf8
        )
        #expect(row.contains("ViewThatFits(in: .horizontal)"))
        #expect(row.contains("compactActionRail"))
        #expect(row.contains(".keiInteractiveGlass(18)"))
        #expect(row.contains(".os26GlassIconButton(prominent: true)"))
    }

    @Test("Library management title chrome keeps filters and actions on the title row")
    func libraryManagementTitleChromeKeepsFiltersAndActionsOnTitleRow() throws {
        let root = try packageRoot()
        let bookmarkTags = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/BookmarkTagsView.swift"),
            encoding: .utf8
        )
        let browsingHistory = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/BrowsingHistoryView.swift"),
            encoding: .utf8
        )
        let mutedContent = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/MutedContentView.swift"),
            encoding: .utf8
        )
        let downloads = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/DownloadQueueView.swift"),
            encoding: .utf8
        )

        #expect(bookmarkTags.contains(".platformPageHeader(\n            title: L10n.bookmarkTags") && bookmarkTags.contains("bookmarkTagTitleActions"))
        #expect(bookmarkTags.contains("if showsBookmarkTagSearchBar"))
        #expect(bookmarkTags.contains("private var bookmarkTagTitleActions: some View"))
        #expect(bookmarkTags.contains("bookmarkRestrictScopeMenu"))
        #expect(bookmarkTags.contains("sortMenu"))

        #expect(browsingHistory.contains(".platformPageHeader(\n            title: L10n.history") && browsingHistory.contains("historyTitleActions"))
        #expect(browsingHistory.contains("if showsHistorySearchBar"))
        #expect(browsingHistory.contains("private var historyTitleActions: some View"))
        #expect(browsingHistory.contains("historySourceMenu"))
        #expect(browsingHistory.contains("historyFilterMenu"))

        #expect(mutedContent.contains(".platformPageHeader(\n            title: L10n.mutedContent") && mutedContent.contains("mutedContentTitleActions"))
        #expect(mutedContent.contains("if showsMutedContentSearchBar"))
        #expect(mutedContent.contains("private var mutedContentTitleActions: some View"))
        #expect(mutedContent.contains("mutedCategoryMenu"))

        #expect(downloads.contains(".platformPageHeader(\n                title: L10n.downloads") && downloads.contains("downloadTitleActions"))
        #expect(downloads.contains("if showsDownloadSearchBar"))
        #expect(downloads.contains("private var downloadTitleActions: some View"))
        #expect(downloads.contains("DownloadQueueSearchBar("))
        #expect(downloads.contains("DownloadQueueActionRail("))
    }

    @Test("Loading placeholders and sheets avoid overlapping legacy chrome")
    func loadingPlaceholdersAndSheetsAvoidOverlappingLegacyChrome() throws {
        let root = try packageRoot()
        let sharedComponents = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/LibrarySurfaceComponents.swift"),
            encoding: .utf8
        )
        let creatorComponents = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/UserPreviewListComponents.swift"),
            encoding: .utf8
        )
        let mutedContent = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/MutedContentView.swift"),
            encoding: .utf8
        )
        let profileSheet = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/UserProfileSheet.swift"),
            encoding: .utf8
        )
        let imageSourceSheet = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/ImageSourceSearchSheet.swift"),
            encoding: .utf8
        )
        let spotlight = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/SpotlightView.swift"),
            encoding: .utf8
        )
        let logViewer = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/LogViewerView.swift"),
            encoding: .utf8
        )

        #expect(sharedComponents.contains("struct OS26InlineLoadingView: View"))
        #expect(sharedComponents.contains("struct OS26InlineUnavailableView<Actions: View>: View"))
        #expect(sharedComponents.contains("struct OS26SkeletonCardSurface: ViewModifier"))
        #expect(sharedComponents.contains("struct OS26GlassCompatibleSegmentedPicker"))
        #expect(sharedComponents.contains("ViewThatFits(in: .horizontal)"))

        #expect(creatorComponents.contains("CreatorPreviewListLoadingPlaceholder"))
        #expect(creatorComponents.contains("let minimum: CGFloat = layoutMode.usesExpandedPreview ? 380 : 280"))
        #expect(creatorComponents.contains(".os26SkeletonSurface(20)"))
        #expect(creatorComponents.contains("ContentUnavailableView") == false)

        #expect(mutedContent.contains("private var mutedCategoryMenu: some View"))
        #expect(mutedContent.contains("Picker(L10n.mutedContent, selection: $category)"))
        #expect(mutedContent.contains("private var addTagButton: some View"))
        #expect(mutedContent.contains(".os26GlassIconButton(prominent: true)"))
        #expect(mutedContent.contains("ContentUnavailableView") == false)
        #expect(mutedContent.contains(".textFieldStyle(.roundedBorder)") == false)

        #expect(profileSheet.contains(".os26SkeletonSurface(18)"))
        #expect(profileSheet.contains("OS26LibraryUnavailableView("))
        #expect(profileSheet.contains("ContentUnavailableView") == false)

        #expect(imageSourceSheet.contains("OS26InlineLoadingView("))
        #expect(imageSourceSheet.contains("OS26InlineUnavailableView("))
        #expect(imageSourceSheet.contains("ContentUnavailableView") == false)

        #expect(spotlight.contains("OS26LibraryLoadingView(title: L10n.loading, systemImage: \"newspaper\")"))
        #expect(spotlight.contains("OS26LibraryUnavailableView("))
        #expect(spotlight.contains(".background(.regularMaterial") == false)

        #expect(logViewer.contains("OS26LibrarySearchField("))
        #expect(logViewer.contains("OS26LibraryLoadingView("))
        #expect(logViewer.contains(".textFieldStyle(.roundedBorder)") == false)
    }

    @Test("Bookmark, login, related, and settings sheets avoid legacy chrome")
    func bookmarkLoginRelatedAndSettingsSheetsAvoidLegacyChrome() throws {
        let root = try packageRoot()
        let relativePaths = [
            "Sources/KeiPix/Views/BookmarkEditorView.swift",
            "Sources/KeiPix/Views/TokenLoginSheetView.swift",
            "Sources/KeiPix/Views/LoginSheetView.swift",
            "Sources/KeiPix/Views/ArtworkRelatedView.swift",
            "Sources/KeiPix/Views/NovelRelatedView.swift",
            "Sources/KeiPix/Views/Settings/DownloadsSettingsPage.swift",
            "Sources/KeiPix/Views/Settings/GeneralSettingsPage.swift",
            "Sources/KeiPix/Views/Settings/SharingSettingsPage.swift",
            "Sources/KeiPix/Views/Settings/KeyboardSettingsPage.swift"
        ]

        for relativePath in relativePaths {
            let source = try String(contentsOf: root.appending(path: relativePath), encoding: .utf8)
            #expect(source.contains("ContentUnavailableView") == false, "\(relativePath) should use OS26 unavailable surfaces")
            #expect(source.contains(".textFieldStyle(.roundedBorder)") == false, "\(relativePath) should use native/glass text entry")
            #expect(source.contains(".buttonStyle(.bordered)") == false, "\(relativePath) should use glass actions")
            #expect(source.contains(".buttonStyle(.borderedProminent)") == false, "\(relativePath) should use prominent glass actions")
            #expect(source.contains(".keiPanel(") == false, "\(relativePath) should avoid legacy panel material")
            #expect(source.contains(".background(.regularMaterial") == false, "\(relativePath) should avoid old material cards")
            #expect(source.contains(".background(.thinMaterial") == false, "\(relativePath) should avoid old material cards")
        }

        let bookmarkEditor = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/BookmarkEditorView.swift"),
            encoding: .utf8
        )
        #expect(bookmarkEditor.contains("OS26LibraryTextEntryField(text: $customTagInput"))
        #expect(bookmarkEditor.contains("OS26LibrarySearchField("))
        #expect(bookmarkEditor.contains("OS26InlineUnavailableView("))

        let relatedArtworks = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/ArtworkRelatedView.swift"),
            encoding: .utf8
        )
        #expect(relatedArtworks.contains("OS26InlineLoadingView("))
        #expect(relatedArtworks.contains("OS26PaginationFooter("))
        #expect(relatedArtworks.contains("OS26LoadMoreButton(") == false)

        let novelRelated = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/NovelRelatedView.swift"),
            encoding: .utf8
        )
        let novelWatchlist = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/NovelWatchlistView.swift"),
            encoding: .utf8
        )
        let novelGallery = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/NovelGalleryView.swift"),
            encoding: .utf8
        )
        let artworkSeries = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/ArtworkSeriesView.swift"),
            encoding: .utf8
        )
        for source in [novelRelated, novelWatchlist, novelGallery, artworkSeries] {
            #expect(source.contains("OS26PaginationFooter("))
            #expect(source.contains("OS26LoadMoreButton(") == false)
            #expect(source.contains("Label(L10n.loadMore") == false)
        }

        let tokenLogin = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/TokenLoginSheetView.swift"),
            encoding: .utf8
        )
        #expect(tokenLogin.contains("SecureField(L10n.refreshToken"))
        #expect(tokenLogin.contains(".keiInteractiveGlass(16)"))
    }

    @Test("Creator list, search, menu, and drop use native P2 bridges")
    func creatorListSearchMenuAndDropUseNativeP2Bridges() throws {
        let root = try packageRoot()
        let creatorComponents = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/UserPreviewListComponents.swift"),
            encoding: .utf8
        )
        let creatorCard = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/UserPreviewCard.swift"),
            encoding: .utf8
        )
        let store = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Stores/KeiPixStore.swift"),
            encoding: .utf8
        )
        let storeSocial = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Stores/KeiPixStore+Social.swift"),
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
        let userPreviewList = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/UserPreviewListView.swift"),
            encoding: .utf8
        )
        let searchBarStart = try #require(creatorComponents.range(of: "struct CreatorListSearchBar: View"))
        let searchBarEnd = try #require(creatorComponents.range(of: "private struct CreatorSearchScopeChip: View"))
        let searchBarSource = String(creatorComponents[searchBarStart.lowerBound..<searchBarEnd.lowerBound])
        let optionsMenuStart = try #require(creatorComponents.range(of: "struct CreatorListViewOptionsMenu: View"))
        let optionsMenuEnd = try #require(creatorComponents.range(of: "/// Bulk-action menu rendered in the creator list's toolbar."))
        let optionsMenuSource = String(creatorComponents[optionsMenuStart.lowerBound..<optionsMenuEnd.lowerBound])

        #expect(creatorComponents.contains("NativeCreatorPreviewCollectionView("))
        #expect(creatorComponents.contains(".frame(maxWidth: .infinity, maxHeight: .infinity)"))
        #expect(creatorComponents.contains(".backgroundExtensionEffect(isEnabled: true)"))
        #expect(creatorComponents.contains("NativeSearchField("))
        #expect(searchBarSource.contains("NativeSearchField("))
        #expect(searchBarSource.contains("Image(systemName: \"magnifyingglass\")") == false)
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
        #expect(nativeCollection.contains("collectionView.contentInsetAdjustmentBehavior = .automatic"))
        #expect(nativeCollection.contains("registerContentScrollViewIfNeeded(collectionView)"))
        #expect(nativeCollection.contains("viewController.setContentScrollView(collectionView, for: .bottom)"))
        #expect(nativeCollection.contains("registeredContentScrollViewController?.setContentScrollView(nil, for: .bottom)"))
        #expect(nativeCollection.contains("let contentReloadToken: Int"))
        #expect(nativeCollection.contains("let onNearContentEnd: (() -> Void)?"))
        #expect(nativeCollection.contains("GalleryAutoLoadMorePolicy.isNearContentEnd("))
        #expect(nativeCollection.contains("func scrollViewDidScroll(_ scrollView: UIScrollView)"))
        #expect(nativeCollection.contains("lastContentReloadToken"))
        #expect(nativeCollection.contains("applySnapshotUsingReloadData"))
        #expect(creatorComponents.contains("onNearContentEnd: loadMoreFromNearContentEnd"))
        #expect(creatorComponents.contains("shouldAutoTopUpSparseVisibleCreators"))
        #expect(creatorComponents.contains("sparseVisibleCreatorTopUpKey"))
        #expect(creatorComponents.contains("minimumAutoFilledCreatorCount"))
        #expect(creatorComponents.contains("maximumSparseAutoTopUpPages"))
        #expect(creatorComponents.contains("autoLoadContextKey"))
        #expect(creatorComponents.contains("loadMoreFromNearContentEnd()"))
        #expect(creatorComponents.contains("autoTopUpSparseVisibleCreatorsIfNeeded()"))
        #expect(userPreviewList.contains("CreatorPreviewListContent("))
        #expect(userPreviewList.contains("sessionRefreshKey"))
        #expect(userPreviewList.contains("creatorAutoLoadContextKey"))
        #expect(userPreviewList.contains("creatorTitleActions"))
        #expect(userPreviewList.contains("creatorRestrictMenu") == false)
        #expect(userPreviewList.contains("CreatorListViewOptionsMenu(\n                    mode: mode,\n                    restrict: restrictBinding"))
        #expect(optionsMenuSource.contains("if mode.usesRestrictPicker"))
        #expect(optionsMenuSource.contains("Picker(L10n.followingCreators, selection: $restrict)"))
        #expect(userPreviewList.contains("private func clearCreatorSearch()"))
        #expect(userPreviewList.contains("showsRestrictPicker: false"))
        #expect(creatorCard.contains("followingButtonTitle"))
        #expect(creatorCard.contains("Label(followingButtonTitle, systemImage: \"person.crop.circle.badge.checkmark\")"))
        #expect(userPreviewList.contains(".frame(maxWidth: .infinity, maxHeight: .infinity)"))
        #expect(store.contains("creatorPreviewArtworkCacheGeneration"))
        #expect(store.contains("creatorPreviewArtworkRequests"))
        #expect(storeSocial.contains("func cachedCreatorPreviewArtworks(for user: PixivUser)"))
        #expect(storeSocial.contains("creatorPreviewArtworkCacheGeneration &+= 1"))
        #expect(creatorComponents.contains("creatorPreviewArtworkCacheGeneration: Int"))
        #expect(creatorComponents.contains("cachedCreatorPreviewArtworks(preview.user)"))
        #expect(creatorCard.contains("cachedPreviewArtworks: [PixivArtwork]"))
        #expect(creatorCard.contains("resetFetchState()"))
        #expect(nativeSearch.contains("NSSearchField"))
        #expect(nativeSearch.contains("UISearchTextField"))
        #expect(enhancedMenu.contains("NSMenu"))
        #expect(enhancedMenu.contains("menuItem.target = target"))
        #expect(enhancedMenu.contains("case checkFollowVisibility"))
        #expect(nativeDrop.contains("NSDraggingInfo"))
        #expect(nativeDrop.contains("NativeDropPayload"))
        #expect(nativeDrop.contains("UTType.utf8PlainText"))
    }

    @Test("Creator list transient status is scoped and expires")
    func creatorListTransientStatusIsScopedAndExpires() throws {
        let root = try packageRoot()
        let userPreviewList = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/UserPreviewListView.swift"),
            encoding: .utf8
        )

        #expect(userPreviewList.contains(".task(id: bulkStatusText)"))
        #expect(userPreviewList.contains(".task(id: undoAction?.id)"))
        #expect(userPreviewList.contains("await dismissUndoActionIfNeeded(undoAction?.id)"))
        #expect(userPreviewList.contains(".onChange(of: modeKey)"))
        #expect(userPreviewList.contains("clearTransientCreatorListChrome()"))
        #expect(userPreviewList.contains(".padding(.bottom, statusBannerBottomPadding)"))
        #expect(userPreviewList.contains("private var statusBannerBottomPadding: CGFloat"))
        #expect(userPreviewList.contains("presentCreatorListError(error)"))
        #expect(userPreviewList.contains("error is CancellationError"))
        #expect(userPreviewList.contains("NSURLErrorCancelled"))
    }

    @Test("Search clear actions reset route state and loading surfaces stay stable")
    func searchClearActionsResetRouteStateAndLoadingSurfacesStayStable() throws {
        let root = try packageRoot()
        let storeSearch = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Stores/KeiPixStore+Search.swift"),
            encoding: .utf8
        )
        let macContentView = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/ContentView.swift"),
            encoding: .utf8
        )
        let iPadContentView = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/ContentView_iPadOS.swift"),
            encoding: .utf8
        )
        let feedHeader = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/GalleryFeedHeaderView.swift"),
            encoding: .utf8
        )
        let creatorList = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/UserPreviewListView.swift"),
            encoding: .utf8
        )
        let creatorComponents = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/UserPreviewListComponents.swift"),
            encoding: .utf8
        )
        let profileSheet = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/UserProfileSheet.swift"),
            encoding: .utf8
        )
        let nativeSearch = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Support/SearchFieldNSView.swift"),
            encoding: .utf8
        )
        let nativeInlineFilter = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Support/NativeInlineFilterField.swift"),
            encoding: .utf8
        )

        #expect(storeSearch.contains("func clearSearchText()"))
        #expect(storeSearch.contains("searchText = \"\""))
        #expect(storeSearch.contains("searchSubmissionID += 1"))
        #expect(storeSearch.contains("allSearchPopularPreviewArtworks = []"))
        #expect(storeSearch.contains("clearNavigationHistory()"))

        #expect(macContentView.contains(".searchable(text: globalSearchTextBinding"))
        #expect(macContentView.contains("private var globalSearchTextBinding"))
        #expect(macContentView.contains("private var hasActiveGlobalSearchText"))
        #expect(macContentView.contains("store.clearSearchText()"))
        #expect(macContentView.contains("|| store.selectedRoute.usesNovelFeed"))
        #expect(macContentView.contains("|| store.canNavigateBack"))
        #expect(iPadContentView.contains("MobileGlobalSearchModifier("))
        #expect(iPadContentView.contains("searchText: globalSearchTextBinding"))
        #expect(iPadContentView.contains(".searchable(text: searchText"))
        #expect(iPadContentView.contains("private var globalSearchTextBinding"))
        #expect(iPadContentView.contains("private var hasActiveGlobalSearchText"))
        #expect(iPadContentView.contains("store.clearSearchText()"))
        #expect(iPadContentView.contains("|| store.selectedRoute.usesNovelFeed"))
        #expect(iPadContentView.contains("|| store.canNavigateBack"))

        #expect(feedHeader.contains("private var hasActiveArtworkSearch"))
        #expect(feedHeader.contains("private func clearArtworkSearch()"))
        #expect(feedHeader.contains("case .artworkSearch"))
        #expect(feedHeader.contains("case .creatorContext"))
        #expect(feedHeader.contains("action: .artworkSearch"))

        #expect(creatorList.contains("isLoadingInitial: isLoading && previews.isEmpty"))
        #expect(creatorList.contains("mode.requiresSearchKeyword == false || searchKeyword.isEmpty == false"))
        #expect(creatorList.contains("globalSearchKeyword: searchKeyword"))
        #expect(creatorList.contains("clearCreatorSearch()"))
        #expect(creatorList.contains("store.clearSearchText()"))
        #expect(creatorList.contains("let showsCloseButton: Bool"))
        #expect(creatorList.contains("showsCloseButton: Bool = false"))
        #expect(creatorList.contains("if showsCloseButton"))
        #expect(creatorComponents.contains("CreatorSearchScopeChip"))
        #expect(creatorComponents.contains("CreatorSearchLandingState"))
        #expect(creatorComponents.contains("CreatorPreviewListLoadingPlaceholder"))
        #expect(creatorComponents.contains("CreatorPreviewSkeletonCard"))
        #expect(creatorComponents.contains("contentReloadToken: creatorContentReloadToken"))
        #expect(creatorComponents.contains("hasher.combine(creatorPreviewArtworkCacheGeneration)"))

        #expect(profileSheet.contains("UserProfileLoadingSkeleton"))
        #expect(profileSheet.contains("UserProfileLoadingSkeletonLayout"))
        #expect(profileSheet.contains("GeometryReader { proxy in"))
        #expect(profileSheet.contains("layout.artworkColumns"))
        #expect(profileSheet.contains("UserPreviewListView(store: store, mode: mode, showsCloseButton: true)"))
        #expect(profileSheet.contains(".id(contentState.animationID)"))
        #expect(profileSheet.contains(".animation(.snappy(duration: 0.22), value: contentState)"))
        #expect(profileSheet.contains("FlowLayout(spacing: 8)"))

        #expect(nativeSearch.contains("searchField.clearButtonMode = .always"))
        #expect(nativeSearch.contains("func textFieldShouldClear(_ textField: UITextField) -> Bool"))
        #expect(nativeSearch.contains("onTextChange(\"\")"))
        #expect(nativeInlineFilter.contains("func textFieldShouldClear(_ textField: UITextField) -> Bool"))
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
        let errorToast = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Support/ErrorToast.swift"),
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
        #expect(savedSearches.contains(".platformGlassControlBar(verticalPadding: 8, topPadding: 2)"))
        #expect(savedSearches.contains("GlassEffectContainer(spacing: 8)"))
        #expect(savedSearches.contains(".keiInteractiveGlass(16)"))
        #expect(savedSearches.contains(".textFieldStyle(.roundedBorder)") == false)
        #expect(savedSearches.contains(".buttonStyle(.bordered)") == false)

        #expect(searchFilters.contains(".keiGlass(18)"))
        #expect(searchFilters.contains("GlassEffectContainer(spacing: 8)"))
        #expect(searchFilters.contains(".buttonStyle(.glassProminent)"))
        #expect(searchFilters.contains("PixivPremiumMenuLabel("))
        #expect(searchFilters.contains("showsPixivPremiumMarker(isPremium: isPremium)"))
        #expect(searchFilters.contains(".textFieldStyle(.roundedBorder)") == false)

        #expect(quickOpenSheet.contains("NativeSearchField("))
        #expect(quickOpenSheet.contains("GeometryReader { proxy in"))
        #expect(quickOpenSheet.contains("private struct PixivIDOpenSheetLayout: Equatable"))
        #expect(quickOpenSheet.contains("layout.isCompact"))
        #expect(quickOpenSheet.contains("compactPasteButton"))
        #expect(quickOpenSheet.contains("presentationDetents(PixivIDOpenSheetLayout.mobilePresentationDetents)"))
        #expect(quickOpenSheet.contains(".keiInteractiveGlass(14)"))
        #expect(quickOpenSheet.contains(".background(.quaternary") == false)
        #expect(errorToast.contains(".fixedSize(horizontal: true, vertical: false)"))
        #expect(errorToast.contains("includesOuterPadding"))

        #expect(imageSourceSearch.contains("private func resultRow"))
        #expect(imageSourceSearch.contains("LazyVStack(spacing: 8)"))
        #expect(imageSourceSearch.contains(".keiInteractiveGlass(16)"))
        #expect(imageSourceSearch.contains("List(results)") == false)

        #expect(creatorComponents.contains(".buttonStyle(.borderless)") == false)
        #expect(creatorComponents.contains(".buttonStyle(.borderedProminent)") == false)
        #expect(creatorComponents.contains(".os26GlassButton(prominent: true)"))
        #expect(creatorComponents.contains("OS26LibraryUnavailableView("))
    }

    @Test("Pixiv Premium-only surfaces expose visible premium markers")
    func pixivPremiumSurfacesExposeVisibleMarkers() throws {
        let root = try packageRoot()
        let premiumBadge = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/PixivPremiumBadge.swift"),
            encoding: .utf8
        )
        let browsingHistory = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/BrowsingHistoryView.swift"),
            encoding: .utf8
        )
        let galleryFeedHeader = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/GalleryFeedHeaderView.swift"),
            encoding: .utf8
        )
        let popularPreview = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/GalleryPopularPreviewStrip.swift"),
            encoding: .utf8
        )
        let mutedContent = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/MutedContentView.swift"),
            encoding: .utf8
        )
        let safetySettings = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/Settings/SafetySettingsPage.swift"),
            encoding: .utf8
        )
        let runtimeReadiness = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/RuntimeReadinessView.swift"),
            encoding: .utf8
        )

        #expect(premiumBadge.contains("struct PixivPremiumBadge: View"))
        #expect(premiumBadge.contains("struct PixivPremiumMenuLabel: View"))
        #expect(premiumBadge.contains("struct PixivPremiumInlineLabel: View"))
        #expect(premiumBadge.contains("0.992"))

        #expect(browsingHistory.contains("requiresPixivPremiumForFullBehavior"))
        #expect(browsingHistory.contains("Picker(L10n.historySource") == false)
        #expect(browsingHistory.contains("PixivPremiumMenuLabel("))
        #expect(galleryFeedHeader.contains("PixivPremiumMenuLabel("))
        #expect(galleryFeedHeader.contains("sort.requiresPixivPremiumForFullPixivWebBehavior") == false)
        #expect(galleryFeedHeader.contains("artworkTagFilterRequiresPixivPremiumForFullPixivWebBehavior") == false)
        #expect(popularPreview.contains("PixivPremiumBadge()"))
        #expect(mutedContent.contains("PixivPremiumMenuLabel("))
        #expect(safetySettings.contains("pixivPremiumSettingsActionButton"))
        #expect(runtimeReadiness.contains("PixivPremiumInlineLabel("))
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
        #expect(creatorCard.contains("private var expandedCommandRail: some View"))
        #expect(creatorCard.contains("compactNavigationChip("))
        #expect(creatorCard.contains("private let tileHeight: CGFloat = 178"))
        #expect(creatorCard.contains(".buttonStyle(.glass)"))
        #expect(creatorCard.contains(".buttonBorderShape(.capsule)"))
        #expect(creatorCard.contains(".truncationMode(.middle)"))
        #expect(creatorCard.contains("cachedArtworks.isEmpty == false"))
        #expect(creatorCard.contains(".task(id: userID)"))
        #expect(nativeCollection.contains("let minimumWidth: CGFloat = 300"))
        #expect(nativeCollection.contains("return 342"))
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
        #expect(recentWorks.contains("contentReloadToken: artworkShelfContentReloadToken"))
        #expect(recentWorks.contains("ViewThatFits(in: .horizontal)"))
        #expect(recentWorks.contains("placeholderCard(index: index, width: cardWidth, imageHeight: 178)"))
        #expect(recentWorks.contains("private var placeholderShelfHeight: CGFloat"))
        #expect(recentWorks.contains("ScrollView(.horizontal)") == false)
        #expect(recentWorks.contains("LazyHStack") == false)

        #expect(relatedCreators.contains("NativeCreatorPreviewCollectionView("))
        #expect(relatedCreators.contains("private var relatedCreatorShelfLayout: NativeCreatorPreviewCollectionLayout"))
        #expect(relatedCreators.contains(".horizontalShelf(itemWidth: relatedCreatorShelfItemWidth, itemHeight: cardHeight)"))
        #expect(relatedCreators.contains("relatedCreatorShelfLayout.viewportHeight ?? cardHeight"))
        #expect(relatedCreators.contains(".frame(height: relatedCreatorShelfHeight)"))
        #expect(relatedCreators.contains("relatedCreatorShelfItems"))
        #expect(relatedCreators.contains("relatedCreatorPlaceholderCard(width: 156, height: 174)"))
        #expect(relatedCreators.contains("private var relatedCreatorPlaceholderHeight: CGFloat"))
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
