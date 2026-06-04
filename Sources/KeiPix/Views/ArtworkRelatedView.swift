import SwiftUI

struct ArtworkRelatedView: View {
    let artwork: PixivArtwork
    @Bindable var store: KeiPixStore
    @Binding var isExpanded: Bool
    var visualQAResponse: PixivFeedResponse?

    @State private var hasLoaded = false
    @State private var relatedArtworks: [PixivArtwork] = []
    @State private var nextURL: URL?
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var errorMessage: String?
    @State private var statusMessage: String?
    @State private var pendingDangerAction: AppDangerAction?

    private let columns = [
        GridItem(.adaptive(minimum: 128, maximum: 184), spacing: 12)
    ]

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 14) {
                if isLoading {
                    OS26InlineLoadingView(
                        title: L10n.loading,
                        systemImage: "sparkles.rectangle.stack",
                        minHeight: 150
                    )
                } else if relatedArtworks.isEmpty {
                    OS26InlineUnavailableView(
                        title: L10n.noRelatedArtworks,
                        systemImage: "sparkles.rectangle.stack",
                        minHeight: 150
                    )
                } else {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(relatedArtworks) { related in
                            ArtworkCardView(
                                artwork: related,
                                isSelected: store.selectedArtwork?.id == related.id,
                                isCompact: true,
                                showContentBadges: store.showContentBadges,
                                maskSensitivePreview: store.maskSensitivePreviews,
                                preferredHeight: 156,
                                feedPreviewTier: store.feedPreviewImageQualityTier,
                                emphasizeFollowing: store.emphasizeFollowingArtists
                            ) {
                                store.selectedArtwork = related
                            }
                            .contextMenu {
                                Button(related.isBookmarked ? L10n.removeBookmark : L10n.bookmark) {
                                    if related.isBookmarked {
                                        pendingDangerAction = AppDangerAction(kind: .removeBookmark(related))
                                    } else {
                                        Task { await bookmark(related) }
                                    }
                                }
                                Button(L10n.download) {
                                    store.enqueueDownload(related)
                                    showStatus(String(format: L10n.queuedDownloadsFormat, 1))
                                }
                                Divider()
                                Button(L10n.muteArtwork) {
                                    pendingDangerAction = AppDangerAction(kind: .muteArtwork(related))
                                }
                                Button(L10n.muteCreator) {
                                    pendingDangerAction = AppDangerAction(kind: .muteCreator(related.user))
                                }
                                if related.tags.isEmpty == false {
                                    Menu(L10n.muteTag) {
                                        ForEach(related.tags.prefix(12), id: \.self) { tag in
                                            Button("#\(tag.name)") {
                                                pendingDangerAction = AppDangerAction(kind: .muteTag(tag))
                                            }
                                        }
                                    }
                                }
                                if let url = related.pixivURL {
                                    Link(L10n.openInPixiv, destination: url)
                                }
                            }
                        }
                    }
                }

                if let statusMessage {
                    Label(statusMessage, systemImage: "checkmark.circle")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .textSelection(.enabled)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .glassEffect(.regular, in: Capsule(style: .continuous))
                }

                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle")
                        .font(.callout)
                        .foregroundStyle(.red)
                        .lineLimit(3)
                        .textSelection(.enabled)
                }

                if nextURL != nil {
                    OS26LoadMoreButton(
                        title: L10n.loadMoreRelatedArtworks,
                        loadingTitle: L10n.loading,
                        systemImage: "ellipsis.circle",
                        isLoading: isLoadingMore,
                        minHeight: 96
                    ) {
                        Task { await loadMore() }
                    }
                }
            }
            .padding(.top, 10)
        } label: {
            ArtworkInspectorSectionHeader(
                title: L10n.relatedArtworks,
                subtitle: headerSubtitle,
                systemImage: "sparkles.rectangle.stack"
            )
            .contentShape(Rectangle())
        }
        .disclosureGroupStyle(.automatic)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .keiGlass(18)
        .task(id: isExpanded) {
            guard isExpanded, hasLoaded == false else { return }
            await loadInitial()
        }
        .confirmationDialog(
            pendingDangerAction?.title ?? L10n.moreActions,
            isPresented: dangerActionBinding,
            titleVisibility: .visible
        ) {
            if let pendingDangerAction {
                Button(pendingDangerAction.title, role: .destructive) {
                    Task { await performDangerAction(pendingDangerAction) }
                }
            }
            Button(L10n.cancel, role: .cancel) {}
        } message: {
            if let pendingDangerAction {
                Text(pendingDangerAction.confirmationMessage)
            }
        }
    }

    private var headerSubtitle: String? {
        relatedArtworks.isEmpty ? nil : relatedArtworks.count.formatted()
    }

    private func loadInitial() async {
        isLoading = true
        errorMessage = nil
        defer {
            isLoading = false
            hasLoaded = true
        }

        do {
            let response: PixivFeedResponse
            if let visualQAResponse {
                response = visualQAResponse
            } else {
                response = try await store.relatedArtworks(for: artwork)
            }
            relatedArtworks = response.illusts
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
            let response = try await store.nextRelatedArtworks(nextURL)
            relatedArtworks.append(contentsOf: response.illusts)
            self.nextURL = response.nextURL
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func bookmark(_ related: PixivArtwork) async {
        do {
            try await store.saveBookmark(
                related,
                restrict: store.defaultBookmarkRestrict,
                tags: store.automaticBookmarkTags(for: related)
            )
            updateRelatedArtwork(related.id) { $0.isBookmarked = true }
            showStatus(String(format: L10n.savedBookmarkFormat, related.title))
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func performDangerAction(_ action: AppDangerAction) async {
        defer { pendingDangerAction = nil }
        let succeeded = await store.performDangerAction(action)
        guard succeeded else {
            errorMessage = store.errorMessage
            return
        }

        switch action.kind {
        case .removeBookmark(let artwork):
            updateRelatedArtwork(artwork.id) { $0.isBookmarked = false }
            showStatus(String(format: L10n.removedBookmarkFormat, artwork.title))
        case .muteArtwork(let artwork):
            relatedArtworks.removeAll { $0.id == artwork.id }
            showStatus(String(format: L10n.mutedArtworkFormat, artwork.title))
        case .muteCreator(let user):
            relatedArtworks.removeAll { $0.user.id == user.id }
            showStatus(String(format: L10n.mutedCreatorFormat, user.name))
        case .muteTag(let tag):
            relatedArtworks.removeAll { artwork in
                artwork.tags.contains { $0.name.localizedCaseInsensitiveCompare(tag.name) == .orderedSame }
            }
            showStatus(String(format: L10n.mutedTagFormat, tag.name))
        case .unfollowCreator:
            break
        }
    }

    private var dangerActionBinding: Binding<Bool> {
        Binding {
            pendingDangerAction != nil
        } set: { value in
            if value == false {
                pendingDangerAction = nil
            }
        }
    }

    private func updateRelatedArtwork(_ id: Int, update: (inout PixivArtwork) -> Void) {
        for index in relatedArtworks.indices where relatedArtworks[index].id == id {
            update(&relatedArtworks[index])
        }
    }

    private func showStatus(_ message: String) {
        statusMessage = message
        Task {
            try? await Task.sleep(for: .seconds(2.5))
            if statusMessage == message {
                statusMessage = nil
            }
        }
    }
}
