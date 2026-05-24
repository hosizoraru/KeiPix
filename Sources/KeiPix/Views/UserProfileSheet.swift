import SwiftUI

struct UserProfileSheet: View {
    let user: PixivUser
    @Bindable var store: KeiPixStore

    @Environment(\.dismiss) private var dismiss
    @State private var detail: PixivUserDetail?
    @State private var isLoading = true
    @State private var isLoadingRelatedUsers = false
    @State private var isFollowed: Bool
    @State private var relatedUsers: [PixivUserPreview] = []
    @State private var errorMessage: String?
    @State private var relatedErrorMessage: String?
    @State private var followRestrict: BookmarkRestrict?
    @State private var selectedRelatedUser: PixivUser?
    @State private var relationshipListMode: UserPreviewListMode?

    init(user: PixivUser, store: KeiPixStore) {
        self.user = user
        self.store = store
        _isFollowed = State(initialValue: user.isFollowed)
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(40)
                    } else {
                        metrics
                        profileCollectionShortcuts
                        comment
                        links
                        workspaceSection
                        relatedCreatorSection
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.callout)
                            .foregroundStyle(.red)
                            .textSelection(.enabled)
                    }
                }
                .padding(20)
            }
        }
        .frame(width: 580)
        .frame(minHeight: 520)
        .task(id: user.id) {
            await loadDetail()
            await loadRelatedUsers()
        }
        .sheet(item: $selectedRelatedUser) { relatedUser in
            UserProfileSheet(user: relatedUser, store: store)
        }
        .sheet(item: $relationshipListMode) { mode in
            UserPreviewListView(store: store, mode: mode)
                .frame(width: 920, height: 680)
        }
    }

    private var header: some View {
        ZStack(alignment: .bottomLeading) {
            RemoteImageView(url: detail?.profile.backgroundImageURL)
                .frame(height: 138)
                .frame(maxWidth: .infinity)
                .clipped()
                .overlay(.ultraThinMaterial)

            HStack(alignment: .bottom, spacing: 14) {
                RemoteImageView(url: detail?.user.avatarURL ?? user.avatarURL)
                    .frame(width: 74, height: 74)
                    .clipShape(Circle())
                    .overlay {
                        Circle().stroke(.quaternary, lineWidth: 1)
                    }

                VStack(alignment: .leading, spacing: 4) {
                    Text(detail?.user.name ?? user.name)
                        .font(.title2.weight(.semibold))
                        .lineLimit(1)
                    Text("@\(detail?.user.account ?? user.account)")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                followMenu
                profileActionsMenu
            }
            .padding(20)
        }
    }

    private var followMenu: some View {
        Group {
            if isFollowed {
                Menu {
                    Button(L10n.followPublicly) {
                        Task { await updateFollowVisibility(.public) }
                    }
                    .disabled(followRestrict == .public)

                    Button(L10n.followPrivately) {
                        Task { await updateFollowVisibility(.private) }
                    }
                    .disabled(followRestrict == .private)

                    Divider()

                    Button(role: .destructive) {
                        Task { await toggleFollow() }
                    } label: {
                        Label(L10n.unfollow, systemImage: "person.crop.circle.badge.minus")
                    }
                } label: {
                    Label(followStatusTitle, systemImage: followStatusImage)
                }
                .buttonStyle(.bordered)
            } else {
                Menu {
                    Button(L10n.followUsingDefault) {
                        Task { await toggleFollow() }
                    }

                    Divider()

                    Button(L10n.followPublicly) {
                        Task { await toggleFollow(restrict: .public) }
                    }
                    Button(L10n.followPrivately) {
                        Task { await toggleFollow(restrict: .private) }
                    }
                } label: {
                    Label(L10n.follow, systemImage: "person.crop.circle.badge.plus")
                }
                .buttonStyle(.glassProminent)
            }
        }
        .disabled(isLoading)
        .help(L10n.followVisibility)
    }

    @ViewBuilder
    private var profileActionsMenu: some View {
        if let url = currentUser.pixivURL {
            Menu {
                Link(L10n.openInPixiv, destination: url)

                Button(L10n.copyLink) {
                    PasteboardWriter.copy(url.absoluteString)
                }
            } label: {
                Label(L10n.moreActions, systemImage: "ellipsis.circle")
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.bordered)
            .help(L10n.moreActions)
        }
    }

    private var followStatusTitle: String {
        followRestrict == .private ? L10n.followingPrivately : L10n.followingPublicly
    }

    private var followStatusImage: String {
        followRestrict == .private ? "lock.circle" : "person.crop.circle.badge.checkmark"
    }

    private var metrics: some View {
        let profile = detail?.profile
        return Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 10) {
            GridRow {
                ProfileMetric(title: L10n.illustrations, value: profile?.totalIllusts ?? 0, systemImage: "photo")
                ProfileMetric(title: L10n.manga, value: profile?.totalManga ?? 0, systemImage: "book.pages")
                ProfileMetric(title: L10n.publicSaves, value: profile?.totalIllustBookmarksPublic ?? 0, systemImage: "bookmark")
                ProfileMetric(title: L10n.followers, value: profile?.totalFollowUsers ?? 0, systemImage: "person.2")
            }
        }
        .padding(14)
        .keiPanel(14)
    }

    @ViewBuilder
    private var comment: some View {
        if let text = (detail?.user.comment ?? user.comment)?.htmlStripped, text.isEmpty == false {
            VStack(alignment: .leading, spacing: 8) {
                Label(L10n.description, systemImage: "text.alignleft")
                    .font(.headline)
                Text(text)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
            .padding(14)
            .keiPanel(14)
        }
    }

    @ViewBuilder
    private var links: some View {
        let profile = detail?.profile
        let entries: [(String, URL?)] = [
            ("Pixiv", currentUser.pixivURL),
            ("Web", profile?.webpage),
            ("X", profile?.twitterURL),
            ("Pawoo", profile?.pawooURL)
        ]

        let visibleEntries = entries.compactMap { title, url in
            url.map { (title, $0) }
        }

        if visibleEntries.isEmpty == false || profile?.region != nil || profile?.job != nil {
            VStack(alignment: .leading, spacing: 10) {
                Label(L10n.links, systemImage: "link")
                    .font(.headline)

                FlowLayout(spacing: 8) {
                    ForEach(visibleEntries, id: \.0) { title, url in
                        Link(destination: url) {
                            Label(title, systemImage: title == "Pixiv" ? "safari" : "link")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }

                if let region = profile?.region, region.isEmpty == false {
                    ProfileInfoLine(title: L10n.region, value: region)
                }
                if let job = profile?.job, job.isEmpty == false {
                    ProfileInfoLine(title: L10n.job, value: job)
                }
            }
            .padding(14)
            .keiPanel(14)
        }
    }

    @ViewBuilder
    private var workspaceSection: some View {
        if let workspace = detail?.workspace {
            let entries = workspace.infoEntries
            let comment = workspace.trimmedComment

            if entries.isEmpty == false || comment != nil {
                VStack(alignment: .leading, spacing: 10) {
                    Label(L10n.workspace, systemImage: "paintbrush.pointed")
                        .font(.headline)

                    ForEach(entries, id: \.title) { entry in
                        ProfileInfoLine(title: entry.title, value: entry.value)
                    }

                    if let comment {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(L10n.workspaceComment)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(comment)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                                .textSelection(.enabled)
                        }
                    }
                }
                .padding(14)
                .keiPanel(14)
            }
        }
    }

    private var profileCollectionShortcuts: some View {
        let profile = detail?.profile
        return VStack(alignment: .leading, spacing: 10) {
            Label(L10n.creatorCollections, systemImage: "rectangle.stack")
                .font(.headline)

            LazyVGrid(columns: profileShortcutColumns, alignment: .leading, spacing: 10) {
                ProfileCollectionShortcutButton(
                    title: L10n.creatorIllustrations,
                    value: (profile?.totalIllusts ?? 0).formatted(),
                    detail: L10n.openCreatorCollection,
                    systemImage: "photo.on.rectangle"
                ) {
                    openFeed(.userIllustrations)
                }

                ProfileCollectionShortcutButton(
                    title: L10n.creatorManga,
                    value: (profile?.totalManga ?? 0).formatted(),
                    detail: L10n.openCreatorCollection,
                    systemImage: "book.closed"
                ) {
                    openFeed(.userManga)
                }

                ProfileCollectionShortcutButton(
                    title: L10n.creatorPublicBookmarks,
                    value: (profile?.totalIllustBookmarksPublic ?? 0).formatted(),
                    detail: L10n.openCreatorCollection,
                    systemImage: "bookmark"
                ) {
                    openFeed(.userPublicBookmarks)
                }

                ProfileCollectionShortcutButton(
                    title: L10n.followers,
                    value: (profile?.totalFollowUsers ?? 0).formatted(),
                    detail: L10n.openCreatorNetwork,
                    systemImage: "person.2"
                ) {
                    relationshipListMode = .userFollowers(detail?.user ?? user)
                }

                ProfileCollectionShortcutButton(
                    title: L10n.followingCreators,
                    value: L10n.open,
                    detail: L10n.openCreatorNetwork,
                    systemImage: "person.2.crop.square.stack"
                ) {
                    relationshipListMode = .userFollowing(detail?.user ?? user)
                }

                ProfileCollectionShortcutButton(
                    title: L10n.relatedCreators,
                    value: relatedUsers.isEmpty ? L10n.open : "\(relatedUsers.count.formatted())+",
                    detail: L10n.openCreatorNetwork,
                    systemImage: "person.3"
                ) {
                    relationshipListMode = .related(detail?.user ?? user)
                }
                .disabled(isLoadingRelatedUsers)
            }
        }
        .padding(14)
        .keiPanel(14)
    }

    private var profileShortcutColumns: [GridItem] {
        [
            GridItem(.adaptive(minimum: 158, maximum: 240), spacing: 10, alignment: .top)
        ]
    }

    private var currentUser: PixivUser {
        detail?.user ?? user
    }

    private func openFeed(_ route: PixivRoute) {
        Task {
            await store.openUserFeed(user: currentUser, route: route)
            dismiss()
        }
    }

    @ViewBuilder
    private var relatedCreatorSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(L10n.relatedCreators, systemImage: "person.2.crop.square.stack")
                    .font(.headline)

                Spacer()

                if relatedUsers.isEmpty == false {
                    Button {
                        relationshipListMode = .related(detail?.user ?? user)
                    } label: {
                        Label(L10n.viewAllRelatedCreators, systemImage: "arrow.right.circle")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

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
                                    selectedRelatedUser = preview.user
                                },
                                openIllustrations: {
                                    Task {
                                        await store.openUserFeed(user: preview.user, route: .userIllustrations)
                                        dismiss()
                                    }
                                },
                                toggleFollow: {
                                    restrict in
                                    Task { await toggleRelatedFollow(preview.user, restrict: restrict) }
                                }
                            )
                        }
                    }
                    .padding(.vertical, 2)
                }
                .scrollIndicators(.hidden)
            }

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

    private func loadDetail() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let loaded = try await store.userDetail(for: user)
            detail = loaded
            isFollowed = loaded.user.isFollowed
            if loaded.user.isFollowed {
                await loadFollowDetail()
            } else {
                followRestrict = nil
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadFollowDetail() async {
        do {
            let followDetail = try await store.followDetail(for: detail?.user ?? user)
            isFollowed = followDetail.isFollowed
            followRestrict = followDetail.isFollowed ? followDetail.restrictValue : nil
        } catch {
            followRestrict = nil
        }
    }

    private func loadRelatedUsers() async {
        isLoadingRelatedUsers = true
        relatedErrorMessage = nil
        defer { isLoadingRelatedUsers = false }

        do {
            let response = try await store.relatedUsers(for: user)
            relatedUsers = response.userPreviews.filter { $0.user.id != user.id }
        } catch {
            relatedErrorMessage = error.localizedDescription
        }
    }

    private func toggleFollow(restrict: BookmarkRestrict? = nil) async {
        var target = detail?.user ?? user
        target.isFollowed = isFollowed
        await store.toggleFollow(target, restrict: restrict)
        let appliedRestrict = restrict ?? store.defaultFollowRestrict
        isFollowed.toggle()
        followRestrict = isFollowed ? appliedRestrict : nil
    }

    private func updateFollowVisibility(_ restrict: BookmarkRestrict) async {
        var target = detail?.user ?? user
        target.isFollowed = false
        await store.toggleFollow(target, restrict: restrict)
        isFollowed = true
        followRestrict = restrict
    }

    private func toggleRelatedFollow(_ user: PixivUser, restrict: BookmarkRestrict? = nil) async {
        await store.toggleFollow(user, restrict: restrict)
        for index in relatedUsers.indices where relatedUsers[index].user.id == user.id {
            var updatedUser = relatedUsers[index].user
            updatedUser.isFollowed.toggle()
            relatedUsers[index] = PixivUserPreview(
                user: updatedUser,
                illusts: relatedUsers[index].illusts,
                isMuted: relatedUsers[index].isMuted
            )
        }
    }
}

