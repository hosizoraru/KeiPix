import SwiftUI
#if os(iOS)
import UIKit
#endif

struct ArtworkCoverCardChrome<Overlay: View, BottomContent: View>: View {
    let imageURL: URL?
    let contentBadges: [ArtworkContentBadge]
    var showContentBadges = true
    var maskSensitivePreview = false
    var gradientFraction: CGFloat = ArtworkCardDisplayStyle.regular.overlayFraction
    var imageHeight: CGFloat?
    @ViewBuilder var overlay: () -> Overlay
    @ViewBuilder var bottomContent: () -> BottomContent

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RemoteImageView(url: imageURL)
                .sensitiveArtworkPreviewMasked(maskSensitivePreview, badges: contentBadges)
                .frame(height: imageHeight)
                .frame(maxHeight: imageHeight == nil ? .infinity : nil)
                .frame(maxWidth: .infinity)
                .overlay(alignment: .bottom) {
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.68)],
                        startPoint: .center,
                        endPoint: .bottom
                    )
                    .frame(height: imageHeight.map { $0 * gradientFraction })
                }

            if showContentBadges {
                ArtworkContentBadgesView(badges: contentBadges, style: .overlay)
                    .padding(8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }

            overlay()

            bottomContent()
                .padding(10)
        }
        .frame(maxWidth: .infinity, maxHeight: imageHeight == nil ? .infinity : nil)
    }
}

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
    /// Own bookmark feeds already imply every visible artwork is bookmarked,
    /// so callers can hide the bookmark state badge there while keeping it in
    /// mixed feeds such as following, search, ranking, history, and creator
    /// pages where the state answers a real question.
    var showsBookmarkedStatusBadge = true
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
        if artwork.user.isFollowed { parts.append(L10n.following) }
        if artwork.isBookmarked { parts.append(L10n.bookmarked) }
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
        ArtworkCoverCardChrome(
            imageURL: artwork.feedPreviewURL(tier: feedPreviewTier) ?? artwork.thumbnailURL,
            contentBadges: artwork.contentBadges,
            showContentBadges: showContentBadges,
            maskSensitivePreview: shouldMaskSensitivePreview,
            gradientFraction: resolvedDisplayStyle.overlayFraction,
            imageHeight: height
        ) {
            if downloadState != .none {
                ArtworkDownloadStateBadge(state: downloadState)
                    .padding(8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            }
        } bottomContent: {
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

                if hasStatusBadges {
                    statusBadges
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
        }
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

    private var hasStatusBadges: Bool {
        artwork.user.isFollowed || showsBookmarkedStatusBadge && artwork.isBookmarked
    }

    private var statusBadges: some View {
        FlowLayout(spacing: statusBadgeStyle.spacing) {
            if artwork.user.isFollowed {
                artworkStatusBadge(
                    title: L10n.following,
                    systemImage: "person.crop.circle.badge.checkmark",
                    tint: .accentColor,
                    help: L10n.followingArtistEmphasizedHelp
                )
            }

            if showsBookmarkedStatusBadge && artwork.isBookmarked {
                artworkStatusBadge(
                    title: L10n.bookmarked,
                    systemImage: "bookmark.fill",
                    tint: .pink,
                    help: L10n.bookmarked
                )
            }
        }
    }

    private func artworkStatusBadge(title: String, systemImage: String, tint: Color, help: String) -> some View {
        HStack(spacing: statusBadgeStyle.spacing) {
            Image(systemName: systemImage)
                .font(statusBadgeStyle.iconFont)
                .symbolRenderingMode(.hierarchical)
            Text(title)
                .font(statusBadgeStyle.textFont)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, statusBadgeStyle.horizontalPadding)
        .padding(.vertical, statusBadgeStyle.verticalPadding)
        .background(tint.opacity(0.78), in: Capsule())
        .help(help)
        .accessibilityLabel(help)
    }

    private var statusBadgeStyle: ArtworkFollowBadgeStyle {
        if usesPhoneFollowBadge {
            return .phone
        }
        if isCompact || resolvedDisplayStyle == .wide {
            return .compact
        }
        return .regular
    }

    private var usesPhoneFollowBadge: Bool {
        #if os(iOS)
        UIDevice.current.userInterfaceIdiom == .phone
        #else
        false
        #endif
    }

    private var shouldMaskSensitivePreview: Bool {
        maskSensitivePreview && artwork.requiresScreenCaptureProtection
    }
}

private struct ArtworkFollowBadgeStyle {
    let textFont: Font
    let iconFont: Font
    let spacing: CGFloat
    let horizontalPadding: CGFloat
    let verticalPadding: CGFloat

    static let regular = ArtworkFollowBadgeStyle(
        textFont: .caption2.weight(.semibold),
        iconFont: .caption2.weight(.semibold),
        spacing: 4,
        horizontalPadding: 7,
        verticalPadding: 3
    )

    static let compact = ArtworkFollowBadgeStyle(
        textFont: .caption2.weight(.semibold),
        iconFont: .caption2.weight(.semibold),
        spacing: 3,
        horizontalPadding: 6,
        verticalPadding: 2
    )

    static let phone = ArtworkFollowBadgeStyle(
        textFont: .system(size: 10.5, weight: .semibold),
        iconFont: .system(size: 10.5, weight: .semibold),
        spacing: 3,
        horizontalPadding: 5,
        verticalPadding: 2
    )
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
