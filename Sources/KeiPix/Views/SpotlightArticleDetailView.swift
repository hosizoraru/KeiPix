import SwiftUI

/// Detail surface for a single Pixivision article.
///
/// The previous implementation embedded a `WKWebView` to render the
/// Pixivision Web page. That meant users were effectively staring at
/// an in-app browser tab — slow first paint, GDPR popovers, and no
/// shared chrome with the rest of KeiPix. The new surface keeps a
/// thin native chrome bar and hands the body to `PixivisionReaderView`,
/// which downloads the page once, parses it through
/// `PixivisionArticleParser`, and renders every block (heading,
/// paragraph, work card, tag) the way Apple News / Reader Mode would.
struct SpotlightArticleDetailView: View {
    @Bindable var store: KeiPixStore
    var showsNavigationChrome = true
    @State private var webProfileUser: PixivUser?
    @State private var actionMessage: String?

    var body: some View {
        if let article = store.selectedSpotlightArticle {
            VStack(spacing: 0) {
                SpotlightArticleHeader(
                    article: article,
                    isSaved: store.isSpotlightArticleSaved(article),
                    copyLink: {
                        PasteboardWriter.copy(article.articleURL.absoluteString)
                        showActionMessage(L10n.copiedArticleLink)
                    },
                    toggleSaved: {
                        let saved = store.toggleSpotlightArticleFavorite(article)
                        showActionMessage(saved ? L10n.savedArticle : L10n.removedSavedArticle)
                    }
                )
                .padding(16)

                Divider()

                PixivisionReaderView(
                    article: article,
                    store: store,
                    openCreator: { userID in
                        await openWebProfile(userID)
                    },
                    showStatus: showActionMessage,
                    selectArticle: { nextArticle in
                        store.recordSpotlightArticleHistory(nextArticle)
                        store.selectedSpotlightArticle = nextArticle
                    }
                )
                .id(article.id)
            }
            .navigationTitle(showsNavigationChrome ? (article.pureTitle.isEmpty ? L10n.spotlight : article.pureTitle) : "")
            .task(id: article.id) {
                store.recordSpotlightArticleHistory(article)
            }
            .sheet(item: $webProfileUser) { user in
                UserProfileSheet(user: user, store: store)
                    .iPadFriendlySheet()
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
                .navigationTitle(showsNavigationChrome ? L10n.spotlight : "")
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

/// Compact header bar above the reader. Identity (avatar / title /
/// date) on the leading edge, share + save + open-in-Pixiv chips on
/// the trailing edge.
private struct SpotlightArticleHeader: View {
    let article: PixivSpotlightArticle
    let isSaved: Bool
    let copyLink: () -> Void
    let toggleSaved: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            RemoteImageView(url: article.thumbnail)
                .aspectRatio(16.0 / 9.0, contentMode: .fill)
                .frame(width: 96, height: 54)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(.quaternary, lineWidth: 1)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(article.pureTitle.isEmpty ? article.title : article.pureTitle)
                    .font(.headline)
                    .lineLimit(2)
                    .textSelection(.enabled)

                Label(
                    article.publishDate.formatted(date: .abbreviated, time: .omitted),
                    systemImage: "calendar"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 8) {
                Button(action: toggleSaved) {
                    Label(
                        isSaved ? L10n.removeSavedArticle : L10n.saveArticle,
                        systemImage: isSaved ? "star.fill" : "star"
                    )
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help(isSaved ? L10n.removeSavedArticle : L10n.saveArticle)

                ShareLink(item: article.articleURL) {
                    Label(L10n.share, systemImage: "square.and.arrow.up")
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help(L10n.share)

                Button(action: copyLink) {
                    Label(L10n.copyLink, systemImage: "link")
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help(L10n.copyLink)

                Link(destination: article.articleURL) {
                    Label(L10n.openInPixiv, systemImage: "safari")
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help(L10n.openInPixiv)
            }
        }
    }
}
