import SwiftUI

/// Creator card used by the recommended / search / following / pinned
/// creator surfaces.
///
/// The redesign tightens three things at once:
///
/// 1. **High-frequency actions are visible.** Pin, Open in Pixiv, Copy
///    Link are the actions users reach for most often when triaging a
///    creator they want to keep tabs on or share — promoting them to a
///    standing chip rail mirrors the same `UserProfileSheetHeader`
///    treatment we landed for the profile sheet, and matches Apple's
///    HIG guidance about routine, reversible operations belonging on
///    the surface, not buried in a menu.
///
/// 2. **The preview strip uses the available width.** The thumbnails
///    used to be pinned at 132 pt tall regardless of card width, which
///    left wide cards with a stubby image rail. The new strip is built
///    inside a `GeometryReader` so each thumbnail's width and height
///    track the card's actual placed size — three thumbnails fill the
///    card edge to edge with 8 pt gutters, no static numbers.
///
/// 3. **Compact actions are one row.** Phone and multi-column cards
///    use icon-only controls in a single command rail. Wider single-card
///    layouts can still show text where the extra width actually helps.
struct UserPreviewCard: View {
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif

    let preview: PixivUserPreview
    let followRestrict: BookmarkRestrict?
    let isUpdating: Bool
    let showContentBadges: Bool
    let maskSensitivePreviews: Bool
    /// When true the preview strip renders as a horizontally scrolling
    /// shelf with bigger thumbnails — the layout single-column mode
    /// switches into. Defaults to false so the existing 3-up grid
    /// behaviour stays unchanged.
    var expandedPreview: Bool = false
    let openProfile: () -> Void
    let openIllustrations: () -> Void
    let openManga: () -> Void
    let followCreator: (BookmarkRestrict?) -> Void
    let requestUnfollow: () -> Void
    let requestMuteCreator: () -> Void
    let requestFeedback: () -> Void
    let copyCreatorLink: () -> Void
    let copyArtworkLink: (PixivArtwork) -> Void
    let isPinned: Bool
    let togglePinnedCreator: () -> Void
    let selectArtwork: (PixivArtwork) -> Void
    var cachedPreviewArtworks: [PixivArtwork] = []
    /// Lazily fetches the creator's recent works for the expanded
    /// shelf. The Pixiv recommended/related-users endpoints only ship
    /// 3 illustrations per user, so when the user picks the single-card
    /// layout we go fetch the rest. Optional so the auto / twoUp paths
    /// can leave it `nil`.
    var loadExpandedArtworks: (() async throws -> [PixivArtwork])? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            if expandedPreview {
                expandedCommandRail
                previewStrip
            } else {
                previewStrip
                if usesIconOnlyActionLabels {
                    compactCommandRail
                } else {
                    navigationRow
                    actionRail
                }
            }
        }
        .padding(12)
        .keiInteractiveGlass(20)
        .contextMenu { creatorContextMenu }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            avatar

            VStack(alignment: .leading, spacing: 3) {
                Text(preview.user.name)
                    .font(.headline)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .layoutPriority(1)

                Text("@\(preview.user.account)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                statusLine
            }
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 8)

            headerActionControls
        }
    }

    private var headerActionControls: some View {
        HStack(spacing: 6) {
            pinActionChip
            followButton
        }
        .layoutPriority(1)
    }

    private var avatar: some View {
        RemoteImageView(url: preview.user.avatarURL)
            .frame(width: 54, height: 54)
            .clipShape(Circle())
            .overlay {
                Circle().stroke(.quaternary, lineWidth: 1)
            }
    }

    /// Optional one-line status the same way `UserProfileSheetHeader`
    /// renders region/job context — keeps the row "filled in" instead
    /// of leaving the slot blank when the creator has no muted/private
    /// state to advertise.
    @ViewBuilder
    private var statusLine: some View {
        if let statusText {
            HStack(spacing: 5) {
                if let icon = statusSystemImage {
                    Image(systemName: icon)
                        .imageScale(.small)
                }
                Text(statusText)
                    .lineLimit(1)
            }
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
        }
    }

    private var statusText: String? {
        if preview.isMuted {
            return L10n.muted
        }
        return nil
    }

    private var statusSystemImage: String? {
        if preview.isMuted {
            return "eye.slash"
        }
        return nil
    }

    @ViewBuilder
    private var followButton: some View {
        let profile = followControlProfile
        if preview.user.isFollowed {
            Menu {
                Button(L10n.followPublicly) {
                    followCreator(.public)
                }
                .disabled(followRestrict == .public)
                Button(L10n.followPrivately) {
                    followCreator(.private)
                }
                .disabled(followRestrict == .private)

                Divider()

                Button(role: .destructive) {
                    requestUnfollow()
                } label: {
                    Label(L10n.unfollow, systemImage: "person.crop.circle.badge.minus")
                }
            } label: {
                if isUpdating {
                    ProgressView().controlSize(.small)
                } else {
                    compactFollowLabel
                }
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.capsule)
            .controlSize(.small)
            .foregroundStyle(compactFollowMenuForegroundStyle)
            .disabled(isUpdating)
            .help(L10n.followVisibility)
        } else {
            Menu {
                Button(L10n.followUsingDefault) {
                    followCreator(nil)
                }

                Divider()

                Button(L10n.followPublicly) {
                    followCreator(.public)
                }
                Button(L10n.followPrivately) {
                    followCreator(.private)
                }
            } label: {
                if isUpdating {
                    ProgressView().controlSize(.small)
                } else {
                    compactFollowLabel
                }
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.capsule)
            .controlSize(.small)
            .foregroundStyle(profile.foregroundStyle)
            .disabled(isUpdating)
            .help(L10n.follow)
        }
    }

    private var compactFollowLabel: some View {
        creatorButtonLabel(
            title: followControlTitle,
            systemImage: followControlProfile.systemImage,
            displayStyle: followControlDisplayStyle
        )
    }

    private var followControlTitle: String {
        if usesIconOnlyActionLabels, let compactTitle = followControlProfile.compactTitle {
            return compactTitle
        }
        return followControlProfile.title
    }

    private var followControlDisplayStyle: CreatorCardButtonDisplayStyle {
        if usesIconOnlyActionLabels, followControlProfile.compactTitle == nil {
            return .iconOnly
        }
        return .titleAndIcon
    }

    private var compactFollowMenuForegroundStyle: Color {
        followControlProfile.foregroundStyle
    }

    private var followControlProfile: CreatorCardFollowControlProfile {
        guard preview.user.isFollowed else {
            return CreatorCardFollowControlProfile(
                title: L10n.follow,
                compactTitle: nil,
                systemImage: "person.crop.circle.badge.plus",
                foregroundStyle: .blue
            )
        }

        switch followRestrict {
        case .public:
            return CreatorCardFollowControlProfile(
                title: L10n.publicFollow,
                compactTitle: L10n.publicRestrict,
                systemImage: "globe",
                foregroundStyle: .green
            )
        case .private:
            return CreatorCardFollowControlProfile(
                title: L10n.privateFollow,
                compactTitle: L10n.privateRestrict,
                systemImage: "lock.fill",
                foregroundStyle: .purple
            )
        case nil:
            return CreatorCardFollowControlProfile(
                title: L10n.following,
                compactTitle: nil,
                systemImage: "person.crop.circle.badge.checkmark",
                foregroundStyle: .blue
            )
        }
    }

    private var pinActionChip: some View {
        Button(action: togglePinnedCreator) {
            creatorButtonLabel(
                title: pinControlProfile.title,
                systemImage: pinControlProfile.systemImage,
                displayStyle: .iconOnly
            )
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.capsule)
        .controlSize(.small)
        .foregroundStyle(compactPinForegroundStyle)
        .help(pinControlProfile.title)
        .accessibilityLabel(pinControlProfile.title)
    }

    private var compactPinForegroundStyle: Color {
        pinControlProfile.foregroundStyle
    }

    private var pinControlProfile: CreatorCardPinControlProfile {
        CreatorCardPinControlProfile(
            title: isPinned ? L10n.unpinCreator : L10n.pinCreator,
            systemImage: isPinned ? "pin.fill" : "pin",
            foregroundStyle: isPinned ? Color.accentColor : Color.secondary
        )
    }

    // MARK: - Preview strip

    @ViewBuilder
    private var previewStrip: some View {
        if expandedPreview {
            expandedPreviewStrip
        } else {
            compactPreviewStrip
        }
    }

    /// Three thumbnails packed across the full card width. Used in the
    /// `auto` and `twoUp` layouts where each card already fits ~2 to
    /// 4 per row and a fixed three-up shelf reads cleanly.
    private var compactPreviewStrip: some View {
        CompactCreatorPreviewStrip(
            seedArtworks: preview.illusts,
            cachedArtworks: cachedPreviewArtworks,
            userID: preview.user.id,
            showContentBadges: showContentBadges,
            maskSensitivePreviews: maskSensitivePreviews,
            selectArtwork: selectArtwork,
            copyArtworkLink: copyArtworkLink,
            loadArtworks: loadExpandedArtworks
        )
    }

    private func compactPreviewStrip(artworks: [PixivArtwork]) -> some View {
        // GeometryReader hands us the card's placed width so the
        // three (or fewer) thumbnails can scale together as the
        // grid widens, instead of staying pinned to a static
        // 132-pt tile. Aspect is held at 4:5 so the row reads as a
        // consistent shelf regardless of card width.
        GeometryReader { proxy in
            let count = min(artworks.count, 3)
            let spacing: CGFloat = 8
            let totalSpacing = spacing * CGFloat(max(0, count - 1))
            let tileWidth = max((proxy.size.width - totalSpacing) / CGFloat(count), 64)

            HStack(spacing: spacing) {
                ForEach(artworks.prefix(count)) { artwork in
                    artworkThumbButton(artwork, tileWidth: tileWidth)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .leading)
        }
        // Match the strip aspect to the tile aspect so the
        // GeometryReader receives a height that the thumbnails can
        // honour — ~5/4 of tile width for the 4:5 portrait shelf.
        .aspectRatio(previewStripAspect(for: artworks.count), contentMode: .fit)
    }

    /// Horizontally scrollable shelf used by the single-column layout.
    /// The shelf is its own subview so it can own the lazy-fetch state
    /// (loaded artworks + isLoading + error) without the rest of the
    /// card growing more `@State`.
    private var expandedPreviewStrip: some View {
        ExpandedCreatorPreviewShelf(
            seedArtworks: preview.illusts,
            cachedArtworks: cachedPreviewArtworks,
            userID: preview.user.id,
            showContentBadges: showContentBadges,
            maskSensitivePreviews: maskSensitivePreviews,
            selectArtwork: selectArtwork,
            copyArtworkLink: copyArtworkLink,
            loadArtworks: loadExpandedArtworks
        )
    }

    private func artworkThumbButton(_ artwork: PixivArtwork, tileWidth: CGFloat) -> some View {
        Button {
            selectArtwork(artwork)
        } label: {
            ArtworkPreviewThumb(
                artwork: artwork,
                tileWidth: tileWidth,
                showContentBadges: showContentBadges,
                maskSensitivePreview: maskSensitivePreviews
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(L10n.selectArtwork) { selectArtwork(artwork) }
            if let url = artwork.pixivURL {
                Link(L10n.openInPixiv, destination: url)
                Button(L10n.copyLink) { copyArtworkLink(artwork) }
            }
        }
    }

    /// Combined width:height ratio for the row of thumbnails. Three
    /// portrait tiles + 2 gutters land at roughly 1.92 — close enough
    /// that the `aspectRatio` modifier hands the GeometryReader a
    /// height that matches the tiles' natural 4:5 ratio.
    private func previewStripAspect(for artworkCount: Int) -> CGFloat {
        let count = CGFloat(max(min(artworkCount, 3), 1))
        // 4:5 portrait tiles -> tile height = tile width * 5/4
        // strip height = tile height; strip width = count * tile width + gutters
        // ratio = (count * tile + gutters) / (tile * 5/4)
        // gutters ~= small relative to tiles; approximate via tileless math
        return count * (4.0 / 5.0)
    }

    // MARK: - Navigation row

    private var navigationRow: some View {
        GlassEffectContainer(spacing: 8) {
            if usesIconOnlyActionLabels {
                iconOnlyNavigationButtons
            } else {
                ViewThatFits(in: .horizontal) {
                    fullWidthNavigationButtons(displayStyle: .titleAndIcon)
                    iconOnlyNavigationButtons
                }
            }
        }
    }

    private var expandedCommandRail: some View {
        GlassEffectContainer(spacing: 8) {
            if usesIconOnlyActionLabels {
                expandedCommandRailContent(displayStyle: .iconOnly)
            } else {
                ViewThatFits(in: .horizontal) {
                    expandedCommandRailContent(displayStyle: .titleAndIcon)
                    expandedCommandRailContent(displayStyle: .iconOnly)
                }
            }
        }
    }

    private var usesIconOnlyActionLabels: Bool {
        #if os(iOS)
        if horizontalSizeClass == .compact {
            return true
        }
        #endif

        return expandedPreview == false
    }

    private var compactCommandRail: some View {
        GlassEffectContainer(spacing: 6) {
            HStack(spacing: 6) {
                compactNavigationChip(
                    title: L10n.creatorProfile,
                    systemImage: "person.crop.circle",
                    displayStyle: .iconOnly,
                    action: openProfile
                )
                compactNavigationChip(
                    title: L10n.illustrations,
                    systemImage: "photo",
                    displayStyle: .iconOnly,
                    action: openIllustrations
                )
                compactNavigationChip(
                    title: L10n.manga,
                    systemImage: "book.closed",
                    displayStyle: .iconOnly,
                    action: openManga
                )
                pixivLink(displayStyle: .iconOnly)
                actionChip(
                    title: L10n.copyLink,
                    systemImage: "link",
                    displayStyle: .iconOnly,
                    action: copyCreatorLink
                )
                feedbackActionChip
                muteCreatorActionChip
            }
        }
    }

    private var iconOnlyNavigationButtons: some View {
        HStack(spacing: 8) {
            compactNavigationChip(
                title: L10n.creatorProfile,
                systemImage: "person.crop.circle",
                displayStyle: .iconOnly,
                action: openProfile
            )
            compactNavigationChip(
                title: L10n.illustrations,
                systemImage: "photo",
                displayStyle: .iconOnly,
                action: openIllustrations
            )
            compactNavigationChip(
                title: L10n.manga,
                systemImage: "book.closed",
                displayStyle: .iconOnly,
                action: openManga
            )
            Spacer(minLength: 0)
        }
    }

    private func fullWidthNavigationButtons(displayStyle: CreatorCardButtonDisplayStyle) -> some View {
        HStack(spacing: 8) {
            navigationChip(
                title: L10n.creatorProfile,
                systemImage: "person.crop.circle",
                displayStyle: displayStyle,
                action: openProfile
            )
            navigationChip(
                title: L10n.illustrations,
                systemImage: "photo",
                displayStyle: displayStyle,
                action: openIllustrations
            )
            navigationChip(
                title: L10n.manga,
                systemImage: "book.closed",
                displayStyle: displayStyle,
                action: openManga
            )
        }
    }

    private func expandedCommandRailContent(displayStyle: CreatorCardButtonDisplayStyle) -> some View {
        HStack(spacing: 8) {
            compactNavigationChip(
                title: L10n.creatorProfile,
                systemImage: "person.crop.circle",
                displayStyle: displayStyle,
                action: openProfile
            )
            compactNavigationChip(
                title: L10n.illustrations,
                systemImage: "photo",
                displayStyle: displayStyle,
                action: openIllustrations
            )
            compactNavigationChip(
                title: L10n.manga,
                systemImage: "book.closed",
                displayStyle: displayStyle,
                action: openManga
            )

            Spacer(minLength: 8)

            pixivLink(displayStyle: displayStyle)
            actionChip(
                title: L10n.copyLink,
                systemImage: "link",
                displayStyle: .iconOnly,
                action: copyCreatorLink
            )
            overflowMenu
        }
    }

    private func navigationChip(
        title: String,
        systemImage: String,
        displayStyle: CreatorCardButtonDisplayStyle,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            creatorButtonLabel(
                title: title,
                systemImage: systemImage,
                displayStyle: displayStyle
            )
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.capsule)
        .controlSize(.small)
        .help(title)
        .accessibilityLabel(title)
    }

    private func compactNavigationChip(
        title: String,
        systemImage: String,
        displayStyle: CreatorCardButtonDisplayStyle,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            creatorButtonLabel(
                title: title,
                systemImage: systemImage,
                displayStyle: displayStyle
            )
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.capsule)
        .controlSize(.small)
        .help(title)
        .accessibilityLabel(title)
    }


    // MARK: - Action rail (high-frequency standalone buttons + overflow)

    private var actionRail: some View {
        GlassEffectContainer(spacing: 8) {
            if usesIconOnlyActionLabels {
                actionRailContent(pixivDisplayStyle: .iconOnly)
            } else {
                ViewThatFits(in: .horizontal) {
                    actionRailContent(pixivDisplayStyle: .titleAndIcon)
                    actionRailContent(pixivDisplayStyle: .iconOnly)
                }
            }
        }
    }

    private func actionRailContent(pixivDisplayStyle: CreatorCardButtonDisplayStyle) -> some View {
        HStack(spacing: 8) {
            pixivLink(displayStyle: pixivDisplayStyle)

            actionChip(
                title: L10n.copyLink,
                systemImage: "link",
                displayStyle: .iconOnly,
                action: copyCreatorLink
            )

            Spacer(minLength: 8)

            overflowMenu
        }
    }

    private func actionChip(
        title: String,
        systemImage: String,
        displayStyle: CreatorCardButtonDisplayStyle,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            creatorButtonLabel(
                title: title,
                systemImage: systemImage,
                displayStyle: displayStyle
            )
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.capsule)
        .controlSize(.small)
        .help(title)
        .accessibilityLabel(title)
    }

    private var feedbackActionChip: some View {
        Button(action: requestFeedback) {
            creatorButtonLabel(
                title: L10n.feedbackAndMute,
                systemImage: "exclamationmark.bubble",
                displayStyle: .iconOnly
            )
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.capsule)
        .controlSize(.small)
        .disabled(isUpdating)
        .help(L10n.feedbackAndMute)
        .accessibilityLabel(L10n.feedbackAndMute)
    }

    private var muteCreatorActionChip: some View {
        Button(role: .destructive, action: requestMuteCreator) {
            creatorButtonLabel(
                title: L10n.muteCreator,
                systemImage: "eye.slash",
                displayStyle: .iconOnly
            )
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.capsule)
        .controlSize(.small)
        .foregroundStyle(.red)
        .disabled(isUpdating)
        .help(L10n.muteCreator)
        .accessibilityLabel(L10n.muteCreator)
    }

    @ViewBuilder
    private func pixivLink(displayStyle: CreatorCardButtonDisplayStyle) -> some View {
        if let url = preview.user.pixivURL {
            Link(destination: url) {
                creatorButtonLabel(
                    title: L10n.openInPixiv,
                    systemImage: "safari",
                    displayStyle: displayStyle
                )
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.capsule)
            .controlSize(.small)
            .help(L10n.openInPixiv)
            .accessibilityLabel(L10n.openInPixiv)
        }
    }

    @ViewBuilder
    private func creatorButtonLabel(
        title: String,
        systemImage: String,
        displayStyle: CreatorCardButtonDisplayStyle
    ) -> some View {
        switch displayStyle {
        case .titleAndIcon:
            Label {
                Text(title)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            } icon: {
                Image(systemName: systemImage)
            }
        case .iconOnly:
            Image(systemName: systemImage)
                .frame(minWidth: 18)
        }
    }

    private var overflowMenu: some View {
        Menu {
            Button {
                requestFeedback()
            } label: {
                Label(L10n.feedbackAndMute, systemImage: "exclamationmark.bubble")
            }

            Divider()

            Button(role: .destructive) {
                requestMuteCreator()
            } label: {
                Label(L10n.muteCreator, systemImage: "eye.slash")
            }
        } label: {
            Label(L10n.moreActions, systemImage: "ellipsis.circle")
        }
        .labelStyle(.iconOnly)
        .menuStyle(.borderlessButton)
        .buttonStyle(.glass)
        .buttonBorderShape(.capsule)
        .controlSize(.small)
        .disabled(isUpdating)
        .help(L10n.moreActions)
    }

    // MARK: - Context menu

    @ViewBuilder
    private var creatorContextMenu: some View {
        Button(L10n.creatorProfile) { openProfile() }
        if let url = preview.user.pixivURL {
            Link(L10n.openInPixiv, destination: url)
        }
        Button(L10n.copyLink) { copyCreatorLink() }
        Button {
            togglePinnedCreator()
        } label: {
            Label(
                isPinned ? L10n.unpinCreator : L10n.pinCreator,
                systemImage: isPinned ? "pin.slash" : "pin"
            )
        }

        Divider()

        if preview.user.isFollowed {
            Button(role: .destructive) {
                requestUnfollow()
            } label: {
                Label(L10n.unfollow, systemImage: "person.crop.circle.badge.minus")
            }
        } else {
            Button(L10n.followUsingDefault) { followCreator(nil) }
            Button(L10n.followPublicly) { followCreator(.public) }
            Button(L10n.followPrivately) { followCreator(.private) }
        }

        Divider()

        Button(L10n.creatorIllustrations) { openIllustrations() }
        Button(L10n.creatorManga) { openManga() }

        Divider()

        Button {
            requestFeedback()
        } label: {
            Label(L10n.feedbackAndMute, systemImage: "exclamationmark.bubble")
        }
        Button(role: .destructive) {
            requestMuteCreator()
        } label: {
            Label(L10n.muteCreator, systemImage: "eye.slash")
        }
    }
}

