import SwiftUI

struct UserPreviewListView: View {
    @Bindable var store: KeiPixStore
    let mode: UserPreviewListMode
    @Environment(\.undoManager) private var undoManager

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
    @State private var updatingCreatorIDs = Set<Int>()
    @State private var bulkStatusText: String?
    @State private var pendingDangerAction: CreatorDangerAction?
    @State private var undoAction: CreatorUndoAction?

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
            } else {
                creatorListSurface
            }
        }
        .navigationTitle(mode.title)
        .toolbar {
            ToolbarItem(placement: .status) {
                Text(headerSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .help(headerDetail)
            }
        }
        .overlay(alignment: .bottom) {
            if isStatusBannerVisible {
                FloatingStatusBanner {
                    VStack(alignment: .leading, spacing: 6) {
                        if let undoAction {
                            HStack(spacing: 10) {
                                Text(undoAction.message)
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)

                                Spacer()

                                Button(L10n.undo) {
                                    Task { await performUndo(undoAction) }
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }

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
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 14)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.snappy(duration: 0.18), value: isStatusBannerVisible)
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
        .confirmationDialog(
            pendingDangerAction?.title ?? L10n.creatorActions,
            isPresented: dangerConfirmationBinding,
            titleVisibility: .visible,
            presenting: pendingDangerAction
        ) { action in
            Button(action.title, role: .destructive) {
                Task { await performDangerAction(action) }
            }
            Button(L10n.cancel, role: .cancel) {
                pendingDangerAction = nil
            }
        } message: { action in
            Text(action.confirmationMessage)
        }
        .sheet(item: $profileUser) { user in
            UserProfileSheet(user: user, store: store)
        }
        .task(id: listRefreshKey) {
            await loadInitial()
        }
        .task(id: bulkStatusText) {
            await dismissBulkStatusTextIfNeeded(bulkStatusText)
        }
    }

    private var creatorListSurface: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 18)
                .padding(.vertical, 6)
                .background(.bar)

            Divider()

            creatorListContent
        }
    }

    @ViewBuilder
    private var creatorListContent: some View {
        if mode.requiresSearchKeyword, searchKeyword.isEmpty {
            ContentUnavailableView(L10n.enterSearchKeyword, systemImage: "magnifyingglass")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if previews.isEmpty {
            if let errorMessage {
                ContentUnavailableView {
                    Label(L10n.errorTitle, systemImage: "exclamationmark.triangle")
                } description: {
                    Text(errorMessage)
                } actions: {
                    Button {
                        Task { await loadInitial() }
                    } label: {
                        Label(L10n.retry, systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ContentUnavailableView(L10n.noCreators, systemImage: "person.2")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        } else {
            ScrollView {
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
                                    isUpdating: updatingCreatorIDs.contains(preview.user.id),
                                    showContentBadges: store.showContentBadges,
                                    openProfile: { profileUser = preview.user },
                                    openIllustrations: {
                                        Task { await store.openUserFeed(user: preview.user, route: .userIllustrations) }
                                    },
                                    openManga: {
                                        Task { await store.openUserFeed(user: preview.user, route: .userManga) }
                                    },
                                    followCreator: { restrict in
                                        Task { await follow(preview.user, restrict: restrict) }
                                    },
                                    requestUnfollow: {
                                        requestDangerAction(.unfollow, user: preview.user)
                                    },
                                    requestMuteCreator: {
                                        requestDangerAction(.mute, user: preview.user)
                                    },
                                    copyCreatorLink: {
                                        copyCreatorLink(preview.user)
                                    },
                                    copyArtworkLink: { artwork in
                                        copyArtworkLink(artwork)
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
            }
            .scrollEdgeEffectStyle(.soft, for: .top)
        }
    }

    private var isStatusBannerVisible: Bool {
        (errorMessage != nil && previews.isEmpty == false)
            || bulkStatusText != nil
            || isRunningBulkAction
            || isCheckingFollowVisibility
            || undoAction != nil
    }

    private var visibleFollowedPreviews: [PixivUserPreview] {
        visiblePreviews.filter(\.user.isFollowed)
    }

    private var isCurrentAccountFollowingList: Bool {
        if case .following = mode {
            return true
        }
        return false
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
                if isCurrentAccountFollowingList {
                    return preview.user.isFollowed
                }
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

    private var listRefreshKey: String {
        "\(modeKey)-\(store.routeRefreshGeneration)"
    }

    private var header: some View {
        FlowLayout(spacing: 8) {
            if mode.usesRestrictPicker {
                Picker(L10n.followingCreators, selection: restrictBinding) {
                    Text(L10n.publicRestrict).tag(BookmarkRestrict.public)
                    Text(L10n.privateRestrict).tag(BookmarkRestrict.private)
                }
                .pickerStyle(.segmented)
                .frame(width: 160)
            }

            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField(L10n.searchCreatorsInList, text: $creatorSearchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(minWidth: 160, idealWidth: 200, maxWidth: 240)
            }

            Button {
                creatorSearchText = ""
            } label: {
                Label(L10n.clearSearch, systemImage: "xmark.circle")
            }
            .labelStyle(.iconOnly)
            .disabled(creatorSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .help(L10n.clearSearch)

            Menu {
                Picker(L10n.creatorFilter, selection: $creatorFilter) {
                    ForEach(CreatorListFilter.allCases) { filter in
                        Text(filter.title).tag(filter)
                    }
                }
                .pickerStyle(.inline)

                Divider()

                Picker(L10n.creatorSort, selection: $creatorSort) {
                    ForEach(CreatorListSort.allCases) { sort in
                        Text(sort.title).tag(sort)
                    }
                }
                .pickerStyle(.inline)
            } label: {
                Label(creatorFilterSummary, systemImage: "line.3.horizontal.decrease.circle")
                    .lineLimit(1)
            }
            .help("\(L10n.creatorFilter): \(creatorFilter.title) · \(L10n.creatorSort): \(creatorSort.title)")

            creatorActionsMenu
        }
        .controlSize(.small)
    }

    private var creatorFilterSummary: String {
        if creatorFilter == .all, creatorSort == .defaultOrder {
            return L10n.creatorFilter
        }
        return "\(creatorFilter.title) · \(creatorSort.title)"
    }

    private var creatorActionsMenu: some View {
        Menu {
            Button {
                Task { await refreshCreatorList() }
            } label: {
                Label(L10n.refresh, systemImage: "arrow.clockwise")
            }
            .disabled(isLoading)

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
    }

    private var headerSubtitle: String {
        "\(visiblePreviews.count.formatted()) / \(previews.count.formatted()) \(L10n.results)"
    }

    private var headerDetail: String {
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
        guard bulkActionTargetCount(action) > 0 else {
            bulkStatusText = L10n.noMatchingCreatorsForAction
            return
        }
        pendingBulkAction = action
        isShowingBulkConfirmation = true
    }

    private func requestDangerAction(_ kind: CreatorDangerAction.Kind, user: PixivUser) {
        pendingDangerAction = CreatorDangerAction(
            kind: kind,
            user: user,
            restoreRestrict: followRestrictsByUserID[user.id] ?? store.defaultFollowRestrict
        )
    }

    private func resetCreatorListState() {
        creatorSearchText = ""
        creatorFilter = .all
        creatorSort = .defaultOrder
        bulkStatusText = L10n.resetCreatorFiltersDone
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
            bulkStatusText = L10n.noMatchingCreatorsForAction
            pendingBulkAction = nil
            return
        }

        isRunningBulkAction = true
        bulkStatusText = nil
        defer {
            isRunningBulkAction = false
            pendingBulkAction = nil
        }

        var updatedCount = 0
        switch action {
        case .followPublic:
            updatedCount = await followCreators(targets, restrict: .public)
        case .followPrivate:
            updatedCount = await followCreators(targets, restrict: .private)
        case .mute:
            let mutedUsers = targets.map(\.user)
            for target in targets {
                store.muteUser(target.user)
                updateMutedState(userID: target.user.id, isMuted: true)
            }
            updatedCount = targets.count
            presentUndo(CreatorUndoAction(kind: .unmuteUsers(mutedUsers)))
        case .unfollow:
            let restores = await unfollowCreators(targets)
            updatedCount = restores.count
            if restores.isEmpty == false {
                presentUndo(CreatorUndoAction(kind: .restoreFollows(restores)))
            }
        }

        bulkStatusText = String(format: L10n.creatorActionCompletedFormat, updatedCount)
    }

    private func followCreators(_ targets: [PixivUserPreview], restrict: BookmarkRestrict) async -> Int {
        var updatedCount = 0
        for target in targets {
            do {
                try await store.setFollow(target.user, isFollowed: true, restrict: restrict)
                updateFollowState(userID: target.user.id, isFollowed: true, restrict: restrict)
                updatedCount += 1
            } catch {
                errorMessage = error.localizedDescription
            }
        }
        return updatedCount
    }

    private func unfollowCreators(_ targets: [PixivUserPreview]) async -> [CreatorFollowRestore] {
        var restores: [CreatorFollowRestore] = []
        for target in targets {
            let restrict = followRestrictsByUserID[target.user.id] ?? store.defaultFollowRestrict
            do {
                try await store.setFollow(target.user, isFollowed: false, restrict: restrict)
                updateFollowState(userID: target.user.id, isFollowed: false, restrict: nil)
                restores.append(CreatorFollowRestore(user: target.user, restrict: restrict))
            } catch {
                errorMessage = error.localizedDescription
            }
        }
        return restores
    }

    private func checkVisibleFollowVisibility() async {
        let targets = visibleFollowedPreviews
        guard targets.isEmpty == false else {
            bulkStatusText = L10n.noFollowedCreatorsToCheck
            return
        }

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

    private func refreshCreatorList() async {
        await loadInitial()
        guard errorMessage == nil else { return }
        bulkStatusText = String(format: L10n.refreshedCreatorsFormat, previews.count)
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

    private func follow(_ user: PixivUser, restrict: BookmarkRestrict? = nil) async {
        guard updatingCreatorIDs.contains(user.id) == false else { return }
        updatingCreatorIDs.insert(user.id)
        defer { updatingCreatorIDs.remove(user.id) }

        do {
            let appliedRestrict = restrict ?? store.defaultFollowRestrict
            try await store.setFollow(user, isFollowed: true, restrict: appliedRestrict)
            updateFollowState(userID: user.id, isFollowed: true, restrict: appliedRestrict)
            bulkStatusText = String(format: L10n.followedCreatorFormat, user.name)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func performDangerAction(_ action: CreatorDangerAction) async {
        defer { pendingDangerAction = nil }
        guard updatingCreatorIDs.contains(action.user.id) == false else { return }
        updatingCreatorIDs.insert(action.user.id)
        defer { updatingCreatorIDs.remove(action.user.id) }

        switch action.kind {
        case .unfollow:
            let restrict = action.restoreRestrict ?? store.defaultFollowRestrict
            do {
                try await store.setFollow(action.user, isFollowed: false, restrict: restrict)
                updateFollowState(userID: action.user.id, isFollowed: false, restrict: nil)
                presentUndo(CreatorUndoAction(kind: .restoreFollows([
                    CreatorFollowRestore(user: action.user, restrict: restrict)
                ])))
            } catch {
                errorMessage = error.localizedDescription
            }
        case .mute:
            store.muteUser(action.user)
            updateMutedState(userID: action.user.id, isMuted: true)
            presentUndo(CreatorUndoAction(kind: .unmuteUsers([action.user])))
        }
    }

    private var dangerConfirmationBinding: Binding<Bool> {
        Binding {
            pendingDangerAction != nil
        } set: { value in
            if value == false {
                pendingDangerAction = nil
            }
        }
    }

    private func performUndo(_ action: CreatorUndoAction) async {
        var restoredCount = 0
        switch action.kind {
        case .restoreFollows(let restores):
            for restore in restores {
                do {
                    try await store.setFollow(restore.user, isFollowed: true, restrict: restore.restrict)
                    updateFollowState(userID: restore.user.id, isFollowed: true, restrict: restore.restrict)
                    restoredCount += 1
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        case .unmuteUsers(let users):
            for user in users {
                store.unmuteUser(id: user.id)
                updateMutedState(userID: user.id, isMuted: false)
                restoredCount += 1
            }
        }
        if restoredCount > 0 {
            bulkStatusText = String(format: L10n.restoredCreatorActionsFormat, restoredCount)
        }
        undoAction = nil
    }

    private func presentUndo(_ action: CreatorUndoAction) {
        undoAction = action
        undoManager?.registerUndo(withTarget: store) { _ in
            Task { @MainActor in
                await performUndo(action)
            }
        }
        undoManager?.setActionName(L10n.undo)
    }

    private func copyCreatorLink(_ user: PixivUser) {
        guard let url = user.pixivURL else {
            bulkStatusText = L10n.noCreatorLinksToCopy
            return
        }
        PasteboardWriter.copy(url.absoluteString)
        bulkStatusText = String(format: L10n.copiedCreatorLinksFormat, 1)
    }

    private func copyArtworkLink(_ artwork: PixivArtwork) {
        guard let url = artwork.pixivURL else {
            bulkStatusText = L10n.noArtworkLinksToCopy
            return
        }
        PasteboardWriter.copy(url.absoluteString)
        bulkStatusText = String(format: L10n.copiedArtworkLinksFormat, 1)
    }

    private func copyVisibleCreatorLinks() {
        let links = visiblePreviews.compactMap { $0.user.pixivURL?.absoluteString }
        guard links.isEmpty == false else {
            bulkStatusText = L10n.noCreatorLinksToCopy
            return
        }
        PasteboardWriter.copy(links.joined(separator: "\n"))
        bulkStatusText = String(format: L10n.copiedCreatorLinksFormat, links.count)
    }

    private func copyVisibleCreatorSummary() {
        let summaries = visiblePreviews.map { preview in
            let user = preview.user
            let url = user.pixivURL?.absoluteString ?? ""
            return "\(user.name)\t@\(user.account)\t\(user.id)\t\(url)"
        }
        guard summaries.isEmpty == false else {
            bulkStatusText = L10n.noCreatorSummariesToCopy
            return
        }
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

    private func dismissBulkStatusTextIfNeeded(_ message: String?) async {
        guard let message else { return }
        try? await Task.sleep(for: .seconds(2.5))
        if bulkStatusText == message {
            bulkStatusText = nil
        }
    }
}

private struct UserPreviewCard: View {
    let preview: PixivUserPreview
    let followRestrict: BookmarkRestrict?
    let isUpdating: Bool
    let showContentBadges: Bool
    let openProfile: () -> Void
    let openIllustrations: () -> Void
    let openManga: () -> Void
    let followCreator: (BookmarkRestrict?) -> Void
    let requestUnfollow: () -> Void
    let requestMuteCreator: () -> Void
    let copyCreatorLink: () -> Void
    let copyArtworkLink: (PixivArtwork) -> Void
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
                        requestUnfollow()
                    }
                    .buttonStyle(.bordered)
                    .disabled(isUpdating)
                } else {
                    Menu {
                        Button(L10n.followUsingDefault) {
                            followCreator(nil)
                        }

                        Divider()

                        Button(L10n.followPublicly) {
                            followCreator(.public)
                        }
                        Button(L10n.followPrivately) {
                            followCreator(.private)
                        }
                    } label: {
                        if isUpdating {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Label(L10n.follow, systemImage: "person.crop.circle.badge.plus")
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(isUpdating)
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
                                    copyArtworkLink(artwork)
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
                    requestMuteCreator()
                } label: {
                    if isUpdating {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label(L10n.muteCreator, systemImage: "eye.slash")
                    }
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.bordered)
                .disabled(isUpdating)
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
                    requestUnfollow()
                }
            } else {
                Button(L10n.followUsingDefault) {
                    followCreator(nil)
                }
                Button(L10n.followPublicly) {
                    followCreator(.public)
                }
                Button(L10n.followPrivately) {
                    followCreator(.private)
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
                requestMuteCreator()
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
