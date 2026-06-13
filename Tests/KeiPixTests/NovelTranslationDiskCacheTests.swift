import Foundation
import Testing
@testable import KeiPix

@Suite("Novel translation disk cache")
struct NovelTranslationDiskCacheTests {
    @Test("Disk cache stores and restores completed segment translations")
    func storesAndRestoresCompletedSegments() throws {
        let cache = try makeCache()
        defer { try? cache.clear() }
        let segments = NovelTranslationPlanner.segments(
            novelID: 42,
            targetLanguageID: "en",
            pages: [[.text("一段落目。\n\n二段落目。")]]
        )
        let result = NovelTranslationBatchResult(
            segment: segments[0],
            translatedText: "First paragraph."
        )

        try cache.store(result)

        #expect(cache.results(for: segments) == [result])
    }

    @Test("Disk cache invalidates when source text changes")
    func invalidatesWhenSourceTextChanges() throws {
        let cache = try makeCache()
        defer { try? cache.clear() }
        let old = NovelTranslationPlanner.segments(
            novelID: 42,
            targetLanguageID: "en",
            pages: [[.text("古い本文。")]]
        )
        let new = NovelTranslationPlanner.segments(
            novelID: 42,
            targetLanguageID: "en",
            pages: [[.text("新しい本文。")]]
        )

        try cache.store(
            NovelTranslationBatchResult(
                segment: old[0],
                translatedText: "Old text."
            )
        )

        #expect(cache.results(for: new).isEmpty)
    }

    @Test("Disk cache clear removes stored translations")
    func clearRemovesStoredTranslations() throws {
        let cache = try makeCache()
        defer { try? cache.clear() }
        let segments = NovelTranslationPlanner.segments(
            novelID: 42,
            targetLanguageID: "en",
            pages: [[.text("本文。")]]
        )

        try cache.store(
            NovelTranslationBatchResult(
                segment: segments[0],
                translatedText: "Text."
            )
        )
        try cache.clear()

        #expect(cache.results(for: segments).isEmpty)
    }

    private func makeCache() throws -> NovelTranslationDiskCache {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("KeiPixNovelTranslationDiskCacheTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return NovelTranslationDiskCache(directoryURL: directory)
    }
}