private enum CreatorCardButtonDisplayStyle {
    case titleAndIcon
    case iconOnly
}

private struct CreatorCardFollowControlProfile {
    let title: String
    let compactTitle: String?
    let systemImage: String
    let foregroundStyle: Color
}

private struct CreatorCardPinControlProfile {
    let title: String
    let systemImage: String
    let foregroundStyle: Color
}

private struct CompactCreatorPreviewStrip: View {
    let seedArtworks: [PixivArtwork]
    let cachedArtworks: [PixivArtwork]
    let userID: Int
    let showContentBadges: Bool
    let maskSensitivePreviews: Bool
    let selectArtwork: (PixivArtwork) -> Void
    let copyArtworkLink: (PixivArtwork) -> Void
    let loadArtworks: (() async throws -> [PixivArtwork])?

    @State private var fetchedArtworks: [PixivArtwork] = []
    @State private var isLoading = false
    @State private var didAttemptLoad = false

    private var renderedArtworks: [PixivArtwork] {
        if fetchedArtworks.isEmpty == false {
            return fetchedArtworks
        }
        if cachedArtworks.isEmpty == false {
            return cachedArtworks
        }
        return seedArtworks
    }

    var body: some View {
        GeometryReader { proxy in
            let visibleArtworks = Array(renderedArtworks.prefix(3))
            let placeholderCount = visibleArtworks.isEmpty ? 3 : visibleArtworks.count
            let spacing: CGFloat = 8
            let totalSpacing = spacing * CGFloat(max(0, placeholderCount - 1))
            let tileWidth = max((proxy.size.width - totalSpacing) / CGFloat(placeholderCount), 64)

            HStack(spacing: spacing) {
                if visibleArtworks.isEmpty {
                    ForEach(0..<placeholderCount, id: \.self) { _ in
                        SkeletonPlaceholder(width: tileWidth, height: tileWidth * 5.0 / 4.0, cornerRadius: 10)
                            .overlay {
                                Image(systemName: "photo")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                    }
                } else {
                    ForEach(visibleArtworks) { artwork in
                        Button {
                            selectArtwork(artwork)
                        } label: {
                            ArtworkPreviewThumb(
                                artwork: artwork,
                                tileWidth: tileWidth,
                                showContentBadges: showContentBadges,
                                maskSensitivePreview: maskSensitivePreviews
                            )
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(L10n.selectArtwork) { selectArtwork(artwork) }
                            if let url = artwork.pixivURL {
                                Link(L10n.openInPixiv, destination: url)
                                Button(L10n.copyLink) { copyArtworkLink(artwork) }
                            }
                        }
                    }
                }
            }
            .opacity(isLoading && visibleArtworks.isEmpty ? 0.82 : 1)
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .leading)
        }
        .aspectRatio(previewStripAspect(for: renderedArtworks.isEmpty ? 3 : renderedArtworks.count), contentMode: .fit)
        .task(id: userID) {
            resetFetchState()
            await loadIfNeeded()
        }
    }

