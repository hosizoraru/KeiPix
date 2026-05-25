import SwiftUI

struct GalleryView: View {
    @Bindable var store: KeiPixStore
    @State private var actionMessage: String?

    var body: some View {
        Group {
            if store.session == nil {
                SignedOutView(store: store)
            } else if store.isLoading {
                ProgressView(L10n.loading)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                GalleryFeedView(store: store, actionMessage: $actionMessage)
            }
        }
        .navigationTitle(navigationTitle)
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
        .animation(.snappy(duration: 0.18), value: actionMessage)
        .toolbar {
            if store.session != nil, store.selectedRoute.usesArtworkFeed {
                ToolbarItem(placement: .status) {
                    Text(feedStatusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .help(feedDetailSummary)
                }
            }
        }
    }

    private var navigationTitle: String {
        if let focusedUser = store.focusedUser {
            return "\(store.selectedRoute.title) · \(focusedUser.name)"
        }
        return store.selectedRoute.title
    }

    private var feedStatusText: String {
        var parts = ["\(store.artworks.count.formatted()) \(L10n.results)"]
        if store.activeFeedSnapshotRestoration != nil {
            parts.append(L10n.cachedFeed)
        }
        if store.selectedRoute == .search, store.searchOptions.isDefault == false {
            parts.append(L10n.activeSearchFilters)
        }
        return parts.joined(separator: " · ")
    }

    private var feedDetailSummary: String {
        var parts = [
            feedStatusText,
            store.activeFeedSnapshotRestoration == nil && store.hasNextPage ? L10n.nextPageAvailable : L10n.noMorePages
        ]
        if let focusedUser = store.focusedUser {
            parts.append("\(focusedUser.name) @\(focusedUser.account)")
        }
        if store.selectedRoute == .search {
            let keyword = store.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            if keyword.isEmpty == false {
                parts.append(keyword)
            }
            parts.append(store.searchOptions.summary)
        }
        return parts.joined(separator: " · ")
    }
}

private struct GalleryFeedView: View {
    @Bindable var store: KeiPixStore
    @Binding var actionMessage: String?
    @State private var artworkSelection = GalleryArtworkSelection()
    @State private var batchBookmarkCommandRequest: BatchBookmarkCommandRequest?
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                Section {
                    Group {
                        if store.artworks.isEmpty {
                            EmptyStateView(
                                title: L10n.noArtworkTitle,
                                subtitle: L10n.noArtworkSubtitle,
                                systemImage: "photo.on.rectangle.angled"
                            )
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 420)
                        } else {
                            if let restoration = store.activeFeedSnapshotRestoration {
                                CachedFeedStatusStrip(restoration: restoration) {
                                    store.requestRouteRefresh()
                                }
                                .padding(.bottom, 12)
                            }

                            SearchPopularPreviewStrip(store: store, actionMessage: $actionMessage)

                            GalleryContentGrid(
                                store: store,
                                actionMessage: $actionMessage,
                                artworkSelection: $artworkSelection
                            )
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 14)
                    .padding(.bottom, 20)
                } header: {
                    FeedHeaderView(
                        store: store,
                        actionMessage: $actionMessage,
                        artworkSelection: $artworkSelection,
                        batchBookmarkCommandRequest: $batchBookmarkCommandRequest
                    )
                        .padding(.horizontal, 18)
                        .padding(.vertical, 5)
                        .background(.bar)
                }
            }
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
        .onChange(of: store.artworks.map(\.id)) { _, visibleArtworkIDs in
            artworkSelection.prune(visibleArtworkIDs: visibleArtworkIDs)
        }
        .onChange(of: store.selectedRoute) { _, _ in
            artworkSelection.clear()
        }
        .focusedSceneValue(\.gallerySelectionCommandActions, gallerySelectionCommandActions)
    }

    private var gallerySelectionCommandActions: GallerySelectionCommandActions? {
        guard store.selectedRoute.usesArtworkFeed, store.artworks.isEmpty == false else { return nil }
        let selectedWorks = selectedArtworks
        let selectedArtworkLinks = selectedWorks.compactMap { $0.pixivURL?.absoluteString }
        return GallerySelectionCommandActions(
            canSelectAll: store.artworks.isEmpty == false,
            canClear: artworkSelection.hasSelection,
            canCopyLinks: selectedArtworkLinks.isEmpty == false,
            canDownload: selectedWorks.isEmpty == false,
            canBatchBookmark: selectedWorks.isEmpty == false,
            selectAllVisible: {
                artworkSelection.selectAll(store.artworks.map(\.id))
                artworkSelection.isSelectionMode = true
            },
            clearSelection: {
                artworkSelection.clear()
            },
            copySelectedLinks: {
                copySelectedArtworkLinks(selectedArtworkLinks)
            },
            downloadSelected: {
                downloadSelectedArtworks(selectedWorks)
            },
            batchBookmarkSelected: {
                batchBookmarkCommandRequest = BatchBookmarkCommandRequest(
                    scope: .selectedWorks,
                    artworkIDs: selectedWorks.map(\.id)
                )
            }
        )
    }

    private var selectedArtworks: [PixivArtwork] {
        store.artworks.filter { artworkSelection.contains($0.id) }
    }

    private func copySelectedArtworkLinks(_ links: [String]) {
        guard links.isEmpty == false else { return }
        PasteboardWriter.copy(links.joined(separator: "\n"))
        actionMessage = String(format: L10n.copiedArtworkLinksFormat, links.count)
    }

    private func downloadSelectedArtworks(_ artworks: [PixivArtwork]) {
        guard artworks.isEmpty == false else { return }
        let queuedCount = store.enqueueDownloads(
            artworks,
            limit: min(max(artworks.count, 1), 100),
            preferOriginal: true
        )
        guard queuedCount > 0 else { return }
        actionMessage = String(format: L10n.queuedDownloadsFormat, queuedCount)
        openWindow(id: "main")
        store.select(.downloads)
    }
}

