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
                                    Task { await store.toggleBookmark(related) }
                                }
                                Button(L10n.download) {
                                    store.downloads.enqueue(related, preferOriginal: true)
                                }
                                Divider()
                                Button(L10n.muteArtwork) {
                                    store.muteArtwork(related)
                                }
                                Button(L10n.muteCreator) {
                                    store.muteUser(related.user)
                                }
                                if related.tags.isEmpty == false {
                                    Menu(L10n.muteTag) {
                                        ForEach(related.tags.prefix(12), id: \.self) { tag in
                                            Button("#\(tag.name)") {
                                                store.muteTag(tag)
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
}
