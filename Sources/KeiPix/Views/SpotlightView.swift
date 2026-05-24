import SwiftUI

struct SpotlightView: View {
    @Bindable var store: KeiPixStore
    @State private var articles: [PixivSpotlightArticle] = []
    @State private var nextURL: URL?
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if store.session == nil {
                EmptyStateView(title: L10n.signedOutTitle, subtitle: L10n.signedOutSubtitle, systemImage: "person.crop.circle.badge.exclamationmark")
            } else if isLoading {
                ProgressView(L10n.loading)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if articles.isEmpty {
                ContentUnavailableView(L10n.noSpotlightArticles, systemImage: "newspaper")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                        Section {
                            LazyVStack(spacing: 12) {
                                ForEach(articles) { article in
                                    SpotlightArticleCard(
                                        article: article,
                                        isSelected: store.selectedSpotlightArticle?.id == article.id
                                    ) {
                                        store.selectedSpotlightArticle = article
                                    }
                                }
                            }
                            .padding(.horizontal, 18)
                            .padding(.top, 14)

                            if nextURL != nil {
                                Button {
                                    Task { await loadMore() }
                                } label: {
                                    Label(isLoadingMore ? L10n.loading : L10n.loadMoreSpotlightArticles, systemImage: "arrow.down.circle")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                                .disabled(isLoadingMore)
                                .padding(.horizontal, 18)
                                .padding(.vertical, 14)
                            }
                        } header: {
                            header
                                .padding(.horizontal, 18)
                                .padding(.vertical, 10)
                                .background(.bar)
                        }
                    }
                }
                .scrollEdgeEffectStyle(.soft, for: .top)
            }
        }
        .navigationTitle(L10n.spotlight)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await load() }
                } label: {
                    Label(L10n.refresh, systemImage: "arrow.clockwise")
                }
                .disabled(isLoading)
            }
        }
        .safeAreaInset(edge: .bottom) {
            if let errorMessage {
                Text(errorMessage)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
                    .padding(12)
                    .frame(maxWidth: .infinity)
                    .background(.bar)
            }
        }
        .task {
            await load()
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(L10n.spotlight)
                    .font(.headline)
                Text("\(articles.count.formatted()) \(L10n.results) · \(nextURL == nil ? L10n.noMorePages : L10n.nextPageAvailable)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    private func load() async {
        guard store.session != nil else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let response = try await store.spotlightArticles()
            articles = response.articles
            selectStableArticle()
            nextURL = response.nextURL
        } catch {
            articles = []
            store.selectedSpotlightArticle = nil
            nextURL = nil
            errorMessage = error.localizedDescription
        }
    }

    private func loadMore() async {
        guard let nextURL, isLoadingMore == false else { return }
        isLoadingMore = true
        errorMessage = nil
        defer { isLoadingMore = false }

        do {
            let response = try await store.nextSpotlightArticles(nextURL)
            articles.append(contentsOf: response.articles)
            selectStableArticle()
            self.nextURL = response.nextURL
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func selectStableArticle() {
        if let selected = store.selectedSpotlightArticle,
           articles.contains(where: { $0.id == selected.id }) {
            return
        }
        store.selectedSpotlightArticle = articles.first
    }
}

private struct SpotlightArticleCard: View {
    let article: PixivSpotlightArticle
    let isSelected: Bool
    let select: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: select) {
            HStack(alignment: .top, spacing: 14) {
                RemoteImageView(url: article.thumbnail)
                    .aspectRatio(16.0 / 9.0, contentMode: .fill)
                    .frame(width: 220, height: 124)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 8) {
                    Text(article.pureTitle.isEmpty ? article.title : article.pureTitle)
                        .font(.headline)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    Text(article.title)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    Spacer(minLength: 4)

                    HStack(spacing: 8) {
                        Label(article.publishDate.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                            .lineLimit(1)

                        Spacer()

                        Label(L10n.openArticle, systemImage: "newspaper")
                            .lineLimit(1)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 148, alignment: .leading)
            .background(.quinary, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(isHovering ? 0.28 : 0.1), lineWidth: isSelected ? 2 : 1)
            }
        }
        .buttonStyle(.plain)
        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .shadow(color: .black.opacity(isHovering ? 0.12 : 0.04), radius: isHovering ? 8 : 2, y: isHovering ? 4 : 1)
        .animation(.snappy(duration: 0.16), value: isHovering)
        .onHover { isHovering = $0 }
        .help(article.pureTitle.isEmpty ? article.title : article.pureTitle)
        .contextMenu {
            Button(L10n.openArticle) {
                select()
            }
            Link(L10n.openInPixiv, destination: article.articleURL)
            Button(L10n.copyLink) {
                PasteboardWriter.copy(article.articleURL.absoluteString)
            }
        }
    }
}
