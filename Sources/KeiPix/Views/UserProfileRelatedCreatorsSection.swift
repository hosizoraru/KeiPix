import SwiftUI

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

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            content

            if let relatedErrorMessage {
                Text(relatedErrorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
            }
        }
        .padding(14)
        .keiPanel(14)
    }

    private var header: some View {
        HStack {
            Label(L10n.relatedCreators, systemImage: "person.2.crop.square.stack")
                .font(.headline)

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
            ProgressView()
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 18)
        } else if relatedUsers.isEmpty {
            Text(L10n.noRelatedCreators)
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    ForEach(relatedUsers.prefix(10)) { preview in
                        RelatedCreatorCard(
                            preview: preview,
                            openProfile: {
                                openProfile(preview.user)
                            },
                            openIllustrations: {
                                openIllustrations(preview.user)
                            },
                            toggleFollow: { restrict in
                                toggleFollow(preview.user, restrict)
                            },
                            isUpdatingFollow: updatingRelatedUserIDs.contains(preview.user.id),
                            requestUnfollow: {
                                requestUnfollow(preview.user)
                            },
                            requestMuteCreator: {
                                requestMuteCreator(preview.user)
                            },
                            copied: copied,
                            selectArtwork: selectArtwork
                        )
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollIndicators(.hidden)
        }
    }
}

private struct RelatedCreatorCard: View {
    let preview: PixivUserPreview
    let openProfile: () -> Void
    let openIllustrations: () -> Void
    let toggleFollow: (BookmarkRestrict?) -> Void
    let isUpdatingFollow: Bool
    let requestUnfollow: () -> Void
    let requestMuteCreator: () -> Void
    let copied: () -> Void
    let selectArtwork: (PixivArtwork) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(action: openProfile) {
                VStack(alignment: .leading, spacing: 8) {
                    RemoteImageView(url: preview.user.avatarURL)
                        .frame(width: 52, height: 52)
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 2) {
                        Text(preview.user.name)
                            .font(.headline)
                            .lineLimit(1)
                        Text("@\(preview.user.account)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)

                        if preview.isMuted {
                            Label(L10n.muted, systemImage: "eye.slash")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            HStack(spacing: 6) {
                ForEach(preview.illusts.prefix(2)) { artwork in
                    Button {
                        selectArtwork(artwork)
                    } label: {
                        RemoteImageView(url: artwork.thumbnailURL)
                            .aspectRatio(1, contentMode: .fill)
                            .frame(width: 56, height: 56)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
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
                }
            }

            HStack(spacing: 8) {
                if preview.user.isFollowed {
                    Button(L10n.unfollow) {
                        requestUnfollow()
                    }
                    .buttonStyle(.bordered)
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
                    }
                    .buttonStyle(.bordered)
                    .disabled(isUpdatingFollow)
                }

                Button {
                    openIllustrations()
                } label: {
                    Label(L10n.illustrations, systemImage: "photo")
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.bordered)
            }
        }
        .frame(width: 170, alignment: .leading)
        .padding(12)
        .keiInteractiveGlass(14)
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
}
