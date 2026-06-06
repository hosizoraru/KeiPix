import SwiftUI

struct CreatorFeedContextCard: View {
    let user: PixivUser
    let route: PixivRoute
    let filter: CreatorArtworkTagFilter?
    let loadedCount: Int
    let visibleCount: Int
    let contentSystemImage: String
    let openProfile: () -> Void
    let clearContext: () -> Void

    init(
        user: PixivUser,
        route: PixivRoute,
        filter: CreatorArtworkTagFilter?,
        loadedCount: Int,
        visibleCount: Int,
        contentSystemImage: String = "square.grid.2x2",
        openProfile: @escaping () -> Void,
        clearContext: @escaping () -> Void
    ) {
        self.user = user
        self.route = route
        self.filter = filter
        self.loadedCount = loadedCount
        self.visibleCount = visibleCount
        self.contentSystemImage = contentSystemImage
        self.openProfile = openProfile
        self.clearContext = clearContext
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 10) {
                avatar

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.headline.weight(.semibold))
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("\(user.name) @\(user.account)")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .layoutPriority(1)

                Spacer(minLength: 6)

                actionButtons
            }

            HStack(spacing: 7) {
                countBadge(value: visibleCount == loadedCount ? loadedCount : visibleCount, systemImage: contentSystemImage)
                if visibleCount != loadedCount {
                    countBadge(value: loadedCount, systemImage: "tray.full")
                }
                if let expectedCount = filter?.expectedCount {
                    countBadge(value: expectedCount, systemImage: "number")
                }
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .contain)
    }

    private var title: String {
        if let filter {
            return String(format: L10n.creatorTagFilterFormat, filter.tag)
        }
        return "\(route.title) · \(user.name)"
    }

    private var avatar: some View {
        RemoteImageView(url: user.avatarURL)
            .frame(width: 42, height: 42)
            .clipShape(Circle())
            .overlay {
                Circle().stroke(.quaternary, lineWidth: 1)
            }
    }

    private var actionButtons: some View {
        HStack(spacing: 7) {
            Button(action: openProfile) {
                Label(L10n.openCreatorProfile, systemImage: "person.crop.circle")
            }
            .labelStyle(.iconOnly)
            .help(L10n.openCreatorProfile)
            .accessibilityLabel(L10n.openCreatorProfile)
            .buttonStyle(.plain)
            .frame(width: 34, height: 34)
            .keiInteractiveGlass(17)

            Button(action: clearContext) {
                Label(L10n.clearFeedFilter, systemImage: "xmark.circle.fill")
            }
            .labelStyle(.iconOnly)
            .help(L10n.clearFeedFilter)
            .accessibilityLabel(L10n.clearFeedFilter)
            .buttonStyle(.plain)
            .frame(width: 34, height: 34)
            .keiInteractiveGlass(17)
        }
    }

    private func countBadge(value: Int, systemImage: String) -> some View {
        Label(value.formatted(), systemImage: systemImage)
            .font(.caption.weight(.semibold).monospacedDigit())
            .foregroundStyle(.secondary)
            .labelStyle(.titleAndIcon)
            .lineLimit(1)
            .padding(.horizontal, 9)
            .frame(height: 28)
            .glassEffect(.regular, in: Capsule(style: .continuous))
    }
}
