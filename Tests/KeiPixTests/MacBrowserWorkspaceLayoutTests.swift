import CoreGraphics
import Testing
@testable import KeiPix

#if os(macOS)
struct MacBrowserWorkspaceLayoutTests {
    @Test("Artwork detail hides before it can compress the feed")
    func artworkDetailHidesBeforeCompressingFeed() {
        let layout = MacBrowserWorkspaceLayout(
            availableWidth: 980,
            route: .illustrations,
            isDetailRequested: true,
            hasSelection: true
        )

        #expect(layout.supportsDetailPanel)
        #expect(layout.feedMinimumWidth == 640)
        #expect(layout.showsDetailPanel == false)
        #expect(layout.detailWidth == 0)
        #expect(layout.feedWidth == 980)
    }

    @Test("Artwork detail shows on wide macOS workspaces while protecting masonry width")
    func artworkDetailShowsOnWideWorkspace() {
        let layout = MacBrowserWorkspaceLayout(
            availableWidth: 1180,
            route: .illustrations,
            isDetailRequested: true,
            hasSelection: true
        )

        #expect(layout.showsDetailPanel)
        #expect(layout.detailWidth >= layout.detailMinimumWidth)
        #expect(layout.detailWidth <= layout.detailMaximumWidth)
        #expect(layout.feedWidth >= layout.feedMinimumWidth)
    }

    @Test("Creator routes reserve feed width instead of showing an empty third pane")
    func creatorRoutesReserveFeedWidth() {
        let layout = MacBrowserWorkspaceLayout(
            availableWidth: 980,
            route: .recommendedUsers,
            isDetailRequested: true,
            hasSelection: true
        )

        #expect(layout.supportsDetailPanel == false)
        #expect(layout.feedMinimumWidth == 720)
        #expect(layout.showsDetailPanel == false)
        #expect(layout.detailWidth == 0)
    }

    @Test("Spotlight panels are wider but still capped")
    func spotlightPanelIsWiderButCapped() {
        let layout = MacBrowserWorkspaceLayout(
            availableWidth: 1480,
            route: .spotlight,
            isDetailRequested: true,
            hasSelection: true
        )

        #expect(layout.showsDetailPanel)
        #expect(layout.detailWidth == layout.detailMaximumWidth)
        #expect(layout.feedWidth >= layout.feedMinimumWidth)
    }

    @Test("Requested detail stays hidden without a concrete selection")
    func requestedDetailNeedsSelection() {
        let layout = MacBrowserWorkspaceLayout(
            availableWidth: 1480,
            route: .illustrations,
            isDetailRequested: true,
            hasSelection: false
        )

        #expect(layout.supportsDetailPanel)
        #expect(layout.showsDetailPanel == false)
        #expect(layout.detailWidth == 0)
    }
}
#endif
