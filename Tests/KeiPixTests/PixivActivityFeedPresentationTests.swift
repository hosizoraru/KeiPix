import Testing
@testable import KeiPix

struct PixivActivityFeedPresentationTests {
    @Test("Activity header status stays empty until activity items load")
    func emptyActivityFeedDoesNotRepeatRouteTitle() {
        #expect(PixivActivityFeedPresentation.statusText(itemCount: 0).isEmpty)
    }

    @Test("Activity header status reports loaded item count")
    func loadedActivityFeedShowsItemCount() {
        #expect(PixivActivityFeedPresentation.statusText(itemCount: 24) == "Loaded 24 activity items")
    }
}
