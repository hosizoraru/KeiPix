import Foundation
import CoreGraphics
import SwiftUI
import Testing
@testable import KeiPix

struct CreatorCollectionTests {
    @Test("Native creator preview layout keeps compact cards dense")
    func nativeCreatorPreviewLayoutKeepsCompactCardsDense() {
        let metrics = NativeCollectionLayoutMetrics.informationCards
        let layout = NativeCreatorPreviewCollectionLayout(mode: .auto)
        let containerWidth: CGFloat = 393
        let size = layout.itemSize(
            for: .preview(Self.preview(id: 42)),
            containerWidth: containerWidth
        )

        #expect(layout.interitemSpacing == metrics.itemSpacing)
        #expect(layout.lineSpacing == metrics.itemSpacing)
        Self.expect(layout.sectionInsets, matches: metrics.insets)
        #expect(size.width >= 340)
        #expect(size.height < size.width * 0.74)
    }

    @Test("Native card grids use shared collection spacing metrics")
    func nativeCardGridsUseSharedCollectionSpacingMetrics() {
        let informationMetrics = NativeCollectionLayoutMetrics.informationCards
        let artworkMetrics = NativeCollectionLayoutMetrics.artworkCards
        let tagMetrics = NativeCollectionLayoutMetrics.tagChips
        let compactDownloadMetrics = NativeCollectionLayoutMetrics.compactDownloadCards
        let adaptiveLayout = NativeAdaptiveGridCollectionLayout(
            minimumItemWidth: 160,
            maximumItemWidth: 260,
            itemHeight: 180
        )
        let creatorLayout = NativeCreatorPreviewCollectionLayout(mode: .auto)
        let bookmarkLayout = NativeBookmarkTagCollectionLayout()
        let galleryLayout = NativeGalleryCollectionLayout.compactGrid(cardHeight: 220, loadMoreHeight: 80)
        let browsingHistoryLayout = NativeBrowsingHistoryCollectionLayout.localCards
        let compactDownloadLayout = DownloadQueueMasonryPresentation.metrics(
            for: 393,
            layoutKind: .compactPhone
        )

        #expect(adaptiveLayout.spacing == informationMetrics.itemSpacing)
        Self.expect(adaptiveLayout.sectionInsets, matches: informationMetrics.insets)
        #expect(creatorLayout.lineSpacing == informationMetrics.itemSpacing)
        Self.expect(creatorLayout.sectionInsets, matches: informationMetrics.insets)

        #expect(bookmarkLayout.spacing == tagMetrics.itemSpacing)
        Self.expect(bookmarkLayout.sectionInsets, matches: tagMetrics.insets)

        #expect(galleryLayout.interitemSpacing == artworkMetrics.itemSpacing)
        Self.expect(galleryLayout.sectionInsets, matches: artworkMetrics.insets)
        #expect(browsingHistoryLayout.interitemSpacing == artworkMetrics.itemSpacing)
        Self.expect(browsingHistoryLayout.sectionInsets, matches: artworkMetrics.insets)

        #expect(compactDownloadLayout.spacing == compactDownloadMetrics.itemSpacing)
        Self.expect(compactDownloadLayout, matches: compactDownloadMetrics.insets)
    }

