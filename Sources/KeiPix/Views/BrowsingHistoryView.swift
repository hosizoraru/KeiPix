import SwiftUI

struct BrowsingHistoryView: View {
    @Bindable var store: KeiPixStore
    @State private var source = BrowsingHistorySource.local
    @State private var localSearchText = ""
    @State private var isClearConfirmationPresented = false

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(.bar)

            Divider()

            switch source {
            case .local:
                localHistoryContent
            case .pixiv:
                pixivHistoryContent
            }
        }
        .navigationTitle(L10n.history)
        .confirmationDialog(
            L10n.clearHistoryConfirmation,
            isPresented: $isClearConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button(L10n.clearHistory, role: .destructive) {
                store.clearLocalBrowsingHistory()
            }
            Button(L10n.cancel, role: .cancel) {}
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Picker(L10n.historySource, selection: $source) {
                ForEach(BrowsingHistorySource.allCases) { source in
                    Text(source.title).tag(source)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 220)

            if source == .local {
                TextField(L10n.searchHistory, text: $localSearchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 280)

                Button {
                    localSearchText = ""
                } label: {
                    Label(L10n.clearSearch, systemImage: "xmark.circle")
                }
                .labelStyle(.iconOnly)
                .disabled(localSearchText.isEmpty)
                .help(L10n.clearSearch)
            }

            Spacer()

            if source == .local {
                Text(localHistoryCountText)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button(role: .destructive) {
                    isClearConfirmationPresented = true
                } label: {
                    Label(L10n.clearHistory, systemImage: "trash")
                }
                .disabled(store.localBrowsingHistory.isEmpty)
            } else {
                Button {
                    Task { await store.reloadCurrentFeed() }
                } label: {
                    Label(L10n.refresh, systemImage: "arrow.clockwise")
                }
            }
        }
    }

    private var localHistoryContent: some View {
        let items = store.localHistoryItems(matching: localSearchText)
        return Group {
            if items.isEmpty {
                EmptyStateView(
                    title: L10n.noLocalHistoryTitle,
                    subtitle: L10n.noLocalHistorySubtitle,
                    systemImage: "clock.arrow.circlepath"
                )
            } else {
                ScrollView {
                    LazyVGrid(columns: localColumns, spacing: 14) {
                        ForEach(items) { item in
                            LocalHistoryCard(
                                item: item,
                                isSelected: store.selectedArtwork?.id == item.id,
                                showContentBadges: store.showContentBadges,
                                select: {
                                    Task { await store.selectLocalHistoryItem(item) }
                                },
                                delete: {
                                    store.deleteLocalHistoryItem(item)
                                }
                            )
                        }
                    }
                    .padding(18)
                }
                .scrollEdgeEffectStyle(.soft, for: .top)
            }
        }
    }

    private var pixivHistoryContent: some View {
        Group {
            if store.isLoading {
                ProgressView(L10n.loading)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if store.artworks.isEmpty {
                EmptyStateView(
                    title: L10n.noPixivHistoryTitle,
                    subtitle: L10n.noPixivHistorySubtitle,
                    systemImage: "clock.badge.questionmark"
                )
            } else {
                ScrollView {
                    LazyVGrid(columns: pixivColumns, spacing: 14) {
                        ForEach(store.artworks) { artwork in
                            ArtworkCardView(
                                artwork: artwork,
                                isSelected: store.selectedArtwork?.id == artwork.id,
                                isCompact: true,
                                showContentBadges: store.showContentBadges
                            ) {
                                store.selectedArtwork = artwork
                            }
                            .contextMenu {
                                Button(artwork.isBookmarked ? L10n.removeBookmark : L10n.bookmark) {
                                    Task { await store.toggleBookmark(artwork) }
                                }
                                Button(L10n.download) {
                                    store.enqueueDownload(artwork)
                                }
                                if let url = artwork.pixivURL {
                                    Link(L10n.openInPixiv, destination: url)
                                }
                            }
                        }

                        if store.hasNextPage {
                            Button {
                                Task { await store.loadMore() }
                            } label: {
                                Label(L10n.loadMore, systemImage: "arrow.down.circle")
                                    .frame(maxWidth: .infinity, minHeight: 132)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding(18)
                }
                .scrollEdgeEffectStyle(.soft, for: .top)
            }
        }
    }

    private var localColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 170, maximum: 240), spacing: 14)]
    }

    private var pixivColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 160, maximum: 220), spacing: 14)]
    }

    private var localHistoryCountText: String {
        String(format: L10n.historyItemCountFormat, store.localHistoryItems(matching: localSearchText).count)
    }
}

private enum BrowsingHistorySource: String, CaseIterable, Identifiable {
    case local
    case pixiv

    var id: String { rawValue }

    var title: String {
        switch self {
        case .local: L10n.localHistory
        case .pixiv: L10n.pixivHistory
        }
    }
}

private struct LocalHistoryCard: View {
    let item: LocalArtworkHistoryItem
    let isSelected: Bool
    let showContentBadges: Bool
    let select: () -> Void
    let delete: () -> Void

    var body: some View {
        Button(action: select) {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .topLeading) {
                    RemoteImageView(url: item.thumbnailURL)
                        .aspectRatio(cardAspectRatio, contentMode: .fill)

                    if showContentBadges {
                        ArtworkContentBadgesView(badges: item.contentBadges, style: .overlay)
                            .padding(8)
                    }
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(item.title)
                        .font(.callout.weight(.semibold))
                        .lineLimit(2)

                    Text(item.creatorName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        Label("\(item.pageCount) \(L10n.pages)", systemImage: "square.stack")
                        Spacer(minLength: 8)
                        Text(item.viewedAt.formatted(date: .abbreviated, time: .shortened))
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
                .padding(10)
            }
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(borderStyle, lineWidth: isSelected ? 2 : 1)
        }
        .contextMenu {
            Button(role: .destructive, action: delete) {
                Label(L10n.deleteFromHistory, systemImage: "trash")
            }
            if let url = item.pixivURL {
                Link(L10n.openInPixiv, destination: url)
            }
        }
    }

    private var cardAspectRatio: CGFloat {
        CGFloat(min(max(item.aspectRatio, 0.72), 1.35))
    }

    private var borderStyle: some ShapeStyle {
        isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.separator.opacity(0.45))
    }
}
