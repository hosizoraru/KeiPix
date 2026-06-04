import SwiftUI

/// Sheet that surfaces a creator's full profile: hero stats, collection
/// shortcuts, recent works, bio, links, workspace, and related creators.
///
/// The view is organised as four cleanly separated layers so each piece
/// of the sheet has one obvious owner:
///
///   1. **Header** — chrome row built by `UserProfileSheetHeader`.
///      Identity + the three top-level controls (follow / actions /
///      close). Pure presentation; this view feeds it state and
///      callbacks.
///   2. **Body** — `bodyContent` switches between `.loading`, `.error`,
///      and `.loaded` so the parent body never branches inline.
///   3. **Loaded sections** — every panel (metrics, shortcuts, recent
///      works, bio, links, workspace, related creators) is its own
///      `View`. The sheet does no layout of its own beyond stacking them
///      with consistent spacing.
///   4. **Side effects & overlays** — task lifecycle, child sheets
///      (related-user profile, list view, feedback report),
///      confirmation dialogs, status banner, undo bar — all attached at
///      the root with explicit modifiers, no nesting inside the body.
///
/// The previous version cooked the avatar / banner / actions into a
/// 168-pt `ZStack` slab and folded loading + error + loaded states
/// directly into the `ScrollView`. It accumulated a lot of patches over
/// time. This rewrite keeps the rendering linear and source-of-truth
/// minimal so the sheet behaves predictably regardless of which fields
/// Pixiv returns.
struct UserProfileSheet: View {
    let user: PixivUser
    @Bindable var store: KeiPixStore
    private let visualQADetail: PixivUserDetail?
    private let visualQARelatedUsers: [PixivUserPreview]?
    private let visualQARecentWorks: [PixivArtwork]?

    @Environment(\.dismiss) private var dismiss

    // Detail loading
    @State private var detail: PixivUserDetail?
    @State private var isLoading = true
    @State private var errorMessage: String?

    // Follow state
    @State private var isFollowed: Bool
    @State private var followRestrict: BookmarkRestrict?
    @State private var isUpdatingFollow = false

    // Related users
    @State private var relatedUsers: [PixivUserPreview] = []
    @State private var isLoadingRelatedUsers = false
    @State private var relatedErrorMessage: String?
    @State private var updatingRelatedUserIDs: Set<Int> = []

    // Sheets / dialogs
    @State private var selectedRelatedUser: PixivUser?
    @State private var relationshipListMode: UserPreviewListMode?
    @State private var pendingDangerAction: AppDangerAction?
    @State private var feedbackRequest: FeedbackReportRequest?

    // Status banner
    @State private var statusMessage: String?

    init(
        user: PixivUser,
        store: KeiPixStore,
        visualQADetail: PixivUserDetail? = nil,
        visualQARelatedUsers: [PixivUserPreview]? = nil,
        visualQARecentWorks: [PixivArtwork]? = nil
    ) {
        self.user = user
        self.store = store
        self.visualQADetail = visualQADetail
        self.visualQARelatedUsers = visualQARelatedUsers
        self.visualQARecentWorks = visualQARecentWorks
        _isFollowed = State(initialValue: user.isFollowed)
    }

    // MARK: - Body

    var body: some View {
        sheetContent
        #if os(macOS)
        .frame(width: 820)
        #else
        .frame(maxWidth: 780)
        #endif
        .frame(minHeight: 560, idealHeight: 720, maxHeight: .infinity)
        .task(id: user.id) {
            await loadDetail()
            await loadRelatedUsers()
        }
        // Side effects and overlays are stacked at the root so the body
        // tree above stays purely structural.
        .modifier(ChildSheetsModifier(
            selectedRelatedUser: $selectedRelatedUser,
            relationshipListMode: $relationshipListMode,
            feedbackRequest: $feedbackRequest,
            store: store,
            currentUser: currentUser,
            pendingDangerAction: $pendingDangerAction,
            showStatus: showStatus
        ))
        .overlay(alignment: .bottom) { statusOverlay }
        .animation(.snappy(duration: 0.18), value: statusMessage)
        .animation(.snappy(duration: 0.18), value: store.undoAction?.id)
        .confirmationDialog(
            pendingDangerAction?.title ?? L10n.moreActions,
            isPresented: dangerActionBinding,
            titleVisibility: .visible
        ) {
            if let pendingDangerAction {
                Button(pendingDangerAction.title, role: .destructive) {
                    Task { await performDangerAction(pendingDangerAction) }
                }
            }
            Button(L10n.cancel, role: .cancel) {}
        } message: {
            if let pendingDangerAction {
                Text(pendingDangerAction.confirmationMessage)
            }
        }
    }

