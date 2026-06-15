import Foundation
import Testing
@testable import KeiPix

@Suite("Spotlight article read state")
struct SpotlightArticleReadStateTests {
    @Test("Articles can be marked read and unread locally")
    func articlesCanBeMarkedReadAndUnread() {
        var library = SpotlightArticleReadStateLibrary()
        let article = makeArticle(id: 42)

        #expect(library.isRead(article) == false)

        library.markRead(article)

        #expect(library.isRead(article))
        #expect(library.readArticleIDs == [42])

        library.markUnread(article)

        #expect(library.isRead(article) == false)
        #expect(library.readArticleIDs.isEmpty)
    }

    @Test("Recording article history marks the article read")
    @MainActor
    func recordingArticleHistoryMarksArticleRead() {
        let defaults = UserDefaults.standard
        let readStateKey = "spotlightArticleReadStateLibrary"
        let historyKey = "spotlightArticleHistory"
        let originalReadState = defaults.data(forKey: readStateKey)
        let originalHistory = defaults.data(forKey: historyKey)
        defer {
            if let originalReadState {
                defaults.set(originalReadState, forKey: readStateKey)
            } else {
                defaults.removeObject(forKey: readStateKey)
            }
            if let originalHistory {
                defaults.set(originalHistory, forKey: historyKey)
            } else {
                defaults.removeObject(forKey: historyKey)
            }
        }
        defaults.removeObject(forKey: readStateKey)
        defaults.removeObject(forKey: historyKey)

        let store = KeiPixStore(
            downloads: ArtworkDownloadStore(completionNotifier: DownloadCompletionNotifier(
                center: FakeUserNotificationCenter(isAuthorized: false),
                authorizationStore: InMemoryAuthorizationCacheStore(hasRequested: true),
                coalesceWindowSeconds: 0.05
            )),
            bootstrapsAutomatically: false
        )
        let article = makeArticle(id: 84)

        #expect(store.isSpotlightArticleRead(article) == false)

        store.recordSpotlightArticleHistory(article)

        #expect(store.isSpotlightArticleRead(article))
        #expect(store.spotlightArticleHistory.map(\.id) == [84])

        store.markSpotlightArticleUnread(article)

        #expect(store.isSpotlightArticleRead(article) == false)
        #expect(store.spotlightArticleHistory.map(\.id) == [84])
    }

    private func makeArticle(id: Int) -> PixivSpotlightArticle {
        PixivSpotlightArticle(
            id: id,
            title: "Article \(id)",
            pureTitle: "Article \(id)",
            thumbnail: nil,
            articleURL: URL(string: "https://www.pixivision.net/a/\(id)")!,
            publishDate: Date(timeIntervalSince1970: 1_771_000_000)
        )
    }
}
