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
        #expect(index.covers([.settingsWindow]))
        #expect(index.summary(for: [.galleryFeed]).contains("1/1"))
        #expect(VisualQASurface(rawValue: "batch-bookmark-preview") == .batchBookmarkPreview)
        #expect(VisualQASurface(rawValue: "pixiv-link-drop") == .pixivLinkDrop)
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
