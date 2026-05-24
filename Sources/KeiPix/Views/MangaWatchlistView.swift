import SwiftUI

struct MangaWatchlistView: View {
    @Bindable var store: KeiPixStore

    @State private var series: [PixivMangaSeriesPreview] = []
    @State private var nextURL: URL?
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var removingSeriesIDs = Set<Int>()
    @State private var errorMessage: String?
    @State private var actionMessage: String?
    @State private var pendingRemoval: PixivMangaSeriesPreview?

    private let columns = [
        GridItem(.adaptive(minimum: 220, maximum: 320), spacing: 14)
    ]

    var body: some View {
        Group {
            if store.session == nil {
                EmptyStateView(title: L10n.signedOutTitle, subtitle: L10n.signedOutSubtitle, systemImage: "person.crop.circle.badge.exclamationmark")
            } else if isLoading {
                ProgressView(L10n.loading)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if series.isEmpty {
                ContentUnavailableView(L10n.noWatchlistSeries, systemImage: "rectangle.stack.badge.person.crop")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(series) { item in
                            MangaWatchlistCard(
                                series: item,
                                isRemoving: removingSeriesIDs.contains(item.id),
                                openLatest: {
                                    Task { await store.openLatestArtwork(in: item) }
                                },
                                remove: {
                                    pendingRemoval = item
                                }
                            )
                        }

                        if nextURL != nil {
                            loadMoreButton
                        }
                    }
                    .padding(18)
                }
                .scrollEdgeEffectStyle(.soft, for: .top)
            }
        }
        .navigationTitle(L10n.mangaWatchlist)
        .confirmationDialog(
            L10n.removeFromWatchlist,
            isPresented: removalBinding,
            titleVisibility: .visible,
            presenting: pendingRemoval
        ) { item in
            Button(L10n.removeFromWatchlist, role: .destructive) {
                Task { await remove(item) }
            }
            Button(L10n.cancel, role: .cancel) {
                pendingRemoval = nil
            }
        } message: { item in
            Text(String(format: L10n.removeFromWatchlistConfirmationFormat, item.title))
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

                if let undoAction = store.undoAction {
                    AppUndoBar(action: undoAction) {
                        Task { await store.performUndo(undoAction) }
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
        .animation(.snappy(duration: 0.18), value: store.undoAction?.id)
        .animation(.snappy(duration: 0.18), value: errorMessage)
        .task(id: actionMessage) {
            await dismissActionMessageIfNeeded(actionMessage)
        }
        .task(id: store.routeRefreshGeneration) {
            await loadInitial()
        }
    }

    private var loadMoreButton: some View {
        Button {
            Task { await loadMore() }
        } label: {
            VStack(spacing: 8) {
                if isLoadingMore {
                    ProgressView()
                } else {
                    Image(systemName: "arrow.down.circle")
                        .font(.title3)
                    Text(L10n.loadMoreWatchlist)
                        .font(.caption.weight(.medium))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 170)
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .keiInteractiveGlass(16)
        .disabled(isLoadingMore)
    }

    private func loadInitial() async {
        guard store.session != nil else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let response = try await store.mangaWatchlist()
            series = response.series
            nextURL = response.nextURL
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadMore() async {
        guard let nextURL else { return }
        isLoadingMore = true
        errorMessage = nil
        defer { isLoadingMore = false }

        do {
            let response = try await store.nextMangaWatchlist(nextURL)
            series.append(contentsOf: response.series)
            self.nextURL = response.nextURL
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func remove(_ item: PixivMangaSeriesPreview) async {
        removingSeriesIDs.insert(item.id)
        errorMessage = nil
        defer { removingSeriesIDs.remove(item.id) }

        do {
            try await store.setMangaWatchlist(seriesID: item.id, isAdded: false)
            series.removeAll { $0.id == item.id }
            pendingRemoval = nil
            store.undoAction = AppUndoAction(kind: .restoreMangaWatchlist(item))
            actionMessage = String(format: L10n.removedFromWatchlistFormat, item.title)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private var removalBinding: Binding<Bool> {
        Binding {
            pendingRemoval != nil
        } set: { value in
            if value == false {
                pendingRemoval = nil
            }
        }
    }

    private func dismissActionMessageIfNeeded(_ message: String?) async {
        guard let message else { return }
        try? await Task.sleep(for: .seconds(2.5))
        if actionMessage == message {
            actionMessage = nil
        }
    }
}

private struct MangaWatchlistCard: View {
    let series: PixivMangaSeriesPreview
    let isRemoving: Bool
    let openLatest: () -> Void
    let remove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            cover

            VStack(alignment: .leading, spacing: 5) {
                Text(series.title)
                    .font(.headline)
                    .lineLimit(2)

                if let user = series.user {
                    Text(user.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                HStack(spacing: 8) {
                    Label(series.publishedContentCount.formatted(), systemImage: "rectangle.stack")
                    if let date = series.lastPublishedContentDate {
                        Text(date.formatted(date: .abbreviated, time: .omitted))
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                Button {
                    openLatest()
                } label: {
                    Label(L10n.openLatestArtwork, systemImage: "arrow.right.circle")
                }
                .buttonStyle(.bordered)

                Spacer()

                Button(role: .destructive) {
                    remove()
                } label: {
                    if isRemoving {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label(L10n.removeFromWatchlist, systemImage: "minus.circle")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(isRemoving)
            }
        }
        .padding(12)
        .keiInteractiveGlass(16)
        .contextMenu {
            Button(L10n.openLatestArtwork) {
                openLatest()
            }
            if let url = series.pixivURL {
                Link(L10n.openSeriesInPixiv, destination: url)
            }
            Divider()
            Button(role: .destructive) {
                remove()
            } label: {
                Text(L10n.removeFromWatchlist)
            }
        }
    }

    @ViewBuilder
    private var cover: some View {
        if let coverURL = series.coverURL {
            RemoteImageView(url: coverURL)
                .frame(maxWidth: .infinity)
                .aspectRatio(1.9, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.quaternary)
                .aspectRatio(1.9, contentMode: .fit)
                .overlay {
                    Image(systemName: "rectangle.stack")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
        }
    }
}
