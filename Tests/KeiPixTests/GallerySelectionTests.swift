import Testing
@testable import KeiPix

struct GallerySelectionTests {
    @Test("Selection toggles, prunes, and clears visible artwork ids")
    func selectionLifecycle() {
        var selection = GalleryArtworkSelection()

        selection.toggle(10)
        selection.toggle(12)
        #expect(selection.selectedIDs == [10, 12])

        selection.toggle(10)
        #expect(selection.selectedIDs == [12])

        selection.selectAll([12, 13, 14])
        #expect(selection.selectedIDs == [12, 13, 14])

        selection.isSelectionMode = true
        selection.prune(visibleArtworkIDs: [13, 20])
        #expect(selection.selectedIDs == [13])
        #expect(selection.isSelectionMode)

        selection.prune(visibleArtworkIDs: [20])
        #expect(selection.selectedIDs.isEmpty)
        #expect(selection.isSelectionMode == false)

        selection.selectAll([1, 2])
        selection.isSelectionMode = true
        selection.clear()
        #expect(selection.selectedIDs.isEmpty)
        #expect(selection.isSelectionMode == false)
    }
}
