import Foundation
import Testing
@testable import KeiPix

@Suite("Download naming template tokens")
struct DownloadNamingTemplateTests {
    /// Pixez parity: serialized manga should land under per-series
    /// folders. The dedicated `${series}` token gives users a single
    /// placeholder they can drop into their template instead of having
    /// to fall back to `${tag1}` and hoping the series tag wins.
    @Test("${series} token expands to the series title for serialized works")
    func seriesTokenExpandsToTitle() {
        let template = DownloadNamingTemplate(rawValue: "${user}/${series}/${id}_p${page1}.${ext}")
        let context = makeContext(seriesTitle: "Morning Series", seriesID: 9001)

        let rendered = template.render(context: context)

        #expect(rendered.components.count >= 3)
        // The folder hierarchy reads user → series → file, so the
        // second-to-last component must be the series title.
        let parent = rendered.parentComponents
        #expect(parent.contains("Morning Series"))
        #expect(rendered.components.last == "12345678_p1.jpg")
    }

    @Test("${series} token collapses to empty when the artwork is standalone")
    func seriesTokenAbsentForStandaloneArtwork() {
        let template = DownloadNamingTemplate(rawValue: "${user}/${series}/${id}.${ext}")
        let context = makeContext(seriesTitle: nil, seriesID: nil)

        let rendered = template.render(context: context)

        // With ${series} expanding to "" the sanitized component
        // collapses, so the rendered path stays user → file. This
        // matches Pixez behaviour: standalone works don't get a stray
        // empty folder layer.
        #expect(rendered.components.allSatisfy { $0.isEmpty == false })
        #expect(rendered.components.contains("Morning Series") == false)
    }

    @Test("${seriesId} expands to the numeric series ID when present")
    func seriesIdToken() {
        let template = DownloadNamingTemplate(rawValue: "series-${seriesId}/${id}.${ext}")
        let context = makeContext(seriesTitle: "Morning Series", seriesID: 9001)

        let rendered = template.render(context: context)

        #expect(rendered.relativePath.contains("series-9001"))
    }

    @Test("Template preview includes a series folder for the canonical sample")
    func previewSurfacesSeriesFolder() {
        let template = DownloadNamingTemplate(rawValue: "${series}/${id}_p${page1}.${ext}")
        let preview = template.previewPath()
        #expect(preview.contains("Morning Series"))
    }

    private func makeContext(
        seriesTitle: String?,
        seriesID: Int?
    ) -> DownloadNamingTemplate.Context {
        let item = ArtworkDownloadItem(
            id: UUID(),
            artworkID: 12345678,
            title: "Blue Morning",
            creatorName: "kei",
            creatorID: 424242,
            seriesTitle: seriesTitle,
            seriesID: seriesID,
            tags: ["landscape", "original"],
            isAI: false,
            isR18: false,
            isR18G: false,
            artifactKind: .imagePages,
            ugoiraFrameCount: nil,
            ugoiraFrames: nil,
            pageCount: 3,
            completedPages: 0,
            status: .queued,
            folderPath: nil,
            sourceImageURLs: nil,
            sourcePageIndexes: nil,
            sourceTotalPageCount: nil,
            queuedAfter: nil,
            downloadedFilePaths: nil,
            errorMessage: nil,
            createdAt: Date(timeIntervalSince1970: 0),
            updatedAt: Date(timeIntervalSince1970: 0)
        )
        return DownloadNamingTemplate.Context(
            item: item,
            pageIndex: 0,
            totalPages: 3,
            sourceURL: URL(string: "https://example.com/sample.jpg")!
        )
    }
}
