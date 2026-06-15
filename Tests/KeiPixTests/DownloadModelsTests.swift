import CoreGraphics
import Foundation
import Testing
@testable import KeiPix

@Suite("Download models")
struct DownloadModelsTests {
    @Test("Source page labels describe contiguous and sparse page ranges")
    func sourcePageLabels() {
        var contiguous = downloadItem(sourcePageIndexes: [1, 2, 3])
        #expect(contiguous.sourcePageLabel?.contains("2-4") == true)

        contiguous.sourcePageIndexes = [0, 2, 4]
        #expect(contiguous.sourcePageLabel?.contains("1, 3, 5") == true)
    }

    @Test("Retry backoff staggers failed download recovery")
    func retryBackoff() {
        #expect(DownloadRetryBackoff.delay(forRetryIndex: 0) == 0)
        #expect(DownloadRetryBackoff.delay(forRetryIndex: 1) == 2)
        #expect(DownloadRetryBackoff.delay(forRetryIndex: 30) == 60)
        #expect(DownloadRetryBackoff.delay(forRetryIndex: 999) == 60)
    }

    @MainActor
    @Test("Download destination exposes the current platform's user-facing target")
    func downloadDestinationSummary() {
        let store = ArtworkDownloadStore(completionNotifier: DownloadCompletionNotifier(
            center: FakeUserNotificationCenter(isAuthorized: false),
            authorizationStore: InMemoryAuthorizationCacheStore(hasRequested: true),
            coalesceWindowSeconds: 0.05
        ))

        #if os(macOS)
        #expect(store.downloadDestination.kind == .customFolder)
        #expect(store.downloadDestination.allowsCustomFolderSelection)
        #expect(store.downloadDestination.detail == store.downloadDirectoryPath)
        #else
        #expect(store.downloadDestination.kind == .photosLibrary)
        #expect(store.downloadDestination.allowsCustomFolderSelection == false)
        #expect(store.downloadDestination.detail != store.downloadDirectoryPath)
        #endif
    }

    @MainActor
    @Test("Download history snapshot exposes completed and failed queue history")
    func downloadHistorySnapshot() {
        let store = ArtworkDownloadStore(completionNotifier: DownloadCompletionNotifier(
            center: FakeUserNotificationCenter(isAuthorized: false),
            authorizationStore: InMemoryAuthorizationCacheStore(hasRequested: true),
            coalesceWindowSeconds: 0.05
        ))
        let oldCompleted = downloadItem(
            title: "Old complete",
            status: .completed,
            updatedAt: Date(timeIntervalSince1970: 100)
        )
        let newCompleted = downloadItem(
            title: "Fresh complete",
            status: .completed,
            updatedAt: Date(timeIntervalSince1970: 300)
        )
        let failed = downloadItem(
            title: "Needs retry",
            status: .failed,
            updatedAt: Date(timeIntervalSince1970: 200)
        )
        let queued = downloadItem(
            title: "Queued",
            status: .queued,
            updatedAt: Date(timeIntervalSince1970: 400)
        )
        store.items = [oldCompleted, failed, newCompleted, queued]

        let snapshot = store.historySnapshot

        #expect(snapshot.hasHistory)
        #expect(snapshot.activeCount == 1)
        #expect(snapshot.completedCount == 2)
        #expect(snapshot.failedCount == 1)
        #expect(snapshot.latestCompletedTitle == "Fresh complete")
        #expect(snapshot.latestCompletedAt == Date(timeIntervalSince1970: 300))
    }

    @MainActor
    @Test("Downloaded reader visual QA fixture writes readable local pages")
    func downloadedReaderVisualQAFixture() {
        let item = VisualQASampleData.downloadedReaderItem()

        #expect(item.status == .completed)
        #expect(item.resolvedArtifactKind == .imagePages)
        #expect(item.pageCount == 4)
        #expect(item.completedPages == 4)
        #expect(item.downloadedFilePaths?.count == 4)
        #expect(item.downloadedFilePaths?.allSatisfy { FileManager.default.fileExists(atPath: $0) } == true)
    }

