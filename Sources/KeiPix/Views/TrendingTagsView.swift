import SwiftUI

struct TrendingTagsView: View {
    @Bindable var store: KeiPixStore
    @State private var tags: [PixivTrendingTag] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var actionMessage: String?

    var body: some View {
        Group {
            if store.session == nil {
                PixivSignedOutStateView(store: store)
            } else if isLoading {
                OS26LibraryLoadingView(title: L10n.loading, systemImage: "number")
            } else if tags.isEmpty {
                OS26LibraryUnavailableView(
                    title: L10n.noTrendingTags,
                    subtitle: errorMessage,
                    systemImage: "number"
                ) {
                    Button {
                        Task { await load() }
                    } label: {
                        Label(L10n.retry, systemImage: "arrow.clockwise")
                    }
                    .os26GlassButton(prominent: true)
                }
            } else {
                ScrollView {
                    TrendingTagMasonryLayout(spacing: 12) {
                        ForEach(tags) { tag in
                            // Use the artwork's reported aspect ratio as the
                            // single source of truth for layout. The previous
                            // implementation also accepted a post-load aspect
                            // override from `imageLoaded`, which re-ran the
                            // masonry pass every time a thumbnail decoded —
                            // making cards swap columns and visually overlap
                            // mid-flow. Sticking to one stable value rules
                            // out that whole class of glitches.
                            TrendingTagCard(
                                tag: tag,
                                showTranslatedName: store.showTranslatedTags,
                                showContentBadges: store.showContentBadges,
                                maskSensitivePreview: store.maskSensitivePreviews,
                                search: { search(tag) },
                                selectArtwork: { store.selectedArtwork = tag.artwork },
                                mute: { store.requestDangerAction(AppDangerAction(kind: .muteTag(tag.pixivTag))) },
                                copied: { copiedText in
                                    showActionMessage(String(format: L10n.copiedKeywordFormat, copiedText))
                                }
                            )
                            .layoutValue(
                                key: TrendingTagAspectRatioKey.self,
                                value: TrendingTagPresentation(tag: tag).aspectRatio
                            )
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 12)
                    .padding(.bottom, 18)
                }
                .scrollEdgeEffectStyle(.soft, for: .top)
            }
        }
        .platformPageHeader(
            title: L10n.trendingTags,
            status: trendingTagsStatusText,
            statusSystemImage: "number"
        )
        .platformPageNavigationChrome(title: L10n.trendingTags, status: trendingTagsStatusText)
        .overlay(alignment: .bottom) {
            VStack(spacing: 8) {
                if let actionMessage {
                    FloatingStatusBanner {
                        Text(actionMessage)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                if let errorMessage, tags.isEmpty == false {
                    FloatingStatusBanner {
                        Text(errorMessage)
                            .font(.callout)
                            .foregroundStyle(.red)
                            .textSelection(.enabled)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 14)
        }
        .animation(.snappy(duration: 0.18), value: actionMessage)
        .animation(.snappy(duration: 0.18), value: errorMessage)
        .task(id: store.routeRefreshGeneration) {
            await load()
        }
    }

    private var trendingTagsStatusText: String {
        guard store.session != nil else { return "" }
        return tags.count.formatted()
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

    private func showActionMessage(_ message: String) {
        actionMessage = message
        Task {
            try? await Task.sleep(for: .seconds(2.5))
            if actionMessage == message {
                actionMessage = nil
            }
        }
    }
}

private struct TrendingTagCard: View {
    let tag: PixivTrendingTag
    let showTranslatedName: Bool
    let showContentBadges: Bool
    let maskSensitivePreview: Bool
    let search: () -> Void
    let selectArtwork: () -> Void
    let mute: () -> Void
    let copied: (String) -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: search) {
            // ArtworkCardView solved the same "image bleeds past its
            // masonry frame" symptom by capturing the placed size via
            // GeometryReader and pinning the thumbnail to it. Without
            // an explicit height, `RemoteImageView`'s underlying
            // `Image.resizable().aspectRatio(contentMode: .fill)` is
            // flexible enough to exceed the proposed size and visually
            // overlap neighbouring cards in the column. We mirror that
            // pattern here so the rendered card never escapes its
            // layout frame.
            GeometryReader { proxy in
                cardContent(size: proxy.size)
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .compositingGroup()
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.white.opacity(isHovering ? 0.32 : 0), lineWidth: 1)
        }
        .shadow(color: .black.opacity(isHovering ? 0.16 : 0), radius: isHovering ? 12 : 0, y: isHovering ? 8 : 0)
        .animation(.snappy(duration: 0.16), value: isHovering)
        .keiPixHoverTracker { isHovering = $0 }
        .help(tagHelp)
        .contextMenu {
            Button(L10n.searchTag, action: search)
            Button(L10n.selectArtwork, action: selectArtwork)

            Divider()

            Button(L10n.copyTag) {
                PasteboardWriter.copy(tag.name)
                copied("#\(tag.name)")
            }

            if let translatedName {
                Button(L10n.copyTranslatedTag) {
                    PasteboardWriter.copy(translatedName)
                    copied(translatedName)
                }
            }

            Divider()

            Button(L10n.muteTag, action: mute)
        }
    }

    private func cardContent(size: CGSize) -> some View {
        ZStack(alignment: .bottomLeading) {
            // Black backstop matches the placed frame so the card has a
            // stable, opaque base even before the image arrives or when
            // it fails to load.
            Color.black
                .frame(width: size.width, height: size.height)

            RemoteImageView(
                url: tag.artwork.thumbnailURL,
                contentMode: .fill
            )
            .sensitiveArtworkPreviewMasked(
                maskSensitivePreview && tag.artwork.requiresScreenCaptureProtection,
                badges: tag.artwork.contentBadges
            )
            .frame(width: size.width, height: size.height)
            .clipped()

            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0), location: 0),
                    .init(color: .black.opacity(0.18), location: 0.48),
                    .init(color: .black.opacity(0.72), location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(width: size.width, height: size.height)
            .allowsHitTesting(false)

            if showContentBadges {
                ArtworkContentBadgesView(badges: tag.artwork.contentBadges, style: .overlay)
                    .padding(8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("#\(tag.name)")
                    .font(.headline.weight(.semibold))
                    .lineLimit(1)
                    .trendingTagTextChip()

                if let translatedName {
                    Text(translatedName)
                        .font(.caption)
                        .lineLimit(1)
                        .trendingTagTextChip(opacity: 0.34)
                }
            }
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.28), radius: 2, y: 1)
            .padding(8)
        }
        .frame(width: size.width, height: size.height)
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
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

private extension View {
    func trendingTagTextChip(opacity: Double = 0.42) -> some View {
        padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(.black.opacity(opacity), in: Capsule())
    }
}
