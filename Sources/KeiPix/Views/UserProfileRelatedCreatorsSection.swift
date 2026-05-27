import SwiftUI

/// "Related creators" carousel.
///
/// The carousel doubles as a follow-suggestion shelf, so each card needs
/// to communicate three things at a glance: who the creator is (avatar +
/// name), what they make (their two most recent illustrations), and what
/// you can do with them (follow / view illustrations / mute). Layout
/// pattern is borrowed from App Store "Discover Developers" cards —
/// avatar at the top, body in the middle, action row pinned to the
/// bottom — which is what feels native on macOS / iPad.
struct UserProfileRelatedCreatorsSection: View {
    let relatedUsers: [PixivUserPreview]
    let isLoadingRelatedUsers: Bool
    let relatedErrorMessage: String?
    let updatingRelatedUserIDs: Set<Int>
    let reload: () -> Void
    let viewAll: () -> Void
    let openProfile: (PixivUser) -> Void
    let openIllustrations: (PixivUser) -> Void
    let toggleFollow: (PixivUser, BookmarkRestrict?) -> Void
    let requestUnfollow: (PixivUser) -> Void
    let requestMuteCreator: (PixivUser) -> Void
    let copied: () -> Void
    let selectArtwork: (PixivArtwork) -> Void

    private let cardWidth: CGFloat = 196
    private let visibleCap = 10

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            content

            if let relatedErrorMessage {
                Text(relatedErrorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
            }
        }
        .padding(16)
        .keiPanel(16)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Label(L10n.relatedCreators, systemImage: "person.2.crop.square.stack")
                .font(.headline)

            if relatedUsers.isEmpty == false {
                Text("\(min(relatedUsers.count, visibleCap))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(.quaternary, in: Capsule())
            }

            Spacer()

            if relatedErrorMessage != nil {
                Button {
                    reload()
                } label: {
                    Label(L10n.retry, systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            if relatedUsers.isEmpty == false {
                Button {
                    viewAll()
                } label: {
                    Label(L10n.viewAllRelatedCreators, systemImage: "arrow.right.circle")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if isLoadingRelatedUsers {
            placeholderRow
        } else if relatedUsers.isEmpty {
            ContentUnavailableView(
                L10n.noRelatedCreators,
                systemImage: "person.2.slash"
            )
            .frame(maxWidth: .infinity)
            .frame(minHeight: 180)
        } else {
            carousel
        }
    }

    private var placeholderRow: some View {
        HStack(spacing: 12) {
            ForEach(0..<4, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.quaternary)
                    .frame(width: cardWidth, height: 230)
                    .overlay {
                        ProgressView()
                            .controlSize(.small)
                    }
            }
        }
        .frame(height: 230)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var carousel: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 12) {
                ForEach(relatedUsers.prefix(visibleCap)) { preview in
                    RelatedCreatorCard(
                        preview: preview,
                        cardWidth: cardWidth,
                        openProfile: { openProfile(preview.user) },
                        openIllustrations: { openIllustrations(preview.user) },
                        toggleFollow: { restrict in
                            toggleFollow(preview.user, restrict)
                        },
                        isUpdatingFollow: updatingRelatedUserIDs.contains(preview.user.id),
                        requestUnfollow: { requestUnfollow(preview.user) },
                        requestMuteCreator: { requestMuteCreator(preview.user) },
                        copied: copied,
                        selectArtwork: selectArtwork
                    )
                }
            }
            .padding(.vertical, 2)
            .padding(.horizontal, 1)
        }
        .scrollIndicators(.hidden)
        .mask {
            HStack(spacing: 0) {
                LinearGradient(colors: [.clear, .black], startPoint: .leading, endPoint: .trailing)
                    .frame(width: 14)
                Rectangle()
                LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing)
                    .frame(width: 14)
            }
        }
    }
}

private struct RelatedCreatorCard: View {
    let preview: PixivUserPreview
    let cardWidth: CGFloat
    let openProfile: () -> Void
    let openIllustrations: () -> Void
    let toggleFollow: (BookmarkRestrict?) -> Void
    let isUpdatingFollow: Bool
    let requestUnfollow: () -> Void
    let requestMuteCreator: () -> Void
    let copied: () -> Void
    let selectArtwork: (PixivArtwork) -> Void

    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerButton

