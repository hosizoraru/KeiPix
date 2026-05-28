import SwiftUI

struct WatchLaterView: View {
    @Bindable var store: KeiPixStore
    @State private var searchText = ""
    @State private var pendingDeleteItem: LocalArtworkHistoryItem?

    private var items: [LocalArtworkHistoryItem] {
        store.watchLaterItems(matching: searchText)
    }

    var body: some View {
        Group {
            if items.isEmpty {
                EmptyStateView(
                    title: L10n.watchLaterEmpty,
                    subtitle: L10n.watchLaterEmptyHint,
                    systemImage: "clock.badge.plus"
                )
            } else {
                content
            }
        }
        .navigationTitle(L10n.watchLater)
        .navigationSubtitle("\(items.count)")
        .searchable(text: $searchText, prompt: L10n.search)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button(role: .destructive) {
                    store.clearWatchLater()
                } label: {
                    Label(L10n.watchLaterClear, systemImage: "trash")
                }
                .disabled(store.watchLaterQueue.isEmpty)
            }
        }
    }

    private var content: some View {
        ScrollView {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 180, maximum: 240), spacing: 12)],
                spacing: 12
            ) {
                ForEach(items) { item in
                    WatchLaterCard(item: item) {
                        Task { await store.selectWatchLaterItem(item) }
                    } onRemove: {
                        pendingDeleteItem = item
                    }
                }
            }
            .padding(16)
        }
        .confirmationDialog(
            L10n.watchLaterRemoveConfirm,
            isPresented: Binding(
                get: { pendingDeleteItem != nil },
                set: { if !$0 { pendingDeleteItem = nil } }
            ),
            presenting: pendingDeleteItem
        ) { item in
            Button(L10n.watchLaterRemoved, role: .destructive) {
                pendingDeleteItem = nil
                store.removeFromWatchLater(item)
            }
            Button(L10n.cancel, role: .cancel) {}
        } message: { item in
            Text(item.title)
        }
    }
}

private struct WatchLaterCard: View {
    let item: LocalArtworkHistoryItem
    let onTap: () -> Void
    let onRemove: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 6) {
                RemoteImageView(url: item.thumbnailURL)
                    .aspectRatio(CGFloat(max(item.aspectRatio, 0.5)), contentMode: .fill)
                    .frame(height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(alignment: .topTrailing) {
                        if item.contentBadges.isEmpty == false {
                            ArtworkContentBadgesView(badges: item.contentBadges)
                                .padding(6)
                        }
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(2)
                    Text(item.creatorName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .padding(.horizontal, 4)
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                onRemove()
            } label: {
                Label(L10n.watchLaterRemoved, systemImage: "clock.badge.xmark")
            }
            if let url = item.pixivURL {
                Divider()
                Button {
                    PlatformWorkspace.open(url)
                } label: {
                    Label(L10n.openInPixiv, systemImage: "arrow.up.right.square")
                }
            }
        }
    }
}
