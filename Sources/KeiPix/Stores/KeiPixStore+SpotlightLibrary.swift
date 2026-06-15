import Foundation

@MainActor
extension KeiPixStore {
    func isSpotlightArticleSaved(_ article: PixivSpotlightArticle) -> Bool {
        spotlightFavoriteArticles.contains { $0.id == article.id }
    }

    func isSpotlightArticleRead(_ article: PixivSpotlightArticle) -> Bool {
        spotlightArticleReadStateLibrary.isRead(article)
    }

    func markSpotlightArticleRead(_ article: PixivSpotlightArticle) {
        guard spotlightArticleReadStateLibrary.isRead(article) == false else { return }
        spotlightArticleReadStateLibrary.markRead(article)
        persistSpotlightArticleReadState()
    }

    func markSpotlightArticleUnread(_ article: PixivSpotlightArticle) {
        guard spotlightArticleReadStateLibrary.isRead(article) else { return }
        spotlightArticleReadStateLibrary.markUnread(article)
        persistSpotlightArticleReadState()
    }

    @discardableResult
    func toggleSpotlightArticleFavorite(_ article: PixivSpotlightArticle) -> Bool {
        if let index = spotlightFavoriteArticles.firstIndex(where: { $0.id == article.id }) {
            spotlightFavoriteArticles.remove(at: index)
            persistSpotlightFavoriteArticles()
            return false
        }

        spotlightFavoriteArticles.removeAll { $0.id == article.id }
        spotlightFavoriteArticles.insert(article, at: 0)
        spotlightFavoriteArticles = Array(spotlightFavoriteArticles.prefix(500))
        persistSpotlightFavoriteArticles()
        return true
    }

    func recordSpotlightArticleHistory(_ article: PixivSpotlightArticle) {
        spotlightArticleHistory.removeAll { $0.id == article.id }
        spotlightArticleHistory.insert(article, at: 0)
        spotlightArticleHistory = Array(spotlightArticleHistory.prefix(500))
        persistSpotlightArticleHistory()
        markSpotlightArticleRead(article)
    }

    func clearSpotlightArticleHistory() {
        spotlightArticleHistory = []
        persistSpotlightArticleHistory()
    }

    func removeSpotlightArticleHistory(_ article: PixivSpotlightArticle) {
        spotlightArticleHistory.removeAll { $0.id == article.id }
        persistSpotlightArticleHistory()
    }

    private func persistSpotlightFavoriteArticles() {
        persistSpotlightArticles(spotlightFavoriteArticles, key: "spotlightFavoriteArticles")
    }

    private func persistSpotlightArticleHistory() {
        persistSpotlightArticles(spotlightArticleHistory, key: "spotlightArticleHistory")
    }

    private func persistSpotlightArticleReadState() {
        guard let data = try? JSONEncoder().encode(spotlightArticleReadStateLibrary) else { return }
        UserDefaults.standard.set(data, forKey: "spotlightArticleReadStateLibrary")
    }

    private func persistSpotlightArticles(_ articles: [PixivSpotlightArticle], key: String) {
        guard let data = try? JSONEncoder().encode(articles) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
