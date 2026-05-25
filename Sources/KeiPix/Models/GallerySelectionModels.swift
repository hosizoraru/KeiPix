import Foundation

struct GalleryArtworkSelection: Hashable, Sendable {
    var selectedIDs: Set<Int> = []
    var isSelectionMode = false

    var count: Int { selectedIDs.count }
    var hasSelection: Bool { selectedIDs.isEmpty == false }

    func contains(_ artworkID: Int) -> Bool {
        selectedIDs.contains(artworkID)
    }

    mutating func toggle(_ artworkID: Int) {
        if selectedIDs.contains(artworkID) {
            selectedIDs.remove(artworkID)
        } else {
            selectedIDs.insert(artworkID)
        }
    }

    mutating func selectAll(_ artworkIDs: some Sequence<Int>) {
        selectedIDs.formUnion(artworkIDs)
    }

    mutating func clear() {
        selectedIDs.removeAll()
        isSelectionMode = false
    }

    mutating func prune(visibleArtworkIDs: some Sequence<Int>) {
        selectedIDs.formIntersection(Set(visibleArtworkIDs))
        if selectedIDs.isEmpty {
            isSelectionMode = false
        }
    }
}
