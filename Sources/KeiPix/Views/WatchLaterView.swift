import SwiftUI

struct WatchLaterView: View {
    @Bindable var store: KeiPixStore
    @State private var searchText = ""
    @State private var pendingDeleteItem: LocalArtworkHistoryItem?
    @State private var isClearConfirmationPresented = false
    @State private var actionMessage: String?

    private var items: [LocalArtworkHistoryItem] {
        store.watchLaterItems(matching: searchText)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(.bar)

            Divider()

            if items.isEmpty {
                EmptyStateView(
                    title: store.watchLaterQueue.isEmpty ? L10n.watchLaterEmpty : L10n.noMatchingHistoryTitle,
                    subtitle: store.watchLaterQueue.isEmpty ? L10n.watchLaterEmptyHint : L10n.noMatchingHistorySubtitle,
                    systemImage: store.watchLaterQueue.isEmpty ? "bookmark.circle" : "magnifyingglass"
                )
            } else {
                content
            }
        }
        .navigationTitle(L10n.watchLater)
        .navigationSubtitle("\(items.count)")
        .confirmationDialog(
            L10n.clearHistoryConfirmation,
            isPresented: $isClearConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button(L10n.watchLaterClear, role: .destructive) {
                let cleared = store.watchLaterQueue
                store.clearWatchLater()
                store.undoAction = AppUndoAction(kind: .restoreWatchLater(cleared))
                actionMessage = String(format: L10n.clearedWatchLaterFormat, cleared.count)
            }
            Button(L10n.cancel, role: .cancel) {}
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
                store.undoAction = AppUndoAction(kind: .restoreWatchLater([item]))
                actionMessage = String(format: L10n.watchLaterRemovedFormat, item.title)
            }
            Button(L10n.cancel, role: .cancel) {
                pendingDeleteItem = nil
            }
        } message: { item in
            Text(item.title)
        }
        .animation(.snappy(duration: 0.18), value: actionMessage)
        .task(id: actionMessage) {
            await dismissActionMessageIfNeeded(actionMessage)
        }
        .overlay(alignment: .bottom) {
            if let actionMessage {
                FloatingStatusBanner(maxWidth: 520) {
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
    }

    private var header: some View {
        HStack(spacing: 8) {
            TextField(L10n.searchHistory, text: $searchText)
                .textFieldStyle(.roundedBorder)
                .frame(minWidth: 180, idealWidth: 220, maxWidth: 260)

            Button {
                searchText = ""
            } label: {
                Label(L10n.clearSearch, systemImage: "xmark.circle")
            }
            .labelStyle(.iconOnly)
            .disabled(searchText.isEmpty)
            .help(L10n.clearSearch)

            Spacer(minLength: 0)

            Menu {
                Button(role: .destructive) {
                    isClearConfirmationPresented = true
                } label: {
                    Label(L10n.watchLaterClear, systemImage: "trash")
                }
                .disabled(store.watchLaterQueue.isEmpty)
            } label: {
                Label(L10n.moreActions, systemImage: "ellipsis.circle")
                    .labelStyle(.iconOnly)
            }
            .help(L10n.moreActions)
        }
        .controlSize(.small)
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
    }

    private func dismissActionMessageIfNeeded(_ message: String?) async {
        try? await Task.sleep(for: .seconds(3))
        if actionMessage == message {
            actionMessage = nil
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
                Label(L10n.watchLaterRemoveConfirm, systemImage: "bookmark.slash")
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
