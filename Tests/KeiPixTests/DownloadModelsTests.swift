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

    private func downloadItem(sourcePageIndexes: [Int]) -> ArtworkDownloadItem {
        ArtworkDownloadItem(
            id: UUID(),
            artworkID: 42,
            title: "Range test",
            creatorName: "Creator",
            artifactKind: .imagePages,
            pageCount: sourcePageIndexes.count,
            completedPages: 0,
            status: .queued,
            folderPath: nil,
            sourceImageURLs: [],
            sourcePageIndexes: sourcePageIndexes,
            sourceTotalPageCount: 10,
            downloadedFilePaths: nil,
            errorMessage: nil,
            createdAt: Date(timeIntervalSince1970: 0),
            updatedAt: Date(timeIntervalSince1970: 0)
        )
    }
}
