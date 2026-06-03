import SwiftUI

/// Compact header for `UserProfileSheet`.
///
/// The previous header rendered a 168 pt banner image; the redesigned
/// version mirrors Pixiv Web's profile chrome: a tight identity row
/// (avatar, name, subtitle, premium badge) above a horizontal action
/// rail with the high-traffic affordances surfaced as standalone
/// buttons rather than buried in an overflow menu.
///
/// Surfacing follow / pin / copy link / open-in-Pixiv on the front
/// page matches the way users actually use the sheet: most visits are
/// to a creator they want to keep tabs on (pin), share to someone (copy
/// link), or open the official page for context (Pixiv Web). Apple's
/// HIG guidance is consistent — primary destructive / one-shot actions
/// stay in the menu, but **frequently used reversible actions** belong
/// in plain sight.
///
/// Pure presentation: every piece of state and every callback comes in
/// via the initializer. The parent sheet owns the truth.
struct UserProfileSheetHeader: View {
    let user: PixivUser
    let detail: PixivUserDetail?
    let isLoading: Bool

    // Follow state — used by both the prominent Follow CTA and the
    // visibility toggle in the same row.
    let isFollowed: Bool
    let isUpdatingFollow: Bool
    let followRestrict: BookmarkRestrict?
    let toggleFollow: (BookmarkRestrict?) -> Void
    let updateFollowVisibility: (BookmarkRestrict) -> Void
    let requestUnfollow: () -> Void

    // Pin / share / open. Pinning is reversible and frequent; copy and
    // open are one-tap routines users reach for constantly. All three
    // get standalone buttons.
    let isPinned: Bool
    let togglePin: () -> Void
    let openInPixivURL: URL?
    let copyLink: () -> Void

    // Mute state — surfaced as a toggle in the overflow menu so the
    // creator can be hushed without going through the full feedback
    // report flow.
    let isMuted: Bool
    let toggleMute: () -> Void

    // Truly low-frequency items live in the overflow menu.
    let requestFeedback: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            identityRow
            actionRail
        }
        .platformGlassControlBar(verticalPadding: 12, topPadding: 8, bottomPadding: 10)
    }

    // MARK: - Identity row

    private var identityRow: some View {
        HStack(alignment: .center, spacing: 14) {
            avatar
            identity
            Spacer(minLength: 12)
            SheetCloseButton(style: .plain)
        }
    }

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
                if isPinned {
                    Image(systemName: "pin.fill")
                        .imageScale(.small)
                        .foregroundStyle(Color.accentColor)
                        .help(L10n.pinnedCreators)
                        .accessibilityLabel(L10n.pinnedCreators)
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
    /// banner: region · job, or the loading state. Kept short so the
    /// row never wraps.
    private var secondaryLine: String? {
        if isLoading {
            return L10n.loading
        }
        let region = detail?.profile.region?.trimmingCharacters(in: .whitespacesAndNewlines)
        let job = detail?.profile.job?.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = [region, job].compactMap { value -> String? in
            guard let value, value.isEmpty == false else { return nil }
            return value
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    // MARK: - Action rail

    private var actionRail: some View {
        HStack(spacing: 8) {
            followButton

            pinButton

            if let openInPixivURL {
                Link(destination: openInPixivURL) {
                    Label(L10n.openInPixiv, systemImage: "safari")
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help(L10n.openInPixiv)

                Button {
                    copyLink()
                } label: {
                    Label(L10n.copyLink, systemImage: "link")
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help(L10n.copyLink)
                .accessibilityLabel(L10n.copyLink)
            }

            Spacer(minLength: 0)

            overflowMenu
        }
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

    /// Pinning is reversible and the most-used "save for later" action,
    /// so it lives outside the overflow menu. The button's appearance
    /// flips between pin / pin.slash so users can read the state at a
    /// glance.
    private var pinButton: some View {
        Button {
            togglePin()
        } label: {
            Label(
                isPinned ? L10n.unpinCreator : L10n.pinCreator,
                systemImage: isPinned ? "pin.slash" : "pin"
            )
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .help(isPinned ? L10n.unpinCreator : L10n.pinCreator)
    }

    @ViewBuilder
    private var overflowMenu: some View {
        Menu {
            Button {
                toggleMute()
            } label: {
                Label(
                    isMuted ? L10n.unmuteCreator : L10n.muteCreator,
                    systemImage: isMuted ? "speaker.wave.2" : "speaker.slash"
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
