import Foundation
import Testing
@testable import KeiPix

/// Pin the wire shape and the schema-version gate. The merge
/// semantics live on `KeiPixStore` (which is `@MainActor` and
/// can't be cleanly spun up in this test target — the other
/// store-driven tests follow the same constraint), so we cover
/// the archive itself: round-trip stability, partial-archive
/// tolerance, and the schema version refusal that protects an
/// older build from a newer file.
@Suite("KeiPix backup archive")
struct KeiPixBackupArchiveTests {

    @Test("Round-trip preserves every field through JSON encoding")
    func roundTripPreservesFields() throws {
        let archive = KeiPixBackupArchive(
            schemaVersion: 1,
            exportedAt: Date(timeIntervalSince1970: 1_700_000_000),
            appVersion: "1.2.3",
            savedSearches: SavedSearchLibraryExport(
                schemaVersion: 1,
                exportedAt: Date(timeIntervalSince1970: 1_700_000_000),
                presets: [],
                savedSearches: ["original"],
                searchHistory: ["landscape"]
            ),
            localBrowsingHistory: [],
            pinnedCreators: PinnedCreatorLibrary(),
            pinnedBookmarkTags: ["favorite"],
            readerProgress: ArtworkReaderProgressLibrary(),
            downloadedReaderProgress: DownloadedArtworkReaderProgressLibrary(),
            mangaWatchlistReadState: MangaWatchlistReadStateLibrary(),
            artworkDetailState: ArtworkDetailStateLibrary(),
            mutedContent: MutedContentArchive(
                exportedAt: Date(timeIntervalSince1970: 1_700_000_000),
                tags: ["spoilers"],
                users: [],
                artworks: [],
                commentPhrases: []
            ),
            preferences: KeiPixBackupArchive.PreferenceSnapshot(
                defaultBookmarkRestrict: "public",
                hideAIArtworks: true
            )
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(archive)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(KeiPixBackupArchive.self, from: data)

        #expect(decoded == archive)
    }

    @Test("Future schema version decodes but is flagged as unsupported")
    func futureSchemaVersionDecodes() throws {
        // We deliberately don't fail decoding for forward versions
        // — the file is still valid JSON, and the store-side guard
        // raises `KeiPixBackupError.unsupportedSchemaVersion` so the
        // UI can show a useful "update KeiPix" message instead of a
        // generic decoding failure.
        let archive = KeiPixBackupArchive(
            schemaVersion: KeiPixBackupArchive.currentSchemaVersion + 5,
            exportedAt: Date()
        )
        let data = try JSONEncoder().encode(archive)
        let decoded = try JSONDecoder().decode(KeiPixBackupArchive.self, from: data)
        #expect(decoded.schemaVersion > KeiPixBackupArchive.currentSchemaVersion)
    }

    @Test("Partial archives default missing collections so older exports import cleanly")
    func partialArchiveTolerated() throws {
        // Simulate an archive produced by an earlier build that only
        // knows about a subset of the libraries. Decoding has to
        // tolerate the missing keys so users don't get stranded
        // after an upgrade.
        let json = """
        {
            "schemaVersion": 1,
            "exportedAt": "2026-05-27T00:00:00Z",
            "localBrowsingHistory": [],
            "pinnedCreators": { "creators": [] },
            "pinnedBookmarkTags": [],
            "readerProgress": { "items": [] },
            "downloadedReaderProgress": { "items": [] },
            "mangaWatchlistReadState": { "items": [] },
            "artworkDetailState": { "entries": [] },
            "preferences": {}
        }
        """
        let data = Data(json.utf8)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(KeiPixBackupArchive.self, from: data)

        #expect(decoded.savedSearches == nil)
        #expect(decoded.mutedContent == nil)
        #expect(decoded.appVersion == nil)
        #expect(decoded.preferences.hideAIArtworks == nil)
    }

    @Test("Import summary totals every section without double-counting")
    func summaryTotalsSum() {
        let summary = KeiPixBackupImportSummary(
            savedSearchPresetCount: 1,
            savedSearchCount: 2,
            searchHistoryCount: 3,
            browsingHistoryCount: 4,
            pinnedCreatorCount: 5,
            pinnedBookmarkTagCount: 6,
            readerProgressCount: 7,
            downloadedReaderProgressCount: 8,
            mangaWatchlistCount: 9,
            artworkDetailStateCount: 10,
            mutedTotalCount: 11,
            preferenceFieldCount: 12
        )
        #expect(summary.totalCount == 78)
    }

    @Test("Schema mismatch produces a localized error message")
    func unsupportedSchemaErrorMessage() {
        let error = KeiPixBackupError.unsupportedSchemaVersion(found: 9, supported: 1)
        // Just asserting the version numbers land in the formatted
        // string — the actual phrasing is owned by the L10n layer.
        let message = error.localizedMessage
        #expect(message.contains("9"))
        #expect(message.contains("1"))
    }

    @Test("Decoding-failed error message includes the underlying detail")
    func decodingFailedErrorMessage() {
        let error = KeiPixBackupError.decodingFailed(message: "boom")
        #expect(error.localizedMessage.contains("boom"))
    }
}
