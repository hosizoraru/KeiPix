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

struct PixivCollectionFeedContext: Equatable, Sendable {
    let id: String
    let title: String
    let owner: PixivCollectionFeedContextOwner
    let tags: [PixivCollectionFeedContextTag]
    let caption: String
    let bookmarkCount: Int
    let viewCount: Int
    let publishedDate: Date?
    let relatedCollectionCount: Int
    let loadedCount: Int
    let visibleCount: Int
    let pixivURLString: String?

    init(collection: PixivCollectionDetail, loadedCount: Int, visibleCount: Int) {
        id = collection.id
        title = collection.title
        owner = PixivCollectionFeedContextOwner(user: collection.owner)
        tags = collection.tags.map(PixivCollectionFeedContextTag.init)
        caption = collection.caption.htmlStripped
        bookmarkCount = collection.bookmarkCount
        viewCount = collection.viewCount
        publishedDate = collection.publishedDate
        relatedCollectionCount = collection.relatedCollections.count
        self.loadedCount = loadedCount
        self.visibleCount = visibleCount
        pixivURLString = collection.pixivURL?.absoluteString
    }

    var displayTitle: String {
        title.isEmpty ? L10n.pixivCollection : title
    }

    var pixivURL: URL? {
        pixivURLString.flatMap { URL(string: $0) }
    }
}

struct PixivCollectionFeedContextOwner: Equatable, Sendable {
    let id: Int
    let name: String
    let account: String
    let avatarURLString: String?

    init(user: PixivUser) {
        id = user.id
        name = user.name
        account = user.account
        avatarURLString = user.avatarURL?.absoluteString
    }

    var avatarURL: URL? {
        avatarURLString.flatMap { URL(string: $0) }
    }

    var pixivUser: PixivUser {
        PixivUser(
            id: id,
            name: name,
            account: account,
            avatarURL: avatarURL
        )
    }
}

struct PixivCollectionFeedContextTag: Identifiable, Hashable, Sendable {
    let name: String
    let translatedName: String?

    init(tag: PixivTag) {
        name = tag.name
        translatedName = tag.translatedName
    }

    var id: String { name }
}

struct PixivCollectionFeedContextCard: View {
    let context: PixivCollectionFeedContext
    let openCreator: () -> Void
    let copyLink: () -> Void
    let clearContext: () -> Void

    private static let visibleTagLimit = 6

    var body: some View {
        ViewThatFits(in: .horizontal) {
            regularLayout
                .frame(minWidth: 560, alignment: .leading)
            compactLayout
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityElement(children: .contain)
    }

    private var regularLayout: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 14) {
                titleBlock
                    .layoutPriority(1)

                Spacer(minLength: 10)

                actionRail
            }

            if metadataItems.isEmpty == false {
                metadataRail
            }

            if context.tags.isEmpty == false {
                tagCloud
            }

