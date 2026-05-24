import SwiftUI

struct CreatorListSummaryStrip: View {
    let previews: [PixivUserPreview]

    var body: some View {
        FlowLayout(spacing: 6) {
            CreatorSummaryChip(
                title: L10n.following,
                value: followedCount,
                systemImage: "person.crop.circle.badge.checkmark"
            )

            CreatorSummaryChip(
                title: L10n.unfollowed,
                value: unfollowedCount,
                systemImage: "person.crop.circle.badge.plus"
            )

            CreatorSummaryChip(
                title: L10n.muted,
                value: mutedCount,
                systemImage: "eye.slash"
            )

            CreatorSummaryChip(
                title: L10n.previewWorks,
                value: previewWorkCount,
                systemImage: "photo.on.rectangle"
            )
        }
    }

    private var followedCount: Int {
        previews.filter(\.user.isFollowed).count
    }

    private var unfollowedCount: Int {
        previews.count - followedCount
    }

    private var mutedCount: Int {
        previews.filter(\.isMuted).count
    }

    private var previewWorkCount: Int {
        previews.reduce(0) { $0 + $1.illusts.count }
    }
}

private struct CreatorSummaryChip: View {
    let title: String
    let value: Int
    let systemImage: String

    var body: some View {
        Label {
            Text("\(value.formatted()) \(title)")
                .lineLimit(1)
        } icon: {
            Image(systemName: systemImage)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.quaternary, in: Capsule())
    }
}
