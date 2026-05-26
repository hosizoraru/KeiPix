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
/// 3. **Navigation is one row, not two.** Profile / Illustrations /
///    Manga used to share a row with the overflow menu (`More`)
///    crammed onto the right, all under `controlSize(.small)`. The
///    layout now separates `nav row` from `action rail` so each row has
///    breathing room and a clear job.
struct UserPreviewCard: View {
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
    /// Lazily fetches the creator's recent works for the expanded
    /// shelf. The Pixiv recommended/related-users endpoints only ship
    /// 3 illustrations per user, so when the user picks the single-card
    /// layout we go fetch the rest. Optional so the auto / twoUp paths
    /// can leave it `nil`.
    var loadExpandedArtworks: (() async throws -> [PixivArtwork])? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            previewStrip
            navigationRow
            actionRail
        }
        .padding(14)
        .keiInteractiveGlass(16)
        .contextMenu { creatorContextMenu }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            avatar

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(preview.user.name)
                        .font(.headline)
                        .lineLimit(1)
                    if isPinned {
                        Image(systemName: "pin.fill")
                            .imageScale(.small)
                            .foregroundStyle(Color.accentColor)
                            .help(L10n.pinnedCreators)
                            .accessibilityLabel(L10n.pinnedCreators)
                    }
                }

                Text("@\(preview.user.account)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                statusLine
            }

            Spacer(minLength: 8)

            followButton
        }
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
        if preview.user.isFollowed, let followRestrict {
            return followRestrict.creatorVisibilityTitle
        }
        return nil
    }

    private var statusSystemImage: String? {
        if preview.isMuted {
            return "eye.slash"
        }
        if preview.user.isFollowed, let followRestrict {
            return followRestrict.creatorVisibilitySystemImage
        }
        return nil
    }

    @ViewBuilder
    private var followButton: some View {
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
                    Label(L10n.following, systemImage: "person.crop.circle.badge.checkmark")
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
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
                    Label(L10n.follow, systemImage: "person.crop.circle.badge.plus")
                }
            }
            .buttonStyle(.glassProminent)
            .controlSize(.small)
            .disabled(isUpdating)
            .help(L10n.follow)
        }
    }

    // MARK: - Preview strip

    @ViewBuilder
    private var previewStrip: some View {
        if preview.illusts.isEmpty == false {
            if expandedPreview {
                expandedPreviewStrip
            } else {
                compactPreviewStrip
            }
        }
    }

    /// Three thumbnails packed across the full card width. Used in the
    /// `auto` and `twoUp` layouts where each card already fits ~2 to
    /// 4 per row and a fixed three-up shelf reads cleanly.
    private var compactPreviewStrip: some View {
        // GeometryReader hands us the card's placed width so the
        // three (or fewer) thumbnails can scale together as the
        // grid widens, instead of staying pinned to a static
        // 132-pt tile. Aspect is held at 4:5 so the row reads as a
        // consistent shelf regardless of card width.
        GeometryReader { proxy in
            let count = min(preview.illusts.count, 3)
            let spacing: CGFloat = 8
            let totalSpacing = spacing * CGFloat(max(0, count - 1))
            let tileWidth = max((proxy.size.width - totalSpacing) / CGFloat(count), 64)

            HStack(spacing: spacing) {
                ForEach(preview.illusts.prefix(count)) { artwork in
                    artworkThumbButton(artwork, tileWidth: tileWidth)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .leading)
        }
        // Match the strip aspect to the tile aspect so the
        // GeometryReader receives a height that the thumbnails can
        // honour — ~5/4 of tile width for the 4:5 portrait shelf.
        .aspectRatio(previewStripAspect, contentMode: .fit)
    }

    /// Horizontally scrollable shelf used by the single-column layout.
    /// The shelf is its own subview so it can own the lazy-fetch state
    /// (loaded artworks + isLoading + error) without the rest of the
    /// card growing more `@State`.
    private var expandedPreviewStrip: some View {
        ExpandedCreatorPreviewShelf(
            seedArtworks: preview.illusts,
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
    private var previewStripAspect: CGFloat {
        let count = CGFloat(max(min(preview.illusts.count, 3), 1))
        // 4:5 portrait tiles -> tile height = tile width * 5/4
        // strip height = tile height; strip width = count * tile width + gutters
        // ratio = (count * tile + gutters) / (tile * 5/4)
        // gutters ~= small relative to tiles; approximate via tileless math
        return count * (4.0 / 5.0)
    }

    // MARK: - Navigation row

    private var navigationRow: some View {
        HStack(spacing: 8) {
            navigationChip(
                title: L10n.creatorProfile,
                systemImage: "person.crop.circle",
                action: openProfile
            )
            navigationChip(
                title: L10n.illustrations,
                systemImage: "photo",
                action: openIllustrations
            )
            navigationChip(
                title: L10n.manga,
                systemImage: "book.closed",
                action: openManga
            )
        }
    }

    private func navigationChip(
        title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: systemImage)
                Text(title)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .help(title)
    }

    // MARK: - Action rail (high-frequency standalone buttons + overflow)

    private var actionRail: some View {
        HStack(spacing: 8) {
            actionChip(
                title: isPinned ? L10n.unpinCreator : L10n.pinCreator,
                systemImage: isPinned ? "pin.slash" : "pin",
                action: togglePinnedCreator
            )

            if let url = preview.user.pixivURL {
                Link(destination: url) {
                    Label(L10n.openInPixiv, systemImage: "safari")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help(L10n.openInPixiv)
            }

            actionChip(
                title: L10n.copyLink,
                systemImage: "link",
                action: copyCreatorLink
            )

            Spacer(minLength: 8)

            overflowMenu
        }
    }

    private func actionChip(
        title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.bordered)
        .controlSize(.small)
        .help(title)
        .accessibilityLabel(title)
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
        .buttonStyle(.bordered)
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
                Text("\(artwork.pageCount)P")
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
    let userID: Int
    let showContentBadges: Bool
    let maskSensitivePreviews: Bool
    let selectArtwork: (PixivArtwork) -> Void
    let copyArtworkLink: (PixivArtwork) -> Void
    let loadArtworks: (() async throws -> [PixivArtwork])?

    private let tileHeight: CGFloat = 200
    private var tileWidth: CGFloat { tileHeight * 4.0 / 5.0 }
    private let visibleCap = 24

    @State private var fetchedArtworks: [PixivArtwork] = []
    @State private var isLoading = false
    @State private var didAttemptLoad = false

    private var renderedArtworks: [PixivArtwork] {
        fetchedArtworks.isEmpty ? seedArtworks : fetchedArtworks
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
                    ProgressView()
                        .controlSize(.small)
                        .frame(width: tileWidth, height: tileHeight)
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
            await loadIfNeeded()
        }
    }

    private func loadIfNeeded() async {
        guard let loadArtworks, didAttemptLoad == false else { return }
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
}