            captionBlock
        }
    }

    private var compactLayout: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                kindLabel

                Spacer(minLength: 8)

                compactActionRail
            }

            titleText
                .font(.title2.weight(.bold))
                .lineLimit(3)
                .minimumScaleFactor(0.88)
                .fixedSize(horizontal: false, vertical: true)

            ownerButton

            if metadataItems.isEmpty == false {
                metadataRail
            }

            if context.tags.isEmpty == false {
                tagCloud
            }

            captionBlock
        }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            kindLabel

            titleText
                .font(.title2.weight(.bold))
                .lineLimit(2)
                .minimumScaleFactor(0.88)
                .fixedSize(horizontal: false, vertical: true)

            ownerButton
        }
    }

    private var titleText: some View {
        Text(context.displayTitle)
            .textSelection(.enabled)
    }

    private var kindLabel: some View {
        Label(L10n.pixivCollection, systemImage: "rectangle.stack")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .labelStyle(.titleAndIcon)
            .lineLimit(1)
    }

    private var ownerButton: some View {
        Button(action: openCreator) {
            Label {
                Text("\(context.owner.name) @\(context.owner.account)")
                    .lineLimit(1)
                    .truncationMode(.middle)
            } icon: {
                RemoteImageView(url: context.owner.avatarURL)
                    .frame(width: 22, height: 22)
                    .clipShape(Circle())
                    .overlay {
                        Circle().stroke(.quaternary, lineWidth: 1)
                    }
            }
        }
        .buttonStyle(.plain)
        .font(.caption.weight(.medium))
        .foregroundStyle(.secondary)
        .help(L10n.openCreatorProfile)
        .accessibilityLabel("\(L10n.openCreatorProfile), \(context.owner.name)")
    }

    private var actionRail: some View {
        HStack(spacing: 7) {
            Button(action: openCreator) {
                Label(L10n.openCreatorProfile, systemImage: "person.crop.circle")
            }
            .collectionHeaderIconButton(L10n.openCreatorProfile)

            if let url = context.pixivURL {
                Link(destination: url) {
                    Label(L10n.openInPixiv, systemImage: "safari")
                }
                .collectionHeaderIconButton(L10n.openInPixiv)

                Button(action: copyLink) {
                    Label(L10n.copyLink, systemImage: "link")
                }
                .collectionHeaderIconButton(L10n.copyLink)
            }

            Button(action: clearContext) {
                Label(L10n.close, systemImage: "xmark.circle.fill")
            }
            .collectionHeaderIconButton(L10n.close)
        }
    }

    private var compactActionRail: some View {
        HStack(spacing: 7) {
            Menu {
                Button(action: openCreator) {
                    Label(L10n.openCreatorProfile, systemImage: "person.crop.circle")
                }

                if let url = context.pixivURL {
                    Link(destination: url) {
                        Label(L10n.openInPixiv, systemImage: "safari")
                    }

                    Button(action: copyLink) {
                        Label(L10n.copyLink, systemImage: "link")
                    }
                }
            } label: {
                Label(L10n.moreActions, systemImage: "ellipsis.circle")
            }
            .collectionHeaderIconButton(L10n.moreActions)

            Button(action: clearContext) {
                Label(L10n.close, systemImage: "xmark.circle.fill")
            }
            .collectionHeaderIconButton(L10n.close)
        }
    }

    private var metadataRail: some View {
        FlowLayout(spacing: 7) {
            ForEach(metadataItems) { item in
                CollectionHeaderMetadataPill(item: item)
            }
        }
    }

    private var tagCloud: some View {
        FlowLayout(spacing: 6) {
            ForEach(context.tags.prefix(Self.visibleTagLimit), id: \.name) { tag in
                PixivCollectionHeaderTagChip(tag: tag)
            }

            if context.tags.count > Self.visibleTagLimit {
                Menu {
                    ForEach(context.tags.dropFirst(Self.visibleTagLimit), id: \.name) { tag in
                        Button("#\(tag.name)") {}
                            .disabled(true)
                    }
                } label: {
                    Label("+\(context.tags.count - Self.visibleTagLimit)", systemImage: "ellipsis")
                }
                .font(.caption.weight(.semibold))
                .labelStyle(.titleAndIcon)
                .padding(.horizontal, 9)
                .frame(height: 28)
                .keiInteractiveGlass(14)
            }
        }
    }

    @ViewBuilder
    private var captionBlock: some View {
        if context.caption.isEmpty == false {
            Text(context.caption)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var metadataItems: [CollectionHeaderMetadataItem] {
        var items: [CollectionHeaderMetadataItem] = [
            CollectionHeaderMetadataItem(
                id: "works",
                title: L10n.works,
                value: worksCountText,
                systemImage: "photo.on.rectangle.angled"
            ),
            CollectionHeaderMetadataItem(
                id: "bookmarks",
                title: L10n.bookmarks,
                value: context.bookmarkCount.formatted(),
                systemImage: "heart.fill"
            ),
            CollectionHeaderMetadataItem(
                id: "views",
                title: L10n.views,
                value: context.viewCount.formatted(),
                systemImage: "eye.fill"
            )
        ]

        if let publishedDate = context.publishedDate {
            items.append(
                CollectionHeaderMetadataItem(
                    id: "published",
                    title: L10n.created,
                    value: publishedDate.formatted(date: .abbreviated, time: .shortened),
                    systemImage: "calendar"
                )
            )
        }

        if context.relatedCollectionCount > 0 {
            items.append(
                CollectionHeaderMetadataItem(
                    id: "related",
                    title: L10n.relatedPixivCollections,
                    value: context.relatedCollectionCount.formatted(),
                    systemImage: "rectangle.stack.badge.plus"
                )
            )
        }

        return items
    }

    private var worksCountText: String {
        guard context.visibleCount != context.loadedCount else {
            return context.loadedCount.formatted()
        }
        return "\(context.visibleCount.formatted())/\(context.loadedCount.formatted())"
    }
}

private struct CollectionHeaderMetadataItem: Identifiable {
    let id: String
    let title: String
    let value: String
    let systemImage: String
}

private struct CollectionHeaderMetadataPill: View {
    let item: CollectionHeaderMetadataItem

    var body: some View {
        Label {
            HStack(spacing: 4) {
                Text(item.value)
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.primary)
                Text(item.title)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: item.systemImage)
                .font(.caption.weight(.semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)
        }
        .labelStyle(.titleAndIcon)
        .lineLimit(1)
        .padding(.horizontal, 9)
        .frame(height: 28)
        .glassEffect(.regular, in: Capsule(style: .continuous))
    }
}

private struct PixivCollectionHeaderTagChip: View {
    let tag: PixivCollectionFeedContextTag

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("#\(tag.name)")
                .font(.caption.weight(.semibold))
                .lineLimit(1)
            if let translatedName = tag.translatedName, translatedName.isEmpty == false {
                Text(translatedName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, translatedNameExists ? 5 : 0)
        .frame(height: translatedNameExists ? 42 : 28)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityLabel(accessibilityLabel)
    }

    private var translatedNameExists: Bool {
        tag.translatedName?.isEmpty == false
    }

    private var accessibilityLabel: String {
        if let translatedName = tag.translatedName, translatedName.isEmpty == false {
            return "#\(tag.name), \(translatedName)"
        }
        return "#\(tag.name)"
    }
}

private extension View {
    func collectionHeaderIconButton(_ accessibilityLabel: String) -> some View {
        self
            .labelStyle(.iconOnly)
            .buttonStyle(.plain)
            .frame(width: 34, height: 34)
            .keiInteractiveGlass(17)
            .help(accessibilityLabel)
            .accessibilityLabel(accessibilityLabel)
    }
}
