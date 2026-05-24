import SwiftUI

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
        GridItem(.adaptive(minimum: 158, maximum: 240), spacing: 10, alignment: .top)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(L10n.creatorCollections, systemImage: "rectangle.stack")
                .font(.headline)

            LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
                ProfileCollectionShortcutButton(
                    title: L10n.creatorIllustrations,
                    value: (profile?.totalIllusts ?? 0).formatted(),
                    detail: L10n.openCreatorCollection,
                    systemImage: "photo.on.rectangle",
                    action: openIllustrations
                )

                ProfileCollectionShortcutButton(
                    title: L10n.creatorManga,
                    value: (profile?.totalManga ?? 0).formatted(),
                    detail: L10n.openCreatorCollection,
                    systemImage: "book.closed",
                    action: openManga
                )

                ProfileCollectionShortcutButton(
                    title: L10n.creatorPublicBookmarks,
                    value: (profile?.totalIllustBookmarksPublic ?? 0).formatted(),
                    detail: L10n.openCreatorCollection,
                    systemImage: "bookmark",
                    action: openPublicBookmarks
                )

                ProfileCollectionShortcutButton(
                    title: L10n.followingCreators,
                    value: (profile?.totalFollowUsers ?? 0).formatted(),
                    detail: L10n.openCreatorNetwork,
                    systemImage: "person.2.crop.square.stack",
                    action: openFollowing
                )

                ProfileCollectionShortcutButton(
                    title: L10n.followers,
                    value: L10n.open,
                    detail: L10n.openCreatorNetwork,
                    systemImage: "person.2",
                    action: openFollowers
                )

                ProfileCollectionShortcutButton(
                    title: L10n.relatedCreators,
                    value: relatedUsersCount == 0 ? L10n.open : "\(relatedUsersCount.formatted())+",
                    detail: L10n.openCreatorNetwork,
                    systemImage: "person.3",
                    action: openRelated
                )
                .disabled(isLoadingRelatedUsers)
            }
        }
        .padding(14)
        .keiPanel(14)
    }
}

private struct ProfileCollectionShortcutButton: View {
    let title: String
    let value: String
    let detail: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: systemImage)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 3) {
                    Text(value)
                        .font(.headline)
                        .lineLimit(1)
                    Text(title)
                        .font(.callout.weight(.medium))
                        .lineLimit(1)
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: 82, alignment: .topLeading)
            .padding(12)
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .keiInteractiveGlass(12)
    }
}
