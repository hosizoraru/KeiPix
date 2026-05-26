import SwiftUI

/// Compact, single-row header for `UserProfileSheet`.
///
/// The previous header rendered a 168 pt banner image with the avatar,
/// name and actions floating at the bottom of a `ZStack`. That worked
/// when Pixiv users had set a custom background, but the vast majority
/// haven't — leaving the sheet with a tall slab of accent-colored
/// gradient that pushes every meaningful row below the fold.
///
/// Apple's own profile *sheets* (Contacts card, Photos people sheet,
/// AppKit's `NSPersonPhotoView` — not the App Store / Music **page**
/// chrome) use a tight one-row header instead: avatar on the leading
/// edge, identity in the center, action buttons trailing. We follow
/// that pattern here so the sheet leads with content.
///
/// The header is intentionally a **pure presentation** struct: every
/// piece of state and every action comes in via the initializer. This
/// keeps the parent sheet's body short and makes the component easy to
/// preview / unit-test in isolation.
struct UserProfileSheetHeader: View {
    /// Resolved user — falls back to the `PixivUser` the sheet was
    /// opened with when the detail response hasn't arrived yet.
    let user: PixivUser
    /// Loaded profile detail. `nil` while loading; the layout adapts
    /// gracefully so the header height never jumps when detail lands.
    let detail: PixivUserDetail?
    let isLoading: Bool

    // Follow state and follow-related callbacks. The follow control is
    // the only part of the header that mutates remote state, so it
    // gets richer inputs than the rest of the chrome.
    let isFollowed: Bool
    let isUpdatingFollow: Bool
    let followRestrict: BookmarkRestrict?
    let toggleFollow: (BookmarkRestrict?) -> Void
    let updateFollowVisibility: (BookmarkRestrict) -> Void
    let requestUnfollow: () -> Void

    // Overflow menu actions. Every action takes the resolved user via
    // the parent — keeps the menu logic out of this component.
    let openInPixivURL: URL?
    let copyLink: () -> Void
    let togglePin: () -> Void
    let isPinned: Bool
    let requestFeedback: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            avatar

            identity

            Spacer(minLength: 12)

            HStack(spacing: 8) {
                followButton
                profileActionsMenu
                SheetCloseButton(style: .bordered)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(.bar)
    }

    // MARK: - Pieces

    private var avatar: some View {
        RemoteImageView(url: user.avatarURL)
            .frame(width: 56, height: 56)
            .clipShape(Circle())
            .overlay {
                Circle().stroke(.quaternary, lineWidth: 1)
            }
    }

    private var identity: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .center, spacing: 6) {
                Text(user.name)
                    .font(.title3.weight(.semibold))
                    .lineLimit(1)
                if detail?.profile.isPremium == true {
                    Image(systemName: "checkmark.seal.fill")
                        .imageScale(.small)
                        .foregroundStyle(.yellow)
                        .help(L10n.premium)
                        .accessibilityLabel(L10n.premium)
                }
            }

            HStack(spacing: 6) {
                Text("@\(user.account)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if let secondaryLine {
                    Text("·")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Text(secondaryLine)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }

    /// Optional secondary status line shown next to `@account`. Adds
    /// just enough context to make the row feel "filled in" without a
    /// banner: region · job, the muted-creator flag, or the loading
    /// state. Kept short so the row never wraps.
    private var secondaryLine: String? {
        if isLoading {
            return L10n.loading
        }
        if let region = detail?.profile.region?.trimmingCharacters(in: .whitespacesAndNewlines),
           region.isEmpty == false {
            if let job = detail?.profile.job?.trimmingCharacters(in: .whitespacesAndNewlines),
               job.isEmpty == false {
                return "\(region) · \(job)"
            }
            return region
        }
        if let job = detail?.profile.job?.trimmingCharacters(in: .whitespacesAndNewlines),
           job.isEmpty == false {
            return job
        }
        return nil
    }

    @ViewBuilder
    private var followButton: some View {
        if isFollowed {
            Menu {
                Button(L10n.followPublicly) {
                    updateFollowVisibility(.public)
                }
                .disabled(followRestrict == .public)

                Button(L10n.followPrivately) {
                    updateFollowVisibility(.private)
                }
                .disabled(followRestrict == .private)

                Divider()

                Button(role: .destructive) {
                    requestUnfollow()
                } label: {
                    Label(L10n.unfollow, systemImage: "person.crop.circle.badge.minus")
                }
            } label: {
                Label(followStatusTitle, systemImage: followStatusImage)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(isLoading || isUpdatingFollow)
            .help(L10n.followVisibility)
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
            .buttonStyle(.glassProminent)
            .controlSize(.small)
            .disabled(isLoading || isUpdatingFollow)
            .help(L10n.follow)
        }
    }

    @ViewBuilder
    private var profileActionsMenu: some View {
        Menu {
            if let url = openInPixivURL {
                Link(L10n.openInPixiv, destination: url)

                Button(L10n.copyLink) {
                    copyLink()
                }
            }

            Button {
                togglePin()
            } label: {
                Label(
                    isPinned ? L10n.unpinCreator : L10n.pinCreator,
                    systemImage: isPinned ? "pin.slash" : "pin"
                )
            }

            Divider()

            Button {
                requestFeedback()
            } label: {
                Label(L10n.feedbackAndMute, systemImage: "exclamationmark.bubble")
            }
        } label: {
            Label(L10n.moreActions, systemImage: "ellipsis.circle")
        }
        .labelStyle(.iconOnly)
        .menuStyle(.borderlessButton)
        .buttonStyle(.bordered)
        .controlSize(.small)
        .help(L10n.moreActions)
    }

    private var followStatusTitle: String {
        followRestrict == .private ? L10n.followingPrivately : L10n.followingPublicly
    }

    private var followStatusImage: String {
        followRestrict == .private ? "lock.circle" : "person.crop.circle.badge.checkmark"
    }
}
