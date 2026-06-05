import SwiftUI

struct ArtworkCardView: View {
    let artwork: PixivArtwork
    let isSelected: Bool
    let isCompact: Bool
    var showContentBadges = true
    var maskSensitivePreview = false
    var downloadState: ArtworkDownloadArtworkState = .none
    var displayStyle: ArtworkCardDisplayStyle = .regular
    var preferredHeight: CGFloat? = nil
    var fillsAvailableHeight = false
    /// Feed preview tier — controls which `image_urls` rung the
    /// thumbnail fetches. Defaults to `.medium` so legacy call sites
    /// keep their previous behaviour without code changes; the gallery
    /// surfaces forward `KeiPixStore.feedPreviewImageQualityTier`.
    var feedPreviewTier: ArtworkImageQualityTier = .medium
    var downloadedFileURL: URL? = nil
    var isScrollPerformanceOptimized = false
    /// When true and the artwork's author is followed, the card draws a
    /// thicker accent-tinted border so the user can spot following-artist
    /// works inside mixed feeds (search, ranking, recommendation). Mirrors
    /// Pixes' `emphasizeArtworksFromFollowingArtists` preference. Default
    /// `false` so legacy call sites stay untouched; the gallery wires this
    /// from `KeiPixStore.emphasizeFollowingArtists`.
    var emphasizeFollowing = false
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            if fillsAvailableHeight && isScrollPerformanceOptimized == false {
                GeometryReader { proxy in
                    cardContent(height: proxy.size.height)
                }
            } else {
                cardContent(height: fillsAvailableHeight ? nil : renderedImageHeight)
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, maxHeight: fillsAvailableHeight ? .infinity : nil)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(borderColor, lineWidth: borderLineWidth)
        }
        .modifier(
            ArtworkCardMotionModifier(
                isEnabled: isScrollPerformanceOptimized == false,
                isHovering: isHovering,
                isSelected: isSelected,
                onHoverChange: { isHovering = $0 }
            )
        )
        .modifier(
            ArtworkCardInteractionModifier(
                isEnabled: isScrollPerformanceOptimized == false,
                dragContent: dragContent,
                accessibilityDescription: accessibilityDescription
            )
        )
    }

    private var accessibilityDescription: String {
        var parts = [artwork.title, artwork.user.name]
        if artwork.isBookmarked { parts.append(L10n.bookmark) }
        if artwork.isAI { parts.append(L10n.aiGenerated) }
        return parts.joined(separator: ", ")
    }

    /// Selection wins over follow-emphasis (selection is a transient user
    /// action, follow-emphasis is a steady-state hint). Hover stays as the
    /// faint secondary tint we had before.
    private var borderColor: Color {
        if isSelected {
            return .accentColor
        }
        if shouldEmphasizeFollowing {
            return .accentColor.opacity(isHovering ? 0.78 : 0.6)
        }
        return .secondary.opacity(isHovering ? 0.45 : 0.16)
    }

    private var borderLineWidth: CGFloat {
        if isSelected {
            return 2
        }
        return shouldEmphasizeFollowing ? 1.5 : 1
    }

    private var shouldEmphasizeFollowing: Bool {
        emphasizeFollowing && artwork.user.isFollowed
    }

    /// Canonical Pixiv URL for this artwork. We always rebuild the URL
    /// from the artwork ID (rather than trusting whatever
    /// `artwork.pixivURL` returns) so a stale or test-fixture artwork
    /// still drags as a valid `.webloc` bookmark.
    private var dragContent: URL {
        downloadedFileURL ?? artworkPixivURL
    }

    private var artworkPixivURL: URL {
        artwork.pixivURL ?? URL(string: "https://www.pixiv.net/artworks/\(artwork.id)")!
    }

    private func cardContent(height: CGFloat?) -> some View {
        ZStack(alignment: .bottomLeading) {
            RemoteImageView(url: artwork.feedPreviewURL(tier: feedPreviewTier) ?? artwork.thumbnailURL)
                .sensitiveArtworkPreviewMasked(shouldMaskSensitivePreview, badges: artwork.contentBadges)
                .frame(height: height)
                .frame(maxHeight: height == nil ? .infinity : nil)
                .frame(maxWidth: .infinity)
                .overlay(alignment: .bottom) {
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.68)],
                        startPoint: .center,
                        endPoint: .bottom
                    )
                    .frame(height: height.map { $0 * resolvedDisplayStyle.overlayFraction })
                }

            if showContentBadges {
                ArtworkContentBadgesView(badges: artwork.contentBadges, style: .overlay)
                    .padding(8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }

            if downloadState != .none {
                ArtworkDownloadStateBadge(state: downloadState)
                    .padding(8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            }

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(artwork.title)
                        .font(isCompact ? .caption.weight(.semibold) : .subheadline.weight(.semibold))
                        .lineLimit(resolvedDisplayStyle.titleLineLimit)
                        .minimumScaleFactor(0.82)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 6)
                    if artwork.pageCount > 1 {
                        pageCountBadge
                    }
                }

                Text(artwork.user.name)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.78))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                if shouldEmphasizeFollowing {
                    Label(L10n.following, systemImage: "checkmark.seal.fill")
                        .font(.caption2.weight(.semibold))
                        .labelStyle(.titleAndIcon)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.accentColor.opacity(0.78), in: Capsule())
                        .help(L10n.followingArtistEmphasizedHelp)
                }

                HStack(spacing: 10) {
                    Label(artwork.totalView.formatted(), systemImage: "eye")
                        .lineLimit(1)
                    Label(artwork.totalBookmarks.formatted(), systemImage: artwork.isBookmarked ? "bookmark.fill" : "bookmark")
                        .lineLimit(1)
                }
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.74))
                .labelStyle(.titleAndIcon)
                .minimumScaleFactor(0.76)
            }
            .padding(10)
        }
        .frame(maxWidth: .infinity, maxHeight: height == nil ? .infinity : nil)
    }

    @ViewBuilder
    private var pageCountBadge: some View {
        let badge = Text(L10n.pageCountShort(artwork.pageCount))
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)

        if isScrollPerformanceOptimized {
            badge
                .foregroundStyle(.white)
                .background(.black.opacity(0.42), in: Capsule())
        } else {
            badge
                .keiGlass(10)
        }
    }

    private var renderedImageHeight: CGFloat {
        preferredHeight ?? (isCompact ? 152 : 222)
    }

    private var resolvedDisplayStyle: ArtworkCardDisplayStyle {
        isCompact ? .compact : displayStyle
    }

    private var shouldMaskSensitivePreview: Bool {
        maskSensitivePreview && artwork.requiresScreenCaptureProtection
    }
}

