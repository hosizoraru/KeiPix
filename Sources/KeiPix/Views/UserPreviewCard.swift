import SwiftUI

struct UserPreviewCard: View {
    let preview: PixivUserPreview
    let followRestrict: BookmarkRestrict?
    let isUpdating: Bool
    let showContentBadges: Bool
    let openProfile: () -> Void
    let openIllustrations: () -> Void
    let openManga: () -> Void
    let followCreator: (BookmarkRestrict?) -> Void
    let requestUnfollow: () -> Void
    let requestMuteCreator: () -> Void
    let requestFeedback: () -> Void
    let copyCreatorLink: () -> Void
    let copyArtworkLink: (PixivArtwork) -> Void
    let selectArtwork: (PixivArtwork) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            previewStrip
            actionStrip
        }
        .padding(12)
        .keiInteractiveGlass(16)
        .contextMenu {
            creatorContextMenu
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            RemoteImageView(url: preview.user.avatarURL)
                .frame(width: 54, height: 54)
                .clipShape(Circle())
                .overlay {
                    Circle().stroke(.quaternary, lineWidth: 1)
                }

            VStack(alignment: .leading, spacing: 3) {
                Text(preview.user.name)
                    .font(.headline)
                    .lineLimit(1)
                Text("@\(preview.user.account)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            creatorBadges
            followMenu
        }
    }

    private var creatorBadges: some View {
        HStack(spacing: 6) {
            if preview.isMuted {
                Label(L10n.muted, systemImage: "eye.slash")
                    .help(L10n.muted)
            }

            if preview.user.isFollowed, let followRestrict {
                Label(followRestrict.creatorVisibilityTitle, systemImage: followRestrict.creatorVisibilitySystemImage)
                    .help(followRestrict.creatorVisibilityTitle)
            }
        }
        .font(.caption.weight(.semibold))
        .labelStyle(.iconOnly)
        .foregroundStyle(.secondary)
    }

    private var followMenu: some View {
        Menu {
            if preview.user.isFollowed {
                Button(role: .destructive) {
                    requestUnfollow()
                } label: {
                    Label(L10n.unfollow, systemImage: "person.crop.circle.badge.minus")
                }
            } else {
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
            }
        } label: {
            if isUpdating {
                ProgressView()
                    .controlSize(.small)
            } else if preview.user.isFollowed {
                Label(L10n.following, systemImage: "person.crop.circle.badge.checkmark")
            } else {
                Label(L10n.follow, systemImage: "person.crop.circle.badge.plus")
            }
        }
        .buttonStyle(.bordered)
        .disabled(isUpdating)
        .help(preview.user.isFollowed ? L10n.following : L10n.follow)
    }

    @ViewBuilder
    private var previewStrip: some View {
        if preview.illusts.isEmpty == false {
            HStack(spacing: 8) {
                ForEach(preview.illusts.prefix(3)) { artwork in
                    Button {
                        selectArtwork(artwork)
                    } label: {
                        ArtworkPreviewThumb(artwork: artwork, showContentBadges: showContentBadges)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button(L10n.selectArtwork) {
                            selectArtwork(artwork)
                        }

                        if let url = artwork.pixivURL {
                            Link(L10n.openInPixiv, destination: url)
                            Button(L10n.copyLink) {
                                copyArtworkLink(artwork)
                            }
                        }
                    }
                }
            }
        }
    }

    private var actionStrip: some View {
        HStack(spacing: 8) {
            Button {
                openProfile()
            } label: {
                Label(L10n.creatorProfile, systemImage: "person.crop.circle")
            }
            .buttonStyle(.bordered)

            Button {
                openIllustrations()
            } label: {
                Label(L10n.illustrations, systemImage: "photo")
            }
            .buttonStyle(.bordered)

            Button {
                openManga()
            } label: {
                Label(L10n.manga, systemImage: "book.closed")
            }
            .buttonStyle(.bordered)

            Spacer(minLength: 8)

            Menu {
                Button {
                    copyCreatorLink()
                } label: {
                    Label(L10n.copyLink, systemImage: "link")
                }

                if let url = preview.user.pixivURL {
                    Link(destination: url) {
                        Label(L10n.openInPixiv, systemImage: "safari")
                    }
                }

                Divider()

                Button(role: .destructive) {
                    requestMuteCreator()
                } label: {
                    Label(L10n.muteCreator, systemImage: "eye.slash")
                }

                Button {
                    requestFeedback()
                } label: {
                    Label(L10n.feedbackAndMute, systemImage: "exclamationmark.bubble")
                }
            } label: {
                Label(L10n.moreActions, systemImage: "ellipsis.circle")
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.bordered)
            .disabled(isUpdating)
            .help(L10n.moreActions)
        }
        .controlSize(.small)
    }

    @ViewBuilder
    private var creatorContextMenu: some View {
        Button(L10n.creatorProfile) {
            openProfile()
        }
        if let url = preview.user.pixivURL {
            Link(L10n.openInPixiv, destination: url)
        }
        Button(L10n.copyLink) {
            copyCreatorLink()
        }
        if preview.user.isFollowed {
            Button(role: .destructive) {
                requestUnfollow()
            } label: {
                Label(L10n.unfollow, systemImage: "person.crop.circle.badge.minus")
            }
        } else {
            Button(L10n.followUsingDefault) {
                followCreator(nil)
            }
            Button(L10n.followPublicly) {
                followCreator(.public)
            }
            Button(L10n.followPrivately) {
                followCreator(.private)
            }
        }
        Divider()
        Button(L10n.creatorIllustrations) {
            openIllustrations()
        }
        Button(L10n.creatorManga) {
            openManga()
        }
        Divider()
        Button(role: .destructive) {
            requestMuteCreator()
        } label: {
            Label(L10n.muteCreator, systemImage: "eye.slash")
        }
        Button {
            requestFeedback()
        } label: {
            Label(L10n.feedbackAndMute, systemImage: "exclamationmark.bubble")
        }
    }
}

private struct ArtworkPreviewThumb: View {
    let artwork: PixivArtwork
    let showContentBadges: Bool
    private let thumbnailHeight: CGFloat = 132

    var body: some View {
        ZStack(alignment: .topLeading) {
            RemoteImageView(url: artwork.thumbnailURL, contentMode: .fill)
                .frame(maxWidth: .infinity)
                .frame(height: thumbnailHeight)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            if showContentBadges {
                ArtworkContentBadgesView(badges: artwork.contentBadges, style: .overlay)
                    .padding(6)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: thumbnailHeight)
    }
}
