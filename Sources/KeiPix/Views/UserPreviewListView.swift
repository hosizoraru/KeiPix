import SwiftUI

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
    @State private var creatorSearchText = ""
    @State private var creatorFilter: CreatorListFilter = .all
    @State private var creatorSort: CreatorListSort = .defaultOrder
    @State private var pendingBulkAction: CreatorBulkAction?
    @State private var isShowingBulkConfirmation = false
    @State private var isRunningBulkAction = false
    @State private var isCheckingFollowVisibility = false
    @State private var followRestrictsByUserID: [Int: BookmarkRestrict] = [:]
    @State private var bulkStatusText: String?

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
            } else if mode.requiresSearchKeyword, searchKeyword.isEmpty {
                ContentUnavailableView(L10n.enterSearchKeyword, systemImage: "magnifyingglass")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if previews.isEmpty {
                ContentUnavailableView(L10n.noCreators, systemImage: "person.2")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                        Section {
                            Group {
                                if visiblePreviews.isEmpty {
                                    VStack(spacing: 14) {
                                        ContentUnavailableView(L10n.noMatchingCreators, systemImage: "person.crop.circle.badge.questionmark")
                                            .frame(maxWidth: .infinity)
                                            .frame(minHeight: 260)

                                        if nextURL != nil {
                                            loadMoreButton
                                                .frame(maxWidth: 420)
                                        }
                                    }
                                } else {
                                    LazyVGrid(columns: columns, spacing: 14) {
                                        ForEach(visiblePreviews) { preview in
                                            UserPreviewCard(
                                                preview: preview,
                                                followRestrict: followRestrictsByUserID[preview.user.id],
                                                showContentBadges: store.showContentBadges,
                                                openProfile: { profileUser = preview.user },
                                                openIllustrations: {
                                                    Task { await store.openUserFeed(user: preview.user, route: .userIllustrations) }
                                                },
                                                openManga: {
                                                    Task { await store.openUserFeed(user: preview.user, route: .userManga) }
                                                },
                                                toggleFollow: { restrict in
                                                    Task { await toggleFollow(preview.user, restrict: restrict) }
                                                },
                                                muteCreator: {
                                                    muteCreator(preview.user)
                                                },
                                                copyCreatorLink: {
                                                    copyCreatorLink(preview.user)
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
        .safeAreaInset(edge: .bottom) {
            if errorMessage != nil || bulkStatusText != nil || isRunningBulkAction || isCheckingFollowVisibility {
                VStack(alignment: .leading, spacing: 6) {
                    if isCheckingFollowVisibility {
                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                            Text(L10n.checkingFollowVisibility)
                        }
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    }

                    if isRunningBulkAction {
                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                            Text(L10n.runningCreatorAction)
                        }
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    }

                    if let bulkStatusText {
                        Text(bulkStatusText)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.callout)
                            .foregroundStyle(.red)
                            .textSelection(.enabled)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.bar)
            }
        }
        .confirmationDialog(
            pendingBulkAction?.title ?? L10n.creatorActions,
            isPresented: $isShowingBulkConfirmation,
            titleVisibility: .visible,
            presenting: pendingBulkAction
        ) { action in
            Button(action.title, role: action.role) {
                Task { await performBulkAction(action) }
            }
            Button(L10n.cancel, role: .cancel) {
                pendingBulkAction = nil
            }
        } message: { action in
            Text(action.confirmationMessage(count: bulkActionTargetCount(action)))
        }
        .sheet(item: $profileUser) { user in
            UserProfileSheet(user: user, store: store)
        }
        .task(id: modeKey) {
            await loadInitial()
        }
    }

    private var visibleFollowedPreviews: [PixivUserPreview] {
        visiblePreviews.filter(\.user.isFollowed)
    }

    private var hasActiveCreatorListState: Bool {
        creatorSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            || creatorFilter != .all
            || creatorSort != .defaultOrder
    }

    private var visiblePreviews: [PixivUserPreview] {
        let normalizedQuery = creatorSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let filtered = previews.filter { preview in
            let matchesQuery = normalizedQuery.isEmpty || preview.matchesCreatorQuery(normalizedQuery)
            guard matchesQuery else { return false }

            switch creatorFilter {
            case .all:
                return true
            case .followed:
                return preview.user.isFollowed
            case .unfollowed:
                return preview.user.isFollowed == false
            case .muted:
                return preview.isMuted
            }
        }

        switch creatorSort {
        case .defaultOrder:
            return filtered
        case .name:
            return filtered.sorted { $0.user.name.localizedStandardCompare($1.user.name) == .orderedAscending }
        case .account:
            return filtered.sorted { $0.user.account.localizedStandardCompare($1.user.account) == .orderedAscending }
        case .previewWorks:
            return filtered.sorted { lhs, rhs in
                if lhs.illusts.count == rhs.illusts.count {
                    return lhs.user.name.localizedStandardCompare(rhs.user.name) == .orderedAscending
                }
                return lhs.illusts.count > rhs.illusts.count
            }
        case .followState:
            return filtered.sorted { lhs, rhs in
                if lhs.user.isFollowed == rhs.user.isFollowed {
                    return lhs.user.name.localizedStandardCompare(rhs.user.name) == .orderedAscending
                }
                return lhs.user.isFollowed && rhs.user.isFollowed == false
            }
        }
    }

    private var searchKeyword: String {
        store.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var modeKey: String {
        "\(mode.key)-\(restrict.rawValue)-\(store.searchSubmissionID)"
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(mode.title)
                        .font(.headline)
                    Text(headerSubtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if visiblePreviews.isEmpty == false {
                        CreatorListSummaryStrip(previews: visiblePreviews)
                    }
                }

                Spacer()

                if mode.usesRestrictPicker {
                    Picker(L10n.followingCreators, selection: restrictBinding) {
                        Text(L10n.publicRestrict).tag(BookmarkRestrict.public)
                        Text(L10n.privateRestrict).tag(BookmarkRestrict.private)
                    }
                    .pickerStyle(.segmented)
                    .controlSize(.small)
                    .frame(width: 160)
                }
            }

            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField(L10n.searchCreatorsInList, text: $creatorSearchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 240)

                Picker(L10n.creatorFilter, selection: $creatorFilter) {
                    ForEach(CreatorListFilter.allCases) { filter in
                        Text(filter.title).tag(filter)
                    }
                }
                .pickerStyle(.menu)
                .help(L10n.creatorFilter)

                Picker(L10n.creatorSort, selection: $creatorSort) {
                    ForEach(CreatorListSort.allCases) { sort in
                        Text(sort.title).tag(sort)
                    }
                }
                .pickerStyle(.menu)
                .help(L10n.creatorSort)

                creatorActionsMenu

                Button {
                    Task { await loadInitial() }
                } label: {
                    Label(L10n.refresh, systemImage: "arrow.clockwise")
                }
                .labelStyle(.iconOnly)
                .help(L10n.refresh)
                .disabled(isLoading)

                Spacer(minLength: 0)
            }
        }
    }

    private var creatorActionsMenu: some View {
        Menu {
            Button {
                Task { await checkVisibleFollowVisibility() }
            } label: {
                Label(L10n.checkFollowVisibility, systemImage: "checkmark.seal")
            }
            .disabled(isCheckingFollowVisibility || visibleFollowedPreviews.isEmpty)

            Divider()

            Button {
                resetCreatorListState()
            } label: {
                Label(L10n.resetCreatorFilters, systemImage: "arrow.counterclockwise")
            }
            .disabled(hasActiveCreatorListState == false)

            Divider()

            Button {
                copyVisibleCreatorLinks()
            } label: {
                Label(L10n.copyVisibleCreatorLinks, systemImage: "link")
            }
            .disabled(visiblePreviews.isEmpty)

            Button {
                copyVisibleCreatorSummary()
            } label: {
                Label(L10n.copyVisibleCreatorSummary, systemImage: "doc.text")
            }
            .disabled(visiblePreviews.isEmpty)

            Divider()

            Button {
                requestBulkAction(.followPublic)
            } label: {
                Label(L10n.followVisiblePublicly, systemImage: "person.crop.circle.badge.plus")
            }
            .disabled(isRunningBulkAction || bulkActionTargetCount(.followPublic) == 0)

            Button {
                requestBulkAction(.followPrivate)
            } label: {
                Label(L10n.followVisiblePrivately, systemImage: "lock.circle")
            }
            .disabled(isRunningBulkAction || bulkActionTargetCount(.followPrivate) == 0)

            Divider()

            Button(role: .destructive) {
                requestBulkAction(.mute)
            } label: {
                Label(L10n.muteVisibleCreators, systemImage: "eye.slash")
            }
            .disabled(isRunningBulkAction || bulkActionTargetCount(.mute) == 0)

            Button(role: .destructive) {
                requestBulkAction(.unfollow)
            } label: {
                Label(L10n.unfollowVisibleCreators, systemImage: "person.crop.circle.badge.minus")
            }
            .disabled(isRunningBulkAction || bulkActionTargetCount(.unfollow) == 0)
        } label: {
            if isRunningBulkAction {
                ProgressView()
                    .controlSize(.small)
            } else {
                Label(L10n.creatorActions, systemImage: "slider.horizontal.3")
            }
        }
        .help(L10n.creatorActions)
        .disabled(visiblePreviews.isEmpty)
    }

    private var headerSubtitle: String {
        let pagingText = nextURL == nil ? L10n.noMorePages : L10n.nextPageAvailable
        let shownText = "\(visiblePreviews.count.formatted()) / \(previews.count.formatted()) \(L10n.results)"
        if mode.requiresSearchKeyword, searchKeyword.isEmpty == false {
            return "\(searchKeyword) · \(shownText) · \(pagingText)"
        }
        return "\(shownText) · \(pagingText)"
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

    private func requestBulkAction(_ action: CreatorBulkAction) {
        pendingBulkAction = action
        isShowingBulkConfirmation = true
    }

    private func resetCreatorListState() {
        creatorSearchText = ""
        creatorFilter = .all
        creatorSort = .defaultOrder
    }

    private func bulkActionTargetCount(_ action: CreatorBulkAction) -> Int {
        bulkActionTargets(action).count
    }

    private func bulkActionTargets(_ action: CreatorBulkAction) -> [PixivUserPreview] {
        switch action {
        case .followPublic, .followPrivate:
            visiblePreviews.filter { $0.user.isFollowed == false }
        case .mute:
            visiblePreviews.filter { $0.isMuted == false }
        case .unfollow:
            visiblePreviews.filter(\.user.isFollowed)
        }
    }

    private func performBulkAction(_ action: CreatorBulkAction) async {
        let targets = bulkActionTargets(action)
        guard targets.isEmpty == false else {
            pendingBulkAction = nil
            return
        }

        isRunningBulkAction = true
        bulkStatusText = nil
        defer {
            isRunningBulkAction = false
            pendingBulkAction = nil
        }

        switch action {
        case .followPublic:
            await followCreators(targets, restrict: .public)
        case .followPrivate:
            await followCreators(targets, restrict: .private)
        case .mute:
            for target in targets {
                store.muteUser(target.user)
                updateMutedState(userID: target.user.id, isMuted: true)
            }
        case .unfollow:
            await unfollowCreators(targets)
        }

        bulkStatusText = String(format: L10n.creatorActionCompletedFormat, targets.count)
    }

    private func followCreators(_ targets: [PixivUserPreview], restrict: BookmarkRestrict) async {
        for target in targets {
            var user = target.user
            user.isFollowed = false
            await store.toggleFollow(user, restrict: restrict)
            updateFollowState(userID: user.id, isFollowed: true, restrict: restrict)
        }
    }

    private func unfollowCreators(_ targets: [PixivUserPreview]) async {
        for target in targets {
            var user = target.user
            user.isFollowed = true
            await store.toggleFollow(user)
            updateFollowState(userID: user.id, isFollowed: false, restrict: nil)
        }
    }

    private func checkVisibleFollowVisibility() async {
        let targets = visibleFollowedPreviews
        guard targets.isEmpty == false else { return }

        isCheckingFollowVisibility = true
        bulkStatusText = nil
        defer { isCheckingFollowVisibility = false }

        var updatedCount = 0
        var failedCount = 0

        for target in targets {
            do {
                let detail = try await store.followDetail(for: target.user)
                if detail.isFollowed {
                    followRestrictsByUserID[target.user.id] = detail.restrictValue
                    updatedCount += 1
                } else {
                    updateFollowState(userID: target.user.id, isFollowed: false, restrict: nil)
                    updatedCount += 1
                }
            } catch {
                failedCount += 1
                errorMessage = error.localizedDescription
            }
        }

        if failedCount == 0 {
            bulkStatusText = String(format: L10n.followVisibilityUpdatedFormat, updatedCount)
        } else {
            bulkStatusText = String(format: L10n.followVisibilityPartiallyUpdatedFormat, updatedCount, failedCount)
        }
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
            case .userFollowing(let user):
                try await store.followingUsers(for: user, restrict: restrict)
            case .userFollowers(let user):
                try await store.followerUsers(for: user, restrict: restrict)
            case .related(let user):
                try await store.relatedUsers(for: user)
            }
            previews = response.userPreviews
            followRestrictsByUserID = inferredFollowRestricts(for: response.userPreviews)
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
            followRestrictsByUserID.merge(inferredFollowRestricts(for: response.userPreviews)) { _, new in new }
            self.nextURL = response.nextURL
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func toggleFollow(_ user: PixivUser, restrict: BookmarkRestrict? = nil) async {
        await store.toggleFollow(user, restrict: restrict)
        let nextValue = !user.isFollowed
        let appliedRestrict = nextValue ? (restrict ?? store.defaultFollowRestrict) : nil
        updateFollowState(userID: user.id, isFollowed: nextValue, restrict: appliedRestrict)
    }

    private func muteCreator(_ user: PixivUser) {
        store.muteUser(user)
        updateMutedState(userID: user.id, isMuted: true)
    }

    private func copyCreatorLink(_ user: PixivUser) {
        guard let url = user.pixivURL else { return }
        PasteboardWriter.copy(url.absoluteString)
        bulkStatusText = String(format: L10n.copiedCreatorLinksFormat, 1)
    }

    private func copyVisibleCreatorLinks() {
        let links = visiblePreviews.compactMap { $0.user.pixivURL?.absoluteString }
        guard links.isEmpty == false else { return }
        PasteboardWriter.copy(links.joined(separator: "\n"))
        bulkStatusText = String(format: L10n.copiedCreatorLinksFormat, links.count)
    }

    private func copyVisibleCreatorSummary() {
        let summaries = visiblePreviews.map { preview in
            let user = preview.user
            let url = user.pixivURL?.absoluteString ?? ""
            return "\(user.name)\t@\(user.account)\t\(user.id)\t\(url)"
        }
        guard summaries.isEmpty == false else { return }
        PasteboardWriter.copy(summaries.joined(separator: "\n"))
        bulkStatusText = String(format: L10n.copiedCreatorSummaryFormat, summaries.count)
    }

    private func updateFollowState(userID: Int, isFollowed: Bool, restrict: BookmarkRestrict?) {
        for index in previews.indices where previews[index].user.id == userID {
            var updatedUser = previews[index].user
            updatedUser.isFollowed = isFollowed
            previews[index] = PixivUserPreview(user: updatedUser, illusts: previews[index].illusts, isMuted: previews[index].isMuted)
        }

        if isFollowed, let restrict {
            followRestrictsByUserID[userID] = restrict
        } else if isFollowed == false {
            followRestrictsByUserID[userID] = nil
        }
    }

    private func updateMutedState(userID: Int, isMuted: Bool) {
        for index in previews.indices where previews[index].user.id == userID {
            previews[index] = PixivUserPreview(user: previews[index].user, illusts: previews[index].illusts, isMuted: isMuted)
        }
    }

    private func inferredFollowRestricts(for userPreviews: [PixivUserPreview]) -> [Int: BookmarkRestrict] {
        guard mode.infersFollowRestrictFromPicker else { return [:] }
        return Dictionary(uniqueKeysWithValues: userPreviews.compactMap { preview in
            preview.user.isFollowed ? (preview.user.id, restrict) : nil
        })
    }
}

private struct UserPreviewCard: View {
    let preview: PixivUserPreview
    let followRestrict: BookmarkRestrict?
    let showContentBadges: Bool
    let openProfile: () -> Void
    let openIllustrations: () -> Void
    let openManga: () -> Void
    let toggleFollow: (BookmarkRestrict?) -> Void
    let muteCreator: () -> Void
    let copyCreatorLink: () -> Void
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

                if preview.isMuted {
                    Label(L10n.muted, systemImage: "eye.slash")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .foregroundStyle(.secondary)
                        .background(.quaternary, in: Capsule())
                }

                if preview.user.isFollowed, let followRestrict {
                    Label(followRestrict.creatorVisibilityTitle, systemImage: followRestrict.creatorVisibilitySystemImage)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .foregroundStyle(.secondary)
                        .background(.quaternary, in: Capsule())
                }

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
                        .contextMenu {
                            Button(L10n.selectArtwork) {
                                selectArtwork(artwork)
                            }

                            if let url = artwork.pixivURL {
                                Link(L10n.openInPixiv, destination: url)
                                Button(L10n.copyLink) {
                                    PasteboardWriter.copy(url.absoluteString)
                                }
                            }
                        }
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

                Spacer()

                Button(role: .destructive) {
                    muteCreator()
                } label: {
                    Label(L10n.muteCreator, systemImage: "eye.slash")
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.bordered)
                .help(L10n.muteCreator)
            }
        }
        .padding(12)
        .keiInteractiveGlass(16)
        .contextMenu {
            Button(L10n.creatorProfile) {
                openProfile()
            }
            if let url = preview.user.pixivURL {
                Link(L10n.openInPixiv, destination: url)
            }
            Button(L10n.copyLink) {
                copyCreatorLink()
            }
            if preview.user.isFollowed {
                Button(L10n.unfollow) {
                    toggleFollow(nil)
                }
            } else {
                Button(L10n.followUsingDefault) {
                    toggleFollow(nil)
                }
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
            Divider()
            Button(role: .destructive) {
                muteCreator()
            } label: {
                Label(L10n.muteCreator, systemImage: "eye.slash")
            }
        }
    }
}

private struct ArtworkPreviewThumb: View {
    let artwork: PixivArtwork
    let showContentBadges: Bool
    private let thumbnailHeight: CGFloat = 132

    var body: some View {
        ZStack(alignment: .topLeading) {
            RemoteImageView(url: artwork.thumbnailURL, contentMode: .fill)
                .frame(maxWidth: .infinity)
                .frame(height: thumbnailHeight)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            if showContentBadges {
                ArtworkContentBadgesView(badges: artwork.contentBadges, style: .overlay)
                    .padding(6)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: thumbnailHeight)
    }
}
