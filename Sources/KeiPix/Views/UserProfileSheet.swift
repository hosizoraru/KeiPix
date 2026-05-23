import SwiftUI

struct UserProfileSheet: View {
    let user: PixivUser
    @Bindable var store: KeiPixStore

    @Environment(\.dismiss) private var dismiss
    @State private var detail: PixivUserDetail?
    @State private var isLoading = true
    @State private var isFollowed: Bool
    @State private var errorMessage: String?

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
                        comment
                        links
                        feedActions
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

                if isFollowed {
                    Button(L10n.unfollow) {
                        Task { await toggleFollow() }
                    }
                    .buttonStyle(.bordered)
                    .disabled(isLoading)
                } else {
                    Button(L10n.follow) {
                        Task { await toggleFollow() }
                    }
                    .buttonStyle(.glassProminent)
                    .disabled(isLoading)
                }
            }
            .padding(20)
        }
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
            ("Pixiv", URL(string: "https://www.pixiv.net/users/\(user.id)")),
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

    private var feedActions: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(L10n.works, systemImage: "rectangle.stack")
                .font(.headline)

            HStack(spacing: 10) {
                feedButton(L10n.creatorIllustrations, systemImage: "photo.on.rectangle", route: .userIllustrations)
                feedButton(L10n.creatorManga, systemImage: "book.closed", route: .userManga)
                feedButton(L10n.creatorPublicBookmarks, systemImage: "bookmark", route: .userPublicBookmarks)
            }
        }
        .padding(14)
        .keiPanel(14)
    }

    private func feedButton(_ title: String, systemImage: String, route: PixivRoute) -> some View {
        Button {
            Task {
                await store.openUserFeed(user: detail?.user ?? user, route: route)
                dismiss()
            }
        } label: {
            Label(title, systemImage: systemImage)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
    }

    private func loadDetail() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let loaded = try await store.userDetail(for: user)
            detail = loaded
            isFollowed = loaded.user.isFollowed
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func toggleFollow() async {
        var target = detail?.user ?? user
        target.isFollowed = isFollowed
        await store.toggleFollow(target)
        isFollowed.toggle()
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
