import Foundation
import Testing
@testable import KeiPix

@Suite("Snapshot tests for key data structures")
struct SnapshotTests {

    // MARK: - Navigation History

    @Test("Navigation history maintains correct state after multiple operations")
    func navigationHistoryState() {
        var history = NavigationHistory(maxEntries: 5)
        history.push(1)
        history.push(2)
        history.push(3)
        #expect(history.entries == [.artwork(1), .artwork(2), .artwork(3)])
        #expect(history.cursor == 2)

        _ = history.goBack()
        #expect(history.cursor == 1)
        _ = history.goBack()
        #expect(history.cursor == 0)
        #expect(history.canGoBack == false)

        _ = history.goForward()
        #expect(history.cursor == 1)
    }

    // MARK: - Gallery selection

    @Test("Gallery selection maintains state")
    func gallerySelection() {
        var selection = GalleryArtworkSelection()
        selection.toggle(1)
        selection.toggle(2)
        #expect(selection.contains(1))
        #expect(selection.contains(2))
        #expect(selection.count == 2)

        selection.toggle(1)
        #expect(selection.contains(1) == false)
        #expect(selection.count == 1)
    }

    // MARK: - Semantic version

    @Test("Semantic version parses correctly")
    func semanticVersion() {
        let version = SemanticVersion("1.2.3")
        #expect(version?.major == 1)
        #expect(version?.minor == 2)
        #expect(version?.patch == 3)
    }

    @Test("Semantic version comparison")
    func semanticVersionComparison() {
        let v1 = SemanticVersion("1.0.0")
        let v2 = SemanticVersion("2.0.0")
        #expect(v1! < v2!)
    }
}
