import Foundation
import Testing
@testable import KeiPix

@Suite("Navigation history")
struct NavigationHistoryTests {
    @Test("Empty history has no back/forward")
    func emptyHistory() {
        let history = NavigationHistory()
        #expect(history.canGoBack == false)
        #expect(history.canGoForward == false)
    }

    @Test("Single entry has no back/forward")
    func singleEntry() {
        var history = NavigationHistory()
        history.push(1)
        #expect(history.canGoBack == false)
        #expect(history.canGoForward == false)
    }

    @Test("Two entries — back from second goes to first")
    func backFromSecond() {
        var history = NavigationHistory()
        history.push(1)
        history.push(2)
        #expect(history.canGoBack == true)
        #expect(history.canGoForward == false)

        let id = history.goBack()
        #expect(id == 1)
        #expect(history.canGoBack == false)
        #expect(history.canGoForward == true)
    }

    @Test("Forward after back returns to later entry")
    func forwardAfterBack() {
        var history = NavigationHistory()
        history.push(1)
        history.push(2)
        history.push(3)

        #expect(history.goBack() == 2)
        #expect(history.goBack() == 1)

        #expect(history.goForward() == 2)
        #expect(history.goForward() == 3)
        #expect(history.canGoForward == false)
    }

    @Test("New entry after back truncates forward history")
    func truncationOnNewEntry() {
        var history = NavigationHistory()
        history.push(1)
        history.push(2)
        history.push(3)

        _ = history.goBack() // now at 2
        history.push(10) // truncates [3]

        #expect(history.canGoBack == true) // can go back to 2
        #expect(history.canGoForward == false) // 3 is gone

        #expect(history.goBack() == 2)
        #expect(history.goBack() == 1)
        #expect(history.canGoBack == false)
    }

    @Test("Consecutive duplicate taps are deduplicated")
    func deduplication() {
        var history = NavigationHistory()
        history.push(1)
        history.push(1) // should not push again
        history.push(1) // should not push again

        #expect(history.canGoBack == false)
        #expect(history.canGoForward == false)
    }

    @Test("Go back on empty history returns nil")
    func backOnEmpty() {
        var history = NavigationHistory()
        #expect(history.goBack() == nil)
    }

    @Test("Go forward with no forward history returns nil")
    func forwardOnEmpty() {
        var history = NavigationHistory()
        history.push(1)
        #expect(history.goForward() == nil)
    }

    @Test("Clear resets everything")
    func clearResets() {
        var history = NavigationHistory()
        history.push(1)
        history.push(2)
        history.push(3)

        history.clear()
        #expect(history.canGoBack == false)
        #expect(history.canGoForward == false)

        // After clear, new navigation works fresh
        history.push(100)
        #expect(history.canGoBack == false)
    }

    @Test("History is capped at max entries")
    func historyCap() {
        var history = NavigationHistory(maxEntries: 100)
        for i in 0..<110 {
            history.push(i)
        }
        // The oldest 10 entries should have been dropped;
        // going back from 109 returns 108
        #expect(history.goBack() == 108)
        // Navigate all the way back (99 total goBacks to reach entry 10)
        for _ in 0..<98 {
            _ = history.goBack()
        }
        // Should be at entry 10 (the first one that survived the cap)
        #expect(history.canGoBack == false)
    }
}
