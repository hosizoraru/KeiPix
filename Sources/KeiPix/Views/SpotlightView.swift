import SwiftUI

struct SpotlightView: View {
    @Bindable var store: KeiPixStore
    @State private var articles: [PixivSpotlightArticle] = []
    @State private var nextURL: URL?
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var errorMessage: String?

    private let columns = [
        GridItem(.adaptive(minimum: 260, maximum: 360), spacing: 14)
    ]

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
                            LazyVGrid(columns: columns, spacing: 14) {
                                ForEach(articles) { article in
                                    SpotlightArticleCard(article: article)
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
            nextURL = response.nextURL
        } catch {
            articles = []
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
            self.nextURL = response.nextURL
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct SpotlightArticleCard: View {
    let article: PixivSpotlightArticle
    @State private var isHovering = false

    var body: some View {
        Link(destination: article.articleURL) {
            VStack(alignment: .leading, spacing: 0) {
                RemoteImageView(url: article.thumbnail)
                    .aspectRatio(1.56, contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .clipped()

                VStack(alignment: .leading, spacing: 8) {
                    Text(article.pureTitle.isEmpty ? article.title : article.pureTitle)
                        .font(.headline)
                        .lineLimit(2)

                    Text(article.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)

                    HStack(spacing: 8) {
                        Label(article.publishDate.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                            .lineLimit(1)

                        Spacer()

                        Label(L10n.openArticle, systemImage: "arrow.up.right.square")
                            .lineLimit(1)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .padding(12)
            }
            .background(.quinary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.secondary.opacity(isHovering ? 0.32 : 0.1), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(isHovering ? 0.16 : 0.06), radius: isHovering ? 10 : 4, y: isHovering ? 6 : 2)
        .scaleEffect(isHovering ? 1.01 : 1)
        .animation(.snappy(duration: 0.16), value: isHovering)
        .onHover { isHovering = $0 }
        .help(article.pureTitle.isEmpty ? article.title : article.pureTitle)
        .contextMenu {
            Link(L10n.openArticle, destination: article.articleURL)
            Button(L10n.copyLink) {
                PasteboardWriter.copy(article.articleURL.absoluteString)
            }
        }
    }
}
