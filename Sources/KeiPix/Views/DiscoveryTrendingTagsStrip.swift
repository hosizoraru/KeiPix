import SwiftUI

/// Inline trending-tags carousel rendered directly on the Discovery
/// dashboard.
///
/// The dedicated `TrendingTagsView` route still owns the masonry-style
/// browse experience. This strip is the "急上昇タグ" preview Pixiv Web
/// shows on its discovery surface — a glanceable horizontal rail that
/// links into the full route. Tapping a tile drops the user straight
/// into the matching search; tapping "View all" jumps to the full
/// trending-tags route.
///
/// Behaviour:
/// - Loads on appear via `store.trendingTags()` and caches into local
///   state. The full route owns its own loading lifecycle, so this strip
///   does not share its cache; the API request is cheap and the data is
///   intentionally a snapshot of "what's trending right now."
/// - Surfaces only the first 12 tags. The point is to nudge the user
///   into the full route, not replicate it.
/// - Skips rendering if the user is signed-out or the API returned no
///   tags after a successful load — keeps the dashboard from showing an
///   empty rail.
struct DiscoveryTrendingTagsStrip: View {
    @Bindable var store: KeiPixStore

    @State private var tags: [PixivTrendingTag] = []
    @State private var isLoading = false
    @State private var loadFailed = false

    /// Cap the rail at 12 tags. Pixiv Web's discovery rail surfaces a
    /// similar count and the dashboard already feels dense; more than
    /// this slows down the scrolling pass without adding utility.
    private static let previewLimit = 12

    var body: some View {
        // Hide the section entirely when there's nothing to show. An
        // empty rail next to populated route cards reads as a broken
        // surface.
        if shouldHideSection {
            EmptyView()
        } else {
            section
        }
    }

    private var shouldHideSection: Bool {
        store.session == nil
            || (loadFailed && tags.isEmpty)
            || (isLoading == false && tags.isEmpty)
    }

    private var section: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            if isLoading && tags.isEmpty {
                ProgressView()
                    .controlSize(.small)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 6)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 10) {
                        ForEach(tags.prefix(Self.previewLimit)) { tag in
                            DiscoveryTrendingTagChip(
                                tag: tag,
                                showTranslatedName: store.showTranslatedTags,
                                showContentBadges: store.showContentBadges,
                                maskSensitivePreview: store.maskSensitivePreviews
                            ) {
                                searchTag(tag)
                            }
                        }
                    }
                    .padding(.horizontal, 1) // keep border strokes inside the clip
                }
            }
        }
        .task(id: store.session?.user.id) {
            await load()
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Label(L10n.trendingTags, systemImage: "number")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)

            Spacer(minLength: 0)

            Button {
                store.select(.trendingTags)
            } label: {
                Label(L10n.viewAll, systemImage: "chevron.right")
                    .labelStyle(.titleAndIcon)
                    .font(.callout)
            }
            .buttonStyle(.borderless)
            .controlSize(.small)
        }
    }

    private func load() async {
        guard store.session != nil else {
            tags = []
            return
        }
        isLoading = true
        loadFailed = false
        defer { isLoading = false }

        do {
            tags = try await store.trendingTags()
        } catch {
            // Silent fall-back — the dashboard rail is a glanceable
            // preview, not a primary surface. The full route still
            // surfaces errors loudly.
            loadFailed = true
        }
    }

    private func searchTag(_ tag: PixivTrendingTag) {
        store.searchText = tag.name
        store.select(.search)
        Task { await store.runSearch() }
    }
}

/// Single tile in the discovery trending-tags rail. A scaled-down
/// cousin of `TrendingTagCard` from `TrendingTagsView.swift` — same
/// visual language (artwork backstop, gradient overlay, tag chip),
/// pinned to a fixed 168×112 size so the rail's row reads as a stable
/// horizontal strip instead of a masonry of varying heights.
private struct DiscoveryTrendingTagChip: View {
    let tag: PixivTrendingTag
    let showTranslatedName: Bool
    let showContentBadges: Bool
    let maskSensitivePreview: Bool
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottomLeading) {
                Color.black

                RemoteImageView(
                    url: tag.artwork.thumbnailURL,
                    contentMode: .fill
                )
                .sensitiveArtworkPreviewMasked(
                    maskSensitivePreview && tag.artwork.requiresScreenCaptureProtection,
                    badges: tag.artwork.contentBadges
                )

                LinearGradient(
                    stops: [
                        .init(color: .black.opacity(0), location: 0),
                        .init(color: .black.opacity(0.18), location: 0.45),
                        .init(color: .black.opacity(0.74), location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .allowsHitTesting(false)

                if showContentBadges {
                    ArtworkContentBadgesView(badges: tag.artwork.contentBadges, style: .overlay)
                        .padding(6)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("#\(tag.name)")
                        .font(.callout.weight(.semibold))
                        .lineLimit(1)
                    if let translatedName {
                        Text(translatedName)
                            .font(.caption2)
                            .lineLimit(1)
                            .foregroundStyle(.white.opacity(0.85))
                    }
                }
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.32), radius: 2, y: 1)
                .padding(8)
            }
            .frame(width: 168, height: 112)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.white.opacity(isHovering ? 0.32 : 0), lineWidth: 1)
        }
        .shadow(color: .black.opacity(isHovering ? 0.18 : 0), radius: isHovering ? 10 : 0, y: isHovering ? 6 : 0)
        .animation(.snappy(duration: 0.16), value: isHovering)
        .keiPixHoverTracker { isHovering = $0 }
        .help(tagHelp)
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
