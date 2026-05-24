import SwiftUI

struct SpotlightArticleDetailView: View {
    @Bindable var store: KeiPixStore
    @State private var webProfileUser: PixivUser?
    @State private var actionMessage: String?

    var body: some View {
        if let article = store.selectedSpotlightArticle {
            VStack(spacing: 0) {
                SpotlightArticleHeader(
                    article: article,
                    copyLink: {
                        PasteboardWriter.copy(article.articleURL.absoluteString)
                        showActionMessage(L10n.copiedArticleLink)
                    }
                )
                    .padding(16)

                Divider()

                WebArticleView(url: article.articleURL) { artworkID in
                    Task { await store.openArtworkFromWebLink(artworkID) }
                } openUserLink: { userID in
                    Task { await openWebProfile(userID) }
                }
                .id(article.id)
            }
            .navigationTitle(article.pureTitle.isEmpty ? L10n.spotlight : article.pureTitle)
            .sheet(item: $webProfileUser) { user in
                UserProfileSheet(user: user, store: store)
            }
            .overlay(alignment: .bottom) {
                if let actionMessage {
                    FloatingStatusBanner(maxWidth: 420) {
                        Text(actionMessage)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 14)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.snappy(duration: 0.18), value: actionMessage)
            .task(id: actionMessage) {
                await dismissActionMessageIfNeeded(actionMessage)
            }
        } else {
            ContentUnavailableView(L10n.selectArticle, systemImage: "newspaper")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .navigationTitle(L10n.spotlight)
        }
    }

    private func openWebProfile(_ userID: Int) async {
        do {
            let detail = try await store.userDetail(userID: userID)
            webProfileUser = detail.user
        } catch {
            store.errorMessage = error.localizedDescription
        }
    }

    private func showActionMessage(_ message: String) {
        actionMessage = message
    }

    private func dismissActionMessageIfNeeded(_ message: String?) async {
        guard let message else { return }
        do {
            try await Task.sleep(for: .seconds(2.5))
        } catch {
            return
        }
        if actionMessage == message {
            actionMessage = nil
        }
    }
}

private struct SpotlightArticleHeader: View {
    let article: PixivSpotlightArticle
    let copyLink: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            RemoteImageView(url: article.thumbnail)
                .aspectRatio(16.0 / 9.0, contentMode: .fill)
                .frame(width: 96, height: 54)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                Text(article.pureTitle.isEmpty ? article.title : article.pureTitle)
                    .font(.headline)
                    .lineLimit(2)
                    .textSelection(.enabled)

                Label(article.publishDate.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            ShareLink(item: article.articleURL) {
                Label(L10n.share, systemImage: "square.and.arrow.up")
            }
            .labelStyle(.iconOnly)
            .help(L10n.share)

            Button(action: copyLink) {
                Label(L10n.copyLink, systemImage: "link")
            }
            .labelStyle(.iconOnly)
            .help(L10n.copyLink)

            Link(destination: article.articleURL) {
                Label(L10n.openInPixiv, systemImage: "safari")
            }
            .labelStyle(.iconOnly)
            .help(L10n.openInPixiv)
        }
    }
}