    @MainActor
    @Test("Downloaded queue visual QA fixture covers history states")
    func downloadedQueueVisualQAFixtureCoversHistoryStates() {
        let store = ArtworkDownloadStore(completionNotifier: DownloadCompletionNotifier(
            center: FakeUserNotificationCenter(isAuthorized: false),
            authorizationStore: InMemoryAuthorizationCacheStore(hasRequested: true),
            coalesceWindowSeconds: 0.05
        ))
        store.items = VisualQASampleData.downloadedQueueItems()

        let snapshot = store.historySnapshot

        #expect(snapshot.hasHistory)
        #expect(snapshot.activeCount == 1)
        #expect(snapshot.completedCount == 1)
        #expect(snapshot.failedCount == 1)
        #expect(snapshot.latestCompletedTitle == "Downloaded reader QA manga")
    }

    @Test("Download masonry metrics keep phone dense and widen on larger canvases")
    func downloadMasonryMetrics() {
        let phoneMetrics = DownloadQueueMasonryPresentation.metrics(
            for: 402,
            layoutKind: .compactPhone
        )
        let regularMetrics = DownloadQueueMasonryPresentation.metrics(
            for: 900,
            layoutKind: .regular
        )

        #expect(phoneMetrics.resolvedColumnCount(for: 402) == 2)
        #expect(regularMetrics.resolvedColumnCount(for: 900) >= 3)
        #expect(phoneMetrics.itemWidth(for: 402) < regularMetrics.itemWidth(for: 900))
    }

    @Test("Download masonry cards grow for failed and path-rich items")
    func downloadMasonryCardHeights() {
        let completed = downloadItem(status: .completed)
        let failed = downloadItem(
            status: .failed,
            errorMessage: "Network QA retry sample needs a visible reason"
        )
        let savedWithPath = downloadItem(status: .completed, folderPath: "/tmp/KeiPix/Downloads/Sample")
        let width: CGFloat = 184

        let completedHeight = DownloadQueueMasonryPresentation.cardHeight(
            for: completed,
            width: width,
            layoutKind: .compactPhone
        )
        let failedHeight = DownloadQueueMasonryPresentation.cardHeight(
            for: failed,
            width: width,
            layoutKind: .compactPhone
        )
        let pathHeight = DownloadQueueMasonryPresentation.cardHeight(
            for: savedWithPath,
            width: width,
            layoutKind: .compactPhone
        )

        #expect(failedHeight > completedHeight)
        #expect(pathHeight > completedHeight)
    }

    @Test("Download masonry placement balances items across columns")
    func downloadMasonryPlacement() {
        let metrics = DownloadQueueMasonryPresentation.metrics(for: 402, layoutKind: .compactPhone)
        let resolved = DownloadQueueMasonryPlacement.resolve(
            heights: [160, 180, 150],
            containerWidth: 402,
            metrics: metrics
        )

        #expect(resolved.frames.count == 3)
        #expect(resolved.frames[0].minX == metrics.leadingInset)
        #expect(resolved.frames[1].minX > resolved.frames[0].minX)
        #expect(resolved.frames[2].minY > resolved.frames[0].minY)
        #expect(resolved.size.height > resolved.frames[1].maxY)
    }

    private func downloadItem(
        title: String = "Range test",
        status: ArtworkDownloadStatus = .queued,
        sourcePageIndexes: [Int] = [0],
        updatedAt: Date = Date(timeIntervalSince1970: 0),
        folderPath: String? = nil,
        errorMessage: String? = nil
    ) -> ArtworkDownloadItem {
        ArtworkDownloadItem(
            id: UUID(),
            artworkID: 42,
            title: title,
            creatorName: "Creator",
            artifactKind: .imagePages,
            pageCount: sourcePageIndexes.count,
            completedPages: status == .completed ? sourcePageIndexes.count : 0,
            status: status,
            folderPath: folderPath,
            sourceImageURLs: [],
            sourcePageIndexes: sourcePageIndexes,
            sourceTotalPageCount: 10,
            downloadedFilePaths: nil,
            errorMessage: errorMessage,
            createdAt: Date(timeIntervalSince1970: 0),
            updatedAt: updatedAt
        )
    }
}
