import Testing
@testable import KeiPix

@Suite("Novel translation scheduler")
struct NovelTranslationSchedulerTests {
    @Test("Single page scheduling translates the active page before nearby prefetch")
    func singlePageSchedulingPrioritizesActivePage() {
        let order = NovelTranslationScheduler.pageOrder(
            pageCount: 7,
            activePageIndex: 3,
            mode: .singlePage
        )

        #expect(order == [3, 2, 4, 1, 5, 0, 6])
    }

    @Test("Double page scheduling translates the visible pair before distant pages")
    func doublePageSchedulingPrioritizesVisiblePair() {
        let order = NovelTranslationScheduler.pageOrder(
            pageCount: 8,
            activePageIndex: 3,
            mode: .doublePage
        )

        #expect(order == [3, 4, 2, 5, 1, 6, 0, 7])
    }

    @Test("Continuous scheduling keeps a simple page order approximation")
    func continuousSchedulingUsesPageOrder() {
        let order = NovelTranslationScheduler.pageOrder(
            pageCount: 5,
            activePageIndex: 3,
            mode: .continuous
        )

        #expect(order == [0, 1, 2, 3, 4])
    }

    @Test("Continuous scheduling prioritizes reported visible pages before distant prefetch")
    func continuousSchedulingPrioritizesVisiblePageRange() {
        let order = NovelTranslationScheduler.pageOrder(
            pageCount: 7,
            activePageIndex: 0,
            mode: .continuous,
            continuousVisiblePageRange: NovelContinuousVisiblePageRange(firstPageIndex: 3, lastPageIndex: 4)
        )

        #expect(order == [3, 4, 2, 5, 1, 6, 0])
    }

    @Test("Schedule identity changes when stale translation work should cancel")
    func scheduleIdentityCapturesCancellationInputs() {
        let base = NovelTranslationScheduleIdentity(
            novelID: 1,
            targetLanguageID: "en",
            mode: .singlePage,
            activePageIndex: 2,
            pageCount: 5
        )

        #expect(base != NovelTranslationScheduleIdentity(novelID: 2, targetLanguageID: "en", mode: .singlePage, activePageIndex: 2, pageCount: 5))
        #expect(base != NovelTranslationScheduleIdentity(novelID: 1, targetLanguageID: "ja", mode: .singlePage, activePageIndex: 2, pageCount: 5))
        #expect(base != NovelTranslationScheduleIdentity(novelID: 1, targetLanguageID: "en", mode: .doublePage, activePageIndex: 2, pageCount: 5))
        #expect(base != NovelTranslationScheduleIdentity(novelID: 1, targetLanguageID: "en", mode: .singlePage, activePageIndex: 3, pageCount: 5))
    }
}
