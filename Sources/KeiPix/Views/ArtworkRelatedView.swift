import SwiftUI

struct ArtworkRelatedView: View {
    let artwork: PixivArtwork
    @Bindable var store: KeiPixStore

    @State private var isExpanded = false
    @State private var hasLoaded = false
    @State private var relatedArtworks: [PixivArtwork] = []
    @State private var nextURL: URL?
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var errorMessage: String?
    @State private var statusMessage: String?
    @State private var pendingDangerAction: AppDangerAction?

    private let columns = [
        GridItem(.adaptive(minimum: 140, maximum: 210), spacing: 12)
    ]

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 14) {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 20)
                } else if relatedArtworks.isEmpty {
                    ContentUnavailableView(L10n.noRelatedArtworks, systemImage: "sparkles.rectangle.stack")
                        .frame(maxWidth: .infinity)
                } else {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(relatedArtworks) { related in
                            ArtworkCardView(
                                artwork: related,
                                isSelected: store.selectedArtwork?.id == related.id,
                                isCompact: true,
                                showContentBadges: store.showContentBadges,
                                preferredHeight: 156
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
                    Text(statusMessage)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.callout)
                        .foregroundStyle(.red)
                        .textSelection(.enabled)
                }

                if nextURL != nil {
                    Button {
                        Task { await loadMore() }
                    } label: {
                        if isLoadingMore {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Label(L10n.loadMoreRelatedArtworks, systemImage: "ellipsis.circle")
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(isLoadingMore)
                }
            }
            .padding(.top, 12)
        } label: {
            Label(title, systemImage: "sparkles.rectangle.stack")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .disclosureGroupStyle(.automatic)
        .padding(14)
        .keiPanel(16)
        .onChange(of: isExpanded) { _, value in
            guard value, hasLoaded == false else { return }
            Task { await loadInitial() }
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

    private var title: String {
        relatedArtworks.isEmpty
            ? L10n.relatedArtworks
            : "\(L10n.relatedArtworks) (\(relatedArtworks.count.formatted()))"
    }

    private func loadInitial() async {
        isLoading = true
        errorMessage = nil
        defer {
            isLoading = false
            hasLoaded = true
        }

        do {
            let response = try await store.relatedArtworks(for: artwork)
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
        case .muteArtwork(let artwork):
            relatedArtworks.removeAll { $0.id == artwork.id }
        case .muteCreator(let user):
            relatedArtworks.removeAll { $0.user.id == user.id }
        case .muteTag(let tag):
            relatedArtworks.removeAll { artwork in
                artwork.tags.contains { $0.name.localizedCaseInsensitiveCompare(tag.name) == .orderedSame }
            }
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