            illustrationStrip

            Spacer(minLength: 0)

            actionRow
        }
        .frame(width: cardWidth, alignment: .leading)
        .padding(14)
        .keiInteractiveGlass(16)
        .scaleEffect(isHovering ? 1.012 : 1)
        .animation(.snappy(duration: 0.16), value: isHovering)
        .keiPixHoverTracker { isHovering = $0 }
        .contextMenu {
            Button(L10n.creatorProfile) {
                openProfile()
            }
            if let url = preview.user.pixivURL {
                Link(L10n.openInPixiv, destination: url)
                Button(L10n.copyLink) {
                    PasteboardWriter.copy(url.absoluteString)
                    copied()
                }
            }

            Divider()

            if preview.user.isFollowed {
                Button(L10n.unfollow) {
                    requestUnfollow()
                }
                .disabled(isUpdatingFollow)
            } else {
                Button(L10n.followUsingDefault) {
                    toggleFollow(nil)
                }
                .disabled(isUpdatingFollow)
                Button(L10n.followPublicly) {
                    toggleFollow(.public)
                }
                .disabled(isUpdatingFollow)
                Button(L10n.followPrivately) {
                    toggleFollow(.private)
                }
                .disabled(isUpdatingFollow)
            }

            Divider()

            Button(role: .destructive) {
                requestMuteCreator()
            } label: {
                Label(L10n.muteCreator, systemImage: "eye.slash")
            }
        }
    }

    private var headerButton: some View {
        Button(action: openProfile) {
            HStack(alignment: .top, spacing: 10) {
                RemoteImageView(url: preview.user.avatarURL)
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())
                    .overlay {
                        Circle().stroke(.quaternary, lineWidth: 1)
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text(preview.user.name)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text("@\(preview.user.account)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    if preview.isMuted {
                        Label(L10n.muted, systemImage: "eye.slash")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    } else if preview.user.isFollowed {
                        Label(L10n.following, systemImage: "checkmark")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .buttonStyle(.plain)
    }

    private var illustrationStrip: some View {
        HStack(spacing: 6) {
            // Pad the strip to two slots so cards line up vertically even
            // when the creator only has a single recent illustration.
            ForEach(0..<2, id: \.self) { index in
                if let artwork = preview.illusts[safe: index] {
                    Button {
                        selectArtwork(artwork)
                    } label: {
                        RemoteImageView(url: artwork.thumbnailURL)
                            .aspectRatio(1, contentMode: .fill)
                            .frame(maxWidth: .infinity)
                            .frame(height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button(L10n.selectArtwork) {
                            selectArtwork(artwork)
                        }

                        if let url = artwork.pixivURL {
                            Link(L10n.openInPixiv, destination: url)
                            Button(L10n.copyLink) {
                                PasteboardWriter.copy(url.absoluteString)
                                copied()
                            }
                        }
                    }
                } else {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(.quaternary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 80)
                }
            }
        }
    }

    @ViewBuilder
    private var actionRow: some View {
        HStack(spacing: 8) {
            if preview.user.isFollowed {
                Button(role: .destructive) {
                    requestUnfollow()
                } label: {
                    Label(L10n.unfollow, systemImage: "person.crop.circle.badge.minus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(isUpdatingFollow)
            } else {
                Menu {
                    Button(L10n.followUsingDefault) {
                        toggleFollow(nil)
                    }

                    Divider()

                    Button(L10n.followPublicly) {
                        toggleFollow(.public)
                    }
                    Button(L10n.followPrivately) {
                        toggleFollow(.private)
                    }
                } label: {
                    Label(L10n.follow, systemImage: "person.crop.circle.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .menuStyle(.borderlessButton)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(isUpdatingFollow)
            }

            Button {
                openIllustrations()
            } label: {
                Label(L10n.illustrations, systemImage: "photo")
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help(L10n.illustrations)
        }
    }
}
