import SwiftUI

enum UserPreviewListMode {
    case recommended
    case following
    case search

    var title: String {
        switch self {
        case .recommended: L10n.recommendedCreators
        case .following: L10n.followingCreators
        case .search: L10n.searchCreators
        }
    }
}

struct UserPreviewListView: View {
    @Bindable var store: KeiPixStore
    let mode: UserPreviewListMode

    @State private var previews: [PixivUserPreview] = []
    @State private var nextURL: URL?
    @State private var restrict: BookmarkRestrict = .public
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var profileUser: PixivUser?
    @State private var errorMessage: String?

    private let columns = [
        GridItem(.adaptive(minimum: 360, maximum: 520), spacing: 14)
    ]

    var body: some View {
        Group {
            if store.session == nil {
                EmptyStateView(title: L10n.signedOutTitle, subtitle: L10n.signedOutSubtitle, systemImage: "person.crop.circle.badge.exclamationmark")
            } else if isLoading {
                ProgressView(L10n.loading)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if mode == .search, searchKeyword.isEmpty {
                ContentUnavailableView(L10n.enterSearchKeyword, systemImage: "magnifyingglass")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if previews.isEmpty {
                ContentUnavailableView(L10n.noCreators, systemImage: "person.2")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                        Section {
                            LazyVGrid(columns: columns, spacing: 14) {
                                ForEach(previews) { preview in
                                    UserPreviewCard(
                                        preview: preview,
                                        showContentBadges: store.showContentBadges,
                                        openProfile: { profileUser = preview.user },
                                        openIllustrations: {
                                            Task { await store.openUserFeed(user: preview.user, route: .userIllustrations) }
                                        },
                                        openManga: {
                                            Task { await store.openUserFeed(user: preview.user, route: .userManga) }
                                        },
                                        toggleFollow: {
                                            restrict in
                                            Task { await toggleFollow(preview.user, restrict: restrict) }
                                        },
                                        selectArtwork: { artwork in
                                            store.selectedArtwork = artwork
                                        }
                                    )
                                }

                                if nextURL != nil {
                                    loadMoreButton
                                }
                            }
                            .padding(.horizontal, 18)
                            .padding(.top, 14)
                            .padding(.bottom, 20)
                        } header: {
                            header
                                .padding(.horizontal, 18)
                                .padding(.vertical, 10)
                                .background(.bar)
                        }
                    }
                }
                .scrollEdgeEffectStyle(.soft, for: .top)
            }
        }
        .navigationTitle(mode.title)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await loadInitial() }
                } label: {
                    Label(L10n.refresh, systemImage: "arrow.clockwise")
                }
                .disabled(isLoading)
            }
        }
        .safeAreaInset(edge: .bottom) {
            if let errorMessage {
                Text(errorMessage)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
                    .padding(12)
                    .frame(maxWidth: .infinity)
                    .background(.bar)
            }
        }
        .sheet(item: $profileUser) { user in
            UserProfileSheet(user: user, store: store)
        }
        .task(id: modeKey) {
            await loadInitial()
        }
    }

    private var searchKeyword: String {
        store.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var modeKey: String {
        "\(mode.title)-\(restrict.rawValue)-\(store.searchSubmissionID)"
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(mode.title)
                    .font(.headline)
                Text(headerSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if mode == .following {
                Picker(L10n.followingCreators, selection: restrictBinding) {
                    Text(L10n.publicRestrict).tag(BookmarkRestrict.public)
                    Text(L10n.privateRestrict).tag(BookmarkRestrict.private)
                }
                .pickerStyle(.segmented)
                .controlSize(.small)
                .frame(width: 160)
            }
        }
    }

    private var headerSubtitle: String {
        let pagingText = nextURL == nil ? L10n.noMorePages : L10n.nextPageAvailable
        if mode == .search, searchKeyword.isEmpty == false {
            return "\(searchKeyword) · \(previews.count.formatted()) \(L10n.results) · \(pagingText)"
        }
        return "\(previews.count.formatted()) \(L10n.results) · \(pagingText)"
    }

    private var restrictBinding: Binding<BookmarkRestrict> {
        Binding {
            restrict
        } set: { value in
            restrict = value
        }
    }

    private var loadMoreButton: some View {
        Button {
            Task { await loadMore() }
        } label: {
            VStack(spacing: 8) {
                if isLoadingMore {
                    ProgressView()
                } else {
                    Image(systemName: "arrow.down.circle")
                        .font(.title3)
                    Text(L10n.loadMoreCreators)
                        .font(.caption.weight(.medium))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 160)
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .keiInteractiveGlass(16)
        .disabled(isLoadingMore)
    }

    private func loadInitial() async {
        guard store.session != nil else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let response: PixivUserPreviewResponse = switch mode {
            case .recommended:
                try await store.recommendedUsers()
            case .following:
                try await store.followingUsers(restrict: restrict)
            case .search:
                try await store.searchUsers(keyword: searchKeyword)
            }
            previews = response.userPreviews
            nextURL = response.nextURL
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadMore() async {
        guard let nextURL else { return }
        isLoadingMore = true
        errorMessage = nil
        defer { isLoadingMore = false }

        do {
            let response = try await store.nextUserPreviews(nextURL)
            previews.append(contentsOf: response.userPreviews)
            self.nextURL = response.nextURL
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func toggleFollow(_ user: PixivUser, restrict: BookmarkRestrict = .public) async {
        await store.toggleFollow(user, restrict: restrict)
        for index in previews.indices where previews[index].user.id == user.id {
            var updatedUser = previews[index].user
            updatedUser.isFollowed.toggle()
            previews[index] = PixivUserPreview(user: updatedUser, illusts: previews[index].illusts, isMuted: previews[index].isMuted)
        }
    }
}

private struct UserPreviewCard: View {
    let preview: PixivUserPreview
    let showContentBadges: Bool
    let openProfile: () -> Void
    let openIllustrations: () -> Void
    let openManga: () -> Void
    let toggleFollow: (BookmarkRestrict) -> Void
    let selectArtwork: (PixivArtwork) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                RemoteImageView(url: preview.user.avatarURL)
                    .frame(width: 54, height: 54)
                    .clipShape(Circle())
                    .overlay {
                        Circle().stroke(.quaternary, lineWidth: 1)
                    }

                VStack(alignment: .leading, spacing: 3) {
                    Text(preview.user.name)
                        .font(.headline)
                        .lineLimit(1)
                    Text("@\(preview.user.account)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                if preview.user.isFollowed {
                    Button(L10n.unfollow) {
                        toggleFollow(.public)
                    }
                    .buttonStyle(.bordered)
                } else {
                    Menu {
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
            }

            if preview.illusts.isEmpty == false {
                HStack(spacing: 8) {
                    ForEach(preview.illusts.prefix(3)) { artwork in
                        Button {
                            selectArtwork(artwork)
                        } label: {
                            ArtworkPreviewThumb(artwork: artwork, showContentBadges: showContentBadges)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            HStack(spacing: 8) {
                Button {
                    openProfile()
                } label: {
                    Label(L10n.creatorProfile, systemImage: "person.crop.circle")
                }
                .buttonStyle(.bordered)

                Button {
                    openIllustrations()
                } label: {
                    Label(L10n.illustrations, systemImage: "photo")
                }
                .buttonStyle(.bordered)

                Button {
                    openManga()
                } label: {
                    Label(L10n.manga, systemImage: "book.closed")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(12)
        .keiInteractiveGlass(16)
        .contextMenu {
            Button(L10n.creatorProfile) {
                openProfile()
            }
            if preview.user.isFollowed {
                Button(L10n.unfollow) {
                    toggleFollow(.public)
                }
            } else {
                Button(L10n.followPublicly) {
                    toggleFollow(.public)
                }
                Button(L10n.followPrivately) {
                    toggleFollow(.private)
                }
            }
            Divider()
            Button(L10n.creatorIllustrations) {
                openIllustrations()
            }
            Button(L10n.creatorManga) {
                openManga()
            }
        }
    }
}

private struct ArtworkPreviewThumb: View {
    let artwork: PixivArtwork
    let showContentBadges: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            RemoteImageView(url: artwork.thumbnailURL)
                .aspectRatio(1, contentMode: .fill)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            if showContentBadges {
                ArtworkContentBadgesView(badges: artwork.contentBadges, style: .overlay)
                    .padding(6)
            }
        }
        .frame(maxWidth: .infinity)
    }
}