private struct RelatedCreatorCard: View {
    let preview: PixivUserPreview
    let openProfile: () -> Void
    let openIllustrations: () -> Void
    let toggleFollow: (BookmarkRestrict?) -> Void

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
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            HStack(spacing: 6) {
                ForEach(preview.illusts.prefix(2)) { artwork in
                    Button(action: openIllustrations) {
                        RemoteImageView(url: artwork.thumbnailURL)
                            .aspectRatio(1, contentMode: .fill)
                            .frame(width: 56, height: 56)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: 8) {
                if preview.user.isFollowed {
                    Button(L10n.unfollow) {
                        toggleFollow(nil)
                    }
                    .buttonStyle(.bordered)
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
    }
}

private struct ProfileMetric: View {
    let title: String
    let value: Int
    let systemImage: String

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(value.formatted())
                    .font(.headline)
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 100, alignment: .leading)
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

private struct ProfileInfoLine: View {
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption)
        }
    }
}

private extension PixivUserWorkspace {
    var infoEntries: [(title: String, value: String)] {
        [
            (L10n.tool, tool),
            (L10n.tablet, tablet),
            (L10n.mouse, mouse)
        ].compactMap { title, value in
            guard let trimmed = value?.trimmedNonEmpty else { return nil }
            return (title, trimmed)
        }
    }

    var trimmedComment: String? {
        comment?.htmlStripped.trimmedNonEmpty
    }
}

private extension String {
    var trimmedNonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
