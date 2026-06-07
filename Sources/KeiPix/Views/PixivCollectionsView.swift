import SwiftUI

struct PixivCollectionsView: View {
    @Bindable var store: KeiPixStore
    @State private var actionMessage: String?

    var body: some View {
        Group {
            if store.session == nil {
                PixivSignedOutStateView(store: store)
            } else if store.isLoadingPixivCollections, store.pixivCollections.isEmpty {
                OS26LibraryLoadingView(title: L10n.loading, systemImage: "rectangle.stack.badge.person.crop")
            } else if store.pixivCollections.isEmpty {
                emptyState
            } else {
                content
            }
        }
        .task(id: store.routeRefreshGeneration) {
            await store.refreshPixivCollections()
        }
        .platformPageNavigationChrome(title: L10n.pixivCollections, status: statusText)
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
        .task(id: actionMessage) {
            await dismissActionMessageIfNeeded(actionMessage)
        }
    }

    private var content: some View {
        VStack(spacing: 0) {
            header

            NativeAdaptiveGridCollectionView(
                items: store.pixivCollections,
                layout: gridLayout
            ) { collection in
                AnyView(
                    PixivCollectionCard(collection: collection) {
                        Task { await store.openPixivCollection(collection) }
                    }
                )
            }
            .nativeBottomTabContentSurface()
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Label(L10n.pixivCollections, systemImage: "rectangle.stack.badge.person.crop")
                .font(.headline.weight(.semibold))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            OS26LibraryActionRail {
                Button {
                    Task { await refresh(showFeedback: true) }
                } label: {
                    Label(L10n.refresh, systemImage: "arrow.clockwise")
                }
                .os26GlassIconButton()
                .help(L10n.refresh)
                .accessibilityLabel(L10n.refresh)

                Button {
                    Task {
                        let message = await store.openPixivLinkFromClipboard()
                        actionMessage = message
                    }
                } label: {
                    Label(L10n.openPixivLinkFromClipboard, systemImage: "doc.on.clipboard")
                }
                .os26GlassIconButton()
                .help(L10n.openPixivLinkFromClipboard)
                .accessibilityLabel(L10n.openPixivLinkFromClipboard)

                if let webURL = ownCollectionsWebURL {
                    Link(destination: webURL) {
                        Label(L10n.openPixivWebCollections, systemImage: "safari")
                    }
                    .os26GlassIconButton()
                    .help(L10n.openPixivWebCollections)
                    .accessibilityLabel(L10n.openPixivWebCollections)
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .platformGlassControlBar(verticalPadding: 5, topPadding: 0, bottomPadding: 6)
    }

    private var emptyState: some View {
        OS26LibraryUnavailableView(
            title: L10n.noPixivCollections,
            subtitle: emptyStateSubtitle,
            systemImage: "rectangle.stack.badge.person.crop"
        ) {
            HStack(spacing: 8) {
                Button {
                    Task { await refresh(showFeedback: true) }
                } label: {
                    Label(L10n.refresh, systemImage: "arrow.clockwise")
                }
                .os26GlassButton(prominent: true)

                Button {
                    Task {
                        let message = await store.openPixivLinkFromClipboard()
                        actionMessage = message
                    }
                } label: {
                    Label(L10n.openPixivLinkFromClipboard, systemImage: "doc.on.clipboard")
                }
                .os26GlassButton()

                if let webURL = ownCollectionsWebURL {
                    Link(destination: webURL) {
                        Label(L10n.openPixivWebCollections, systemImage: "safari")
                    }
                    .os26GlassButton()
                }
            }
            .controlSize(.regular)
        }
    }

    private var gridLayout: NativeAdaptiveGridCollectionLayout {
        NativeAdaptiveGridCollectionLayout(
            minimumItemWidth: 220,
            maximumItemWidth: 320,
            itemHeight: 292,
            spacing: 14,
            sectionInsets: EdgeInsets(top: 16, leading: 18, bottom: 26, trailing: 18)
        )
    }

    private var ownCollectionsWebURL: URL? {
        guard let userID = store.session?.user.id else { return nil }
        return PixivWebURLBuilder.userBookmarkCollectionsURL(userID: userID)
    }

    private var statusText: String {
        if store.isLoadingPixivCollections {
            return L10n.loading
        }
        if store.pixivCollections.isEmpty {
            return L10n.noStoredItems
        }
        return String(format: L10n.itemCountFormat, store.pixivCollections.count)
    }

    private var emptyStateSubtitle: String {
        store.pixivCollectionErrorMessage ?? L10n.pixivCollectionsEmptyHint
    }

    private func refresh(showFeedback: Bool) async {
        await store.refreshPixivCollections()
        if showFeedback, store.pixivCollectionErrorMessage == nil {
            actionMessage = String(format: L10n.refreshedPixivCollectionsFormat, store.pixivCollections.count)
        }
    }

    private func dismissActionMessageIfNeeded(_ message: String?) async {
        guard let message else { return }
        try? await Task.sleep(for: .seconds(2))
        if actionMessage == message {
            actionMessage = nil
        }
    }
}

private struct PixivCollectionCard: View {
    let collection: PixivCollectionDetail
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            VStack(alignment: .leading, spacing: 8) {
                collectionThumbnail

                VStack(alignment: .leading, spacing: 4) {
                    Text(collection.title.isEmpty ? L10n.pixivCollection : collection.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(2)

                    Text(collection.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    if collection.tags.isEmpty == false {
                        Text(collection.tags.prefix(3).map { "#\($0.name)" }.joined(separator: " "))
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal, 4)
            }
            .padding(10)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .keiInteractiveGlass(18)
        .contextMenu {
            if let url = collection.pixivURL {
                Link(L10n.openInPixiv, destination: url)
                Button(L10n.copyLink) {
                    PasteboardWriter.copy(url.absoluteString)
                }
            }
        }
        .accessibilityLabel(collection.title.isEmpty ? L10n.pixivCollection : collection.title)
    }

    @ViewBuilder
    private var collectionThumbnail: some View {
        if let url = collection.thumbnailImageURL {
            RemoteImageView(url: url, contentMode: .fill)
                .frame(height: 168)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        } else if let artwork = collection.artworks.first {
            RemoteImageView(url: artwork.thumbnailURL, contentMode: .fill)
                .frame(height: 168)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        } else {
            ZStack {
                Image(systemName: "rectangle.stack")
                    .font(.title.weight(.semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 168)
            .background(.quinary, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }
}