    private var sheetContent: some View {
        VStack(spacing: 0) {
            UserProfileSheetHeader(
                user: currentUser,
                detail: detail,
                isLoading: isLoading,
                isFollowed: isFollowed,
                isUpdatingFollow: isUpdatingFollow,
                followRestrict: followRestrict,
                toggleFollow: { restrict in
                    Task { await toggleFollow(restrict: restrict) }
                },
                updateFollowVisibility: { restrict in
                    Task { await updateFollowVisibility(restrict) }
                },
                requestUnfollow: {
                    pendingDangerAction = AppDangerAction(kind: .unfollowCreator(currentUser, followRestrict))
                },
                isPinned: store.isPinnedCreator(currentUser),
                togglePin: togglePinnedCreator,
                openInPixivURL: currentUser.pixivURL,
                copyLink: copyProfileLink,
                isMuted: store.mutedUsers[currentUser.id] != nil,
                toggleMute: toggleCreatorMute,
                requestFeedback: {
                    feedbackRequest = .creator(currentUser)
                }
            )

            Divider()
                .opacity(0.35)

            bodyContent
                .id(contentState.animationID)
                .transition(.opacity.combined(with: .scale(scale: 0.985)))
        }
        .animation(.snappy(duration: 0.22), value: contentState)
    }

    // MARK: - Body content states

    @ViewBuilder
    private var bodyContent: some View {
        switch contentState {
        case .loading:
            loadingState
        case .error(let message):
            errorState(message: message)
        case .loaded:
            loadedScroll
        }
    }

    private var loadingState: some View {
        UserProfileLoadingSkeleton()
    }

    private func errorState(message: String) -> some View {
        OS26LibraryUnavailableView(
            title: L10n.errorTitle,
            subtitle: message,
            systemImage: "exclamationmark.triangle"
        ) {
            Button {
                Task { await loadDetail() }
            } label: {
                Label(L10n.retry, systemImage: "arrow.clockwise")
            }
            .os26GlassButton(prominent: true)
        }
    }

    private var loadedScroll: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                UserProfileOverviewSection(
                    profile: detail?.profile,
                    relatedUsersCount: relatedUsers.count,
                    isLoadingRelatedUsers: isLoadingRelatedUsers,
                    openIllustrations: { openFeed(.userIllustrations) },
                    openManga: { openFeed(.userManga) },
                    openPublicBookmarks: { openFeed(.userPublicBookmarks) },
                    openFollowing: {
                        relationshipListMode = .userFollowing(currentUser)
                    },
                    openFollowers: {
                        relationshipListMode = .userFollowers(currentUser)
                    },
                    openRelated: {
                        relationshipListMode = .related(currentUser)
                    }
                )

                UserProfileCreatorTagsSection(
                    user: currentUser,
                    store: store,
                    openTag: openCreatorTag,
                    visualQAArtworks: visualQARecentWorks
                )

                UserProfileRecentWorksSection(
                    user: currentUser,
                    store: store,
                    openAllWorks: { openFeed(.userIllustrations) },
                    selectArtwork: selectArtwork,
                    showStatus: showStatus,
                    visualQAArtworks: visualQARecentWorks
                )

                UserProfileDescriptionSection(text: bioText)

                UserProfileWorkspaceSection(workspace: detail?.workspace)

                UserProfileRelatedCreatorsSection(
                    relatedUsers: relatedUsers,
                    isLoadingRelatedUsers: isLoadingRelatedUsers,
                    relatedErrorMessage: relatedErrorMessage,
                    updatingRelatedUserIDs: updatingRelatedUserIDs,
                    reload: { Task { await loadRelatedUsers() } },
                    viewAll: {
                        relationshipListMode = .related(currentUser)
                    },
                    openProfile: { selectedRelatedUser = $0 },
                    openIllustrations: { relatedUser in
                        Task {
                            await store.openUserFeed(user: relatedUser, route: .userIllustrations)
                            dismiss()
                        }
                    },
                    toggleFollow: { related, restrict in
                        Task { await toggleRelatedFollow(related, restrict: restrict) }
                    },
                    requestUnfollow: { related in
                        pendingDangerAction = AppDangerAction(kind: .unfollowCreator(related, nil))
                    },
                    requestMuteCreator: { related in
                        pendingDangerAction = AppDangerAction(kind: .muteCreator(related))
                    },
                    copied: { showStatus(L10n.copied) },
                    selectArtwork: selectArtwork
                )