    @Test("Compact creator preview metrics keep sparse thumbnails in fixed slots")
    func compactCreatorPreviewMetricsKeepSparseThumbnailsInFixedSlots() {
        let contentWidth: CGFloat = 240

        #expect(NativeCollectionLayoutMetrics.compactCreatorPreviewSlotCount == 3)
        #expect(abs(NativeCollectionLayoutMetrics.compactCreatorPreviewAspect - 2.4) < 0.0001)
        #expect(
            abs(
                NativeCollectionLayoutMetrics.compactCreatorPreviewHeight(forContentWidth: contentWidth)
                    - contentWidth / NativeCollectionLayoutMetrics.compactCreatorPreviewAspect
            ) < 0.0001
        )
    }

    @Test("Pinned creator library keeps newest pins first")
    func pinnedCreatorLibraryKeepsNewestPinsFirst() {
        var library = PinnedCreatorLibrary()
        library.pin(Self.user(id: 1, name: "Alice"), addedAt: Date(timeIntervalSince1970: 10))
        library.pin(Self.user(id: 2, name: "Bob"), addedAt: Date(timeIntervalSince1970: 20))

        #expect(library.sortedCreators.map(\.id) == [2, 1])
        #expect(library.contains(userID: 1))
    }

    @Test("Pinned creator library updates existing creator metadata")
    func pinnedCreatorLibraryUpdatesExistingCreatorMetadata() {
        var library = PinnedCreatorLibrary()
        library.pin(Self.user(id: 1, name: "Alice"), addedAt: Date(timeIntervalSince1970: 10))
        library.pin(Self.user(id: 1, name: "Alice Prime", account: "alice_prime"), addedAt: Date(timeIntervalSince1970: 20))

        #expect(library.creators.count == 1)
        #expect(library.sortedCreators.first?.name == "Alice Prime")
        #expect(library.sortedCreators.first?.account == "alice_prime")
    }

    @Test("Pinned creator library removes creators by id")
    func pinnedCreatorLibraryRemovesCreatorsByID() {
        var library = PinnedCreatorLibrary()
        library.pin(Self.user(id: 1, name: "Alice"))
        let firstRemoval = library.unpin(userID: 1)
        let secondRemoval = library.unpin(userID: 1)

        #expect(firstRemoval)
        #expect(library.contains(userID: 1) == false)
        #expect(secondRemoval == false)
    }

    @Test("Creator list selection tracks selected creators and prunes hidden ids")
    func creatorListSelectionTracksSelectedCreatorsAndPrunesHiddenIDs() {
        var selection = CreatorListSelection()

        selection.toggle(1)
        #expect(selection.contains(1))
        #expect(selection.count == 1)

        selection.selectAll([2, 3])
        selection.isSelectionMode = true
        #expect(selection.selectedIDs == [1, 2, 3])

        selection.prune(visibleCreatorIDs: [2, 3, 4])
        #expect(selection.selectedIDs == [2, 3])
        #expect(selection.isSelectionMode)

        selection.prune(visibleCreatorIDs: [4])
        #expect(selection.selectedIDs.isEmpty)
        #expect(selection.isSelectionMode == false)
    }

    @Test("Visual QA creator profile includes related creators and recent works")
    func visualQACreatorProfileFixture() {
        let detail = VisualQASampleData.creatorProfileDetail

        #expect(detail.user.id == 5001)
        #expect(detail.profile.totalIllusts > 0)
        #expect(VisualQASampleData.creatorProfileRecentWorks.isEmpty == false)
        #expect(VisualQASampleData.creatorProfileRelatedUsers.count >= 2)
    }

    private static func preview(id: Int) -> PixivUserPreview {
        PixivUserPreview(user: user(id: id, name: "Alice"), illusts: [], isMuted: false)
    }

    private static func expect(_ edgeInsets: EdgeInsets, matches insets: NativeCollectionLayoutInsets) {
        #expect(edgeInsets.top == insets.top)
        #expect(edgeInsets.leading == insets.leading)
        #expect(edgeInsets.bottom == insets.bottom)
        #expect(edgeInsets.trailing == insets.trailing)
    }

    private static func expect(
        _ metrics: DownloadQueueMasonryMetrics,
        matches insets: NativeCollectionLayoutInsets
    ) {
        #expect(metrics.topInset == insets.top)
        #expect(metrics.leadingInset == insets.leading)
        #expect(metrics.bottomInset == insets.bottom)
        #expect(metrics.trailingInset == insets.trailing)
    }

    private static func user(id: Int, name: String, account: String? = nil) -> PixivUser {
        PixivUser(
            id: id,
            name: name,
            account: account ?? name.lowercased(),
            avatarURL: URL(string: "https://i.pximg.net/user-profile/img/\(id).jpg"),
            isFollowed: false
        )
    }
}
