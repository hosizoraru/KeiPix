import SwiftUI

struct WatchLaterView: View {
    @Bindable var store: KeiPixStore
    @State private var searchText = ""
    @State private var isSearchPresented = false
    @State private var pendingDeleteItem: LocalArtworkHistoryItem?
    @State private var isClearConfirmationPresented = false
    @State private var actionMessage: String?

    private let gridLayout = NativeAdaptiveGridCollectionLayout(
        minimumItemWidth: 180,
        maximumItemWidth: 240,
        itemHeight: 252,
        spacing: 12,
        sectionInsets: EdgeInsets(top: 16, leading: 16, bottom: 20, trailing: 16)
    )

    private var items: [LocalArtworkHistoryItem] {
        store.watchLaterItems(matching: searchText)
    }

    var body: some View {
        VStack(spacing: 0) {
            if showsWatchLaterSearchBar {
                header
                    .platformGlassControlBar(verticalPadding: 7, topPadding: 0)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

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
        .platformPageHeader(
            title: L10n.watchLater,
            status: watchLaterStatusText,
            statusSystemImage: "bookmark.circle"
        ) {
            watchLaterTitleActions
        }
        .platformPageNavigationChrome(title: L10n.watchLater, status: watchLaterStatusText)
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
        .animation(.snappy(duration: 0.18), value: showsWatchLaterSearchBar)
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

    private var watchLaterStatusText: String {
        items.count.formatted()
    }

    private var header: some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 10) {
                watchLaterSearchField
                    .frame(minWidth: 220, idealWidth: 320, maxWidth: 520)
                    .layoutPriority(1)
                Spacer(minLength: 0)
            }
        }
        .controlSize(.small)
    }

    private var watchLaterSearchField: some View {
        OS26LibrarySearchField(
            text: $searchText,
            placeholder: L10n.searchHistory,
            minWidth: 180,
            idealWidth: 260,
            maxWidth: 420,
            collapsesOnPhone: false
        )
    }

    private var watchLaterTitleActions: some View {
        OS26LibraryActionRail {
            Button {
                withAnimation(.snappy(duration: 0.16)) {
                    if showsWatchLaterSearchBar, searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        isSearchPresented = false
                    } else {
                        isSearchPresented = true
                    }
                }
            } label: {
                Label(
                    L10n.search,
                    systemImage: searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? "magnifyingglass"
                        : "magnifyingglass.circle.fill"
                )
            }
            .os26GlassIconButton(prominent: showsWatchLaterSearchBar || searchText.isEmpty == false)
            .help(L10n.searchHistory)
            .accessibilityLabel(L10n.searchHistory)

            Button {
                withAnimation(.snappy(duration: 0.16)) {
                    searchText = ""
                    isSearchPresented = false
                }
            } label: {
                Label(L10n.clearSearch, systemImage: "xmark.circle")
            }
            .os26GlassIconButton()
            .disabled(searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && isSearchPresented == false)
            .help(L10n.clearSearch)

            Menu {
                Button(role: .destructive) {
                    isClearConfirmationPresented = true
                } label: {
                    Label(L10n.watchLaterClear, systemImage: "trash")
                }
                .disabled(store.watchLaterQueue.isEmpty)
            } label: {
                Label(L10n.moreActions, systemImage: "ellipsis.circle")
            }
            .os26GlassIconButton()
            .help(L10n.moreActions)
        }
        .controlSize(.small)
    }

    private var showsWatchLaterSearchBar: Bool {
        isSearchPresented || searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    private var content: some View {
        NativeAdaptiveGridCollectionView(
            items: items,
            layout: gridLayout
        ) { item in
            AnyView(
                WatchLaterCard(item: item) {
                    Task { await store.selectWatchLaterItem(item) }
                } onRemove: {
                    pendingDeleteItem = item
                }
            )
        }
        .nativeBottomTabContentSurface()
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
                    .frame(height: 170)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
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
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .keiInteractiveGlass(18)
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
