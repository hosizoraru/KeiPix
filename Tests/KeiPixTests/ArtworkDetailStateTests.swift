import Foundation
import Testing
@testable import KeiPix

struct ArtworkDetailStateTests {
    @Test("Artwork detail expansion state is scoped by artwork id")
    func detailExpansionStateIsScopedByArtworkID() {
        var library = ArtworkDetailStateLibrary()
        let expanded = ArtworkDetailExpansionState(
            isCaptionExpanded: true,
            isSeriesExpanded: true,
            isCommentsExpanded: false,
            isRelatedExpanded: true,
            isTagsExpanded: false,
            isMetadataExpanded: true
        )

        library.setExpansionState(expanded, for: 10, now: Date(timeIntervalSince1970: 10))

        #expect(library.expansionState(for: 10) == expanded)
        #expect(library.expansionState(for: 11) == .designDefault)
    }

    @Test("Artwork detail state library keeps recent entries bounded")
    func detailStateLibraryKeepsRecentEntriesBounded() {
        var library = ArtworkDetailStateLibrary()

        for id in 1...4 {
            var state = ArtworkDetailExpansionState.designDefault
            state.isTagsExpanded = id.isMultiple(of: 2)
            library.setExpansionState(state, for: id, now: Date(timeIntervalSince1970: TimeInterval(id)), limit: 3)
        }

        #expect(library.entries.map(\.artworkID) == [4, 3, 2])
        #expect(library.expansionState(for: 1) == .designDefault)
    }
}