    private func previewStripAspect(for artworkCount: Int) -> CGFloat {
        CGFloat(max(min(artworkCount, 3), 1)) * (4.0 / 5.0)
    }

    private func loadIfNeeded() async {
        guard seedArtworks.isEmpty,
              cachedArtworks.isEmpty,
              let loadArtworks,
              didAttemptLoad == false else { return }
        didAttemptLoad = true
        isLoading = true
        defer { isLoading = false }

        do {
            let loaded = try await loadArtworks()
            if loaded.isEmpty == false {
                fetchedArtworks = loaded
            }
        } catch {
            // Keep the static placeholder. Creator cards are scannable
            // even when Pixiv withholds user-preview thumbnails.
        }
    }

    private func resetFetchState() {
        fetchedArtworks = []
        isLoading = false
        didAttemptLoad = false
    }
}

/// Self-sizing artwork thumbnail tile used by the creator preview
/// strip. The tile pins its own (width, height) so SwiftUI's resizable
/// image can't bleed past the layout frame — same fix that landed for
/// `TrendingTagCard` and `ArtworkCardView`.
private struct ArtworkPreviewThumb: View {
    let artwork: PixivArtwork
    let tileWidth: CGFloat
    let showContentBadges: Bool
    let maskSensitivePreview: Bool

