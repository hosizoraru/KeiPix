import Foundation
import Testing
@testable import KeiPix

@Suite("Cache category snapshot")
struct CacheCategorySnapshotTests {

    @Test("Display label prefers byte size when measurable")
    func bytesWinOverItemCount() {
        let snapshot = CacheCategorySnapshot(
            id: .image,
            title: "Image cache",
            detail: "—",
            byteSize: 4_194_304, // 4 MiB
            itemCount: 7,
            isEmpty: false
        )
        // Don't pin the exact byte string — the formatter is locale-
        // sensitive — but assert it's a byte-shaped readout, not the
        // item-count fallback.
        #expect(snapshot.displayLabel.contains("MB") || snapshot.displayLabel.contains("KB"))
        #expect(snapshot.displayLabel.contains("7 items") == false)
    }

    @Test("Display label falls back to item count when byte size is unmeasurable")
    func itemsWhenBytesNil() {
        let snapshot = CacheCategorySnapshot(
            id: .searchHistory,
            title: "Search history",
            detail: "—",
            byteSize: nil,
            itemCount: 12,
            isEmpty: false
        )
        // Format string is "%d items" in the source language; we
        // assert the count is in the rendered label rather than
        // pinning the exact wording so a future translation pass
        // doesn't break the test.
        #expect(snapshot.displayLabel.contains("12"))
    }

    @Test("Display label collapses to empty-state copy when nothing is stored")
    func emptyStateLabel() {
        let snapshot = CacheCategorySnapshot(
            id: .feedSnapshots,
            title: "Offline feed snapshots",
            detail: "—",
            byteSize: 0,
            itemCount: 0,
            isEmpty: true
        )
        // The empty-state string is L10n-driven, so just assert it's
        // non-empty and not the byte/item readout shape we'd see in
        // the populated cases.
        #expect(snapshot.displayLabel.isEmpty == false)
        #expect(snapshot.displayLabel.contains("0 items") == false)
    }

    @Test("CacheCategoryKind.allCases covers the six regenerable surfaces the page renders")
    func allCasesShape() {
        // The settings page builds rows from `allCases`, so a
        // missing case would silently drop a row. Pin the canonical
        // six so a reordering or renaming shows up here first.
        #expect(CacheCategoryKind.allCases == [
            .image, .feedSnapshots, .browsingHistory, .searchHistory, .artworkDetailState, .novelText
        ])
    }
}