private struct CachedFeedStatusStrip: View {
    let restoration: FeedSnapshotRestoration
    let refresh: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.cachedFeed)
                        .font(.subheadline.weight(.semibold))
                    Text(statusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            } icon: {
                Image(systemName: "externaldrive.badge.icloud")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            Button {
                refresh()
            } label: {
                Label(L10n.refreshLiveFeed, systemImage: "arrow.clockwise")
            }
            .controlSize(.small)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(.quinary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(.secondary.opacity(0.14), lineWidth: 1)
        }
        .help(helpText)
    }

    private var statusText: String {
        let savedAtText = restoration.savedAt.formatted(date: .abbreviated, time: .shortened)
        return String(
            format: L10n.showingCachedFeedFormat,
            restoration.title,
            restoration.artworkCount,
            savedAtText
        )
    }

    private var helpText: String {
        [
            L10n.cachedFeedReadOnlyHint,
            restoration.errorDescription
        ]
        .joined(separator: " · ")
    }
}

private struct SignedOutView: View {
    @Bindable var store: KeiPixStore

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "sparkles.rectangle.stack")
                .font(.system(size: 56, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)

            VStack(spacing: 6) {
                Text(L10n.signedOutTitle)
                    .font(.title2.weight(.semibold))
                Text(L10n.signedOutSubtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 480)
            }

            HStack(spacing: 10) {
                Button {
                    store.activateGuestMode()
                } label: {
                    Label(L10n.guestAccount, systemImage: "sparkles.rectangle.stack")
                }

                Button {
                    store.isLoginPresented = true
                } label: {
                    Label(L10n.login, systemImage: "person.crop.circle.badge.plus")
                }
                .buttonStyle(.borderedProminent)

                Button {
                    store.isTokenLoginPresented = true
                } label: {
                    Label(L10n.importToken, systemImage: "key")
                }
            }
            .controlSize(.large)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
