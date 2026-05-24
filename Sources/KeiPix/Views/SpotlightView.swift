import SwiftUI

struct SpotlightView: View {
    @Bindable var store: KeiPixStore
    @State private var articles: [PixivSpotlightArticle] = []
    @State private var nextURL: URL?
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var errorMessage: String?
    @State private var actionMessage: String?

    var body: some View {
        Group {
            if store.session == nil {
                EmptyStateView(title: L10n.signedOutTitle, subtitle: L10n.signedOutSubtitle, systemImage: "person.crop.circle.badge.exclamationmark")
            } else if isLoading {
                ProgressView(L10n.loading)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if articles.isEmpty {
                ContentUnavailableView {
                    Label(L10n.noSpotlightArticles, systemImage: "newspaper")
                } description: {
                    if let errorMessage {
                        Text(errorMessage)
                    }
                } actions: {
                    Button {
                        Task { await load() }
                    } label: {
                        Label(L10n.retry, systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: articleColumns, spacing: 14) {
                        ForEach(articles) { article in
                            SpotlightArticleCard(
                                article: article,
                                isSelected: store.selectedSpotlightArticle?.id == article.id
                            ) {
                                store.selectedSpotlightArticle = article
                            } copied: {
                                showActionMessage(L10n.copied)
                            }
                        }

                        if nextURL != nil {
                            Button {
                                Task { await loadMore() }
                            } label: {
                                Label(isLoadingMore ? L10n.loading : L10n.loadMoreSpotlightArticles, systemImage: "arrow.down.circle")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .disabled(isLoadingMore)
                            .gridCellColumns(2)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 14)
                    .padding(.bottom, 18)
                }
                .scrollEdgeEffectStyle(.soft, for: .top)
            }
        }
        .navigationTitle(L10n.spotlight)
        .toolbar {
            if articles.isEmpty == false {
                ToolbarItem(placement: .status) {
                    spotlightCountBadge
                }
            }
        }
        .overlay(alignment: .bottom) {
            VStack(spacing: 8) {
                if let actionMessage {
                    FloatingStatusBanner {
                        Text(actionMessage)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                if let errorMessage {
                    FloatingStatusBanner {
                        Text(errorMessage)
                            .font(.callout)
                            .foregroundStyle(.red)
                            .textSelection(.enabled)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 14)
        }
        .animation(.snappy(duration: 0.18), value: actionMessage)
        .animation(.snappy(duration: 0.18), value: errorMessage)
        .task(id: store.routeRefreshGeneration) {
            await load()
        }
    }

    private var articleColumns: [GridItem] {
        [
            GridItem(
                .adaptive(minimum: 280, maximum: 390),
                spacing: 14,
                alignment: .top
            )
        ]
    }

    private var spotlightCountBadge: some View {
        Text(spotlightSummary)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .help(spotlightSummary)
    }

    private var spotlightSummary: String {
        "\(articles.count.formatted()) \(L10n.results) · \(nextURL == nil ? L10n.noMorePages : L10n.nextPageAvailable)"
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

    private func showActionMessage(_ message: String) {
        actionMessage = message
        Task {
            try? await Task.sleep(for: .seconds(2.5))
            if actionMessage == message {
                actionMessage = nil
            }
        }
    }
}

private struct SpotlightArticleCard: View {
    let article: PixivSpotlightArticle
    let isSelected: Bool
    let select: () -> Void
    let copied: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: select) {
            VStack(alignment: .leading, spacing: 10) {
                RemoteImageView(url: article.thumbnail)
                    .aspectRatio(16.0 / 9.0, contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .frame(height: 156)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 8) {
                    Text(primaryTitle)
                        .font(.headline)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    if let secondaryTitle {
                        Text(secondaryTitle)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }

                    Spacer(minLength: 4)

                    HStack(alignment: .firstTextBaseline, spacing: 8) {
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
            .frame(maxWidth: .infinity, minHeight: 286, alignment: .topLeading)
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
        .help(primaryTitle)
        .contextMenu {
            Button(L10n.openArticle) {
                select()
            }
            Link(L10n.openInPixiv, destination: article.articleURL)
            Button(L10n.copyLink) {
                PasteboardWriter.copy(article.articleURL.absoluteString)
                copied()
            }
        }
    }

    private var primaryTitle: String {
        article.pureTitle.isEmpty ? article.title : article.pureTitle
    }

    private var secondaryTitle: String? {
        let normalizedTitle = article.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedPrimaryTitle = primaryTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalizedTitle.isEmpty == false,
              normalizedTitle.localizedCaseInsensitiveCompare(normalizedPrimaryTitle) != .orderedSame else {
            return nil
        }
        return normalizedTitle
    }
}