                if let inlineErrorMessage {
                    Text(inlineErrorMessage)
                        .font(.callout)
                        .foregroundStyle(.red)
                        .textSelection(.enabled)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
    }

    @ViewBuilder
    private var statusOverlay: some View {
        VStack(spacing: 8) {
            if let statusMessage {
                FloatingStatusBanner {
                    Text(statusMessage)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if let undoAction = store.undoAction {
                AppUndoBar(action: undoAction) {
                    Task { await performUndo(undoAction) }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 14)
    }

    // MARK: - Derived state

    /// Three-way content state. `error` only fires when we have nothing
    /// to show — once `detail` lands successfully, transient errors fall
    /// through to `inlineErrorMessage` instead of replacing the body.
    private enum ContentState: Equatable {
        case loading
        case error(String)
        case loaded

        var animationID: String {
            switch self {
            case .loading:
                "loading"
            case .error:
                "error"
            case .loaded:
                "loaded"
            }
        }
    }

    private var contentState: ContentState {
        if isLoading && detail == nil {
            return .loading
        }
        if detail == nil, let errorMessage {
            return .error(errorMessage)
        }
        return .loaded
    }

    /// Error message shown inline at the bottom of the loaded state — for
    /// errors that happen *after* we already have detail data.
    private var inlineErrorMessage: String? {
        guard detail != nil else { return nil }
        return errorMessage
    }

    private var bioText: String? {
        (detail?.user.comment ?? user.comment)?.htmlStripped
    }

    private var currentUser: PixivUser {
        detail?.user ?? user
    }

    private var dangerActionBinding: Binding<Bool> {
        Binding {
            pendingDangerAction != nil
        } set: { value in
            if value == false {
                pendingDangerAction = nil
            }
        }
    }

    // MARK: - Loading

    private func loadDetail() async {
        if let visualQADetail {
            detail = visualQADetail
            isFollowed = visualQADetail.user.isFollowed
            followRestrict = visualQADetail.user.isFollowed ? .public : nil
            errorMessage = nil
            isLoading = false
            return
        }

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
        if let visualQARelatedUsers {
            relatedUsers = visualQARelatedUsers.filter { $0.user.id != user.id }
            isLoadingRelatedUsers = false
            relatedErrorMessage = nil
            return
        }

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

    // MARK: - Follow actions

    private func toggleFollow(restrict: BookmarkRestrict? = nil) async {
        guard isUpdatingFollow == false else { return }
        let target = currentUser
        let nextValue = isFollowed == false
        let appliedRestrict = restrict ?? store.defaultFollowRestrict
        isUpdatingFollow = true
        defer { isUpdatingFollow = false }
        do {
            try await store.setFollow(target, isFollowed: nextValue, restrict: appliedRestrict)
            isFollowed = nextValue
            followRestrict = nextValue ? appliedRestrict : nil
            if nextValue {
                showStatus(String(format: L10n.followedCreatorFormat, target.name))
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func updateFollowVisibility(_ restrict: BookmarkRestrict) async {
        guard isUpdatingFollow == false else { return }
        let target = currentUser
        isUpdatingFollow = true
        defer { isUpdatingFollow = false }
        do {
            try await store.setFollow(target, isFollowed: true, restrict: restrict)
            isFollowed = true
            followRestrict = restrict
            showStatus(String(format: L10n.updatedCreatorFollowVisibilityFormat, target.name))
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func toggleRelatedFollow(_ user: PixivUser, restrict: BookmarkRestrict? = nil) async {
        guard updatingRelatedUserIDs.contains(user.id) == false else { return }
        let nextValue = user.isFollowed == false
        let appliedRestrict = restrict ?? store.defaultFollowRestrict
        updatingRelatedUserIDs.insert(user.id)
        defer { updatingRelatedUserIDs.remove(user.id) }
        do {
            try await store.setFollow(user, isFollowed: nextValue, restrict: appliedRestrict)
        } catch {
            relatedErrorMessage = error.localizedDescription
            return
        }
        updateRelatedFollowState(userID: user.id, isFollowed: nextValue)
        if nextValue {
            showStatus(String(format: L10n.followedCreatorFormat, user.name))
        }
    }

    // MARK: - Danger / undo

    private func performDangerAction(_ action: AppDangerAction) async {
        defer { pendingDangerAction = nil }
        let succeeded = await store.performDangerAction(action)
        guard succeeded else {
            errorMessage = store.errorMessage
            return
        }

        switch action.kind {
        case .unfollowCreator(let user, _):
            if user.id == currentUser.id {
                isFollowed = false
                followRestrict = nil
            }
            updateRelatedFollowState(userID: user.id, isFollowed: false)
            showStatus(String(format: L10n.unfollowedCreatorFormat, user.name))
        case .muteCreator(let user):
            updateRelatedMutedState(userID: user.id, isMuted: true)
            showStatus(String(format: L10n.mutedCreatorFormat, user.name))
        case .removeBookmark, .muteArtwork, .muteTag:
            break
        }
    }

    private func performUndo(_ action: AppUndoAction) async {
        await store.performUndo(action)

        switch action.kind {
        case .restoreFollow(let user, let restrict):
            if user.id == currentUser.id {
                isFollowed = true
                followRestrict = restrict
            }
            updateRelatedFollowState(userID: user.id, isFollowed: true)
            showStatus(String(format: L10n.followedCreatorFormat, user.name))
        case .unmuteCreator(let user):
            updateRelatedMutedState(userID: user.id, isMuted: false)
        default:
            break
        }
    }

    // MARK: - Related-user mutation helpers

    private func updateRelatedFollowState(userID: Int, isFollowed: Bool) {
        for index in relatedUsers.indices where relatedUsers[index].user.id == userID {
            var updatedUser = relatedUsers[index].user
            updatedUser.isFollowed = isFollowed
            relatedUsers[index] = PixivUserPreview(
                user: updatedUser,
                illusts: relatedUsers[index].illusts,
                isMuted: relatedUsers[index].isMuted
            )
        }
    }

    private func updateRelatedMutedState(userID: Int, isMuted: Bool) {
        for index in relatedUsers.indices where relatedUsers[index].user.id == userID {
            relatedUsers[index] = PixivUserPreview(
                user: relatedUsers[index].user,
                illusts: relatedUsers[index].illusts,
                isMuted: isMuted
            )
        }
    }

    // MARK: - Misc actions

    private func openFeed(_ route: PixivRoute) {
        Task {
            await store.openUserFeed(user: currentUser, route: route)
            dismiss()
        }
    }

    private func openCreatorTag(_ tag: CreatorArtworkTag) {
        Task {
            await store.openCreatorTagFeed(user: currentUser, tag: tag)
            dismiss()
        }
    }

    private func selectArtwork(_ artwork: PixivArtwork) {
        store.selectedArtwork = artwork
        dismiss()
    }

    private func copyProfileLink() {
        guard let url = currentUser.pixivURL else { return }
        PasteboardWriter.copy(url.absoluteString)
        showStatus(L10n.copied)
    }

    private func togglePinnedCreator() {
        let isPinned = store.togglePinnedCreator(currentUser)
        showStatus(String(
            format: isPinned ? L10n.pinnedCreatorFormat : L10n.unpinnedCreatorFormat,
            currentUser.name
        ))
    }

    /// Quick mute toggle on the profile chrome. Mute routes through the
    /// shared danger-action confirmation (parity with the related-creators
    /// list and the bulk-block sheet); unmute is reversible so it fires
    /// immediately and surfaces a status banner.
    private func toggleCreatorMute() {
        let target = currentUser
        if store.mutedUsers[target.id] != nil {
            store.unmuteUser(id: target.id)
            showStatus(String(format: L10n.removedMutedCreatorFormat, target.name))
        } else {
            pendingDangerAction = AppDangerAction(kind: .muteCreator(target))
        }
    }

    private func showStatus(_ message: String) {
        statusMessage = message
        Task {
            try? await Task.sleep(for: .seconds(2.5))
            if statusMessage == message {
                statusMessage = nil
            }
        }
    }
}

private struct UserProfileLoadingSkeleton: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                metricsSkeleton
                tagsSkeleton
                recentWorksSkeleton
                descriptionSkeleton
                relatedCreatorsSkeleton
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
        .allowsHitTesting(false)
        .accessibilityLabel(L10n.loading)
    }

    private var metricsSkeleton: some View {
        LazyVGrid(columns: metricColumns, spacing: 10) {
            ForEach(0..<6, id: \.self) { _ in
                VStack(alignment: .leading, spacing: 8) {
                    SkeletonPlaceholder(width: 86, height: 12, cornerRadius: 6)
                    SkeletonPlaceholder(width: 54, height: 18, cornerRadius: 9)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .os26SkeletonSurface(16)
            }
        }
    }

    private var tagsSkeleton: some View {
        VStack(alignment: .leading, spacing: 12) {
            SkeletonPlaceholder(width: 130, height: 18, cornerRadius: 9)
            FlowLayout(spacing: 8) {
                ForEach([72, 96, 64, 118, 84, 104], id: \.self) { width in
                    SkeletonPlaceholder(width: CGFloat(width), height: 28, cornerRadius: 14)
                }
            }
        }
        .padding(14)
        .os26SkeletonSurface(18)
    }

    private var recentWorksSkeleton: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SkeletonPlaceholder(width: 118, height: 18, cornerRadius: 9)
                Spacer(minLength: 0)
                SkeletonPlaceholder(width: 88, height: 28, cornerRadius: 14)
            }

            HStack(spacing: 10) {
                ForEach(0..<4, id: \.self) { _ in
                    SkeletonPlaceholder(width: nil, height: 120, cornerRadius: 16)
                }
            }
        }
        .padding(14)
        .os26SkeletonSurface(18)
    }

    private var descriptionSkeleton: some View {
        VStack(alignment: .leading, spacing: 9) {
            SkeletonPlaceholder(width: 96, height: 18, cornerRadius: 9)
            SkeletonPlaceholder(width: nil, height: 12, cornerRadius: 6)
            SkeletonPlaceholder(width: nil, height: 12, cornerRadius: 6)
            SkeletonPlaceholder(width: 260, height: 12, cornerRadius: 6)
        }
        .padding(14)
        .os26SkeletonSurface(18)
    }

    private var relatedCreatorsSkeleton: some View {
        VStack(alignment: .leading, spacing: 12) {
            SkeletonPlaceholder(width: 132, height: 18, cornerRadius: 9)

            HStack(spacing: 10) {
                ForEach(0..<3, id: \.self) { _ in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 10) {
                            SkeletonPlaceholder(width: 38, height: 38, cornerRadius: 19)
                            VStack(alignment: .leading, spacing: 7) {
                                SkeletonPlaceholder(width: 92, height: 13, cornerRadius: 7)
                                SkeletonPlaceholder(width: 64, height: 10, cornerRadius: 5)
                            }
                        }
                        SkeletonPlaceholder(width: nil, height: 76, cornerRadius: 14)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .os26SkeletonSurface(16)
                }
            }
        }
        .padding(14)
        .os26SkeletonSurface(18)
    }

    private var metricColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 112, maximum: 160), spacing: 10)]
    }
}

// MARK: - Child sheets

/// Bundles the three child sheets the profile presents (related-user
/// profile, relationship list, feedback report) so the main view body
/// stays linear and doesn't grow a tower of `.sheet(item:)` modifiers.
private struct ChildSheetsModifier: ViewModifier {
    @Binding var selectedRelatedUser: PixivUser?
    @Binding var relationshipListMode: UserPreviewListMode?
    @Binding var feedbackRequest: FeedbackReportRequest?
    @Bindable var store: KeiPixStore
    let currentUser: PixivUser
    @Binding var pendingDangerAction: AppDangerAction?
    let showStatus: (String) -> Void

    func body(content: Content) -> some View {
        content
            .sheet(item: $selectedRelatedUser) { relatedUser in
                UserProfileSheet(user: relatedUser, store: store)
                    .os26SheetChrome(.detail)
            }
            .sheet(item: $relationshipListMode) { mode in
                UserPreviewListView(store: store, mode: mode, showsCloseButton: true)
                    #if os(macOS)
                    .frame(width: 920, height: 680)
                    #endif
                    .os26SheetChrome(.detail)
            }
            .sheet(item: $feedbackRequest) { request in
                FeedbackReportSheet(request: request) {
                    pendingDangerAction = AppDangerAction(kind: .muteCreator(currentUser))
                } onComplete: { message in
                    showStatus(message)
                }
                .os26SheetChrome(.form)
            }
    }
}
