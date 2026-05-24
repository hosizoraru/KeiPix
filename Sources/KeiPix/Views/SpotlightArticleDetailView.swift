import SwiftUI

struct SpotlightArticleDetailView: View {
    @Bindable var store: KeiPixStore
    @State private var webProfileUser: PixivUser?
    @State private var webNavigationState = WebArticleNavigationState()
    @State private var webCommand: WebArticleCommand?
    @State private var actionMessage: String?

    var body: some View {
        if let article = store.selectedSpotlightArticle {
            VStack(spacing: 0) {
                SpotlightArticleHeader(
                    article: article,
                    isSaved: store.isSpotlightArticleSaved(article),
                    navigationState: webNavigationState,
                    goBack: {
                        webCommand = WebArticleCommand(action: .goBack)
                    },
                    goForward: {
                        webCommand = WebArticleCommand(action: .goForward)
                    },
                    reload: {
                        webCommand = WebArticleCommand(action: .reload)
                    },
                    copyCurrentPageLink: {
                        PasteboardWriter.copy((webNavigationState.currentURL ?? article.articleURL).absoluteString)
                        showActionMessage(L10n.copied)
                    },
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

                ZStack {
                    WebArticleView(
                        url: article.articleURL,
                        navigationState: $webNavigationState,
                        command: webCommand
                    ) { artworkID in
                        Task { await store.openArtworkFromWebLink(artworkID) }
                    } openUserLink: { userID in
                        Task { await openWebProfile(userID) }
                    }

                    if let errorMessage = webNavigationState.errorMessage {
                        WebArticleRecoveryView(errorMessage: errorMessage) {
                            webCommand = WebArticleCommand(action: .reload)
                        }
                    }
                }
                .id(article.id)
            }
            .navigationTitle(article.pureTitle.isEmpty ? L10n.spotlight : article.pureTitle)
            .task(id: article.id) {
                store.recordSpotlightArticleHistory(article)
            }
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
    let isSaved: Bool
    let navigationState: WebArticleNavigationState
    let goBack: () -> Void
    let goForward: () -> Void
    let reload: () -> Void
    let copyCurrentPageLink: () -> Void
    let copyLink: () -> Void
    let toggleSaved: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                RemoteImageView(url: article.thumbnail)
                    .aspectRatio(16.0 / 9.0, contentMode: .fill)
                    .frame(width: 86, height: 48)
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
            }

            HStack(spacing: 8) {
                ControlGroup {
                    Button(action: goBack) {
                        Label(L10n.previousPage, systemImage: "chevron.left")
                    }
                    .disabled(navigationState.canGoBack == false)

                    Button(action: goForward) {
                        Label(L10n.nextPage, systemImage: "chevron.right")
                    }
                    .disabled(navigationState.canGoForward == false)

                    Button(action: reload) {
                        if navigationState.isLoading {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Label(L10n.reloadPage, systemImage: "arrow.clockwise")
                        }
                    }
                }
                .labelStyle(.iconOnly)

                Spacer(minLength: 8)

                Button(action: toggleSaved) {
                    Label(isSaved ? L10n.removeSavedArticle : L10n.saveArticle, systemImage: isSaved ? "star.fill" : "star")
                }
                .labelStyle(.iconOnly)
                .help(isSaved ? L10n.removeSavedArticle : L10n.saveArticle)

                ShareLink(item: article.articleURL) {
                    Label(L10n.share, systemImage: "square.and.arrow.up")
                }
                .labelStyle(.iconOnly)
                .help(L10n.share)

                Button(action: copyCurrentPageLink) {
                    Label(L10n.copyCurrentPageLink, systemImage: "doc.on.doc")
                }
                .labelStyle(.iconOnly)
                .help(L10n.copyCurrentPageLink)

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
}

private struct WebArticleRecoveryView: View {
    let errorMessage: String
    let retry: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label(L10n.errorTitle, systemImage: "exclamationmark.triangle")
        } description: {
            Text(errorMessage)
        } actions: {
            Button(action: retry) {
                Label(L10n.retry, systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(24)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(24)
    }
}