private struct ArtworkDownloadStateBadge: View {
    let state: ArtworkDownloadArtworkState

    var body: some View {
        Label(state.shortTitle, systemImage: state.systemImage)
            .font(.caption2.weight(.bold))
            .labelStyle(.titleAndIcon)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .foregroundStyle(.white)
            .background(tint.opacity(0.78), in: Capsule())
            .help(state.title)
    }

    private var tint: Color {
        switch state {
        case .none:
            .secondary
        case .queued:
            .secondary
        case .downloading:
            .blue
        case .downloaded:
            .green
        case .failed:
            .orange
        }
    }
}

private struct ArtworkCardMotionModifier: ViewModifier {
    let isEnabled: Bool
    let isHovering: Bool
    let isSelected: Bool
    let onHoverChange: (Bool) -> Void

    @ViewBuilder
    func body(content: Content) -> some View {
        if isEnabled {
            content
                .shadow(
                    color: .black.opacity(isHovering ? 0.18 : 0.08),
                    radius: isHovering ? 12 : 5,
                    y: isHovering ? 8 : 3
                )
                .scaleEffect(isHovering ? 1.012 : 1)
                .animation(.snappy(duration: 0.16), value: isHovering)
                .animation(.snappy(duration: 0.16), value: isSelected)
                .keiPixHoverTracker(onChange: onHoverChange)
        } else {
            content
                .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }
}

private struct ArtworkCardInteractionModifier: ViewModifier {
    let isEnabled: Bool
    let dragContent: URL
    let accessibilityDescription: String

    @ViewBuilder
    func body(content: Content) -> some View {
        if isEnabled {
            // Drag the artwork's Pixiv URL out of the card. macOS turns a
            // URL drop on Finder into a `.webloc` bookmark, while drops
            // into Safari, Notes, or Messages paste the link verbatim —
            // matches the affordance Pixes/Pixez expose through their
            // "Copy link" action but without the round-trip through the
            // pasteboard. Falls back to the canonical
            // `https://www.pixiv.net/artworks/<id>` URL if the artwork
            // payload didn't carry one.
            content
                .draggable(dragContent)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(accessibilityDescription)
                .accessibilityHint(L10n.artworkCardHint)
        } else {
            content
        }
    }
}
