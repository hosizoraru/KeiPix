import SwiftUI

/// "Collections" grid: every count attached to the user routed back into a
/// dedicated feed (illustrations, manga, public saves) or list (following,
/// followers, related). Re-designed to behave like the navigation shelf in
/// Apple Music / TV — large primary number, gentle accent tint on the
/// glyph, an arrow chevron showing the row is tappable.
struct UserProfileCollectionShortcutsSection: View {
    let profile: PixivUserProfile?
    let relatedUsersCount: Int
    let isLoadingRelatedUsers: Bool
    let openIllustrations: () -> Void
    let openManga: () -> Void
    let openPublicBookmarks: () -> Void
    let openFollowing: () -> Void
    let openFollowers: () -> Void
    let openRelated: () -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 188, maximum: 260), spacing: 12, alignment: .top)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Label(L10n.creatorCollections, systemImage: "rectangle.stack")
                    .font(.headline)
                Spacer(minLength: 0)
                Text(L10n.openCreatorCollection)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                ProfileCollectionShortcutButton(
                    title: L10n.creatorIllustrations,
                    value: profile?.totalIllusts.formatted(.number.notation(.compactName)),
                    systemImage: "photo.on.rectangle",
                    tint: .blue,
                    isPrimary: true,
                    action: openIllustrations
                )

                ProfileCollectionShortcutButton(
                    title: L10n.creatorManga,
                    value: profile?.totalManga.formatted(.number.notation(.compactName)),
                    systemImage: "book.closed",
                    tint: .orange,
                    isPrimary: true,
                    action: openManga
                )

                ProfileCollectionShortcutButton(
                    title: L10n.creatorPublicBookmarks,
                    value: profile?.totalIllustBookmarksPublic.formatted(.number.notation(.compactName)),
                    systemImage: "bookmark",
                    tint: .pink,
                    isPrimary: true,
                    action: openPublicBookmarks
                )

                ProfileCollectionShortcutButton(
                    title: L10n.followingCreators,
                    value: profile?.totalFollowUsers.formatted(.number.notation(.compactName)),
                    systemImage: "person.2.crop.square.stack",
                    tint: .indigo,
                    isPrimary: false,
                    action: openFollowing
                )

                ProfileCollectionShortcutButton(
                    title: L10n.followers,
                    value: nil,
                    systemImage: "person.2",
                    tint: .teal,
                    isPrimary: false,
                    action: openFollowers
                )

                ProfileCollectionShortcutButton(
                    title: L10n.relatedCreators,
                    value: relatedUsersCount > 0
                        ? "\(relatedUsersCount.formatted())+"
                        : nil,
                    systemImage: "person.3",
                    tint: .purple,
                    isPrimary: false,
                    isLoading: isLoadingRelatedUsers,
                    action: openRelated
                )
                .disabled(isLoadingRelatedUsers)
            }
        }
        .padding(16)
        .keiPanel(16)
    }
}

private struct ProfileCollectionShortcutButton: View {
    let title: String
    let value: String?
    let systemImage: String
    let tint: Color
    /// Primary cells (illustrations / manga / public saves) get the larger
    /// hero number, while secondary cells (network) skip the count to keep
    /// visual hierarchy clear.
    let isPrimary: Bool
    var isLoading: Bool = false
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(tint.opacity(0.16))
                    Image(systemName: systemImage)
                        .font(.title3)
                        .foregroundStyle(tint)
                }
                .frame(width: 38, height: 38)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    if isLoading {
                        ProgressView()
                            .controlSize(.small)
                    } else if let value {
                        Text(value)
                            .font(isPrimary ? .title3.weight(.semibold).monospacedDigit() : .callout.monospacedDigit())
                            .foregroundStyle(isPrimary ? .primary : .secondary)
                            .lineLimit(1)
                    } else {
                        Text(L10n.open)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.forward")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .opacity(isHovering ? 0.85 : 0.55)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .keiInteractiveGlass(12)
        .scaleEffect(isHovering ? 1.01 : 1)
        .animation(.snappy(duration: 0.16), value: isHovering)
        .onHover { isHovering = $0 }
        .help(title)
        .accessibilityLabel(title)
        .accessibilityValue(value ?? "")
    }
}
