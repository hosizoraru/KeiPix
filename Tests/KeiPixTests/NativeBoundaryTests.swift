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

    @Test("Gallery feed layouts use a native collection bridge")
    func galleryFeedLayoutsUseNativeCollectionBridge() throws {
        let root = try packageRoot()
        let galleryView = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Views/GalleryView.swift"),
            encoding: .utf8
        )
        let nativeCollection = try String(
            contentsOf: root.appending(path: "Sources/KeiPix/Support/NativeGalleryCollectionView.swift"),
            encoding: .utf8
        )

        #expect(galleryView.contains("usesNativeGalleryCollection"))
        #expect(galleryView.contains("usesArtworkMasonry"))
        #expect(galleryView.contains("NativeGalleryCollectionView("))
        #expect(galleryView.contains("nativeHighlightedArtworkIDs"))
        #expect(galleryView.contains("nativeGalleryContentReloadToken"))
        #expect(nativeCollection.contains("NativeGalleryMasonryNSCollectionViewLayout"))
        #expect(nativeCollection.contains("NativeGalleryMasonryUICollectionViewLayout"))
        #expect(nativeCollection.contains("ArtworkMasonryPlacement.resolve"))
        #expect(nativeCollection.contains("NSCollectionViewDiffableDataSource"))
        #expect(nativeCollection.contains("UICollectionViewDiffableDataSource"))
        #expect(nativeCollection.contains("NSHostingView"))
        #expect(nativeCollection.contains("UIHostingController"))
        #expect(nativeCollection.contains("UIRefreshControl"))
        #expect(nativeCollection.contains("lastSnapshotItemIDs"))
        #expect(nativeCollection.contains("lastLayoutFingerprint"))
        #expect(nativeCollection.contains("reloadHighlightDeltaIfNeeded"))
        #expect(nativeCollection.contains("reconfigureVisibleItems"))
        #expect(nativeCollection.contains("symmetricDifference"))
        #expect(nativeCollection.contains("reloadItems(at: collectionView.indexPathsForVisibleItems())") == false)
        #expect(nativeCollection.contains("reloadItems(at: collectionView.indexPathsForVisibleItems)") == false)
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
        #expect(recentWorks.contains(".horizontalShelf(itemWidth: cardWidth, itemHeight: cardHeight)"))
        #expect(recentWorks.contains("artworkShelfItems"))
        #expect(recentWorks.contains("ScrollView(.horizontal)") == false)
        #expect(recentWorks.contains("LazyHStack") == false)

        #expect(relatedCreators.contains("NativeCreatorPreviewCollectionView("))
        #expect(relatedCreators.contains(".horizontalShelf(itemWidth: relatedCreatorShelfItemWidth, itemHeight: cardHeight)"))
        #expect(relatedCreators.contains("relatedCreatorShelfItems"))
        #expect(relatedCreators.contains("ScrollView(.horizontal)") == false)
        #expect(relatedCreators.contains("LazyHStack") == false)

        #expect(nativeCollection.contains("case artwork(PixivArtwork)"))
        #expect(nativeCollection.contains("case horizontalShelf(itemWidth: CGFloat, itemHeight: CGFloat)"))
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
