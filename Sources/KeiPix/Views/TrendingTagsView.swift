import SwiftUI

struct TrendingTagsView: View {
    @Bindable var store: KeiPixStore
    @State private var tags: [PixivTrendingTag] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let columns = [
        GridItem(.adaptive(minimum: 168, maximum: 224), spacing: 12)
    ]
    private let cardHeight: CGFloat = 150

    var body: some View {
        Group {
            if store.session == nil {
                EmptyStateView(title: L10n.signedOutTitle, subtitle: L10n.signedOutSubtitle, systemImage: "person.crop.circle.badge.exclamationmark")
            } else if isLoading {
                ProgressView(L10n.loading)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if tags.isEmpty {
                ContentUnavailableView(L10n.noTrendingTags, systemImage: "number")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        header

                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(tags) { tag in
                                TrendingTagCard(
                                    tag: tag,
                                    cardHeight: cardHeight,
                                    showTranslatedName: store.showTranslatedTags,
                                    showContentBadges: store.showContentBadges,
                                    search: { search(tag) },
                                    selectArtwork: { store.selectedArtwork = tag.artwork },
                                    mute: { store.muteTag(tag.pixivTag) }
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 8)
                    .padding(.bottom, 20)
                }
                .scrollEdgeEffectStyle(.soft, for: .top)
            }
        }
        .navigationTitle(L10n.trendingTags)
        .safeAreaInset(edge: .bottom) {
            if let errorMessage {
                Text(errorMessage)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
                    .padding(12)
                    .frame(maxWidth: .infinity)
                    .background(.bar)
            }
        }
        .task(id: store.routeRefreshGeneration) {
            await load()
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Label("\(tags.count.formatted()) \(L10n.results)", systemImage: "number")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.quaternary, in: Capsule())
            Spacer()
        }
    }

    private func load() async {
        guard store.session != nil else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            tags = try await store.trendingTags()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func search(_ tag: PixivTrendingTag) {
        store.searchText = tag.name
        Task { await store.runSearch() }
    }
}

private struct TrendingTagCard: View {
    let tag: PixivTrendingTag
    let cardHeight: CGFloat
    let showTranslatedName: Bool
    let showContentBadges: Bool
    let search: () -> Void
    let selectArtwork: () -> Void
    let mute: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: search) {
            ZStack(alignment: .bottomLeading) {
                RemoteImageView(url: tag.artwork.thumbnailURL, contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .frame(height: cardHeight)
                    .clipped()
                    .overlay(alignment: .bottom) {
                        LinearGradient(
                            colors: [.clear, .black.opacity(0.72)],
                            startPoint: .center,
                            endPoint: .bottom
                        )
                        .frame(height: 96)
                    }

                if showContentBadges {
                    ArtworkContentBadgesView(badges: tag.artwork.contentBadges, style: .overlay)
                        .padding(8)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("#\(tag.name)")
                        .font(.headline.weight(.semibold))
                        .lineLimit(1)

                    if let translatedName {
                        Text(translatedName)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.82))
                            .lineLimit(1)
                    }
                }
                .foregroundStyle(.white)
                .padding(10)
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .frame(height: cardHeight)
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.secondary.opacity(isHovering ? 0.42 : 0.14), lineWidth: 1)
        }
        .shadow(color: .black.opacity(isHovering ? 0.18 : 0.08), radius: isHovering ? 12 : 5, y: isHovering ? 8 : 3)
        .scaleEffect(isHovering ? 1.012 : 1)
        .animation(.snappy(duration: 0.16), value: isHovering)
        .onHover { isHovering = $0 }
        .help(tagHelp)
        .contextMenu {
            Button(L10n.searchTag, action: search)
            Button(L10n.selectArtwork, action: selectArtwork)

            Divider()

            Button(L10n.copyTag) {
                PasteboardWriter.copy(tag.name)
            }

            if let translatedName {
                Button(L10n.copyTranslatedTag) {
                    PasteboardWriter.copy(translatedName)
                }
            }

            Divider()

            Button(L10n.muteTag, action: mute)
        }
    }

    private var translatedName: String? {
        guard showTranslatedName,
              let translatedName = tag.translatedName?.trimmingCharacters(in: .whitespacesAndNewlines),
              translatedName.isEmpty == false,
              translatedName.localizedCaseInsensitiveCompare(tag.name) != .orderedSame else {
            return nil
        }
        return translatedName
    }

    private var tagHelp: String {
        if let translatedName {
            return "#\(tag.name) / \(translatedName)"
        }
        return "#\(tag.name)"
    }
}
