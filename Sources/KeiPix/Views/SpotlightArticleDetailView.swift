import SwiftUI

struct SpotlightArticleDetailView: View {
    @Bindable var store: KeiPixStore

    var body: some View {
        if let article = store.selectedSpotlightArticle {
            VStack(spacing: 0) {
                SpotlightArticleHeader(article: article)
                    .padding(16)

                Divider()

                WebArticleView(url: article.articleURL)
                    .id(article.id)
            }
            .navigationTitle(article.pureTitle.isEmpty ? L10n.spotlight : article.pureTitle)
        } else {
            ContentUnavailableView(L10n.selectArticle, systemImage: "newspaper")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .navigationTitle(L10n.spotlight)
        }
    }
}

private struct SpotlightArticleHeader: View {
    let article: PixivSpotlightArticle

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            RemoteImageView(url: article.thumbnail)
                .aspectRatio(16.0 / 9.0, contentMode: .fill)
                .frame(maxWidth: .infinity)
                .frame(height: 190)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                Text(article.pureTitle.isEmpty ? article.title : article.pureTitle)
                    .font(.title3.weight(.semibold))
                    .lineLimit(3)
                    .textSelection(.enabled)

                Text(article.title)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .textSelection(.enabled)

                HStack(spacing: 12) {
                    Label(article.publishDate.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")

                    Spacer()

                    ShareLink(item: article.articleURL) {
                        Label(L10n.share, systemImage: "square.and.arrow.up")
                    }

                    Link(destination: article.articleURL) {
                        Label(L10n.openInPixiv, systemImage: "safari")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }
}
