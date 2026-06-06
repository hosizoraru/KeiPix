import Foundation
import SwiftUI

struct UserPreviewListView: View {
    @Bindable var store: KeiPixStore
    let mode: UserPreviewListMode
    let showsCloseButton: Bool
    @Environment(\.undoManager) private var undoManager
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

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
    @State private var feedbackRequest: FeedbackReportRequest?
    @State private var feedbackMuteUser: PixivUser?

    init(
        store: KeiPixStore,
        mode: UserPreviewListMode,
        showsCloseButton: Bool = false
    ) {
        self.store = store
        self.mode = mode
        self.showsCloseButton = showsCloseButton
    }

    var body: some View {
        Group {
            if store.session == nil {
                PixivSignedOutStateView(store: store)
            } else {
                creatorListSurface
            }
        }
        .platformPageHeader(
            title: mode.title,
            status: creatorNavigationStatus,
            statusSystemImage: "person.2"
        )
        .platformPageNavigationChrome(title: mode.title, status: creatorNavigationStatus)
        .toolbar {
            // macOS HIG keeps refresh / view-options / bulk-action
            // entry points in the toolbar so the body stays focused on
            // content. The previous version crammed all five into a
            // FlowLayout band below the title — replaced with the
            // standard pattern used by Mail / Photos / Music.
            ToolbarItem(placement: .secondaryAction) {
                Button {
                    Task { await refreshCreatorList() }
                } label: {
                    Label(L10n.refresh, systemImage: "arrow.clockwise")
                }
                .labelStyle(.iconOnly)
                .help(L10n.refresh)
                .disabled(isLoading)
            }

            ToolbarItem(placement: .secondaryAction) {
                CreatorListViewOptionsMenu(
                    creatorFilter: $creatorFilter,
                    creatorSort: $creatorSort,
                    layoutMode: creatorLayoutBinding
                )
            }

            ToolbarItem(placement: .secondaryAction) {
                if hasActiveCreatorListState {
                    Button {
                        resetCreatorListState()
                    } label: {
                        Label(L10n.resetCreatorFilters, systemImage: "arrow.counterclockwise")
                    }
                    .labelStyle(.iconOnly)
                    .help(L10n.resetCreatorFilters)
                }
            }

            ToolbarItem(placement: .secondaryAction) {
                CreatorListBulkActionsMenu(
                    isRunningBulkAction: isRunningBulkAction,
                    isCheckingFollowVisibility: isCheckingFollowVisibility,
                    visiblePreviewsCount: visiblePreviews.count,
                    visibleFollowedPreviewsCount: visibleFollowedPreviews.count,
                    bulkActionTargetCount: bulkActionTargetCount,
                    checkVisibleFollowVisibility: { Task { await checkVisibleFollowVisibility() } },
                    copyVisibleCreatorLinks: copyVisibleCreatorLinks,
                    copyVisibleCreatorSummary: copyVisibleCreatorSummary,
                    requestBulkAction: requestBulkAction
                )
            }

            if showsCloseButton {
                ToolbarItem(placement: .confirmationAction) {
                    SheetCloseButton(style: .bordered)
                }
            }
        }
        .overlay(alignment: .bottom) {
            if isStatusBannerVisible {
                CreatorListStatusBanner(
                    errorMessage: errorMessage,
                    bulkStatusText: bulkStatusText,
                    isRunningBulkAction: isRunningBulkAction,
                    isCheckingFollowVisibility: isCheckingFollowVisibility,
                    undoAction: undoAction,
                    performUndo: { action in Task { await performUndo(action) } }
                )
                .padding(.horizontal, 18)
                .padding(.bottom, statusBannerBottomPadding)
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
                .os26SheetChrome(.detail)
        }
        .sheet(item: $feedbackRequest) { request in
            FeedbackReportSheet(request: request) {
                if let feedbackMuteUser {
                    requestDangerAction(.mute, user: feedbackMuteUser)
                }
            } onComplete: { message in
                bulkStatusText = message
            }
            .os26SheetChrome(.form)
        }
        .task(id: listRefreshKey) {
            await loadInitial()
        }
        .task(id: bulkStatusText) {
            await dismissBulkStatusTextIfNeeded(bulkStatusText)
        }
        .task(id: undoAction?.id) {
            await dismissUndoActionIfNeeded(undoAction?.id)
        }
        .onChange(of: modeKey) {
            clearTransientCreatorListChrome()
        }
    }

    private var creatorListSurface: some View {
        VStack(spacing: 0) {
            CreatorListSearchBar(
                mode: mode,
                restrict: restrictBinding,
                creatorSearchText: $creatorSearchText,
                globalSearchKeyword: searchKeyword,
                clearGlobalSearch: {
                    withAnimation(.snappy(duration: 0.16)) {
                        store.clearSearchText()
                    }
                }
            )
            .platformGlassControlBar(verticalPadding: 8, topPadding: 2)

            CreatorPreviewListContent(
                mode: mode,
                layoutMode: store.creatorListLayoutMode,
                searchKeyword: searchKeyword,
                previews: previews,
                visiblePreviews: visiblePreviews,
                nextURL: nextURL,
                errorMessage: errorMessage,
                isLoadingInitial: isLoading && previews.isEmpty,
                isLoadingMore: isLoadingMore,
                followRestrictsByUserID: followRestrictsByUserID,
                updatingCreatorIDs: updatingCreatorIDs,
                showContentBadges: store.showContentBadges,
                maskSensitivePreviews: store.maskSensitivePreviews,
                retry: { Task { await loadInitial() } },
                loadMore: { Task { await loadMore() } },
                openProfile: { profileUser = $0 },
                openIllustrations: { user in Task { await store.openUserFeed(user: user, route: .userIllustrations) } },
                openManga: { user in Task { await store.openUserFeed(user: user, route: .userManga) } },
                followCreator: { user, restrict in Task { await follow(user, restrict: restrict) } },
                requestUnfollow: { requestDangerAction(.unfollow, user: $0) },
                requestMuteCreator: { requestDangerAction(.mute, user: $0) },
                requestFeedback: presentFeedback,
                copyCreatorLink: copyCreatorLink,
                copyArtworkLink: copyArtworkLink,
                isPinnedCreator: store.isPinnedCreator,
                togglePinnedCreator: togglePinnedCreator,
                selectArtwork: { store.selectedArtwork = $0 },
                creatorPreviewArtworkCacheGeneration: store.creatorPreviewArtworkCacheGeneration,
                cachedCreatorPreviewArtworks: { user in
                    store.cachedCreatorPreviewArtworks(for: user)
                },
                loadCreatorPreviewArtworks: { user in
                    try await store.creatorPreviewArtworks(for: user)
                }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Two-way bridge between the header's segmented Picker and the
    /// store-owned setting. The setter persists to UserDefaults so the
    /// preference survives relaunches.
    private var creatorLayoutBinding: Binding<CreatorListLayoutMode> {
        Binding {
            store.creatorListLayoutMode
        } set: { newValue in
            store.setCreatorListLayoutMode(newValue)
        }
    }

    private var isStatusBannerVisible: Bool {
        (errorMessage != nil && previews.isEmpty == false)
            || bulkStatusText != nil
            || isRunningBulkAction
            || isCheckingFollowVisibility
            || undoAction != nil
    }

    private var statusBannerBottomPadding: CGFloat {
        #if os(iOS)
        UIDevice.current.userInterfaceIdiom == .phone || horizontalSizeClass == .compact ? 92 : 14
        #else
        14
        #endif
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

    /// Subtitle shown beside the navigation title. Keep it compact:
    /// visible/total count plus the search keyword when relevant.
    private var navigationSubtitle: String {
        let counts = "\(visiblePreviews.count.formatted())/\(previews.count.formatted())"
        if mode.requiresSearchKeyword, searchKeyword.isEmpty == false {
            return "\(searchKeyword) · \(counts)"
        }
        return counts
    }

    private var creatorNavigationStatus: String {
        guard store.session != nil else { return "" }
        return navigationSubtitle
    }

    private var restrictBinding: Binding<BookmarkRestrict> {
        Binding {
            restrict
        } set: { value in
            restrict = value
        }
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

    private func presentFeedback(for user: PixivUser) {
        feedbackMuteUser = user
        feedbackRequest = .creator(user)
    }

    private func clearTransientCreatorListChrome() {
        bulkStatusText = nil
        undoAction = nil
        errorMessage = nil
        pendingBulkAction = nil
        pendingDangerAction = nil
        isShowingBulkConfirmation = false
    }

    private func resetCreatorListState() {
        withAnimation(.snappy(duration: 0.16)) {
            creatorSearchText = ""
            creatorFilter = .all
            creatorSort = .defaultOrder
        }
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
            let followedUsers = await followCreators(targets, restrict: .public)
            updatedCount = followedUsers.count
            if followedUsers.isEmpty == false {
                presentUndo(CreatorUndoAction(kind: .unfollowUsers(followedUsers)))
            }
        case .followPrivate:
            let followedUsers = await followCreators(targets, restrict: .private)
            updatedCount = followedUsers.count
            if followedUsers.isEmpty == false {
                presentUndo(CreatorUndoAction(kind: .unfollowUsers(followedUsers)))
            }
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
                await refreshCurrentAccountFollowingListIfNeeded()
            }
        }

        bulkStatusText = updatedCount > 0
            ? String(format: L10n.creatorActionCompletedFormat, updatedCount)
            : L10n.noMatchingCreatorsForAction
    }

    private func followCreators(_ targets: [PixivUserPreview], restrict: BookmarkRestrict) async -> [PixivUser] {
        var followedUsers: [PixivUser] = []
        for target in targets {
            do {
                try await store.setFollow(target.user, isFollowed: true, restrict: restrict)
                updateFollowState(userID: target.user.id, isFollowed: true, restrict: restrict)
                followedUsers.append(target.user)
            } catch {
                presentCreatorListError(error)
            }
        }
        return followedUsers
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
                presentCreatorListError(error)
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
                if presentCreatorListError(error) {
                    failedCount += 1
                }
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
        guard mode.requiresSearchKeyword == false || searchKeyword.isEmpty == false else {
            previews = []
            nextURL = nil
            followRestrictsByUserID = [:]
            errorMessage = nil
            isLoading = false
            return
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let response: PixivUserPreviewResponse = switch mode {
            case .recommended:
                try await store.recommendedUsers()
            case .following:
                try await store.followingUsers(restrict: restrict)
            case .pinned:
                PixivUserPreviewResponse(userPreviews: store.pinnedCreatorPreviews, nextURL: nil)
            case .search:
                try await store.searchUsers(keyword: searchKeyword)
            case .userFollowing(let user):
                try await store.followingUsers(for: user, restrict: restrict)
            case .userFollowers(let user):
                try await store.followerUsers(for: user, restrict: restrict)
            case .related(let user):
                try await store.relatedUsers(for: user)
            }
            let loadedPreviews = normalizedLoadedPreviews(response.userPreviews)
            previews = loadedPreviews
            followRestrictsByUserID = inferredFollowRestricts(for: loadedPreviews)
            nextURL = response.nextURL
        } catch {
            presentCreatorListError(error)
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
            let loadedPreviews = normalizedLoadedPreviews(response.userPreviews)
            previews.append(contentsOf: loadedPreviews)
            followRestrictsByUserID.merge(inferredFollowRestricts(for: loadedPreviews)) { _, new in new }
            self.nextURL = response.nextURL
        } catch {
            presentCreatorListError(error)
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
            presentUndo(CreatorUndoAction(kind: .unfollowUsers([user])))
            bulkStatusText = String(format: L10n.followedCreatorFormat, user.name)
        } catch {
            presentCreatorListError(error)
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
                bulkStatusText = String(format: L10n.unfollowedCreatorFormat, action.user.name)
                await refreshCurrentAccountFollowingListIfNeeded()
            } catch {
                presentCreatorListError(error)
            }
        case .mute:
            store.muteUser(action.user)
            updateMutedState(userID: action.user.id, isMuted: true)
            presentUndo(CreatorUndoAction(kind: .unmuteUsers([action.user])))
            bulkStatusText = String(format: L10n.mutedCreatorFormat, action.user.name)
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
                    presentCreatorListError(error)
                }
            }
        case .unmuteUsers(let users):
            for user in users {
                store.unmuteUser(id: user.id)
                updateMutedState(userID: user.id, isMuted: false)
                restoredCount += 1
            }
        case .unfollowUsers(let users):
            for user in users {
                do {
                    try await store.setFollow(user, isFollowed: false, restrict: store.defaultFollowRestrict)
                    updateFollowState(userID: user.id, isFollowed: false, restrict: nil)
                    restoredCount += 1
                } catch {
                    presentCreatorListError(error)
                }
            }
        }
        if restoredCount > 0 {
            bulkStatusText = String(format: L10n.restoredCreatorActionsFormat, restoredCount)
            await refreshCurrentAccountFollowingListIfNeeded()
        }
        undoAction = nil
    }

    private func refreshCurrentAccountFollowingListIfNeeded() async {
        guard isCurrentAccountFollowingList else { return }
        try? await Task.sleep(for: .milliseconds(350))
        await loadInitial()
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

    private func togglePinnedCreator(_ user: PixivUser) {
        let isPinned = store.togglePinnedCreator(user)
        if case .pinned = mode, isPinned == false {
            previews.removeAll { $0.user.id == user.id }
        } else {
            upsertPreview(user)
        }
        bulkStatusText = String(format: isPinned ? L10n.pinnedCreatorFormat : L10n.unpinnedCreatorFormat, user.name)
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
            store.renderCreatorCopySummary(preview.user)
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

    private func upsertPreview(_ user: PixivUser) {
        guard let index = previews.firstIndex(where: { $0.user.id == user.id }) else {
            return
        }
        previews[index] = PixivUserPreview(user: user, illusts: previews[index].illusts, isMuted: previews[index].isMuted)
    }

    private func normalizedLoadedPreviews(_ userPreviews: [PixivUserPreview]) -> [PixivUserPreview] {
        guard isCurrentAccountFollowingList else { return userPreviews }
        return userPreviews.map { preview in
            var user = preview.user
            user.isFollowed = true
            return PixivUserPreview(user: user, illusts: preview.illusts, isMuted: preview.isMuted)
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

    private func dismissUndoActionIfNeeded(_ actionID: UUID?) async {
        guard let actionID else { return }
        do {
            try await Task.sleep(for: .seconds(4))
        } catch {
            return
        }
        if undoAction?.id == actionID {
            undoAction = nil
        }
    }

    @discardableResult
    private func presentCreatorListError(_ error: Error) -> Bool {
        guard isCreatorListCancellationError(error) == false else {
            return false
        }
        errorMessage = error.localizedDescription
        return true
    }

    private func isCreatorListCancellationError(_ error: Error) -> Bool {
        if error is CancellationError {
            return true
        }

        let nsError = error as NSError
        return nsError.domain == NSURLErrorDomain
            && nsError.code == NSURLErrorCancelled
    }
}
