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

    @Test("previewScenarios renders three documented shapes for the live preview")
    func previewScenariosCoverDocumentedShapes() {
        let template = DownloadNamingTemplate(rawValue: DownloadNamingTemplate.defaultTemplate)
        let scenarios = template.previewScenarios()

        #expect(scenarios.count == 3)
        #expect(scenarios.map(\.id) == [.standalone, .multiPage, .series])
        // Each rendered path must be non-empty so the settings page never
        // shows a row with just the download folder followed by a slash.
        for scenario in scenarios {
            #expect(scenario.renderedPath.isEmpty == false)
        }
        // The multi-page scenario must show a different page index than
        // the standalone scenario so a token swap surfaces visibly.
        let standalone = scenarios.first { $0.id == .standalone }?.renderedPath ?? ""
        let multiPage = scenarios.first { $0.id == .multiPage }?.renderedPath ?? ""
        #expect(standalone != multiPage)
    }

    @Test("unknownPlaceholders flags typos but stays silent for documented tokens")
    func unknownPlaceholdersFlagsTypos() {
        let clean = DownloadNamingTemplate(rawValue: "${user}/${id}_p${page1}.${ext}")
        #expect(clean.unknownPlaceholders.isEmpty)

        let typo = DownloadNamingTemplate(rawValue: "${user}/${ide}_p${page1}.${ext}")
        #expect(typo.unknownPlaceholders == ["ide"])

        // The `tag(name)` form is a documented dynamic placeholder; it
        // should not show up as unknown even though the suffix changes.
        let dynamic = DownloadNamingTemplate(rawValue: "${tag(landscape)}/${id}.${ext}")
        #expect(dynamic.unknownPlaceholders.isEmpty)
    }

    @Test("Documented token catalog stays in sync with template validation")
    func documentedTokenCatalogMatchesValidator() {
        let tokens = DownloadNamingTemplate.documentedTokens

        #expect(tokens.isEmpty == false)
        #expect(tokens.map(\.placeholder).contains("${id}"))
        #expect(tokens.map(\.placeholder).contains("${series}"))
        #expect(tokens.map(\.placeholder).contains("${tag(name)}"))
        #expect(Set(tokens.map(\.group)).isSuperset(of: [.identity, .creator, .series, .page, .flags, .tags]))

        let template = DownloadNamingTemplate(rawValue: tokens.map(\.placeholder).joined(separator: "/"))
        #expect(template.unknownPlaceholders.isEmpty)
    }

    @Test("Token catalog exposes insertable placeholder text")
    func tokenCatalogExposesInsertablePlaceholderText() {
        let token = DownloadNamingTemplate.documentedTokens.first { $0.key == "page1" }

        #expect(token?.placeholder == "${page1}")
        #expect(token?.displayName.isEmpty == false)
        #expect(token?.sampleValue.isEmpty == false)
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