    /// 4:5 portrait — close enough to most Pixiv illustrations that
    /// thumbnails crop to a flattering centre without needing a per-
    /// artwork aspect read.
    private var tileHeight: CGFloat {
        tileWidth * 5.0 / 4.0
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            RemoteImageView(url: artwork.thumbnailURL, contentMode: .fill)
                .sensitiveArtworkPreviewMasked(
                    maskSensitivePreview && artwork.requiresScreenCaptureProtection,
                    badges: artwork.contentBadges
                )
                .frame(width: tileWidth, height: tileHeight)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            if showContentBadges {
                ArtworkContentBadgesView(badges: artwork.contentBadges, style: .overlay)
                    .padding(6)
            }

            if artwork.pageCount > 1 {
                Text(L10n.pageCountShort(artwork.pageCount))
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .keiGlass(8)
                    .padding(6)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            }
        }
        .frame(width: tileWidth, height: tileHeight)
    }
}

/// Horizontally scrollable artwork shelf used by the single-card
/// layout. Owns its own fetch state (`artworks`, `isLoading`, error
/// banner) so the parent `UserPreviewCard` doesn't have to grow more
/// `@State` slots for the lazy-load lifecycle.
///
/// The shelf seeds itself with the 3 illustrations Pixiv ships in the
/// recommended-users / related-users response, then asynchronously
/// fetches the creator's full recent works. Once they arrive the merged
/// list (de-duped, sorted newest first by the store) replaces the seed
/// — same call shape `UserProfileRecentWorksSection` uses, so we share
/// the cache the API layer keeps internally.
private struct ExpandedCreatorPreviewShelf: View {
    let seedArtworks: [PixivArtwork]
    let cachedArtworks: [PixivArtwork]
    let userID: Int
    let showContentBadges: Bool
    let maskSensitivePreviews: Bool
    let selectArtwork: (PixivArtwork) -> Void
    let copyArtworkLink: (PixivArtwork) -> Void
    let loadArtworks: (() async throws -> [PixivArtwork])?

