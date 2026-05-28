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

    private var stats: (followed: Int, muted: Int, works: Int) {
        previews.reduce(into: (0, 0, 0)) { acc, p in
            if p.user.isFollowed { acc.0 += 1 }
            if p.isMuted { acc.1 += 1 }
            acc.2 += p.illusts.count
        }
    }

    private var followedCount: Int { stats.followed }
    private var unfollowedCount: Int { previews.count - stats.followed }
    private var mutedCount: Int { stats.muted }
    private var previewWorkCount: Int { stats.works }
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
