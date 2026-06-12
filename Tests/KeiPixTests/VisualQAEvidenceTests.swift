import Foundation
import Testing
@testable import KeiPix

@Suite("Visual QA evidence")
struct VisualQAEvidenceTests {
    @Test("Manifest parser reads capture script output")
    func manifestParser() throws {
        let text = """
        # KeiPix Visual QA

        - Captured at: 20260525T085911Z
        - Surface: trending-tags
        - App: KeiPix
        - PID: 123
        - Window ID: 456
        - Git commit: abc123
        - Screenshot: trending-tags.png
        """

        let manifest = try #require(VisualQAEvidenceIndex.manifest(from: text, manifestPath: "/tmp/trending-tags.md"))

        #expect(manifest.surface == .trendingTags)
        #expect(manifest.capturedAt == "20260525T085911Z")
        #expect(manifest.screenshotPath == "trending-tags.png")
    }

    @Test("Evidence index reports required surface coverage")
    func surfaceCoverage() {
        let index = VisualQAEvidenceIndex(manifests: [
            VisualQAEvidenceManifest(
                id: "gallery",
                surface: .galleryFeed,
                capturedAt: "20260525T085911Z",
                screenshotPath: "gallery-feed.png",
                manifestPath: "/tmp/gallery-feed.md"
            ),
            VisualQAEvidenceManifest(
                id: "discover",
                surface: .discoverDashboard,
                capturedAt: "20260525T103000Z",
                screenshotPath: "discover-dashboard.png",
                manifestPath: "/tmp/discover-dashboard.md"
            ),
            VisualQAEvidenceManifest(
                id: "downloads",
                surface: .downloadQueue,
                capturedAt: "20260525T103312Z",
                screenshotPath: "download-queue.png",
                manifestPath: "/tmp/download-queue.md"
            ),
            VisualQAEvidenceManifest(
                id: "downloaded-reader",
                surface: .downloadedReader,
                capturedAt: "20260525T103320Z",
                screenshotPath: "downloaded-reader.png",
                manifestPath: "/tmp/downloaded-reader.md"
            ),
            VisualQAEvidenceManifest(
                id: "reader",
                surface: .readerWindow,
                capturedAt: "20260525T103329Z",
                screenshotPath: "reader-window.png",
                manifestPath: "/tmp/reader-window.md"
            ),
            VisualQAEvidenceManifest(
                id: "settings",
                surface: .settingsWindow,
                capturedAt: "20260525T123900Z",
                screenshotPath: "settings-window.png",
                manifestPath: "/tmp/settings-window.md"
            )
        ])

        #expect(index.covers([.discoverDashboard, .galleryFeed]))
        #expect(index.covers([.galleryFeed, .pixivision]) == false)
        #expect(index.covers([.downloadQueue, .readerWindow]))
        #expect(index.covers([.downloadQueue, .downloadedReader]))
        #expect(index.covers([.settingsWindow]))
        #expect(index.summary(for: [.galleryFeed]).contains("1/1"))
        #expect(VisualQASurface(rawValue: "batch-bookmark-preview") == .batchBookmarkPreview)
        #expect(VisualQASurface(rawValue: "pixiv-link-drop") == .pixivLinkDrop)
        #expect(VisualQASurface(rawValue: "pixiv-id-open") == .pixivIDOpen)
        #expect(VisualQASurface(rawValue: "creator-profile") == .creatorProfile)
        #expect(VisualQASurface(rawValue: "manga-watchlist") == .mangaWatchlist)
        #expect(VisualQASurface(rawValue: "series-sheet") == .seriesSheet)
        #expect(VisualQASurface(rawValue: "cached-feed") == .cachedFeed)
        #expect(VisualQASurface(rawValue: "gallery-auto") == .galleryAuto)
        #expect(VisualQASurface(rawValue: "gallery-two-column") == .galleryTwoColumn)
        #expect(VisualQASurface(rawValue: "gallery-three-column") == .galleryThreeColumn)
        #expect(VisualQASurface(rawValue: "gallery-compact") == .galleryCompact)
        #expect(VisualQASurface(rawValue: "novel-feed") == .novelFeed)
        #expect(VisualQASurface(rawValue: "search-workspace") == .searchWorkspace)
        #expect(VisualQASurface(rawValue: "ranking") == .ranking)
        #expect(VisualQASurface(rawValue: "muted-content") == .mutedContent)
        #expect(VisualQASurface(rawValue: "about") == .about)
        #expect(VisualQASurface(rawValue: "settings-window") == .settingsWindow)
        #expect(VisualQASurface(rawValue: "bottom-tabs") == .bottomTabs)
        #expect(VisualQASurface(rawValue: "runtime-readiness") == .runtimeReadiness)
        #expect(VisualQASurface(rawValue: "sharing-templates") == .sharingTemplates)
        #expect(VisualQASurface(rawValue: "ugoira-player") == .ugoiraPlayer)
        #expect(VisualQASurface(rawValue: "downloaded-reader") == .downloadedReader)
        #expect(VisualQASurface(rawValue: "feedback-sheet") == .feedbackSheet)
        #expect(VisualQASurface(rawValue: "artwork-detail-social") == .artworkDetailSocial)
        #expect(VisualQASurface(rawValue: "bookmark-editor") == .bookmarkEditor)
        #expect(VisualQALaunchArgument.discoverDashboard.surface == .discoverDashboard)
        #expect(VisualQALaunchArgument.mangaWatchlist.surface == .mangaWatchlist)
        #expect(VisualQALaunchArgument.pixivIDOpen.surface == .pixivIDOpen)
        #expect(VisualQALaunchArgument.creatorProfile.surface == .creatorProfile)
        #expect(VisualQALaunchArgument.seriesSheet.surface == .seriesSheet)
        #expect(VisualQALaunchArgument.cachedFeed.surface == .cachedFeed)
        #expect(VisualQALaunchArgument.ranking.surface == .ranking)
        #expect(VisualQALaunchArgument.mutedContent.surface == .mutedContent)
        #expect(VisualQALaunchArgument.about.surface == .about)
        #expect(VisualQALaunchArgument.settingsWindow.surface == .settingsWindow)
        #expect(VisualQALaunchArgument.bottomTabs.surface == .bottomTabs)
        #expect(VisualQALaunchArgument.runtimeReadiness.surface == .runtimeReadiness)
        #expect(VisualQALaunchArgument.sharingTemplates.surface == .sharingTemplates)
        #expect(VisualQALaunchArgument.ugoiraPlayer.surface == .ugoiraPlayer)
        #expect(VisualQALaunchArgument.downloadedReader.surface == .downloadedReader)
        #expect(VisualQALaunchArgument.feedbackSheet.surface == .feedbackSheet)
        #expect(VisualQALaunchArgument.artworkDetailSocial.surface == .artworkDetailSocial)
        #expect(VisualQALaunchArgument.bookmarkEditor.surface == .bookmarkEditor)
        #expect(VisualQALaunchArgument.searchWorkspace.surface == .searchWorkspace)
        #expect(VisualQALaunchArgument.novelFeed.surface == .novelFeed)
        #expect(VisualQALaunchArgument.galleryAuto.galleryLayoutMode == .autoMasonry)
        #expect(VisualQALaunchArgument.galleryTwoColumn.galleryLayoutMode == .twoColumnMasonry)
        #expect(VisualQALaunchArgument.galleryThreeColumn.galleryLayoutMode == .threeColumnMasonry)
        #expect(VisualQALaunchArgument.galleryCompact.galleryLayoutMode == .compactGrid)
        #expect(VisualQALaunchArgument.isActive(in: ["KeiPix", "--visual-qa-cached-feed"]))
        #expect(VisualQALaunchArgument.isActive(in: ["KeiPix", "--visual-qa-pixiv-id-open"]))
        #expect(VisualQALaunchArgument.isActive(in: ["KeiPix", "--visual-qa-ranking"]))
        #expect(VisualQALaunchArgument.isActive(in: ["KeiPix", "--visual-qa-feedback-sheet"]))
        #expect(VisualQALaunchArgument.isActive(in: ["KeiPix", "--visual-qa-artwork-detail-social"]))
        #expect(VisualQALaunchArgument.isActive(in: ["KeiPix", "--visual-qa-bookmark-editor"]))
        #expect(VisualQALaunchArgument.isActive(in: ["KeiPix", "--visual-qa-discover-dashboard"]))
        #expect(VisualQALaunchArgument.isActive(in: ["KeiPix", "--visual-qa-creator-profile"]))
        #expect(VisualQALaunchArgument.isActive(in: ["KeiPix", "--visual-qa-runtime-readiness"]))
        #expect(VisualQALaunchArgument.isActive(in: ["KeiPix", "--visual-qa-bottom-tabs"]))
        #expect(VisualQALaunchArgument.isActive(in: ["KeiPix", "--visual-qa-sharing-templates"]))
        #expect(VisualQALaunchArgument.isActive(in: ["KeiPix", "--visual-qa-search-workspace"]))
        #expect(VisualQALaunchArgument.isActive(in: ["KeiPix", "--visual-qa-novel-feed"]))
        #expect(VisualQALaunchArgument.isActive(in: ["KeiPix"]) == false)
        #expect(VisualQALaunchArgument.activeGalleryLayoutMode(in: ["KeiPix", "--visual-qa-gallery-three-column"]) == .threeColumnMasonry)
    }

    @Test("Evidence index scans multiple candidate roots")
    func multiRootScanning() throws {
        let base = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let rootA = base.appending(path: "a/artifacts/visual-qa", directoryHint: .isDirectory)
        let rootB = base.appending(path: "b/artifacts/visual-qa", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: rootA, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: rootB, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: base) }

        try """
        # KeiPix Visual QA

        - Captured at: 20260525T091127Z
        - Surface: gallery-feed
        - Screenshot: gallery-feed.png
        """.write(to: rootA.appending(path: "gallery-feed.md"), atomically: true, encoding: .utf8)

        try """
        # KeiPix Visual QA

        - Captured at: 20260525T091536Z
        - Surface: pixivision
        - Screenshot: pixivision.png
        """.write(to: rootB.appending(path: "pixivision.md"), atomically: true, encoding: .utf8)

        let index = VisualQAEvidenceIndex(rootURLs: [rootA, rootB])

        #expect(index.covers([.galleryFeed, .pixivision]))
        #expect(index.latestManifest(for: .pixivision)?.capturedAt == "20260525T091536Z")
    }
}
