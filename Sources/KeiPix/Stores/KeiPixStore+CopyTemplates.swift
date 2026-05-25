import Foundation

@MainActor
extension KeiPixStore {
    var artworkCopyTemplatePreview: String {
        ArtworkCopyTemplate(rawValue: artworkCopyTemplate).render(context: .preview)
    }

    var creatorCopyTemplatePreview: String {
        CreatorCopyTemplate(rawValue: creatorCopyTemplate).render(context: .preview)
    }

    func renderArtworkCopySummary(_ artwork: PixivArtwork, pageCount: Int? = nil) -> String {
        ArtworkCopyTemplate(rawValue: artworkCopyTemplate).render(
            context: ArtworkCopyTemplate.Context(
                artworkID: artwork.id,
                title: artwork.title,
                creatorName: artwork.user.name,
                creatorAccount: artwork.user.account,
                creatorID: artwork.user.id,
                pageCount: pageCount ?? artwork.pageCount,
                views: artwork.totalView,
                bookmarks: artwork.totalBookmarks,
                comments: artwork.totalComments,
                tags: artwork.tags.map(\.name),
                badges: artwork.contentBadges.map(\.title),
                url: artwork.pixivURL?.absoluteString ?? ""
            )
        )
    }

    func renderCreatorCopySummary(_ user: PixivUser) -> String {
        CreatorCopyTemplate(rawValue: creatorCopyTemplate).render(
            context: CreatorCopyTemplate.Context(
                name: user.name,
                account: user.account,
                userID: user.id,
                url: user.pixivURL?.absoluteString ?? ""
            )
        )
    }
}