    private let tileHeight: CGFloat = 178
    private var tileWidth: CGFloat { tileHeight * 4.0 / 5.0 }
    private let visibleCap = 24

    @State private var fetchedArtworks: [PixivArtwork] = []
    @State private var isLoading = false
    @State private var didAttemptLoad = false

    private var renderedArtworks: [PixivArtwork] {
        if fetchedArtworks.isEmpty == false {
            return fetchedArtworks
        }
        if cachedArtworks.isEmpty == false {
            return cachedArtworks
        }
        return seedArtworks
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(renderedArtworks.prefix(visibleCap)) { artwork in
                    Button {
                        selectArtwork(artwork)
                    } label: {
                        ArtworkPreviewThumb(
                            artwork: artwork,
                            tileWidth: tileWidth,
                            showContentBadges: showContentBadges,
                            maskSensitivePreview: maskSensitivePreviews
                        )
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button(L10n.selectArtwork) { selectArtwork(artwork) }
                        if let url = artwork.pixivURL {
                            Link(L10n.openInPixiv, destination: url)
                            Button(L10n.copyLink) { copyArtworkLink(artwork) }
                        }
                    }
                }

                if isLoading {
                    SkeletonPlaceholder(width: tileWidth, height: tileHeight, cornerRadius: 12)
                        .overlay {
                            Image(systemName: "photo")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                }
            }
        }
        .frame(height: tileHeight)
        // Same edge-fade treatment as Apple's shelves so the user gets
        // a visual cue that the rail scrolls horizontally.
        .mask {
            HStack(spacing: 0) {
                LinearGradient(colors: [.clear, .black], startPoint: .leading, endPoint: .trailing)
                    .frame(width: 14)
                Rectangle()
                LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing)
                    .frame(width: 14)
            }
        }
        // `.task(id:)` keys the load to userID so switching cards
        // (when SwiftUI recycles a view) re-fires the fetch for the
        // new creator instead of stale data.
        .task(id: userID) {
            resetFetchState()
            await loadIfNeeded()
        }
    }

    private func loadIfNeeded() async {
        guard cachedArtworks.isEmpty,
              let loadArtworks,
              didAttemptLoad == false else { return }
        didAttemptLoad = true
        isLoading = true
        defer { isLoading = false }

        do {
            let loaded = try await loadArtworks()
            // Some accounts return zero artworks (private feeds, muted,
            // etc.) — preserve the seed in that case so we don't end
            // up with an empty shelf.
            if loaded.isEmpty == false {
                fetchedArtworks = loaded
            }
        } catch {
            // Silent failure on the shelf is intentional: the seed
            // illustrations are still rendered, and the rest of the
            // card surfaces error reporting via the bulk-status banner.
        }
    }

    private func resetFetchState() {
        fetchedArtworks = []
        isLoading = false
        didAttemptLoad = false
    }
}
